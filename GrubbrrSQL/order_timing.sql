select DISTINCT ol.organizationname, ol.locationname, th.*--count(*)
from fact.transactionheader as th 
inner join (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
        on th.locationid = ol.locationid
where 1=1
--and th.locationid = 'loc-be3572e0-40c6-42a5-8784-6a132e8af3cb'
and th.orderstatus = 'order-placed'--11,681/61,408
--and th.ordersessionid in ('6GF2B0AP2J39FTE5')--,'R90EA4UYI0MDMG0Y') 901-full/11,700 2025-10-23 18:00:24.906	2025-10-23 18:04:23.289	2025-10-23 18:02:26.403	2025-10-23 18:05:08.203	2025-10-23 18:06:05.694	121.497	219.291	238.383	-116.886	57.491	340.788
--and (th.reviewordertime is not null and th.orderstarttime is not null and th.checkouttime is not null and th.paystarttime is not null and th.sessionendtime is not null)
--and (th.reviewordertime is null or th.orderstarttime is null or th.checkouttime is null or th.paystarttime is null or th.sessionendtime is null)
--9,392 / 11,101 --8,936--11,700  8,936 --> 8,899
--and th.businessdate = '2025-08-06'
and th.reviewpagetime < 0 --262
order by th.orderdateutc desc --ol.organizationname-- 
limit 1000

SELECT ot.locationid, ot.eventtoken, ot.deviceid, ot.dateid,
    COUNT(*) as dupl
FROM fact.ordertiming as ot
GROUP BY ot.locationid, ot.eventtoken, ot.deviceid, ot.dateid
HAVING COUNT(*) > 1
ORDER BY dupl DESC
LIMIT 100;

ALTER TABLE IF EXISTS fact.ordertiming DROP CONSTRAINT IF EXISTS locationid_eventtoken_unq;
ALTER TABLE IF EXISTS fact.ordertiming ADD CONSTRAINT locationid_eventtoken_unq UNIQUE (locationid, eventtoken, deviceid, sessionstart);



UPDATE fact.ordertiming
SET id = new_id
FROM (SELECT *, ROW_NUMBER() OVER(ORDER BY id) as new_id FROM fact.ordertiming) as ot 
WHERE ordertiming.id = ot.id

/*Production
Started executing query at Line 29
UPDATE 4,385,707
Total execution time: 00:01:33.791
*/

select th.locationid, th.transactionheaderid, count(*)
from fact.transactionheader as th 
GROUP BY th.locationid, th.transactionheaderid 
HAVING count(*)>1


SELECT *--count(*)
from fact.transactionheader as th
WHERE 1=1 
--and th.ordertype not in (SELECT id from dim.ordertype)
and th.orderstatus = 'order-placed'
and locationid = 'loc-3068e32c-1da4-40bc-956f-f305a8529bc6'
--and th.ordertype is null --338,341/14,224
order by th.orderdateutc desc
LIMIT 100

SELECT *
FROM fact.ordertiming
ORDER BY sessionstart desc
LIMIT 100

SELECT *--ordersessionid
FROM fact.transactionitem
WHERE 1=1 
and transactionheaderid like 'ordevt-%'
--and locationid = 'loc-3068e32c-1da4-40bc-956f-f305a8529bc6'
--and addtocarttime is not null
and sysupdatetime is not null
ORDER BY orderdateutc desc
LIMIT 100


select
    ti.*
from fact.transactionitem ti
inner join fact.transactionheader th on th.transactionheaderid = ti.transactionheaderid
where ti.menuitemid > 0
    and lower(th.orderstatus) = 'order-placed'
    and th.locationid = 'loc-3068e32c-1da4-40bc-956f-f305a8529bc6'
    and	th.businessdate between '2025-01-01'::DATE and '2025-09-30';



SELECT * FROM dim.organizationlocation
WHERE organizationid = 'org-07dd10c8-82e2-44b8-b6fa-0961c3950a57'

SELECT DISTINCT *
    /*busdate,
    eventtype,
    ordersessionidentifier,
    itemsessionidentifier,
    elementidentifier*/
FROM 
    fact.userbehaviour
WHERE 1=1 
  --AND locationid = 'loc-3068e32c-1da4-40bc-956f-f305a8529bc6'-- 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc' 
  --ORDER BY busdate desc
  AND eventtype IN (
        'ItemCustomizeClicked',
        'CustomizeItemSelected',
        'ComboCustomizeClicked',
        'RegularItemSelected',
        'ComboComponentItemSelected',
        'AddToCartClicked',
        'ComboSizeSelected',
        'ComboItemSelected',
        'AddAsIsSelected'
)
--ORDER BY busdate desc LIMIT 1000
AND ordersessionidentifier in (
    SELECT DISTINCT ordersessionid
    FROM fact.transactionitem
    WHERE 1=1 
    and transactionheaderid like 'ordevt-%'
    --and locationid = 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc'
    and addtocarttime is null
    --and sysupdatetime = '2025-09-22 12:20:56.266063' :: TIMESTAMP
    --ORDER BY orderdateutc desc

)
ORDER BY busdate desc
LIMIT 100;

UPDATE fact.userbehaviour
SET busdate = 
case when substring(eventinstant, 20, 1) = '.' 
     then cast(replace(replace(substring(eventinstant, 1, 23), 'T', ' '), '+', '0') as TIMESTAMP)
     else cast(substring(eventinstant, 1, 19) as TIMESTAMP) end
WHERE eventinstant is not null;

SELECT th.locationid, th.ordersessionid,
       COUNT(*) as dup_count
from fact.transactionheader as th
WHERE 1=1 
--and th.ordertype not in (SELECT id from dim.ordertype)
and th.orderstatus = 'order-placed'
GROUP BY th.locationid, th.ordersessionid
HAVING COUNT(*) > 1
ORDER BY dup_count desc


UPDATE fact.transactionheader
set ordertype = null 
WHERE ordertype not in (SELECT id from dim.ordertype)

SELECT * from dim.ordertype
ORDER BY id

SELECT DISTINCT dt.yearval, dt.weekval, dt.dayval 
FROM dim.datedim as dt
WHERE 1=1
AND dt.weekval = 17
AND dt.yearval = 2025

--30 2025-07-20 2025-07-26
--17 2025-04-20 2025-04-26
