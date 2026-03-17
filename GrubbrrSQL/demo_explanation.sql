/** Dim tables
1. dim.itemcategory
2. dim.location
3. dim.menuitem
4. dim.kiosk
5. dim.ordertype
6. dim.frequentcustomer
7. dim.upsellgrouplookup
8. dim.organization
9. dim.organizationlocation
10.dim.vw_grubbrrinstallbase
**/ 

/** Fact tables
1. fact.transactionheader --order-level
2. fact.transactionitem   --item-level
3. fact.transactionpayment
4. fact.itemmodifier
5. fact.transactionrefunds
6. fact.deviceevent
7. fact.userbehaviour
8. fact.recommendations   Smart/AI Upsells
9. fact.vw_offer_analysis
10.fact.usercheckedin
*/
SELECT l.locationname,
       l.city,
       fc.frequentcustomerid,
       fc.ordercount,
       th.transactionheaderid,
       th.orderid,
       th.kioskid,
       k.kioskname,
       ti.itemid,
       ic.categoryname,
       mi.menuitemname,
       th.ordertotal,
       ot.ordertypelabel,
       th.orderdatelocal,
       th.businessdate
from fact.transactionheader as th --order-level
inner join fact.transactionitem as ti --item-level
 on ti.transactionheaderid = th.transactionheaderid
and ti.locationid = th.locationid
inner join dim.itemcategory as ic on ic.id = ti.categoryid
inner join dim.location as l on l.locationid = th.locationid
inner join dim.menuitem as mi on mi.id = ti.menuitemid
inner join dim.ordertype as ot on ot.id = th.ordertype
inner join dim.kiosk as k on k.kioskid = th.kioskid
inner join dim.frequentcustomer as fc on th.frequentcustomerid = fc.frequentcustomerid
and k.locationid = th.locationid
where 1=1
        and lower(th.orderstatus) = 'order-placed'
order by fc.ordercount desc
LIMIT 1000;

SELECT max(th.syscosmosts) as maxts, 'fact.transactionheader' as watermarktablename
FROM fact.transactionheader as th

SELECT *-- wt.ts as maxts, wt.ticks as maxticks, watermarkvalue as maxinstant
FROM fact.watermarktable as wt
WHERE wt.watermarktablename = 'fact.transactionheader';

select * 
from dim.frequentcustomer
ORDER BY ordercount desc

SELECT *
from fact.recommendations as r 
where 1=1
ORDER by prompttimestamp desc
LIMIT 1000


SELECT *
from fact.transactionrefunds as tr 
where 1=1
--and tr.orderdateutc is not null
and tr.orderid = 'ord-11215151085290273350'
order by orderdateutc desc;

SELECT *
from fact.transactionheader as th
where 1=1
and th.locationid = 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3'-- in ('loc-ae8a76b8-6974-4b81-b935-ada633d00108', 'loc-dce5171a-94cf-42fa-bc51-6df9a383ff77') --and th.orderstatus = 'order-placed'
--and th.orderdateutc like '2025-07-%'
--and th.orderid = 'ord-11215151085290273350'
and th.transactionheaderid like 'ordevt-%'
and th.businessdate >= '2025-07-01'
order by th.orderdateutc desc
LIMIT 100;

SELECT *
from fact.transactionpayment as tp --order-level
where 1=1
--and tp.orderdateutc is not null
and tp.orderid = 'ord-11215151085290273350'
ORDER BY tp.orderdateutc desc;

SELECT *
from fact.itemmodifier
LIMIT 100

SELECT *
from fact.usercheckedin as uc 
where 1=1
order by orderdatelocal desc
LIMIT 100;

        
select *-- distinct ti.upselllevel
from fact.transactionitem as ti 
where ti.transactionheaderid like 'ordevt-%' --placed/completed orders
and ti.upselllevel is not null 
order by orderdateutc DESC
LIMIT 100

SELECT *
from fact.deviceevent
LIMIT 100;

SELECT *
from fact.userbehaviour
ORDER BY createddate desc
LIMIT 100;


SELECT *-- l.locationid, *--, count(*)
from dim.location as l
GROUP BY l.locationid
HAVING count(*) > 1;


SELECT *
from dim.menuitem
ORDER BY id

SELECT *
from dim.ordertype
ORDER BY locationid,
         kioskid,
         ordertypeid


SELECT *
from dim.itemcategory
where id between 1 and 15
ORDER BY id


SELECT *-- locationid, kioskid, COUNT(*)
from dim.kiosk
GROUP BY locationid,
         kioskid
HAVING count(*) > 1;



SELECT DISTINCT c.id ?? null AS transactionheaderid,
                c.orderId ?? null AS orderid,
                c.locationId ?? null AS locationid,
                c.orderDate ?? null AS orderdate,
                c.kioskSessionId ?? null AS ordersessionid,
                i.orderItemId ?? null AS itemid1,
                i.itemSessionId ?? null AS itemsessionid1,
                i.menuItemId ?? null AS menuitemid1,
                i.name ?? null AS itemname1,
                i.quantity ?? null AS itemquantity1,
                i.unitPrice ?? null AS itemunitprice1,
                i.categoryId ?? null AS categoryid1,
                i.upsellSource.upsellLevelType ?? null AS upselllevel1,
                i.upsellSource.upsellPromptItemId ?? null AS upsellpromptitemid1,
                c.kioskSource.kioskId ?? null AS kioskid
FROM c
JOIN i IN c.items
WHERE 1=1
        AND c._ts > {$pdf_ts}
        AND (c.isTestOrder = false
             OR is_defined(c.isTestOrder) = false)
        AND c.orderDate >= '2024-06-23'
        AND c.kioskSource.kioskId > ''