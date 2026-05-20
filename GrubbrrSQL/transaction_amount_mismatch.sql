SELECT --sum((th.ordertotal - coalesce(th.ordertip,0) - coalesce(th.orderservicecharge,0) - coalesce(th.charityamount,0))) as salesAmount
--sum(th.ordertotal - coalesce(th.orderservicecharge,0))
sum(th.ordertotal - th.ordertip - th.orderservicecharge - th.charityamount) as gas_sum,
sum(th.ordersubtotal - th.orderdiscount - th.ordersredeemedrewards + th.ordertax) as nge_sum
FROM fact.transactionheader as th 
WHERE th.locationid = 'loc-e73fdbc1-d8cb-4e88-9809-8f7041cab09b'
--AND th.transactionheaderid = 'ordevt-m7fifhl2n7'
AND th.businessdate = '2026-01-26'-- BETWEEN '2026-01-26' AND '2026-01'
AND th.orderstatus = 'order-placed'

SELECT ol.organizationId, ol.organizationname, 
       th.locationid, ol.locationname,-- th.businessdate,
       count(*) as trxn_count,
       sum(th.ordertotal - th.ordertip - th.orderservicecharge - th.charityamount) as gas_sum,
       sum(th.ordersubtotal - th.orderdiscount - th.ordersredeemedrewards + th.ordertax) as nge_sum,
       min(th.orderdatelocal) as first_order_time,
       max(th.orderdatelocal) as last_order_time,
       max(updateddate) as max_updateddate
FROM (select * from fact.transactionheader WHERE businessdate >= '2022-01-01') as th
INNER JOIN (select * from dim.organizationlocation where organizationtype = 0) as ol 
        on th.locationid = ol.locationid
WHERE 1=1
--AND th.locationid = 'loc-0fa39b77-9897-4d35-9c23-c94ec9d08db2'-- 'loc-e73fdbc1-d8cb-4e88-9809-8f7041cab09b' --
--AND th.transactionheaderid = 'ordevt-m7fifhl2n7'
--AND th.businessdate = '2026-01-28' --AND '2028-12-31'-- BETWEEN '2026-01-26' AND '2026-01'
AND th.orderstatus = 'order-placed'
GROUP BY ol.organizationId, ol.organizationname, 
         th.locationid, ol.locationname--, th.businessdate
HAVING sum(th.ordertotal - th.ordertip - th.orderservicecharge - th.charityamount) = --P=90**P<>112***R=52**R<>47
       sum(th.ordersubtotal - th.orderdiscount - th.ordersredeemedrewards + th.ordertax);


SELECT th.transactionheaderid,
       th.ordersubtotal,
       th.ordertax,
       th.ordertip,
       th.ordertotal,
       th.orderdiscount,
       th.ordersredeemedrewards,
       th.orderservicecharge,
       th.charityamount,
       th.syscosmosts,
       th.businessdate,
       th.orderdatelocal
FROM fact.transactionheader as th 
WHERE th.locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992' --'loc-e73fdbc1-d8cb-4e88-9809-8f7041cab09b'
--AND th.businessdate = '2026-01-26'-- BETWEEN '2026-01-26' AND '2026-01'
AND th.orderstatus = 'order-placed'
ORDER BY th.syscosmosts DESC


SELECT th.locationid, th.transactionheaderid, th.ordersessionid, th.businessdate, th.orderdatelocal, th.orderstatus,
       th.orderstarttime, th.reviewordertime, th.checkouttime, th.paystarttime, th.sessionendtime
FROM fact.transactionheader as th 
WHERE 1=1
AND th.orderstatus <> 'order-placed'
--AND (th.orderstarttime is null or th.reviewordertime is null or th.checkouttime is null or th.paystarttime is null or th.sessionendtime is null)
AND (th.orderstarttime is not null  
    and th.reviewordertime is not null
    --and th.checkouttime is not null 
    --and th.paystarttime is not null 
    --and th.sessionendtime is not null
    )
ORDER BY updateddate desc
LIMIT 1000

/*
--UPDATE fact.transactionheader as th
--/SET ordertotal = 13.340
WHERE th.locationid = 'loc-e73fdbc1-d8cb-4e88-9809-8f7041cab09b'
AND th.transactionheaderid = 'ordevt-m7fifhl2n7'
AND th.businessdate = '2026-01-26'-- BETWEEN '2026-01-26' AND '2026-01'
AND th.orderstatus = 'order-placed'
*/