SELECT DISTINCT ct.organization_id, 
  CASE ct.organization_id WHEN 'org-0281beee-a2f2-46fb-ac88-cc20df85fbfc' THEN 'BurgerFi'
                          WHEN 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269' THEN 'Bojangles'
                          WHEN 'org-7bd17b79-edd7-48bf-b655-dd2fbb1650a7' THEN 'Wienerschnitzel' END as organization_name,
       im.id as menu_item_id,
       'Item' as item_type,
       im.name as menu_item_name,
       im.display_name,
       im.description,
       im.calories,
       cm.name as category_name       
FROM public.item_master as im 
INNER JOIN public.catalog as ct  --to get OrganizationID
        ON im.catalog_id = ct.id
INNER JOIN public.category_displayable_item as cdi --to get Item-to-Ctg mapping and from there CategoryID
        ON im.id = cdi.item_master_id 
       AND im.catalog_id = cdi.catalog_id
INNER JOIN public.category_master as cm  --to get CategoryName
        ON cdi.category_master_id = cm.id 
WHERE ct.organization_id in ('org-7bd17b79-edd7-48bf-b655-dd2fbb1650a7',
                             'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269',
                             'org-0281beee-a2f2-46fb-ac88-cc20df85fbfc')
  AND im.is_active = True 
  AND im.is_deleted = False

UNION

SELECT DISTINCT ct.organization_id, 
  CASE ct.organization_id WHEN 'org-0281beee-a2f2-46fb-ac88-cc20df85fbfc' THEN 'BurgerFi'
                          WHEN 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269' THEN 'Bojangles'
                          WHEN 'org-7bd17b79-edd7-48bf-b655-dd2fbb1650a7' THEN 'Wienerschnitzel' END as organization_name,
       cbm.id as menu_item_id,
       'Combo' as item_type,
       cbm.name as menu_item_name,
       cbm.display_name,
       cbm.description,
       cbm.calories,
       cm.name as category_name       
FROM public.combo_master as cbm 
INNER JOIN public.catalog as ct  --to get OrganizationID
        ON cbm.catalog_id = ct.id
INNER JOIN public.category_displayable_item as cdi --to get Item-to-Ctg mapping and from there CategoryID
        ON cbm.id = cdi.combo_id 
       AND cbm.catalog_id = cdi.catalog_id
INNER JOIN public.category_master as cm  --to get CategoryName
        ON cdi.category_master_id = cm.id 
WHERE ct.organization_id in ('org-7bd17b79-edd7-48bf-b655-dd2fbb1650a7',
                             'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269',
                             'org-0281beee-a2f2-46fb-ac88-cc20df85fbfc')
  AND cbm.is_active = True 
  AND cbm.is_deleted = False

SELECT *-- count(*)
FROM public.pricebook --13,532,902
WHERE 1=1 
  AND item_id IS NOT NULL
  AND is_active = True 
  AND is_deleted = False 
  AND modified_on IS NOT NULL
ORDER BY modified_on DESC
LIMIT 100

SELECT *
FROM public.pricebook_item --1,260,634
WHERE 1=1 
  AND item_id IS NOT NULL
  AND is_active = True 
  AND is_deleted = False 
  AND modified_on IS NOT NULL
ORDER BY modified_on DESC
LIMIT 1000


/*
SELECT * FROM public.category_displayable_item as cdi LIMIT 100
SELECT * FROM public.category_master as cm LIMIT 100
SELECT * FROM public.combo_master as cmb LIMIT 100

org-7bd17b79-edd7-48bf-b655-dd2fbb1650a7	Wienerschnitzel
org-5cf80db5-7a28-4dcf-846b-8cdf5f362269	Bojangles
org-0281beee-a2f2-46fb-ac88-cc20df85fbfc	BurgerFi

itemId, itemType, itemName, displayName, description, calories, categoryName
SELECT * FROM public.item_master LIMIT 100;
SELECT * FROM public.item_master_bojangle LIMIT 100
SELECT * FROM public.item_master_wiener LIMIT 100
SELECT * FROM public.item_master LIMIT 100
SELECT * FROM public.catalog as ct
WHERE ct.organization_id in ('org-7bd17b79-edd7-48bf-b655-dd2fbb1650a7',
'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269',
'org-0281beee-a2f2-46fb-ac88-cc20df85fbfc') 
LIMIT 100
*/
