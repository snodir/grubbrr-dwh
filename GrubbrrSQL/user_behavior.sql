CREATE TABLE IF NOT EXISTS fact.userbehaviour_reload
(
    --id bigint NOT NULL,
    busdate timestamp without time zone,
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    daypart text COLLATE pg_catalog."default",
    ordertype bigint,
    eventtype text COLLATE pg_catalog."default",
    ordersessionidentifier text COLLATE pg_catalog."default",
    viewidentifier integer,
    itemsessionidentifier text COLLATE pg_catalog."default",
    elementidentifier integer,
    quantity integer,
    createddate timestamp without time zone,
    syscosmosts bigint,
    eventinstant text COLLATE pg_catalog."default"
    --CONSTRAINT userbehaviour_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE fact.userbehaviour_reload
    OWNER to citus;

ALTER TABLE fact.userbehaviour_reload
ADD COLUMN IF NOT EXISTS status INTEGER

-- Index: fact.userbehaviour_locationid_dateid_idx
/*CREATE INDEX IF NOT EXISTS userbehaviour_locationid_dateid_idx
    ON fact.userbehaviour USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier)
    TABLESPACE pg_default;*/

--INSERT INTO fact.userbehaviour_exceptions

ALTER TABLE fact.userbehaviour
add syscosmosts BIGINT,
add eventinstant text

select * from fact.userbehaviour
where busdate > now()
--order by busdate desc

SELECT *
FROM dim.VIEW


SELECT *
FROM dim.menuitem
WHERE 1=1 and item_class_type is not null
ORDER BY id desc

ALTER TABLE dim.VIEW
ADD CONSTRAINT view_pkey PRIMARY KEY (viewid)

SELECT --substring(eventinstant, 1, 7) as yyyymm, 
       count(*), 
       min(eventinstant) as min_eventinstant,
       max(eventinstant) as max_eventinstant,
       min(syscosmosts) as min_syscosmosts,
       max(syscosmosts) as max_syscosmosts
FROM fact.userbehaviour_reload
WHERE eventinstant > '2025-10-06T14:47:19.999+00:00'
GROUP BY substring(eventinstant, 1, 7)
ORDER BY yyyymm
--9,305,904	    2025-05-30T13:54:25.887+00:00	2025-12-11T17:00:31+00:00	1761582023	1765472589
--2025-10	792,343	2025-10-06T14:47:19.999+00:00	2025-10-31T23:59:59.71+00:00	1761582023	1764877459
--9,305,840	    2025-10-06T14:47:20.06+00:00	2025-12-11T17:00:31+00:00	1761582023	1765472589

SELECT createddate, 
       count(*), 
       max(id) as max_id,
       min(id) as min_id,
       min(eventinstant) as min_eventinstant,
       max(eventinstant) as max_eventinstant,
       min(syscosmosts) as min_syscosmosts,
       max(syscosmosts) as max_syscosmosts
FROM fact.userbehaviour
WHERE 1=1 
AND createddate :: date = '2025-12-11' :: date --2025-12-11 16:20:18.841126	9305904
GROUP BY createddate                  --max_id    min_id
--2025-12-11 16:20:18.841126	9,305,904	48554247	39248344	2025-05-30T13:54:25.887+00:00	2025-12-11T17:00:31+00:00	1761582023	1765472589

SELECT --substring(eventinstant, 1, 7) as yyyymm, 
       count(*), 
       max(id) as max_id,
       min(id) as min_id,
       min(eventinstant) as min_eventinstant,
       max(eventinstant) as max_eventinstant,
       min(syscosmosts) as min_syscosmosts,
       max(syscosmosts) as max_syscosmosts
FROM fact.userbehaviour--_reload
WHERE 1=1 
--and eventinstant > '2025-12-11T17:00:31+00:00'
and eventinstant > '2025-10-06T14:47:19.999+00:00'
GROUP BY substring(eventinstant, 1, 7)
ORDER BY yyyymm
--49,818,647	2025-07-25T02:21:59.984+00:00	    2025-12-12T02:40:49+00:00	1753410136	1765507875
--123,515+++del	    2025-12-11T17:00:31.0327742+00:00	2025-12-12T02:40:49+00:00	1765475133	1765507875
--123,132	2025-12-11T17:00:31.0327742+00:00	2025-12-12T02:40:49+00:00	1765475133	1765507875
--10,493,097	2025-10-06T14:47:20.736+00:00	2025-12-11T17:00:31+00:00	1759762043	1765507039
/*INSERT INTO fact.userbehaviour_reload
SELECT busdate, locationid, dateid, daypart, ordertype, eventtype, ordersessionidentifier, viewidentifier, 
       itemsessionidentifier, elementidentifier, quantity, createddate, syscosmosts, eventinstant,
       0 as status 
from fact.userbehaviour*/
--INSERT 0 10,493,097
--DELETE 10,493,097   DELETE 9,167,804
--DELETE FROM- fact.userbehaviour as ub
--SELECT * FROM fact.watermarktable


SELECT min(eventinstant), max(eventinstant), max(syscosmosts), count(*) 
 FROM fact.userbehaviour WHERE 1=1 AND eventinstant > '2025-12-10T00:00:00.000' --AND lower(eventcategory) <> 'insight' AND eventcategory IS NOT NULL
--2025-12-10T04:38:42.444+00:00, 72,504 Test
--2025-12-10T00:20:55+00:00	     124,187 Reg

SELECT *-- count(*)
FROM fact.userbehaviour as ub 
WHERE 1=1 --and locationid = 'loc-a8845b12-b118-4c08-bb08-66d1e38957e8' AND eventtoken = 'IZJGZ1S8AZIHCMW4'
AND ub.busdate BETWEEN '2025-12-10' :: TIMESTAMP AND '2026-01-06' :: TIMESTAMP
ORDER BY ub.busdate
LIMIT 100

SELECT ub.*, e.*-- min(eventinstant), count(*) 
FROM fact.userbehaviour as ub 
LEFT JOIN dim.element as e on ub.elementidentifier = e.elementid
WHERE 1=1-- eventinstant = '2025-10-06T14:47:19.999+00:00'
AND ub.locationid = 'loc-a8845b12-b118-4c08-bb08-66d1e38957e8'-- 'loc-e84afe92-d79b-4633-bb72-aa38d9e3fd6d'
AND ub.eventcategory IS NOT NULL --AND lower(ub.eventcategory) = 'insight'
AND ub.eventtype = 'OrderTypeSelected' ORDER BY ub.ordersessionidentifier
AND ub.busdate :: date BETWEEN '2025-12-14' :: date AND '2025-12-24' :: date
AND lower(eventtype) in ('tabletententered','modifierselected') ORDER BY eventtype desc
--AND id >= 39248344
  AND NOT EXISTS (SELECT 1 
                  FROM fact.userbehaviour_reload as ubr 
                  WHERE ubr.locationid = ub.locationid
                    AND ubr.ordersessionidentifier = ub.ordersessionidentifier)
--39,248,407	2025-10-06 14:47:19.999	loc-a785c5b7-d9eb-45cd-9586-77f4182cf8c2	2025100614	None	1074	CategorySelected	VAWPQEGYZ88CYRH4	6	NULL	698201	NULL	2025-12-11 16:20:18.841126	1761857898	2025-10-06T14:47:19.999+00:00
--39,248,407	2025-10-06 16:06:19.107	loc-aac6bbd8-40da-43dd-a9db-4faf4a2e775e	2025100616	None	948	CheckoutClicked	ASSYRE82OKV0O7RX	1	NULL	214938	NULL	2025-10-06 18:07:59.183063	1759766780	2025-10-06T16:06:19.107+00:00
--INSERT INTO fact.userbehaviour
SELECT ((SELECT max(id) FROM fact.userbehaviour) + ROW_NUMBER() over(ORDER by eventinstant)) as id,
       busdate, locationid, dateid, daypart, ordertype, eventtype, ordersessionidentifier, viewidentifier, 
       itemsessionidentifier, elementidentifier, quantity, createddate, syscosmosts, eventinstant
FROM fact.userbehaviour_reload WHERE status is NULL

SELECT * FROM dim.element WHERE sourceelementid = '20001' ORDER BY elementname


--INSERT INTO fact.userbehaviour
SELECT *-- distinct de.eventtoken --*-- count(*)
FROM fact.deviceevent as de --64,465,333 WHERE eventdata :: jsonb ->> 'elementId' <> ''
WHERE 1=1-- eventinstant = '2025-10-06T14:47:19.999+00:00'
  AND locationid = 'loc-e84afe92-d79b-4633-bb72-aa38d9e3fd6d'-- 'loc-e84afe92-d79b-4633-bb72-aa38d9e3fd6d' 
  AND lower(actiontype) in ('tabletententered','modifierselected') ORDER BY actiontype desc --tabletententered
  AND eventtoken = '5TJ495IA9KKNUBFJ'
  AND eventinstant like '2025-12-19%' ORDER BY de.eventtoken
  AND NOT EXISTS (SELECT 1 
                  FROM fact.userbehaviour as ub 
                  WHERE ub.locationid = de.locationid
                    AND ub.ordersessionidentifier = de.eventtoken
                    AND ub.eventtype = de.actiontype
                    AND ub.eventinstant = de.eventinstant)

SELECT *
FROM fact.userbehaviour--_reload
WHERE 1=1-- eventinstant = '2025-10-06T14:47:19.999+00:00'
and syscosmosts IS not null
ORDER BY syscosmosts desc
LIMIT 1000

UPDATE fact.watermarktable
   SET watermarkvalue = ub.max_busdate,
       ts = ub.max_syscosmosts
FROM (select MAX(busdate) as max_busdate, max(syscosmosts) as max_syscosmosts,
      'fact.userbehaviour' as table_name
      from fact.userbehaviour) as ub
WHERE watermarktable.watermarktablename = ub.table_name

SELECT * FROM fact.watermarktable

UPDATE fact.userbehaviour
SET busdate = 
case when substring(eventinstant, 20, 1) = '.' 
     then cast(replace(replace(substring(eventinstant, 1, 23), 'T', ' '), '+', '0') as TIMESTAMP)
     else cast(substring(eventinstant, 1, 19) as TIMESTAMP) end
WHERE eventinstant is not null;



--select now()

SELECT DISTINCT eventtype
FROM fact.userbehaviour

SELECT *-- distinct orderstatus
FROM fact.transactionheader AS th
WHERE 1=1
and orderstatus = 'order-placed' --LIMIT 10 
and th.locationid = 'loc-c7ce66a2-3f71-4d3c-a017-608886b7536d'-- 'loc-7b149de8-32db-46be-883e-fc7db625be7b'
AND th.businessdate BETWEEN '2025-11-16'::DATE AND '2025-11-22'::DATE
--and ordersessionid in ('7VEUBFO1PY4IU9IQ','L1IVQ3QIFUKRZ94I','W11UL22RJBW26NK3')
ORDER BY orderdatelocal DESC



SELECT *--ordersessionid
FROM fact.transactionitem
WHERE 1=1 
--and transactionheaderid like 'ordevt-%'
and locationid = 'loc-ac905f5d-6f72-4057-b055-6a466c4b86d6'
and busine is null
--and sysupdatetime is not null
ORDER BY orderdateutc desc
LIMIT 1000

select max(busdate) --distinct eventtype 
from fact.userbehaviour
where 1=1 
--and busdate is not null 
and busdate > now()
order by busdate desc
limit 1000

SELECT 1 < 2

SELECT *-- DISTINCT ordersessionidentifier
FROM 
    fact.userbehaviour--_reload
WHERE 1=1
  AND locationid = 'loc-c7ce66a2-3f71-4d3c-a017-608886b7536d'
  and busdate is not null 
  --and eventtype = 'OrderTypeSelected'--is null --
  /*and ordersessionidentifier in -- '59YZJEWAGXVAC21O'-- 'JPYA28WRGIB0NBWC'
        (SELECT ordersessionid
        FROM fact.transactionheader AS th
        WHERE 1=1
        and orderstatus = 'order-placed' --LIMIT 10
        and th.locationid = 'loc-c7ce66a2-3f71-4d3c-a017-608886b7536d'-- 'loc-7b149de8-32db-46be-883e-fc7db625be7b'
        AND th.businessdate BETWEEN '2025-11-16'::DATE AND '2025-11-22'::DATE)*/
ORDER BY busdate desc 
LIMIT 100

SELECT locationid, ordersessionidentifier, eventtype, count(*)
FROM fact.userbehaviour_reload
GROUP BY locationid, ordersessionidentifier, eventtype
HAVING count(*) > 1

SELECT DISTINCT *-- eventtoken 
       /* ol.organizationname, ol.organizationid, ol.locationname, kioskname,
       de.application, de.moduleid, datacategory,
       actiontype, severity, eventtoken, eventinstant, dateid*/
FROM 
    fact.deviceevent as de 
INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
        ON de.locationid = ol.locationid
INNER JOIN dim.kiosk as ksk        ON de.locationid = ksk.locationid       AND de.devicename = ksk.kioskid
WHERE 1=1
  AND de.locationid = 'loc-c7ce66a2-3f71-4d3c-a017-608886b7536d' --Mr. Pickles 0196 - Woodland
  AND de.actiontype = 'Abandoned'
  AND eventtoken in -- '59YZJEWAGXVAC21O'

          (SELECT ordersessionid
        FROM fact.transactionheader AS th
        WHERE 1=1
        and orderstatus = 'order-placed' --LIMIT 10 
        and th.locationid = 'loc-c7ce66a2-3f71-4d3c-a017-608886b7536d'-- 'loc-7b149de8-32db-46be-883e-fc7db625be7b'
        AND th.businessdate BETWEEN '2025-11-16'::DATE AND '2025-11-22'::DATE)

ORDER BY eventinstant desc
LIMIT 1000


WITH A as (
SELECT *
FROM fact.deviceevent as de 
WHERE 1=1
  AND de.moduleid = 'kiosk'
  AND de.datacategory = 'insight'
  AND de.eventtoken NOT EXISTS 
)

ALTER TABLE fact.userbehaviour_exceptions
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT,
ADD COLUMN IF NOT EXISTS eventinstant TEXT COLLATE pg_catalog."default"

SELECT count(*)
FROM fact.userbehaviour_exceptions

SELECT * FROM dim.kiosk

SELECT 

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



select * 
from dim.LOCATION 
where locationid = 'loc-226e3a8f-6d4d-40ae-bab9-71be20f96906' --'loc-b8c181a0-69ca-42e7-9f22-50fd23cb9bec'

select *
from fact.transactionitem
where locationid = 'loc-226e3a8f-6d4d-40ae-bab9-71be20f96906'

select *
from fact.transactionheader
where 1=1 
and locationid = 'loc-226e3a8f-6d4d-40ae-bab9-71be20f96906'
and businessdate = '2025-05-27'
and orderstatus <> 'order-placed'

select * 
from dim.kiosk
where kioskid = 'ksk-46198578';

SELECT * from fact.watermarktable;

/*update fact.watermarktable
set watermarkvalue = '2025-05-21 08:47:24.976' :: TIMESTAMP
where watermarktablename = 'userbehaviour';*/

select *-- distinct ordersessionidentifier--, eventtype--dateid, eventtype
from fact.userbehaviour 
where 1=1
and locationid = 'loc-3068e32c-1da4-40bc-956f-f305a8529bc6'-- 'loc-0396f9b6-099e-42dc-9719-7f757a933757' --'loc-7b149de8-32db-46be-883e-fc7db625be7b'
and busdate :: date is not null
/*and (ordersessionidentifier is null or ordersessionidentifier in ('null',''))
and ordersessionidentifier in ('IAQ6EO8CTZPO39CA','CK0DAQ1CJ7D4I4LR');
and ordersessionidentifier in (
    SELECt distinct ordersessionid
    FROM fact.transactionheader AS th
    WHERE 1=1
    and th.locationid = 'loc-7b149de8-32db-46be-883e-fc7db625be7b'
    AND th.businessdate BETWEEN '2025-02-03'::DATE AND '2025-02-03'::DATE
)*/
order by busdate desc
limit 10

select count(distinct ordersessionidentifier), count(*) as total
from fact.userbehaviour
where busdate :: date >= '2025-03-01' --196,131T, --3,863 dist.orderSessionID

select * from fact.transactionheader
where ordersessionid in (
                        select ordersessionid
                        from fact.transactionheader
                        group by ordersessionid
                        having count(*) > 1)
--where ordersessionid = 'CA5VXJZXWCJHQ41M'
order by 

select *
from fact.transactionheader
where ordersessionid = 'GM9WG5GZ55TGWU17'

--delete from fact.userbehaviour
where busdate :: date >= '2025-03-01';

select * from fact.watermarktable;

update fact.watermarktable
set watermarkvalue = '2025-03-01 00:00:00.000'
where watermarktablename = 'userbehaviour';