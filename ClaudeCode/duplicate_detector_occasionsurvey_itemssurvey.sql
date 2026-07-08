SELECT *
FROM fact.occasionsurveydetail
--WHERE dateid IS NULL
ORDER BY syscosmosts DESC NULLS LAST;

SELECT *
FROM stg.fact_occasionsurveydetail

SELECT locationid, orderid, surveyid, surveytransid, COUNT(*)
FROM fact.occasionsurveydetail
GROUP BY locationid, orderid, surveyid, surveytransid
HAVING COUNT(*) > 1;

ALTER TABLE IF EXISTS fact.occasionsurveydetail
ADD CONSTRAINT location_orderid_surveyid_surveytrxnid_unq UNIQUE (locationid, orderid, surveyid, surveytransid)

DELETE 
FROM fact.occasionsurveydetail t
USING (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY locationid, orderid, surveyid, surveytransid
            ORDER BY syscosmosts DESC, ctid DESC
        ) AS rn
    FROM fact.occasionsurveydetail
) dedup
WHERE t.ctid = dedup.ctid
  AND dedup.rn > 1;




--fact.itemssurvey
SELECT ol.organizationname, ol.locationname, its.*
FROM fact.itemssurvey as its 
LEFT JOIN dim.organizationlocation as ol 
    ON ol.organizationid   = its.organizationid
   AND ol.locationid       = its.locationid
   AND ol.organizationtype = 0
WHERE 1=1 
  --AND locationid IN ('loc-a86dc5f7-c575-4eed-9fd4-18290bc06052', 'loc-8ef0f09d-76fd-4bce-af56-40182bc73c26')
  --AND orderid IS NULL
  --AND dateid IS NULL
ORDER BY nge_syscosmosts DESC NULLS LAST 
LIMIT 10000;

SELECT locationid, orderid, itemid, surveyid, surveytransid, COUNT(*)--locationid, 
FROM fact.itemssurvey
GROUP BY locationid, orderid, itemid, surveyid, surveytransid--locationid, 
HAVING COUNT(*) > 1;

ALTER TABLE IF EXISTS fact.itemssurvey
ADD CONSTRAINT location_orderid_itemid_surveyid_surveytrxnid_unq UNIQUE (locationid, orderid, itemid, surveyid, surveytransid)

SELECT th.locationid, th.transactionheaderid, its.orderid, its.itemid, its.surveyid, its.surveytransid
FROM fact.itemssurvey as its 
INNER JOIN fact.transactionheader as th 
        ON th.locationid     = its.locationid
       AND th.ordersessionid = its.ordersessionid
WHERE 1=1 
  AND its.locationid IN ('loc-a86dc5f7-c575-4eed-9fd4-18290bc06052', 'loc-8ef0f09d-76fd-4bce-af56-40182bc73c26')
  AND its.orderid IS NULL


UPDATE fact.itemssurvey
SET orderid = th.transactionheaderid
FROM fact.transactionheader AS th 
WHERE itemssurvey.locationid     = th.locationid
  AND itemssurvey.ordersessionid = th.ordersessionid  
  AND itemssurvey.locationid     IN ('loc-a86dc5f7-c575-4eed-9fd4-18290bc06052', 'loc-8ef0f09d-76fd-4bce-af56-40182bc73c26')
  AND itemssurvey.orderid        IS NULL
  AND itemssurvey.itemid         IS NULL
  AND itemssurvey.surveyid       IS NOT NULL;

--DELETE 
FROM fact.itemssurvey t
USING (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY locationid, orderid, itemid, surveyid, surveytransid
            ORDER BY nge_syscosmosts DESC, ctid DESC
        ) AS rn
    FROM fact.itemssurvey
) dedup
WHERE t.ctid = dedup.ctid
  AND dedup.rn > 1;



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
    --CONSTRAINT location_orderid_surveyid_surveytrxnid_unq UNIQUE (locationid, orderid, surveyid, surveytransid),
    /*CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid)
        REFERENCES fact.transactionheader (locationid, transactionheaderid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid)
        REFERENCES dim.organizationlocation (organizationid, locationid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,*/
    CONSTRAINT sourceid_fk FOREIGN KEY (sourceid)
        REFERENCES dim.grubbrr_source_lookup (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.occasionsurveydetail
    OWNER to citus;


CREATE INDEX IF NOT EXISTS occasionsurveydetail_locationid_dateid_idx
    ON fact.occasionsurveydetail USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(surveyrating, orderid, surveytransstatus)
    TABLESPACE pg_default;

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
    CONSTRAINT location_orderid_itemid_surveyid_surveytrxnid_unq UNIQUE (locationid, orderid, itemid, surveyid, surveytransid),
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

CREATE INDEX IF NOT EXISTS locationid_dateid_idx
    ON fact.itemssurvey USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(itemrating)
    TABLESPACE pg_default;