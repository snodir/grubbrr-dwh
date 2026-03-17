WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (CASE WHEN 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269'
      AND ol.organizationtype = 0
), order_items AS (
    SELECT ti.*, ic.categoryid as dimcategoryid, ic.categoryname
    FROM (
        SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.* 
        FROM fact.transactionitem AS ti
        INNER JOIN org_loc_lookup as ol
			ON ti.locationid = ol.locationid
        WHERE 1=1
          AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
          AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = 2025
          AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = 30
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
    max(itemunitprice) as itemunitprice
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
	INNER JOIN org_loc_lookup as ol
			ON ctgh.locationid = ol.locationid
    WHERE (EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER = 2025 AND EXTRACT(WEEK FROM mi.gms_created_on)::INTEGER <= 30)
            OR 
            (EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER < 2025)
)
SELECT DISTINCT
    mi.organizationid,
    mi.organizationname,
    COALESCE(mi.locationid, ti.locationid) as locationid,
    2025::INTEGER AS yyyy,
    30::INTEGER AS ww,
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


--SELECT count(*) FROM dim.menuitem as mi WHERE mi.itemunitprice is not null

SELECT *
FROM dim.menuitem as m
WHERE 1=1
  AND m.itemunitprice is NULL
  AND m.sysupdatetime IS NOT NULL
LIMIT 100

