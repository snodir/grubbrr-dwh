CREATE TABLE IF NOT EXISTS dim.locationcatalog
(
    id bigint NOT NULL,
    organizationid text COLLATE pg_catalog."default" NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    locationname text COLLATE pg_catalog."default",
    catalogid text COLLATE pg_catalog."default",
    timezone text COLLATE pg_catalog."default",
    menuid text COLLATE pg_catalog."default",
    CONSTRAINT location_ctlg_pk PRIMARY KEY (organizationid, locationid)
)

TABLESPACE pg_default;

ALTER TABLE dim.locationcatalog
    OWNER to citus;

SELECT o.organizationid, o.organizationname,
       o.locationid, o.locationname,
       loc.createdon, loc.modifiedon, loc.active as is_loc_active,
       CASE loc.status WHEN 0 THEN 'Draft' WHEN 1 THEN 'Onboarding' WHEN 2 THEN 'Live' WHEN 3 THEN 'Cancelled' END as location_status
FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as o 
INNER JOIN (SELECT * FROM dim.organization WHERE status <> 2) as loc 
        ON o.locationid = loc.id
WHERE 1=1
  AND active = False
ORDER by createdon desc;

--/TRUNCATE TABLE dim.locationcatalog;

select organizationid, count(*)
from dim.organizationlocation
--where organizationtype = 0
group by organizationid
order by organizationid;

select locationid, count(*)
from dim.organizationlocation
where organizationtype = 0
group by locationid
having count(*) > 1
order by locationid;

select * from dim.organizationlocation 
where locationid = 'org-2ad9799e-2df3-4ebb-9563-8772f5638552'

SELECT * 
from dim.LOCATION;

SELECT *
FROM dim.locationcatalog;

/***Columns to be added to the vw_grubbrrinstallbase
1. Status (0-draft, 1-onboarding, 2-live, 3-cancelled)
2. Go-Live date
3. CEP - Complex Event Processing
3. ECM and non-ECM
***/

/***Columns to be added to the dim.organization
1. roundupforcharity
2. is_ecm_enabled
3. is_cep_enabled
4. is_concessionaire_enabled
5. is_smart_upsells_enabled
6. is_feedback_survey_enabled
7. is_digital_menu_board_enabled
8. is_digital_menu_default_format_enabled
***/

SELECT count(*)
from dim.organization as o --3816

SELECT count(*) OVER(PARTITION by id) as dupl, *
from dim.organization as o --3816
--GROUP BY id 
ORDER BY dupl desc

SELECT count(*) OVER(PARTITION by organizationid, locationid) as dupl, *
from dim.organizationlocation as o --3816
--GROUP BY id 
ORDER BY dupl desc, organizationid, locationid

ALTER TABLE dim.organizationlocation
add roundupforcharity BOOLEAN;

ALTER TABLE dim.organization
add roundupforcharity BOOLEAN,
add is_ecm_enabled BOOLEAN,
add is_cep_enabled BOOLEAN,
add is_concessionaire_enabled BOOLEAN,
add is_smart_upsells_enabled BOOLEAN,
add is_feedback_survey_enabled BOOLEAN,
add is_digital_menu_board_enabled BOOLEAN,
add is_digital_menu_default_format_enabled BOOLEAN

/*UPDATE dim.organizationlocation
SET roundupforcharity = o.roundupforcharity
FROM dim.organization as o
WHERE organizationlocation.locationid = o.id;

SELECT 1 AS rn;*/

WITH cte AS (
SELECT distinct ol.organizationid,
       ol.organizationname,
       ol.locationid,
       ol.locationname,
       ol.organizationtype,
       sum(case when o.roundupforcharity = True then 1 else 0 end) over(partition by ol.organizationid) as org_level_roundup_for_charity,
       count(*) over(partition by ol.organizationid) as count_by_org --locationid
FROM dim.organizationlocation as ol --mapping of organizations and its locations 2,570
INNER JOIN dim.organization as o 
        on ol.locationid = o.id
where 1=1
--and ol.organizationtype = 0
--order by count_by_org desc, ol.organizationid
)
UPDATE dim.organizationlocation
   SET roundupforcharity = case when cte.org_level_roundup_for_charity > 0 then True else False end
FROM cte 
WHERE organizationlocation.organizationid = cte.organizationid
  AND organizationlocation.locationid = cte.locationid


SELECT o.organizationid, o.organizationname,
       o.locationid, o.locationname,
       loc.createdon, loc.modifiedon, loc.active as is_loc_active, org.active as is_org_active
FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as o 
LEFT JOIN (SELECT * FROM dim.organization WHERE active = False) as loc 
        ON o.locationid = loc.id
LEFT JOIN (SELECT * FROM dim.organization WHERE active = False) as org 
        ON o.organizationid = org.id
WHERE 1=1
  AND active = False
ORDER by createdon desc;

SELECT o.organizationid, o.organizationname,
       o.locationid, o.locationname,
       loc.createdon, loc.modifiedon, loc.active as is_loc_active,
       CASE loc.status WHEN 0 THEN 'Draft' WHEN 1 THEN 'Onboarding' WHEN 2 THEN 'Live' WHEN 3 THEN 'Cancelled' END as location_status
FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as o 
INNER JOIN (SELECT * FROM dim.organization WHERE status <> 2) as loc 
        ON o.locationid = loc.id
WHERE 1=1
  AND active = False
ORDER by createdon desc;

--and organizationtype = 1
--and roundupforcharity is not null
--and isdeleted = False


select *, count(*) over(partition by locationid) as count_by_loc
from dim.organizationlocation 
where 1=1
--and organizationid = 'org-42a2fc0d-1696-4fd9-8c9e-dc5504f903c2'
--and locationid = 'loc-45d0f6d6-47b2-4524-b350-a1451aa24b62' --(SELECT id from dim.organization where roundupforcharity is not null)
and organizationtype = 1
order by count_by_loc desc, locationid;

SELECT * 
from dim.LOCATION;

select locationid, count(*)
from dim.organizationlocation 
where 1=1
and organizationtype = 0
group by locationid

select * from fact.transactionheader 
where 1=1
--and organizationid = 'org-42a2fc0d-1696-4fd9-8c9e-dc5504f903c2'
and locationid = 'loc-2d672932-a1b7-4ff0-a848-d65c0c18c417'
--and orderid in ('ord-32492334929395718','ord-32491966367449089','ord-32491173946081280')
order by orderdateutc desc

select * from dim.organizationlocation where organizationtype = 0

select distinct locationid from dim.organizationlocation where organizationtype = 5 --29/77
except
select distinct id from dim.organizationgeography where organizationtype = 5 --31/77
except

select og.*, 
       l.timezone,
       l.address1
from (select * from dim.organizationlocation where organizationtype = 0) as og
inner join (select distinct locationid, address1, timezone from dim.location) as l
on og.locationid = l.locationid
where og.locationid in 
(select DISTINCT locationid from fact.transactionheader where orderdatelocal between (orderdatelocal - INTERVAL '90 days') and CURRENT_DATE)
--and organizationname not in ('')
order by organizationid

select CURRENT_DATE
select distinct companyid, locationid, address1, timezone
from dim.location

select * from dim.company
select * from dim.organization

select * from dim.organizationlocation where organizationtype = 0 --1,941
select * from dim.location --1,973
select distinct locationid from dim.location --1,973
select distinct city from dim.location --1,973


