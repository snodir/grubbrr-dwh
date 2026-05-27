-- Table: fact.occasionsurveydetail

-- DROP TABLE IF EXISTS fact.occasionsurveydetail;

CREATE TABLE IF NOT EXISTS fact.occasionsurveydetail
(
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    surveyid text COLLATE pg_catalog."default",
    surveytransid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    surveyrating text COLLATE pg_catalog."default",
    surveytransstatus text COLLATE pg_catalog."default",
    surveyissuedtimestamp text COLLATE pg_catalog."default",
    surveycompletedtimestamp text COLLATE pg_catalog."default",
    surveylocaltimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    syscosmosts bigint,
    sourceid integer,
    surveytype integer,
    ordersessionid text COLLATE pg_catalog."default",
    CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid)
        REFERENCES fact.transactionheader (locationid, transactionheaderid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid)
        REFERENCES dim.organizationlocation (organizationid, locationid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT sourceid_fk FOREIGN KEY (sourceid)
        REFERENCES dim.grubbrr_source_lookup (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.occasionsurveydetail
    OWNER to citus;



CREATE TABLE IF NOT EXISTS stg.fact_occasionsurveydetail
(
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    surveyid text COLLATE pg_catalog."default",
    surveytransid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    surveyrating text COLLATE pg_catalog."default",
    surveytransstatus text COLLATE pg_catalog."default",
    surveyissuedtimestamp text COLLATE pg_catalog."default",
    surveycompletedtimestamp text COLLATE pg_catalog."default",
    surveylocaltimestamp timestamp without time zone,
    syscosmosts bigint,
    sourceid integer,
    surveytype integer,
    ordersessionid text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.fact_occasionsurveydetail
    OWNER to citus;


-- PROCEDURE: fact.usp_stg_occasionsurveydetail_to_fact()
--
-- Two separate insert streams into fact.occasionsurveydetail:
--   sourceid = 1 → NGE survey feedbacks     (stg.fact_occasionsurveydetail WHERE sourceid = 1)
--   sourceid = 2 → GEM skipped surveys      (stg.fact_occasionsurveydetail WHERE sourceid = 2)
--
-- Separate watermarks per sourceid because the two streams originate from
-- different Cosmos containers with independent _ts progressions.
--
-- No unique constraint on fact.occasionsurveydetail → NOT EXISTS is the sole
-- dedup gate; there is no ON CONFLICT safety net.

-- DROP PROCEDURE IF EXISTS fact.usp_stg_occasionsurveydetail_to_fact();

-- PROCEDURE: fact.usp_stg_occasionsurveydetail_to_fact()
--
-- Two separate insert streams into fact.occasionsurveydetail:
--   sourceid = 1 → NGE survey feedbacks   (stg.fact_occasionsurveydetail WHERE sourceid = 1)
--   sourceid = 2 → GEM skipped surveys    (stg.silver_kiosk_events WHERE eventmodule = 'kiosk'
--                                          AND eventcategory = 'survey' AND eventtype = 'skipped')
--
-- Separate watermarks per sourceid because the two streams originate from
-- different Cosmos containers with independent _ts progressions.
--
-- No unique constraint on fact.occasionsurveydetail → NOT EXISTS is the sole
-- dedup gate; there is no ON CONFLICT safety net.

-- DROP PROCEDURE IF EXISTS fact.usp_stg_occasionsurveydetail_to_fact();

CREATE OR REPLACE PROCEDURE fact.usp_stg_occasionsurveydetail_to_fact()
LANGUAGE 'plpgsql'
AS $BODY$

DECLARE
    v_max_syscosmosts_nge   BIGINT;
    v_max_syscosmosts_gem   BIGINT;
BEGIN

    -- Separate watermarks to avoid one source suppressing the other
    SELECT COALESCE(MAX(syscosmosts) - 10, 0)
    INTO v_max_syscosmosts_nge
    FROM fact.occasionsurveydetail
    WHERE sourceid = 1;

    SELECT COALESCE(MAX(syscosmosts) - 10, 0)
    INTO v_max_syscosmosts_gem
    FROM fact.occasionsurveydetail
    WHERE sourceid = 2;


    -- ================================================================
    -- Stream 1: NGE Survey Feedbacks (sourceid = 1)     [UNCHANGED]
    --
    -- Dedup key  : (locationid, surveytransid, orderid)
    -- Lookups    : dim.organizationlocation → organizationid
    --              dim.occasionsurvey       → validates survey exists
    -- Gate       : fact.transactionheader INNER JOIN (orderstatus = 'order-placed')
    -- ordersessionid resolved from transactionheader (not in Cosmos NGE source)
    -- ================================================================
    INSERT INTO fact.occasionsurveydetail (
        organizationid,
        locationid,
        dateid,
        surveyid,
        surveytransid,
        orderid,
        ordersessionid,
        surveyrating,
        surveytransstatus,
        surveycompletedtimestamp,
        surveylocaltimestamp,
        surveytype,
        sysinserttime,
        syscosmosts,
        sourceid
    )
    SELECT
        ol.organizationid,
        stg.locationid,
        stg.dateid,
        stg.surveyid,
        stg.surveytransid,
        stg.orderid,
        COALESCE(stg.ordersessionid, th.ordersessionid)                     AS ordersessionid,
        stg.surveyrating,
        stg.surveytransstatus,
        stg.surveycompletedtimestamp,
        stg.surveylocaltimestamp,
        COALESCE(
            stg.surveytype,
            CASE WHEN stg.surveyrating ~ '^\d+$' THEN 1 ELSE 2 END
        )                                                                   AS surveytype,
        now() :: TIMESTAMP                                                  AS sysinserttime,
        stg.syscosmosts,
        1                                                                   AS sourceid
    FROM stg.fact_occasionsurveydetail AS stg
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = stg.locationid
        AND th.transactionheaderid = stg.orderid
        AND th.orderstatus         = 'order-placed'
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = stg.locationid
        AND ol.organizationtype = 0
    INNER JOIN dim.occasionsurvey AS os
        ON  os.organizationid = ol.organizationid
        AND os.surveyid       = stg.surveyid
    WHERE stg.sourceid      = 1
      AND stg.syscosmosts   > v_max_syscosmosts_nge
      AND NOT EXISTS (
          SELECT 1
          FROM fact.occasionsurveydetail AS f
          WHERE f.locationid    = stg.locationid
            AND f.surveytransid = stg.surveytransid
            AND f.orderid       = stg.orderid
      );


    -- ================================================================
    -- Stream 2: GEM Skipped Surveys (sourceid = 2)      [MODIFIED]
    --
    -- Source     : stg.silver_kiosk_events (replaces stg.fact_occasionsurveydetail)
    -- Dedup key  : (locationid, ordersessionid) WHERE sourceid = 2
    -- Lookups    : dim.organizationlocation → organizationid
    -- Gate       : fact.transactionheader INNER JOIN on ordersessionid
    --              → resolves orderid = transactionheaderid
    --              → validates orderstatus = 'order-placed'
    -- Sparse insert: no surveyid, surveyrating, surveytransstatus, surveytype
    -- ================================================================
    WITH delta_skipped AS (

        -- Deduplicate within the incoming batch.
        -- A session could theoretically produce multiple 'skipped' events;
        -- keep the latest one by syscosmosts.
        SELECT DISTINCT ON (locationid, token)
            locationid,
            token           AS ordersessionid,
            eventinstant    AS surveycompletedtimestamp,
            syscosmosts
        FROM stg.silver_kiosk_events
        WHERE eventmodule               = 'kiosk'
          AND LOWER(eventcategory)      = 'survey'
          AND LOWER(eventtype)          = 'skipped'
          AND syscosmosts               > v_max_syscosmosts_gem
        ORDER BY locationid, token, syscosmosts DESC

    )
    INSERT INTO fact.occasionsurveydetail (
        organizationid,
        locationid,
        orderid,
        ordersessionid,
        surveycompletedtimestamp,
        sysinserttime,
        syscosmosts,
        sourceid
    )
    SELECT
        ol.organizationid,
        ds.locationid,
        th.transactionheaderid          AS orderid,
        ds.ordersessionid,
        ds.surveycompletedtimestamp,
        now() :: TIMESTAMP              AS sysinserttime,
        ds.syscosmosts,
        2                               AS sourceid
    FROM delta_skipped AS ds
    -- Resolves orderid and validates the order exists and was placed
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid     = ds.locationid
        AND th.ordersessionid = ds.ordersessionid
        AND th.orderstatus    = 'order-placed'
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = ds.locationid
        AND ol.organizationtype = 0
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.occasionsurveydetail AS f
        WHERE f.locationid    = ds.locationid
          AND f.ordersessionid = ds.ordersessionid
          AND f.sourceid      = 2
    );

END;
$BODY$;

ALTER PROCEDURE fact.usp_stg_occasionsurveydetail_to_fact()
    OWNER TO citus;