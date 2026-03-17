--drop table if EXISTS dim.menuitem;
CREATE TABLE IF NOT EXISTS dim.menuitem
(
    id bigint NOT NULL,
    /*organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,*/
    menuitemid text COLLATE pg_catalog."default" NOT NULL,
    menuitemname text COLLATE pg_catalog."default" NOT NULL,
    guest integer NOT NULL DEFAULT 1,
    effective_date date,
    /*issuedsurveycount integer,
    receivedsurveycount integer,
    totalratingvalue integer,*/
    CONSTRAINT menuitem_pk PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE dim.menuitem
    OWNER to citus;

-- Index: dim.menuitem_locationid_idx
CREATE INDEX IF NOT EXISTS menuitem_locationid_idx
    ON dim.menuitem USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(menuitemid, effective_date)
    TABLESPACE pg_default;


--insert into dim.menuitem
select * from dim.menuitem order by id desc;

--insert into dim.menuitem (id, locationid, menuitemid, menuitemname, guest, effective_date)
select id, locationid, menuitemid, menuitemname, guest, effective_date from dim.menuitem_bkp;


--insert into dim.menuitem_bkp
select * from dim.menuitem --where locationid = 'loc-4ea7c9ad-9807-4e46-bf8f-b48a0ac627ad'
select * from dim.menuitem_bkp order by id

select * 
from dim.menuitem
ORDER BY locationid, menuitemid;

select locationid, count(*)
from dim.menuitem --4,731T --464 dist.Locations
group by locationid
order by locationid;

select menuitemid, count(*)
from dim.menuitem --4,731T --3,268 dist.ItemIDs, of which 438 duplicated
group by menuitemid
having count(*) > 1
order by menuitemid;

select *, count(*) over(partition by menuitemid) as item_count
from dim.menuitem--_bkp --4,588   --menuitem
order by count(*) over(partition by menuitemid) desc, menuitemid asc;

select distinct ti.transactionheaderid, ti.menuitemid, /*mi.id, mi.locationid,*/ 
mi.menuitemid, mi.menuitemname, ti.itemname
from fact.transactionitem as ti 
inner join dim.menuitem as mi 
on ti.menuitemid = mi.id 
where ti.menuitemid is not null

select * 
from dim.frequentcustomer 
order by ordercount desc



select locationid, menuitemid, count(*)
from dim.menuitem--_test --4,731T --4,629 dist.[locID + ItemID] of which 97 duplicated
group by locationid, menuitemid
having count(*) > 1
order by locationid, menuitemid;

select *
from fact.transactionitem
where sysinserttime is not null and transactionheaderid like 'ordevt%'
order by sysinserttime desc
limit 100

select mi.id, ol.organizationid, mi.locationid, mi.menuitemid, 
       mi.menuitemname, count(*) over(partition by mi.locationid, mi.menuitemid) as loc_item_count
from dim.menuitem as mi 
left join (select * from dim.organizationlocation where organizationtype = 0) as ol 
on mi.locationid = ol.locationid
order by count(*) over(partition by mi.locationid, mi.menuitemid) desc, mi.locationid asc, mi.menuitemid

SELECT ol.organizationid, its.*
from fact.itemssurvey as its 
left join (select * from dim.organizationlocation where organizationtype = 0) as ol
on its.locationid = ol.locationid


--alter table dim.menuitem
add issuedsurveycount int;

--alter table dim.menuitem
add receivedsurveycount int;

--alter table dim.menuitem
add totalratingvalue int;*/

select * from dim.menuitem

select mi.organizationid, mi.locationid, mi.menuitemid, mi.menuitemname,
       its.issuedsurveycount, its.receivedsurveycount, its.totalrating
from dim.menuitem as mi 
left join (select organizationid, 
                   itemid, 
                   count(distinct surveytransid) as issuedsurveycount,
                   count(*) as receivedsurveycount,
                   sum(cast(itemrating as decimal(6,3))) as totalrating 
            from fact.itemssurvey
            group by organizationid, itemid) as its 
on mi.organizationid = its.organizationid and mi.menuitemid = its.itemid
where its.issuedsurveycount is not null
order by mi.locationid, mi.menuitemid

select * --organizationid, count(distinct catalogid)
from dim.locationcatalog
where 1=1
and organizationid = 'com-3aeuuijrb2'
and catalogid = 'catlg-83282977-fb26-45f4-8044-a0f0659c0d2a'

group by organizationid

select * from dim.menuitem order by id;

select * 
from dim.menuitem_test 
order by id asc

select * from fact.itemssurvey order by surveycompletedtimestamp desc;

select organizationid, itemid, count(distinct surveytransid)
from fact.itemssurvey
group by  organizationid, itemid


/*update dim.menuitem
set organizationid = ol.organizationid
from (select * from dim.organizationlocation where organizationtype = 0) as ol 
where menuitem.locationid = ol.locationid 
  and menuitem.organizationid is null;*/

--update dim.menuitem
set issuedsurveycount = its.issuedsurveycount,
    receivedsurveycount = its.receivedsurveycount,
    totalratingvalue = its.totalrating
from (select organizationid, 
             itemid, 
             count(distinct surveytransid) as issuedsurveycount,
             count(*) as receivedsurveycount,
             sum(cast(itemrating as decimal(6,3))) as totalrating 
      from fact.itemssurvey
      group by organizationid, itemid) as its
where menuitem.organizationid = its.organizationid
  and menuitem.menuitemid = its.itemid;

SELECT
    conname AS fk_name,
    conrelid::regclass AS fk_table,
    att2.attname AS fk_column,
    confrelid::regclass AS referenced_table,
    att1.attname AS referenced_column
FROM
    pg_constraint
JOIN
    pg_attribute att1 ON att1.attnum = ANY (conkey) AND att1.attrelid = confrelid
JOIN
    pg_attribute att2 ON att2.attnum = ANY (confkey) AND att2.attrelid = conrelid
WHERE
    confrelid = 'dim.menuitem'::regclass AND
    att1.attname = 'id' AND
    contype = 'f';


SELECT *
FROM information_schema.referential_constraints
WHERE unique_constraint_schema = 'public'
  AND unique_constraint_name = 'menuitem_pk';



select * from dim.menuitem

--drop TABLE IF EXISTS dim.menuitem_bkp;
CREATE TABLE IF NOT EXISTS dim.menuitem_bkp
(
    id bigint NOT NULL,
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,
    menuitemid text COLLATE pg_catalog."default" NOT NULL,
    menuitemname text COLLATE pg_catalog."default" NOT NULL,
    guest integer NOT NULL DEFAULT 1,
    effective_date date,
    issuedsurveycount integer,
    receivedsurveycount integer,
    totalratingvalue integer,
    CONSTRAINT menuitem_bkp_pk PRIMARY KEY (id)
)


TABLESPACE pg_default;

select * from dim.ordertype; --305

select * from dim.menuitem
where menuitemid not in (
SELECT menuitemid from dim.menuitem_bkp)
--insert into dim.menuitem_bkp

select * from dim.menuitem_bkp
where menuitemid not in (
SELECT menuitemid from dim.menuitem)
