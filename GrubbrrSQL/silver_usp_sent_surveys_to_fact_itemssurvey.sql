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



-- PROCEDURE: fact.usp_sent_surveys_to_fact_itemssurvey()

-- DROP PROCEDURE IF EXISTS fact.usp_sent_surveys_to_fact_itemssurvey();

CREATE OR REPLACE PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey(
	)
LANGUAGE plpgsql
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

