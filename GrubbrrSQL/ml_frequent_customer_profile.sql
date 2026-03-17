SELECT fc.frequentcustomerid, 
       fc.organizationid,
       th.locationid, 
       ti.dimmenuitemid,
       count(*) x_times_selected
FROM dim.frequentcustomer as fc 
INNER JOIN fact.transactionheader as th 
        ON fc.frequentcustomerid = th.frequentcustomerid
INNER JOIN fact.transactionitem as ti 
        ON th.locationid = ti.locationid 
       AND th.transactionheaderid = ti.transactionheaderid
GROUP BY fc.frequentcustomerid, 
         fc.organizationid,
         th.locationid, 
         ti.dimmenuitemid
ORDER BY fc.frequentcustomerid, x_times_selected DESC
LIMIT 1000


SELECT 
    frequentcustomerid,
    jsonb_agg(
        jsonb_build_object(
            'organizationid', organizationid,
            'locationid', locationid,
            'menuitemid', dimmenuitemid,
            'x_times_selected', x_times_selected
        ) ORDER BY x_times_selected DESC
    ) AS menu_selections
FROM (
    SELECT 
        fc.frequentcustomerid, 
        fc.organizationid, 
        th.locationid, 
        ti.dimmenuitemid, 
        count(*) as x_times_selected 
    FROM dim.frequentcustomer as fc 
    INNER JOIN fact.transactionheader as th 
        ON fc.frequentcustomerid = th.frequentcustomerid 
    INNER JOIN fact.transactionitem as ti 
        ON th.locationid = ti.locationid 
        AND th.transactionheaderid = ti.transactionheaderid 
    GROUP BY fc.frequentcustomerid, fc.organizationid, th.locationid, ti.dimmenuitemid
) AS subquery
GROUP BY frequentcustomerid
ORDER BY frequentcustomerid;



/******item_class_type******
0=Undefined
1=Main
2=Side
3=Drink
4=Dessert
5=Meal
6=Other
*/

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
        


SELECT *
FROM fact.recommendations as rec
WHERE rec.selecteditems <> '[]'::jsonb
LIMIT 1000


selecteditems
SELECT th.frequentcustomerid, oa.selecteditem, count(*) as x_times_selected
FROM fact.vw_offer_analysis as oa 
INNER JOIN (SELECT * FROM fact.transactionheader WHERE frequentcustomerid IS NOT NULL) as th 
        ON oa.locationid = th.locationid
       AND oa.transactionheaderid = th.transactionheaderid
WHERE 1=1 
AND oa.selecteditem IS NOT NULL
GROUP BY th.frequentcustomerid, oa.selecteditem
ORDER BY x_times_selected DESC
LIMIT 1000





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