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