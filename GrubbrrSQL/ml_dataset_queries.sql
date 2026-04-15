/***
Common Parameters:
1. @{pipeline().parameters.p_orgid} --> OrganizationID or LocationID being specified as ADF pipeline param
2. {$pdf_orgid} --> OrganizationID or LocationID being specified as ADF Data Flow Parameter 
3. {$pdf_yyyy} --> year to be collected data for, e.g. 2025, 2026 etc, ADF Data Flow Parameter
4. {$pdf_ww} --> week number 1 to 52, ADF Data Flow Parameter

Training Data Files:

1. Frequent Customers, one file per Organization (only Org-level data, since customer loyalty is tied to Organization)
   Automatically converted to Org-level even if a LocationID is specified as parameter
   Naming Convention: frequentcustomers.parquet
   File: Frequent Customers (one file per Organization)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/frequentcustomers.parquet

***/ 

WITH org_loc_lookup AS(
    SELECT DISTINCT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname
    FROM dim.organizationlocation as ol
    WHERE ol.organizationid in 
                   (SELECT DISTINCT organizationid
                    FROM dim.organizationlocation AS ol
                    WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.p_orgid}'
                    AND ol.organizationtype = 0)
), loc_specific_favorite_items AS (
    SELECT 
        fc.frequentcustomerid, 
        fc.organizationid, 
        th.locationid, 
        ti.dimmenuitemid, 
        min(mi.item_class_type) as item_class_type,
        count(*) as x_times_selected,
        row_number() OVER(PARTITION BY fc.frequentcustomerid, fc.organizationid, th.locationid ORDER BY count(*) DESC) as item_ranking_within_loc
    FROM dim.frequentcustomer as fc 
    INNER JOIN fact.transactionheader as th 
        ON fc.frequentcustomerid = th.frequentcustomerid 
    INNER JOIN fact.transactionitem as ti 
        ON th.locationid = ti.locationid 
        AND th.transactionheaderid = ti.transactionheaderid
    INNER JOIN dim.menuitem as mi 
            ON ti.menuitemid = mi.id
    WHERE ti.dimmenuitemid IS NOT NULL
      AND th.locationid IN (SELECT DISTINCT locationid FROM org_loc_lookup)
    GROUP BY fc.frequentcustomerid, fc.organizationid, th.locationid, ti.dimmenuitemid
), overall_favorite_items AS (
    SELECT 
        fc.frequentcustomerid, 
        fc.organizationid,
        ti.dimmenuitemid, 
        min(mi.item_class_type) as item_class_type,
        count(*) as x_times_selected,
        row_number() OVER(PARTITION BY fc.frequentcustomerid, fc.organizationid ORDER BY count(*) DESC) as item_ranking_within_org
    FROM dim.frequentcustomer as fc 
    INNER JOIN fact.transactionheader as th 
        ON fc.frequentcustomerid = th.frequentcustomerid
    INNER JOIN fact.transactionitem as ti 
        ON th.locationid = ti.locationid 
        AND th.transactionheaderid = ti.transactionheaderid 
    INNER JOIN dim.menuitem as mi 
        ON ti.menuitemid = mi.id
    WHERE ti.dimmenuitemid IS NOT NULL
      AND th.locationid IN (SELECT DISTINCT locationid FROM org_loc_lookup)
    GROUP BY fc.frequentcustomerid, fc.organizationid, ti.dimmenuitemid
), jsonb_loc_specific_favorite_items AS (
SELECT 
    organizationid,
    frequentcustomerid,
    jsonb_agg(
        jsonb_build_object(
            'organizationid', organizationid,
            'locationid', locationid,
            'menuitemid', dimmenuitemid,
            'item_class_type', item_class_type,
            'x_times_selected', x_times_selected,
            'item_ranking', item_ranking_within_loc
        ) ORDER BY x_times_selected DESC
    ) AS loc_specific_favorite_items_jsonb
FROM loc_specific_favorite_items
GROUP BY organizationid, frequentcustomerid
), jsonb_overall_favorite_items AS (
SELECT
    organizationid,
    frequentcustomerid,
    jsonb_agg(
        jsonb_build_object(
            'organizationid', organizationid,
            'menuitemid', dimmenuitemid,
            'item_class_type', item_class_type,
            'x_times_selected', x_times_selected,
            'item_ranking', item_ranking_within_org
        ) ORDER BY x_times_selected DESC
    ) AS overall_favorite_items_jsonb
FROM overall_favorite_items
GROUP BY organizationid, frequentcustomerid
), static_upsells as (
SELECT th.frequentcustomerid, oa.offereditem, 
       min(mi.item_class_type) as item_class_type,
       count(*) as x_times_offered,
       sum(CASE WHEN oa.selecteditem IS NOT NULL THEN 1 ELSE 0 END) as x_times_selected
FROM fact.vw_offer_analysis as oa 
INNER JOIN (SELECT * FROM fact.transactionheader WHERE frequentcustomerid IS NOT NULL) as th 
        ON oa.locationid = th.locationid
       AND oa.transactionheaderid = th.transactionheaderid
INNER JOIN dim.menuitem as mi 
        ON oa.offereditem = mi.menuitemid
WHERE oa.locationid IN (SELECT DISTINCT locationid FROM org_loc_lookup)
GROUP BY th.frequentcustomerid, oa.offereditem
), jsonb_static_upsells AS (
SELECT frequentcustomerid,
    jsonb_agg(
        jsonb_build_object(
            'menuitemid', offereditem,
            'item_class_type', item_class_type,
            'x_times_offered', x_times_offered,
            'x_times_selected', x_times_selected
        ) ORDER BY x_times_selected DESC
    ) as static_upsell_stats_jsonb
FROM static_upsells
GROUP BY frequentcustomerid
)
    SELECT DISTINCT
           ol.organizationid,
           ol.organizationname,
           fc.frequentcustomerid,
           fc.firstname,
           fc.lastname,
           fc.email,
           fc.phone,
           fc.source,
           fc.ordercount,
           fc.amountspent,
           fc.amountspent / case when fc.ordercount > 0 then fc.ordercount else 1 end as avg_amount_spent,
           lfi.loc_specific_favorite_items_jsonb, 
           ofi.overall_favorite_items_jsonb,
           su.static_upsell_stats_jsonb
    FROM dim.frequentcustomer as fc
    LEFT JOIN jsonb_loc_specific_favorite_items as lfi
            ON lfi.organizationid = fc.organizationid
           AND lfi.frequentcustomerid = fc.frequentcustomerid    
    LEFT JOIN jsonb_overall_favorite_items as ofi
            ON lfi.frequentcustomerid = ofi.frequentcustomerid
           AND lfi.organizationid = ofi.organizationid
    LEFT JOIN jsonb_static_upsells as su
            ON lfi.frequentcustomerid = su.frequentcustomerid
    INNER JOIN (SELECT DISTINCT organizationid, organizationname FROM org_loc_lookup) as ol 
            ON fc.organizationid = ol.organizationid









/***
Training Data Files:

2. Location dataset, one file per Organization or Location, depending on what is specified as ADF pipeline param
   Naming Convention: location.parquet
   File: Location Details and Statistics (one file per Organization or Location)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/location.parquet
***/ 

CREATE OR REPLACE PROCEDURE fact.usp_location_statistics()
LANGUAGE plpgsql
AS $BODY$

BEGIN

TRUNCATE TABLE fact.location_statistics;

WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname, 
           ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE 1=1 
      --AND (CASE WHEN 'com-3owh66znkd' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'com-3owh66znkd'
      AND ol.organizationtype = 0
), order_items AS (
    SELECT ti.*
    FROM (
        SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.* 
        FROM fact.transactionitem AS ti
        INNER JOIN org_loc_lookup as ol
			ON ti.locationid = ol.locationid
        WHERE 1=1
          AND ti.transactionheaderid LIKE 'ordevt-%'
    ) as ti
), frequent_customers as (
    SELECT fc.organizationid, 
           count(*) as number_of_frequent_customers,
           sum(fc.ordercount) as orders_placed_by_freq_customers,
           sum(fc.amountspent) as amount_spent_by_freq_customers,
           sum(fc.amountspent) / case when sum(fc.ordercount) > 0 then sum(fc.ordercount) else 1 end as avg_amount_spent_by_freq_customers
    FROM dim.frequentcustomer as fc
    GROUP BY fc.organizationid
), org_agg_trxn as (
	SELECT ol.organizationid, 
           count(*) as org_total_order_count,
           sum(th.ordertotal) as org_total_sales_amount,
           round(avg(th.ordertotal), 3) as org_avg_order_amount
	FROM fact.transactionheader as th 
    INNER JOIN org_loc_lookup as ol
            ON th.locationid = ol.locationid
    WHERE th.orderstatus = 'order-placed'
	GROUP BY organizationid
), loc_agg_trxn as (
	SELECT th.locationid, 
           count(*) as loc_total_order_count,
           sum(th.ordertotal) as loc_total_sales_amount,
           round(avg(th.ordertotal), 3) as loc_avg_order_amount
	FROM fact.transactionheader as th 
    WHERE th.orderstatus = 'order-placed'
	GROUP BY th.locationid
), loc_agg as (
	SELECT organizationid, locationid, 
           count(*) as total_items_ordered_within_loc
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
           dense_rank() OVER(PARTITION by lia.locationid ORDER BY item_selection_frequency_within_loc DESC) as loc_item_popularity
	FROM loc_itm_agg as lia
    INNER JOIN loc_agg as la 
            ON lia.organizationid = la.organizationid
           AND lia.locationid = la.locationid
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
INSERT INTO fact.location_statistics
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
itd.loc_item_popularity,
COALESCE(la.loc_total_order_count, 0) as loc_total_order_count,
COALESCE(la.loc_total_sales_amount, 0) as loc_total_sales_amount,
COALESCE(la.loc_avg_order_amount, 0) as loc_avg_order_amount,
COALESCE(oa.org_total_order_count, 0) as org_total_order_count,
COALESCE(oa.org_total_sales_amount, 0) as org_total_sales_amount,
COALESCE(oa.org_avg_order_amount, 0) as org_avg_order_amount,
COALESCE(fc.number_of_frequent_customers, 0) as number_of_frequent_customers,
COALESCE(fc.orders_placed_by_freq_customers, 0) as orders_placed_by_freq_customers,
COALESCE(fc.amount_spent_by_freq_customers, 0) as amount_spent_by_freq_customers,
COALESCE(ROUND(fc.avg_amount_spent_by_freq_customers, 3), 0) as avg_amount_spent_by_freq_customers,
now() :: TIMESTAMP as sysupdatetime
FROM org_loc_lookup as olk
LEFT JOIN dim.organization as l
       ON olk.locationid = l.id
LEFT JOIN order_types as ot
       ON olk.locationid = ot.locationid
LEFT JOIN item_details as itd
       ON olk.locationid = itd.locationid
LEFT JOIN loc_agg_trxn as la 
       ON olk.locationid = la.locationid
LEFT JOIN org_agg_trxn as oa
       ON olk.organizationid = oa.organizationid
LEFT JOIN frequent_customers as fc 
       ON olk.organizationid = fc.organizationid;

END;
$BODY$;
ALTER PROCEDURE fact.usp_location_statistics()
    OWNER TO citus;

SELECT DISTINCT
    organizationid,
    organizationname,
    locationid,
    locationname,
    city,
    state,
    country,
    isactive,
    timezone,
    order_type_labels,
    loc_item_popularity,
    loc_total_order_count,
    loc_total_sales_amount,
    loc_avg_order_amount,
    org_total_order_count,
    org_total_sales_amount,
    org_avg_order_amount,
    number_of_frequent_customers,
    orders_placed_by_freq_customers,
    amount_spent_by_freq_customers,
    avg_amount_spent_by_freq_customers
FROM fact.location_statistics
WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN organizationid ELSE locationid END) = '@{pipeline().parameters.p_orgid}'














/***
Training Data Files:

3. Duplicate Item Master data, one file per Organization or Location, depending on what is specified as ADF pipeline param
   Naming Convention: master-items.parquet
   File: Frequent Customers (one file per Organization or Location)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/master-items.parquet
***/ 


CREATE OR REPLACE PROCEDURE dim.usp_master_keys_for_duplicate_items()
LANGUAGE plpgsql
AS $BODY$

BEGIN

WITH duplicate_items AS (
    SELECT *, 
           count(*) over(PARTITION BY locationid, trim(lower(menuitemname))) as dupl
    FROM dim.category_hierarchy
)
INSERT INTO dim.duplicate_items_master (
    organizationid,
    locationid,
    categoryid,
    categoryname,
    menuitemid,
    entitytype,
    item_class_type,
    menuitemname,
    sysinserttime
)
SELECT organizationid,
       locationid,
       categoryid,
       categoryname,
       menuitemid,
       entitytype,
       item_class_type,
       menuitemname,
       now()::TIMESTAMP
FROM duplicate_items di
WHERE dupl > 1
  AND NOT EXISTS (
        SELECT 1 
        FROM dim.duplicate_items_master as dim
        WHERE dim.locationid = di.locationid
          AND dim.categoryid = di.categoryid
          AND dim.menuitemid = di.menuitemid
  );

WITH item_counts AS (
    SELECT locationid, dimmenuitemid, count(*) AS instance_count
    FROM fact.transactionitem
	WHERE transactionheaderid like 'ordevt-%'
    GROUP BY locationid, dimmenuitemid
)
UPDATE dim.duplicate_items_master dim
SET instance_count = ic.instance_count,
    sysupdatetime  = now()::TIMESTAMP
FROM item_counts ic
WHERE dim.locationid = ic.locationid
  AND dim.menuitemid = ic.dimmenuitemid;

UPDATE dim.duplicate_items_master dim
SET masteritemid = concat('mstritm-', uuid_generate_v5(uuid_ns_dns(), concat(dim.locationid, ':', trim(lower(dim.menuitemname))))),
	sysupdatetime  = now()::TIMESTAMP
WHERE dim.masteritemid IS NULL;


END;
$BODY$;
ALTER PROCEDURE dim.usp_master_keys_for_duplicate_items()
    OWNER TO citus;

WITH org_loc_lookup AS (
SELECT DISTINCT ol.organizationid, ol.organizationname, 
	   ol.locationid, ol.locationname
FROM dim.organizationlocation AS ol
WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.p_orgid}'
  AND ol.organizationtype = 0
)
SELECT dim.organizationid,
	   ol.organizationname,
	   dim.locationid,
	   ol.locationname,
	   ctg.catalogid,
	   ctg.catalogname,
	   dim.categoryid,
	   dim.categoryname,
	   dim.menuitemid,
	   ctg.is_item_active,
	   ctg.is_item_deleted,
	   dim.entitytype,
	   dim.item_class_type,
	   dim.menuitemname,
	   dim.instance_count,
	   dim.masteritemid
FROM dim.duplicate_items_master as dim
INNER JOIN org_loc_lookup as ol 
		ON dim.locationid = ol.locationid
INNER JOIN dim.category_hierarchy as ctg 
		ON dim.locationid = ctg.locationid
	   AND dim.categoryid = ctg.categoryid
	   AND dim.menuitemid = ctg.menuitemid










/***
Training Data Files:

4. Main Transaction dataset, weekly file per Organization or Location, depending on what is specified as ADF pipeline param
   Naming Convention: data-yyww.parquet
   yyww - stands for year and week of observation date period, for example, 
   2026 year and 10 th week would be formatted as yyww = 2610, 
   the first yy means the last 2 digits of year (26 in case of 2026) 
   and week number ww --> 10 --> 2610
   File: Main Transaction dataset (Item-level, weekly snapshot)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/data-yyww.parquet
***/ 

WITH cte AS (
    SELECT *
    FROM fact.transactionheader AS th
    WHERE th.locationid IN (
        SELECT DISTINCT ol.locationid
        FROM dim.organizationlocation AS ol
        WHERE (
            CASE 
                WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' 
                THEN ol.organizationid 
                ELSE ol.locationid 
            END
        ) = '{$pdf_orgid}'
          AND ol.organizationtype = 0
    )
      AND LOWER(th.orderstatus) = 'order-placed'
      AND EXTRACT(YEAR FROM th.businessdate)::integer = {$pdf_yyyy}
      AND EXTRACT(WEEK FROM th.businessdate)::integer = {$pdf_ww}
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








/***
Training Data Files:

5. Upsell-Analysis dataset, weekly file per Organization or Location, depending on what is specified as ADF pipeline param
   Naming Convention: upsell-analysis-yyww.parquet
   yyww - stands for year and week of observation date period, for example, 
   2026 year and 10 th week would be formatted as yyww = 2610, 
   the first yy means the last 2 digits of year (26 in case of 2026) 
   and week number ww --> 10 --> 2610
   File: Upsell-Analysis dataset (Item-level, weekly snapshot)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/upsell-analysis-yyww.parquet
***/ 

WITH th AS (
    SELECT *
    FROM fact.transactionheader
    WHERE locationid IN (
        SELECT DISTINCT locationid
        FROM dim.organizationlocation
        WHERE (
            CASE 
                WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' 
                THEN organizationid 
                ELSE locationid 
            END
        ) = '{$pdf_orgid}'
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
    EXTRACT(YEAR FROM th.businessdate)::INTEGER AS yyyy,
    EXTRACT(MONTH FROM th.businessdate)::INTEGER AS mm,
    EXTRACT(DAY FROM th.businessdate)::INTEGER AS dd,
    EXTRACT(HOUR FROM th.orderdatelocal)::INTEGER AS hh,
    EXTRACT(WEEK FROM th.businessdate)::INTEGER AS ww
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






/***
Training Data Files:

6. Weather dataset, weekly file per Organization or Location, depending on what is specified as ADF pipeline param
   Naming Convention: weather-yyww.parquet
   yyww - stands for year and week of observation date period, for example, 
   2026 year and 10 th week would be formatted as yyww = 2610, 
   the first yy means the last 2 digits of year (26 in case of 2026) 
   and week number ww --> 10 --> 2610
   File: Weather dataset (hourly weather data, weekly snapshot)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/weather-yyww.parquet
***/ 


WITH wh AS (
    SELECT *
    FROM dim.vw_weatherhourlydata
    WHERE locationid IN (
        SELECT DISTINCT locationid
        FROM dim.organizationlocation
        WHERE (
            CASE 
                WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' 
                THEN organizationid 
                ELSE locationid 
            END
        ) = '{$pdf_orgid}'
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
    EXTRACT(YEAR FROM wh.weatherdate)::INTEGER AS yyyy,
    EXTRACT(MONTH FROM wh.weatherdate)::INTEGER AS mm,
    EXTRACT(DAY FROM wh.weatherdate)::INTEGER AS dd,
    EXTRACT(WEEK FROM wh.weatherdate)::INTEGER AS ww,
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


/***
Training Data Files:

7. Menu Entities dataset, weekly file per Organization or Location, depending on what is specified as ADF pipeline param
   Naming Convention: menu-entities-yyww.parquet
   yyww - stands for year and week of observation date period, for example, 
   2026 year and 10 th week would be formatted as yyww = 2610, 
   the first yy means the last 2 digits of year (26 in case of 2026) 
   and week number ww --> 10 --> 2610
   File: Menu Entities dataset (Item-level, weekly snapshot)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/menu-entities-yyww.parquet
***/

WITH org_loc_lookup AS (
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        ol.locationid,
        ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (
        CASE 
            WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' 
            THEN ol.organizationid 
            ELSE ol.locationid 
        END
    ) = '{$pdf_orgid}'
      AND ol.organizationtype = 0
),

order_items AS (
    SELECT ti.*, ic.categoryid AS dimcategoryid, ic.categoryname
    FROM (
        SELECT 
            ol.organizationid,
            ol.organizationname,
            ol.locationname,
            ti.*
        FROM fact.transactionitem AS ti
        INNER JOIN org_loc_lookup AS ol
            ON ti.locationid = ol.locationid
        WHERE 1=1
          AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
          AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = {$pdf_yyyy}
          AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = {$pdf_ww}
    ) AS ti
    INNER JOIN dim.itemcategory AS ic
        ON ti.categoryid = ic.id
),

org_agg AS (
    SELECT 
        organizationid,
        COUNT(*) AS total_items_ordered_within_org_and_week
    FROM order_items
    GROUP BY organizationid
),

org_itm_agg AS (
    SELECT 
        organizationid,
        dimmenuitemid,
        COUNT(*) AS item_selection_frequency_within_org_and_week
    FROM order_items
    GROUP BY organizationid, dimmenuitemid
),

loc_agg AS (
    SELECT 
        organizationid,
        locationid,
        COUNT(*) AS total_items_ordered_within_loc_and_week
    FROM order_items
    GROUP BY organizationid, locationid
),

loc_itm_agg AS (
    SELECT 
        organizationid,
        locationid,
        dimmenuitemid,
        COUNT(*) AS item_selection_frequency_within_loc_and_week,
        MAX(itemunitprice) AS itemunitprice
    FROM order_items
    GROUP BY organizationid, locationid, dimmenuitemid
),

item_statistics AS (
    SELECT 
        lia.organizationid,
        lia.locationid,
        lia.dimmenuitemid,
        lia.itemunitprice,
        lia.item_selection_frequency_within_loc_and_week,
        la.total_items_ordered_within_loc_and_week,
        100 * lia.item_selection_frequency_within_loc_and_week::NUMERIC(8,3) 
            / la.total_items_ordered_within_loc_and_week AS pct_item_selection_freq_within_loc_and_week,
        oia.item_selection_frequency_within_org_and_week,
        oa.total_items_ordered_within_org_and_week,
        100 * oia.item_selection_frequency_within_org_and_week::NUMERIC(8,3) 
            / oa.total_items_ordered_within_org_and_week AS pct_item_selection_freq_within_org_and_week
    FROM loc_itm_agg AS lia
    INNER JOIN loc_agg AS la
        ON lia.organizationid = la.organizationid
       AND lia.locationid = la.locationid
    INNER JOIN org_itm_agg AS oia
        ON lia.organizationid = oia.organizationid
       AND lia.dimmenuitemid = oia.dimmenuitemid
    INNER JOIN org_agg AS oa
        ON lia.organizationid = oa.organizationid
),

category_hierarchy AS (
    SELECT 
        mi.*,
        ol.organizationid,
        ol.organizationname,
        ctgh.locationid,
        ol.locationname,
        ctgh.categoryid,
        ctgh.categoryname
    FROM dim.menuitem AS mi
    LEFT JOIN dim.category_hierarchy AS ctgh
        ON mi.menuitemid = ctgh.menuitemid
    INNER JOIN org_loc_lookup AS ol
        ON ctgh.locationid = ol.locationid
    WHERE (
        EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER = {$pdf_yyyy}
        AND EXTRACT(WEEK FROM mi.gms_created_on)::INTEGER <= {$pdf_ww}
    )
    OR (
        EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER < {$pdf_yyyy}
    )
)

SELECT DISTINCT
    mi.organizationid,
    mi.organizationname,
    COALESCE(mi.locationid, ti.locationid) AS locationid,
    {$pdf_yyyy}::INTEGER AS yyyy,
    {$pdf_ww}::INTEGER AS ww,
    mi.locationname,
    COALESCE(mi.categoryid, ti.dimcategoryid) AS categoryid,
    COALESCE(mi.categoryname, ti.categoryname) AS categoryname,
    COALESCE(mi.menuitemid, ti.dimmenuitemid) AS menuitemid,
    COALESCE(its.itemunitprice, ti.itemunitprice) AS unitprice,
    its.item_selection_frequency_within_loc_and_week,
    its.total_items_ordered_within_loc_and_week,
    its.pct_item_selection_freq_within_loc_and_week,
    its.item_selection_frequency_within_org_and_week,
    its.total_items_ordered_within_org_and_week,
    its.pct_item_selection_freq_within_org_and_week,
    COALESCE(mi.menuitemname, ti.itemname) AS menuitemname,
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
FROM category_hierarchy AS mi
LEFT JOIN order_items AS ti
    ON mi.id = ti.menuitemid
   AND mi.categoryid = ti.dimcategoryid
LEFT JOIN item_statistics AS its
    ON ti.organizationid = its.organizationid
   AND ti.locationid = its.locationid
   AND ti.dimmenuitemid = its.dimmenuitemid;







/***
Training Data Files:

8. Modifier-Interactions dataset, weekly file per Organization or Location, depending on what is specified as ADF pipeline param
   Naming Convention: modifiers-yyww.parquet
   yyww - stands for year and week of observation date period, for example, 
   2026 year and 10 th week would be formatted as yyww = 2610, 
   the first yy means the last 2 digits of year (26 in case of 2026) 
   and week number ww --> 10 --> 2610
   File: Modifiers dataset (modifier-level, weekly snapshot)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/modifier-interactions-yyww.parquet
***/



WITH org_loc_lookup AS (
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        ol.locationid,
        ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (
        CASE
            WHEN '{$pdf_orgid}' NOT LIKE 'loc-%'
                THEN ol.organizationid
            ELSE ol.locationid
        END
    ) = '{$pdf_orgid}'
      AND ol.organizationtype = 0
),

org_loc_ctlg AS (
    SELECT
        ol.*,
        c.catalogid,
        c.catalogname
    FROM org_loc_lookup AS ol
    INNER JOIN dim.catalog AS c
        ON ol.organizationid = c.organizationid
       AND ol.locationid = c.gem_location_id
),

org_loc_ctlg_modifiers AS (
    SELECT
        m.*,
        olc.organizationid,
        olc.organizationname,
        olc.locationid,
        olc.locationname,
        olc.catalogname
    FROM dim.modifier AS m
    INNER JOIN org_loc_ctlg AS olc
        ON m.catalogid = olc.catalogid
    WHERE (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER = {$pdf_yyyy}
            AND EXTRACT(WEEK FROM m.modifier_created_on)::INTEGER <= {$pdf_ww}
          )
       OR (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER < {$pdf_yyyy}
          )
),

trxn_items AS (
    SELECT
        ol.organizationid,
        ol.organizationname,
        ol.locationname,
        ti.*
    FROM fact.transactionitem AS ti
    INNER JOIN org_loc_lookup AS ol
        ON ti.locationid = ol.locationid
    WHERE 1 = 1
      AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
      AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = {$pdf_yyyy}
      AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = {$pdf_ww}
)

SELECT
    olcm.organizationid,
    olcm.organizationname,
    olcm.locationname,
    olcm.locationid,
    olcm.catalogid,
    olcm.catalogname,
    mt.businessdate,
    ti.orderdatelocal,
    {$pdf_yyyy} AS yyyy,
    {$pdf_ww} AS ww,
    mt.transactionheaderid,
    ti.ordersessionid,
    mt.orderid,
    mt.itemid AS orderitemid,
    ti.dimmenuitemid AS menuitemid,
    mi.menuitemname,
    ti.itemquantity,
    ti.itemunitprice,
    mi.item_class_type,
    mt.modifiergroupid,
    mg.modifiergroupname,
    mt.modifierid,
    mt.modifiername,
    NULL::TEXT AS parent_modifier_id,
    NULL::INTEGER AS nesting_depth,
    mt.modifierquantity,
    mt.modifierprice,
    mt.freequantity,
    mgm.is_default as is_modifier_default,
    mg.min_selection as min_quantity,
    mg.max_selection as max_quantity,
    CASE
        WHEN mgm.is_default = FALSE
             AND mg.min_selection = 0
             AND mg.max_selection >= 0
            THEN 'optional'
        WHEN mgm.is_default = FALSE
             AND mg.min_selection >= 1
             AND mg.max_selection >= 1
            THEN 'required'
        WHEN mgm.is_default = TRUE
            THEN 'default'
    END AS selection_type,
    CASE
        WHEN mgm.is_default = FALSE
             AND mg.min_selection = 0
             AND mg.max_selection >= 0
             AND mt.modifierquantity >= 1
            THEN 'added'
        WHEN mgm.is_default = FALSE
             AND mg.min_selection >= 1
             AND mg.max_selection >= 1
             AND mt.modifierquantity >= 1
            THEN 'selected'
        WHEN mgm.is_default = TRUE
             AND mg.min_selection >= 1
             AND mg.max_selection >= 1
             AND mt.modifierquantity >= 1
            THEN 'kept'
        WHEN mgm.is_default = TRUE
             AND mg.min_selection >= 1
             AND mg.max_selection >= 1
             AND mt.modifierquantity = 0
            THEN 'removed'
    END AS action,
    NULL::TEXT AS session_recorded_at,
    ti.frequentcustomerid,
    olcm.modifier_default_quantity,
    olcm.classification AS modifier_class_type
FROM fact.itemmodifier AS mt
INNER JOIN trxn_items AS ti
    ON mt.transactionheaderid = ti.transactionheaderid
   AND mt.itemid = ti.itemid
INNER JOIN org_loc_ctlg_modifiers AS olcm
    ON ti.locationid = olcm.locationid
   AND mt.modifierid = olcm.modifierid
INNER JOIN dim.menuitem AS mi
    ON mi.menuitemid = ti.dimmenuitemid
LEFT JOIN dim.modifier_group_mapping as mgm
    ON mgm.modifiergroupid = mt.modifiergroupid
    AND mgm.modifierid = mt.modifierid
LEFT JOIN dim.modifier_group as mg 
    ON mg.modifiergroupid = mt.modifiergroupid;



/**
9. Modifier-Impressions dataset, weekly file per Organization or Location, depending on what is specified as ADF pipeline param
   Naming Convention: modifiers-yyww.parquet
   yyww - stands for year and week of observation date period, for example, 
   2026 year and 10 th week would be formatted as yyww = 2610, 
   the first yy means the last 2 digits of year (26 in case of 2026) 
   and week number ww --> 10 --> 2610
   File: Item-Modifier-Group-Modifier-Mapping dataset dataset (modifier-level, weekly snapshot)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/item-modifier-group-modifier-mapping-yyww.parquet
***/

WITH org_loc_lookup AS (
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        ol.locationid,
        ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (
        CASE
            WHEN '{$pdf_orgid}' NOT LIKE 'loc-%'
                THEN ol.organizationid
            ELSE ol.locationid
        END
    ) = '{$pdf_orgid}'
      AND ol.organizationtype = 0
),

org_loc_ctlg AS (
    SELECT
        ol.*,
        c.catalogid,
        c.catalogname
    FROM org_loc_lookup AS ol
    INNER JOIN dim.catalog AS c
        ON ol.organizationid = c.organizationid
       AND ol.locationid = c.gem_location_id
),

org_loc_ctlg_modifiers AS (
    SELECT
        m.*,
        olc.organizationid,
        olc.organizationname,
        olc.locationid,
        olc.locationname,
        olc.catalogname
    FROM dim.modifier AS m
    INNER JOIN org_loc_ctlg AS olc
        ON m.catalogid = olc.catalogid
    WHERE (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER = {$pdf_yyyy}
            AND EXTRACT(WEEK FROM m.modifier_created_on)::INTEGER <= {$pdf_ww}
          )
       OR (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER < {$pdf_yyyy}
          )
),

trxn_items AS (
    SELECT
        ol.organizationid,
        ol.organizationname,
        ol.locationname,
        ti.*
    FROM fact.modifier_impressions AS ti
    INNER JOIN org_loc_lookup AS ol
        ON ti.locationid = ol.locationid
    WHERE 1 = 1
      AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
      AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = {$pdf_yyyy}
      AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = {$pdf_ww}
)

SELECT
    olcm.organizationid,
    olcm.organizationname,
    olcm.locationname,
    olcm.locationid,
    olcm.catalogid,
    olcm.catalogname,
    m.businessdate,
    m.orderdatelocal,
    {$pdf_yyyy} AS yyyy,
    {$pdf_ww} AS ww,
    m.transactionheaderid,
    m.ordersessionid,
    m.orderid,
    m.menuitemid,
    mi.menuitemname,
    mi.item_class_type,
    m.modifierid,
    olcm.modifiername,
    olcm.classification AS modifier_class_type,
    m.parent_modifier_id,
    m.nesting_depth,
    olcm.price AS modifierprice,
    m.selection_type,
    m.position,
    m.score,
    m.strategy,
    m.context,
    m.selected,
    m.pre_deselected,
    m.confirmed_removed,
    m.pre_selected,
    m.frequentcustomerid
FROM trxn_items AS m
INNER JOIN org_loc_ctlg_modifiers AS olcm
    ON m.locationid = olcm.locationid
   AND m.modifierid = olcm.modifierid
INNER JOIN dim.menuitem AS mi
    ON mi.menuitemid = m.menuitemid;


/**
10. Item-Modifier-Group-Modifier-Mapping dataset, weekly file per Organization or Location, depending on what is specified as ADF pipeline param
   Naming Convention: modifiers-yyww.parquet
   yyww - stands for year and week of observation date period, for example, 
   2026 year and 10 th week would be formatted as yyww = 2610, 
   the first yy means the last 2 digits of year (26 in case of 2026) 
   and week number ww --> 10 --> 2610
   File: Item-Modifier-Group-Modifier-Mapping dataset dataset (modifier-level, weekly snapshot)
   File hierarchy: ml-training-data/org-abcd/loc-abcd/item-modifier-group-modifier-mapping-yyww.parquet
***/


WITH org_loc_lookup AS (
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        ol.locationid,
        ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE 1 = 1
      AND (
          CASE
              WHEN '{$pdf_orgid}' NOT LIKE 'loc-%'
                  THEN ol.organizationid
              ELSE ol.locationid
          END
      ) = '{$pdf_orgid}'
      AND ol.organizationtype = 0
),

org_loc_ctlg AS (
    SELECT
        ol.*,
        c.catalogid,
        c.catalogname
    FROM org_loc_lookup AS ol
    INNER JOIN dim.catalog AS c
        ON ol.organizationid = c.organizationid
       AND ol.locationid = c.gem_location_id
),

org_loc_ctlg_modifiers AS (
    SELECT
        m.*,
        olc.organizationid,
        olc.organizationname,
        olc.locationid,
        olc.locationname,
        olc.catalogname
    FROM dim.modifier AS m
    INNER JOIN org_loc_ctlg AS olc
        ON m.catalogid = olc.catalogid
    WHERE (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER = {$pdf_yyyy}
            AND EXTRACT(WEEK FROM m.modifier_created_on)::INTEGER <= {$pdf_ww}
          )
       OR (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER < {$pdf_yyyy}
          )
),

trxn_items AS (
    SELECT
        ol.organizationid,
        ol.organizationname,
        ol.locationname,
        ti.*
    FROM fact.transactionitem AS ti
    INNER JOIN org_loc_lookup AS ol
        ON ti.locationid = ol.locationid
    WHERE 1 = 1
      AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
      AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = {$pdf_yyyy}
      AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = {$pdf_ww}
),

trxn_modifiers AS (
    SELECT
        ti.organizationid,
        ti.organizationname,
        ti.locationname,
        ti.locationid,
        ti.businessdate,
        ti.orderdatelocal,
        {$pdf_yyyy} AS yyyy,
        {$pdf_ww} AS ww,
        m.transactionheaderid,
        m.itemid AS orderitemid,
        ti.dimmenuitemid AS menuitemid,
        ti.itemquantity,
        ti.itemunitprice,
        m.modifiergroupid,
        m.modifierid,
        m.modifiername,
        m.modifierquantity,
        m.modifierprice,
        m.freequantity
    FROM fact.itemmodifier AS m
    INNER JOIN trxn_items AS ti
        ON m.transactionheaderid = ti.transactionheaderid
       AND m.itemid = ti.itemid
),

loc_mdfr_agg AS (
    SELECT
        organizationid,
        locationid,
        modifierid,
        COUNT(*) AS mdfr_selection_frequency_within_loc_and_week,
        MAX(modifierprice) AS modifierprice
    FROM trxn_modifiers
    GROUP BY organizationid, locationid, modifierid
),

loc_mdfr_itm AS (
    SELECT
        organizationid,
        locationid,
        modifierid,
        menuitemid,
        COUNT(*) AS x_times_added_on_to_the_item,
        ROW_NUMBER() OVER (
            PARTITION BY organizationid, locationid, modifierid
            ORDER BY COUNT(*) DESC
        ) AS mdfr_selection_ranking
    FROM trxn_modifiers
    GROUP BY organizationid, locationid, modifierid, menuitemid
)

SELECT
    m.organizationid,
    m.organizationname,
    m.locationid,
    m.locationname,
    m.catalogid,
    m.catalogname,
    {$pdf_yyyy} AS yyyy,
    {$pdf_ww} AS ww,
    imgm.menuitemid,
    mi.menuitemname,
    mi.item_class_type,
    imgm.modifiergroupid,
    mg.modifiergroupname,
    imgm.modifierid,
    m.modifiername,
    m.classification AS modifier_class_type,
    imgm.is_default AS is_modifier_default,
    mg.min_selection as min_quantity,
    mg.max_selection as max_quantity,
    m.allow_quantity_increment,
    m.increment_step,
    m.modifier_default_quantity,
    m.is_invisible AS is_modifier_invisible,
    m.calories,
    m.is_modifier_active,
    m.is_modifier_deleted,
    lmi.x_times_added_on_to_the_item,
    lma.mdfr_selection_frequency_within_loc_and_week,
    ROUND(
        100 * CAST(lmi.x_times_added_on_to_the_item AS NUMERIC(9,3))
        / lma.mdfr_selection_frequency_within_loc_and_week,
        3
    ) AS pct_relative_selection_frequency
FROM dim.item_modifier_group_modifier_mapping AS imgm
INNER JOIN org_loc_ctlg_modifiers AS m
    ON imgm.catalogid = m.catalogid
   AND imgm.modifierid = m.modifierid
INNER JOIN dim.menuitem AS mi
    ON imgm.menuitemid = mi.menuitemid
INNER JOIN dim.modifier_group as mg
    ON imgm.catalogid = mg.catalogid
    AND imgm.modifiergroupid = mg.modifiergroupid
LEFT JOIN loc_mdfr_itm AS lmi
    ON m.organizationid = lmi.organizationid
   AND m.locationid = lmi.locationid
   AND imgm.modifierid = lmi.modifierid
   AND imgm.menuitemid = lmi.menuitemid
LEFT JOIN loc_mdfr_agg AS lma
    ON m.organizationid = lma.organizationid
   AND m.locationid = lma.locationid
   AND imgm.modifierid = lma.modifierid;