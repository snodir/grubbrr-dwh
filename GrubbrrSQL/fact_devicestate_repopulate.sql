--CALL fact.usp_gsh_devicehealth_to_fact_devicestate();

CREATE TABLE IF NOT EXISTS fact.devicestate_bkp
(
    id bigserial NOT NULL,
    companyid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,
    deviceid text COLLATE pg_catalog."default" NOT NULL,
    dateid integer,
    state text COLLATE pg_catalog."default",
    lasteventtime timestamp without time zone NOT NULL,
    statuschangetime timestamp without time zone,
    duration numeric(10,3),
    sysinserttime timestamp without time zone,
    status text COLLATE pg_catalog."default",
    statusmessage text COLLATE pg_catalog."default",
    healthdatatype text COLLATE pg_catalog."default",
    sysupdatetime timestamp without time zone
    --CONSTRAINT devicestate_id_pkey PRIMARY KEY (id),
    --CONSTRAINT locationid_deviceid_lasteventtime_unq UNIQUE (locationid, deviceid, lasteventtime)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.devicestate_bkp
    OWNER to citus;


ALTER TABLE IF EXISTS fact.devicestate
ALTER COLUMN duration TYPE NUMERIC(10,3),
ADD COLUMN IF NOT EXISTS sysinserttime  TIMESTAMP,
ADD COLUMN IF NOT EXISTS status         TEXT,  --added on 2026-06-19 for enhanced System Health Report
ADD COLUMN IF NOT EXISTS statusmessage  TEXT,  --added on 2026-06-19 for enhanced System Health Report
ADD COLUMN IF NOT EXISTS healthdatatype TEXT,  --added on 2026-06-19 for enhanced System Health Report
ADD COLUMN IF NOT EXISTS sysupdatetime  TIMESTAMP;

ALTER TABLE IF EXISTS fact.devicestate --DROP CONSTRAINT locationid_deviceid_lasteventtime_pkey
ADD CONSTRAINT devicestate_id_pkey PRIMARY KEY (id),
ADD CONSTRAINT locationid_deviceid_lasteventtime_unq UNIQUE (locationid, deviceid, lasteventtime);


SELECT id, count(*)
FROM fact.devicestate
GROUP BY id
HAVING count(*) > 1


SELECT *,
    count(*) OVER(PARTITION BY locationid, deviceid, lasteventtime) as dupl
FROM fact.devicestate
ORDER BY dupl DESC, locationid, deviceid, lasteventtime
LIMIT 1000;

SELECT *--count(*) 
FROM fact.devicestate --606,739/after de-duplication --534,561
ORDER BY id DESC
LIMIT 10000;

-- How many duplicate sets and how many extra rows?
SELECT
    COUNT(*)                    AS duplicate_key_sets,
    SUM(cnt - 1)                AS rows_to_delete,
    MAX(cnt)                    AS worst_case_copies
FROM (
    SELECT locationid, deviceid, lasteventtime, COUNT(*) AS cnt
    FROM fact.devicestate
    GROUP BY locationid, deviceid, lasteventtime
    HAVING COUNT(*) > 1
) dups;
--duplicate_key_sets    rows_to_delete  worst_case_copies
--18,539	            72,033	        13

SELECT id, count(*) --> 1
FROM fact.devicestate
GROUP BY id 
HAVING count(*) > 1

UPDATE fact.devicestate
SET id = new_id, --UPDATE 548,119, Total execution time: 00:00:16.925
    sysupdatetime = NOW() :: TIMESTAMP
FROM (SELECT *, ROW_NUMBER() OVER(ORDER BY id) as new_id
      FROM fact.devicestate) AS ds 
WHERE devicestate.id = ds.id;

--INSERT INTO fact.devicestate_bkp --INSERT 0 534,706, Total execution time: 00:00:01.299
--SELECT * FROM fact.devicestate;

--TRUNCATE TABLE fact.devicestate;

INSERT INTO fact.devicestate (
    id,
    companyid,
    locationid,
    deviceid,
    dateid,
    state,
    lasteventtime,
    statuschangetime,
    duration,
    sysinserttime,
    status,
    statusmessage,
    healthdatatype,
    sysupdatetime
)
SELECT
    ROW_NUMBER() OVER(ORDER BY lasteventtime) as new_id,
    companyid,
    locationid,
    deviceid,
    dateid,
    state,
    lasteventtime,
    statuschangetime,
    duration,
    sysinserttime,
    status,
    statusmessage,
    healthdatatype,
    sysupdatetime
FROM fact.devicestate_bkp;

-- ── STEP 1: Dry run ────────────────────────────────────────────────────────
SELECT *
FROM fact.devicestate
WHERE ctid IN (
    SELECT ctid
    FROM (
        SELECT
            ctid,
            ROW_NUMBER() OVER (
                PARTITION BY locationid, deviceid, lasteventtime
                ORDER BY ctid  -- always unique per physical row; no column values needed
            ) AS rn
        FROM fact.devicestate
    ) dupes
    WHERE rn > 1
);

-- ── STEP 2: Sanity check ───────────────────────────────────────────────────
SELECT locationid, deviceid, lasteventtime, COUNT(*) AS cnt
FROM fact.devicestate
GROUP BY locationid, deviceid, lasteventtime
HAVING COUNT(*) > 1
ORDER BY cnt DESC;

-- ── STEP 3: Delete ─────────────────────────────────────────────────────────
DELETE FROM fact.devicestate
WHERE ctid IN (
    SELECT ctid
    FROM (
        SELECT
            ctid,
            ROW_NUMBER() OVER (
                PARTITION BY locationid, deviceid, lasteventtime
                ORDER BY ctid
            ) AS rn
        FROM fact.devicestate
    ) dupes
    WHERE rn > 1
);


SELECT *
FROM stg.fact_devicestate
ORDER BY id ASC
LIMIT 1000;

SELECT *
FROM fact.devicestate
ORDER BY id DESC
LIMIT 1000;




SELECT *
FROM dim.kiosk
WHERE devicetype <> 'kiosk'
ORDER BY id DESC

SELECT *,
    EXTRACT(EPOCH FROM (healthdatatime - statuschangetime)) / 60.0,
    count(*) OVER(PARTITION BY locationid, deviceid, ds.healthdatatime) as dupl_count
FROM stg.fact_devicestate as ds
--GROUP BY locationid, deviceid, ds.healthdatatime
--HAVING count(*) > 1
ORDER BY locationid, deviceid, ds.healthdatatime, dupl_count DESC
LIMIT 100;


SELECT locationid, deviceid, lasteventtime, count(*)
FROM fact.devicestate as ds
GROUP BY locationid, deviceid, lasteventtime
HAVING count(*) > 1
ORDER BY ds.lasteventtime DESC





--TRUNCATE TABLE fact.devicestate;
    -- ----------------------------------------------------------
    -- Step 2 — Insert qualifying rows into fact.devicestate
    -- ----------------------------------------------------------
WITH delta AS (
    SELECT DISTINCT ON (stg.locationid, stg.deviceid, stg.healthdatatime)
        stg.id,
        stg.companyid,
        stg.locationid,
        stg.deviceid,
        stg.healthdatatime                                          AS lasteventtime,
        stg.statuschangetime,
        ROUND(
            GREATEST(
                0,
                EXTRACT(EPOCH FROM (stg.healthdatatime - stg.statuschangetime)) / 60.0
            )::numeric, 3
        )                                                           AS duration,
        REPLACE(
            REPLACE(
                REPLACE(SUBSTRING(stg.healthdatatime::text, 1, 13),
                        '-', ''),
                ' ', ''),
            'T', ''
        ) :: INTEGER                                                AS dateid,
        CASE stg.status
            WHEN 'Ok'      THEN 'Up'
            WHEN 'Dormant' THEN 'Caution'
            WHEN 'Unknown' THEN 'Down'
            ELSE                'PartialUp'
        END                                                         AS state,
        stg.status,
        stg.statusmessage,
        stg.healthdatatype
    FROM  stg.fact_devicestate AS stg
    ORDER BY stg.locationid, stg.deviceid, stg.healthdatatime, stg.statuschangetime DESC
)

INSERT INTO fact.devicestate (
    id,
    companyid,
    locationid,
    deviceid,
    dateid,
    state,
    lasteventtime,
    statuschangetime,
    duration,
    status,
    statusmessage,
    healthdatatype,
    sysinserttime
)
SELECT
    NEXTVAL('fact.devicestate_id_seq') as id,
    companyid,
    locationid,
    deviceid,
    dateid,
    state,
    lasteventtime,
    statuschangetime,
    duration,
    status,
    statusmessage,
    healthdatatype,
    NOW()::timestamp
FROM delta
ON CONFLICT ON CONSTRAINT locationid_deviceid_lasteventtime_unq
DO UPDATE SET
    companyid        = EXCLUDED.companyid,
    dateid           = EXCLUDED.dateid,
    state            = EXCLUDED.state,
    statuschangetime = EXCLUDED.statuschangetime,
    duration         = EXCLUDED.duration,
    status           = EXCLUDED.status,
    statusmessage    = EXCLUDED.statusmessage,
    healthdatatype   = EXCLUDED.healthdatatype,
    sysupdatetime    = NOW()::timestamp
WHERE (
       fact.devicestate.state            IS DISTINCT FROM EXCLUDED.state
    OR fact.devicestate.status           IS DISTINCT FROM EXCLUDED.status
    OR fact.devicestate.statusmessage    IS DISTINCT FROM EXCLUDED.statusmessage
    OR fact.devicestate.statuschangetime IS DISTINCT FROM EXCLUDED.statuschangetime
    OR fact.devicestate.duration         IS DISTINCT FROM EXCLUDED.duration
    OR fact.devicestate.healthdatatype   IS DISTINCT FROM EXCLUDED.healthdatatype
);

    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- ----------------------------------------------------------

        UPDATE fact.watermarktable
        SET    watermarkvalue = (SELECT COALESCE(MAX(lasteventtime) - INTERVAL '10 seconds', '1970-01-01 00:00:00'::TIMESTAMP) FROM fact.devicestate),
               sysupdatetime  = NOW() :: TIMESTAMP
        WHERE  watermarktablename = 'fact.devicestate'
          AND  source             = 'gsh';



END;
$BODY$;


ALTER PROCEDURE fact.usp_gsh_devicehealth_to_fact_devicestate() OWNER TO citus;