SELECT * FROM dim.ordertype
SELECT * FROM dim.kiosk ORDER BY id 
SELECT * FROM dim.element ORDER BY elementid desc LIMIT 100

SELECT count(*), max(createddate), max(updateddate), max(syscosmosts)--, max(th.sysinserttime)
FROM fact.transactionheader as th --742,385	2025-10-09 18:14:33.529755	2025-10-09 18:17:07.622153	1760033667
WHERE th.orderstatus <> 'order-placed'
ORDER BY th.orderdateutc DESC
LIMIT 10


SELECT *-- count(*), max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.transactionitem as ti --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
ORDER BY ti.orderdateutc DESC
LIMIT 10


SELECT COUNT(*)-- OVER(PARTITION BY tp.locationid, tp.transactionheaderid) dupl, *--, count(*), max(tp.sysinserttime)--, max(tp.sysupdatetime)--, max(syscosmosts)
FROM fact.transactionpayment as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
WHERE tp.sysinserttime = '2025-08-14 12:06:20.690912' --357,188
--GROUP BY tp.locationid, tp.transactionheaderid
--HAVING COUNT(*) > 1
ORDER BY dupl desc, tp.transactionheaderid -- tp.sysinserttime DESC
LIMIT 10000

SELECT *-- tp.locationid, tp.transactionheaderid, count(*)--, max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.transactionrefunds as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
GROUP BY tp.locationid, tp.transactionheaderid
HAVING COUNT(*) > 1
ORDER BY tp.sysinserttime DESC
LIMIT 10

ALTER TABLE fact.transactionrefunds
ADD CONSTRAINT locationid_transactionheaderid_pk PRIMARY KEY (locationid, transactionheaderid)

SELECT tp.transactionheaderid, tp.itemid, tp.modifiergroupid, tp.modifierid, count(*)--, max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.itemmodifier as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
--WHERE tp.sysinserttime is not null
GROUP BY tp.transactionheaderid, tp.itemid, tp.modifiergroupid, tp.modifierid
HAVING COUNT(*) > 1
ORDER BY tp.sysinserttime DESC
LIMIT 10

ALTER TABLE fact.itemmodifier
ADD CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY KEY (transactionheaderid, itemid, modifiergroupid, modifierid)

SELECT tp.locationid, tp.orderid, tp.surveytransid, tp.itemid, count(*)--, max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.itemssurvey as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
WHERE tp.sysinserttime is not null
GROUP BY tp.locationid, tp.orderid, tp.surveytransid, tp.itemid
HAVING COUNT(*) > 1
ORDER BY tp.sysinserttime DESC
LIMIT 10

ALTER TABLE fact.itemssurvey
ADD CONSTRAINT locationid_orderid_surveytransid_itemid_pk PRIMARY KEY (locationid, orderid, surveytransid, itemid)

SELECT tp.locationid, tp.orderid, tp.surveytransid, count(*)--, max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.occasionsurveydetail as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
WHERE tp.sysinserttime is not null
GROUP BY tp.locationid, tp.orderid, tp.surveytransid--, tp.itemid
HAVING COUNT(*) > 1
ORDER BY tp.sysinserttime DESC
LIMIT 10

ALTER TABLE fact.occasionsurveydetail
ADD CONSTRAINT locationid_orderid_surveytransid_pk PRIMARY KEY (locationid, orderid, surveytransid)

SELECT *-- tp.locationid, tp.deviceid, tp.eventtoken, count(*)-- *-- tp.id, count(*)-- tp.locationid, tp.deviceid, tp.eventtoken, count(*)--, max(id) -- DISTINCT tp.locationid, tp.deviceid, cast(tp.sessionstart as date) -- count(*), max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.ordertiming as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
--WHERE tp.eventtoken = '8MPBBG6P1DWHK75Q'-- tp.dateid is null-- tp.sessionstart > '2025-10-10 00:00:00.000' --is not null
--GROUP BY tp.locationid, tp.deviceid, tp.eventtoken-- tp.id-- tp.locationid, tp.deviceid, tp.eventtoken--, tp.itemid
--HAVING COUNT(*) > 1
ORDER BY id desc-- cast(tp.sessionstart as date) DESC
LIMIT 10--186,338

ALTER TABLE fact.ordertiming
ADD CONSTRAINT ordertiming_pkey PRIMARY KEY (id)

SELECT ('2025-07-20 14:04:48.857557' :: TIMESTAMP) :: TIMESTAMP

SELECT *-- count(*), max(id) -- DISTINCT tp.locationid, tp.deviceid, cast(tp.sessionstart as date) -- count(*), max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.recommendations as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
--WHERE tp.sessionstart > '2025-10-10 00:00:00.000' is not null
ORDER BY tp.sysinserttime desc-- cast(tp.sessionstart as date) DESC
LIMIT 10--186,338

ALTER TABLE fact.recommendations
ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid)

SELECT count(*)--, max(id) -- DISTINCT tp.locationid, tp.deviceid, cast(tp.sessionstart as date) -- count(*), max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.vw_offer_analysis as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
--WHERE tp.sessionstart > '2025-10-10 00:00:00.000' is not null
ORDER BY tp.sysinserttime desc-- cast(tp.sessionstart as date) DESC
LIMIT 10--186,338

SELECT locationid, orderid, count(*)--, max(id) -- DISTINCT tp.locationid, tp.deviceid, cast(tp.sessionstart as date) -- count(*), max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.usercheckedin as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
--WHERE tp.sessionstart > '2025-10-10 00:00:00.000' is not null
GROUP BY locationid, orderid
HAVING COUNT(*) > 1
ORDER BY tp.sysinserttime desc-- cast(tp.sessionstart as date) DESC
LIMIT 10--186,338

ALTER TABLE fact.usercheckedin
ADD CONSTRAINT locationid_orderid_uidx PRIMARY KEY(locationid, orderid)

SELECT *-- tp.id, count(*)-- count(*), max(id) -- DISTINCT tp.locationid, tp.deviceid, cast(tp.sessionstart as date) -- count(*), max(ti.sysinserttime), max(ti.sysupdatetime)--, max(syscosmosts)
FROM fact.userbehaviour as tp --1,343,787	2025-10-09 14:29:02.950211	2025-10-09 14:21:10.799746
--WHERE tp.sessionstart > '2025-10-10 00:00:00.000' is not null
--GROUP BY tp.id --desc --15,592
--HAVING count(*) > 1
ORDER BY tp.createddate desc
LIMIT 100--186,338

SELECT count(*) FROM fact.userbehaviour WHERE createddate >= '2025-10-05 00:00:00.000' :: TIMESTAMP

ALTER TABLE fact.userbehaviour
ADD CONSTRAINT userbehaviour_pkey PRIMARY KEY (id)

SELECT *--locationid, eventtoken, datacategory, actiontype, eventinstant, 
       --count(*)--, max(eve)
FROM fact.deviceevent as tp --S**61,221,386
--GROUP BY locationid, eventtoken, datacategory, actiontype, eventinstant --dupl yes
--HAVING count(*) > 1
--ORDER BY de.sysinserttime desc 
LIMIT 10 --no ID
--638,878,530,284,468,313

ALTER TABLE fact.deviceevent
ADD CONSTRAINT locationid, eventtoken, datacategory, actiontype, eventinstant
--????

SELECT *--count(*)-- *-- tp.locationid, tp.deviceid, tp.state, tp.lasteventtime, count(*)--, max(de.lasteventtime)
FROM fact.devicestate as tp --P**117,537 ---S**109,782
WHERE tp.lasteventtime is not null
--GROUP BY tp.locationid, tp.deviceid, tp.state, tp.lasteventtime --desc --15,592
--HAVING count(*) > 1
order BY tp.lasteventtime desc --15,592
--HAVING count(*) > 1
LIMIT 100

--????

SELECT tp.locationid, tp.deviceid, tp.dateid, count(*)-- max(eve)
FROM fact.devicetelemetry as tp --S**61,221,386
--WHERE de.dateid is not null
GROUP BY tp.locationid, tp.deviceid, tp.dateid--, tp.lasteventtime --desc --15,592
HAVING count(*) > 1
ORDER BY de.cputimestamp desc 
LIMIT 10

ALTER TABLE fact.devicetelemetry
ADD CONSTRAINT locationid_deviceid_dateid_pk PRIMARY KEY (locationid, deviceid, dateid)

SELECT * FROM dim.organization
ORDER BY createdon desc

SELECT * 
FROM fact.transactionheader as th
WHERE th.createddate is not null
ORDER BY th.createddate desc
LIMIT 100

SELECT * FROM fact.watermarktable;

SELECT * 
FROM fact.transactionrefunds
--WHERE 
LIMIT 100