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