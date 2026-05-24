-- Let Postgres clean up the dead tuples from 6.1M updates
--VACUUM ANALYZE fact.transactionpayment;
--VACUUM ANALYZE fact.transactionheader;
--VACUUM ANALYZE fact.transactionitem;
--VACUUM ANALYZE fact.itemmodifier;



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
