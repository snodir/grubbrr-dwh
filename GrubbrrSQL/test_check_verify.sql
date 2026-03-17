select *-- sum(ordertotal), sum(ordersubtotal)
from fact.transactionheader 
where 1=1
--and organizationid = 'org-42a2fc0d-1696-4fd9-8c9e-dc5504f903c2'
and locationid = 'loc-f8040c7b-4b0c-410c-af25-3e79bf4af86c' --'loc-7b149de8-32db-46be-883e-fc7db625be7b'-- 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3'-- 'loc-72cd6945-5b7c-4fa5-942b-ee3ec8f21881'-- 'loc-9070a34c-e976-4d96-b06e-ec2ec5214ee4'
--and orderid like '%6202F57FAE274A4F82D96495B0B1A2C2%'-- in ('ord-17366','ord-17383','ord-17384')-- = 'ord-AAASLMR79QAA'-- is not null-- in ('ord-32492334929395718','ord-32491966367449089','ord-32491173946081280')
--and orderdateutc >= '2025-02-20 05:00:00.0000000Z' and orderdateutc < '2025-02-21 05:00:00.0000000Z'
and businessDate = '2025-02-27' --dateid between 2025022000 and 2025022023 
--and channel is not null
and orderstatus = 'order-placed'
order by orderdateutc desc limit 100

--6202F57FAE274A4F82D96495B0B1A2C2

select *-- sum(ordertotal), sum(ordersubtotal)
from fact.transactionheader 
where 1=1
and locationid = 'loc-f7fe5b34-c814-42e9-a4be-18a7f69d238d' --'loc-637638f7-ef71-4416-85c3-dd63bb25f77d'-- 'loc-9070a34c-e976-4d96-b06e-ec2ec5214ee4'
--and orderid in ('')  --is not null
--and dateid between 2025011300 and 2025011400
order by orderdateutc desc

SELECT max(id) from fact.transactionheader 
select * from dim.ordertype

select * from fact.transactionheader where channel is not null order by orderdateutc desc


SELECT * from fact.transactionitem 
where upselllevel not like '%Upsell%'
order by orderdateutc desc limit 10

select distinct upselllevel from fact.transactionitem
select * from fact.devicestate

select ti.* 
from fact.transactionheader as th 
left join fact.transactionitem as ti 
on ti.transactionheaderid = th.transactionheaderid --and ti.orderid = th.orderid
where 1=1
and th.locationid = 'loc-4a21222e-137e-4f55-969e-c857d297b499'
--and ti.ordersessionid = 'Z2WPHXOGHML16HEO'
and th.businessdate in ('2025-07-23','2025-07-24')
--and ti.categoryid in (select id from dim.itemcategory where categoryid = 'cat-e7344912-7419-4f98-961c-dc2741997b6c')
order by orderdateutc desc

select * from fact.watermarktable
SELECT * from fact.transactionitem where totaltime between 1 and 2 order by orderdateutc desc limit 10
select * from dim.itemcategory where categoryid = 'cat-e7344912-7419-4f98-961c-dc2741997b6c'
select * 
from dim.menuitem 
--where menuitemid = 'itm-0bba53ec-b034-42ac-b0bb-2f163cd3d060'
ORDER by id DESC

SELECT * 
FROM fact.transactionitem as ti 
where 1=1
--and ti.transactionheaderid in ('ordevt-l5hu1liixp','ordevt-d97r4qskct')
--and ti.orderid in ('ord-AABF4MQZ9QAC'/*'ord-AAASLMJ79QAA','ord-AAASLMJ79QAB','ord-AAASLMJ79QAC',
--'ord-AAASLMJ79QAD','ord-AAASLMJ79QAE','ord-AAASLMJ79QAF',
--'ord-AAASLMJ79QAG','ord-AAASLMJ79QAH'*/);
--and organizationid = 'org-42a2fc0d-1696-4fd9-8c9e-dc5504f903c2'
--and orderid in ('ord-32492334929395718','ord-32491966367449089','ord-32491173946081280')
order by orderdateutc desc
limit 10


SELECT orderid,locationid,dateid, orderdateutc,orderdatelocal, businessdate
FROM fact.transactionheader
where 1=1
--and ti.transactionheaderid in ('ordevt-l5hu1liixp','ordevt-d97r4qskct')
and orderid in 
('ord-15454','ord-15452','ord-15451','ord-15446','ord-15445','ord-15441','ord-15434','ord-15424','ord-15414')
and dateid between 2025011800 and 2025012023
order by orderdateutc desc

select *-- transactionheaderid,orderid,locationid,dateid, orderdateutc,orderdatelocal, businessdate, createddate
FROM fact.transactionheader
where 1=1
--and cast(orderdatelocal as date) <> businessdate --887
--and cast(orderdatelocal as date) = businessdate  --4,435
--and cast(orderdateutc as date) = businessdate    --7,556
--and cast(orderdateutc as date) <> businessdate    --0
--and businessdate is null --7,556
and orderdatelocal is null --180T, --289S, --19P
order by orderdateutc desc

select *-- transactionheaderid, orderid,locationid,dateid, orderdateutc,orderdatelocal, businessdate
FROM fact.transactionheader
where 1=1
--and businessdate is not null --7,280
--and orderdatelocal is null --104,128
and orderstatus <> 'order-placed'
order by orderdateutc desc

select * from dim.kiosk where istestkiosk = True


--update fact.transactionheader
/*set businessdate = coalesce(cast(orderdatelocal as date), cast(orderdateutc as date))
where 1=1
and cast(orderdatelocal as date) <> businessdate*/

select distinct timezone from dim.organizationgeography

select distinct th.locationid, l.locationid, th.transactionheaderid, l.timezone, th.orderdateutc, th.orderdatelocal,
th.orderdateutc::TIMESTAMPTZ AT TIME ZONE l.timezone as localts,
th.businessdate, th.orderid, th.orderstatus
from fact.transactionheader as th 
--left join (select distinct id, timezone from dim.organizationgeography where organizationtype = 5) as og
left join (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end from dim.location) as l
--on og.id = th.locationid
on l.locationid = th.locationid
where 1=1
and th.orderdatelocal is null --loc-36a67e05-cb3d-472f-9651-6ecf8ebc14b6
--and th.locationid in ('loc-7b149de8-32db-46be-883e-fc7db625be7b', 'loc-637638f7-ef71-4416-85c3-dd63bb25f77d')
--and og.id is null
order by th.locationid, th.orderdatelocal desc

update fact.transactionheader
set orderdatelocal = orderdateutc::TIMESTAMPTZ AT TIME ZONE l.timezone
from (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end from dim.location) as l
where l.locationid = transactionheader.locationid 
and transactionheader.orderdatelocal is null
and transactionheader.orderid in ('ord-AAACEMPX9QAJ','ord-AAACEMPX9QAH','ord-AAACEMPX9QAG');
*/
select * from dim.organizationlocation

select distinct l.locationid, l.timezone, og.id, og.timezone
from dim.location as l 
left join (select distinct id, timezone from dim.organizationgeography where organizationtype = 5) as og
on og.id = l.locationid
where l.timezone <> og.timezone

select distinct th.locationid, 
(select distinct l.locationid from dim.location as l where l.locationid = th.locationid) as lid,
(select distinct l.timezone from dim.location as l where l.locationid = th.locationid) as tznull,
(select distinct case when l.timezone is null or l.timezone='' then 'America/New_York' else l.timezone end from dim.location as l where l.locationid = th.locationid) as tz
from fact.transactionheader as th

select * from dim.organizationgeography where organizationtype = 5

/*update fact.transactionheader
set orderdatelocal = 
case when og.timezone like '%Chicago%' then cast(orderdateutc as timestamp) - INTERVAL '360 minutes'
     when og.timezone like '%New_York%' then cast(orderdateutc as timestamp) - INTERVAL '300 minutes'
     when og.timezone like '%Denver%' then cast(orderdateutc as timestamp) - INTERVAL '420 minutes'
     when og.timezone like '%Los_Angeles%' then cast(orderdateutc as timestamp) - INTERVAL '480 minutes'
     when og.timezone like '%Phoenix%' then cast(orderdateutc as timestamp) - INTERVAL '420 minutes'
     when og.timezone is null then cast(orderdateutc as timestamp) - INTERVAL '300 minutes' end
from (select distinct id, timezone from dim.organizationgeography where organizationtype = 5) as og
where og.id = transactionheader.locationid 
and transactionheader.orderdatelocal is null;

--update fact.transactionheader
set businessdate = cast(orderdatelocal as date)
where businessdate is null;
*/

select * from fact.transactionheader where orderdateutc like '%T%'

select cast('2024-06-29T16:28:10.517+00:00' as timestamp),
       cast('2024-06-29T16:28:10.517+00:00' as timestamp) - INTERVAL '240 minutes',
       cast('2025-01-21 03:58:28.658' as timestamp),
       to_timestamp(1737969597)


select distinct 
	th.locationid, 
	og.id, 
	og.timezone, 
	th.orderdateutc,
	th.orderdateutc::TIMESTAMPTZ AT TIME ZONE COALESCE(og.timezone,'America/New_York')
from fact.transactionheader as th 
left join (select distinct id, timezone from dim.organizationgeography where organizationtype = 5) as og
on og.id = th.locationid
order by timezone

select * from fact.transactionheader 
where 1=1
--and orderid = 'ord-15951'
--and cast(orderdatelocal as date) = '2025-01-27' 
--and locationid= 'loc-72cd6945-5b7c-4fa5-942b-ee3ec8f21881'
--and orderstatus = 'order-placed'
order by orderdatelocal desc
limit 100

/*update fact.transactionheader
set businessdate = cast(orderdatelocal as date)
where cast(orderdatelocal as date) >= '2024-12-14' --8,926P--11,816T--11,047S
--and locationid= 'loc-72cd6945-5b7c-4fa5-942b-ee3ec8f21881'
--and orderstatus = 'order-placed'*/

