WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname, 
           ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (CASE WHEN 'com-3owh66znkd' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'com-3owh66znkd'
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
    ) as ti
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