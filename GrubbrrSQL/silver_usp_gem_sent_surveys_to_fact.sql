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





-- PROCEDURE: fact.usp_sent_surveys_to_fact_itemssurvey()

-- DROP PROCEDURE IF EXISTS fact.usp_sent_surveys_to_fact_itemssurvey();

CREATE OR REPLACE PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey(
	)
LANGUAGE plpgsql
AS $BODY$


BEGIN

DROP TABLE IF EXISTS temp_delta_sent_surveys;
CREATE TEMPORARY TABLE temp_delta_sent_surveys (
    organizationid       TEXT COLLATE pg_catalog."default",
    locationid           TEXT COLLATE pg_catalog."default",
    ordersessionid       TEXT COLLATE pg_catalog."default",
    transactionheaderid  TEXT COLLATE pg_catalog."default",
    gem_event_category   TEXT COLLATE pg_catalog."default",
    gem_event_type       TEXT COLLATE pg_catalog."default",
    orderid              TEXT COLLATE pg_catalog."default",
    surveyid             TEXT COLLATE pg_catalog."default",
    itemid               TEXT COLLATE pg_catalog."default",
    is_responded         BOOLEAN,
    gem_event_instant    TEXT COLLATE pg_catalog."default",
    gem_syscosmosts      BIGINT,
    sysinserttime        TIMESTAMP,
    sysupdatetime        TIMESTAMP,
    menuitemid           TEXT COLLATE pg_catalog."default"
);


WITH delta_sent_surveys AS (
    SELECT 
        organizationid,
        locationid,
        ordersessionid,
        orderid AS transactionheaderid,
        gem_event_category,
        gem_event_type,
        survey_metadata,
        CONCAT('ord-', (survey_metadata ->> 'orderId')::TEXT) AS orderid,
        CASE WHEN jsonb_typeof(survey_metadata -> 'surveyIds') = 'array' THEN survey_metadata -> 'surveyIds' END AS surveyid_array,
        CASE WHEN survey_metadata ->> 'surveyIds' NOT LIKE '[%]' THEN survey_metadata ->> 'surveyIds' END AS surveyid_text,
        CASE WHEN jsonb_typeof(survey_metadata -> 'itemId') = 'array' THEN survey_metadata -> 'itemId' END AS itemid_array,
        CASE WHEN survey_metadata ->> 'itemId' NOT LIKE '[%]' THEN survey_metadata ->> 'itemId' END AS itemid_text,
        is_responded,
        gem_event_instant,
        gem_syscosmosts,
        sysinserttime,
        sysupdatetime
    FROM fact.sent_surveys AS ss
    WHERE ss.gem_syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.itemssurvey' AND source = 'gem')
      AND NOT EXISTS (SELECT 1 FROM fact.itemssurvey AS its 
                      WHERE its.locationid = ss.locationid
                        AND its.orderid = ss.orderid)
), flattened_survey_trxns AS (
    SELECT
        dss.organizationid,
        dss.locationid,
        dss.ordersessionid,
        dss.transactionheaderid,
        dss.gem_event_category,
        dss.gem_event_type,
        dss.orderid,
        TRIM(flat_survey.surveyid) AS surveyid,
        --TRIM(flat_item.itemid)     AS itemid,
        dss.is_responded,
        dss.gem_event_instant,
        dss.gem_syscosmosts,
        dss.sysinserttime,
        dss.sysupdatetime
    FROM delta_sent_surveys AS dss
    CROSS JOIN LATERAL (
        SELECT unnest(
            CASE WHEN dss.surveyid_array IS NOT NULL THEN ARRAY(SELECT jsonb_array_elements_text(dss.surveyid_array))
                 WHEN dss.surveyid_text  IS NOT NULL THEN string_to_array(dss.surveyid_text, ',')
            END
        ) AS surveyid
    ) AS flat_survey
    /*CROSS JOIN LATERAL (
        SELECT unnest(
            CASE WHEN dss.itemid_array IS NOT NULL THEN ARRAY(SELECT jsonb_array_elements_text(dss.itemid_array))
                 WHEN dss.itemid_text  IS NOT NULL THEN string_to_array(dss.itemid_text, ',')
            END
        ) AS itemid
    ) AS flat_item*/
), flattened_item_trxns AS (
    SELECT
        dss.organizationid,
        dss.locationid,
        dss.ordersessionid,
        dss.transactionheaderid,
        dss.gem_event_category,
        dss.gem_event_type,
        dss.orderid,
        --TRIM(flat_survey.surveyid) AS surveyid,
        TRIM(flat_item.itemid)     AS itemid,
        dss.is_responded,
        dss.gem_event_instant,
        dss.gem_syscosmosts,
        dss.sysinserttime,
        dss.sysupdatetime
    FROM delta_sent_surveys AS dss
    /*CROSS JOIN LATERAL (
        SELECT unnest(
            CASE WHEN dss.surveyid_array IS NOT NULL THEN ARRAY(SELECT jsonb_array_elements_text(dss.surveyid_array))
                 WHEN dss.surveyid_text  IS NOT NULL THEN string_to_array(dss.surveyid_text, ',')
            END
        ) AS surveyid
    ) AS flat_survey*/
    CROSS JOIN LATERAL (
        SELECT unnest(
            CASE WHEN dss.itemid_array IS NOT NULL THEN ARRAY(SELECT jsonb_array_elements_text(dss.itemid_array))
                 WHEN dss.itemid_text  IS NOT NULL THEN string_to_array(dss.itemid_text, ',')
            END
        ) AS itemid
    ) AS flat_item

), joined_surveys_with_items AS (
    SELECT st.organizationid,
           st.locationid,
           st.ordersessionid,
           st.transactionheaderid,
           st.gem_event_category,
           st.gem_event_type,
           st.orderid,
           st.surveyid,
           it.itemid,
           st.is_responded,
           st.gem_event_instant,
           st.gem_syscosmosts,
           st.sysinserttime,
           st.sysupdatetime 
           --ti.dimmenuitemid as menuitemid
    FROM flattened_survey_trxns as st 
    LEFT JOIN flattened_item_trxns as it
        ON st.locationid = it.locationid
        AND st.transactionheaderid = it.transactionheaderid
)
INSERT INTO temp_delta_sent_surveys
SELECT * FROM joined_surveys_with_items;


INSERT INTO fact.itemssurvey (
    organizationid,
    locationid,
    ordersessionid,
    orderid,
    surveyissuedtimestamp,
    gem_event_category,
    gem_event_type,
    surveyid,
    is_responded,
    gem_event_instant,
    gem_syscosmosts,
    sysinserttime,
    sysupdatetime,
    itemid
)
SELECT
    organizationid,
    locationid,
    ordersessionid,
    transactionheaderid,
    CASE WHEN substring(gem_event_instant, 20, 1) = '.' 
         THEN replace(replace(substring(gem_event_instant, 1, 23), 'T', ' '), '+', '0') 
         ELSE replace(substring(gem_event_instant, 1, 19), 'T', ' ') 
    END AS surveyissuedtimestamp,
    gem_event_category,
    gem_event_type,
    surveyid,
    is_responded,
    gem_event_instant,
    gem_syscosmosts,
    sysinserttime,
    sysupdatetime,
    itemid
FROM temp_delta_sent_surveys as tds
WHERE NOT EXISTS (SELECT * FROM fact.itemssurvey as its 
                  WHERE its.organizationid = tds.organizationid
                    AND its.locationid = tds.locationid
                    AND its.orderid = tds.transactionheaderid
                    AND its.itemid = tds.menuitemid
                    AND its.surveyid = tds.surveyid);


UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(gem_syscosmosts), 1775002010) - 10 FROM fact.itemssurvey)
WHERE watermarktablename = 'fact.itemssurvey'
  AND source = 'gem';


END;
$BODY$;
ALTER PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey()
    OWNER TO citus;

