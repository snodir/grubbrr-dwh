/*
public enum ModifierClassificationType
{
    Undefined = 0,
    Protein = 1,
    Side = 2,
    Cheese = 3,
    Topping = 4,
    Sauce = 5,
    Size = 6,
    Prep = 7,
    Other = 8
}
*/

--catalog
SELECT c.id as catalogid,
       c.name as catalogname,
       c.organization_id as organizationid,
       c.is_deleted as is_catalog_deleted,
       c.created_on as catalog_created_on,
       c.modified_on as catalog_modified_on,
       c.gem_company_id,
       c.gem_location_id,
       c.sync_in_progress as is_sync_in_progress,
       c.is_standalone,
       c.is_master,
       c.is_ecm_enabled
FROM public.catalog as c
WHERE c.organization_id <> c.gem_company_id
  AND c.gem_company_id <> ''


--modifiers
SELECT mm.id as modifierid,
       mm.catalog_id as catalogid,
       mm.name as modifiername,
       mm.min_quantity,
       mm.max_quantity,
       mm.allow_quantity_increment,
       mm.increment_step,
       mm.calories,
       mm.is_active as is_modifier_active,
       mm.is_deleted as is_modifier_deleted,
       mm.created_on as modifier_created_on,
       mm.modified_on as modifier_modified_on,
       mm.is_default as is_modifier_default,
       mm.default_quantity as modifier_default_quantity,
       mm.is_invisible,
       mm.classification,
       NULL :: numeric(12,3) as price
FROM public.modifier_master as mm
ORDER BY mm.id
LIMIT 100;




SELECT mg.id as modifier_mapping_id,
       mg.modifier_master_id as modifierid,
       mg.modifier_group_master_id as modifiergroupid,
       mg.catalog_id as catalogid,
       mg.is_active as is_mapping_active,
       mg.is_deleted as is_mapping_deleted,
       mg.created_on as mapping_created_on,
       mg.modified_on as mapping_modified_on,
       mg.is_default,
       mg.default_quantity,
       mg.allow_quantity_increment,
       mg.increment_step,
       mg.min_quantity,
       mg.max_quantity,
       mg.calories_text,
       mg.is_invisible
FROM public.modifier_group_modifier_glue as mg
ORDER BY mg.modifier_group_master_id
LIMIT 100;


SELECT DISTINCT isc.table_name, isc.column_name, isc.ordinal_position
FROM information_schema.columns as isc
WHERE 1=1
  AND isc.table_name like '%modifier%'
  AND isc.column_name like '%%'
ORDER BY isc.table_name, isc.ordinal_position

SELECT mg.modifier_master_id, count(*)
FROM public.modifier_group_modifier_glue as mg --867,169
GROUP BY mg.modifier_master_id
--ORDER BY mg.modifier_group_master_id
HAVING count(*) > 1
LIMIT 100;

SELECT *--count(*)-- *
FROM public.catalog as mg --2,168
--ORDER BY mg.modifier_group_master_id
LIMIT 1000;





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