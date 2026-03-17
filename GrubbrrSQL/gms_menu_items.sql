SELECT id, category_master_id,item_master_id,item_variation_id
,pre_selected_combo_id,sub_category_id,combo_id,display_order
,is_active,is_deleted,created_on,modified_on,combo_family_id
,catalog_id,pos_linked_entity_id,pos_sync_enable,pos_overrided_fields
,created_by,modified_by,source
FROM public.category_displayable_item as ci
WHERE ci.category_master_id = 'cat-20b466fb-8605-4817-8617-02f91a5dde30'
LIMIT 5;
--cat-20b466fb-8605-4817-8617-02f91a5dde30 --itm-ac3e05b8-4d03-4de0-afc5-b142abed5883
--cat-03284fc5-285b-4f09-a13e-c417af5f125b

SELECT *
FROM public.catalog 
LIMIT 5;

SELECT DISTINCT
       ctlg.id as catalogid, 
       ctlg.name as catalogname, 
       ctlg.organization_id as organizationid, 
       ctlg.gem_location_id as locationid,
       ctlg.is_ecm_enabled, 
       ci.is_active as is_mapping_active, 
       ci.is_deleted as is_mapping_deleted, 
       ci.created_on as mapping_created_on, 
       ci.modified_on as mapping_modified_on,
       ctlg.is_deleted as is_catalog_deleted, 
       ctlg.created_on as catalog_created_on, 
       ctlg.modified_on as catalog_modified_on,
       ci.category_master_id as categoryid, 
       ctg.name as categoryname, 
       ctg.created_on as category_created_on,
       ctg.modified_on as category_modified_on,
       ctg.is_active as is_category_active,
       ctg.is_deleted as is_category_deleted,
       ci.item_master_id as menuitemid, 
       i.name as menuitemname,
       i.item_class_type,
       i.created_on as item_created_on,
       i.modified_on as item_modified_on, 
       i.is_active as is_item_active,
       i.is_deleted as is_item_deleted
FROM public.category_displayable_item as ci
INNER JOIN public.catalog as ctlg 
        ON ci.catalog_id = ctlg.id
INNER JOIN public.category_master as ctg
        ON ci.category_master_id = ctg.id
INNER JOIN public.item_master as i
        ON ci.item_master_id = i.id
WHERE 1=1
  AND ctlg.gem_location_id IS NOT NULL
  AND ctlg.gem_location_id <> ''
  AND ci.item_master_id = 'itm-04d5e110-f73a-487f-bb75-054fe07d21bf'
  AND ci.is_active = True
  AND ci.is_deleted = False
  AND ctlg.is_deleted = False 
  AND ctg.is_active = True 
  AND ctg.is_deleted = False
  AND i.is_active = True
  AND i.is_deleted = False
LIMIT 1000;

SELECT ci.catalog_id, ci.item_master_id,
       count(*) over(PARTITION BY ci.catalog_id, ci.item_master_id) as dupl, *
FROM public.category_displayable_item as ci
WHERE ci.item_master_id IS NOT NULL
ORDER BY dupl DESC, ci.item_master_id
LIMIT 1000

SELECT count(*)
from public.category_displayable_item; --648,953


SELECT DISTINCT 
       ci.category_master_id as categoryid,
       ci.item_master_id as menuitemid,
       ci.sub_category_id as subcategoryid,
       ci.is_active as isactive,
       ci.is_deleted as isdeleted,
       ci.modified_on as modifiedon
FROM public.category_displayable_item as ci



select count(DISTINCT gem_location_id)--id, "name", organization_id, is_deleted, gem_company_id, gem_location_id,       count(*) over(partition by organization_id) as org_count
from public.catalog 
where 1=1 AND gem_location_id <> '' 
and gem_location_id is not NULL --1,590AllLocs===1,233DistinctLocs
--group by catalogid
--order by count(*) over(partition by organization_id) desc
limit 1000;

SELECT DISTINCT 
       cdi.category_master_id as categoryid, 
       cdi.item_master_id as menuitemid,
       cdi.sub_category_id as subcategoryid,
       cdi.is_active as isactive,
       cdi.is_deleted as isdeleted,
       cdi.modified_on as modifiedon
FROM public.category_displayable_item as cdi
LIMIT 1000

SELECT *--
FROM public.category_displayable_item as cdi
--INNER JOIN public.catalog as ctlg
WHERE 1=1
--AND combo_id is NOT NULL
AND item_master_id = 'itm-c93a6fd3-83ff-4f40-9a56-cc1d99443d32'-- IS NOT NULL
LIMIT 1000

SELECT cdi.item_master_id, count(*) as dupl
FROM public.category_displayable_item as cdi
GROUP BY cdi.item_master_id
HAVING count(*)>1
ORDER BY dupl DESC

SELECT *
FROM public.pricebook
LIMIT 1000



INNER JOIN public.catalog as ctlg 

SELECT *
FROM public.catalog as cdi
LIMIT 1000

SELECT *-- cdi.catalog_id, lower(cdi.name) as item_name, count(*)-- count(*) --T*739,667===S*145,710
FROM public.item_master as cdi
WHERE 1=1
--AND calories is not null and calories <> ''
--GROUP BY cdi.catalog_id, lower(cdi.name)
--HAVING count(*) > 1
LIMIT 1000;

SELECT *
FROM public.menu_dataset_overrides
LIMIT 1000


SELECT count(*) --T*147,577===S*5,359
FROM public.combo_master as cdi
LIMIT 1000

SELECT *--count(*) --T*766,205
FROM public.category_displayable_item as cdi
WHERE cdi.item_master_id IS NOT NULL
ORDER BY cdi.item_master_id
LIMIT 1000


SELECT *--count(*) --T*147,577===S*5,359
FROM public.category_master as cdi
where id in ('cat-826da139-3762-4edf-b02b-f534c49e129f',
'cat-b3022088-40d0-416d-8f4d-f35ade2ba443',
'cat-e837af29-6894-40e3-b220-a142517d0c40',
'cat-cfc9325e-c365-4c59-95ff-67eb1ba35f07',
'cat-091fbc0c-5b40-48e0-8908-f8ad5a2cff64'
)
LIMIT 1000

SELECT *
FROM information_schema.columns as isc 
WHERE isc.COLUMN_name like '%location%'

SELECT max(price), min(price), count(*)
FROM public.pricebook

select *-- count(*) 
from public.combo_master --138,092
WHERE is_active = True AND is_deleted = False
order by modified_on desc
limit 1000;

WITH latest_price AS (
SELECT item_id, max(modified_on) as max_modified_on
FROM public.pricebook
WHERE 1=1 
  AND item_id IS NOT NULL-- = 'itm-4e60cfc5-e296-48d7-ac44-a45a73adb68a'-- 
  --AND modified_on IS NOT NULL
GROUP BY item_id
)
SELECT im.id as menuitemid, 
       im.name as menuitemname, 
       'Item' as entitytype,
       im.calories :: text as calories,
       NULL :: numeric as protein,
       NULL :: numeric as sugar,
       NULL :: numeric as fat,
       im.is_alcoholic,
       NULL :: boolean as is_vegetarian_item,
       NULL :: boolean as is_vegan_item,
       NULL :: boolean as has_allergen,
       im.item_class_type,
       im.is_active,
       im.is_deleted,
       im.created_on as gms_created_on,
       im.modified_on as gms_modified_on,
       pb.price :: NUMERIC(16,4) / 100 as itemunitprice, 
       pb.modified_on as price_changed_on
FROM public.item_master as im
LEFT JOIN latest_price as lp
       ON im.id = lp.item_id
LEFT JOIN public.pricebook as pb
       ON lp.item_id = pb.item_id
      AND lp.max_modified_on = pb.modified_on
WHERE is_active = True AND is_deleted = False --585,903

UNION ALL

SELECT DISTINCT id as comboid, 
       name as comboname, 
       'Combo' as entitytype,
       calories :: text as calories,
       NULL :: numeric as protein,
       NULL :: numeric as sugar,
       NULL :: numeric as fat,
       NULL :: boolean as is_alcoholic,
       NULL :: boolean as is_vegetarian_item,
       NULL :: boolean as is_vegan_item,
       NULL :: boolean as has_allergen,
       NULL :: integer as item_class_type,
       is_active,
       is_deleted,
       created_on as gms_created_on,
       modified_on as gms_modified_on
       NULL :: NUMERIC(16,4) as itemunitprice,
       NULL :: TIMESTAMP as price_changed_on 
from public.combo_master
WHERE is_active = True AND is_deleted = False --585,903
order by modified_on desc
limit 1000;


SELECT *-- count(*)
FROM public.pricebook --13,532,902
WHERE 1=1 
  AND item_id = 'itm-4e60cfc5-e296-48d7-ac44-a45a73adb68a'-- IS NOT NULL
  AND is_active = True 
  AND is_deleted = False 
  AND modified_on IS NOT NULL
ORDER BY modified_on DESC
LIMIT 100


WITH latest_price AS (
SELECT item_id, max(modified_on) as max_modified_on
FROM public.pricebook
WHERE 1=1 
  AND item_id IS NOT NULL-- = 'itm-4e60cfc5-e296-48d7-ac44-a45a73adb68a'-- IS NOT NULL
  AND is_active = True 
  AND is_deleted = False 
  --AND modified_on IS NOT NULL
GROUP BY item_id
)
SELECT count(1)
FROM latest_price as lp
INNER JOIN public.pricebook as pb
        ON lp.item_id = pb.item_id
       AND lp.max_modified_on = pb.modified_on




select count(*) 
from public.category_master --394,739
WHERE is_active = True AND is_deleted = False
order by modified_on desc
limit 1000;

select id, count(*) -- 
from public.catalog --1,182T --no dupl
group by id

select count(*) over(PARTITION by organization_id) as ctl_count_by_org,
*--organization_id, count(distinct id) -- 
from public.catalog --1,182T --167 dist.Orgs
where 1=1
--and organization_id = 'com-3aeuuijrb2'
--and id = 'catlg-83282977-fb26-45f4-8044-a0f0659c0d2a'
order by organization_id

group by organization_id