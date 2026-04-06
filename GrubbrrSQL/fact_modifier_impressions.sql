CREATE TABLE IF NOT EXISTS stg.modifier_recommendation_sessions
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    modifier_impressions text COLLATE pg_catalog."default",
    modifier_interactions text COLLATE pg_catalog."default",
    businessdate date,
    orderdateutc text COLLATE pg_catalog."default",
    orderdatelocal TIMESTAMP,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts BIGINT,
    sysinserttime TIMESTAMP,
    sysupdatetime TIMESTAMP
);

ALTER TABLE stg.modifier_recommendation_sessions
OWNER TO citus;

CREATE TABLE IF NOT EXISTS fact.modifier_recommendations
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    modifier_impressions text COLLATE pg_catalog."default",
    modifier_interactions text COLLATE pg_catalog."default",
    businessdate date,
    orderdateutc text COLLATE pg_catalog."default",
    orderdatelocal TIMESTAMP,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts BIGINT,
    sysinserttime TIMESTAMP,
    sysupdatetime TIMESTAMP
);

ALTER TABLE fact.modifier_recommendations
OWNER TO citus;

--CALL fact.usp_recommendations_stage_to_fact();
CREATE OR REPLACE PROCEDURE fact.usp_recommendations_stage_to_fact()
LANGUAGE plpgsql
AS $BODY$

BEGIN

insert into fact.recommendations 
(transactionheaderid, locationid, recommendationid, offereditems, selecteditems, isconverted, prompttimestamp, sysinserttime, syscosmosts)
select rc.transactionheaderid,
       rc.locationid,
       rc.recommendationid, 
       rc.offereditems :: jsonb, 
       rc.selecteditems :: jsonb, 
       case when (rc.selecteditems = '[]' or rc.selecteditems is null) then false else true end as isconverted,
       rc.prompttimestamp, 
       rc.sysinserttime,
       rc.syscosmosts
from stg.recommendations as rc
where not exists (select 1 from fact.recommendations as th where th.transactionheaderid = rc.transactionheaderid and th.recommendationid = rc.recommendationid);

insert into fact.modifier_recommendations 
(locationid, transactionheaderid, ordersessionid, orderid, modifier_impressions, modifier_interactions, 
 businessdate, orderdateutc, frequentcustomerid, syscosmosts, sysinserttime)
select mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       mrc.orderid,
       mrc.modifier_impressions :: jsonb, 
       mrc.modifier_interactions :: jsonb, 
       mrc.businessdate, 
       mrc.orderdateutc,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime
from stg.modifier_recommendation_sessions as mrc
where not exists (select 1 from fact.modifier_recommendations as mr where mr.locationid = mrc.locationid and mr.transactionheaderid = mrc.transactionheaderid);

END;
$BODY$;

ALTER PROCEDURE fact.usp_recommendations_stage_to_fact()
OWNER TO citus;

CREATE TABLE IF NOT EXISTS fact.modifier_impressions
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    orderitemid text COLLATE pg_catalog."default" NOT NULL,
    menuitemid text COLLATE pg_catalog."default",
    modifiergroupid text COLLATE pg_catalog."default" NOT NULL,
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    modifiername text COLLATE pg_catalog."default",
    modifierquantity smallint,
    modifierprice numeric(12,3),
    freequantity integer,
    selectiontype text COLLATE pg_catalog."default",
    action text COLLATE pg_catalog."default",
    businessdate date,
    orderdatelocal timestamp,
    frequentcustomerid text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT trxnid_itemid_modfrgrpid_modfrid_pk PRIMARY KEY (transactionheaderid, orderitemid, modifiergroupid, modifierid)
);

ALTER TABLE fact.modifier_interactions
OWNER to citus;


SELECT *
FROM fact.deviceevent as de
WHERE 1=1
AND de.application = 'nge'
AND de.companyid = 'org-d54ec735-238b-454f-ba73-6ec9d3a7a955' --
AND de.locationid = 'loc-56db8917-3e54-4be9-941b-5d2d4a5a4c22' --
AND de.moduleid = 'kiosk'
--AND de.eventtoken = 'ZUADG48O7E1H3AFI'
AND de.datacategory = 'insight'
AND LOWER(de.actiontype) LIKE '%modifier%'
--AND de.dateid = 2026022014
ORDER BY de.eventinstant DESC 
LIMIT 1000