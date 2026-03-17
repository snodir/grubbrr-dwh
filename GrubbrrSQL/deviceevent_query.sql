WITH order_items as (
    SELECT *
    FROM fact.transactionitem as ti
    WHERE ti.transactionheaderid like 'ordevt-%'
    AND ti.locationid = 'loc-x4pw1awq97'
    AND ti.orderdateutc like '2026-02-20 20%' 
    ORDER BY orderdateutc DESC LIMIT 1000
)
SELECT *
FROM order_items as it
INNER JOIN fact.deviceevent as de 
    ON it.locationid = de.locationid
    AND it.
WHERE 1=1
AND de.locationid = 'loc-x4pw1awq97'
AND de.actiontype = 'ModifierSelected'
--AND de.eventtoken = 'PIKEBY9B3C5ZN6LD'
ORDER BY de.eventinstant DESC
LIMIT 100

SELECT *
FROM fact.deviceevent as de
WHERE 1=1
AND de.application = 'nge'
AND de.companyid = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269' --Bojangles
AND de.locationid = 'loc-f8417e68-4a8a-4fa6-8c9b-780564b86a90' --Monro
AND de.moduleid = 'kiosk'
--AND de.eventtoken = 'ZUADG48O7E1H3AFI'
AND de.datacategory = 'insight'
AND de.actiontype = 'ModifierSelected'
--AND de.dateid = 2026022014
ORDER BY de.eventinstant DESC 
LIMIT 100

SELECT * FROM fact.userbehaviour as ub 
WHERE ub.eventcategory = 'insight'
AND ub.eventtype = 'ModifierSelected'
ORDER BY id desc LIMIT 100

SELECT *
FROM dim.organizationlocation as ol
WHERE ol.locationid = 'loc-f8417e68-4a8a-4fa6-8c9b-780564b86a90'
AND ol.organizationtype = 0

SELECT th.locationid, th.businessdate, th.ordersessionid, im.*
FROM fact.itemmodifier as im 
INNER JOIN fact.transactionheader as th 
    ON im.transactionheaderid = th.transactionheaderid
WHERE 1=1
AND th.businessdate = '2026-02-20'
AND th.ordersessionid = 'ZUADG48O7E1H3AFI'
--ORDER BY th.dateid DESC
LIMIT 100

ORDER BY im.sysinserttime DESC
LIMIT 100