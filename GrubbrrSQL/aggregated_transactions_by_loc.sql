select ol.organizationId, ol.organizationname, 
       th.locationid, ol.locationname, --th.businessdate,
	   --EXTRACT(YEAR FROM th.businessdate)::INTEGER as yyyy,
       --EXTRACT(WEEK FROM th.businessdate)::INTEGER as ww,
       count(1) as ordercounts, sum(ordertotal) as amtspent, avg(ordertotal) as avg_amtspent,
	   min(orderdatelocal) as first_order_time,
	   max(orderdatelocal) as latest_order_time
from (select * from fact.transactionheader WHERE businessdate >= '2026-01-01') as th
inner join (select * from dim.organizationlocation where organizationtype = 0) as ol 
        on th.locationid = ol.locationid
where 1=1
--and ol.organizationid = 'org-ug5zsn9mpq'
--and th.locationid = 'loc-8ead49a8-798b-4786-988a-90bbbb4775c7'-- 'loc-26335157-cfac-40a3-b901-2bca43618bc6'-- 'loc-353c730c-36ca-4575-95f8-38516cdc9de7'
and th.orderstatus = 'order-placed'
--and th.businessdate = '2026-03-30' :: DATE-- BETWEEN '2023-01-01' and CURRENT_DATE :: date--'2025-07-13' --
group by ol.organizationId, ol.organizationname, th.locationid, ol.locationname--, th.businessdate
   		 --EXTRACT(YEAR FROM th.businessdate)::INTEGER
         --EXTRACT(WEEK FROM th.businessdate)::INTEGER
order by ordercounts DESC-- first_order_time ASC--, ordercounts DESC--, 

SELECT *
FROM dim.organization
WHERE id = 'loc-003bf5fc-1391-4afd-ac29-bbf18f9ae2c3';
--["loc-73ad6e86-1f5c-4123-adbb-4b12339ea171","loc-8ead49a8-798b-4786-988a-90bbbb4775c7","loc-26335157-cfac-40a3-b901-2bca43618bc6","loc-96f0d639-95a2-4e42-b9ba-35e836bec523","loc-353c730c-36ca-4575-95f8-38516cdc9de7","loc-f8417e68-4a8a-4fa6-8c9b-780564b86a90","loc-d30b1e76-3b2b-42cf-b357-f4790df19159"]
select to_jsonb(array_agg(locationname)) as locations,
	   to_jsonb(array_agg(locationid)) as locationids,
	   jsonb_agg(
			jsonb_build_object(
				'locationid', locationid,
				'locationname', locationname
			)
	   )
from dim.organizationlocation 
where organizationname like 'Bojangles'
and (locationname like '0927%Steele%'
  or locationname like '2031%Wax%'
  or locationname like '%Monroe%'
  or locationname like '%Richmond%'
  or locationname like '%Pisc%'
  or locationname like '1020%Charlot%')
and organizationtype = 0;

/*
org-5834d77c-4c45-4f98-a110-4c0fcd977490	WaBa Grill	loc-c9df0f68-c306-4dea-9fd3-290417065a03	WG0234 - Northridge
org-5834d77c-4c45-4f98-a110-4c0fcd977490	WaBa Grill	loc-f876b618-684e-449b-a1cc-78103eb107b9	WG0235 - Oxnard (Rose Avenue)

org-5cf80db5-7a28-4dcf-846b-8cdf5f362269	Bojangles	loc-73ad6e86-1f5c-4123-adbb-4b12339ea171	1020 - Charlotte, NC
org-5cf80db5-7a28-4dcf-846b-8cdf5f362269	Bojangles	loc-7d483b28-0129-4e28-b32c-105bfcc993f0	1305 - Charlotte, NC
org-5cf80db5-7a28-4dcf-846b-8cdf5f362269	Bojangles	loc-8ead49a8-798b-4786-988a-90bbbb4775c7	0927 Steele Creek Road
org-5cf80db5-7a28-4dcf-846b-8cdf5f362269	Bojangles	loc-26335157-cfac-40a3-b901-2bca43618bc6	1414 - Piscataway, NJ


org-91b23045-d053-4579-a9e4-acb8d4ec37b2	Rak One			loc-49a53dc2-1818-4a6f-8312-ed4da2adacb3	HMS GAB
org-b2c96641-209e-47c8-b1d5-b5d3c881a244	Tanvi - Loyalty	loc-1364b2ed-9c7d-4a1a-bfee-d0cdd148fb09	paytronix loyalty
org-d54ec735-238b-454f-ba73-6ec9d3a7a955	Jiten Company	loc-9dbd4815-f50a-4e4f-ac1d-5fd6d9ec728e	Test Toast
org-tf5i2lw1qz								Sakshi Demo		loc-b30f55b4-fc0b-40b7-af00-29bb2f653c1e	Toast + Punchh

[
	 {
		"organizationid": "org-5cf80db5-7a28-4dcf-846b-8cdf5f362269",
		"organizationname": "Bojangles",
		"locationid": "loc-73ad6e86-1f5c-4123-adbb-4b12339ea171",
		"locationname": "1020 - Charlotte, NC"
	 },
     {
		"organizationid": "org-5cf80db5-7a28-4dcf-846b-8cdf5f362269",
		"organizationname": "Bojangles",
		"locationid": "loc-7d483b28-0129-4e28-b32c-105bfcc993f0",
		"locationname": "1305 - Charlotte, NC"
     },
     {
		"organizationid": "org-5834d77c-4c45-4f98-a110-4c0fcd977490",
		"organizationname": "WaBa Grill",
		"locationid": "loc-c9df0f68-c306-4dea-9fd3-290417065a03",
		"locationname": "WG0234 - Northridge"
     },
     {
		"organizationid": "org-5834d77c-4c45-4f98-a110-4c0fcd977490",
		"organizationname": "WaBa Grill",
		"locationid": "loc-f876b618-684e-449b-a1cc-78103eb107b9",
		"locationname": "WG0235 - Oxnard (Rose Avenue)"
     }
]

*/

SELECT *
FROM dim.menuitem

SELECT *
FROM dim.frequentcustomer
WHERE organizationid = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269'

SELECT *
FROM dim.vw_weatherhourlydata LIMIT 1000

SELECT 
CASE WHEN EXISTS
				(SELECT 1 --count(*)
				FROM fact.transactionheader AS th 
				WHERE th.locationid in (SELECT DISTINCT ol.locationid 
										FROM dim.organizationlocation AS ol 
										WHERE (CASE WHEN 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269' AND ol.organizationtype = 0) 
										AND lower(th.orderstatus) = 'order-placed' 
										AND EXTRACT(YEAR FROM th.businessdate) :: integer = 2025
										AND EXTRACT(WEEK FROM th.businessdate) :: integer = 1
				)
	 THEN 1 ELSE 0 END has_data


select ol.organizationId, ol.organizationname, 
       th.locationid, ol.locationname, th.businessdate,
	   min(orderdateutc) :: timestamp as first_order_time,
       min(orderdateutc) :: timestamp with time zone AT TIME ZONE 'America/New_York' as NY_first_order_time,
       max(orderdateutc) :: timestamp as latest_order_time,
       max(orderdateutc) :: timestamp with time zone AT TIME ZONE 'America/New_York' as NY_last_order_time
from fact.transactionheader as th
inner join (select * from dim.organizationlocation where organizationtype = 0) as ol 
        on th.locationid = ol.locationid
where 1=1
--and ol.organizationid = 'org-ug5zsn9mpq'
--and th.locationid = 'loc-8ead49a8-798b-4786-988a-90bbbb4775c7'-- 'loc-26335157-cfac-40a3-b901-2bca43618bc6'-- 'loc-353c730c-36ca-4575-95f8-38516cdc9de7'
and th.orderstatus = 'order-placed'
and th.businessdate = '2026-03-30' :: DATE
group by ol.organizationId, ol.organizationname, th.locationid, ol.locationname, th.businessdate
order by first_order_time ASC

/*
org-2ad9799e-2df3-4ebb-9563-8772f5638552	Rohan's Org	loc-96abd656-679f-41dc-a5ef-7bca8ffc5333	BurgerKing par	998
org-2ad9799e-2df3-4ebb-9563-8772f5638552	Rohan's Org	loc-9dd1eaea-e264-4d51-bffb-1abdc65e3fff	Upsell Testing	939
org-tf5i2lw1qz	Sakshi Demo	loc-66d85cfc-62f3-40eb-96c3-39afb144b4e3	Toast grubbrr lab + Como	38
org-d54ec735-238b-454f-ba73-6ec9d3a7a955	Jiten Company	loc-56db8917-3e54-4be9-941b-5d2d4a5a4c22	Test NCR Aloha	35
com-3owh66znkd	Akshit NCR test	loc-ebd23f7f-a4e3-452a-a643-db13ee756fc5	Zinger's Deli NCR Menu v1	34
*/

SELECT count(*)
FROM fact.transactionheader as th
where 1=1
--and th.orderstatus = 'order-placed'
--and businessdate BETWEEN '2025-01-01' AND '2025-12-01'
and createddate BETWEEN '2025-01-01' AND '2025-12-01'
and createddate is NULL
--P**803,903--S**803,888 30/11
--P**690,255--S**690,255 30/10
--P**724,360--S**724,360 10/11
--P**761,677--S**761,677 20/11
--P**786,470--S**761,677 25/11

--P**874,717--S**874,717
--P**878,551--

ORDER BY th.updateddate desc
LIMIT 2000

/*Sample Prod data
["org-0281beee-a2f2-46fb-ac88-cc20df85fbfc","org-ug5zsn9mpq","org-5cf80db5-7a28-4dcf-846b-8cdf5f362269"]
org-0281beee-a2f2-46fb-ac88-cc20df85fbfc	#1--BurgerFi
org-21b9c258-ad27-4aab-8663-4d480c235950	++Pizza Hut
org-d7a82a2f-b933-4459-8a1e-91a605df80f7	++Mr. Pickles Sandwich Shop
org-ug5zsn9mpq	                            #2--Einstein Bros. Bagels
loc-x4pw1awq97	                            Excalibur
loc-f5apk9hxfi	                            Circus Circus
loc-6e6a1e38-f495-417a-95a0-cc9a1dd1a88a	Pasadena
loc-273ffa25-f0d2-48e5-befa-47f0934f3baa	Mead 241 Welker Rd
org-7bd17b79-edd7-48bf-b655-dd2fbb1650a7	Wienerschnitzel
org-5cf80db5-7a28-4dcf-846b-8cdf5f362269	#3--Bojangles
org-0281beee-a2f2-46fb-ac88-cc20df85fbfc	BurgerFi
*/
--2025-08-03

WITH A as (
SELECT DISTINCT ol.organizationId, ol.organizationname, 
       ti.locationid, ol.locationname, 
	   --ti.transactionheaderid, ti.itemid,
	   ctg.categoryid, categoryname,
	   CASE WHEN lower(categoryname) is NULL OR categoryname = ''  THEN 'Undefined' 
	   		WHEN lower(categoryname) like '%beverage%' THEN 'Drink'
	   		WHEN lower(categoryname) like '%sauce%'
			  OR lower(categoryname) like '%extra%' THEN 'Other'
			WHEN lower(categoryname) like '%fixin%' THEN 'Side'
			WHEN lower(categoryname) like '%sweet%' THEN 'Dessert'
			WHEN lower(categoryname) like '%biscuit%meal%'
			  OR lower(categoryname) like '%boneless%chicken%'
			  OR lower(categoryname) like '%family%meal%'
			  OR lower(categoryname) like '%dinner%'
			  OR lower(categoryname) like '%tender%platter%'
			  OR lower(categoryname) like '%kid%meal%' THEN 'Meal'
			WHEN lower(categoryname) like '%limited%time%menu%'
			  OR lower(categoryname) like '%bo%favorites%'
			  OR lower(categoryname) like '%sandwich%'
			  OR lower(categoryname) like '%biscuits%'
			  OR lower(categoryname) like '%individual%'
			  OR lower(categoryname) like '%regional%favorites%'
			  OR lower(categoryname) like '%salad%' THEN 'Main'
			ELSE NULL END as item_class_desc,
	   CASE WHEN lower(categoryname) is NULL OR categoryname = ''  THEN 0
	   		WHEN lower(categoryname) like '%beverage%' THEN 3
	   		WHEN lower(categoryname) like '%sauce%'
			  OR lower(categoryname) like '%extra%' THEN 6
			WHEN lower(categoryname) like '%fixin%' THEN 2
			WHEN lower(categoryname) like '%sweet%' THEN 4
			WHEN lower(categoryname) like '%biscuit%meal%'
			  OR lower(categoryname) like '%boneless%chicken%'
			  OR lower(categoryname) like '%family%meal%'
			  OR lower(categoryname) like '%dinner%'
			  OR lower(categoryname) like '%tender%platter%'
			  OR lower(categoryname) like '%kid%meal%' THEN 5
			WHEN lower(categoryname) like '%limited%time%menu%'
			  OR lower(categoryname) like '%bo%favorites%'
			  OR lower(categoryname) like '%sandwich%'
			  OR lower(categoryname) like '%biscuits%'
			  OR lower(categoryname) like '%individual%'
			  OR lower(categoryname) like '%regional%favorites%'
			  OR lower(categoryname) like '%salad%' THEN 1
			ELSE NULL END as item_class_type,
	   --ti.dimmenuitemid, ti.menuitemid,
	   mi.id, mi.menuitemid, 
	   mi.menuitemname--, mi.item_class_type
FROM fact.transactionitem as ti 
INNER JOIN (SELECT * FROM dim.organizationlocation 
		    WHERE organizationtype = 0 AND organizationid = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269') as ol 
		ON ti.locationid = ol.locationid
INNER JOIN dim.itemcategory as ctg 
		ON ti.categoryid = ctg.id 
INNER JOIN dim.menuitem as mi 
		ON ti.menuitemid = mi.id 
--ORDER BY orderdateutc DESC
--LIMIT 1000
)
UPDATE dim.menuitem
   SET item_class_type = A.item_class_type
FROM A 
WHERE menuitem.menuitemid = A.menuitemid
  AND menuitem.id = A.id

/*
0=Undefined
1=Main
2=Side
3=Drink
4=Dessert
5=Meal
6=Other
*/

SELECT DISTINCT ol.organizationid, ol.organizationname,
	   --ctg.locationid, ol.locationname,
	   --ctg.id, ctg.categoryid, 
	   CASE WHEN lower(categoryname) is NULL OR categoryname = ''  THEN 'Undefined' 
	   		WHEN lower(categoryname) like '%beverage%' THEN 'Drink'
	   		WHEN lower(categoryname) like '%sauce%'
			  OR lower(categoryname) like '%extra%' THEN 'Other'
			WHEN lower(categoryname) like '%fixin%' THEN 'Side'
			WHEN lower(categoryname) like '%sweet%' THEN 'Dessert'
			WHEN lower(categoryname) like '%biscuit%meal%'
			  OR lower(categoryname) like '%boneless%chicken%'
			  OR lower(categoryname) like '%family%meal%'
			  OR lower(categoryname) like '%dinner%'
			  OR lower(categoryname) like '%tender%platter%'
			  OR lower(categoryname) like '%kid%meal%' THEN 'Meal'
			WHEN lower(categoryname) like '%limited%time%menu%'
			  OR lower(categoryname) like '%bo%favorites%'
			  OR lower(categoryname) like '%sandwich%'
			  OR lower(categoryname) like '%biscuits%'
			  OR lower(categoryname) like '%individual%'
			  OR lower(categoryname) like '%regional%favorites%'
			  OR lower(categoryname) like '%salad%' THEN 'Main'
			ELSE NULL END as item_class_desc,
	   CASE WHEN lower(categoryname) is NULL OR categoryname = ''  THEN 0
	   		WHEN lower(categoryname) like '%beverage%' THEN 3
	   		WHEN lower(categoryname) like '%sauce%'
			  OR lower(categoryname) like '%extra%' THEN 6
			WHEN lower(categoryname) like '%fixin%' THEN 2
			WHEN lower(categoryname) like '%sweet%' THEN 4
			WHEN lower(categoryname) like '%biscuit%meal%'
			  OR lower(categoryname) like '%boneless%chicken%'
			  OR lower(categoryname) like '%family%meal%'
			  OR lower(categoryname) like '%dinner%'
			  OR lower(categoryname) like '%tender%platter%'
			  OR lower(categoryname) like '%kid%meal%' THEN 5
			WHEN lower(categoryname) like '%limited%time%menu%'
			  OR lower(categoryname) like '%bo%favorites%'
			  OR lower(categoryname) like '%sandwich%'
			  OR lower(categoryname) like '%biscuits%'
			  OR lower(categoryname) like '%individual%'
			  OR lower(categoryname) like '%regional%favorites%'
			  OR lower(categoryname) like '%salad%' THEN 1
			ELSE NULL END as item_class_type,
	   ctg.categoryname
FROM dim.itemcategory as ctg
INNER JOIN (SELECT * FROM dim.organizationlocation 
		    WHERE organizationtype = 0 AND organizationid = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269') as ol 
		ON ctg.locationid = ol.locationid
--WHERE ctg.locationid in (SELECT locationid FROM dim.organizationlocation 
--						 WHERE organizationtype = 0 AND organizationid = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269')
ORDER BY id DESC
LIMIT 100 

'Sandwiches'
'Sandwiches '

Tender Platters   --Meal
Extras			  --Other
Individual  	  --Main
Regional Favorites--Main

SELECT DISTINCT dt.yearval, dt.weekval, dt.dayval 
FROM dim.datedim as dt
WHERE 1=1
AND dt.weekval = 17
AND dt.yearval = 2025

--30 2025-07-20 2025-07-26
--17 2025-04-20 2025-04-26


SELECT DISTINCT o.id
FROM dim.organization as o
WHERE o.id = '@{pipeline().parameters.organizationId}';

SELECT DISTINCT 
CASE WHEN '@{pipeline().parameters.organizationId}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END AS id
FROM dim.organizationlocation as ol
WHERE ol.organizationtype = 0
AND (CASE WHEN '@{pipeline().parameters.organizationId}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.organizationId}';


--DELETE FROM fact.transactionheader--item--
SELECT * FROM fact.transactionitem--header--
where ordersessionid in
(
	SELECT th.ordersessionid
	from fact.transactionheader as th
	WHERE 1=1 
	and th.orderstatus = 'order-placed'
	and th.ordersessionid <> ''
	GROUP BY th.ordersessionid
	HAVING COUNT(*) > 1
)
and orderid = 'ord-';

--select * from fact.transactionitem limit 10

ALTER TABLE fact.transactionitem 
add CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);
