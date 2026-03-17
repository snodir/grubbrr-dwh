WITH org_loc_lookup AS (
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        ol.locationid,
        ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE ol.organizationid IN (
        SELECT DISTINCT organizationid
        FROM dim.organizationlocation AS ol
        WHERE (CASE WHEN 'org-d54ec735-238b-454f-ba73-6ec9d3a7a955' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'org-d54ec735-238b-454f-ba73-6ec9d3a7a955'
          AND ol.organizationtype = 0
    )
), trxn_modifiers as (
    SELECT ol.organizationid, ol.organizationname, ol.locationname,
           ti.locationid, ti.businessdate, ti.orderdatelocal, ti.dimmenuitemid,
           m.*
    FROM fact.itemmodifier as m 
    INNER JOIN fact.transactionitem as ti 
            ON m.transactionheaderid = ti.transactionheaderid
           AND m.itemid = ti.itemid
    INNER JOIN org_loc_lookup as ol 
            ON ti.locationid = ol.locationid
    WHERE 1=1
      AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
      AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = 2025
      AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = 30
), org_mdfr_agg as (
	SELECT organizationid, modifierid, 
    count(*) as mdfr_selection_frequency_within_org_and_week,
    max(modifierprice) as modifierprice
	FROM trxn_modifiers
	GROUP BY organizationid, modifierid
), org_mdfr_itm as (
	SELECT organizationid, modifierid, dimmenuitemid,
    count(*) as x_times_added_on_to_the_item,
    row_number() over(PARTITION BY organizationid, modifierid ORDER BY count(*) DESC) as mdfr_selection_ranking
    --max(modifierprice) as modifierprice
	FROM trxn_modifiers
	GROUP BY organizationid, modifierid, dimmenuitemid
), loc_mdfr_agg as (
	SELECT organizationid, locationid, modifierid, 
    count(*) as mdfr_selection_frequency_within_loc_and_week,
    max(modifierprice) as modifierprice
	FROM trxn_modifiers
	GROUP BY organizationid, locationid, modifierid
), loc_mdfr_itm as (
	SELECT organizationid, locationid, modifierid, dimmenuitemid,
    count(*) as x_times_added_on_to_the_item,
    row_number() over(PARTITION BY organizationid, locationid, modifierid ORDER BY count(*) DESC) as mdfr_selection_ranking
    --max(modifierprice) as modifierprice
	FROM trxn_modifiers
	GROUP BY organizationid, locationid, modifierid, dimmenuitemid
), loc_mdfr_itm_agg as (
	SELECT lmi.organizationid, lmi.locationid, lmi.modifierid, 
    jsonb_agg(
        jsonb_build_object(
            'menuitemid', lmi.dimmenuitemid,
            'item_class_type', mi.item_class_type,
            'x_times_added_on_to_the_item', lmi.x_times_added_on_to_the_item,
            'pct_relative_selection_frequency', 100 * lmi.x_times_added_on_to_the_item / lma.mdfr_selection_frequency_within_loc_and_week,
            'modifier_selection_ranking', lmi.mdfr_selection_ranking
        ) ORDER BY mdfr_selection_ranking
    ) as loc_modifier_popularity
	FROM loc_mdfr_itm as lmi 
    LEFT JOIN loc_mdfr_agg as lma 
           ON lmi.organizationid = lma.organizationid 
          AND lmi.locationid = lma.locationid 
          AND lmi.modifierid = lma.modifierid
    LEFT JOIN dim.menuitem as mi 
           ON lmi.dimmenuitemid = mi.menuitemid
	GROUP BY lmi.organizationid, lmi.locationid, lmi.modifierid
), org_mdfr_itm_agg as (
	SELECT omi.organizationid, omi.modifierid, 
    jsonb_agg(
        jsonb_build_object(
            'menuitemid', omi.dimmenuitemid,
            'item_class_type', mi.item_class_type,
            'x_times_added_on_to_the_item', omi.x_times_added_on_to_the_item,
            'pct_relative_selection_frequency', 100 * omi.x_times_added_on_to_the_item / oma.mdfr_selection_frequency_within_org_and_week,
            'modifier_selection_ranking', omi.mdfr_selection_ranking
        ) ORDER BY mdfr_selection_ranking
    ) as org_modifier_popularity
	FROM org_mdfr_itm as omi 
    LEFT JOIN org_mdfr_agg as oma 
           ON omi.organizationid = oma.organizationid 
          AND omi.modifierid = oma.modifierid
    LEFT JOIN dim.menuitem as mi 
           ON omi.dimmenuitemid = mi.menuitemid
	GROUP BY omi.organizationid, omi.modifierid
)
SELECT DISTINCT 
    ol.organizationid,
    ol.organizationname,
    ol.locationid,
    ol.locationname,
    m.catalogid,
    ctlg.catalogname,
    mg.modifiergroupid,
    m.modifierid,
    m.modifiername,
    m.classification as modifier_class_type,
    m.min_quantity,
    m.max_quantity,
    m.allow_quantity_increment,
    m.calories_text,
    m.is_modifier_default,
    m.modifier_default_quantity,
    m.is_invisible,
    COALESCE(m.price, lma.modifierprice) as modifierprice,
    lmia.loc_modifier_popularity,
    omia.org_modifier_popularity
FROM dim.modifier as m 
LEFT JOIN dim.modifier_group_mapping as mg
        ON m.modifierid = mg.modifierid
LEFT JOIN dim.catalog as ctlg 
        ON m.catalogid = ctlg.catalogid
INNER JOIN org_loc_lookup as ol 
        ON ctlg.gem_company_id = ol.organizationid
       AND ctlg.gem_location_id = ol.locationid
LEFT JOIN  loc_mdfr_agg as lma 
        ON ol.organizationid = lma.organizationid
       AND ol.locationid = lma.locationid
       AND m.modifierid = lma.modifierid
LEFT JOIN  loc_mdfr_itm_agg as lmia 
        ON ol.organizationid = lmia.organizationid
       AND ol.locationid = lmia.locationid
       AND m.modifierid = lmia.modifierid
LEFT JOIN  org_mdfr_itm_agg as omia 
        ON ol.organizationid = omia.organizationid
       AND m.modifierid = omia.modifierid
WHERE (EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER = 2025 AND EXTRACT(WEEK FROM m.modifier_created_on)::INTEGER <= 30)
            OR 
      (EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER < 2025)

SELECT ol.*, ctlg.*
FROM dim.CATALOG as ctlg 
INNER JOIN (
        SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        ol.locationid,
        ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE ol.organizationid IN (
        SELECT DISTINCT organizationid
        FROM dim.organizationlocation AS ol
        WHERE (CASE WHEN 'org-d54ec735-238b-454f-ba73-6ec9d3a7a955' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'org-d54ec735-238b-454f-ba73-6ec9d3a7a955'
          AND ol.organizationtype = 0
    )
) as ol 
        ON ctlg.gem_location_id = ol.locationid


SELECT c.*, mg.*
FROM dim.modifier_group_mapping as mg 
INNER JOIN dim.catalog  as c 
        ON mg.catalogid = c.catalogid
WHERE 1=1
  --AND c.organizationid = 'org-d54ec735-238b-454f-ba73-6ec9d3a7a955' --78,446
  AND c.gem_company_id = 'org-d54ec735-238b-454f-ba73-6ec9d3a7a955' --78,446

SELECT count(*) as row_count, --2,178
       sum(CASE WHEN organizationid IS NULL or organizationid = '' THEN 0 ELSE 1 END) as org_count, --2,178
       sum(CASE WHEN gem_company_id IS NULL or gem_company_id = '' THEN 0 ELSE 1 END) as gem_org_count, --1,614
       sum(CASE WHEN gem_location_id IS NULL or gem_location_id = '' THEN 0 ELSE 1 END) as gem_loc_count --1,614
FROM dim.catalog

/* ctlg.gem_company_id = ol.organizationid
       AND 
SELECT * FROM fact.transactionheader 
WHERE transactionheaderid = 'ordevt-ivspdkhf2p' 
LIMIT 100;

SELECT * FROM fact.transactionitem 
WHERE transactionheaderid = 'ordevt-ivspdkhf2p' 
LIMIT 100;

SELECT * FROM fact.itemmodifier LIMIT 100;
--78433	ordevt-0cusxbv64z	ord-20D822DEB9C9	loc-9dd1eaea-e264-4d51-bffb-1abdc65e3fff	ksk-14821756	9EE2FEE1FAFA4027	2025102313	2025-10-23 17:53:55.948	2025-10-23 13:53:55.948	order-placed	2058	2	1	0.000	5.290	5.660	0.370	0.000	0.000	0.000	Paid	NGE	2025-10-27 09:08:00.873828	2026-02-02 15:50:46.940355	NULL	NULL	NULL	NULL	NULL	0.000	0.000	0.000	0.000	0.000	0.000	2025-10-23	NULL	NULL	Kiosk	1	0.000	1761242036	1	0.000	NULL

SELECT *
FROM fact.transactionitem as ti 
WHERE ti.transactionheaderid LIKE 'ordevt-%'
LIMIT 100

SELECT ti.locationid, ti.businessdate, ti.orderdatelocal, ti.dimmenuitemid,
       m.*
FROM fact.itemmodifier as m 
INNER JOIN fact.transactionitem as ti 
    ON m.transactionheaderid = ti.transactionheaderid
    AND m.itemid = ti.itemid
--WHERE ti.orderdatelocal IS not null 
ORDER BY ti.orderdatelocal DESC
LIMIT 100;


SELECT COUNT(DISTINCT m.modifierid) --2,920
FROM fact.itemmodifier as m 
--GROUP BY 

SELECT c.catalogid, c.organizationid, c.gem_location_id, -- COUNT(*) --868,993
       m.*
FROM dim.modifier as m 
INNER JOIN dim.catalog as c 
    ON m.catalogid = c.catalogid
LIMIT 100

SELECT *-- COUNT(*) --868,993
FROM dim.catalog as c
ORDER BY c.catalog_created_on DESC
LIMIT 100;*/