-- 1. Save watermark
SELECT ts FROM fact.watermarktable
WHERE watermarktablename = 'fact.userbehaviour' AND source = 'gem';

SELECT * FROM fact.userbehaviour ORDER BY id DESC LIMIT 100;
SELECT * FROM fact.deviceevent LIMIT 100;

SELECT * FROM dim.view    ORDER BY viewid    DESC LIMIT 1000;
SELECT * FROM dim.element ORDER BY elementid DESC LIMIT 100;

CREATE TABLE IF NOT EXISTS dim.view_test(
  viewid        INTEGER,
  viewname      TEXT,
  sysinserttime TIMESTAMP,
  sysupdatetime TIMESTAMP
);

--INSERT INTO dim.view --Imported from Test GAS
SELECT nextval('dim.view_id_seq') as viewid,
    viewname,
    sysinserttime,
    sysupdatetime
FROM dim.view_test as vt
WHERE NOT EXISTS 
    (SELECT 1 FROM dim.view as v
    WHERE v.viewname = vt.viewname)

-- 2. TRUNCATE
--TRUNCATE TABLE fact.userbehaviour;
ALTER SEQUENCE fact.userbehaviour_id_seq RESTART WITH 1;
SELECT NEXTVAL('fact.userbehaviour_id_seq');
-- 3. Run STEP 7 from the runbook (INSERT INTO...SELECT FROM fact.deviceevent)

-- 4. Unique constraint + VACUUM

-- 5. Restore watermark

-- For the INSERT...SELECT itself:
SET work_mem = '1GB';                      -- sort/hash memory for the JOINs and any ORDER BY
SET max_parallel_workers_per_gather = 3;     -- let Postgres parallelize the deviceevent scan (4 vCores)

-- Verify they took:
SHOW work_mem;
SHOW max_parallel_workers_per_gather;

ALTER TABLE IF EXISTS fact.userbehaviour
ADD COLUMN IF NOT EXISTS deviceid        TEXT,
ADD COLUMN IF NOT EXISTS syscosmosticks  BIGINT,
ADD COLUMN IF NOT EXISTS eventdata       TEXT,
ADD COLUMN IF NOT EXISTS viewname        TEXT,
ADD COLUMN IF NOT EXISTS elementname     TEXT,
ADD COLUMN IF NOT EXISTS sourceelementid TEXT;


--after UPDATE, we can get rid of additional columns in fact.userbehaviour
-- Index: userbehaviour_locationid_dateid_idx

-- DROP INDEX IF EXISTS fact.userbehaviour_locationid_dateid_idx;
--Re-create after populating table
CREATE INDEX IF NOT EXISTS userbehaviour_locationid_dateid_idx
    ON fact.userbehaviour USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier)
    TABLESPACE pg_default;

SELECT *--COUNT(*)
FROM fact.transactionheader
LIMIT 100;

UPDATE fact.userbehaviour
SET ordertype     = th.ordertype,
    deviceid      = th.kioskid,
    sysupdatetime = NOW() :: TIMESTAMP
FROM fact.transactionheader as th 
WHERE userbehaviour.locationid             = th.locationid
  AND userbehaviour.ordersessionidentifier = th.ordersessionid
  AND th.orderstatus = 'order-placed'

/*
Started executing query at Line 48
UPDATE 27,770,775
Total execution time: 01:10:37.219
*/



/* ---------------------------------------------------------------------------
   STEP 7  REBUILD fact.userbehaviour FROM CLEAN deviceevent
   
   Key differences from the SP:
     - No DISTINCT ON: deviceevent's unique constraint guarantees no dupes
     - Joins fact.transactionheader instead of stg.silver_transaction_header
       (staging table only holds current-hour data; useless for a full rebuild)
     - fact.transactionheader.ordertype already holds dim.ordertype.id,
       so the dim.ordertype join is eliminated entirely
     - No NOT EXISTS check: inserting into an empty table

   Set before running:
     SET work_mem = '1GB';
     SET max_parallel_workers_per_gather = 3;
--------------------------------------------------------------------------- */

WITH parsed AS (
    SELECT
        de.locationid,
        de.eventtoken                                                                       AS ordersessionidentifier,
        de.datacategory                                                                     AS eventcategory,
        de.eventinstant,
        de.actiontype                                                                       AS eventtype,
        de.syscosmosts,
        de.syscosmosticks,
        de.deviceid,
        fact.parse_iso_timestamp(de.eventinstant)                                           AS busdate,
        REPLACE(REPLACE(SUBSTRING(de.eventinstant, 1, 13), '-', ''), 'T', '')::INTEGER      AS dateid,
        de.eventdata                                                                         AS eventdata,
        NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)::jsonb->>'view'),         '')   AS viewname,
        COALESCE(NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)::jsonb->>'element'),   ''), 'None') AS elementname,
        COALESCE(NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)::jsonb->>'elementId'), ''), 'None') AS sourceelementid,
        NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)::jsonb->>'quantity'),     '')::INTEGER AS quantity,
        NULLIF(TRIM(fact.safe_conversion_to_jsonb(de.eventdata)::jsonb->>'itemSessionId'), '')         AS itemsessionidentifier
    FROM fact.deviceevent AS de
    WHERE de.datacategory IN ('insight', 'Order', 'StoreTiming', 'BusinessHours', 'Session')
      --AND de.eventdata    IS NOT NULL
      --AND de.eventdata <> ''
),
enriched AS (
    SELECT
        p.locationid,
        p.ordersessionidentifier,
        p.eventcategory,
        p.eventinstant,
        p.eventtype,
        p.syscosmosts,
        p.syscosmosticks,
        p.busdate,
        p.dateid,
        p.itemsessionidentifier,
        p.quantity,
        --th.ordertype,
        --dv.viewid            AS viewidentifier,
        --el.elementid         AS elementidentifier,
        'None'::TEXT         AS daypart,
        NOW()::TIMESTAMP     AS createddate,
        p.deviceid,
        p.eventdata,
        p.viewname,
        p.elementname, 
        p.sourceelementid
    FROM parsed AS p
    /*LEFT JOIN fact.transactionheader AS th
        ON  th.locationid      = p.locationid
        AND th.ordersessionid  = p.ordersessionidentifier
    LEFT JOIN dim.view AS dv
        ON  dv.viewname = p.view_name*
    LEFT JOIN dim.element AS el
        ON  el.elementname     = p.elementname
        AND el.sourceelementid = p.sourceelementid*/
)

INSERT INTO fact.userbehaviour (
    id,
    busdate,
    locationid,
    dateid,
    daypart,
    --ordertype,
    eventtype,
    ordersessionidentifier,
    --viewidentifier,
    itemsessionidentifier,
    --elementidentifier,
    quantity,
    createddate,
    syscosmosts,
    eventinstant,
    eventcategory,
    deviceid,
    syscosmosticks,
    eventdata,
    viewname,
    elementname, 
    sourceelementid
)
SELECT
    nextval('fact.userbehaviour_id_seq'),
    busdate::TIMESTAMP,
    locationid,
    dateid,
    daypart,
    --ordertype,
    eventtype,
    ordersessionidentifier,
    --viewidentifier,
    itemsessionidentifier,
    --elementidentifier,
    quantity,
    createddate,
    syscosmosts,
    eventinstant,
    eventcategory,
    deviceid,
    syscosmosticks,
    eventdata,
    viewname,
    elementname, 
    sourceelementid
FROM enriched;


SELECT sourceelementid, elementname, COUNT(*)
    --COUNT(*) OVER(PARTITION BY sourceelementid, elementname) as dupl_count
FROM dim.element
GROUP BY sourceelementid, elementname
HAVING count(*) > 1


WITH dupl_records AS (
SELECT *, --sourceelementid, elementname, COUNT(*)
  count(*) OVER(PARTITION BY sourceelementid, elementname) as dupl_count
FROM dim.element
--GROUP BY sourceelementid, elementname
--HAVING count(*) > 1
), flattened_duplicates AS (
SELECT *, ROW_NUMBER() OVER(PARTITION BY sourceelementid, elementname ORDER BY elementid) as row_num
FROM dim.element as el 
WHERE EXISTS(SELECT 1 FROM dupl_records as dr 
             WHERE el.elementid = dr.elementid)
--ORDER BY el.sourceelementid, el.elementname
)
SELECT *-- DELETE --
FROM dim.element as el 
WHERE EXISTS(SELECT 1 FROM flattened_duplicates as fd 
             WHERE fd.elementid = el.elementid
               AND fd.row_num   > 1);


UPDATE dim.element
SET elementid     = el.new_id,
    sysupdatetime = NOW() :: TIMESTAMP
FROM (SELECT *, ROW_NUMBER() OVER(ORDER BY elementid) AS new_id
      FROM dim.element) as el 
WHERE element.elementid = el.elementid;

ALTER TABLE IF EXISTS dim.element
ADD CONSTRAINT sourceelementid_elementname_unq UNIQUE (sourceelementid, elementname);


/*
Started executing query at Line 20
UPDATE 2,104,847
Total execution time: 00:00:11.230
*/


WITH dupl_records AS (
    SELECT viewname, COUNT(*)
    FROM dim.view
    GROUP BY viewname
    HAVING COUNT(*) > 1
), flattened_duplicates AS (
    SELECT *, ROW_NUMBER() OVER(ORDER BY viewid) as row_num
    FROM dim.view as v 
    WHERE EXISTS (SELECT 1 FROM dupl_records as dr 
                  WHERE dr.viewname = v.viewname)
)
SELECT * --DELETE-- 
FROM dim.view as v 
WHERE EXISTS (SELECT 1 FROM flattened_duplicates as fd
              WHERE fd.viewid  = v.viewid
                AND fd.row_num > 1);

UPDATE dim.view 
SET viewid = new_id,
    sysupdatetime = NOW() :: TIMESTAMP
FROM (SELECT *, ROW_NUMBER() OVER(ORDER BY viewid) as new_id FROM dim.view) as v
WHERE view.viewid = v.viewid;

ALTER TABLE IF EXISTS dim.view
ADD CONSTRAINT viewname_unq UNIQUE (viewname);

SELECT * FROM dim.view    ORDER BY viewid    DESC LIMIT 1000;
SELECT * FROM dim.element ORDER BY elementid DESC LIMIT 1000;

SELECT viewname, COUNT(*)
FROM dim.view
GROUP BY viewname
HAVING COUNT(*) > 1;

UPDATE fact.userbehaviour
SET viewidentifier = v.viewid,
    sysupdatetime  = NOW() :: TIMESTAMP
FROM dim.view as v
WHERE userbehaviour.viewname       = v.viewname
  AND userbehaviour.viewidentifier IS NULL;     --added some more views from Test env
/*
Started executing query at Line 73
UPDATE 23,076,364
Total execution time: 00:29:25.611
--After importing some more views from Test GAS
Started executing query at Line 282
UPDATE 3,284,184
Total execution time: 00:34:35.712
*/


UPDATE fact.userbehaviour
SET elementidentifier = el.elementid,
    sysupdatetime     = NOW() :: TIMESTAMP
FROM dim.element as el
WHERE userbehaviour.sourceelementid = el.sourceelementid
  AND userbehaviour.elementname     = el.elementname;

SELECT * FROM fact.userbehaviour
ORDER BY id DESC 
LIMIT 1000;

SELECT COUNT(*)
FROM fact.transactionheader
WHERE orderstatus = 'order-placed'
LIMIT 100;