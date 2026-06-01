

CALL fact.usp_stg_gem_failed_order_job_notifications_to_fact();
CALL fact.usp_silver_cep_incidents_to_fact_cep_incidents();

SELECT *--count(*)
FROM fact.cep_incidents 
ORDER BY incidentkey DESC
LIMIT 1000;

-- Table: stg.silver_kiosk_events

-- DROP TABLE IF EXISTS stg.silver_kiosk_events;

CREATE TABLE IF NOT EXISTS stg.silver_kiosk_events
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
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_kiosk_events
    OWNER to citus;
-- Index: ix_silver_kiosk_events_syscosmosts_brin

-- DROP INDEX IF EXISTS stg.ix_silver_kiosk_events_syscosmosts_brin;

CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_syscosmosts_brin
    ON stg.silver_kiosk_events USING brin
    (syscosmosts)
    WITH (pages_per_range=128)
    TABLESPACE pg_default;

-- Table: fact.cep_incidents

-- DROP TABLE IF EXISTS fact.cep_incidents;

CREATE TABLE IF NOT EXISTS fact.cep_incidents
(
    incidentkey bigint,
    application text COLLATE pg_catalog."default",
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    deviceid text COLLATE pg_catalog."default",
    eventmodule text COLLATE pg_catalog."default",
    eventcategory text COLLATE pg_catalog."default",
    eventtype text COLLATE pg_catalog."default",
    eventtoken text COLLATE pg_catalog."default",
    incidenttype text COLLATE pg_catalog."default",
    incidentcount integer,
    eventinstant text COLLATE pg_catalog."default",
    firstoccurred timestamp without time zone,
    lastoccurred timestamp without time zone,
    notificationtypeid text COLLATE pg_catalog."default",
    incidentdata text COLLATE pg_catalog."default",
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    severity text COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.cep_incidents
    OWNER to citus;


-- Table: stg.silver_cep_incidents

-- DROP TABLE IF EXISTS stg.silver_cep_incidents;

CREATE TABLE IF NOT EXISTS stg.silver_cep_incidents
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
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_cep_incidents
    OWNER to citus;

-- Table: stg.gem_failed_order_job_notifications
-- Source: Cosmos gemJobs container, job = 'asa-failed-order'
-- Populated via ADF pipeline (gemCEPIncidents source)

-- DROP TABLE IF EXISTS stg.gem_failed_order_job_notifications;

CREATE TABLE IF NOT EXISTS stg.gem_failed_order_job_notifications
(
    incidentid          TEXT    COLLATE pg_catalog."default",
    application         TEXT    COLLATE pg_catalog."default",
    organizationid      TEXT    COLLATE pg_catalog."default",
    locationid          TEXT    COLLATE pg_catalog."default",
    eventmodule         TEXT    COLLATE pg_catalog."default",
    eventcategory       TEXT    COLLATE pg_catalog."default",
    eventtype           TEXT    COLLATE pg_catalog."default",
    eventtoken          TEXT    COLLATE pg_catalog."default",
    incidentcount       INTEGER,
    firstoccurred       TEXT    COLLATE pg_catalog."default",
    lastoccurred        TEXT    COLLATE pg_catalog."default",
    incidenttype        TEXT    COLLATE pg_catalog."default",
    notificationtypeid  TEXT    COLLATE pg_catalog."default",
    syscosmosts         BIGINT,
    sysinserttime       TIMESTAMP WITHOUT TIME ZONE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.gem_failed_order_job_notifications
    OWNER TO citus;

-- Index: ix_gem_failed_order_job_notifications_syscosmosts_brin

-- DROP INDEX IF EXISTS stg.ix_gem_failed_order_job_notifications_syscosmosts_brin;

CREATE INDEX IF NOT EXISTS ix_gem_failed_order_job_notifications_syscosmosts_brin
    ON stg.gem_failed_order_job_notifications USING brin
    (syscosmosts)
    WITH (pages_per_range = 128)
    TABLESPACE pg_default;


CREATE TABLE IF NOT EXISTS fact.gem_failed_order_job_notifications
(
    incidentid          BIGINT,
    application         TEXT    COLLATE pg_catalog."default",
    organizationid      TEXT    COLLATE pg_catalog."default",
    locationid          TEXT    COLLATE pg_catalog."default",
    eventmodule         TEXT    COLLATE pg_catalog."default",
    eventcategory       TEXT    COLLATE pg_catalog."default",
    eventtype           TEXT    COLLATE pg_catalog."default",
    eventtoken          TEXT    COLLATE pg_catalog."default",
    incidentcount       INTEGER,
    firstoccurred       TEXT    COLLATE pg_catalog."default",
    lastoccurred        TEXT    COLLATE pg_catalog."default",
    incidenttype        TEXT    COLLATE pg_catalog."default",
    notificationtypeid  TEXT    COLLATE pg_catalog."default",
    syscosmosts         BIGINT,
    sysinserttime       TIMESTAMP WITHOUT TIME ZONE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.gem_failed_order_job_notifications
    OWNER TO citus;




CREATE OR REPLACE PROCEDURE fact.usp_stg_gem_failed_order_job_notifications_to_fact()
    LANGUAGE plpgsql
    AS $BODY$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1767225610) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.gem_failed_order_job_notifications'
      AND source             = 'gem-Job';


    WITH new_notifications AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- DISTINCT ON natural key, latest syscosmosts wins
        -- NOT EXISTS deduplicates against fact on:
        --   incidentid == incidentid
        --   eventtoken == eventtoken

        SELECT DISTINCT ON (
            stg.incidentid,
            stg.eventtoken
        )
            stg.incidentid,
            stg.application,
            stg.organizationid,
            stg.locationid,
            stg.eventmodule,
            stg.eventcategory,
            stg.eventtype,
            stg.eventtoken,
            stg.incidentcount,
            stg.firstoccurred,
            stg.lastoccurred,
            stg.incidenttype,
            stg.notificationtypeid,
            stg.syscosmosts
        FROM stg.gem_failed_order_job_notifications     AS stg
        WHERE stg.syscosmosts   > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.gem_failed_order_job_notifications    AS f
                WHERE f.incidentid = stg.incidentid :: BIGINT
                  AND f.eventtoken = stg.eventtoken
              )
        ORDER BY
            stg.incidentid,
            stg.eventtoken,
            stg.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.gem_failed_order_job_notifications (
        incidentid,
        application,
        organizationid,
        locationid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidentcount,
        firstoccurred,
        lastoccurred,
        incidenttype,
        notificationtypeid,
        syscosmosts,
        sysinserttime
    )
    SELECT
        incidentid :: BIGINT,
        application,
        organizationid,
        locationid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidentcount,
        firstoccurred,
        lastoccurred,
        incidenttype,
        notificationtypeid,
        syscosmosts,
        NOW() :: TIMESTAMP      AS sysinserttime
    FROM new_notifications;


    UPDATE fact.watermarktable
    SET ts            = (SELECT COALESCE(MAX(syscosmosts), 0) FROM fact.gem_failed_order_job_notifications),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.gem_failed_order_job_notifications'
      AND source             = 'gem-Job';

END;
$BODY$;

ALTER PROCEDURE fact.usp_stg_gem_failed_order_job_notifications_to_fact() OWNER TO citus;



CREATE OR REPLACE PROCEDURE fact.usp_silver_cep_incidents_to_fact_cep_incidents()
    LANGUAGE plpgsql
    AS $BODY$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1767225610) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.cep_incidents'
      AND source             = 'gem';


    WITH new_error_events AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- stg.silver_cep_incidents is pre-filtered at the bronze→silver
        -- layer (application=nge, module=connector, severity=critical,
        -- category=order, type=ordersubmitresponse), so no re-filtering needed.
        -- DISTINCT ON natural key, latest syscosmosts wins.
        -- NOT EXISTS mirrors ADF negate exists against GASfactCEPIncidents:
        --   id        == incidentkey
        --   token     == eventtoken
        -- EXISTS dim.organizationlocation mirrors ADF ExistingLocations check

        SELECT DISTINCT ON (
            sci.id,
            sci.token
        )
            sci.id,
            sci.application,
            sci.companyid,
            sci.locationid,
            sci.eventmodule,
            sci.eventcategory,
            sci.eventtype,
            sci.severity,
            sci.token,
            sci.eventinstant,
            sci.device,
            sci.data,
            sci.syscosmosts
        FROM stg.silver_cep_incidents               AS sci
        WHERE sci.syscosmosts   > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.cep_incidents              AS ci
                WHERE ci.incidentkey = sci.id :: BIGINT
                  AND ci.eventtoken  = sci.token
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organizationlocation        AS ol
                WHERE ol.locationid     = sci.locationid
                  AND ol.organizationid = sci.companyid
              )
        ORDER BY
            sci.id,
            sci.token,
            sci.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.cep_incidents (
        incidentkey,
        application,
        organizationid,
        locationid,
        deviceid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidenttype,
        incidentcount,
        eventinstant,
        firstoccurred,
        lastoccurred,
        notificationtypeid,
        incidentdata,
        syscosmosts,
        sysinserttime,
        severity
    )
    -- ── gemJobCEP left join mirrored here ──────────────────────
    -- ADF joins error events LEFT JOIN gemCEPIncidents
    -- (Cosmos job='asa-failed-order') on:
    --   incidentkey  == incidentid
    --   errortoken   == eventtoken
    --   eventcategory == eventcategory
    --   eventtype    == eventtype
    -- Incident metadata (counts, timestamps) enriched from
    -- fact.gem_failed_order_job_notifications
    SELECT
        nee.id :: BIGINT                                                    AS incidentkey,
        nee.application,
        nee.companyid                                                       AS organizationid,
        nee.locationid,
        nee.device                                                          AS deviceid,
        nee.eventmodule,
        nee.eventcategory,
        nee.eventtype,
        nee.token                                                           AS eventtoken,
        gfojn.incidenttype,
        gfojn.incidentcount,
        nee.eventinstant,
        fact.parse_iso_timestamp(gfojn.firstoccurred) :: TIMESTAMP          AS firstoccurred,
        fact.parse_iso_timestamp(gfojn.lastoccurred) :: TIMESTAMP           AS firstoccurred,
        gfojn.notificationtypeid,
        nee.data                                                            AS incidentdata,
        nee.syscosmosts,
        NOW() :: TIMESTAMP                                                  AS sysinserttime,
        nee.severity
    FROM new_error_events                               AS nee
    LEFT JOIN fact.gem_failed_order_job_notifications   AS gfojn
        ON  gfojn.incidentid    = nee.id :: BIGINT
        AND gfojn.eventtoken    = nee.token
        AND gfojn.eventcategory = nee.eventcategory
        AND gfojn.eventtype     = nee.eventtype;


    UPDATE fact.watermarktable
    SET ts            = (SELECT COALESCE(MAX(syscosmosts), 0) FROM fact.cep_incidents),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.cep_incidents'
      AND source             = 'gem';

END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_cep_incidents_to_fact_cep_incidents() OWNER TO citus;