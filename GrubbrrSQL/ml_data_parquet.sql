--File: Main Transaction dataset (Item-level, weekly snapshot)
--File hierarchy: ml-training-data/org-abcd/data-yyww-00001.parquet
WITH cte AS (
    SELECT *
    FROM fact.transactionheader AS th
    WHERE th.locationid IN (
        SELECT DISTINCT ol.locationid
        FROM dim.organizationlocation AS ol
        WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.p_orgid}'
          AND ol.organizationtype = 0
    )
      AND LOWER(th.orderstatus) = 'order-placed'
      AND EXTRACT(YEAR FROM th.businessdate)::integer = @{item().yearval}
      AND EXTRACT(WEEK FROM th.businessdate)::integer = @{item().weekval}
)
SELECT DISTINCT
    th.frequentcustomerid,
    ol.organizationid,
    ol.organizationname,
    th.locationid,
    ol.locationname,
    th.kioskid,
    th.transactionheaderid,
    ti.itemid AS orderitemid,
    ti.dimmenuitemid AS menuitemid,
    ti.itemname,
    COALESCE(ti.upselllevel, '') AS upselllevel,
    mi.item_class_type,
    ti.itemquantity,
    ti.categoryid,
    ctg.categoryname,
    ti.itemunitprice,
    th.paymentstatus,
    th.numberofitems,
    th.numberofpayments,
    th.ordertotal,
    th.ordersubtotal,
    th.ordertip,
    th.ordertax,
    ot.ordertypelabel,
    th.orderdatelocal,
    th.businessdate,
    wh.humidity AS weatherhumidity,
    wh.condition AS weathercondition,
    wh.temperature_c AS temperatureincelcius,
    EXTRACT(YEAR FROM th.businessdate)::integer AS yyyy,
    EXTRACT(MONTH FROM th.businessdate)::integer AS mm,
    EXTRACT(DAY FROM th.businessdate)::integer AS dd,
    EXTRACT(HOUR FROM th.orderdatelocal)::integer AS hh,
    EXTRACT(WEEK FROM th.businessdate)::integer AS ww
FROM cte AS th
LEFT JOIN (
    SELECT *
    FROM dim.organizationlocation
    WHERE organizationtype = 0
) AS ol
    ON th.locationid = ol.locationid
LEFT JOIN fact.transactionitem AS ti
    ON th.transactionheaderid = ti.transactionheaderid
LEFT JOIN dim.vw_weatherhourlydata AS wh
    ON th.locationid = wh.locationid
   AND th.businessdate = wh.weatherdate
   AND EXTRACT(HOUR FROM th.orderdatelocal)::integer = wh.hh
LEFT JOIN dim.itemcategory AS ctg
    ON ti.categoryid = ctg.id
LEFT JOIN dim.menuitem AS mi
    ON ti.menuitemid = mi.id
LEFT JOIN dim.ordertype AS ot
    ON th.ordertype = ot.id;



--File name: Upsell Analysis (Item-level, weekly snapshot)
--File hierarchy: ml-training-data/org-abcd/upsell-analysis-yyww-00001.parquet
WITH th (
SELECT * 
FROM fact.transactionheader
WHERE locationid IN (SELECT DISTINCT locationid
                     FROM dim.organizationlocation
                     WHERE (CASE WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' THEN organizationid ELSE locationid END) = '{$pdf_orgid}'
                       AND organizationtype = 0
                    ) 
  AND EXTRACT(YEAR FROM businessdate)::INTEGER = {$pdf_yyyy}
  AND EXTRACT(WEEK FROM businessdate)::INTEGER = {$pdf_ww}

)
SELECT DISTINCT
    ol.organizationid,
    ol.organizationname,
    oa.locationid,
    ol.locationname,
    th.frequentcustomerid,
    oa.transactionheaderid,
    oa.recommendationid,
    oa.offereditem,
    oa.selecteditem,
    mi.item_class_type,
    oa.upselltype,
    oa.quantity,
    th.businessdate,
    th.orderdatelocal,
    EXTRACT(YEAR  FROM th.businessdate)::INTEGER AS yyyy,
    EXTRACT(MONTH FROM th.businessdate)::INTEGER AS mm,
    EXTRACT(DAY   FROM th.businessdate)::INTEGER AS dd,
    EXTRACT(HOUR  FROM th.orderdatelocal)::INTEGER AS hh,
    EXTRACT(WEEK  FROM th.businessdate)::INTEGER AS ww
FROM fact.vw_offer_analysis AS oa
INNER JOIN th
    ON oa.locationid = th.locationid
   AND oa.transactionheaderid = th.transactionheaderid
INNER JOIN (
    SELECT *
    FROM dim.organizationlocation
    WHERE organizationtype = 0
) AS ol
    ON oa.locationid = ol.locationid
LEFT JOIN dim.menuitem AS mi
    ON (
        CASE 
            WHEN oa.offereditem NOT LIKE 'cat-%' 
                THEN oa.offereditem 
            ELSE oa.selecteditem 
        END
    ) = mi.menuitemid;



--File: Weather Dataset (weekly snapshot)
--File hierarchy: ml-training-data/org-abcd/weather-yyww-00001.parquet
WITH wh (
SELECT * 
FROM dim.vw_weatherhourlydata
WHERE locationid IN (SELECT DISTINCT locationid
                     FROM dim.organizationlocation
                     WHERE (CASE WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' THEN organizationid ELSE locationid END) = '{$pdf_orgid}'
                       AND organizationtype = 0
                    ) 
  AND EXTRACT(YEAR FROM weatherdate)::INTEGER = {$pdf_yyyy}
  AND EXTRACT(WEEK FROM weatherdate)::INTEGER = {$pdf_ww}
)
SELECT 
    ol.organizationid,
    ol.organizationname,
    wh.locationid,
    ol.locationname,
    wh.weatherdate,
    EXTRACT(YEAR  FROM wh.weatherdate)::INTEGER AS yyyy,
    EXTRACT(MONTH FROM wh.weatherdate)::INTEGER AS mm,
    EXTRACT(DAY   FROM wh.weatherdate)::INTEGER AS dd,
    EXTRACT(WEEK  FROM wh.weatherdate)::INTEGER AS ww,
    wh.hh,
    wh.humidity,
    wh.condition,
    wh.temperature_c,
    wh.is_hot,
    wh.is_calm,
    wh.is_cold,
    wh.is_cool,
    wh.is_mild,
    wh.is_warm,
    wh.rain_mm,
    wh.is_sunny,
    wh.is_windy,
    wh.is_cloudy,
    wh.is_daytime,
    wh.is_raining,
    wh.is_snowing,
    wh.is_very_hot,
    wh.is_freezing,
    wh.is_overcast,
    wh.snowfall_mm,
    wh.temp_bucket,
    wh.wind_bucket,
    wh.feels_colder,
    wh.feels_hotter,
    wh.food_weather,
    wh.is_heavy_rain,
    wh.is_light_rain,
    wh.is_nighttime,
    wh.is_very_windy,
    wh.pressure_hpa,
    wh.weather_code,
    wh.wind_gust_kmh,
    wh.comfort_score,
    wh.drink_weather,
    wh.wind_speed_kmh,
    wh.comfort_bucket,
    wh.humidity_bucket,
    wh.condition_bucket,
    wh.is_precipitating,
    wh.precipitation_mm,
    wh.visibility_meters,
    wh.cloud_cover_percent,
    wh.is_unseasonably_hot,
    wh.is_unseasonably_cold,
    wh.outdoor_dining_score,
    wh.wind_direction_degrees,
    wh.precipitation_probability,
    wh.apparent_temperature_celsius
FROM wh
LEFT JOIN (
    SELECT *
    FROM dim.organizationlocation
    WHERE organizationtype = 0
) AS ol
    ON wh.locationid = ol.locationid;


--File: Menu Entities V1 (Item-level, weekly snapshot, All levels of hierarchy starting from Org to Item(most granular)
--File hierarchy: ml-training-data/org-abcd/menu-entities-yyww-00001.parquet
WITH order_items AS (
    SELECT *
    FROM fact.transactionitem AS ti
    WHERE ti.locationid IN (
        SELECT DISTINCT ol.locationid
        FROM dim.organizationlocation AS ol
        WHERE (
            CASE WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid  ELSE ol.locationid END
        ) = '{$pdf_orgid}'
          AND ol.organizationtype = 0
    )
      AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
      AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = {$pdf_yyyy}
      AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = {$pdf_ww}
)
SELECT DISTINCT
    ol.organizationid,
    ol.organizationname,
    ti.locationid,
    ti.businessdate,
    EXTRACT(YEAR FROM ti.businessdate)::INTEGER AS yyyy,
    EXTRACT(WEEK FROM ti.businessdate)::INTEGER AS ww,
    ol.locationname,
    ic.categoryid,
    ic.categoryname,
    mi.menuitemid,
    ti.itemunitprice AS unitprice,
    mi.menuitemname,
    mi.item_class_type,
    mi.entitytype,
    mi.calories,
    mi.protein,
    mi.sugar,
    mi.fat,
    mi.is_alcoholic,
    mi.is_vegetarian_item,
    mi.is_vegan_item,
    mi.has_allergen
FROM order_items AS ti
INNER JOIN dim.menuitem AS mi
    ON ti.menuitemid = mi.id
INNER JOIN dim.itemcategory AS ic
    ON ti.categoryid = ic.id
INNER JOIN (
    SELECT *
    FROM dim.organizationlocation
    WHERE organizationtype = 0
) AS ol
    ON ti.locationid = ol.locationid;

--File: Menu Entities V2 (Item-level, weekly snapshot, All levels of hierarchy starting from Org to Item(most granular)
--File hierarchy: ml-training-data/org-abcd/menu-entities-yyww-00001.parquet
WITH order_items AS (
    SELECT ti.*, ic.categoryid as dimcategoryid, ic.categoryname
    FROM (
	SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.* FROM fact.transactionitem AS ti
	INNER JOIN (SELECT DISTINCT * FROM dim.organizationlocation AS ol WHERE (CASE WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid  ELSE ol.locationid END) = '{$pdf_orgid}' AND ol.organizationtype = 0) as ol
			ON ti.locationid = ol.locationid
    WHERE 1=1
      AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
      AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = {$pdf_yyyy}
      AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = {$pdf_ww}
    ) as ti
    INNER JOIN dim.itemcategory as ic 
            ON ti.categoryid = ic.id
), org_agg AS (
	SELECT organizationid, count(*) as total_items_ordered_within_org_and_week
	FROM order_items
    GROUP BY organizationid
), org_itm_agg as (
	SELECT organizationid, dimmenuitemid, count(*) as item_selection_frequency_within_org_and_week
	FROM order_items
	GROUP BY organizationid, dimmenuitemid
), loc_agg as (
	SELECT organizationid, locationid, count(*) as total_items_ordered_within_loc_and_week
	FROM order_items
	GROUP BY organizationid, locationid
), loc_itm_agg as (
	SELECT organizationid, locationid, dimmenuitemid, 
    count(*) as item_selection_frequency_within_loc_and_week,
    avg(itemunitprice) as itemunitprice
	FROM order_items
	GROUP BY organizationid, locationid, dimmenuitemid
), item_statistics AS (
	SELECT lia.organizationid, lia.locationid, lia.dimmenuitemid, lia.itemunitprice,
           lia.item_selection_frequency_within_loc_and_week,
           la.total_items_ordered_within_loc_and_week,
           100 * lia.item_selection_frequency_within_loc_and_week :: NUMERIC(8,3) / la.total_items_ordered_within_loc_and_week as pct_item_selection_freq_within_loc_and_week,
           oia.item_selection_frequency_within_org_and_week,
           oa.total_items_ordered_within_org_and_week,
           100 * oia.item_selection_frequency_within_org_and_week :: NUMERIC(8,3) / oa.total_items_ordered_within_org_and_week as pct_item_selection_freq_within_org_and_week
	FROM loc_itm_agg as lia
    INNER JOIN loc_agg as la 
            ON lia.organizationid = la.organizationid
           AND lia.locationid = la.locationid
    INNER JOIN org_itm_agg as oia 
            ON lia.organizationid = oia.organizationid
           AND lia.dimmenuitemid = oia.dimmenuitemid
    INNER JOIN org_agg as oa 
            ON lia.organizationid = oa.organizationid
), category_hierarchy AS (
    SELECT mi.*, ol.organizationid, ol.organizationname, ctgh.locationid, ol.locationname, ctgh.categoryid, ctgh.categoryname
    FROM dim.menuitem as mi 
    LEFT JOIN dim.category_hierarchy as ctgh 
            ON mi.menuitemid = ctgh.menuitemid
	INNER JOIN (SELECT DISTINCT * FROM dim.organizationlocation AS ol WHERE (CASE WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid  ELSE ol.locationid END) = '{$pdf_orgid}' AND ol.organizationtype = 0) as ol
			ON ctgh.locationid = ol.locationid
    WHERE (EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER = {$pdf_yyyy} AND EXTRACT(WEEK FROM mi.gms_created_on)::INTEGER <= {$pdf_ww})
            OR 
          (EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER < {$pdf_yyyy})
)
SELECT DISTINCT
    mi.organizationid,
    mi.organizationname,
    COALESCE(mi.locationid, ti.locationid) as locationid,
    {$pdf_yyyy}::INTEGER AS yyyy,
    {$pdf_ww}::INTEGER AS ww,
    mi.locationname,
    COALESCE(mi.categoryid, ti.dimcategoryid) as categoryid,
    COALESCE(mi.categoryname, ti.categoryname) as categoryname,
    COALESCE(mi.menuitemid, ti.dimmenuitemid) as menuitemid,
    COALESCE(its.itemunitprice, ti.itemunitprice) AS unitprice,
    its.item_selection_frequency_within_loc_and_week,
    its.total_items_ordered_within_loc_and_week,
    its.pct_item_selection_freq_within_loc_and_week,
    its.item_selection_frequency_within_org_and_week,
    its.total_items_ordered_within_org_and_week,
    its.pct_item_selection_freq_within_org_and_week,
    COALESCE(mi.menuitemname, ti.itemname) as menuitemname,
    mi.item_class_type,
    mi.entitytype,
    mi.calories,
    mi.protein,
    mi.sugar,
    mi.fat,
    mi.is_alcoholic,
    mi.is_vegetarian_item,
    mi.is_vegan_item,
    mi.has_allergen
FROM category_hierarchy as mi 
LEFT JOIN order_items AS ti
    ON mi.id = ti.menuitemid AND mi.categoryid = ti.dimcategoryid
LEFT JOIN item_statistics as its
    ON ti.organizationid = its.organizationid
   AND ti.locationid = its.locationid
   AND ti.dimmenuitemid = its.dimmenuitemid


--File: Location Data (Org/Loc specific attribute, one file per Org/Loc)
--File hierarchy: ml-training-data/org-abcd/location.parquet
WITH order_types AS (
SELECT locationid, jsonb_agg(value->>'label') AS order_type_labels
FROM (SELECT * FROM dim.kioskdetails 
      WHERE dim.is_valid_jsonb(order_types) 
        AND locationid IN (SELECT locationid FROM dim.organizationlocation
                           WHERE organizationtype = 0 
                             AND CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = '@{pipeline().parameters.p_orgid}')
      ) as ld
CROSS JOIN LATERAL jsonb_each(ld.order_types :: jsonb -> 'options')
GROUP BY locationid
)
SELECT DISTINCT 
ol.organizationid,
ol.organizationname,
o.id as locationid,
o.name as locationnname,
o.city,
o.state,
o.country,
o.active as isactive,
o.timezone,
ot.order_type_labels
FROM dim.organization as o
INNER JOIN order_types as ot
        ON o.id = ot.locationid
INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
        ON ot.locationid = ol.locationid
        


--File: Frequent Customers (Organization-level only, thus no locationid, one file per Org)
--File hierarchy: ml-training-data/org-abcd/frequentcustomers.parquet
SELECT fc.organizationid,
       ol.organizationname,
       fc.frequentcustomerid,
       fc.firstname,
       fc.lastname,
       fc.email,
       fc.phone,
       fc.source,
       fc.ordercount,
       fc.amountspent,
       fc.amountspent / case when fc.ordercount > 0 then fc.ordercount else 1 end as avg_amount_spent
FROM dim.frequentcustomer as fc 
INNER JOIN (SELECT DISTINCT organizationid, organizationname
            FROM dim.organizationlocation
            WHERE CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = '@{pipeline().parameters.p_orgid}'
              AND organizationtype = 0) as ol
        ON fc.organizationid = ol.organizationid



WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname, 
           ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.p_orgid}'
      AND ol.organizationtype = 0
), order_items AS (
    SELECT ti.*
    FROM (
        SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.* 
        FROM fact.transactionitem AS ti
        INNER JOIN org_loc_lookup as ol
			ON ti.locationid = ol.locationid
        WHERE 1=1
          AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
          AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = {$pdf_yyyy}
          AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = {$pdf_ww}
    ) as ti/*
), org_agg AS (
    SELECT organizationid, count(*) as total_items_ordered_within_org
    FROM order_items as icl 
    GROUP BY organizationid
), org_itm_agg as (
	SELECT organizationid, dimmenuitemid, count(*) as item_selection_frequency_within_org
	FROM order_items
	GROUP BY organizationid, dimmenuitemid*/
), loc_agg as (
	SELECT organizationid, locationid, count(*) as total_items_ordered_within_loc
	FROM order_items
	GROUP BY organizationid, locationid
), loc_itm_agg as (
	SELECT organizationid, locationid, dimmenuitemid, 
    count(*) as item_selection_frequency_within_loc,
    max(itemunitprice) as itemunitprice
	FROM order_items
	GROUP BY organizationid, locationid, dimmenuitemid
), item_statistics AS (
	SELECT lia.organizationid, lia.locationid, lia.dimmenuitemid, lia.itemunitprice,
           lia.item_selection_frequency_within_loc,
           la.total_items_ordered_within_loc,
           100 * lia.item_selection_frequency_within_loc :: NUMERIC(8,3) / la.total_items_ordered_within_loc as pct_item_selection_freq_within_loc,
           --oia.item_selection_frequency_within_org,
           --oa.total_items_ordered_within_org,
           --100 * oia.item_selection_frequency_within_org :: NUMERIC(8,3) / oa.total_items_ordered_within_org as pct_item_selection_freq_within_org,
           dense_rank() OVER(PARTITION by locationid ORDER BY item_selection_frequency_within_loc DESC) as loc_item_popularity
           --row_number() OVER(PARTITION by organizationid ORDER BY total_items_ordered_within_org DESC) as org_item_popularity,
	FROM loc_itm_agg as lia
    INNER JOIN loc_agg as la 
            ON lia.organizationid = la.organizationid
           AND lia.locationid = la.locationid
    INNER JOIN org_itm_agg as oia 
            ON lia.organizationid = oia.organizationid
           AND lia.dimmenuitemid = oia.dimmenuitemid
    INNER JOIN org_agg as oa 
            ON lia.organizationid = oa.organizationid
), item_details AS (
    SELECT its.organizationid, its.locationid, 
    jsonb_agg(
        jsonb_build_object(
            'menuitemid', its.dimmenuitemid, 
            'x_times_selected', its.item_selection_frequency_within_loc,
            'total_items_selected', its.total_items_ordered_within_loc,
            'pct_of_all_items',  its.pct_item_selection_freq_within_loc,
            'item_class_type', mi.item_class_type,
            'itemunitprice', COALESCE(its.itemunitprice, mi.itemunitprice),
            'loc_item_popularity', loc_item_popularity
        ) ORDER BY loc_item_popularity ASC, item_selection_frequency_within_loc DESC
    ) as loc_item_popularity
    FROM item_statistics as its 
    LEFT JOIN dim.menuitem as mi
           ON its.dimmenuitemid = mi.menuitemid
    WHERE loc_item_popularity <= 20
    GROUP BY its.organizationid, its.locationid
), order_types AS (
SELECT locationid, jsonb_agg(value->>'label') AS order_type_labels
FROM (SELECT * FROM dim.kioskdetails 
      WHERE dim.is_valid_jsonb(order_types) 
        AND locationid IN (SELECT locationid FROM org_loc_lookup)
      ) as ld
CROSS JOIN LATERAL jsonb_each(ld.order_types :: jsonb -> 'options')
GROUP BY locationid
)
SELECT DISTINCT 
olk.organizationid,
olk.organizationname,
olk.locationid,
olk.locationname,
l.city,
l.state,
l.country,
l.active as isactive,
l.timezone,
ot.order_type_labels,
itd.loc_item_popularity
FROM org_loc_lookup as olk
LEFT JOIN dim.organization as l
       ON olk.locationid = l.id
LEFT JOIN order_types as ot
       ON olk.locationid = ot.locationid
LEFT JOIN item_details as itd
       ON olk.locationid = itd.locationid






WITH order_items AS (
SELECT * FROM fact.transactionitem as ti
    WHERE ti.locationid IN (SELECT DISTINCT ol.locationid 
                            FROM dim.organizationlocation AS ol
                            WHERE (CASE WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '{$pdf_orgid}'
                            AND ol.organizationtype = 0
                           )
      AND LOWER(ti.transactionheaderid) like 'ordevt-%'
      AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = {$pdf_yyyy}
      AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = {$pdf_ww}
)
SELECT DISTINCT ol.organizationid, ol.organizationname, ti.locationid, ol.locationname,
        ic.categoryid, ic.categoryname, 
       mi.menuitemid, ti.itemunitprice, mi.menuitemname, mi.item_class_type, 
       mi.entitytype, mi.calories, mi.protein, mi.sugar, mi.fat, mi.is_alcoholic,
       mi.is_vegetarian_item, mi.is_vegan_item, mi.has_allergen
FROM order_items as ti 
INNER JOIN dim.menuitem as mi
        ON ti.menuitemid = mi.id
INNER JOIN dim.itemcategory as ic 
        ON ti.categoryid = ic.id
INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
        ON ti.locationid = ol.locationid

/*
-- ... same CTEs as above ...
SELECT locationid,
       jsonb_agg(
           jsonb_build_object(
               'dimmenuitemid', dimmenuitemid,
               'menuitemname', menuitemname,
               'item_count', item_count,
               'ranking', ranking
           )
           ORDER BY ranking ASC, item_count DESC
       ) as top_menu_items
FROM top_items
GROUP BY locationid
ORDER BY locationid;
*/




SELECT * FROM dim.vw_weatherhourlydata ORDER BY weatherdate DESC, hh DESC

SELECT * FROM dim.organizationlocation
--org-5cf80db5-7a28-4dcf-846b-8cdf5f362269	Bojangles	loc-8ead49a8-798b-4786-988a-90bbbb4775c7	0927 Steele Creek Road	0	True


SELECT organizationid, count(DISTINCT frequentcustomerid), count(DISTINCT transactionheaderid)
FROM test
WHERE frequentcustomerid is NOT NULL
GROUP BY organizationid
--HAVING count(*) > 1


SELECT frequentcustomerid, count(*)
FROM dim.frequentcustomer
GROUP BY frequentcustomerid
HAVING count(*) > 1

select * from dim.itemcategory as ti where ti.id in (546,579162)

SELECT DISTINCT dt.weekval
FROM dim.datedim as dt
WHERE dt.dayval >= '2025-01-01' AND dt.dayval <= '2025-'
order by dt.weekval

SELECT DISTINCT ol.organizationid FROM dim.organizationlocation as ol
WHERE ol.organizationid in 
(
'com-ijr56b6i0h',
'com-usvo6vs4de',
'org-eea294f6-612e-4139-832b-ca3e34257b4b',
'com-3aeuuijrb2',
'org-4c462b58-aaf8-4c3d-8ca9-77d3d02d63c4',
'com-3owh66znkd',
'org-6318f082-1fd5-4c80-bb46-24cbb3399bde',
'com-o519j3rnvd',
'org-a4b81610-f019-45d2-8522-2ccee0e85bd7',
'org-d54ec735-238b-454f-ba73-6ec9d3a7a955'
)

SELECT DISTINCT 
CASE WHEN 'com-o519j3rnvd' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END AS id
FROM dim.organizationlocation as ol
WHERE ol.organizationtype = 0
AND (CASE WHEN 'com-o519j3rnvd' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'com-o519j3rnvd'

select distinct dt.weekval, dt.dayval
from dim.datedim as dt
where 1=1
--and dt.dayval >= '2025-01-01' and dt.dayval <= '2025-06-02'
--and dt.dayval = cast(now() as date)
and EXTRACT(WEEK FROM dt.dayval) :: integer = 1

select cast(now() as date) as nowdatetime, CURRENT_DATE as currend_date