SELECT --sum((th.ordertotal - coalesce(th.ordertip,0) - coalesce(th.orderservicecharge,0) - coalesce(th.charityamount,0))) as salesAmount
--sum(th.ordertotal - coalesce(th.orderservicecharge,0))
sum(th.ordertotal - th.ordertip - th.orderservicecharge - th.charityamount) as gas_sum,
sum(th.ordersubtotal - th.orderdiscount - th.ordersredeemedrewards + th.ordertax) as nge_sum
FROM fact.transactionheader as th 
WHERE th.locationid = 'loc-e73fdbc1-d8cb-4e88-9809-8f7041cab09b'
--AND th.transactionheaderid = 'ordevt-m7fifhl2n7'
AND th.businessdate = '2026-01-26'-- BETWEEN '2026-01-26' AND '2026-01'
AND th.orderstatus = 'order-placed'



SELECT th.transactionheaderid,
       th.ordersubtotal,
       th.ordertax,
       th.ordertip,
       th.ordertotal,
       th.orderdiscount,
       th.ordersredeemedrewards,
       th.orderservicecharge,
       th.charityamount,
       th.syscosmosts
FROM fact.transactionheader as th 
WHERE th.locationid = 'loc-e73fdbc1-d8cb-4e88-9809-8f7041cab09b'
AND th.businessdate = '2026-01-26'-- BETWEEN '2026-01-26' AND '2026-01'
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