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
    modifier_impressions jsonb,
    modifier_interactions jsonb,
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

SELECT * FROM fact.modifier_recommendations
--CALL fact.usp_recommendations_stage_to_fact();
CREATE OR REPLACE PROCEDURE fact.usp_item_recommendations_stage_to_fact()
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

END;
$BODY$;

ALTER PROCEDURE fact.usp_item_recommendations_stage_to_fact()
OWNER TO citus;

--CALL fact.usp_modifier_recommendations_stage_to_fact();
CREATE OR REPLACE PROCEDURE fact.usp_modifier_recommendations_stage_to_fact()
LANGUAGE plpgsql
AS $BODY$

BEGIN

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

UPDATE fact.modifier_recommendations
SET orderdatelocal = orderdateutc::TIMESTAMPTZ AT TIME ZONE l.timezone
FROM (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end as timezone from dim.location) as l
WHERE modifier_recommendations.locationid = l.locationid 
  AND modifier_recommendations.orderdatelocal is null;

UPDATE fact.watermarktable
SET ts = (SELECT max(syscosmosts) FROM fact.modifier_recommendations)
WHERE watermarktablename = 'fact.modifier_recommendations'
  AND source = 'nge';

END;
$BODY$;

ALTER PROCEDURE fact.usp_modifier_recommendations_stage_to_fact()
OWNER TO citus;

SELECT * FROM fact.modifier_impressions;
SELECT * FROM fact.modifier_interactions;
--CALL fact.usp_modifier_recommendation_analysis();
CREATE OR REPLACE PROCEDURE fact.usp_modifier_recommendation_analysis()
LANGUAGE plpgsql
AS $BODY$

BEGIN

WITH delta_impressions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_impressions')
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_impressions as mim 
                  WHERE mim.locationid = mrc.locationid
                    AND mim.transactionheaderid = mrc.transactionheaderid)
), modifier_impressions AS (
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
      (rec->>'score')::NUMERIC(5, 3)         AS score,
       outer_elem->>'strategy'               AS strategy,
       outer_elem->>'context'                AS context,
      (rec->>'selected')::boolean            AS selected,
      (rec->>'preDeselected')::boolean       AS pre_deselected,
      (rec->>'confirmedRemoved')::boolean    AS confirmed_removed,
      (rec->>'preSelected')::boolean         AS pre_selected,
       mrc.businessdate, 
       mrc.orderdatelocal,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime    
FROM delta_impressions as mrc,
    -- Step 1: unnest the top-level array
    jsonb_array_elements(modifier_impressions) AS outer_elem,
    -- Step 2: unnest the nested recommendations array
    jsonb_array_elements(outer_elem->'recommendations') AS rec
)
INSERT INTO fact.modifier_impressions
SELECT *, NULL :: TIMESTAMP as sysupdatetime
FROM modifier_impressions;

UPDATE fact.watermarktable
SET ts = (SELECT max(syscosmosts) - 10 FROM fact.modifier_impressions)
WHERE watermarktablename = 'fact.modifier_impressions'
  AND source = 'nge';

WITH delta_interactions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_interactions')
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_interactions as mim 
                  WHERE mim.locationid = mrc.locationid
                    AND mim.transactionheaderid = mrc.transactionheaderid)
), modifier_interactions AS (
SELECT mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       mrc.orderid,
       outer_elem->>'itemId' as menuitemid,
       outer_elem->>'action' as action,
       outer_elem->>'modifierId' as modifierid,
       (outer_elem->>'recordedAt')::TIMESTAMP as recorded_at,
       (outer_elem->>'nestingDepth') :: INTEGER as nesting_depth,
       outer_elem->>'selectionType' as selection_type,
       outer_elem->>'modifierGroupId' as modifiergroupid,
       outer_elem->>'parentModifierId' as parent_modifier_id,
       mrc.businessdate, 
       mrc.orderdatelocal,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime    
FROM delta_interactions as mrc,
    -- Step 1: unnest the top-level array
    jsonb_array_elements(modifier_interactions) AS outer_elem
), trxn_enrichment AS (
SELECT mi.locationid,
       mi.transactionheaderid,
       mi.ordersessionid,
       mi.orderid,
       imd.itemid as orderitemid,
       mi.menuitemid,
       mi.modifiergroupid,
       mi.modifierid,
       imd.modifiername,
       mi.parent_modifier_id,
       mi.nesting_depth,
       imd.modifierquantity,
       imd.modifierprice,
       imd.freequantity,
       mi.selection_type,
       mi.action,
       mi.recorded_at as session_recorded_at,
       mi.businessdate,
       mi.orderdatelocal,
       mi.frequentcustomerid,
       mi.syscosmosts,
       mi.sysinserttime
    FROM modifier_interactions as mi 
    LEFT JOIN fact.transactionitem as ti 
        ON mi.locationid = ti.locationid
        AND mi.transactionheaderid = ti.transactionheaderid
        AND mi.menuitemid = ti.dimmenuitemid
    LEFT JOIN fact.itemmodifier as imd 
        ON mi.transactionheaderid = imd.transactionheaderid
        AND ti.itemid = imd.itemid
        AND mi.modifiergroupid = imd.modifiergroupid
        AND mi.modifierid = imd.modifierid
)
INSERT INTO fact.modifier_interactions
SELECT *, NULL :: TIMESTAMP as sysupdatetime
FROM trxn_enrichment;

UPDATE fact.watermarktable
SET ts = (SELECT max(syscosmosts) - 10 FROM fact.modifier_interactions)
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge';

END;
$BODY$;


/*
{
        "action": "added",
        "itemId": "itm-5d097ea8-f777-4133-9611-78a242c27a62",
        "modifierId": "modfr-667d144f-1609-4445-a00e-14385a589632",
        "recordedAt": null,
        "nestingDepth": 0,
        "selectionType": "optional",
        "modifierGroupId": "modgrp-d9ca644e-0da9-4674-a763-5bf9841d7d63",
        "parentModifierId": null
    }
*/








CREATE TABLE IF NOT EXISTS fact.modifier_impressions
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    parent_modifier_id text COLLATE pg_catalog."default",
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

ALTER TABLE fact.modifier_impressions
OWNER to citus;

CREATE TABLE IF NOT EXISTS fact.modifier_interactions
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    orderitemid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    modifiergroupid text COLLATE pg_catalog."default" NOT NULL,
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    modifiername text COLLATE pg_catalog."default",
    parent_modifier_id text COLLATE pg_catalog."default",
    nesting_depth INTEGER,
    modifierquantity INTEGER,
    modifierprice numeric(12,3),
    freequantity integer,
    selection_type text COLLATE pg_catalog."default",
    action text COLLATE pg_catalog."default",
    session_recorded_at text COLLATE pg_catalog."default",
    businessdate date,
    orderdatelocal timestamp,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts BIGINT,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT trxnid_menuitemid_modfrgrpid_modfrid_pk PRIMARY KEY (transactionheaderid, menuitemid, modifiergroupid, modifierid)
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

UPDATE fact.modifier_recommendations
SET syscosmosts = 1775164585

INSERT INTO fact.modifier_recommendations (
    locationid,
    transactionheaderid,
    ordersessionid,
    orderid,
    modifier_impressions,
    modifier_interactions,
    businessdate,
    orderdateutc,
    orderdatelocal,
    frequentcustomerid,
    syscosmosts,
    sysinserttime,
    sysupdatetime
)
VALUES (
    'loc-b30f55b4-fc0b-40b7-af00-29bb2f653c1e',
    'ordevt-RDNOLBCL2HQDCLN2',
    'RDNOLBCL2HQDCLN2',
    'ord-0253178a-ca9a-4957-9f2a-b4bdc82173b3',
    '[{"itemId":"itm-5d097ea8-f777-4133-9611-78a242c27a62","selectionType":"default","nestingDepth":0,"parentModifierId":null,"strategy":"default","recommendations":[{"modifierId":"modfr-667d144f-1609-4445-a00e-14385a589632","score":0,"position":0,"selected":true,"preDeselected":null,"confirmedRemoved":null,"preSelected":null},{"modifierId":"modfr-e8effaad-58cc-4e00-8b74-ce6e7db44a69","score":0,"position":1,"selected":true,"preDeselected":null,"confirmedRemoved":null,"preSelected":null},{"modifierId":"modfr-761dff41-eec7-4ee0-942c-15dffef94b00","score":0,"position":2,"selected":true,"preDeselected":null,"confirmedRemoved":null,"preSelected":null},{"modifierId":"modfr-792ab6ea-2bc7-49bd-9236-e6dd1d487a33","score":0,"position":3,"selected":null,"preDeselected":null,"confirmedRemoved":null,"preSelected":null},{"modifierId":"modfr-d4467e17-2dee-4d64-a597-9f1c702baf4d","score":0,"position":4,"selected":null,"preDeselected":null,"confirmedRemoved":null,"preSelected":null}],"context":null}]':: jsonb,
    '[{"itemId":"itm-5d097ea8-f777-4133-9611-78a242c27a62","modifierId":"modfr-667d144f-1609-4445-a00e-14385a589632","modifierGroupId":"modgrp-d9ca644e-0da9-4674-a763-5bf9841d7d63","selectionType":"optional","action":"added","nestingDepth":0,"parentModifierId":null,"recordedAt":null},{"itemId":"itm-5d097ea8-f777-4133-9611-78a242c27a62","modifierId":"modfr-e8effaad-58cc-4e00-8b74-ce6e7db44a69","modifierGroupId":"modgrp-d9ca644e-0da9-4674-a763-5bf9841d7d63","selectionType":"optional","action":"added","nestingDepth":0,"parentModifierId":null,"recordedAt":null},{"itemId":"itm-5d097ea8-f777-4133-9611-78a242c27a62","modifierId":"modfr-761dff41-eec7-4ee0-942c-15dffef94b00","modifierGroupId":"modgrp-d9ca644e-0da9-4674-a763-5bf9841d7d63","selectionType":"optional","action":"added","nestingDepth":0,"parentModifierId":null,"recordedAt":null}]' :: jsonb,
    '2026-04-02',
    '2026-04-02T21:16:22.4537275Z',
    NULL,   -- orderdatelocal: not present in source; populate if a local TZ conversion is available
    NULL,   -- frequentcustomerid: null in source
    NULL,   -- syscosmosts: system-generated, populate as needed
    NOW(),  -- sysinserttime
    NOW()   -- sysupdatetime
);