--CALL fact.usp_distribute_silver_gem_events();

SELECT * FROM stg.silver_all_gem_events LIMIT 100;
SELECT * FROM stg.silver_kiosk_events LIMIT 100;


CREATE TABLE IF NOT EXISTS stg.silver_all_gem_events
(
    id text COLLATE pg_catalog."default",
    application text COLLATE pg_catalog."default",
    companyid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    eventmodule text COLLATE pg_catalog."default",
    eventcategory text COLLATE pg_catalog."default",
    eventtype text COLLATE pg_catalog."default",
    severity text COLLATE pg_catalog."default",
    token text COLLATE pg_catalog."default",
    eventinstant text COLLATE pg_catalog."default",
    username text COLLATE pg_catalog."default",
    userid text COLLATE pg_catalog."default",
    device text COLLATE pg_catalog."default",
    devicename text COLLATE pg_catalog."default",
    summary text COLLATE pg_catalog."default",
    data text COLLATE pg_catalog."default",
    syscosmosticks bigint,
    syscosmosts bigint,
    bronze_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_all_gem_events
    OWNER to citus;

-- ============================================================
-- stg.silver_kiosk_events   — Target staging table (NGE kiosk)
-- stg.silver_connector_events — Target staging table (NGE connector)
--
-- Both are populated by sp_distribute_silver_gem_events()
-- from stg.silver_all_gem_events.
--
-- NOTE: silver_kiosk_events uses a 15-min sliding DELETE
--       (not TRUNCATE) in fact-layer SPs due to cross-hour
--       session joins (ordersessionid = token).
--       silver_connector_events is safe to truncate per batch.
-- ============================================================

-- ============================================================
-- STORED PROCEDURE
-- ============================================================


-- ================================================================
-- usp_distribute_silver_gem_events targets
-- ================================================================
ALTER TABLE stg.silver_kiosk_events
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

ALTER TABLE stg.silver_cep_incidents
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

CREATE OR REPLACE PROCEDURE fact.usp_distribute_silver_gem_events(
    p_partition_path TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- ================================================================
    -- 1. KIOSK EVENTS
    -- ================================================================
    INSERT INTO stg.silver_kiosk_events (
        id, application, companyid, locationid,
        eventmodule, eventcategory, eventtype, severity,
        token, eventinstant, username, userid,
        device, devicename, summary, data,
        syscosmosticks, syscosmosts,
        silver_transform_time, silver_folderpath, bronze_folderpath, sysinserttime
    )
    SELECT
        src.id,
        src.application,
        src.companyid,
        src.locationid,
        src.eventmodule,
        src.eventcategory,
        src.eventtype,
        src.severity,
        src.token,
        src.eventinstant,
        src.username,
        src.userid,
        src.device,
        src.devicename,
        src.summary,
        src.data,
        src.syscosmosticks,
        src.syscosmosts,
        now()::text      AS silver_transform_time,
        NULL::text       AS silver_folderpath,
        src.bronze_folderpath,
        now()::timestamp AS sysinserttime
    FROM stg.silver_all_gem_events src
    WHERE (p_partition_path IS NULL OR src.bronze_folderpath = p_partition_path)
      AND LOWER(src.application) = 'nge'
      AND LOWER(src.eventmodule) = 'kiosk'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_kiosk_events ke
          WHERE ke.id         = src.id
            AND ke.locationid = src.locationid
      );


    -- ================================================================
    -- 2. CEP INCIDENTS
    --    Mirrors DF filter: application='nge' AND eventmodule='connector'
    --                       AND severity='critical' AND eventcategory='order'
    --                       AND eventtype='ordersubmitresponse'
    -- ================================================================
    INSERT INTO stg.silver_cep_incidents (
        id, application, companyid, locationid,
        eventmodule, eventcategory, eventtype, severity,
        token, eventinstant, username, userid,
        device, devicename, summary, data,
        syscosmosticks, syscosmosts,
        silver_transform_time, silver_folderpath, bronze_folderpath, sysinserttime
    )
    SELECT
        src.id,
        src.application,
        src.companyid,
        src.locationid,
        src.eventmodule,
        src.eventcategory,
        src.eventtype,
        src.severity,
        src.token,
        src.eventinstant,
        src.username,
        src.userid,
        src.device,
        src.devicename,
        src.summary,
        src.data,
        src.syscosmosticks,
        src.syscosmosts,
        now()::text      AS silver_transform_time,
        NULL::text       AS silver_folderpath,
        src.bronze_folderpath,
        now()::timestamp AS sysinserttime
    FROM stg.silver_all_gem_events src
    WHERE (p_partition_path IS NULL OR src.bronze_folderpath = p_partition_path)
      AND LOWER(src.application)   = 'nge'
      AND LOWER(src.eventmodule)   = 'connector'
      AND LOWER(src.severity)      = 'critical'
      AND LOWER(src.eventcategory) = 'order'
      AND LOWER(src.eventtype)     = 'ordersubmitresponse'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_cep_incidents ci
          WHERE ci.id         = src.id
            AND ci.locationid = src.locationid
      );


    -- ================================================================
    -- FLUSH
    -- ================================================================
    IF p_partition_path IS NULL THEN
        TRUNCATE TABLE stg.silver_all_gem_events;
    ELSE
        DELETE FROM stg.silver_all_gem_events
        WHERE bronze_folderpath = p_partition_path;
    END IF;

END;
$BODY$;

ALTER PROCEDURE fact.usp_distribute_silver_gem_events(TEXT) OWNER TO citus;