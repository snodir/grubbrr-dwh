-- Table: fact.sent_surveys

-- DROP TABLE IF EXISTS fact.sent_surveys;

CREATE TABLE IF NOT EXISTS fact.sent_surveys
(
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default" NOT NULL,
    orderid text COLLATE pg_catalog."default",
    gem_event_category text COLLATE pg_catalog."default",
    gem_event_type text COLLATE pg_catalog."default",
    survey_metadata jsonb,
    is_responded boolean,
    gem_event_instant text COLLATE pg_catalog."default",
    gem_syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT sent_surveys_ordersessionid_pkey PRIMARY KEY (locationid, ordersessionid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.sent_surveys
    OWNER to citus;


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

-- PROCEDURE: fact.usp_gem_sent_surveys_to_fact()

-- DROP PROCEDURE IF EXISTS fact.usp_gem_sent_surveys_to_fact();

CREATE OR REPLACE PROCEDURE fact.usp_gem_sent_surveys_to_fact(
	)
LANGUAGE plpgsql
AS $BODY$


DECLARE
    v_max_gem_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_gem_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.sent_surveys'
      AND source             = 'gem';

    WITH delta_sent AS (

        SELECT DISTINCT ON (locationid, token)
            locationid,
            token                                           AS ordersessionid,
            NULLIF(ke.data, '') :: jsonb ->> 'orderId'      AS orderid,
            NULLIF(ke.data, '') :: jsonb                    AS survey_metadata,
            eventcategory                                   AS gem_event_category,
            eventtype                                       AS gem_event_type,
            eventinstant                                    AS gem_event_instant,
            syscosmosts                                     AS gem_syscosmosts
        FROM stg.silver_kiosk_events AS ke
        WHERE ke.eventcategory = 'Survey'
          AND ke.eventtype     = 'Sent'
          AND ke.token         > ''
          AND ke.syscosmosts   > v_max_gem_syscosmosts
        ORDER BY locationid, token, syscosmosts DESC

    )
    INSERT INTO fact.sent_surveys (
        organizationid,
        locationid,
        ordersessionid,
        orderid,
        survey_metadata,
        gem_event_category,
        gem_event_type,
        gem_event_instant,
        gem_syscosmosts,
        is_responded,
        sysinserttime
    )
    SELECT
        ol.organizationid,
        ds.locationid,
        ds.ordersessionid,
        ds.orderid,
        ds.survey_metadata,
        ds.gem_event_category,
        ds.gem_event_type,
        ds.gem_event_instant,
        ds.gem_syscosmosts,
        false                   AS is_responded,
        now() :: TIMESTAMP      AS sysinserttime
    FROM delta_sent AS ds
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = ds.locationid
        AND ol.organizationtype = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM fact.sent_surveys AS fs
        WHERE fs.locationid     = ds.locationid
          AND fs.ordersessionid = ds.ordersessionid
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(gem_syscosmosts), 1775002010) FROM fact.sent_surveys)
    WHERE watermarktablename = 'fact.sent_surveys'
      AND source             = 'gem';

END;
$BODY$;
ALTER PROCEDURE fact.usp_gem_sent_surveys_to_fact()
    OWNER TO citus;





