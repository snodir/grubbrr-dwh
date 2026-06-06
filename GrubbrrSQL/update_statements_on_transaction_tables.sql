-- Let Postgres clean up the dead tuples from 6.1M updates
--VACUUM ANALYZE fact.transactionpayment;
--VACUUM ANALYZE fact.transactionheader;
--VACUUM ANALYZE fact.transactionitem;
--VACUUM ANALYZE fact.itemmodifier;

SELECT *
FROM fact.transactionheader as th
WHERE th.orderid LIKE 'ord--%'
ORDER BY createddate DESC

UPDATE fact.transactionheader
SET orderid = CONCAT(orderid, ordersessionid)
WHERE orderid         = 'ord-';
  AND ordersessionid <> '' ;

UPDATE fact.transactionheader
   SET orderid = CONCAT(orderid, SUBSTRING(transactionheaderid, 8, LENGTH(transactionheaderid)))
WHERE orderid        = 'ord-'
  AND ordersessionid = '' ;



UPDATE fact.transactionitem
SET orderid = CONCAT(orderid, ordersessionid)
WHERE orderid = 'ord-';


UPDATE fact.transactionpayment
SET orderid = th.orderid
FROM fact.transactionheader as th
WHERE transactionpayment.locationid          = th.locationid
  AND transactionpayment.transactionheaderid = th.transactionheaderid
  AND transactionpayment.orderid = 'ord-';


UPDATE fact.vw_offer_analysis
SET upselltype = 'AI-Order'
WHERE locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
AND upselltype = 'Smart Upsells'




UPDATE fact.transactionitem
SET upselllevel = 'AI-Order'
WHERE locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
AND upselllevel = 'Order'
AND transactionheaderid in(
    'ordevt-CNPOGTSBP47OVWI5',
    'ordevt-S84VP26L0YQVO83Q',
    'ordevt-L3P6U07LKMNZ6NC0',
    'ordevt-60T2WJ12YLEXKV4A',
    'ordevt-1YEPZM4KNIECW982'
)

UPDATE dim.frequentcustomer
SET ordercount = coalesce(th.ordercount, 0),
    amountspent = coalesce(th.amountspent, 0),
    sysupdatetime = now()
FROM (
    SELECT frequentcustomerid, count(*) as ordercount, sum(ordertotal) as amountspent
    FROM fact.transactionheader 
    WHERE orderstatus = 'order-placed' and frequentcustomerid is not null
    GROUP BY frequentcustomerid) as th 
WHERE th.frequentcustomerid = frequentcustomer.frequentcustomerid;

UPDATE fact.transactionitem
SET orderdatelocal = th.orderdatelocal,
    businessdate = th.businessdate,
    syscosmosts = th.syscosmosts,
    frequentcustomerid = th.frequentcustomerid
FROM fact.transactionheader as th
WHERE transactionitem.locationid = th.locationid
  AND transactionitem.transactionheaderid = th.transactionheaderid
  AND transactionitem.orderdatelocal IS NULL;


UPDATE fact.transactionpayment
SET kioskid = th.kioskid,
    orderdateutc = th.orderdateutc,
    syscosmosts = th.syscosmosts
FROM fact.transactionheader as th
WHERE transactionpayment.locationid = th.locationid
  AND transactionpayment.transactionheaderid = th.transactionheaderid
  AND (transactionpayment.kioskid IS NULL 
    OR transactionpayment.orderdateutc IS NULL 
    OR transactionpayment.syscosmosts IS NULL);

UPDATE fact.itemmodifier
SET locationid = ti.locationid,
    businessdate = ti.businessdate,
    syscosmosts = ti.syscosmosts
FROM fact.transactionitem as ti 
WHERE itemmodifier.transactionheaderid = ti.transactionheaderid
  AND itemmodifier.itemid = ti.itemid
  AND itemmodifier.locationid IS NULL;

UPDATE fact.itemmodifier
SET locationid = th.locationid,
    businessdate = th.businessdate,
    syscosmosts = th.syscosmosts
FROM fact.transactionheader as th 
WHERE itemmodifier.locationid = th.locationid
  AND itemmodifier.transactionheaderid = th.transactionheaderid
  AND (itemmodifier.locationid IS NULL
    OR itemmodifier.businessdate IS NULL
    OR itemmodifier.syscosmosts IS NULL);

SELECT * FROM fact.transactionitem WHERE locationid IS NULL;
SELECT * FROM fact.transactionpayment WHERE locationid IS NULL;

SELECT * FROM fact.transactionitem as ti
WHERE EXISTS (SELECT 1 FROM fact.itemmodifier as im WHERE im.locationid IS NULL AND im.transactionheaderid = ti.transactionheaderid)-- AND im.itemid = ti.itemid)
(
SELECT *-- transactionheaderid 
FROM fact.itemmodifier as im
WHERE 1=1
--AND NOT EXISTS (SELECT 1 FROM fact.transactionitem as ti WHERE ti.transactionheaderid = im.transactionheaderid)
AND locationid IS NULL
);

--DELETE FROM fact.itemmodifier WHERE locationid IS NULL
