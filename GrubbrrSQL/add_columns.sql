select *
from dim.menuitem
--where id = 3897
order by id
limit 1000;

select *
from dim.itemcategory
--where id = 3897
order by id
limit 1000;

select *, count(*) over(PARTITION by locationid, kioskid) as count_by_key
from dim.ordertype
ORDER BY id DESC
limit 1000



select *
from dim.organizationlocation as o
where o.organizationtype = 0
--and lower(o.organizationid) like 'boj'
and o.locationid = 'loc-705e38ab-3c34-4318-94d8-80f52a993a87'-- 'loc-d4a115b5-bbf8-483e-b84b-d05177102341'
limit 1000;



select *--, substring(th.transactionheaderid, 7, length(th.transactionheaderid)) :: BIGINT as abortedorderid
from fact.transactionheader as th
where 1=1
--and th.transactionheaderid like 'abort-%'
and th.ordersessionid = 'AAD4INBEXCMUHICK'
--and th.channel is null
--and th.charityamount is not null
and not exists (select 1 from dim.ordertype as ot where ot.id = th.ordertype)
and th.ordertype is not null
and th.orderstatus = 'order-placed'
--and th.locationid = 'loc-8ead49a8-798b-4786-988a-90bbbb4775c7'-- 'loc-49971226-2278-440e-8fd1-eff402a73881'-- 'loc-9dbd4815-f50a-4e4f-ac1d-5fd6d9ec728e'-- 'loc-273ffa25-f0d2-48e5-befa-47f0934f3baa'
--and th.businessdate = '2025-06-18'
and th.transactionheaderid = 'ordevt-09bhgd5h1h'-- 'ordevt-649sdzodt4'
order by th.orderdateutc desc -- th.id desc
limit 200
--RDBMS
select substring('abort-',7,1)

select *--count(*) 
from fact.transactionitem as ti --P=696,431---T=63,794/2---R=21,617
where 1=1
and ti.menuitemid is not null--  in (SELECT id from dim.menuitem)
and ti.transactionheaderid not like 'abort-%' --562,942
--and (ti.menuitemid is not null and ti.menuitemid <> 0) 
/*and not exists (select 1 from fact.transactionheader as th --573,376
            where th.transactionheaderid = ti.transactionheaderid)
              and th.locationid = ti.locationid)*/
--and ti.locationid is null --562,107
order by ti.orderdateutc desc
limit 1000

--UPDATE fact.transactionitem
--set menuitemid = NULL

ALTER TABLE fact.transactionheader
add charityamount  NUMERIC(7,3),
add syscosmosts BIGINT

ALTER TABLE fact.userbehaviour
add syscosmosts BIGINT,
add eventinstant text


ALTER TABLE fact.transactionheader
add syscosmosts BIGINT

ALTER TABLE fact.transactionitem
add syscosmosts BIGINT

ALTER TABLE fact.transactionheader
add CONSTRAINT ordertype_fk FOREIGN KEY (ordertype) REFERENCES dim.ordertype(id);

ALTER TABLE fact.transactionheader
add CONSTRAINT location_kiosk_fk FOREIGN key (locationid, kioskid) REFERENCES dim.kiosk(locationid, kioskid)

ALTER TABLE fact.transactionitem 
add CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);

ALTER TABLE fact.transactionheader
ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.location(locationid);

ALTER TABLE fact.transactionitem
add CONSTRAINT categoryid_fk FOREIGN KEY (categoryid) REFERENCES dim.itemcategory(id)

ALTER TABLE fact.transactionitem
add CONSTRAINT menuitemid_fk FOREIGN KEY (menuitemid) REFERENCES dim.menuitem(id)

select * 
from 

select * 
from dim.frequentcustomer as fc 
order by fc.ordercount desc
limit 100




--DELETE FROM fact.transactionitem as ti
where not exists (select 1 from fact.transactionheader as th --573,376
            where th.transactionheaderid = ti.transactionheaderid)

select th.transactionheaderid, count(*)
from fact.transactionheader as th
group by th.transactionheaderid
having count(*) > 1


SELECT
    ti.*,
	ic.categoryname AS Name
FROM fact.transactionheader th
INNER JOIN fact.transactionitem ti ON ti.transactionheaderid = th.transactionheaderid
LEFT JOIN dim.itemcategory ic ON ic.id = ti.categoryid
INNER JOIN dim.organizationlocation ol ON ol.locationid = th.locationid
WHERE ol.organizationid = 'loc-e058e270-4475-405c-b0af-074817ee1372'
    AND LOWER(th.orderstatus) = 'order-placed'
    AND th.businessdate BETWEEN '2025-01-01'::TIMESTAMP AND '2025-06-13'::TIMESTAMP
AND ti.categoryid is not null

--INSERT INTO fact.transactionheader(locationid, transactionheaderid, id)--orderdateutc, id)
select *-- DISTINCT locationid, transactionheaderid  -- count(distinct ti.categoryid)
            --row_number() OVER(ORDER BY transactionheaderid) + (SELECT max(id) FROM fact.transactionheader)
from fact.transactionitem as ti 
where 1=1
--and not exists (select 1 from dim.itemcategory as ic where ic.id = ti.categoryid) --64,513
--and not exists (select 1 from dim.menuitem as mi where mi.id = ti.menuitemid)
and not exists (select 1 from fact.transactionheader as th 
                where th.locationid = ti.locationid and th.transactionheaderid = ti.transactionheaderid)
and ti.categoryid is not null --9,975 NULLs + 54,538 non-NULLs = 64,513
--and ti.menuitemid is null
and ti.transactionheaderid like 'abort-%'
--and ti.sysupdatetime is not null
order by ti.orderdateutc desc
limit 1000

--UPDATE fact.transactionheader
SET locationid = ti.locationid,
    transactionheaderid = ti.transactionheaderid,
    orderdateutc = ti.orderdateutc,
    ordersessionid = ti.ordersessionid,
    orderid = ti.orderid
FROM (SELECT locationid, transactionheaderid, 
             max(orderdateutc) orderdateutc, 
             max(ordersessionid) ordersessionid, 
             max(orderid) orderid
      FROM fact.transactionitem
      GROUP BY locationid, transactionheaderid) as ti
WHERE transactionheader.orderid is null and businessdate is null 
  AND transactionheader.locationid = ti.locationid
  AND transactionheader.transactionheaderid = ti.transactionheaderid
  
--55,891

--UPDATE fact.transactionitem
SET orderdateutc = 
case when substring(orderdateutc, 20, 1) = '.' 
     then replace(replace(substring(orderdateutc, 1, 23), 'T', ' '), '+', '0')-- :: TIMESTAMP
     else substring(orderdateutc, 1, 19) end-- :: TIMESTAMP end
WHERE orderdateutc is not null
--and kioskid is null AND businessdate is NULL;



select * from dim.itemcategory--_bkp
--where id in (755191, 754827, 754837)
order by id
--alter TABLE fact.transactionheader
--add guestcount INTEGER


-- Update rows in table '[TableName]' in schema '[dbo]'

update fact.transactionheader
set orderdateutc = 
case when substring(orderdateutc, 20, 1) = '.' 
     then replace(replace(substring(orderdateutc, 1, 23), 'T', ' '), '+', '0')
     else substring(orderdateutc, 1, 19) end;

UPDATE fact.transactionpayment
SET
   locationid = th.locationid,
   orderdateutc = th.orderdateutc,
   kioskid = th.kioskid
   -- Add more columns and values here
from fact.transactionheader as th
WHERE transactionpayment.transactionheaderid = th.transactionheaderid
GO


select th.transactionheaderid, count(1)
from fact.transactionheader as th
group by th.transactionheaderid
HAVING count(1) > 1


select *
from fact.transactionheader as th
--where th.orderdateutc like '%T%'
limit 100

update fact.transactionheader
set orderdateutc = 
case when substring(orderdateutc, 20, 1) = '.' 
     then replace(replace(substring(orderdateutc, 1, 23), 'T', ' '), '+', '0')
     else substring(orderdateutc, 1, 19) end;
   
SELECT '2025-05-23T07:08:07.45+00:00', replace(replace(substring('2025-05-23T07:08:07.45+00:00', 1, 23), 'T', ' '), '+', '0')

select * 
from fact.devicetelemetry as dt
where dt.cpuvalue < 0 or dt.memoryvalue < 0
limit 10;

select * 
from fact.devicestate as ds
where ds.duration < 0
limit 10;

select mi.menuitemid, mi.menuitemname, count(1)
from fact.transactionitem as ti 
inner join dim.menuitem as mi 
on ti.menuitemid = mi.id
where ti.locationid = 'loc-d5cc5cc1-dcf4-454e-8b42-88d07fb78e0f'
group by mi.menuitemid, mi.menuitemname
order by count(1) desc


select count(*) as total,
       sum(case when th.orderstatus = 'order-placed' then 1 else 0 end) as placed, --*-- max(th.orderdateutc)
       100*sum(case when th.orderstatus = 'order-placed' then 1 else 0 end) :: NUMERIC(10,3) / count(*) as placed_percentage,
       sum(case when th.orderstatus <> 'order-placed' then 1 else 0 end) as aborted,
       100*sum(case when th.orderstatus <> 'order-placed' then 1 else 0 end) :: NUMERIC(10,3) / count(*) as aborted_percentage
from fact.transactionheader as th 
where 1=1
and th.orderstatus <> 'order-placed'
--and th.ordertype is not null
--and th.channel is null-- = 'Kiosk'
order by th.orderdatelocal desc
limit 1000

--select distinct th.channel from fact.transactionheader as th

select * from fact.recommendations order by prompttimestamp desc
SELECT * from fact.usercheckedin order by orderdatelocal desc

select mi.*, ti.* 
from fact.transactionitem as ti 
inner join dim.menuitem as mi 
        on ti.menuitemid = mi.id
limit 1000

select ti.orderdateutc, *-- distinct ti.transactionheaderid, ti.orderdateutc
from fact.transactionitem as ti
where 1=1
and ti.categoryid is null 
and (ti.upselllevel = '' or ti.upselllevel is null)
and ti.transactionheaderid like 'ordevt-%'
and ((ti.transactionheaderid = 'ordevt-h6kbzdlyuj' and ti.itemid = 'orditm--YOYorwXKV')
   or (ti.transactionheaderid = 'ordevt-mks3yv5bqb' and ti.itemid ='orditm-1ml_jNQswc')
   or (ti.transactionheaderid = 'ordevt-ulrm3jbepf' and ti.itemid ='orditm-ZzCYkAMFFB')
   or (ti.transactionheaderid = 'ordevt-vxun07xfva' and ti.itemid ='orditm-IrXt6rS-Yy')
   or (ti.transactionheaderid = 'ordevt-rhb9n46sit' and ti.itemid ='orditm-bSuY7IpK1l')
   or (ti.transactionheaderid = 'ordevt-bb5j8rmbuu' and ti.itemid ='orditm-032YVY5Q6y'))
order by ti.orderdateutc desc

/*and ((c.id = 'ordevt-h6kbzdlyuj' and i.orderItemId = 'orditm--YOYorwXKV')
   or (c.id = 'ordevt-mks3yv5bqb' and i.orderItemId ='orditm-1ml_jNQswc')
   or (c.id = 'ordevt-ulrm3jbepf' and i.orderItemId ='orditm-ZzCYkAMFFB')
   or (c.id = 'ordevt-vxun07xfva' and i.orderItemId ='orditm-IrXt6rS-Yy')
   or (c.id = 'ordevt-rhb9n46sit' and i.orderItemId ='orditm-bSuY7IpK1l')
   or (c.id = 'ordevt-bb5j8rmbuu' and i.orderItemId ='orditm-032YVY5Q6y'))*/

select *-- ic.locationid, ic.categoryid, count(1)
from dim.itemcategory as ic
where 1=1
and ic.categoryid in (
'cat-67af84cd-a781-405c-91df-e353daaf616c',
'cat-081feef7-bd50-4dcc-87f4-ace76865732d')-- 'cat-22951f77-e1d7-4668-9789-1629900034ca'
group by ic.locationid, ic.categoryid

select *
from dim.menuitem as mi
where 1=1
and mi.menuitemid = 'itm-4ccdf2d7-505d-4a3e-92a9-eaf6953a2628'

select th.ordersessionid, COUNT(1)
from fact.transactionheader as th
group by th.ordersessionid
having COUNT(1) > 1

update fact.transactionitem
   set locationid = th.locationid,
       orderdateutc = th.orderdateutc
from fact.transactionheader as th
where transactionitem.transactionheaderid = th.transactionheaderid
  --and transactionitem.locationid*/

/*update fact.transactionitem
   set orderdateutc = replace(replace(substring(orderdateutc, 1, 23), 'T', ' '), '+', '0');

update fact.transactionheader
   set orderdateutc = replace(replace(substring(orderdateutc, 1, 23), 'T', ' '), '+', '0');
*/


/*update fact.transactionheader
set channel = 'Kiosk'
where channel is null*/

/*update fact.transactionitem
set dimmenuitemid = mi.menuitemid,
    locationid = mi.locationid
from dim.menuitem as mi
where transactionitem.menuitemid = mi.id
*/

/*alter table fact.transactionitem
--add dimmenuitemid character varying(50)
add locationid character varying(50)
--drop COLUMN dim_locationid
drop COLUMN dim_menuitemid*/

--alter table fact.transactionitem
--add constraint dimmenuitem_fk (dimmenuitem) references dim.menuitem(menuitemid)

/*update fact.transactionitem
set locationid = dim_locationid,
    dimmenuitemid = dim_menuitemid*/


/*update fact.transactionitem 
set menuitemid = mi.id --547,291
from dim.menuitem as mi
where transactionitem.dimmenuitemid = mi.menuitemid*/

