--drop table IF EXISTS dim.kiosk;
CREATE TABLE IF NOT EXISTS dim.kiosk
(
    id bigint NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    kioskid text COLLATE pg_catalog."default" NOT NULL,
    kioskname text COLLATE pg_catalog."default",
    serialnumber text COLLATE pg_catalog."default",
    appversion text COLLATE pg_catalog."default",
    istestkiosk boolean,
    devicetype character varying(50) COLLATE pg_catalog."default" NOT NULL DEFAULT 'kiosk'::character varying,
    devicecreatedon timestamp without time zone,
    devicedeletedon timestamp without time zone,
    CONSTRAINT kiosk_pk PRIMARY KEY (id),
    CONSTRAINT kiosk_uidx UNIQUE (locationid, kioskid)
)

TABLESPACE pg_default;

ALTER TABLE dim.kiosk
    OWNER to citus;

CREATE INDEX IF NOT EXISTS kiosk_location_idx
    ON dim.kiosk USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(istestkiosk, devicetype, devicedeletedon)
    TABLESPACE pg_default;

select locationid, kioskid, count(1)
from dim.kiosk
group by locationid, kioskid
having count(1) > 1

/*insert into dim.kiosk 
(id, locationid, kioskid, kioskname, serialnumber,
appversion, istestkiosk, devicetype, devicedeletedon 
)
select * from dim.kiosk_bkp*/

alter table dim.kiosk
alter id drop IDENTITY
--drop column devicedeletedon
--add devicecreatedon TIMESTAMP
--add devicedeletedon TIMESTAMP

select coalesce(max(id),0) as maxid from dim.kiosk



select * 
from dim.kiosk 
order by id desc

select * from dim.company;


select * from dim.company11;
select * from dim.organization order by createdon desc;
select * from dim.organizationparent;
select * from dim.locationgroup;
select * from dim.organizationlocation where organizationtype = 0 --1,941
select * from dim.organizationgeography where organizationtype = 0
select * from dim.location --1,973
select distinct locationid from dim.location --1,973
select distinct concat(city, ' ', coalesce(state, '')) as city
from dim.location 
where city is not null and city <> ''; --372

select * from fact.peripheralstate limit 10
select * from fact.devicestate order by lasteventtime desc limit 10

select * from dim.peripheral limit 10
select * from fact.peripheralhealth limit 10

select * from dim.device limit 10
select * from fact.devicehealth limit 10

select *-- distinct th.channel
from fact.transactionheader as th 
where th.orderstatus = 'order-placed'
and th.transactionheaderid = 'ordevt-kliisgniy6'
limit 10

select * from dim.location
where locationid = 'loc-ebd23f7f-a4e3-452a-a643-db13ee756fc5'

select * 
from dim.organization as o
where o.id = 'org-ug5zsn9mpq'

select *-- distinct th.channel-- th.orderstatus
from fact.transactionheader as th
where 1=1
--and th.channel is null-- = 'External'
--and th.locationid = 'loc-ebd23f7f-a4e3-452a-a643-db13ee756fc5'
--and th.orderid = 'ord-10311109634815219517'
and th.orderid like 'ord-%-%'
and th.orderstatus = 'order-placed'
and th.ordertype is null
order by th.orderdateutc DESC

select * 
from dim.ordertype as ot
where 1=1 
and ot.locationid= 'loc-lr3h36utnl'-- 'loc-ebd23f7f-a4e3-452a-a643-db13ee756fc5'
and ot.kioskid = 'ksk-38444495'-- 'ksk-32172083'
and ot.id = 1045


select *-- count(*) 
from fact.transactionitem as ti
where ti.dimmenuitemid is not null
--and th.transactionheaderid = 'ordevt-396i1ees39'
limit 1000

select * from dim.menuitem as mi
where mi.menuitemid not in 
(select distinct dimmenuitemid from fact.transactionitem)

select *-- distinct ti.dimmenuitemid -- ti.transactionheaderid-- 
from fact.transactionitem as ti
where ti.dimmenuitemid not in 
(select distinct menuitemid from dim.menuitem)

select distinct vw.offereditem
from fact.vw_offer_analysis as vw
where vw.offereditem not in 
(select distinct menuitemid from dim.menuitem)

/*alter table fact.transactionitem
--add dimmenuitemid character varying(50)
--add locationid character varying(50)
--drop COLUMN dim_locationid
drop COLUMN dim_menuitemid*/

--alter table fact.transactionitem
--add constraint dimmenuitem_fk (dimmenuitem) references dim.menuitem(menuitemid)

/*update fact.transactionitem
set locationid = dim_locationid,
    dimmenuitemid = dim_menuitemid*/

update fact.transactionheader
set channel = 'Kiosk'
where channel is null
and orderstatus <> 'order-placed'*/



select case when 'Kiosk'='kiosk' then 'ci' else 'cs' end

select * 
from fact.userbehaviour 
order by createddate desc
limit 10

select * from fact.pipelinerunstatus

select * from dim.menuitem

select count(th.ordertype), count(*), count(*) - count(th.ordertype) -- distinct th.channel
from fact.transactionheader as th 
where th.orderstatus <> 'order-placed'
limit 10


select * 
from dim.ordertype
where id = 1337
and locationid = 'loc-ebd23f7f-a4e3-452a-a643-db13ee756fc5'

select *-- distinct ordertypeid, ordertypelabel
from dim.ordertype
order by id -- locationid, kioskid

SELECT 
	ti.* 
FROM fact.transactionheader th
INNER JOIN dim.datedim dd 
    ON dd.dateid = th.dateid
INNER JOIN fact.transactionitem ti 
    ON ti.transactionheaderid = th.transactionheaderid
INNER JOIN dim.menuitem as itm 
    ON ti.menuitemid = itm.id
WHERE  th.locationid = 'loc-90b318fe-3444-475f-a3a4-68f5219221a8'
 AND LOWER(th.orderstatus) = 'order-placed'

select ti.transactionheaderid, ti.itemid, count(1)
from fact.transactionitem as ti 
group by ti.transactionheaderid, ti.itemid
having count(1) > 1

select ti.*-- count(ti.menuitemid) --13,898/14,934
from fact.transactionheader as th 
INNER JOIN fact.transactionitem ti 
    ON ti.transactionheaderid = th.transactionheaderid
WHERE  th.locationid = 'loc-90b318fe-3444-475f-a3a4-68f5219221a8'
 AND LOWER(th.orderstatus) = 'order-placed'

select * 
from dim.menuitem as mi
where mi.menuitemid in (
'itm-91f784f3-dead-4c56-afc3-c59f64a4bb0f',
'itm-b79f2ebe-d783-4003-bb63-6b3c1360edc6',
'itm-2080a9a1-f306-4767-828e-1bed96e7a844',
'itm-809a5f27-7f90-4dd0-bcc1-322e1580bd83'
)


