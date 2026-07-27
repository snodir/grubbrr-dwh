SELECT ol.organizationId, ol.organizationname, 
       th.locationid, ol.locationname, --th.businessdate,
	   --EXTRACT(YEAR FROM th.businessdate)::INTEGER as yyyy,
       --EXTRACT(WEEK FROM th.businessdate)::INTEGER as ww,
       count(1) as ordercounts, sum(ordertotal) as amtspent, round(avg(ordertotal), 3) as avg_amtspent,
	   min(orderdatelocal) as first_order_time,
	   max(orderdatelocal) as latest_order_time
FROM 	   (SELECT * FROM fact.transactionheader /*WHERE businessdate >= '2026-06-09' AND businessdate <= '2026-06-10'*/) as th
INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
        on th.locationid = ol.locationid
WHERE 1=1
and ol.organizationid = 'org-30b00f49-c9a7-462a-bc5f-c113f4fb8a77' --'org-490e23ce-6f23-4d3d-8544-8728f0965cfc'
--and th.locationid  IN ('loc-d45f4b24-0d3a-4ed2-a2c1-836ffd78e021','loc-2bd29e8d-b962-472e-9e01-1ff06b6f9172')-- 'loc-26335157-cfac-40a3-b901-2bca43618bc6'-- 'loc-353c730c-36ca-4575-95f8-38516cdc9de7'
and th.orderstatus = 'order-placed'
--and th.businessdate = '2026-03-30' :: DATE-- BETWEEN '2023-01-01' and CURRENT_DATE :: date--'2025-07-13' --
GROUP BY ol.organizationId, ol.organizationname, th.locationid, ol.locationname--, th.businessdate
   		 --EXTRACT(YEAR FROM th.businessdate)::INTEGER
         --EXTRACT(WEEK FROM th.businessdate)::INTEGER
ORDER BY ordercounts DESC-- first_order_time ASC--, ordercounts DESC--, 
--S=org-5cf80db5-7a28-4dcf-846b-8cdf5f362269	Bojangles	loc-73ad6e86-1f5c-4123-adbb-4b12339ea171	1020 - Charlotte, NC	71	1144.610	16.1212676056338028	2026-06-09 06:33:55.447	2026-06-10 21:26:49.067
--P=org-5cf80db5-7a28-4dcf-846b-8cdf5f362269	Bojangles	loc-73ad6e86-1f5c-4123-adbb-4b12339ea171	1020 - Charlotte, NC	211	3884.850	18.4116113744075829	2026-06-09 06:33:55.447	2026-06-10 21:26:49.067
--SELECT max(orderdatelocal) FROM fact.transactionheader

SELECT * FROM fact.transactionheader 
WHERE locationid = 'loc-7e11383c-03a8-40bb-866e-ec596d780773'-- 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
AND frequentcustomerid IS NOT NULL
LIMIT 1000;


SELECT * FROM dim.organizationlocation 
WHERE lower(organizationname) LIKE '%grubbrr%demo%'
AND organizationtype = 0;
--org-642556df-6d2c-42cc-81cc-83c1e490a458	GRUBBRR AI DEMO PICO BURRITO	loc-7e11383c-03a8-40bb-866e-ec596d780773	Pico Burrito Demo



/*
org-d4efebe6-0ab3-4f44-a113-b9653a58c1d2	GRUBBRR Demos	loc-d45f4b24-0d3a-4ed2-a2c1-836ffd78e021	Pico Burrito Demo
org-d4efebe6-0ab3-4f44-a113-b9653a58c1d2	GRUBBRR Demos	loc-2bd29e8d-b962-472e-9e01-1ff06b6f9172	Fat Slice Demo
*/

SELECT *
FROM ml.menu_entities
WHERE locationid = 'loc-2bd29e8d-b962-472e-9e01-1ff06b6f9172' --Fat Slice Demo -- 'loc-d45f4b24-0d3a-4ed2-a2c1-836ffd78e021'--Pico Burrito Demo



SELECT th.businessdate, 
	   count(DISTINCT th.locationid) as locations,
	   count(*) as order_count
FROM fact.transactionheader as th 
WHERE th.businessdate >= CAST('2026-05-01' AS DATE)
GROUP BY th.businessdate
ORDER BY th.businessdate DESC;

SELECT locationid, kioskid, ordersessionid, COUNT(*)
FROM fact.transactionheader
--WHERE orderstatus = 'order-placed'
GROUP BY locationid, kioskid, ordersessionid
HAVING COUNT(*) > 1
--P=199,196 dupl (having more than double of it)


WITH aggr_trxns_by_hour AS (
	SELECT bronze_folderpath, MAX(syscosmosts) as max_sys, MIN(syscosmosts) as min_sys
	FROM stg.silver_transaction_header
	GROUP BY bronze_folderpath
)
SELECT th1.bronze_folderpath, th2.bronze_folderpath AS prvs_folderpath,
	th1.max_sys, th2.max_sys AS prvs_hour_max, ROUND((th1.max_sys - th2.max_sys) :: NUMERIC(10,2) / 60, 2) AS is_max_correct, 
	th1.min_sys, th2.min_sys AS prvs_hour_min, ROUND((th1.min_sys - th2.min_sys) :: NUMERIC(10,2) / 60, 2) AS is_min_correct,
	ROUND((th1.min_sys - th2.max_sys) :: NUMERIC(10,2) / 60, 2) AS is_cross_hour_sequence_correct
FROM 	  (SELECT *, ROW_NUMBER() OVER(ORDER BY bronze_folderpath) AS rn FROM aggr_trxns_by_hour) as th1
LEFT JOIN (SELECT *, ROW_NUMBER() OVER(ORDER BY bronze_folderpath) AS rn FROM aggr_trxns_by_hour) as th2
	ON th2.rn = th1.rn - 1
ORDER BY th1.bronze_folderpath;


WITH aggr_trxns_by_hour AS (
	SELECT bronze_folderpath, MAX(syscosmosts) as max_sys, MIN(syscosmosts) as min_sys
	FROM stg.silver_transaction_header
	GROUP BY bronze_folderpath
)
SELECT th1.bronze_folderpath, th2.bronze_folderpath AS prvs_folderpath,
	TO_TIMESTAMP(th1.max_sys) as current_hour_max, TO_TIMESTAMP(th2.max_sys) AS prvs_hour_max, ROUND((th1.max_sys - th2.max_sys) :: NUMERIC(10,2) / 60, 2) AS is_max_correct, 
	TO_TIMESTAMP(th1.min_sys) as current_hour_min, TO_TIMESTAMP(th2.min_sys) AS prvs_hour_min, ROUND((th1.min_sys - th2.min_sys) :: NUMERIC(10,2) / 60, 2) AS is_min_correct,
	ROUND((th1.min_sys - th2.max_sys) :: NUMERIC(10,2) / 60, 2) AS is_cross_hour_sequence_correct
FROM 	  (SELECT *, ROW_NUMBER() OVER(ORDER BY bronze_folderpath) AS rn FROM aggr_trxns_by_hour) as th1
LEFT JOIN (SELECT *, ROW_NUMBER() OVER(ORDER BY bronze_folderpath) AS rn FROM aggr_trxns_by_hour) as th2
	ON th2.rn = th1.rn - 1
ORDER BY th1.bronze_folderpath;


WITH aggr_trxns_by_hour AS (
	SELECT (to_char(orderdateutc :: TIMESTAMP, 'YYYYMMDDHH24'::TEXT))::INTEGER AS dateid, 
		MAX(syscosmosts) as max_sys, MIN(syscosmosts) as min_sys,
		MAX(createddate) as max_etl, MIN(createddate) as min_etl
	FROM fact.transactionheader
	WHERE dateid >= 2026050100 AND dateid <= 2026060100
	  AND orderstatus = 'order-placed'
	GROUP BY (to_char(orderdateutc :: TIMESTAMP, 'YYYYMMDDHH24'::TEXT))::INTEGER
)
SELECT th1.dateid, th2.dateid AS prvs_folderpath,
	TO_TIMESTAMP(th1.max_sys) as current_hour_max, TO_TIMESTAMP(th2.max_sys) AS prvs_hour_max, ROUND((th1.max_sys - th2.max_sys) :: NUMERIC(10,2) / 60, 2) AS is_max_correct, 
	TO_TIMESTAMP(th1.min_sys) as current_hour_min, TO_TIMESTAMP(th2.min_sys) AS prvs_hour_min, ROUND((th1.min_sys - th2.min_sys) :: NUMERIC(10,2) / 60, 2) AS is_min_correct,
	ROUND((th1.min_sys - th2.max_sys) :: NUMERIC(10,2) / 60, 2) AS is_cross_hour_sequence_correct,
	th1.min_etl, th1.max_etl, th2.min_etl, th2.max_etl
FROM 	  (SELECT *, ROW_NUMBER() OVER(ORDER BY dateid) AS rn FROM aggr_trxns_by_hour) as th1
LEFT JOIN (SELECT *, ROW_NUMBER() OVER(ORDER BY dateid) AS rn FROM aggr_trxns_by_hour) as th2
	ON th2.rn = th1.rn - 1
ORDER BY th1.dateid;

WITH trxn_by_day_parts AS (
	SELECT *, 
		CASE WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 0 AND 5 THEN 'Overnight_0_5'
			 WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 6 AND 9 THEN 'Breakfast_6_9'
			 WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 10 AND 13 THEN 'Lunch_10_13'
			 WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 14 AND 15 THEN 'Afternoon_Snack_14_15'
			 WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 16 AND 21 THEN 'Dinner_16_21'
			 WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 22 AND 23 THEN 'Late_Night_22_23'
		END AS day_parts
	FROM fact.transactionheader as th
)
SELECT th.day_parts, 
	   count(*) as total_orders,
	   sum(th.ordertotal) as total_amount_spent
FROM trxn_by_day_parts as th 
--WHERE th.businessdate >= CAST('2026-04-01' AS DATE)
GROUP BY th.day_parts
ORDER BY total_orders DESC;

WITH trxn_by_day_parts AS (
	SELECT *, 
		CASE WHEN EXTRACT(HOUR FROM th.orderdateutc :: TIMESTAMP) BETWEEN 0 AND 5 THEN 'Overnight_0_5'
			 WHEN EXTRACT(HOUR FROM th.orderdateutc :: TIMESTAMP) BETWEEN 6 AND 9 THEN 'Breakfast_6_9'
			 WHEN EXTRACT(HOUR FROM th.orderdateutc :: TIMESTAMP) BETWEEN 10 AND 13 THEN 'Lunch_10_13'
			 WHEN EXTRACT(HOUR FROM th.orderdateutc :: TIMESTAMP) BETWEEN 14 AND 15 THEN 'Afternoon_Snack_14_15'
			 WHEN EXTRACT(HOUR FROM th.orderdateutc :: TIMESTAMP) BETWEEN 16 AND 21 THEN 'Dinner_16_21'
			 WHEN EXTRACT(HOUR FROM th.orderdateutc :: TIMESTAMP) BETWEEN 22 AND 23 THEN 'Late_Night_22_23'
		END AS day_parts
	FROM fact.transactionheader as th
)
SELECT th.day_parts, 
	   count(*) as total_orders,
	   sum(th.ordertotal) as total_amount_spent
FROM trxn_by_day_parts as th 
--WHERE th.businessdate >= CAST('2026-04-01' AS DATE)
GROUP BY th.day_parts
ORDER BY total_orders DESC;


-- A temp table column containing 24 hour integers
DROP TABLE IF EXISTS table_hours;
CREATE TEMPORARY TABLE table_hours AS
SELECT generate_series(0, 23) AS hour;
--SELECT * FROM table_hours;

WITH trxn_by_day_parts AS (
	SELECT *, EXTRACT(HOUR FROM th.orderdateutc :: TIMESTAMP) AS hours_24
	FROM fact.transactionheader as th
), aggr_trxns_by_hour AS (
SELECT th.hours_24, 
	   count(*) as total_orders,
	   sum(th.ordertotal) as total_amount_spent
FROM trxn_by_day_parts as th 
--WHERE th.businessdate >= CAST('2026-04-01' AS DATE)
GROUP BY th.hours_24
--ORDER BY total_orders DESC;
)
SELECT th.hour, 
	coalesce(agg.total_orders, 0) as total_orders, 
	coalesce(agg.total_amount_spent, 0) as total_amount_spent 
FROM table_hours as th 
LEFT JOIN aggr_trxns_by_hour as agg
	ON th.hour = agg.hours_24
ORDER BY total_orders DESC;

SELECT count(*) FROM fact.transactionheader; --P=2,900,940
SELECT count(*) FROM fact.transactionitem;	 --P=5,124,830

SELECT *
FROM dim.organization
WHERE id = 'loc-003bf5fc-1391-4afd-ac29-bbf18f9ae2c3';
--["loc-73ad6e86-1f5c-4123-adbb-4b12339ea171","loc-8ead49a8-798b-4786-988a-90bbbb4775c7","loc-26335157-cfac-40a3-b901-2bca43618bc6","loc-96f0d639-95a2-4e42-b9ba-35e836bec523","loc-353c730c-36ca-4575-95f8-38516cdc9de7","loc-f8417e68-4a8a-4fa6-8c9b-780564b86a90","loc-d30b1e76-3b2b-42cf-b357-f4790df19159"]
SELECT to_jsonb(array_agg(locationname)) as locations,
	   to_jsonb(array_agg(locationid)) as locationids,
	   jsonb_agg(
			jsonb_build_object(
				'locationid', locationid,
				'locationname', locationname
			)
	   )
FROM dim.organizationlocation 
WHERE organizationname like 'Bojangles'
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


SELECT ol.organizationId, ol.organizationname, 
       th.locationid, ol.locationname, th.businessdate,
	   min(orderdateutc) :: timestamp as first_order_time,
       min(orderdateutc) :: timestamp with time zone AT TIME ZONE 'America/New_York' as NY_first_order_time,
       max(orderdateutc) :: timestamp as latest_order_time,
       max(orderdateutc) :: timestamp with time zone AT TIME ZONE 'America/New_York' as NY_last_order_time
FROM fact.transactionheader as th
INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
        on th.locationid = ol.locationid
WHERE 1=1
--and ol.organizationid = 'org-ug5zsn9mpq'
--and th.locationid = 'loc-8ead49a8-798b-4786-988a-90bbbb4775c7'-- 'loc-26335157-cfac-40a3-b901-2bca43618bc6'-- 'loc-353c730c-36ca-4575-95f8-38516cdc9de7'
and th.orderstatus = 'order-placed'
and th.businessdate = '2026-03-30' :: DATE
GROUP BY ol.organizationId, ol.organizationname, th.locationid, ol.locationname, th.businessdate
ORDER BY first_order_time ASC

/*
org-2ad9799e-2df3-4ebb-9563-8772f5638552	Rohan's Org	loc-96abd656-679f-41dc-a5ef-7bca8ffc5333	BurgerKing par	998
org-2ad9799e-2df3-4ebb-9563-8772f5638552	Rohan's Org	loc-9dd1eaea-e264-4d51-bffb-1abdc65e3fff	Upsell Testing	939
org-tf5i2lw1qz	Sakshi Demo	loc-66d85cfc-62f3-40eb-96c3-39afb144b4e3	Toast grubbrr lab + Como	38
org-d54ec735-238b-454f-ba73-6ec9d3a7a955	Jiten Company	loc-56db8917-3e54-4be9-941b-5d2d4a5a4c22	Test NCR Aloha	35
com-3owh66znkd	Akshit NCR test	loc-ebd23f7f-a4e3-452a-a643-db13ee756fc5	Zinger's Deli NCR Menu v1	34
*/

SELECT count(*)
FROM fact.transactionheader as th
WHERE 1=1
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
WHERE ordersessionid in
(
	SELECT th.ordersessionid
	FROM fact.transactionheader as th
	WHERE 1=1 
	and th.orderstatus = 'order-placed'
	and th.ordersessionid <> ''
	GROUP BY th.ordersessionid
	HAVING COUNT(*) > 1
)
and orderid = 'ord-';

--SELECT * FROM fact.transactionitem limit 10

ALTER TABLE fact.transactionitem 
add CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);
