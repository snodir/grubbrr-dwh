--tables to be checked before migration

CALL fact.usp_prod_to_stage_migration_audit();

SELECT *
FROM fact.prod_to_stage_migration_audit
WHERE 1=1
  AND table_name NOT IN ('userlocation','pos_sales_details','device','weather','stage_watermark','peripheral','prod_to_stage_migration_audit','company','datedim','weather','menuentities','menuentities_0912','holidays','prod_to_stage_migration_audit_bkp','location_statistics','duplicate_items_master','userbehaviour','deviceevent')
  --AND sysupdatetime_after_migration is NULL
  --AND table_name IN ('userlocation','pos_sales_details')
ORDER BY dependency_level, 
         dependency_count, 
         table_schema, table_name;
/*
TRUNCATE TABLE dim.menuitem;
TRUNCATE TABLE dim.category_hierarchy;
TRUNCATE TABLE dim.catalog;
TRUNCATE TABLE dim.modifier;
TRUNCATE TABLE dim.modifier_group_mapping;
*/

SELECT * 
FROM dim.category_hierarchy



SELECT *
FROM fact.prod_to_stage_migration_audit_bkp

