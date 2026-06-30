/* ============================================================================
   DEDUP RUNBOOK — fact.deviceevent (~200M) & fact.userbehaviour (~170M)
   Target: Azure Cosmos DB for PostgreSQL (Citus), 4 vCore / 16 GB coordinator (post scale-up)
   Goal:   remove duplicates -> create the unique index -> incremental loads
           drop from 15-20 min back to seconds.

   Run order: STEP 0 -> 6. Run on STAGE first, capture timings, then PROD.
   Run each STEP with autocommit ON and NOT inside an outer BEGIN block
   (the dedup procedure issues its own COMMITs).

   Natural keys (must match the SPs exactly):
     fact.deviceevent     : locationid, eventtoken, datacategory, actiontype, eventinstant
     fact.userbehaviour   : locationid, ordersessionidentifier, eventcategory, eventtype, eventinstant
   Tie-break (which copy to KEEP): latest by syscosmosts, then syscosmosticks, then ctid.
============================================================================ */


/* ---------------------------------------------------------------------------
   STEP 0  PREREQUISITES & SAFETY  (HA is disabled + disk at 82% = be careful)
--------------------------------------------------------------------------- */

-- 0a. Pause the ADF triggers / Medallion pipelines so the SPs are NOT running
--     concurrently with the dedup (avoids lock contention + watermark races).

-- 0b. Create an on-demand restore point / backup in the Azure portal BEFORE
--     any DELETE. This is destructive and HA is off.

SELECT phase, tuples_done, tuples_total,
       round(100.0 * blocks_done / NULLIF(blocks_total, 0), 1) AS pct
FROM pg_stat_progress_create_index;

DROP INDEX IF EXISTS deviceeventuidx;
DROP INDEX IF EXISTS ux_deviceevent_nk;

-- Then build the new one:
SET maintenance_work_mem             = '2GB';
SET max_parallel_maintenance_workers = 3;

ALTER TABLE IF EXISTS fact.deviceevent --Total execution time: 00:00:56.279  R=Total execution time: 00:00:15.928
ADD CONSTRAINT locationid_eventtoken_datacategory_actiontype_eventinstant_unq UNIQUE (locationid, eventtoken, datacategory, actiontype, eventinstant)

--SELECT stats_reset FROM pg_stat_database WHERE datname = current_database();


-- 0c. Confirm these ARE distributed on locationid (plan assumes it).
SELECT table_name, citus_table_type, distribution_column
FROM   citus_tables
WHERE  table_name::text IN ('fact.deviceevent', 'fact.userbehaviour');

SELECT COUNT(*) FROM fact.deviceevent;   -- S=180,073,590, TimeTaken=03m:31s
SELECT COUNT(*) FROM fact.userbehaviour; -- S=159,156,684, TimeTaken=01m:18s

SELECT locationid, COUNT(*) AS rowcount_by_location
FROM fact.deviceevent
GROUP BY locationid
ORDER BY rowcount_by_location DESC;      -- S=769 locations, TimeTaken=03m:31s

SELECT companyid, locationid, COUNT(*) AS rowcount_by_location
FROM fact.deviceevent
GROUP BY companyid, locationid
ORDER BY rowcount_by_location DESC;      -- S=769 locations, TimeTaken=03m:32s

SELECT 'fact.deviceevent' AS table_name,
    pg_size_pretty(pg_relation_size('fact.deviceevent')) AS table_only,
    pg_size_pretty(pg_indexes_size('fact.deviceevent')) AS indexes,
    pg_size_pretty(pg_total_relation_size('fact.deviceevent')) AS total_with_indexes
UNION ALL
SELECT 'fact.userbehaviour' AS table_name,
    pg_size_pretty(pg_relation_size('fact.userbehaviour')) AS table_only,
    pg_size_pretty(pg_indexes_size('fact.userbehaviour')) AS indexes,
    pg_size_pretty(pg_total_relation_size('fact.userbehaviour')) AS total_with_indexes;
--table_name         table_only    indexes     total_with_indexes
--fact.deviceevent   80 GB	        49 GB	    227 GB
--fact.userbehaviour 30 GB	        21 GB	    51 GB
--============================================================================

-- Expect distribution_column = locationid. If they are local/reference tables,
-- the plan below still works (deletes just aren't "router" queries).

-- 0d. Know your sizes & headroom (decides Method A vs Method B in STEP 3).
SELECT 'fact.deviceevent'   AS tbl, pg_size_pretty(citus_total_relation_size('fact.deviceevent'))
UNION ALL
SELECT 'fact.userbehaviour',        pg_size_pretty(citus_total_relation_size('fact.userbehaviour'));

-- 0e. Session tuning for the maintenance window (you now have 16 GB RAM).
--     Run these in each session that executes the dedup / vacuum / index steps.
--     Session-level SET is allowed on Cosmos DB for PostgreSQL; values are
--     generous because pipelines are paused and this is the only heavy workload.
SET work_mem             = '512MB';  -- keeps the per-location ROW_NUMBER sorts in memory (STEP 3)
SET maintenance_work_mem = '2GB';    -- speeds VACUUM (STEP 4) and the index build (STEP 5)


/* ---------------------------------------------------------------------------
   STEP 1  MEASURE  (don't go in blind — gives expected delete counts to verify against)
--------------------------------------------------------------------------- */

-- 1a. deviceevent: duplicate sets / rows to delete / worst group size
SELECT COUNT(*) AS duplicate_key_sets, 
    SUM(cnt-1) AS rows_to_delete, 
    MAX(cnt) AS worst_case_copies
FROM (SELECT COUNT(*) cnt FROM fact.deviceevent
      GROUP BY locationid, eventtoken, datacategory, actiontype, eventinstant
      HAVING COUNT(*) > 1) d;

-- 1b. userbehaviour: same (expect a very large worst_case_copies from the old watermark bug)
SELECT COUNT(*) AS duplicate_key_sets, SUM(cnt-1) AS rows_to_delete, MAX(cnt) AS worst_case_copies
FROM (SELECT COUNT(*) cnt FROM fact.userbehaviour
      GROUP BY locationid, ordersessionidentifier, eventcategory, eventtype, eventinstant
      HAVING COUNT(*) > 1) d;

-- 1c. (optional) heaviest locations, so you can eyeball the biggest batches
SELECT locationid, COUNT(*) rows_in_location
FROM fact.userbehaviour GROUP BY locationid ORDER BY 2 DESC LIMIT 20;


/* ---------------------------------------------------------------------------
   STEP 2  NORMALIZE THE KEY COLUMNS  (must happen BEFORE dedup)
   Mirror the SP's 3-way COALESCE so no empty/NULL key survives. These are
   bounded by the empty-count (small), but they create dead tuples -> VACUUM after.
--------------------------------------------------------------------------- */

UPDATE fact.deviceevent
SET eventtoken    = COALESCE(NULLIF(eventtoken,''), NULLIF(deviceid,''), syscosmosticks::text),
    sysupdatetime = now()::timestamp
WHERE eventtoken IS NULL OR eventtoken = '';

UPDATE fact.userbehaviour
SET ordersessionidentifier = COALESCE(NULLIF(ordersessionidentifier,''), NULLIF(deviceid,''),
                                      NULLIF(syscosmosticks::text,''), id::text),
    sysupdatetime          = now()::timestamp
WHERE ordersessionidentifier IS NULL OR ordersessionidentifier = '';

-- Verify zero empties before continuing:
SELECT COUNT(*) FROM fact.deviceevent   WHERE eventtoken IS NULL OR eventtoken = '';                          -- must be 0
SELECT COUNT(*) FROM fact.userbehaviour WHERE ordersessionidentifier IS NULL OR ordersessionidentifier = ''; -- must be 0


/* ---------------------------------------------------------------------------
   STEP 3  DEDUP — Method A (recommended at 82% disk: in-place, batched per shard)
   ROW_NUMBER() keeps ONE row per key (latest), scoped per locationid so each
   DELETE is a single-shard router query and each location is its own COMMIT.
   Idempotent: a rerun deletes 0 from already-clean locations.
--------------------------------------------------------------------------- */

CREATE OR REPLACE PROCEDURE fact.usp_dedup_by_location(
    p_table        regclass,
    p_partition_by text,    -- NK columns after locationid, e.g. 'eventtoken, datacategory, actiontype, eventinstant'
    p_order_by     text DEFAULT 'syscosmosts DESC NULLS LAST, syscosmosticks DESC NULLS LAST, ctid DESC'
)
LANGUAGE plpgsql
AS $proc$
DECLARE
    r_loc     record;
    v_deleted bigint;
    v_total   bigint := 0;
BEGIN
    FOR r_loc IN EXECUTE format('SELECT DISTINCT locationid FROM %s ORDER BY locationid', p_table)
    LOOP
        EXECUTE format($q$
            WITH ranked AS (
                SELECT ctid,
                       row_number() OVER (PARTITION BY locationid, %s ORDER BY %s) AS rn
                FROM   %s
                WHERE  locationid = %L
            )
            DELETE FROM %s t USING ranked r
            WHERE t.ctid = r.ctid AND r.rn > 1
        $q$, p_partition_by, p_order_by, p_table, r_loc.locationid, p_table);

        GET DIAGNOSTICS v_deleted = ROW_COUNT;
        v_total := v_total + v_deleted;
        COMMIT;   -- bounded, shard-local transaction per location
        RAISE NOTICE 'loc % -> deleted % (running total %)', r_loc.locationid, v_deleted, v_total;
    END LOOP;
    RAISE NOTICE 'DONE %  -> removed % rows', p_table, v_total;
END;
$proc$;

-- Run (these CALLs must be top-level, autocommit on):
CALL fact.usp_dedup_by_location('fact.deviceevent',   'eventtoken, datacategory, actiontype, eventinstant');
CALL fact.usp_dedup_by_location('fact.userbehaviour', 'ordersessionidentifier, eventcategory, eventtype, eventinstant');

-- The total reported by each CALL must equal rows_to_delete from STEP 1.
-- If any single location is huge, add a dateid sub-loop inside the procedure
-- (PARTITION key is unchanged; you just add "AND dateid BETWEEN ..." to the WHERE).


/* ---------------------------------------------------------------------------
   STEP 4  RECLAIM & REFRESH STATS  (VACUUM cannot run inside the procedure)
   Regular VACUUM marks space reusable for the ongoing ETL (stops further growth);
   it does NOT shrink files. Avoid VACUUM FULL on prod at 82% disk (needs a full
   2nd copy + exclusive lock). If you need real shrink, scale storage instead.
--------------------------------------------------------------------------- */
VACUUM (ANALYZE) fact.deviceevent;
VACUUM (ANALYZE) fact.userbehaviour;


/* ---------------------------------------------------------------------------
   STEP 5  CREATE THE UNIQUE INDEX  (the actual fix for the 15-20 min loads)
   Pipelines are paused (STEP 0a) -> nothing is writing -> a plain (non-CONCURRENT)
   build is the faster choice on 4 vCore / 16 GB: it can use parallel maintenance
   workers + a large maintenance_work_mem, both of which CONCURRENTLY disables.
   The SHARE lock it takes only blocks writes (there are none right now); SELECTs
   still work. Verify dup-count is 0 (STEP 1) before running.
--------------------------------------------------------------------------- */
SET maintenance_work_mem            = '2GB';   -- (also set in 0e; harmless if repeated)
SET max_parallel_maintenance_workers = 3;      -- 4 vCores -> allow parallel build


-- FALLBACK — only if you must build while pipelines are LIVE. No long write-lock,
-- but single-threaded and slower (cannot combine with the parallel settings above):
--   CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS ux_deviceevent_nk   ON fact.deviceevent   (...);
--   CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS ux_userbehaviour_nk ON fact.userbehaviour (...);
--   (a failed CONCURRENTLY build leaves an INVALID index: DROP INDEX CONCURRENTLY ux_...; then retry)


/* ---------------------------------------------------------------------------
   STEP 6  POST
--------------------------------------------------------------------------- */
-- 6a. (optional) Now that the unique index exists, you CAN switch the
--     userbehaviour SP from NOT EXISTS to ON CONFLICT DO NOTHING for atomic,
--     race-free cross-run dedup — same pattern deviceevent already uses.
--     If you keep NOT EXISTS, it's now fast anyway (index lookups).
-- 6b. Re-enable the ADF triggers / pipelines.
-- 6c. Re-run STEP 1 — both queries must now return 0 duplicate_key_sets.
-- 6d. Trigger one incremental load and confirm it's back to seconds, not minutes.


/* ===========================================================================
   APPENDIX A — Method B (faster, cleaner, but needs ~table-size free disk)
   If you scale Cosmos DB storage up first (online, cheap, and you're at 82%
   anyway), this is much faster than per-row DELETE and leaves zero bloat,
   because dedup becomes a single sequential DISTINCT ON pass and the unique
   index is built fresh on load.

     CREATE TABLE fact.deviceevent_new (LIKE fact.deviceevent INCLUDING DEFAULTS);
     SELECT create_distributed_table('fact.deviceevent_new', 'locationid');  -- match dist col
     INSERT INTO fact.deviceevent_new
       SELECT DISTINCT ON (locationid, eventtoken, datacategory, actiontype, eventinstant) *
       FROM   fact.deviceevent
       ORDER  BY locationid, eventtoken, datacategory, actiontype, eventinstant,
                 syscosmosts DESC NULLS LAST, syscosmosticks DESC NULLS LAST;
     -- build ux_..._nk + all other indexes on _new, then swap in one short txn:
     BEGIN;
       ALTER TABLE fact.deviceevent     RENAME TO fact.deviceevent_old;
       ALTER TABLE fact.deviceevent_new RENAME TO fact.deviceevent;
     COMMIT;
     -- re-point any dependent views/SPs, validate, then DROP fact.deviceevent_old.
   Watch out for: sequence ownership, dependent views/SPs, FKs, and that you
   recreate EVERY index that existed on the original.
=========================================================================== */


/* ===========================================================================
   APPENDIX B — what NOT to copy from the test/reg scratchpad at this scale
   1. The self-join "EXISTS strictly-better-row" DELETE: quadratic inside each
      duplicate group -> dies on the ~187k-copy userbehaviour key. Use STEP 3.
   2. UPDATE fact.userbehaviour SET id = ROW_NUMBER() OVER(...) over the whole
      table: rewrites all 170M rows. Skip — ids come from the sequence in prod.
   3. The 2-way eventtoken backfill: use the 3-way COALESCE in STEP 2 so nothing
      is left un-deduped (that's the source of the "8 rows" discrepancy).
=========================================================================== */

-- Table: fact.deviceevent

-- DROP TABLE IF EXISTS fact.deviceevent;

-- Table: fact.deviceevent

-- DROP TABLE IF EXISTS fact.deviceevent;

CREATE TABLE IF NOT EXISTS fact.deviceevent
(
    application text COLLATE pg_catalog."default" NOT NULL,
    companyid text COLLATE pg_catalog."default" NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    moduleid text COLLATE pg_catalog."default",
    datacategory text COLLATE pg_catalog."default",
    actiontype text COLLATE pg_catalog."default",
    severity text COLLATE pg_catalog."default",
    eventtoken text COLLATE pg_catalog."default",
    eventinstant text COLLATE pg_catalog."default",
    dateid integer,
    username text COLLATE pg_catalog."default",
    userid text COLLATE pg_catalog."default",
    deviceid text COLLATE pg_catalog."default",
    devicename text COLLATE pg_catalog."default",
    summary text COLLATE pg_catalog."default",
    eventdata text COLLATE pg_catalog."default",
    syscosmosticks bigint,
    sysinserttime timestamp without time zone,
    syscosmosts bigint,
    sysupdatetime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.deviceevent
    OWNER to citus;

-- Index: deviceeventidx

-- DROP INDEX IF EXISTS fact.deviceeventidx;

CREATE INDEX IF NOT EXISTS deviceeventidx
    ON fact.deviceevent USING btree
    (companyid COLLATE pg_catalog."default" ASC NULLS LAST, locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: deviceeventuidx

-- DROP INDEX IF EXISTS fact.deviceeventuidx;

CREATE INDEX IF NOT EXISTS deviceeventuidx
    ON fact.deviceevent USING btree
    (application COLLATE pg_catalog."default" ASC NULLS LAST, companyid COLLATE pg_catalog."default" ASC NULLS LAST, locationid COLLATE pg_catalog."default" ASC NULLS LAST, moduleid COLLATE pg_catalog."default" ASC NULLS LAST, eventtoken COLLATE pg_catalog."default" ASC NULLS LAST, datacategory COLLATE pg_catalog."default" ASC NULLS LAST, actiontype COLLATE pg_catalog."default" ASC NULLS LAST, eventinstant COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: ix_deviceevent_journey_lookup

-- DROP INDEX IF EXISTS fact.ix_deviceevent_journey_lookup;

CREATE INDEX IF NOT EXISTS ix_deviceevent_journey_lookup
    ON fact.deviceevent USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST, datacategory COLLATE pg_catalog."default" ASC NULLS LAST, eventtoken COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default
    WHERE datacategory = 'insight'::text AND (actiontype = ANY (ARRAY['CategorySelected'::text, 'SubCategorySelected'::text, 'RegularItemSelected'::text, 'ItemRemoved'::text, 'ModifierGroupSelected'::text, 'ModifierSelected'::text, 'ModifierUnselected'::text]));
-- Index: ix_deviceevent_syscosmosts_brin

-- DROP INDEX IF EXISTS fact.ix_deviceevent_syscosmosts_brin;

CREATE INDEX IF NOT EXISTS ix_deviceevent_syscosmosts_brin
    ON fact.deviceevent USING brin
    (syscosmosts)
    WITH (pages_per_range=128)
    TABLESPACE pg_default;



-- Table: fact.userbehaviour

-- DROP TABLE IF EXISTS fact.userbehaviour;

CREATE TABLE IF NOT EXISTS fact.userbehaviour
(
    id bigserial NOT NULL,
    busdate timestamp without time zone,
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    daypart text COLLATE pg_catalog."default",
    ordertype bigint,
    eventtype text COLLATE pg_catalog."default",
    ordersessionidentifier text COLLATE pg_catalog."default",
    viewidentifier integer,
    itemsessionidentifier text COLLATE pg_catalog."default",
    elementidentifier integer,
    quantity integer,
    createddate timestamp without time zone,
    syscosmosts bigint,
    eventinstant text COLLATE pg_catalog."default",
    eventcategory text COLLATE pg_catalog."default",
    sysupdatetime timestamp without time zone,
    deviceid text COLLATE pg_catalog."default",
    syscosmosticks bigint,
    eventdata text COLLATE pg_catalog."default",
    CONSTRAINT userbehaviour_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.userbehaviour
    OWNER to citus;

-- Index: ix_userbehaviour_syscosmosts_brin

-- DROP INDEX IF EXISTS fact.ix_userbehaviour_syscosmosts_brin;

CREATE INDEX IF NOT EXISTS ix_userbehaviour_syscosmosts_brin
    ON fact.userbehaviour USING brin
    (syscosmosts)
    WITH (pages_per_range=128)
    TABLESPACE pg_default;
-- Index: userbehaviour_locationid_dateid_idx

-- DROP INDEX IF EXISTS fact.userbehaviour_locationid_dateid_idx;

CREATE INDEX IF NOT EXISTS userbehaviour_locationid_dateid_idx
    ON fact.userbehaviour USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier)
    TABLESPACE pg_default;