-- Table: gsh.devicetelemetry

-- DROP TABLE IF EXISTS gsh.devicetelemetry;

CREATE TABLE IF NOT EXISTS gsh.devicetelemetry
(
    deviceid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    telemetryname text COLLATE pg_catalog."default" NOT NULL,
    telemetryvalue text COLLATE pg_catalog."default" NOT NULL,
    telemetrytime timestamp without time zone NOT NULL
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS gsh.devicetelemetry
    OWNER to citus;
-- Index: deviceid_locationid_time_idx

-- DROP INDEX IF EXISTS gsh.deviceid_locationid_time_idx;

-- Table: fact.devicetelemetry

-- DROP TABLE IF EXISTS fact.devicetelemetry;

CREATE TABLE IF NOT EXISTS fact.devicetelemetry
(
    deviceid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    cpuvalue numeric(10,5),
    memoryvalue numeric(10,5),
    cputimestamp timestamp without time zone,
    memorytimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT location_deviceid_fk FOREIGN KEY (locationid, deviceid)
        REFERENCES dim.kiosk (locationid, kioskid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT locationid_fk FOREIGN KEY (locationid)
        REFERENCES dim.organization (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.devicetelemetry
    OWNER to citus;


CREATE TABLE IF NOT EXISTS stg.fact_devicetelemetry
(
    deviceid         text,
    locationid       text,
    dateid           integer,
    cpuvalue         numeric(10,5),
    memoryvalue      numeric(10,5),
    cputimestamp     timestamp without time zone,
    memorytimestamp  timestamp without time zone,
    sysinserttime    timestamp without time zone
);

ALTER TABLE IF EXISTS stg.fact_devicetelemetry OWNER TO citus;




SELECT
    COALESCE(cpu.deviceid,   mem.deviceid)   AS deviceid,
    COALESCE(cpu.locationid, mem.locationid) AS locationid,
    COALESCE(cpu.dateid,     mem.dateid)     AS dateid,
    REPLACE(cpu.cpuvalue,    '%', '')        AS cpuvalue,
    REPLACE(mem.memoryvalue, '%', '')        AS memoryvalue,
    cpu.cputimestamp,
    mem.memorytimestamp,
    NOW()::timestamp                         AS sysinserttime
FROM (
    SELECT DISTINCT ON (deviceid, locationid, TO_CHAR(telemetrytime, 'YYYYMMDDHH24'))
        deviceid,
        locationid,
        telemetryvalue                         AS cpuvalue,
        telemetrytime                          AS cputimestamp,
        TO_CHAR(telemetrytime, 'YYYYMMDDHH24') AS dateid
    FROM gsh.devicetelemetry
    WHERE telemetryname  = 'cpu'
      AND deviceid      <> 'no-serial'
      AND telemetryvalue NOT LIKE '%null%'
      AND telemetrytime  < NOW()
      AND telemetrytime  > '{$pdf_instant}'::timestamp
    ORDER BY deviceid, locationid, TO_CHAR(telemetrytime, 'YYYYMMDDHH24'),
             telemetryvalue DESC, telemetrytime DESC
) AS cpu
FULL OUTER JOIN (
    SELECT DISTINCT ON (deviceid, locationid, TO_CHAR(telemetrytime, 'YYYYMMDDHH24'))
        deviceid,
        locationid,
        telemetryvalue                         AS memoryvalue,
        telemetrytime                          AS memorytimestamp,
        TO_CHAR(telemetrytime, 'YYYYMMDDHH24') AS dateid
    FROM gsh.devicetelemetry
    WHERE telemetryname  = 'memory'
      AND deviceid      <> 'no-serial'
      AND telemetryvalue NOT LIKE '%null%'
      AND telemetrytime  < NOW()
      AND telemetrytime  > '{$pdf_instant}'::timestamp
    ORDER BY deviceid, locationid, TO_CHAR(telemetrytime, 'YYYYMMDDHH24'),
             telemetryvalue DESC, telemetrytime DESC
) AS mem
ON  cpu.deviceid   = mem.deviceid
AND cpu.locationid = mem.locationid
AND cpu.dateid     = mem.dateid





CREATE OR REPLACE PROCEDURE fact.usp_gsh_devicetelemetry_to_fact_devicetelemetry()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_watermark TIMESTAMP;

BEGIN

    -- ----------------------------------------------------------
    -- Step 1 — Read the current watermark
    -- Conservative: lesser of MAX(cputimestamp) and MAX(memorytimestamp)
    -- mirrors ADF sourcedevicetelemetry query
    -- ----------------------------------------------------------
    SELECT COALESCE(watermarkvalue, '1970-01-01 00:00:00'::timestamp)
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.devicetelemetry'
      AND  source             = 'gsh';

    -- ----------------------------------------------------------
    -- Step 2 — Upsert into fact.devicetelemetry
    --
    -- Qualifications:
    --   a) cputimestamp OR memorytimestamp beats the watermark
    --   b) Location is live (dim.organization status=2, active=true,
    --      dim.kiosk istestkiosk=false)
    --   c) locationid exists in dim.organization
    --      (mirrors ADF ExistingLocations exists check)
    --
    -- cpu/memory normalization (mirrors ADF CastFields derivedColumn):
    --   ksk-% devices with value <= 1  → keep as-is (already a ratio)
    --   all others with value > 1      → divide by 100
    --
    -- Upsert key: (deviceid, locationid, dateid)
    --   On conflict: update metric values and timestamps,
    --                preserve original sysinserttime
    -- ----------------------------------------------------------
    WITH live_locations_kiosks AS (
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
            stg.deviceid,
            stg.locationid,
            stg.dateid,
            stg.cputimestamp,
            stg.memorytimestamp,
            CASE
                WHEN stg.deviceid LIKE 'ksk-%' AND stg.cpuvalue    <= 1 THEN stg.cpuvalue
                WHEN stg.cpuvalue    > 1                                 THEN stg.cpuvalue    / 100
            END AS cpuvalue,
            CASE
                WHEN stg.deviceid LIKE 'ksk-%' AND stg.memoryvalue <= 1 THEN stg.memoryvalue
                WHEN stg.memoryvalue > 1                                 THEN stg.memoryvalue / 100
            END AS memoryvalue
        FROM  stg.fact_devicetelemetry AS stg
        INNER JOIN live_locations_kiosks AS ll
               ON  ll.locationid = stg.locationid
              AND  ll.deviceid   = stg.deviceid
        WHERE EXISTS (
                  SELECT 1
                  FROM   dim.organization AS o
                  WHERE  o.id = stg.locationid
              )
          AND (stg.cputimestamp >= v_watermark OR stg.memorytimestamp >= v_watermark)
    )

    INSERT INTO fact.devicetelemetry (
        deviceid,
        locationid,
        dateid,
        cpuvalue,
        memoryvalue,
        cputimestamp,
        memorytimestamp,
        sysinserttime,
        sysupdatetime
    )
    SELECT
        deviceid,
        locationid,
        dateid,
        cpuvalue,
        memoryvalue,
        cputimestamp,
        memorytimestamp,
        NOW()::timestamp,
        NULL
    FROM delta
    ON CONFLICT (deviceid, locationid, dateid)
    DO UPDATE SET
        cpuvalue        = COALESCE(EXCLUDED.cpuvalue,        fact.devicetelemetry.cpuvalue),
        memoryvalue     = COALESCE(EXCLUDED.memoryvalue,     fact.devicetelemetry.memoryvalue),
        cputimestamp    = COALESCE(EXCLUDED.cputimestamp,    fact.devicetelemetry.cputimestamp),
        memorytimestamp = COALESCE(EXCLUDED.memorytimestamp, fact.devicetelemetry.memorytimestamp),
        sysupdatetime   = NOW()::timestamp;
        -- sysinserttime deliberately excluded — preserves original insert time

    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- Conservative: lesser of MAX(cputimestamp) and MAX(memorytimestamp)
    -- ----------------------------------------------------------
    UPDATE fact.watermarktable
    SET    watermarkvalue = (
               SELECT LEAST(MAX(cputimestamp), MAX(memorytimestamp))
               FROM   fact.devicetelemetry
           )
    WHERE  watermarktablename = 'fact.devicetelemetry'
      AND  source             = 'gsh';

END;
$BODY$;

ALTER PROCEDURE fact.usp_gsh_devicetelemetry_to_fact_devicetelemetry() OWNER TO citus;