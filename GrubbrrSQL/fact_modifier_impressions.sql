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

update fact.modifier_recommendations
set orderdatelocal = orderdateutc::TIMESTAMPTZ AT TIME ZONE l.timezone
from (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end as timezone from dim.location) as l
where modifier_recommendations.locationid = l.locationid 
  and modifier_recommendations.orderdatelocal is null;

END;
$BODY$;

ALTER PROCEDURE fact.usp_recommendations_stage_to_fact()
OWNER TO citus;


--CALL fact.usp_recommendations_stage_to_fact();
CREATE OR REPLACE PROCEDURE fact.usp_modifier_recommendation_analysis()
LANGUAGE plpgsql
AS $BODY$

WITH modifier_impressions AS (
SELECT mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       mrc.orderid,
       outer_elem->>'itemId'                 AS menuitemid,
       rec->>'modifierId'                    AS modifierid,
       outer_elem->>'parentModifierId'       AS parent_modifier_id,
       outer_elem->>'selectionType'          AS selection_type,
      (outer_elem->>'nestingDepth')::INTEGER AS nesting_depth,    
      (rec->>'position')::INTEGER            AS position,
      (rec->>'score')::numeric               AS score,
       outer_elem->>'strategy'               AS strategy,
       outer_elem->>'context'                AS context,
      (rec->>'selected')::boolean            AS selected,
      (rec->>'preDeselected')::boolean       AS pre_deselected,
      (rec->>'confirmedRemoved')::boolean    AS confirmed_removed,
      (rec->>'preSelected')::boolean         AS pre_selected
       mrc.businessdate, 
       mrc.orderdatelocal,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime    
FROM fact.modifier_recommendations as mrc,
    -- Step 1: unnest the top-level array
    jsonb_array_elements(modifier_impression) AS outer_elem,
    -- Step 2: unnest the nested recommendations array
    jsonb_array_elements(outer_elem->'recommendations') AS rec;
)










CREATE TABLE IF NOT EXISTS fact.modifier_impressions
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    parent_modifier_id text COLLATE pg_catalog."default" NOT NULL,
    selection_type text COLLATE pg_catalog."default",
    nesting_depth INTEGER,
    position INTEGER,
    score NUMERIC(5, 3),
    strategy text COLLATE pg_catalog."default",
    context text COLLATE pg_catalog."default",
    selected BOOLEAN,
    pre_deselected BOOLEAN,
    confirmed_removed BOOLEAN,
    pre_selected BOOLEAN,
    businessdate date,
    orderdatelocal timestamp,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts BIGINT,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
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