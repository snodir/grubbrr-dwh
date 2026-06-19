SELECT * FROM stg.silver_kiosk_events LIMIT 100;

SELECT *, ctid FROM fact.deviceevent WHERE syscosmosts IS NOT NULL ORDER BY syscosmosts DESC LIMIT 100;

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


DELETE FROM fact.deviceevent --7,530,035 SELECT COUNT(*)
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

UPDATE fact.deviceevent
SET eventtoken = COALESCE(NULLIF(eventtoken, ''), deviceid)   -- ← DISTINCT ON key
WHERE eventtoken IS NULL OR eventtoken = '';
-- 1,335 rows

-- Confirm clean
SELECT COUNT(*) FROM fact.deviceevent WHERE eventtoken IS NULL OR eventtoken = '';
-- Must return 0



CREATE UNIQUE INDEX CONCURRENTLY uq_deviceevent_natkey_idx --DROP INDEX IF EXISTS
    ON fact.deviceevent
    (locationid, eventtoken, datacategory, actiontype, eventinstant); --47seconds for 6,413,074 rows

ALTER TABLE fact.deviceevent
    ADD CONSTRAINT uq_deviceevent_natural_key
    UNIQUE USING INDEX uq_deviceevent_natkey_idx;







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

ALTER TABLE IF EXISTS fact.userbehaviour
ADD COLUMN IF NOT EXISTS deviceid TEXT,
ADD COLUMN IF NOT EXISTS syscosmosticks BIGINT;

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