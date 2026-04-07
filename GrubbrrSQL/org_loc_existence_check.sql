SELECT * FROM dim.organization
WHERE 1=1 
  AND id = 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc'-- 'loc-96abd656-679f-41dc-a5ef-7bca8ffc5333'-- 'loc-66d85cfc-62f3-40eb-96c3-39afb144b4e3'
  AND organizationtype = 0

SELECT * FROM dim.organizationlocation
WHERE 1=1
  AND locationid in ('loc-9dd1eaea-e264-4d51-bffb-1abdc65e3fff')--, 'loc-61493b82-41d7-4b02-b788-de845b480d17')-- 'loc-66d85cfc-62f3-40eb-96c3-39afb144b4e3'
  
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

SELECT '''nodir''' as one_single_quote

SELECT *-- locationid, count(*)
FROM dim.location
WHERE 1=1
and locationid = 'loc-9dd1eaea-e264-4d51-bffb-1abdc65e3fff'-- 'loc-66d85cfc-62f3-40eb-96c3-39afb144b4e3'
and locationid not in (SELECT id FROM dim.organization)
group by locationid

--INSERT INTO dim.organization(id, name, address1, address2, city, state, zipcode, timezone, coordinates)
select locationid, locationname, address1, address2, city,
       state, zipcode, timezone, 
       case when latitude = '' or latitude is NULL or longitude = '' or longitude is NULL then NULL 
            else concat('(', latitude, ',', longitude, ')') end as coordinates
from dim.location as l
WHERE not exists (SELECT id FROM dim.organization as o where o.id = l.locationid)


--INSERT INTO dim.organizationlocation(organizationid, locationid, locationname)
select companyid, locationid, locationname,
       address1, address2, city, state, zipcode, timezone, case when latitude = '' or latitude is NULL or longitude = '' or longitude is NULL then NULL else concat('(', latitude, ',', longitude, ')') end as coordinates
from dim.location as l
WHERE not exists (SELECT * FROM dim.organizationlocation as ol where ol.locationid = l.locationid and ol.organizationid = l.companyid)


SELECT * FROM dim.organization;
SELECT * FROM dim.location;

select * from dim.organizationlocation


WHERE locationid = 'loc-66d85cfc-62f3-40eb-96c3-39afb144b4e3'

alter TABLE dim.organization
--ALTER COLUMN organizationtype drop not null
--ALTER COLUMN status drop not null,
--ALTER COLUMN createdon drop not null,
ALTER COLUMN active drop not null,
ALTER COLUMN isdeleted drop not null;

alter TABLE dim.organizationlocation
--ALTER COLUMN organizationname drop not null
ALTER COLUMN organizationtype drop not null
