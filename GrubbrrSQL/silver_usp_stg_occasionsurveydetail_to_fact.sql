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
    -- Stream 1: NGE Survey Feedbacks (sourceid = 1)
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
        ol.organizationid,                                                  -- COALESCE(os.organizationid, ol.organizationid) in ADF
        stg.locationid,                                                     -- they are equal after INNER JOIN on os.organizationid = ol.organizationid
        stg.dateid,
        stg.surveyid,
        stg.surveytransid,
        stg.orderid,
        COALESCE(stg.ordersessionid, th.ordersessionid)                     AS ordersessionid,
        stg.surveyrating,
        stg.surveytransstatus,
        stg.surveycompletedtimestamp,
        stg.surveylocaltimestamp,
        -- surveytype: 1 = numeric rating, 2 = text rating
        -- mirrors ADF: case(isInteger(surveyrating), 1, 2)
        COALESCE(
            stg.surveytype,
            CASE WHEN stg.surveyrating ~ '^\d+$' THEN 1 ELSE 2 END
        )                                                                   AS surveytype,
        now() :: TIMESTAMP                                                  AS sysinserttime,
        stg.syscosmosts,
        1                                                                   AS sourceid
    FROM stg.fact_occasionsurveydetail AS stg
    -- Order must exist and be placed
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = stg.locationid
        AND th.transactionheaderid = stg.orderid
        AND th.orderstatus         = 'order-placed'
    -- Resolve organizationid; mirrors ADF: organisationtype = 0 filter
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = stg.locationid
        AND ol.organizationtype = 0
    -- Survey must exist in dim — mirrors ADF INNER JOIN on (organizationid, surveyid)
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
    -- Stream 2: GEM Skipped Surveys (sourceid = 2)
    --
    -- Dedup key  : (locationid, ordersessionid) WHERE sourceid = 2
    -- Lookups    : dim.organizationlocation → organizationid
    -- Gate       : fact.transactionheader INNER JOIN (orderstatus = 'order-placed')
    -- orderid in stg = transactionheaderid (resolved during staging process)
    -- Sparse insert: no surveyid, surveyrating, surveytransstatus, surveytype
    -- ================================================================
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
        stg.locationid,
        stg.orderid,
        stg.ordersessionid,
        stg.surveycompletedtimestamp,
        now() :: TIMESTAMP      AS sysinserttime,
        stg.syscosmosts,
        2                       AS sourceid
    FROM stg.fact_occasionsurveydetail AS stg
    -- Order must exist and be placed
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = stg.locationid
        AND th.transactionheaderid = stg.orderid
        AND th.orderstatus         = 'order-placed'
    -- Resolve organizationid
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = stg.locationid
        AND ol.organizationtype = 0
    WHERE stg.sourceid      = 2
      AND stg.syscosmosts   > v_max_syscosmosts_gem
      AND NOT EXISTS (
          SELECT 1
          FROM fact.occasionsurveydetail AS f
          WHERE f.locationid    = stg.locationid
            AND f.ordersessionid = stg.ordersessionid
            AND f.sourceid      = 2
      );

END;
$BODY$;

ALTER PROCEDURE fact.usp_stg_occasionsurveydetail_to_fact()
    OWNER TO citus;