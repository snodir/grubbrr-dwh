--New table in all environments
--drop table if EXISTS fact.occasionsurveydetail;
CREATE TABLE IF NOT EXISTS fact.occasionsurveydetail
(
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    surveytransid text COLLATE pg_catalog."default",
    surveytransstatus text COLLATE pg_catalog."default",
    surveyissuedtimestamp text COLLATE pg_catalog."default",
    surveycompletedtimestamp text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    surveyid text COLLATE pg_catalog."default",
    surveyrating text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE fact.occasionsurveydetail
    OWNER to citus;
