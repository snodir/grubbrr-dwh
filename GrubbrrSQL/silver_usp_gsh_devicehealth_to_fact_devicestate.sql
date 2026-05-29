--CALL fact.usp_gsh_devicestate_to_fact_devicestate();


SELECT * 
FROM fact.devicestate
ORDER BY id DESC 
LIMIT 100;

-- ============================================================
-- stg.fact_devicestate  — Staging table
-- ============================================================
--SELECT 'infinity'::timestamp

SELECT
    dh.id,
    dh.healthdatatype,
    dh.locationid,
    dh.companyid,
    dh.deviceid,
    dh.devicetype,
    dh.status,
    dh.statusmessage,
    dh.healthdatatime,
    dh.statuschangetime,
    dh.inserttime,
    dh.version,
    dh.devicedatatime,
    NOW()::timestamp AS sysinserttime
FROM gsh.devicehealth AS dh
INNER JOIN gsh.device AS d
        ON d.deviceid = dh.deviceid
       AND d.state NOT IN ('New', 'Deleted')
WHERE dh.healthdatatime > '@{activity('LookupMaxValues').output.firstRow.maxinstant}' :: TIMESTAMP
  AND dh.deviceid       <> 'no-serial'
  AND dh.healthdatatime <> '-infinity' :: TIMESTAMP



SELECT
    CAST(id              AS bigint)    AS id,
    CAST(healthdatatype  AS text)      AS healthdatatype,
    CAST(locationid      AS text)      AS locationid,
    CAST(companyid       AS text)      AS companyid,
    CAST(deviceid        AS text)      AS deviceid,
    CAST(devicetype      AS text)      AS devicetype,
    CAST(status          AS text)      AS status,
    CAST(statusmessage   AS text)      AS statusmessage,
    CAST(healthdatatime  AS TIMESTAMP) AS healthdatatime,
    CAST(statuschangetime AS TIMESTAMP) AS statuschangetime,
    CAST(inserttime      AS TIMESTAMP) AS inserttime,
    CAST(version         AS text)      AS version
FROM gsh.devicehealth
WHERE CAST(healthdatatime AS TIMESTAMP) > CAST('{$pdf_instant}' AS TIMESTAMP)
  AND deviceid <> 'no-serial'
  AND healthdatatime <> '-infinity';


CREATE TABLE IF NOT EXISTS stg.fact_devicestate
(
    id               bigint,                      -- GSH source PK, used as watermark
    healthdatatype   text,
    locationid       text,
    companyid        text,
    deviceid         text,
    devicetype       text,
    status           text,
    statusmessage    text,
    healthdatatime   timestamp without time zone,
    statuschangetime timestamp without time zone,
    inserttime       timestamp without time zone,
    version          text,
    devicedatatime   timestamp without time zone,
    sysinserttime    timestamp without time zone
);

ALTER TABLE IF EXISTS stg.fact_devicestate OWNER TO citus;



-- Watermark filter index
CREATE INDEX IF NOT EXISTS idx_stg_fact_devicestate_id
    ON stg.fact_devicestate USING btree (id ASC NULLS LAST);

-- Duplicate guard index
CREATE INDEX IF NOT EXISTS idx_stg_fact_devicestate_device_event
    ON stg.fact_devicestate USING btree (deviceid, locationid, healthdatatime);


-- Table: fact.devicestate

-- DROP TABLE IF EXISTS fact.devicestate;

CREATE TABLE IF NOT EXISTS fact.devicestate
(
    id bigint NOT NULL,
    companyid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    deviceid text COLLATE pg_catalog."default",
    dateid integer,
    state text COLLATE pg_catalog."default",
    lasteventtime timestamp without time zone,
    statuschangetime timestamp without time zone,
    duration numeric(10,3),
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.devicestate
    OWNER to citus;




-- Table: gsh.devicehealth

-- DROP TABLE IF EXISTS gsh.devicehealth;

CREATE TABLE IF NOT EXISTS gsh.devicehealth
(
    id bigint NOT NULL DEFAULT nextval('gsh.devicehealth_id_seq'::regclass),
    healthdatatype character varying(50) COLLATE pg_catalog."default" NOT NULL,
    locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    companyid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    deviceid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    devicetype character varying(50) COLLATE pg_catalog."default" NOT NULL,
    status character varying(50) COLLATE pg_catalog."default" NOT NULL,
    statusmessage text COLLATE pg_catalog."default",
    healthdatatime timestamp without time zone NOT NULL,
    statuschangetime timestamp without time zone NOT NULL,
    inserttime timestamp without time zone NOT NULL,
    version character varying(50) COLLATE pg_catalog."default",
    devicedatatime timestamp without time zone NOT NULL,
    CONSTRAINT devicehealth_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS gsh.devicehealth
    OWNER to citus;
-- Index: devicehealth_idx

-- DROP INDEX IF EXISTS gsh.devicehealth_idx;


CREATE SEQUENCE IF NOT EXISTS fact.devicestate_id_seq;

ALTER SEQUENCE fact.devicestate_id_seq OWNER TO citus;

SELECT setval('fact.devicestate_id_seq', (SELECT MAX(id) FROM fact.devicestate));

ALTER TABLE fact.devicestate
    ALTER COLUMN id SET DEFAULT NEXTVAL('fact.devicestate_id_seq');

-- ============================================================
-- fact.usp_stg_devicestate_to_fact
--
-- Source   : stg.fact_devicestate  (ADF-populated)
-- Target   : fact.devicestate
-- Watermark: fact.watermarktable   (watermarktablename = 'fact.devicestate',
--                                   watermarkcolumn    = 'gsh_id')
--            Tracks MAX(id) from gsh.devicehealth — bigint, monotonic
-- ============================================================

CREATE OR REPLACE PROCEDURE fact.usp_gsh_devicestate_to_fact_devicestate()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_watermark     TIMESTAMP;

BEGIN

    -- ----------------------------------------------------------
    -- Step 1 — Read the current watermark
    -- ----------------------------------------------------------
    SELECT COALESCE(watermarkvalue, '1970-01-01 00:00:00'::timestamp)
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.devicestate'
      AND  source             = 'gsh';

    -- ----------------------------------------------------------
    -- Step 2 — Insert qualifying rows into fact.devicestate
    -- ----------------------------------------------------------
    WITH live_locations AS (
        SELECT DISTINCT
            o.id      AS locationid,
            k.kioskid AS deviceid
        FROM  dim.organization AS o
        INNER JOIN dim.kiosk   AS k ON o.id = k.locationid
        WHERE o.active      = true
          AND o.status      = 2
          AND k.istestkiosk = false
    ),

    delta AS (
        SELECT
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
            END                                                         AS state
        FROM  stg.fact_devicestate AS stg
        INNER JOIN live_locations  AS ll
               ON  ll.locationid = stg.locationid
              AND  ll.deviceid   = stg.deviceid
        WHERE stg.healthdatatime > v_watermark
          AND NOT EXISTS (
                  SELECT 1
                  FROM   fact.devicestate AS f
                  WHERE  f.deviceid      = stg.deviceid
                    AND  f.locationid    = stg.locationid
                    AND  f.lasteventtime = stg.healthdatatime
              )
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
        sysinserttime
    )
    SELECT
        NEXTVAL('fact.devicestate_id_seq'),
        companyid,
        locationid,
        deviceid,
        dateid,
        state,
        lasteventtime,
        statuschangetime,
        duration,
        NOW()::timestamp
    FROM delta;


    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- ----------------------------------------------------------

        UPDATE fact.watermarktable
        SET    ts = (SELECT COALESCE(MAX(id), 1775002010) FROM fact.devicestate)
        WHERE  watermarktablename = 'fact.devicestate'
          AND  source             = 'gsh';



END;
$BODY$;

ALTER PROCEDURE fact.usp_gsh_devicestate_to_fact_devicestate() OWNER TO citus;

