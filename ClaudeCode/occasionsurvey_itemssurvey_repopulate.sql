-- Table: fact.occasionsurveydetail

-- DROP TABLE IF EXISTS fact.occasionsurveydetail;


CREATE TABLE IF NOT EXISTS fact.occasionsurveydetail_bkp
(
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,
    dateid integer,
    surveytransid text COLLATE pg_catalog."default",
    surveytransstatus text COLLATE pg_catalog."default",
    surveyissuedtimestamp text COLLATE pg_catalog."default",
    surveycompletedtimestamp text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default" NOT NULL,
    surveyid text COLLATE pg_catalog."default",
    surveyrating text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    surveylocaltimestamp timestamp without time zone,
    syscosmosts bigint,
    sourceid integer,
    surveytype integer,
    ordersessionid text COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.occasionsurveydetail_bkp
    OWNER to citus;

-- DROP INDEX IF EXISTS fact.occasionsurveydetail_locationid_dateid_idx;

CREATE INDEX IF NOT EXISTS occasionsurveydetail_locationid_dateid_idx
    ON fact.occasionsurveydetail USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(surveyrating, orderid, surveytransstatus)
    TABLESPACE pg_default;


--INSERT INTO fact.occasionsurveydetail_bkp
SELECT * FROM fact.occasionsurveydetail

INSERT INTO fact.occasionsurveydetail(
    organizationid,
    locationid,
    dateid,
    surveyid,
    surveytransid,
    orderid,
    surveyrating,
    surveytransstatus,
    surveyissuedtimestamp,
    surveycompletedtimestamp,
    surveylocaltimestamp,
    sysinserttime,
    syscosmosts,
    sourceid,
    surveytype,
    ordersessionid)
SELECT 
    organizationid,
    locationid,
    dateid,
    surveyid,
    surveytransid,
    orderid,
    surveyrating,
    surveytransstatus,
    surveyissuedtimestamp,
    surveycompletedtimestamp,
    surveylocaltimestamp,
    sysinserttime,
    syscosmosts,
    sourceid,
    surveytype,
    ordersessionid
FROM fact.occasionsurveydetail_bkp


-- Table: fact.itemssurvey

-- DROP TABLE IF EXISTS fact.itemssurvey;

CREATE TABLE IF NOT EXISTS fact.itemssurvey
(
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,
    dateid integer,
    surveyid text COLLATE pg_catalog."default",
    surveytransid text COLLATE pg_catalog."default" NOT NULL,
    orderid text COLLATE pg_catalog."default" NOT NULL,
    itemid text COLLATE pg_catalog."default" NOT NULL,
    itemrating text COLLATE pg_catalog."default",
    surveytransstatus text COLLATE pg_catalog."default",
    surveyissuedtimestamp text COLLATE pg_catalog."default",
    surveycompletedtimestamp text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    surveylocaltimestamp timestamp without time zone,
    nge_syscosmosts bigint,
    ordersessionid text COLLATE pg_catalog."default",
    gem_event_category text COLLATE pg_catalog."default",
    gem_event_type text COLLATE pg_catalog."default",
    is_responded boolean,
    gem_syscosmosts bigint,
    gem_event_instant text COLLATE pg_catalog."default",
    sysupdatetime timestamp without time zone,
    sourceid integer,
    CONSTRAINT locationid_orderid_surveytransid_itemid_pk PRIMARY KEY (locationid, orderid, surveytransid, itemid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.itemssurvey
    OWNER to citus;

-- DROP INDEX IF EXISTS fact.locationid_dateid_idx;

CREATE INDEX IF NOT EXISTS locationid_dateid_idx
    ON fact.itemssurvey USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(itemrating)
    TABLESPACE pg_default;