-- Schema evolution: fact.devicestate
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

SELECT *
FROM stg.fact_devicestate
ORDER BY id ASC
LIMIT 1000;

SELECT *
FROM fact.devicestate
ORDER BY id
LIMIT 1000;

SELECT id, count(*) > 1
FROM fact.devicestate
GROUP BY id 
HAVING count(*) > 1

UPDATE fact.devicestate
SET id = new_id
FROM (SELECT *, ROW_NUMBER() OVER(ORDER BY id) as new_id
      FROM fact.devicestate) AS ds 
WHERE devicestate.id = ds.id


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


SELECT ds.*,
    count(*) OVER(PARTITION BY locationid, deviceid, lasteventtime) as dupl_count
FROM fact.devicestate as ds
--GROUP BY locationid, deviceid, lasteventtime
--HAVING count(*) > 1
ORDER BY locationid, deviceid, lasteventtime, dupl_count DESC
LIMIT 100

CALL fact.usp_gsh_devicehealth_to_fact_devicestate();


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
        /*INNER JOIN live_locations  AS ll
               ON  ll.locationid = stg.locationid
              AND  ll.deviceid   = stg.deviceid*/
        WHERE 1=1 --AND stg.healthdatatime > v_watermark
          AND NOT EXISTS (
                  SELECT 1
                  FROM   fact.devicestate AS f
                  WHERE  f.deviceid      = stg.deviceid
                    AND  f.locationid    = stg.locationid
                    AND  f.lasteventtime = stg.healthdatatime
              )
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
        NOW()::timestamp
    FROM delta;


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