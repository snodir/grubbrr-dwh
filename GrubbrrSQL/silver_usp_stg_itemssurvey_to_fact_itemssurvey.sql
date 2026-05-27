-- Table: fact.itemssurvey

-- DROP TABLE IF EXISTS fact.itemssurvey;

CREATE TABLE IF NOT EXISTS fact.itemssurvey
(
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    surveyid text COLLATE pg_catalog."default",
    surveytransid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    itemid text COLLATE pg_catalog."default",
    itemrating text COLLATE pg_catalog."default",
    surveytransstatus text COLLATE pg_catalog."default",
    surveyissuedtimestamp text COLLATE pg_catalog."default",
    surveycompletedtimestamp text COLLATE pg_catalog."default",
    surveylocaltimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    nge_syscosmosts bigint,
    ordersessionid text COLLATE pg_catalog."default",
    gem_event_category text COLLATE pg_catalog."default",
    gem_event_type text COLLATE pg_catalog."default",
    is_responded boolean,
    gem_syscosmosts bigint,
    gem_event_instant text COLLATE pg_catalog."default",
    sysupdatetime timestamp without time zone,
    sourceid integer,
    CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid)
        REFERENCES fact.transactionheader (locationid, transactionheaderid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid)
        REFERENCES dim.organizationlocation (organizationid, locationid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.itemssurvey
    OWNER to citus;



CREATE TABLE IF NOT EXISTS stg.fact_itemssurvey
(
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    surveyid text COLLATE pg_catalog."default",
    surveytransid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    itemid text COLLATE pg_catalog."default",
    itemrating text COLLATE pg_catalog."default",
    surveytransstatus text COLLATE pg_catalog."default",
    surveyissuedtimestamp text COLLATE pg_catalog."default",
    surveycompletedtimestamp text COLLATE pg_catalog."default",
    surveylocaltimestamp timestamp without time zone,
    nge_syscosmosts bigint,
    sourceid integer,
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.fact_itemssurvey
    OWNER to citus;


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

-- PROCEDURE: fact.usp_gem_sent_surveys_to_fact()
--
-- Populates fact.sent_surveys from stg.silver_kiosk_events.
-- Dedup   : DISTINCT ON (locationid, token) → latest sent event per session
-- Gate    : NOT EXISTS on (locationid, ordersessionid) in fact.sent_surveys
-- Watermark: fact.watermarktable WHERE watermarktablename='fact.sent_surveys' AND source='gem'

-- DROP PROCEDURE IF EXISTS fact.usp_gem_sent_surveys_to_fact();

--CALL fact.usp_gem_sent_surveys_to_fact();

--SELECT * FROM fact.sent_surveys;

CREATE OR REPLACE PROCEDURE fact.usp_gem_sent_surveys_to_fact()
LANGUAGE 'plpgsql'
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
-- SELECT TO_TIMESTAMP(1775002010)
-- Populates fact.itemssurvey from fact.sent_surveys.
-- surveyIds and itemId in survey_metadata can each be a JSON array or scalar CSV;
-- both are handled via dual-branch LATERAL unnesting.
-- They are unnested in separate CTEs then LEFT JOINed to produce
-- one fact row per (session × surveyId × itemId).
-- Watermark: fact.watermarktable WHERE watermarktablename='fact.itemssurvey' AND source='gem'
--
-- Fix vs original SP: NOT EXISTS previously used tds.menuitemid (always NULL).
--                     Corrected to tds.itemid for proper item-level dedup.

-- DROP PROCEDURE IF EXISTS fact.usp_sent_surveys_to_fact_itemssurvey();

CREATE OR REPLACE PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey()
LANGUAGE 'plpgsql'
AS $BODY$

DECLARE
    v_max_gem_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_gem_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'gem';

    DROP TABLE IF EXISTS temp_delta_sent_surveys;
    CREATE TEMPORARY TABLE temp_delta_sent_surveys (
        organizationid       TEXT COLLATE pg_catalog."default",
        locationid           TEXT COLLATE pg_catalog."default",
        ordersessionid       TEXT COLLATE pg_catalog."default",
        transactionheaderid  TEXT COLLATE pg_catalog."default",
        gem_event_category   TEXT COLLATE pg_catalog."default",
        gem_event_type       TEXT COLLATE pg_catalog."default",
        surveyid             TEXT COLLATE pg_catalog."default",
        itemid               TEXT COLLATE pg_catalog."default",
        is_responded         BOOLEAN,
        gem_event_instant    TEXT COLLATE pg_catalog."default",
        gem_syscosmosts      BIGINT,
        sysinserttime        TIMESTAMP,
        sysupdatetime        TIMESTAMP
    );

    WITH delta_sent_surveys AS (

        SELECT
            organizationid,
            locationid,
            ordersessionid,
            orderid                                                             AS transactionheaderid,
            gem_event_category,
            gem_event_type,
            survey_metadata,
            CASE WHEN jsonb_typeof(survey_metadata -> 'surveyIds') = 'array'
                 THEN survey_metadata -> 'surveyIds'
            END                                                                 AS surveyid_array,
            CASE WHEN survey_metadata ->> 'surveyIds' NOT LIKE '[%]'
                 THEN survey_metadata ->> 'surveyIds'
            END                                                                 AS surveyid_text,
            CASE WHEN jsonb_typeof(survey_metadata -> 'itemId') = 'array'
                 THEN survey_metadata -> 'itemId'
            END                                                                 AS itemid_array,
            CASE WHEN survey_metadata ->> 'itemId' NOT LIKE '[%]'
                 THEN survey_metadata ->> 'itemId'
            END                                                                 AS itemid_text,
            is_responded,
            gem_event_instant,
            gem_syscosmosts,
            sysinserttime,
            sysupdatetime
        FROM fact.sent_surveys AS ss
        WHERE ss.gem_syscosmosts > v_max_gem_syscosmosts
          AND NOT EXISTS (
              SELECT 1 FROM fact.itemssurvey AS its
              WHERE its.locationid = ss.locationid
                AND its.orderid    = ss.orderid
          )

    ), flattened_survey_trxns AS (

        SELECT
            dss.organizationid,
            dss.locationid,
            dss.ordersessionid,
            dss.transactionheaderid,
            dss.gem_event_category,
            dss.gem_event_type,
            TRIM(flat_survey.surveyid)                                          AS surveyid,
            dss.is_responded,
            dss.gem_event_instant,
            dss.gem_syscosmosts,
            dss.sysinserttime,
            dss.sysupdatetime
        FROM delta_sent_surveys AS dss
        CROSS JOIN LATERAL (
            SELECT unnest(
                CASE WHEN dss.surveyid_array IS NOT NULL
                     THEN ARRAY(SELECT jsonb_array_elements_text(dss.surveyid_array))
                     WHEN dss.surveyid_text  IS NOT NULL
                     THEN string_to_array(dss.surveyid_text, ',')
                END
            ) AS surveyid
        ) AS flat_survey

    ), flattened_item_trxns AS (

        SELECT
            dss.locationid,
            dss.transactionheaderid,
            TRIM(flat_item.itemid)                                              AS itemid
        FROM delta_sent_surveys AS dss
        CROSS JOIN LATERAL (
            SELECT unnest(
                CASE WHEN dss.itemid_array IS NOT NULL
                     THEN ARRAY(SELECT jsonb_array_elements_text(dss.itemid_array))
                     WHEN dss.itemid_text  IS NOT NULL
                     THEN string_to_array(dss.itemid_text, ',')
                END
            ) AS itemid
        ) AS flat_item

    ), joined_surveys_with_items AS (

        SELECT
            st.organizationid,
            st.locationid,
            st.ordersessionid,
            st.transactionheaderid,
            st.gem_event_category,
            st.gem_event_type,
            st.surveyid,
            it.itemid,
            st.is_responded,
            st.gem_event_instant,
            st.gem_syscosmosts,
            st.sysinserttime,
            st.sysupdatetime
        FROM flattened_survey_trxns AS st
        LEFT JOIN flattened_item_trxns AS it
            ON  it.locationid          = st.locationid
            AND it.transactionheaderid = st.transactionheaderid

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
        itemid,
        is_responded,
        gem_event_instant,
        gem_syscosmosts,
        sysinserttime,
        sysupdatetime,
        sourceid
    )
    SELECT
        tds.organizationid,
        tds.locationid,
        tds.ordersessionid,
        tds.transactionheaderid,
        fact.parse_iso_timestamp(tds.gem_event_instant)     AS surveyissuedtimestamp,
        tds.gem_event_category,
        tds.gem_event_type,
        tds.surveyid,
        tds.itemid,
        tds.is_responded,
        tds.gem_event_instant,
        tds.gem_syscosmosts,
        tds.sysinserttime,
        tds.sysupdatetime,
        2                                                   AS sourceid
    FROM temp_delta_sent_surveys AS tds
    WHERE NOT EXISTS (
        SELECT 1 FROM fact.itemssurvey AS its
        WHERE its.organizationid = tds.organizationid
          AND its.locationid     = tds.locationid
          AND its.orderid        = tds.transactionheaderid
          AND its.surveyid       = tds.surveyid
          AND its.itemid         = tds.itemid
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(gem_syscosmosts), 1775002010) FROM fact.itemssurvey)
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'gem';

END;
$BODY$;

ALTER PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey()
    OWNER TO citus;



-- PROCEDURE: fact.usp_nge_itemssurvey_update()
--
-- Updates fact.itemssurvey with NGE item-level survey responses
-- from stg.fact_itemssurvey.
-- Update key : (locationid, orderid, surveyid, itemid)
-- Guard      : sysupdatetime IS NULL — only rows not yet responded to
-- Lookups    : dim.organizationlocation INNER JOIN
--              dim.occasionsurvey INNER JOIN — survey must exist in dim
-- is_responded = true when surveytransstatus = '2'

-- DROP PROCEDURE IF EXISTS fact.usp_nge_itemssurvey_update();

--SELECT * FROM fact.watermarktable;

CREATE OR REPLACE PROCEDURE fact.usp_nge_update_itemssurvey()
LANGUAGE 'plpgsql'
AS $BODY$

DECLARE
    v_max_nge_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_nge_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'nge';


    WITH delta_responses AS (

        SELECT DISTINCT ON (locationid, orderid, surveyid, itemid)
            locationid,
            orderid,
            surveyid,
            surveytransid,
            itemid,
            itemrating,
            surveytransstatus,
            surveycompletedtimestamp,
            nge_syscosmosts
        FROM stg.fact_itemssurvey
        WHERE nge_syscosmosts > v_max_nge_syscosmosts
        ORDER BY locationid, orderid, surveyid, itemid, nge_syscosmosts DESC

    )
    UPDATE fact.itemssurvey AS f
    SET
        organizationid              = COALESCE(os.organizationid, ol.organizationid),
        surveytransid               = dr.surveytransid,
        itemrating                  = dr.itemrating,
        surveytransstatus           = dr.surveytransstatus,
        surveycompletedtimestamp    = dr.surveycompletedtimestamp,
        nge_syscosmosts             = dr.nge_syscosmosts,
        is_responded                = CASE WHEN dr.surveytransstatus = '2'
                                          THEN true ELSE false END,
        sysupdatetime               = now() :: TIMESTAMP
    FROM delta_responses AS dr
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = dr.locationid
        AND th.transactionheaderid = dr.orderid
        AND th.orderstatus         = 'order-placed'
    INNER JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = dr.locationid
        AND ol.organizationtype = 0
    INNER JOIN dim.occasionsurvey AS os
        ON  os.organizationid = ol.organizationid
        AND os.surveyid       = dr.surveyid
    WHERE f.locationid    = dr.locationid
      AND f.orderid       = dr.orderid
      AND f.surveyid      = dr.surveyid
      AND f.itemid        = dr.itemid
      AND f.sysupdatetime IS NULL;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(nge_syscosmosts), 1775002010) FROM fact.itemssurvey)
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'nge';

END;
$BODY$;

ALTER PROCEDURE fact.usp_nge_update_itemssurvey()
    OWNER TO citus;