WITH dupl AS (
    SELECT *, 
    CASE WHEN th.orderid <> 'ord-' AND th.orderid IS NOT NULL THEN 1 ELSE 0 END as has_orderid
    FROM fact.transactionheader as th --transactionitem
    WHERE 1=1
    AND th.transactionheaderid LIKE 'abort-%' 
    --AND th.orderid IS NOT NULL
    AND th.businessdate >= '2026-03-25'
), latest_orders AS (
    SELECT *,
    ROW_NUMBER() OVER(PARTITION BY locationid, ordersessionid ORDER BY has_orderid DESC, transactionheaderid DESC) as rn
    FROM dupl
)
SELECT * FROM fact.transactionheader as th --delete
WHERE EXISTS (SELECT 1 FROM latest_orders as dupl 
              WHERE dupl.locationid = th.locationid 
                AND dupl.transactionheaderid = th.transactionheaderid
                AND dupl.rn > 1)

--Identify Duplicate order entries

SELECT th.locationid, th.ordersessionid, count(*) as dupl
FROM fact.transactionheader as th 
    WHERE 1=1
    AND th.transactionheaderid LIKE 'abort-%' 
    AND th.orderid IS NOT NULL
    AND th.businessdate >= '2026-03-25'
GROUP BY th.locationid, th.ordersessionid
HAVING count(*)>1
ORDER BY dupl DESC;

--LIMIT 100--Postgresql, Oracle

SELECT *--DISTINCT locationid, ordersessionid, dateid
FROM fact.transactionheader as th 
WHERE th.locationid = 'loc-9dbd4815-f50a-4e4f-ac1d-5fd6d9ec728e'-- 'loc-b8c181a0-69ca-42e7-9f22-50fd23cb9bec'-- 'loc-61493b82-41d7-4b02-b788-de845b480d17'
--AND th.transactionheaderid = 'abort-639107488481834591'
--AND th.orderid = 'ord-EY80X7B2YDGFFXUA'
AND th.ordersessionid = '0FZ8THB47WUX45SD' --'YIUGEOH6QXXOW3BE'
AND th.orderstatus = 'order-placed'
AND th.businessdate = '2026-01-28'





SELECT FROM fact.occasionsurveydetail
WHERE orderid IN ('')

SELECT *
FROM fact.occasionsurveydetail



SELECT *
FROM fact.transactionrefunds as tr

SELECT *
FROM dim.organizationlocation as ol 
WHERE 1=1
AND ol.locationid = 'loc-e73fdbc1-d8cb-4e88-9809-8f7041cab09b'


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

SELECT *
FROM fact.transactionitem as ti --header as ti-- 
WHERE ti.transactionheaderid = 'ordevt-D9H0PZTGO2IVK8U0'
OR ti.ordersessionid = 'D9H0PZTGO2IVK8U0'

/*
--UPDATE fact.transactionheader as th
--/SET ordertotal = 13.340
WHERE th.locationid = 'loc-e73fdbc1-d8cb-4e88-9809-8f7041cab09b'
AND th.transactionheaderid = 'ordevt-m7fifhl2n7'
AND th.businessdate = '2026-01-26'-- BETWEEN '2026-01-26' AND '2026-01'
AND th.orderstatus = 'order-placed'
*/