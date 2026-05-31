SELECT DISTINCT isc.table_schema, isc.table_name
FROM information_schema.columns as isc 
WHERE isc.table_schema IN ('dim','fact','stg')
ORDER BY isc.table_schema, isc.table_name--, isc.ordinal_position

SELECT *
FROM dim.businessdate
ORDER BY dateid DESC 
LIMIT 100

WITH unique_records AS (
SELECT *, ROW_NUMBER() OVER(PARTITION BY table_schema, table_name ORDER BY table_schema, table_name) as rn
FROM etl.gas_db_object_dependency_sort
WHERE 1=1
  --AND table_name NOT IN ('userlocation','device','weather','stage_watermark','peripheral','prod_to_stage_migration_audit','company','datedim','weather','menuentities','menuentities_0912','holidays','prod_to_stage_migration_audit_bkp','location_statistics','duplicate_items_master','item_modifier_group_modifier_mapping','userbehaviour','deviceevent')
  --AND sysupdatetime_after_migration is NULL ,'userbehaviour','deviceevent','userlocation',
  --AND table_name IN ('occasionsurvey','userbehaviour','deviceevent')
)
SELECT *
FROM unique_records
WHERE rn = 1
ORDER BY dependency_level, 
         dependency_count, 
         table_schema, table_name;