--New table in all environments
--drop table if EXISTS fact.itemssurvey;
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
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE fact.itemssurvey
    OWNER to citus;
