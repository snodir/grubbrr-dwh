/* ============================================================================
   DEDUP RUNBOOK — fact.deviceevent (~200M) & fact.userbehaviour (~170M)
   Target: Azure Cosmos DB for PostgreSQL, SINGLE-NODE (coordinator only),
           4 vCore / 16 GB (post scale-up)
   Goal:   remove duplicates -> create unique indexes -> incremental loads
           drop from 15-20 min back to seconds.

   KEY INSIGHT: userbehaviour is a SUBSET of deviceevent filtered by
     eventmodule = 'kiosk' AND datacategory IN ('insight','Order','StoreTiming',
     'BusinessHours','Session')
   So we don't dedup userbehaviour in-place at all — we TRUNCATE it (instant,
   reclaims 51 GB to the OS) and rebuild from the clean deviceevent. This:
     - frees 51 GB of real disk BEFORE the deviceevent index build needs it
     - skips the 187k-copy duplicate group entirely (no quadratic risk)
     - produces a compact, bloat-free userbehaviour with sequential layout

   Run order: STEP 0 -> 8. Run on STAGE first, capture timings, then PROD.
   Run each STEP with autocommit ON and NOT inside an outer BEGIN block
   (the dedup procedure issues its own COMMITs).

   Natural keys (must match the SPs exactly):
     fact.deviceevent     : locationid, eventtoken, datacategory, actiontype, eventinstant
     fact.userbehaviour   : locationid, ordersessionidentifier, eventcategory, eventtype, eventinstant
   Tie-break (which copy to KEEP): latest by syscosmosts, then syscosmosticks, then ctid.
============================================================================ */


/* ---------------------------------------------------------------------------
   STEP 0  PREREQUISITES & SAFETY
--------------------------------------------------------------------------- */

-- 0a. Pause the ADF triggers / Medallion pipelines so the SPs are NOT running
--     concurrently with the cleanup (avoids lock contention + watermark races).

-- 0b. Create an on-demand restore point / backup in the Azure portal BEFORE
--     any destructive operation. HA is off — this is your only safety net.

-- 0c. Know your sizes & headroom.
SELECT t AS table_name,
       pg_size_pretty(pg_relation_size(t))                                                  AS heap_main,
       pg_size_pretty(pg_indexes_size(t))                                                   AS indexes,
       pg_size_pretty(pg_total_relation_size(t) - pg_relation_size(t) - pg_indexes_size(t)) AS toast_approx,
       pg_size_pretty(pg_total_relation_size(t))                                            AS total
FROM (VALUES ('fact.deviceevent'::regclass), ('fact.userbehaviour'::regclass)) v(t);
-- STAGE observed: deviceevent  = 80 GB heap + 49 GB idx + ~98 GB TOAST = 227 GB total
--                 userbehaviour = 30 GB heap + 21 GB idx + ~0  TOAST   =  51 GB total

-- 0d. Session tuning for the maintenance window (16 GB RAM, sole workload).
SET work_mem             = '512MB';   -- keeps per-location ROW_NUMBER sorts in memory
SET maintenance_work_mem = '2GB';     -- speeds VACUUM and index builds


DROP INDEX IF EXISTS fact.deviceeventuidx;

-- Then build the new one:
SET maintenance_work_mem             = '2GB';
SET max_parallel_maintenance_workers = 3;


/* ---------------------------------------------------------------------------
   STEP 1  MEASURE  (baseline delete counts to verify against later)
--------------------------------------------------------------------------- */

-- 1a. deviceevent duplicate profile
SELECT COUNT(*) AS duplicate_key_sets, SUM(cnt-1) AS rows_to_delete, MAX(cnt) AS worst_case_copies
FROM (SELECT COUNT(*) cnt FROM fact.deviceevent
      GROUP BY locationid, eventtoken, datacategory, actiontype, eventinstant
      HAVING COUNT(*) > 1) d;

-- 1b. userbehaviour duplicate profile (for the record; we won't dedup in-place)
SELECT COUNT(*) AS duplicate_key_sets, SUM(cnt-1) AS rows_to_delete, MAX(cnt) AS worst_case_copies
FROM (SELECT COUNT(*) cnt FROM fact.userbehaviour
      GROUP BY locationid, ordersessionidentifier, eventcategory, eventtype, eventinstant
      HAVING COUNT(*) > 1) d;

-- 1c. Confirm userbehaviour row count (pre-truncate baseline)
SELECT COUNT(*) AS userbehaviour_total FROM fact.userbehaviour;

-- 1d. (optional) Heaviest deviceevent locations (anticipate per-batch time)
SELECT locationid, COUNT(*) rows_in_location
FROM fact.deviceevent GROUP BY locationid ORDER BY 2 DESC LIMIT 20;


/* ---------------------------------------------------------------------------
   STEP 2  TRUNCATE fact.userbehaviour  (frees ~51 GB immediately)
   This MUST come before the deviceevent dedup so that the freed space is
   available for the deviceevent unique index build in STEP 6.
   userbehaviour will be rebuilt from the clean deviceevent in STEP 7.
--------------------------------------------------------------------------- */

-- Safety: record the watermark so we can write it back after the rebuild.
SELECT ts, source
FROM fact.watermarktable
WHERE watermarktablename = 'fact.userbehaviour';
-- Save this value ↑ (e.g. v_saved_ub_watermark). You'll need it in STEP 7.

-- Optional: back up to a side table if you want a rollback path beyond the
-- Azure restore point. Skip if disk is very tight — this costs another 51 GB.
-- CREATE TABLE fact.userbehaviour_bkp AS SELECT * FROM fact.userbehaviour;

--TRUNCATE TABLE fact.userbehaviour;

-- Confirm space is actually freed:
SELECT pg_size_pretty(pg_total_relation_size('fact.userbehaviour'));  -- should be ~0 bytes

-- Reset the sequence (the rebuild in STEP 7 will use it)
-- Check current max id first in case you kept the backup:
ALTER SEQUENCE fact.userbehaviour_id_seq RESTART WITH 1;


/* ---------------------------------------------------------------------------
   STEP 3  NORMALIZE deviceevent KEY COLUMN  (must happen BEFORE dedup)
   Mirror the SP's 3-way COALESCE so no empty/NULL eventtoken survives.
--------------------------------------------------------------------------- */

UPDATE fact.deviceevent
SET eventtoken    = COALESCE(NULLIF(eventtoken,''), NULLIF(deviceid,''), syscosmosticks::text),
    sysupdatetime = now()::timestamp
WHERE eventtoken IS NULL OR eventtoken = '';
-- Expected: small count (was ~1,335 in test)

-- Verify:
SELECT COUNT(*) FROM fact.deviceevent WHERE eventtoken IS NULL OR eventtoken = ''; --3,641 --3m:31s
-- Must return 0

SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan AS times_used,
       idx_tup_read AS rows_read_from_index,
       idx_tup_fetch AS rows_fetched_from_table
FROM pg_stat_user_indexes
WHERE relname = 'deviceevent'
ORDER BY idx_scan DESC;

VACUUM (VERBOSE, ANALYZE) fact.deviceevent;

/* ---------------------------------------------------------------------------
   STEP 4  DEDUP fact.deviceevent  (in-place, batched per location)

   CRITICAL INDEX AWARENESS:
   The only usable index for row filtering is deviceeventidx (companyid, locationid).
   There is NO index leading on locationid alone. So the loop MUST filter by
   (companyid, locationid) to get an index scan; filtering by locationid only
   would seq-scan 80 GB per iteration × 769 locations = ~61 TB of I/O.

   The location list comes from dim.organizationlocation (small dim table, instant)
   rather than SELECT DISTINCT from the 180M-row fact table (which itself would
   be a full seq scan).

   ROW_NUMBER() keeps ONE row per natural key (latest by syscosmosts/ticks/ctid).
   Each location is its own COMMIT -> bounded WAL, crash-safe, autovacuum-friendly.
   Idempotent: rerun deletes 0 from already-clean locations.

   STAGE distribution (769 locations, 180M rows):
     Top:    6.4M rows (loc-x4pw1awq97)
     Median: 42K rows
     >1M:    39 locations
     <1K:    207 locations
   The 6.4M location is the heaviest single batch — at 512MB work_mem the
   ROW_NUMBER sort should stay in memory (6.4M × ~120 bytes ≈ 730 MB, borderline;
   bump to 1GB if EXPLAIN shows a disk sort).
--------------------------------------------------------------------------- */

SELECT DISTINCT organizationid, locationid FROM dim.organizationlocation WHERE organizationtype = 0;

--DROP TABLE IF EXISTS fact.deviceevent_org_loc;
CREATE TABLE IF NOT EXISTS fact.deviceevent_org_loc(
    companyid      TEXT,
    locationid     TEXT,
    rowcount       INTEGER,
    sysinserttime  TIMESTAMP DEFAULT NOW() :: TIMESTAMP
);

SELECT * FROM fact.userbehaviour ORDER BY id DESC LIMIT 100;
--loc-704c0f96-3b03-414d-a620-be6e12fde2be
SELECT * FROM fact.deviceevent_org_loc 
WHERE locationid = 'loc-57b8ac62-9c05-46d2-b270-8cc26c5e5bbe';

CREATE OR REPLACE PROCEDURE fact.usp_dedup_deviceevent_by_location()
LANGUAGE plpgsql
AS $BODY$
DECLARE
    r_loc     record;
    v_deleted bigint;
    v_total   bigint := 0;
    v_count   int    := 0;
    v_locs    int;
    v_start   timestamptz;
BEGIN
    v_start := clock_timestamp();

    -- Count for progress reporting
    SELECT COUNT(*)
    INTO v_locs
    FROM fact.deviceevent_org_loc;

    FOR r_loc IN
        SELECT DISTINCT companyid, locationid, rowcount
        FROM fact.deviceevent_org_loc
        --WHERE rowcount < 160291
        ORDER BY rowcount DESC
    LOOP
        v_count := v_count + 1;

        WITH ranked AS (
            SELECT companyid, locationid, ctid,
                   row_number() OVER (
                       PARTITION BY locationid, eventtoken, datacategory, actiontype, eventinstant
                       ORDER BY syscosmosts DESC NULLS LAST,
                                syscosmosticks DESC NULLS LAST,
                                ctid DESC
                   ) AS rn
            FROM   fact.deviceevent
            WHERE  companyid  = r_loc.companyid      -- ← index scan on
              AND  locationid = r_loc.locationid      --   deviceeventidx(companyid, locationid)
        )
        DELETE FROM fact.deviceevent t
        USING  ranked r
        WHERE  t.companyid  = r.companyid
          AND  t.locationid = r.locationid
          AND  t.ctid       = r.ctid 
          AND  r.rn > 1;

        GET DIAGNOSTICS v_deleted = ROW_COUNT;
        v_total := v_total + v_deleted;
        COMMIT;
        RAISE NOTICE '[%] [%/%] loc % -> deleted % (running total %)',
                     clock_timestamp() - v_start,
                     v_count, v_locs,
                     r_loc.locationid, v_deleted, v_total;
    END LOOP;

    RAISE NOTICE 'DONE fact.deviceevent -> removed % duplicate rows across % locations in %',
                 v_total, v_count, clock_timestamp() - v_start;
END;
$BODY$;

ALTER PROCEDURE fact.usp_dedup_deviceevent_by_location() OWNER TO citus;

SET work_mem = '1GB';

SHOW work_mem;
-- Run (top-level, autocommit ON):
CALL fact.usp_dedup_deviceevent_by_location();


/* ---------------------------------------------------------------------------
   STEP 5  VACUUM & STATS on deviceevent
   Regular VACUUM marks dead space reusable (does NOT shrink files on disk,
   but prevents the table from growing further during the rebuild below).
--------------------------------------------------------------------------- */
VACUUM (VERBOSE, ANALYZE) fact.deviceevent;


/* ---------------------------------------------------------------------------
   STEP 6  UNIQUE INDEX on fact.deviceevent
   Pipelines are paused -> nothing is writing -> plain (non-CONCURRENT) build
   is faster: parallel workers + large maintenance_work_mem both apply.
   The ~51 GB freed by STEP 2's TRUNCATE provides the disk headroom.
--------------------------------------------------------------------------- */
SET maintenance_work_mem             = '2GB';
SET max_parallel_maintenance_workers = 3;  -- 4 vCores -> 3 parallel workers

ALTER SEQUENCE fact.userbehaviour_id_seq RESTART WITH 1;

SET work_mem = '1GB';

SHOW work_mem;

CREATE OR REPLACE PROCEDURE fact.usp_rebuild_userbehaviour_by_location()
LANGUAGE plpgsql AS $BODY$
DECLARE
    r_loc      record;
    v_inserted bigint;
    v_total    bigint := 0;
    v_count    int    := 0;
    v_locs     int;
    v_start    timestamptz;
BEGIN
    v_start := clock_timestamp();

    SELECT COUNT(*) INTO v_locs FROM fact.deviceevent_org_loc;

    -- one-time truncate, committed before the loop begins
    --TRUNCATE TABLE --fact.userbehaviour;
    --COMMIT;

    FOR r_loc IN
        SELECT companyid, locationid, rowcount
        FROM fact.deviceevent_org_loc
        --WHERE rowcount < 895595
        ORDER BY rowcount DESC
    LOOP
        v_count := v_count + 1;

        -- idempotent: clears any partial rows from a prior crashed run on this location
        --DELETE FROM --fact.userbehaviour WHERE locationid = r_loc.locationid;

        WITH parsed AS (
            SELECT
                de.locationid,
                de.eventtoken                                                                  AS ordersessionidentifier,
                de.datacategory                                                                 AS eventcategory,
                de.eventinstant,
                de.actiontype                                                                   AS eventtype,
                de.syscosmosts,
                de.syscosmosticks,
                de.deviceid                                                                     AS source_deviceid,
                fact.parse_iso_timestamp(de.eventinstant) :: TIMESTAMP                          AS busdate,
                REPLACE(REPLACE(SUBSTRING(de.eventinstant, 1, 13), '-', ''), 'T', '')::INTEGER  AS dateid,
                --de.eventdata,
                -- *** plug in your already-validated safe_jsonb parsing CTE here ***
                NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)->>'view'), '')                        AS viewname,
                COALESCE(NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)->>'element'), ''), 'None')    AS elementname,
                COALESCE(NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)->>'elementId'), ''), 'None')  AS sourceelementid,
                NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)->>'itemSessionId'), '')                AS itemsessionidentifier,
                NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)->>'quantity'), '')::INTEGER            AS quantity,
                de.sysinserttime
            FROM fact.deviceevent de
            WHERE de.companyid  = r_loc.companyid
              AND de.locationid = r_loc.locationid
              AND de.datacategory IN ('insight','Order','StoreTiming','BusinessHours','Session')
        ),
        enriched AS (
            SELECT
                p.*,
                --th.ordertype,
                --th.kioskid       AS th_deviceid,
                v.viewid         AS viewidentifier,
                el.elementid     AS elementidentifier
            FROM parsed p
            /*LEFT JOIN fact.transactionheader th
                   ON  th.locationid    = p.locationid
                  AND th.ordersessionid = p.ordersessionidentifier
                  AND th.orderstatus    = 'order-placed'*/
            LEFT JOIN dim.view v
                   ON v.viewname = p.viewname
            LEFT JOIN dim.element el
                   ON  el.sourceelementid = p.sourceelementid
                  AND el.elementname     = p.elementname
        )
        INSERT INTO fact.userbehaviour (
            id, busdate, locationid, dateid, daypart, /*ordertype,*/ eventtype,
            ordersessionidentifier, itemsessionidentifier, elementidentifier,
            viewidentifier, quantity, createddate, syscosmosts, eventinstant,
            eventcategory, deviceid, syscosmosticks, --eventdata,
            viewname, elementname, sourceelementid, sysupdatetime
        )
        SELECT
            nextval('fact.userbehaviour_id_seq'),
            busdate, locationid, dateid, 'None', /*ordertype,*/ eventtype,
            ordersessionidentifier, itemsessionidentifier, elementidentifier,
            viewidentifier, quantity, sysinserttime, syscosmosts, eventinstant,
            eventcategory, source_deviceid, syscosmosticks, --eventdata,
            viewname, elementname, sourceelementid, NOW()::timestamp
        FROM enriched;

        GET DIAGNOSTICS v_inserted = ROW_COUNT;
        v_total := v_total + v_inserted;
        COMMIT;
        RAISE NOTICE '[%] [%/%] loc % -> inserted % (running total %)',
                     clock_timestamp() - v_start, v_count, v_locs,
                     r_loc.locationid, v_inserted, v_total;
    END LOOP;

    RAISE NOTICE 'DONE fact.userbehaviour rebuild -> % rows across % locations in %',
                 v_total, v_count, clock_timestamp() - v_start;
END;
$BODY$;

ALTER PROCEDURE fact.usp_rebuild_userbehaviour_by_location() OWNER TO citus;

SET work_mem = '4GB';
SET max_parallel_maintenance_workers = 6;  -- 4 vCores -> 3 parallel workers

SHOW work_mem;
-- Run (top-level, autocommit ON):
CALL fact.usp_rebuild_userbehaviour_by_location();


/* ---------------------------------------------------------------------------
   STEP 7  REBUILD fact.userbehaviour FROM CLEAN deviceevent
   Sources from fact.deviceevent (already deduped + indexed) with the same
   filter and enrichment joins as usp_silver_kiosk_events_to_fact_userbehaviour.
   DISTINCT ON is a safety net but shouldn't find duplicates at this point.
--------------------------------------------------------------------------- */

INSERT INTO fact.userbehaviour (
    id,
    busdate,
    locationid,
    dateid,
    daypart,
    ordertype,
    eventtype,
    ordersessionidentifier,
    viewidentifier,
    itemsessionidentifier,
    elementidentifier,
    quantity,
    createddate,
    syscosmosts,
    eventinstant,
    eventcategory,
    deviceid,
    syscosmosticks
)
WITH source_events AS (
    SELECT DISTINCT ON (
        de.locationid, de.eventtoken, de.datacategory, de.actiontype, de.eventinstant
    )
        de.locationid,
        de.eventtoken                                                         AS ordersessionidentifier,
        de.datacategory                                                       AS eventcategory,
        de.eventinstant,
        de.actiontype                                                         AS eventtype,
        de.eventdata,
        de.deviceid,
        de.syscosmosts,
        de.syscosmosticks
    FROM fact.deviceevent AS de
    WHERE de.moduleid     = 'kiosk'
      AND de.datacategory IN ('insight', 'Order', 'StoreTiming', 'BusinessHours', 'Session')
      AND de.eventdata IS NOT NULL
      AND de.eventdata <> ''
    ORDER BY de.locationid, de.eventtoken, de.datacategory, de.actiontype, de.eventinstant,
             de.syscosmosts DESC NULLS LAST, de.syscosmosticks DESC NULLS LAST
),
parsed AS (
    SELECT
        se.locationid,
        se.ordersessionidentifier,
        se.eventcategory,
        se.eventinstant,
        se.eventtype,
        se.syscosmosts,
        se.syscosmosticks,
        se.deviceid,
        fact.parse_iso_timestamp(se.eventinstant)                                               AS busdate,
        REPLACE(REPLACE(SUBSTRING(se.eventinstant, 1, 13), '-', ''), 'T', '')::INTEGER          AS dateid,
        NULLIF(TRIM(fact.safe_conversion_to_jsonb(se.eventdata)::jsonb->>'view'),         '')   AS view_name,
        COALESCE(NULLIF(TRIM(fact.safe_conversion_to_jsonb(se.eventdata)::jsonb->>'element'),   ''), 'None') AS element_name,
        COALESCE(NULLIF(TRIM(fact.safe_conversion_to_jsonb(se.eventdata)::jsonb->>'elementId'), ''), 'None') AS source_element_id,
        NULLIF(TRIM(fact.safe_conversion_to_jsonb(se.eventdata)::jsonb->>'quantity'),     '')::INTEGER AS quantity,
        NULLIF(TRIM(fact.safe_conversion_to_jsonb(se.eventdata)::jsonb->>'itemSessionId'), '')         AS itemsessionidentifier
    FROM source_events AS se
),
enriched AS (
    SELECT
        pe.locationid,
        pe.ordersessionidentifier,
        pe.eventcategory,
        pe.eventinstant,
        pe.eventtype,
        pe.syscosmosts,
        pe.syscosmosticks,
        pe.busdate,
        pe.dateid,
        pe.itemsessionidentifier,
        pe.quantity,
        ot.id                AS ordertype,
        dv.viewid            AS viewidentifier,
        de.elementid         AS elementidentifier,
        'None'::TEXT         AS daypart,
        NOW()::TIMESTAMP     AS createddate,
        pe.deviceid
    FROM parsed AS pe
    LEFT JOIN (
        SELECT locationid, ordersessionid, kioskid,
               CASE WHEN ordertype = '' OR ordertype IS NULL
                    THEN order_type_label
                    ELSE ordertype END AS ordertypeid
        FROM stg.silver_transaction_header
    ) AS st
        ON  st.locationid     = pe.locationid
        AND st.ordersessionid = pe.ordersessionidentifier
    LEFT JOIN dim.ordertype AS ot
        ON  ot.locationid  = st.locationid
        AND ot.kioskid     = st.kioskid
        AND ot.ordertypeid = st.ordertypeid
    LEFT JOIN dim.view AS dv
        ON  dv.viewname = pe.view_name
    LEFT JOIN dim.element AS de
        ON  de.elementname     = pe.element_name
        AND de.sourceelementid = pe.source_element_id
)
SELECT
    nextval('fact.userbehaviour_id_seq'),
    busdate::TIMESTAMP,
    locationid,
    dateid,
    daypart,
    ordertype,
    eventtype,
    ordersessionidentifier,
    viewidentifier,
    itemsessionidentifier,
    elementidentifier,
    quantity,
    createddate,
    syscosmosts,
    eventinstant,
    eventcategory,
    deviceid,
    syscosmosticks
FROM enriched;

-- Verify row count (should be close to the pre-truncate total minus duplicates):
SELECT COUNT(*) AS userbehaviour_rebuilt FROM fact.userbehaviour;
-- Expected ≈ (STEP 1c total) - (STEP 1b rows_to_delete)
-- Some small variance is okay (the enrichment WHERE filters null/empty eventdata).


-- Restore the watermark (saved in STEP 2) so incremental loads resume correctly.
-- Replace <SAVED_WATERMARK> with the value you recorded:
UPDATE fact.watermarktable
SET ts            = <SAVED_WATERMARK>,
    sysupdatetime = NOW()::TIMESTAMP
WHERE watermarktablename = 'fact.userbehaviour'
  AND source             = 'gem';


/* ---------------------------------------------------------------------------
   STEP 9  POST-CLEANUP
--------------------------------------------------------------------------- */
-- 9a. Re-run duplicate checks — both must return 0:
SELECT COUNT(*) FROM (
    SELECT 1 FROM fact.deviceevent
    GROUP BY locationid, eventtoken, datacategory, actiontype, eventinstant
    HAVING COUNT(*) > 1) d;

SELECT COUNT(*) FROM (
    SELECT 1 FROM fact.userbehaviour
    GROUP BY locationid, ordersessionidentifier, eventcategory, eventtype, eventinstant
    HAVING COUNT(*) > 1) d;

-- 9b. Compare table sizes to pre-cleanup (STEP 0c) — userbehaviour should be
--     dramatically smaller (no bloat); deviceevent heap stays same but has
--     reusable dead space inside.
SELECT t AS table_name,
       pg_size_pretty(pg_relation_size(t))       AS heap_main,
       pg_size_pretty(pg_indexes_size(t))        AS indexes,
       pg_size_pretty(pg_total_relation_size(t)) AS total
FROM (VALUES ('fact.deviceevent'::regclass), ('fact.userbehaviour'::regclass)) v(t);

-- 9c. Re-enable the ADF triggers / Medallion pipelines.

-- 9d. Trigger ONE incremental load and confirm it completes in seconds, not minutes.
--     Check the watermarks advanced correctly:
SELECT * FROM fact.watermarktable
WHERE watermarktablename IN ('fact.deviceevent', 'fact.userbehaviour');

-- 9e. (Optional) Now that ux_userbehaviour_nk exists, consider switching the
--     userbehaviour SP from NOT EXISTS to ON CONFLICT DO NOTHING — same atomic
--     dedup pattern deviceevent already uses.

-- 9f. Drop the backup table once you're confident (if created in STEP 2):
-- DROP TABLE IF EXISTS fact.userbehaviour_bkp;

-- 9g. Drop the dedup procedure (one-time use):
-- DROP PROCEDURE IF EXISTS fact.usp_dedup_deviceevent_by_location();


/* ===========================================================================
   APPENDIX — what NOT to copy from the test/reg scratchpad at this scale

   1. The self-join "EXISTS strictly-better-row" DELETE: quadratic inside each
      duplicate group. The userbehaviour ~187k-copy group alone would be
      ~3.5×10^10 comparisons. Use the ROW_NUMBER approach in STEP 4.

   2. UPDATE fact.userbehaviour SET id = ROW_NUMBER() OVER(...) over the whole
      table: rewrites all 170M rows -> massive dead-tuple backlog.
      Skip entirely — the rebuild in STEP 7 assigns fresh sequence ids.

   3. In-place dedup of userbehaviour: unnecessary when deviceevent is already
      clean — TRUNCATE + rebuild is faster, bloat-free, and simpler.

   4. The 2-way eventtoken backfill (COALESCE(NULLIF(eventtoken,''), deviceid)):
      doesn't match the SP's 3-way COALESCE. Use STEP 3's 3-way version so
      nothing is left un-deduped.
=========================================================================== */