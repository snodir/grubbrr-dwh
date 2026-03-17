select * 
from fact.transactionheader 
where 1=1
--and orderid in ('ord-09588220834124221212', 'ord-10642777065200686652')
and transactionheaderid in ('ordevt-4bserpx7rw', 'ordevt-e3t0wjjytm');

select *
from fact.transactionitem as ti
where ti.transactionheaderid in ('ordevt-4bserpx7rw', 'ordevt-e3t0wjjytm')

select *
from fact.transactionitemtest as ti
where ti.transactionheaderid in ('ordevt-4bserpx7rw', 'ordevt-e3t0wjjytm')

select * from fact.transactionitem 
where dateid >= 2024121000 --6,370
--and transactionheaderid like 'abort%'
order by orderdateutc 

select * from fact.watermarktable

/*alter table fact.transactionitem
add dateid INTEGER;

--alter table fact.transactionitem
add orderdateutc text;

--alter table fact.transactionitem
add sysinserttime TIMESTAMP;

--alter table fact.transactionitem
add sysupdatetime TIMESTAMP;*/

/*update fact.transactionitem
--set dateid = transactionheader.dateid,
    orderdateutc = transactionheader.orderdateutc
from fact.transactionheader 
where transactionitem.transactionheaderid = transactionheader.transactionheaderid
and transactionitem.orderid = transactionheader.orderid*/


select count(*) as total_cnt, count(distinct transactionheaderid) from fact.transactionitem; --33,717	31,261
select count(*) as total_cnt, count(distinct transactionheaderid) from fact.transactionheader--31,353	31,261

select * from fact.transactionheader
where transactionheaderid in (
    select transactionheaderid
    from fact.transactionheader
    group by transactionheaderid
    having count(*) > 1
)
order by transactionheaderid


select count(*) from fact.transactionitem where transactionheaderid like 'abort%';
select count(*) from fact.transactionheader where transactionheaderid like 'abort%'

SELECT
    --ic.categoryname as CategoryName,
	ti.*
    --SUM(itemquantity) as Count,
    --SUM(th.ordersubtotal), as SalesAmount
FROM fact.transactionheader as th
INNER JOIN dim.datedim as dd ON dd.dateid = th.dateid
left JOIN fact.transactionitem as ti ON ti.transactionheaderid = th.transactionheaderid
--INNER JOIN dim.itemcategory ic on ic.id = ti.categoryid
INNER JOIN dim.organizationlocation as ol ON ol.locationid = th.locationid
WHERE ol.organizationid = 'loc-cde3d28b-9c43-4899-80a3-56cca46241a3'
AND LOWER(th.orderstatus) = 'order-placed'
AND dd.datets BETWEEN '2024-12-29 18:30:00'::TIMESTAMP WITH TIME ZONE AND '2024-12-31 18:29:59'::TIMESTAMP WITH TIME ZONE
order BY ti.transactionheaderid

select * 
from dim.itemcategory 
where locationid = 'loc-cde3d28b-9c43-4899-80a3-56cca46241a3'

select ti.* 
from fact.transactionitem as ti 
inner join fact.transactionheader as th
ON ti.transactionheaderid = th.transactionheaderid and LOWER(th.orderstatus) = 'order-placed'
where th.locationid = 'loc-cde3d28b-9c43-4899-80a3-56cca46241a3'


SELECT DISTINCT 
   c.locationId ?? null as locationid,
  i.categoryId ?? null as categoryid, 
  i.categoryName ?? null as categoryname
FROM c
JOIN i in c.items
where 1=1
and c.isTestOrder = false
and i.categoryId > ''
AND i.categoryName > ''
and c.locationId = 'loc-cde3d28b-9c43-4899-80a3-56cca46241a3'

SELECT DISTINCT
    c.id ?? null as transactionheaderid,
    c.orderId ?? null as orderid,
    c.locationId ?? null as locationid,
    c.kioskSource.kioskId ?? null as kioskid,
    c.kioskSessionId ?? null as ordersessionid,
    c.orderDate ?? null as orderdate,
    c.type ?? null as type,
    c.orderType ?? null as ordertype,
    --c.orderTypeLabel ?? null as ordertype,
    c.totals.subTotal ?? 0.0 as ordersubtotal,
    c.totals.total ?? 0.0 as ordertotal,
    c.totals.tax ?? 0.0 as ordertax,
    c.totals.tip ?? 0.0 as ordertip,
    c.totals.discount ?? null as orderdiscount,
    c.refundedAmount ?? 0.0 as refundedamount,
    c.redeemedRewards ?? null as redeemedrewards,
    --c.items,
    --c.paymentDetails,
    c.businessDate ?? null as businessdate,
    ci.orderItemId,
    ci.categoryId,
    ci.menuItemId,
    ci.name
FROM c
join ci in c.items
where 1=1
and c.isTestOrder = false
and c.kioskSource.kioskId > ''
and c.id > ''
and c.orderDate >= '2024-06-23'
and (c.paymentDetails =[] or c.paymentDetails !=[])
and c.id in ('ordevt-e3t0wjjytm', 'ordevt-4bserpx7rw')


select * from c where c.id in ('ordevt-e3t0wjjytm', 'ordevt-4bserpx7rw')

select locationid, menuitemid, count(*) 
from dim.menuitem
group by locationid, menuitemid
having count(*)>1

--insert into fact.transactionitem 
--(transactionheaderid,categoryid,menuitemid,itemid,ordersessionid,itemsessionid,
--itemname,itemquantity,itemunitprice,upselllevel,upsellpromptitemid,orderid,itemtype,)
select * from fact.transactionitemtest
where transactionheaderid = 'ordevt-4bserpx7rw'
and itemname <> 'Sprite'

