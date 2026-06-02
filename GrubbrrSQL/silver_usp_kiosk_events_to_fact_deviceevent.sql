SELECT * FROM fact.deviceevent 
WHERE syscosmosts IS NOT NULL 
ORDER BY syscosmosts DESC LIMIT 100;

CALL fact.usp_silver_kiosk_events_to_fact_deviceevent();

-- Table: fact.deviceevent

-- DROP TABLE IF EXISTS fact.deviceevent;

-- Suggested Indexes on fact.deviceevent columns

-- fact.deviceevent — speeds up watermark capture
CREATE INDEX IF NOT EXISTS ix_deviceevent_syscosmosts_brin
    ON fact.deviceevent USING brin (syscosmosts)
    WITH (pages_per_range = 128);

-- stg.silver_kiosk_events — speeds up incremental filter
-- (benefits ALL procs that use syscosmosts watermark on this table)
CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_syscosmosts_brin
    ON stg.silver_kiosk_events USING brin (syscosmosts)
    WITH (pages_per_range = 128);

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
    CONSTRAINT orgid_locationid_fk FOREIGN KEY (companyid, locationid)
        REFERENCES dim.organizationlocation (organizationid, locationid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
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

-- ============================================================
-- fact.deviceevent – Refresh Procedure
-- Source  : stg.silver_kiosk_events WHERE eventmodule = 'kiosk'
-- Target  : fact.deviceevent
-- Pattern : incremental via syscosmosts watermark
--           + NOT EXISTS guard on 5-column natural key
-- No surrogate ID — fact.deviceevent has no id/PK column
-- ADF notes:
--   CosmosDB source includes connector events too, but after split
--   only KioskAllEvents (module='kiosk') writes to fact.deviceevent
--   → stg.silver_kiosk_events already contains kiosk events only
--   JSONCleanUp (unicode escape replacement) already applied in silver layer
--   devicename = deviceid in ADF sink — both populated from ske.device
--   dimOrgLoc EXISTS check → dim.organizationlocation (matches FK on table)
-- ============================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_kiosk_events_to_fact_deviceevent()
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(MAX(syscosmosts) - 10, 0)
    INTO v_max_syscosmosts
    FROM fact.deviceevent;


    WITH new_events AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- DISTINCT ON natural key, latest syscosmosts wins
        -- NOT EXISTS mirrors ADF negate exists against AnalyticsDbEvents:
        --   location == locationid
        --   token    == eventtoken
        --   category == datacategory
        --   type     == actiontype
        --   instant  == eventinstant
        -- EXISTS dim.organizationlocation mirrors ADF dimOrgLoc exists check
        --   and aligns with the FK constraint on fact.deviceevent

        SELECT DISTINCT ON (
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant
        )
            ske.application,
            ske.companyid,
            ske.locationid,
            ske.eventmodule,
            ske.eventcategory,
            ske.eventtype,
            ske.severity,
            ske.token,
            ske.eventinstant,
            ske.username,
            ske.userid,
            ske.device,
            ske.summary,
            ske.data,
            ske.syscosmosticks,
            ske.syscosmosts
        FROM stg.silver_kiosk_events            AS ske
        WHERE ske.syscosmosts   > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.deviceevent           AS de
                WHERE de.locationid   = ske.locationid
                  AND de.eventtoken   = ske.token
                  AND de.datacategory = ske.eventcategory
                  AND de.actiontype   = ske.eventtype
                  AND de.eventinstant = ske.eventinstant
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organizationlocation   AS ol
                WHERE ol.locationid     = ske.locationid
                  AND ol.organizationid = ske.companyid
              )
        ORDER BY
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant,
            ske.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.deviceevent (
        application,
        companyid,
        locationid,
        moduleid,
        datacategory,
        actiontype,
        severity,
        eventtoken,
        eventinstant,
        dateid,
        username,
        userid,
        deviceid,
        devicename,
        summary,
        eventdata,
        syscosmosticks,
        sysinserttime,
        syscosmosts
    )
    SELECT
        application,
        companyid,
        locationid,
        eventmodule                                                         AS moduleid,
        eventcategory                                                       AS datacategory,
        eventtype                                                           AS actiontype,
        severity,
        token                                                               AS eventtoken,
        eventinstant,
        REPLACE(REPLACE(SUBSTRING(eventinstant, 1, 13), '-', ''), 'T', '')
            :: INTEGER                                                      AS dateid,
        username,
        userid,
        device                                                              AS deviceid,
        device                                                              AS devicename,
        summary,
        data                                                                AS eventdata,
        syscosmosticks,
        NOW() :: TIMESTAMP                                                  AS sysinserttime,
        syscosmosts
    FROM new_events;

END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_kiosk_events_to_fact_deviceevent()
    OWNER TO citus;