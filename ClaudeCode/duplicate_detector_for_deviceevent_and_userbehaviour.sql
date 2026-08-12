SELECT * FROM stg.silver_kiosk_events LIMIT 100;

SELECT *, ctid FROM fact.deviceevent WHERE syscosmosts IS NOT NULL ORDER BY syscosmosts DESC LIMIT 100;
SELECT *, ctid FROM fact.userbehaviour /*WHERE syscosmosts IS NOT NULL*/ ORDER BY id DESC LIMIT 100;

SELECT * FROM fact.deviceevent_org_loc 
WHERE locationid = 'loc-57b8ac62-9c05-46d2-b270-8cc26c5e5bbe';

ALTER TABLE IF EXISTS fact.deviceevent
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

DROP INDEX IF EXISTS deviceeventuidx;
DROP INDEX IF EXISTS ux_deviceevent_nk;

-- Then build the new one:
SET maintenance_work_mem             = '2GB';
SET max_parallel_maintenance_workers = 3;

/*
Started executing query at Line 16
ALTER TABLE--fact.deviceevent
Total execution time: 00:13:51.441

Started executing query at Line 27
ALTER TABLE--fact.userbehaviour
Total execution time: 00:02:54.701
*/

SET maintenance_work_mem = '4GB';        -- this IS the right knob here — index build, not row-scan
SET max_parallel_maintenance_workers = 6; -- lets the btree build sort in parallel
--SET statement_timeout = 0;                -- don't let this get killed mid-build
--SET lock_timeout = '5s';                  -- fail fast if something else is holding a conflicting lock, rather than queuing indefinitely and blocking everyone behind it

ALTER TABLE IF EXISTS fact.deviceevent --Total execution time: 00:00:56.279  R=Total execution time: 00:00:15.928
ADD CONSTRAINT locationid_eventtoken_datacategory_actiontype_eventinstant_unq UNIQUE (locationid, eventtoken, datacategory, actiontype, eventinstant)

/* Production--fact.deviceevent
Started executing query at Line 31
ALTER TABLE
Total execution time: 00:14:13.354
*/


ALTER TABLE IF EXISTS fact.userbehaviour --Total execution time: 00:00:05.004
ADD CONSTRAINT locationid_eventtoken_eventcategory_eventtype_eventinstant_unq UNIQUE (locationid, ordersessionidentifier, eventcategory, eventtype, eventinstant)

/* Production--fact.userbehaviour
Started executing query at Line 44
ALTER TABLE
Total execution time: 00:02:18.037
*/

-- Index: userbehaviour_locationid_dateid_idx

-- DROP INDEX IF EXISTS fact.userbehaviour_locationid_dateid_idx;

CREATE INDEX IF NOT EXISTS userbehaviour_locationid_dateid_idx
    ON fact.userbehaviour USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier)
    TABLESPACE pg_default;

/* Production--fact.userbehaviour/index
Started executing query at Line 57
CREATE INDEX
Total execution time: 00:01:33.674
*/


ALTER TABLE IF EXISTS fact.userbehaviour
ADD COLUMN IF NOT EXISTS deviceid        TEXT,
ADD COLUMN IF NOT EXISTS syscosmosticks  BIGINT,
ADD COLUMN IF NOT EXISTS eventdata       TEXT,
ADD COLUMN IF NOT EXISTS viewname        TEXT,
ADD COLUMN IF NOT EXISTS elementname     TEXT,
ADD COLUMN IF NOT EXISTS sourceelementid TEXT;

ALTER TABLE IF EXISTS fact.userbehaviour
DROP COLUMN IF EXISTS eventdata,
DROP COLUMN IF EXISTS viewname,
DROP COLUMN IF EXISTS elementname,
DROP COLUMN IF EXISTS sourceelementid;


VACUUM (VERBOSE, ANALYZE) fact.userbehaviour;
--VACUUM (VERBOSE, ANALYZE, PARALLEL 4) fact.userbehaviour;
VACUUM (INDEX_CLEANUP OFF) fact.userbehaviour;
VACUUM (FREEZE) fact.userbehaviour;

--TRUNCATE TABLE fact.userbehaviour;

SELECT *--max(id), count(*) --DISTINCT de.datacategory, de.actiontype S=36,875,506--after 1June--36,334,104, maxid=36,714,158, count=36,714,158 (after id re-alignment on 2026-07-04)
FROM fact.userbehaviour as ub --_reload --5,707,284***252,036---R=2,236,236***163,019---S=159,156,684/159,331,487--Total execution time: 00:01:17.866
WHERE 1=1 --P=211,468,927	211,515,235, Total execution time: 00:01:09.713
--AND eventcategory IN ('insight','Order','StoreTiming','BusinessHours','Session') 
--AND viewidentifier IS NOT NULL
--AND elementidentifier IS NOT NULL
--AND syscosmosticks IS NOT NULL
--AND deviceid = ''
ORDER BY id --DESC
LIMIT 1000;

--2026-07-06 05:09:53.780262 max_createddate/sysinserttime StageGAS

--P=262,118,533***52,795,667 ('insight','Order','StoreTiming','BusinessHours','Session')--2026-07-16
--Total execution time: 00:02:34.478
--no empty eventtoken, no NULL eventtoken
--missing deviceid = 81,491,987
SELECT *--count(*) --*--DISTINCT de.datacategory, de.actiontype
FROM fact.deviceevent as de --T=6,413,074  ***1,036,943  ---R=2,725,650***473,077---S=178,165,004***36,334,104
WHERE 1=1                   --P=237,271,369***47,776,614, --Total execution time: 00:04:20.802***Total execution time: 00:04:21.329
--AND de.moduleid     = 'kiosk'---S=36,334,104--Total execution time: 00:03:29.938
--AND de.datacategory IN ('insight','Order','StoreTiming','BusinessHours','Session') --S=36,334,104--Total execution time: 00:01:04.870
--AND (de.eventtoken = '' OR de.eventtoken IS NULL) --R=228,727, S=0 rows after de-dup--Total execution time: 00:01:08.533
--AND (de.deviceid = '' OR de.deviceid IS NULL) --R=2,069,735---UPDATE 2,069,735---Total execution time: 00:01:22.617, empty/missing deviceids
AND de.deviceid <> '' 
--AND de.devicename LIKE 'ksk-%'
--AND (de.eventdata LIKE '%"view"%' OR de.eventdata LIKE '%"element"%' OR de.eventdata LIKE '%"elementId"%')
LIMIT 10;



UPDATE fact.deviceevent
SET deviceid = CASE WHEN devicename LIKE 'ksk-%' THEN devicename ELSE deviceid END
WHERE deviceid = ''
  AND devicename LIKE 'ksk-%'; --P=UPDATE 81,456,411; Total execution time: 00:25:26.259

UPDATE fact.deviceevent
SET eventtoken = COALESCE(NULLIF(eventtoken, ''), NULLIF(deviceid, ''), syscosmosticks :: TEXT),   -- ← DISTINCT ON key
    sysupdatetime = NOW() :: TIMESTAMP
WHERE eventtoken IS NULL OR eventtoken = '';
-- 1,335 rows

UPDATE fact.userbehaviour
SET id            = new_id, --T=UPDATE 1,059,149, Total execution time: 00:00:47.145
    sysupdatetime = NOW() :: TIMESTAMP --P=
FROM (SELECT *, ROW_NUMBER() OVER(ORDER BY id) as new_id
      FROM fact.userbehaviour) AS ub --WHERE id > 36334104 37,255,560, UPDATE 380,054, --TotExT: 26.487s
WHERE userbehaviour.id = ub.id;


SELECT 
FROM fact.userbehaviour
GROUP BY createddate 

WITH dupl_records AS (
SELECT locationid, coalesce(eventtoken, deviceid, syscosmosticks::TEXT) as eventtoken, datacategory, actiontype, eventinstant, -- syscosmosticks
    COUNT(*) as dupl_count
FROM fact.deviceevent
GROUP BY locationid, coalesce(eventtoken, deviceid, syscosmosticks::TEXT), datacategory, actiontype, eventinstant--, syscosmosticks
HAVING COUNT(*) > 1
)
SELECT locationid, 
    coalesce(de.eventtoken, de.syscosmosticks::TEXT, de.deviceid) as eventtoken, 
    datacategory, 
    actiontype, 
    eventinstant, 
    COUNT(*) OVER(PARTITION BY locationid, coalesce(de.eventtoken, de.deviceid, de.syscosmosticks::TEXT), datacategory, actiontype, eventinstant) as dupl_count --syscosmosticks, 
FROM fact.deviceevent as de
WHERE EXISTS (SELECT 1 FROM dupl_records as dr 
              WHERE dr.locationid   = de.locationid
                AND dr.eventtoken   = coalesce(de.eventtoken, de.deviceid, de.syscosmosticks::TEXT) 
                AND dr.datacategory = de.datacategory
                AND dr.actiontype   = de.actiontype
                AND dr.eventinstant = de.eventinstant)
ORDER BY locationid, eventtoken, datacategory, actiontype, eventinstant, dupl_count DESC
LIMIT 100

SELECT *
FROM fact.deviceevent
WHERE syscosmosts > 1779001410
ORDER BY syscosmosts DESC
LIMIT 100


-- How many duplicate sets and how many extra rows?
SELECT
    COUNT(*)                    AS duplicate_key_sets,
    SUM(cnt - 1)                AS rows_to_delete,
    MAX(cnt)                    AS worst_case_copies
FROM (
    SELECT COUNT(*) AS cnt
    FROM fact.deviceevent
    GROUP BY locationid, eventtoken, datacategory, actiontype, eventinstant
    HAVING COUNT(*) > 1
) dups;
--duplicate_key_sets    rows_to_delete  worst_case_copies
--433,658	            1,116,961	    206
--53,091	            92,684	        37
-- Sample the duplicates to understand what's different between copies

SELECT
    locationid,
    eventtoken,
    datacategory,
    actiontype,
    eventinstant,
    syscosmosts,
    syscosmosticks,
    sysinserttime,
    COUNT(*) OVER (
        PARTITION BY locationid, eventtoken, datacategory, actiontype, eventinstant
    ) AS copies
FROM fact.deviceevent
WHERE (locationid, eventtoken, datacategory, actiontype, eventinstant) IN (
    SELECT locationid, eventtoken, datacategory, actiontype, eventinstant
    FROM fact.deviceevent
    GROUP BY locationid, eventtoken, datacategory, actiontype, eventinstant
    HAVING COUNT(*) > 1
)
ORDER BY locationid, eventtoken, datacategory, actiontype, eventinstant, sysinserttime
LIMIT 100;


--DELETE FROM fact.deviceevent --7,530,035 SELECT COUNT(*) --R=92,684--took 51 seconds
WHERE EXISTS (--1,116,953 rows deleted from 7,530,035 record table, however rows_to_delete was 1,116,961
    SELECT 1
    FROM fact.deviceevent b
    WHERE b.locationid   = fact.deviceevent.locationid
      AND b.eventtoken   = fact.deviceevent.eventtoken
      AND b.datacategory = fact.deviceevent.datacategory
      AND b.actiontype   = fact.deviceevent.actiontype
      AND b.eventinstant = fact.deviceevent.eventinstant
      AND (
            -- b is strictly better than the current row
            b.syscosmosts > fact.deviceevent.syscosmosts
            OR (    b.syscosmosts      IS NOT DISTINCT FROM fact.deviceevent.syscosmosts
                AND b.syscosmosticks   >  fact.deviceevent.syscosmosticks)
            OR (    b.syscosmosts      IS NOT DISTINCT FROM fact.deviceevent.syscosmosts
                AND b.syscosmosticks   IS NOT DISTINCT FROM fact.deviceevent.syscosmosticks
                AND b.ctid             >  fact.deviceevent.ctid)  -- tiebreaker for Type C NULLs
      )
)
--LIMIT 100;


SELECT * FROM fact.deviceevent --DELETE 8 rows got deleted
WHERE eventtoken IS NULL
  AND ctid NOT IN (
        SELECT DISTINCT ON (locationid, datacategory, actiontype, eventinstant)
            ctid
        FROM fact.deviceevent
        WHERE eventtoken IS NULL
        ORDER BY
            locationid, datacategory, actiontype, eventinstant,
            syscosmosts    DESC NULLS LAST,
            syscosmosticks DESC NULLS LAST
  );


-- Should return zero rows
SELECT COUNT(*)
FROM fact.deviceevent
WHERE 1=1                 --6,413,074
  --AND eventtoken IS NULL  --1,335
  AND deviceid   IS NULL; --no simultaneous NUL eventtoken and deviceid, but standalone NULL deviceid exists - 36 rows


-- Confirm clean
SELECT COUNT(*) FROM fact.deviceevent WHERE eventtoken IS NULL OR eventtoken = '';
-- Must return 0

--fact.userbehaviour

/*
INSERT 0 1,036,943
Total execution time: 00:01:33.442

Reg env:
INSERT 0 473,077
Total execution time: 00:00:23.637
*/
    WITH parsed_events AS (
        SELECT
            fact.parse_iso_timestamp(de.eventinstant)                                AS busdate,
            de.locationid                                                            AS locationid,
            REPLACE(REPLACE(SUBSTRING(de.eventinstant, 1, 13), '-', ''), 'T', '')
                ::INTEGER                                                            AS dateid,
            'None'                                                                   AS daypart,
            de.actiontype                                                            AS eventtype,
            de.eventtoken                                                            AS ordersessionidentifier,
            -- Parse once; all field extractions below reuse this column
            fact.safe_conversion_to_jsonb(de.eventdata)                              AS eventdata_json,
            NOW()::TIMESTAMP                                                         AS createddate,
            de.syscosmosts,
            de.eventinstant,
            de.datacategory                                                          AS eventcategory,
            de.deviceid,
            de.syscosmosticks,
            de.eventdata                                                             AS eventdata
        FROM fact.deviceevent AS de
        WHERE de.datacategory IN ('insight', 'Order', 'StoreTiming', 'BusinessHours', 'Session')

    ),
    extracted AS (

        SELECT
            busdate,
            locationid,
            dateid,
            daypart,
            eventtype,
            ordersessionidentifier,
            --NULLIF(TRIM(eventdata_json->>'view'),         '')                      AS view_name,
            --COALESCE(NULLIF(TRIM(eventdata_json->>'element'),   ''), 'None')       AS element_name,
            --COALESCE(NULLIF(TRIM(eventdata_json->>'elementId'), ''), 'None')       AS source_element_id,
            NULLIF(TRIM(eventdata_json->>'itemSessionId'), '')                       AS itemsessionidentifier,
            NULLIF(TRIM(eventdata_json->>'quantity'), '')::INTEGER                   AS quantity,
            createddate,
            syscosmosts,
            eventinstant,
            eventcategory,
            deviceid,
            syscosmosticks,
            eventdata
        FROM parsed_events

    )
    INSERT INTO fact.userbehaviour (
        id,
        busdate,
        locationid,
        dateid,
        daypart,
        eventtype,
        ordersessionidentifier,
        itemsessionidentifier,
        quantity,
        createddate,
        syscosmosts,
        eventinstant,
        eventcategory,
        deviceid,
        syscosmosticks,
        eventdata
    )
    SELECT
        ROW_NUMBER() OVER (ORDER BY syscosmosticks)  AS id,
        busdate::TIMESTAMP,
        locationid,
        dateid,
        daypart,
        eventtype,
        ordersessionidentifier,
        itemsessionidentifier,
        quantity,
        createddate,
        syscosmosts,
        eventinstant,
        eventcategory,
        deviceid,
        syscosmosticks,
        eventdata
    FROM extracted;





UPDATE fact.userbehaviour
SET deviceid = de.deviceid,
    sysupdatetime = NOW() :: TIMESTAMP
FROM fact.deviceevent as de
WHERE userbehaviour.locationid             = de.locationid
  AND userbehaviour.ordersessionidentifier = de.eventtoken
  AND userbehaviour.eventcategory          = de.datacategory
  AND userbehaviour.eventtype              = de.actiontype
  AND userbehaviour.eventinstant           = de.eventinstant
  AND userbehaviour.deviceid               = ''


SELECT * FROM dim.view ORDER BY viewid DESC;
SELECT * FROM dim.element /*WHERE sourceelementid = '' OR sourceelementid IS NULL*/ ORDER BY elementid DESC; --0 rows

    
    DROP TABLE IF EXISTS tmp_view;
    CREATE TEMP TABLE tmp_view AS --SELECT 286,181 Total execution time: 00:00:28.129
    SELECT DISTINCT
        NULLIF(TRIM(eventdata::jsonb->>'view'), '') AS viewname
    FROM (SELECT fact.safe_conversion_to_jsonb(eventdata) as eventdata FROM fact.userbehaviour /*WHERE dim.is_valid_jsonb(eventdata)*/) as ub
    WHERE NULLIF(TRIM(eventdata::jsonb->>'view'), '') IS NOT NULL;

    CREATE INDEX ix_tmp_view ON tmp_view (viewname);
    ANALYZE tmp_view;

    SELECT * FROM tmp_view LIMIT 1000;

    --TRUNCATE TABLE dim.view;
    INSERT INTO dim.view (viewid, viewname, sysinserttime)
    SELECT
        ROW_NUMBER() OVER(ORDER BY t.viewname) as new_id, -- nextval('dim.view_id_seq'),
        t.viewname,
        NOW()::TIMESTAMP as sysinserttime
    FROM tmp_view t
    WHERE NOT EXISTS (
        SELECT 1
        FROM dim.view v
        WHERE v.viewname = t.viewname
    );


WITH ub AS (
    SELECT id, 
        fact.safe_conversion_to_jsonb(eventdata) as eventdata,
        TRIM(fact.safe_conversion_to_jsonb(eventdata)::jsonb->>'view') as viewname
    FROM fact.userbehaviour
    WHERE fact.safe_conversion_to_jsonb(eventdata) IS NOT NULL 
      AND NULLIF(TRIM(fact.safe_conversion_to_jsonb(eventdata)::jsonb->>'view'), '') IS NOT NULL
), ub_view AS (
    SELECT ub.*, v.viewid
    FROM ub 
    INNER JOIN dim.view as v 
            ON v.viewname = ub.viewname
)
UPDATE fact.userbehaviour
SET viewidentifier = ub.viewid, --UPDATE 625,314, Total execution time: 00:01:19.169 --R=UPDATE 312,645, Total execution time: 00:00:25.319
    sysupdatetime = NOW() :: TIMESTAMP
FROM ub_view as ub
WHERE userbehaviour.id = ub.id;


WITH ub AS (
    SELECT id, 
        fact.safe_conversion_to_jsonb(eventdata) as eventdata,
        TRIM(fact.safe_conversion_to_jsonb(eventdata)::jsonb->>'element') as elementname,
        TRIM(fact.safe_conversion_to_jsonb(eventdata)::jsonb->>'elementId') as sourceelementid
    FROM fact.userbehaviour
    WHERE fact.safe_conversion_to_jsonb(eventdata) IS NOT NULL 
      AND NULLIF(TRIM(fact.safe_conversion_to_jsonb(eventdata)::jsonb->>'element'), '')   IS NOT NULL
      AND NULLIF(TRIM(fact.safe_conversion_to_jsonb(eventdata)::jsonb->>'elementId'), '') IS NOT NULL
), ub_element AS (
    SELECT ub.*, e.elementid
    FROM ub 
    INNER JOIN dim.element as e
            ON e.sourceelementid = ub.sourceelementid
           AND e.elementname     = ub.elementname
)
UPDATE fact.userbehaviour
SET elementidentifier = ub.elementid, --UPDATE 211,534, Total execution time: 00:00:51.772, --R=UPDATE 113,866, Total execution time: 00:00:13.915
    sysupdatetime = NOW() :: TIMESTAMP
FROM ub_element as ub
WHERE userbehaviour.id = ub.id;

UPDATE fact.userbehaviour
SET ordertype     = th.ordertype,   --UPDATE 548,850, Total execution time: 00:00:41.540, R=UPDATE 198,042, Total execution time: 00:00:04.868
    sysupdatetime = NOW() :: TIMESTAMP
FROM fact.transactionheader as th
WHERE userbehaviour.locationid             = th.locationid
  AND userbehaviour.ordersessionidentifier = th.ordersessionid;


--639165814406676069	1,780,984,640
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT DISTINCT ON (
    ske.locationid, ske.token, ske.eventcategory,
    ske.eventtype, ske.eventinstant
)
    ske.syscosmosts
FROM stg.silver_kiosk_events AS ske
WHERE ske.syscosmosts > 1779001410  -- substitute your current watermark
  AND NOT EXISTS (
        SELECT 1 FROM fact.deviceevent AS de
        WHERE de.locationid   = ske.locationid
          AND de.eventtoken   = ske.token
          AND de.datacategory = ske.eventcategory
          AND de.actiontype   = ske.eventtype
          AND de.eventinstant = ske.eventinstant
      );

--SELECT MAX(syscosmosts) FROM stg.silver_kiosk_events --1,780,984,799
SELECT to_timestamp(1779001410), to_timestamp(2000000000)









-- Scale check
SELECT
    COUNT(*)        AS duplicate_key_sets,
    SUM(cnt - 1)    AS rows_to_delete,
    MAX(cnt)        AS worst_case_copies
FROM (
    SELECT COUNT(*) AS cnt
    FROM fact.userbehaviour
    GROUP BY locationid, ordersessionidentifier, eventcategory, eventtype, eventinstant
    HAVING COUNT(*) > 1
) dups;

--duplicate_key_sets    rows_to_delete  worst_case_copies
--244,056	            3,513,961	    186,967


-- NULL/empty ordersessionidentifier check
SELECT COUNT(*) FROM fact.userbehaviour --5,707,284
WHERE NULLIF(TRIM(ordersessionidentifier), '') IS NULL; --6,684


WITH dupl_records AS (
SELECT locationid, COALESCE(NULLIF(ordersessionidentifier, ''), NULLIF(deviceid, ''), syscosmosticks :: TEXT) as ordersessionidentifier, eventcategory, eventtype, eventinstant, -- syscosmosticks
    COUNT(*) as dupl_count
FROM fact.userbehaviour
GROUP BY locationid, COALESCE(NULLIF(ordersessionidentifier, ''), NULLIF(deviceid, ''), syscosmosticks :: TEXT), eventcategory, eventtype, eventinstant--, syscosmosticks
HAVING COUNT(*) > 1
)
SELECT count(*) --234,898
/*  locationid, 
    COALESCE(NULLIF(ordersessionidentifier, ''), NULLIF(deviceid, ''), syscosmosticks :: TEXT) as ordersessionidentifier, 
    eventcategory, 
    eventtype, 
    eventinstant, 
    COUNT(*) OVER(PARTITION BY locationid, COALESCE(NULLIF(ordersessionidentifier, ''), NULLIF(deviceid, ''), syscosmosticks :: TEXT), eventcategory, eventtype, eventinstant) as dupl_count --syscosmosticks, 
*/
FROM fact.userbehaviour as ub
WHERE EXISTS (SELECT 1 FROM dupl_records as dr 
              WHERE dr.locationid             = ub.locationid
                AND dr.ordersessionidentifier = COALESCE(NULLIF(ub.ordersessionidentifier, ''), NULLIF(ub.deviceid, ''), ub.syscosmosticks :: TEXT) 
                AND dr.eventcategory          = ub.eventcategory
                AND dr.eventtype              = ub.eventtype
                AND dr.eventinstant           = ub.eventinstant)
ORDER BY locationid, ordersessionidentifier, eventcategory, eventtype, eventinstant, dupl_count DESC
LIMIT 100

SELECT count(*) FROM fact.deviceevent WHERE moduleid = 'kiosk' AND datacategory = 'insight'



UPDATE fact.userbehaviour
SET deviceid       = de.deviceid,
    syscosmosticks = de.syscosmosticks
FROM fact.deviceevent as de 
WHERE userbehaviour.locationid             = de.locationid
  AND userbehaviour.ordersessionidentifier = de.eventtoken
  AND userbehaviour.eventcategory          = de.datacategory
  AND userbehaviour.eventtype              = de.actiontype
  AND userbehaviour.eventinstant           = de.eventinstant



/*
Started executing query at Line 210
UPDATE 1118336
Total execution time: 00:00:29.450
*/

UPDATE fact.userbehaviour
SET ordersessionidentifier = COALESCE(NULLIF(ordersessionidentifier, ''), deviceid)   -- ← DISTINCT ON key
WHERE ordersessionidentifier IS NULL OR ordersessionidentifier = '';
-- 1,335 rows

-- Confirm clean
SELECT COUNT(*) FROM fact.userbehaviour WHERE ordersessionidentifier IS NULL OR ordersessionidentifier = ''; --6,684
-- Must return 0


SELECT COUNT(*) FROM fact.userbehaviour --7,530,035 SELECT COUNT(*)
WHERE EXISTS (--1,116,953 rows deleted from 7,530,035 record table, however rows_to_delete was 1,116,961
    SELECT 1
    FROM fact.userbehaviour ub
    WHERE ub.locationid             = fact.userbehaviour.locationid
      AND ub.ordersessionidentifier = fact.userbehaviour.ordersessionidentifier
      AND ub.eventcategory          = fact.userbehaviour.eventcategory
      AND ub.eventtype              = fact.userbehaviour.eventtype
      AND ub.eventinstant           = fact.userbehaviour.eventinstant
      AND (
            -- b is strictly better than the current row
            ub.syscosmosts > fact.userbehaviour.syscosmosts
            OR (    ub.syscosmosts      IS NOT DISTINCT FROM fact.userbehaviour.syscosmosts
                AND ub.syscosmosticks   >  fact.userbehaviour.syscosmosticks)
            OR (    ub.syscosmosts      IS NOT DISTINCT FROM fact.userbehaviour.syscosmosts
                AND ub.syscosmosticks   IS NOT DISTINCT FROM fact.userbehaviour.syscosmosticks
                AND ub.ctid             >  fact.userbehaviour.ctid)  -- tiebreaker for Type C NULLs
      )
)

-- Table: fact.userbehaviour

-- DROP TABLE IF EXISTS fact.userbehaviour;

CREATE TABLE IF NOT EXISTS fact.userbehaviour_bkp
(
    id bigint NOT NULL,-- DEFAULT nextval('fact.userbehaviour_id_seq'::regclass),
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
    syscosmosticks bigint
    --CONSTRAINT userbehaviour_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.userbehaviour_bkp
    OWNER to citus;


--INSERT INTO fact.userbehaviour_bkp 
SELECT * FROM fact.userbehaviour;


/*
BusinessHours	StoreClosed
BusinessHours	StoreOpened
insight	
insight	AcceptanceOfAlcoholicAgeBySelf
insight	AcceptanceOfAlcoholicAgeByStaff
insight	AcceptGuards
insight	AcceptGuardsClicked
insight	AddAsIsClicked
insight	Addasisselected
insight	AddAsIsSelected
insight	AddComboAsIsSelected
insight	AddCustomTipClicked
insight	AddFromLast5
insight	AddItemSelected
insight	AddressSuggestionSelected
insight	AddTipClicked
insight	AddToBag
insight	AddToCart
insight	AddToCartClicked
insight	AppySelected
insight	BackAutoReward
insight	BackspaceClicked
insight	BillingDataCollected
insight	BillingFormSubmitted
insight	CancelAlcoholicAgeVerificationByStaff
insight	CancelAlcoholicOrderTypeSwitch
insight	CancelCharity
insight	CancellingOrder
insight	Cancelorder
insight	CancelOrder
insight	CancelRefund
insight	CancelSignInClicked
insight	CartPreviewBackClicked
insight	CartPreviewComboClicked
insight	CartPreviewItemClicked
insight	CartPreviewNextClicked
insight	Categoryselected
insight	CategorySelected
insight	CategoryTabSelected
insight	ChangePrimaryModifierClicked
insight	CheckoutClicked
insight	ClearClicked
insight	click
insight	CloseAlcoholWarningModal
insight	CloseAutoReward
insight	CloseClicked
insight	CloseComboModifierPopup
insight	CloseCustomizeComboSelected
insight	CloseCustomizeItemSelected
insight	CloseDialog
insight	CloseFreeItemSelected
insight	CloseMenuAvailabilityModal
insight	CloseSubtotalZeroWithReward
insight	ComboComponentChoiceGroupingClicked
insight	ComboComponentItemSelected
insight	ComboComponentNavClicked
insight	ComboComponentSelected
insight	ComboCustomizeClicked
insight	ComboItemSelected
insight	ComboModifierPopupDone
insight	ComboSizeSelected
insight	ConcessionaireSelected
insight	ConfirmAlcoholicOrderTypeSwitch
insight	ConfirmCancelClicked
insight	ContinueCharity
insight	ContinueClicked
insight	ContinueOrder
insight	CoverageOptionClicked
insight	CreateAccountSelected
insight	Customernameentered
insight	CustomerNameEntered
insight	Customerphoneentered
insight	CustomerPhoneEntered
insight	CustomizeClicked
insight	CustomizeComboSelected
insight	Customizeitemselected
insight	CustomizeItemSelected
insight	CustomTipClicked
insight	DeclineClicked
insight	DiscountApplied
insight	DiscountCardClicked
insight	DiscountClicked
insight	DiscountRemoved
insight	EmailReceipt
insight	ExitClicked
insight	FeedbackForm
insight	FinishOrderClicked
insight	GotItClicked
insight	GotoPreviousView
insight	HeaderConceptSelected
insight	HeaderLogoSelected
insight	ItemAvailabilityChanged
insight	ItemCustomizeClicked
insight	ItemRemoved
insight	ItemSelected
insight	ItemSpecialRequestAdd
insight	ItemSpecialRequestClear
insight	ItemSpecialRequestOpen
insight	KeepOrdering
insight	KeypadPressed
insight	LandingAssetSelected
insight	LanguageSelected
insight	LastFiveOrdersTab
insight	LoginAttempt
insight	LoginCompleted
insight	LoyaltyButtonClicked
insight	LoyaltySignedIn
insight	LoyaltySignedOut
insight	LoyaltySignIn
insight	MainMenuSearchClicked
insight	ModalClosed
insight	ModalOpened
insight	ModifierAvailabilityChanged
insight	ModifierCodeSelected
insight	ModifierCustomizeChanged
insight	ModifierDescriptionModalClosed
insight	ModifierGroupSelected
insight	ModifierGroupViewed
insight	Modifierselected
insight	ModifierSelected
insight	Modifierunselected
insight	ModifierUnselected
insight	ModifierUpsellDeclined
insight	NextCategoryClicked
insight	NoTipSelected
insight	Ok
insight	OrderCancelled
insight	OrderPostAuth
insight	OrderRefunded
insight	OrderTypeChanged
insight	Ordertypeselected
insight	OrderTypeSelected
insight	OTPRequired
insight	OtpSignUpSelected
insight	PageViewed
insight	PayClicked
insight	PaymentMethodSelected
insight	Paymentoption
insight	PaymentOption
insight	Payment Otp Selected
insight	PaySubtotalZeroWithReward
insight	PopupCanceled
insight	PostAuthAttempted
insight	PreviousCategoryClicked
insight	PrintReceiptClicked
insight	QuantityChanged
insight	Receipt
insight	RefundAttempted
insight	Regularitemselected
insight	RegularItemSelected
insight	RemoveItemClicked
insight	RemoveOtherConceptItemsNo
insight	RemoveOtherConceptItemsYes
insight	RemoveSelectedItem
insight	RemoveSoldOutItems
insight	ResendOTP
insight	ReturnToOrderClicked
insight	ReviewOrderClicked
insight	RewardAdded
insight	RewardApplied
insight	RewardRemoved
insight	RewardsTab
insight	SelectLanguage
insight	SignedInSelected
insight	SignUpClicked
insight	SignUpSelected
insight	SkipClicked
insight	SkippedSelected
insight	SkipSelected
insight	SpecialRequestEntered
insight	SubCategorySelected
insight	SubmitClicked
insight	SubmitPhoneClicked
insight	TableTentEntered
insight	TextReceipt
insight	TipSelected
insight	ToggleDetailsClicked
insight	TryAgainClicked
insight	UpsellCategorySelected
insight	UpsellCheckout
insight	UpsellComboSelected
insight	Upselldeclined
insight	UpsellDeclined
insight	UpsellItemSelected
insight	UpsellItemUnselected
insight	UpsellViewCart
insight	ViewLast5Clicked
insight	ViewRewardsClicked
insight	VisitMenuClicked
Order	Checkoutclicked
Order	CheckoutClicked
Order	Revieworderclicked
Order	ReviewOrderClicked
Session	Started
Store Timing	Store Closed
Store Timing	Store Open
Store Timing	Store Opened
StoreTiming	StoreClosed
StoreTiming	Storeopened
StoreTiming	StoreOpened
*/