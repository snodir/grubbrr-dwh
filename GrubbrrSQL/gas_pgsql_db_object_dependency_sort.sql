ALTER TABLE fact.prod_to_stage_migration_audit
ADD COLUMN IF NOT EXISTS sql_source_query text COLLATE pg_catalog."default";

--DELETE FROM fact.prod_to_stage_migration_audit WHERE table_name in ('prod_to_stage_migration_audit_bkp','company')

CALL fact.usp_prod_to_stage_migration_audit();

WITH unique_records AS (
SELECT *, ROW_NUMBER() OVER(PARTITION BY table_schema, table_name ORDER BY table_schema, table_name) as rn
FROM fact.prod_to_stage_migration_audit
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


ALTER TABLE fact.prod_to_stage_migration_audit
ADD COLUMN IF NOT EXISTS sql_source_query text COLLATE pg_catalog."default";
         
CREATE OR REPLACE PROCEDURE fact.usp_prod_to_stage_migration_audit()
LANGUAGE plpgsql
AS $BODY$
BEGIN

DROP TABLE IF EXISTS temp_prod_to_stage_migration_audit;

CREATE TEMPORARY TABLE IF NOT EXISTS temp_prod_to_stage_migration_audit(
    table_schema text COLLATE pg_catalog."default",
    table_name text COLLATE pg_catalog."default",
    key_columns jsonb,
    key_type text COLLATE pg_catalog."default",
    key_column_data_types jsonb,
    dependency_level INTEGER,
    dependency_count INTEGER,
    depends_on jsonb,
    referenced_by jsonb,  -- NEW COLUMN
    insert_watermark text COLLATE pg_catalog."default",
    insert_watermark_data_type text COLLATE pg_catalog."default",
    update_watermark text COLLATE pg_catalog."default",
    update_watermark_data_type text COLLATE pg_catalog."default",
    sql_aggregate text COLLATE pg_catalog."default"
);

WITH RECURSIVE watermark_columns AS (
    SELECT DISTINCT
        COALESCE(it.table_schema, ut.table_schema) as table_schema, 
        COALESCE(it.table_name, ut.table_name) as table_name, 
        it.column_name as insert_watermark, 
        it.data_type as insert_watermark_type,
        ut.column_name as update_watermark, 
        ut.data_type as update_watermark_type
    FROM
        (SELECT 
            n.nspname::text as table_schema,
            c.relname::text as table_name,
            a.attname::text as column_name,
            format_type(a.atttypid, a.atttypmod) as data_type
         FROM pg_catalog.pg_attribute a
         JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
         JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
         WHERE n.nspname IN ('dim','fact')
           AND c.relkind = 'r'
           AND a.attnum > 0 
           AND NOT a.attisdropped
           AND (a.attname LIKE 'create%date%' OR a.attname LIKE 'sys%inserttime' OR a.attname LIKE 'created%on%')
           AND format_type(a.atttypid, a.atttypmod) LIKE '%timestamp%') as it
    FULL OUTER JOIN  
        (SELECT 
            n.nspname::text as table_schema,
            c.relname::text as table_name,
            a.attname::text as column_name,
            format_type(a.atttypid, a.atttypmod) as data_type
         FROM pg_catalog.pg_attribute a
         JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
         JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
         WHERE n.nspname IN ('dim','fact')
           AND c.relkind = 'r'
           AND a.attnum > 0 
           AND NOT a.attisdropped
           AND (a.attname LIKE 'update%date%' OR a.attname LIKE 'sys%updatetime' OR a.attname LIKE 'modified%on%')
           AND format_type(a.atttypid, a.atttypmod) LIKE '%timestamp%') as ut
        ON it.table_schema = ut.table_schema
       AND it.table_name = ut.table_name
),
table_dependencies AS (
    -- Get all base tables in the schema
    SELECT DISTINCT
        n.nspname::text AS table_schema,
        c.relname::text AS table_name
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' -- regular tables only
        AND n.nspname IN ('dim','fact')
        AND n.nspname NOT LIKE 'pg_temp_%'
        AND n.nspname NOT LIKE 'pg_toast_temp_%'
),
foreign_keys AS (
    -- Extract all foreign key relationships using pg_constraint (including cross-schema)
    SELECT DISTINCT
        n1.nspname::text AS referencing_schema,
        c1.relname::text AS referencing_table,
        n2.nspname::text AS referenced_schema,
        c2.relname::text AS referenced_table,
        -- Create a combined identifier for matching
        n1.nspname::text || '.' || c1.relname::text AS referencing_full,
        n2.nspname::text || '.' || c2.relname::text AS referenced_full
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c1 ON con.conrelid = c1.oid
    JOIN pg_catalog.pg_namespace n1 ON c1.relnamespace = n1.oid
    JOIN pg_catalog.pg_class c2 ON con.confrelid = c2.oid
    JOIN pg_catalog.pg_namespace n2 ON c2.relnamespace = n2.oid
    WHERE con.contype = 'f' -- foreign key constraints
        AND n1.nspname IN ('dim','fact')
),
dependency_graph AS (
    -- Build the complete dependency graph (including cross-schema dependencies)
    SELECT DISTINCT
        td.table_schema,
        td.table_name,
        td.table_schema || '.' || td.table_name AS full_table_name,
        COALESCE(array_agg(DISTINCT fk.referenced_full) 
            FILTER (WHERE fk.referenced_full IS NOT NULL), ARRAY[]::text[]) AS depends_on
    FROM table_dependencies td
    LEFT JOIN foreign_keys fk 
        ON td.table_schema || '.' || td.table_name = fk.referencing_full
    GROUP BY td.table_schema, td.table_name
),
reverse_dependency_graph AS (
    -- NEW CTE: Build reverse dependencies (which tables reference this table)
    SELECT DISTINCT
        td.table_schema,
        td.table_name,
        td.table_schema || '.' || td.table_name AS full_table_name,
        COALESCE(array_agg(DISTINCT fk.referencing_full) 
            FILTER (WHERE fk.referencing_full IS NOT NULL), ARRAY[]::text[]) AS referenced_by
    FROM table_dependencies td
    LEFT JOIN foreign_keys fk 
        ON td.table_schema || '.' || td.table_name = fk.referenced_full
    GROUP BY td.table_schema, td.table_name
),
table_keys AS (
    -- Get Primary Key or Unique Key columns using pg_constraint
    SELECT DISTINCT
        n.nspname::text AS table_schema,
        c.relname::text AS table_name,
        CASE 
            WHEN con.contype = 'p' THEN 'PRIMARY KEY'
            WHEN con.contype = 'u' THEN 'UNIQUE'
        END AS constraint_type,
        to_jsonb(array_agg(a.attname::text ORDER BY array_position(con.conkey, a.attnum))) AS key_columns,
        -- Build JSON object of column:type pairs
        jsonb_object_agg(
            a.attname::text,
            format_type(a.atttypid, a.atttypmod)
        ) AS key_data_types,
        CASE 
            WHEN con.contype = 'p' THEN 1
            WHEN con.contype = 'u' THEN 2
        END AS key_priority
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c ON con.conrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(con.conkey)
    WHERE con.contype IN ('p', 'u') -- primary key or unique
        AND n.nspname IN ('dim','fact')
    GROUP BY n.nspname, c.relname, con.contype, con.conname
),
best_keys AS (
    -- Select the best key for each table (PK preferred over UNIQUE)
    SELECT DISTINCT ON (table_schema, table_name)
        table_schema,
        table_name,
        constraint_type,
        key_columns,
        key_data_types
    FROM table_keys
    ORDER BY table_schema, table_name, key_priority
),
dependency_levels AS (
    -- Level 0: Tables with no dependencies
    SELECT DISTINCT
        dg.table_schema,
        dg.table_name,
        dg.full_table_name,
        0 AS dependency_level,
        dg.depends_on,
        ARRAY[dg.full_table_name] AS dependency_chain,
        bk.key_columns,
        bk.key_data_types,
        bk.constraint_type AS key_type
    FROM dependency_graph dg
    LEFT JOIN best_keys bk
        ON dg.table_schema = bk.table_schema
        AND dg.table_name = bk.table_name
    WHERE cardinality(dg.depends_on) = 0
    
    UNION ALL
    
    -- Recursive: Calculate levels for dependent tables
    SELECT DISTINCT
        dg.table_schema,
        dg.table_name,
        dg.full_table_name,
        dl.dependency_level + 1 AS dependency_level,
        dg.depends_on,
        dl.dependency_chain || dg.full_table_name AS dependency_chain,
        bk.key_columns,
        bk.key_data_types,
        bk.constraint_type AS key_type
    FROM dependency_graph dg
    JOIN dependency_levels dl 
        ON dl.full_table_name = ANY(dg.depends_on)
    LEFT JOIN best_keys bk
        ON dg.table_schema = bk.table_schema
        AND dg.table_name = bk.table_name
    WHERE NOT dg.full_table_name = ANY(dl.dependency_chain) -- Prevent circular dependencies
)

INSERT INTO temp_prod_to_stage_migration_audit
SELECT DISTINCT
    dl.table_schema,
    dl.table_name,
    dl.key_columns,
    dl.key_type,
    dl.key_data_types,
    dl.dependency_level,
    COALESCE(array_length(dl.depends_on, 1), 0) AS dependency_count,
    to_jsonb(dl.depends_on) as depends_on,
    to_jsonb(rdg.referenced_by) as referenced_by,  -- NEW COLUMN
    wc.insert_watermark,
    wc.insert_watermark_type,
    wc.update_watermark,
    wc.update_watermark_type,
    CASE WHEN (dl.key_data_types :: text LIKE '%bigint"}' OR dl.key_data_types :: text LIKE '%integer"}') AND jsonb_array_length(dl.key_columns) = 1
         THEN concat('max(', dl.key_columns ->> 0, ') as max_id, ', 
                      CASE WHEN wc.insert_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.insert_watermark, ')') END, ' as max_insert, ', 
                      CASE WHEN wc.update_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.update_watermark, ')') END, ' as max_update, ', 
                      'count(*) as record_count')
         ELSE concat('NULL as max_id, ', 
                      CASE WHEN wc.insert_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.insert_watermark, ')') END, ' as max_insert, ', 
                      CASE WHEN wc.update_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.update_watermark, ')') END, ' as max_update, ', 
                      'count(*) as record_count')
    END as sql_aggregate
FROM dependency_levels dl
LEFT JOIN watermark_columns wc
    ON dl.table_schema = wc.table_schema
    AND dl.table_name = wc.table_name
LEFT JOIN reverse_dependency_graph rdg  -- NEW JOIN
    ON dl.table_schema = rdg.table_schema
    AND dl.table_name = rdg.table_name
WHERE dl.dependency_level = (
    -- Get the maximum level for each table (in case of multiple paths)
    SELECT MAX(dl2.dependency_level)
    FROM dependency_levels dl2
    WHERE dl2.table_name = dl.table_name
        AND dl2.table_schema = dl.table_schema
);

INSERT INTO fact.prod_to_stage_migration_audit (
    table_schema,
    table_name,
    key_columns,
    key_type,
    key_column_data_types,
    dependency_level,
    dependency_count,
    depends_on,
    referenced_by,  -- NEW COLUMN
    insert_watermark,
    insert_watermark_data_type,
    update_watermark,
    update_watermark_data_type,
    sql_aggregate
)
SELECT * FROM temp_prod_to_stage_migration_audit as tau
WHERE NOT EXISTS (SELECT 1 FROM fact.prod_to_stage_migration_audit as pau 
                  WHERE pau.table_schema = tau.table_schema
                    AND pau.table_name = tau.table_name);

UPDATE fact.prod_to_stage_migration_audit
SET table_schema = tau.table_schema,
    table_name = tau.table_name,
    key_columns = tau.key_columns,
    key_type = tau.key_type,
    key_column_data_types = tau.key_column_data_types,
    dependency_level = tau.dependency_level,
    dependency_count = tau.dependency_count,
    depends_on = tau.depends_on,
    referenced_by = tau.referenced_by,  -- NEW COLUMN
    insert_watermark = tau.insert_watermark,
    insert_watermark_data_type = tau.insert_watermark_data_type,
    update_watermark = tau.update_watermark,
    update_watermark_data_type = tau.update_watermark_data_type,
    sql_aggregate = tau.sql_aggregate
FROM temp_prod_to_stage_migration_audit as tau
WHERE prod_to_stage_migration_audit.table_schema = tau.table_schema
  AND prod_to_stage_migration_audit.table_name = tau.table_name;

UPDATE fact.prod_to_stage_migration_audit
SET sql_source_query = CASE WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NULL AND update_watermark_value IS NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' > ''', insert_watermark_value :: text,
                                        ''' :: TIMESTAMP OR ', update_watermark, ' > ''', update_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' > ''', insert_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', update_watermark, ' > ''', update_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN jsonb_array_length(key_columns) >= 1 AND record_count <= 100000
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            WHEN jsonb_array_length(key_columns) = 1 AND (key_column_data_types :: text LIKE '%bigint"}' OR key_column_data_types :: text LIKE '%integer"}')
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', key_columns ->> 0, ' >= ', COALESCE(watermark_integer_value, 0) :: text)
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' >= ''', insert_watermark_value :: text,
                                        ''' :: TIMESTAMP OR ', update_watermark, ' >= ''', update_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' > ''', insert_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', update_watermark, ' > ''', update_watermark_value :: text, ''' :: TIMESTAMP')                            
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NULL AND update_watermark_value IS NULL AND record_count < 10000000 AND (referenced_by :: text LIKE '[]' OR referenced_by IS NULL)
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            ELSE concat('SELECT * FROM ', table_schema, '.', table_name)
                        END;


DROP TABLE IF EXISTS temp_prod_to_stage_migration_audit;

END;
$BODY$;


CREATE TABLE IF NOT EXISTS public.prod_to_stage_migration_audit
(
    table_schema text COLLATE pg_catalog."default",
    table_name text COLLATE pg_catalog."default",
    key_columns jsonb,
    key_type text COLLATE pg_catalog."default",
    key_column_data_types jsonb,
    dependency_level integer,
    dependency_count integer,
    depends_on jsonb,
    referenced_by jsonb,
    insert_watermark text COLLATE pg_catalog."default",
    insert_watermark_data_type text COLLATE pg_catalog."default",
    update_watermark text COLLATE pg_catalog."default",
    update_watermark_data_type text COLLATE pg_catalog."default",
    insert_watermark_value timestamp without time zone,
    update_watermark_value timestamp without time zone,
    watermark_integer_value bigint,
    record_count bigint,
    sql_aggregate text COLLATE pg_catalog."default",
    sysupdatetime timestamp without time zone,
    post_sync_insert_watermark_value timestamp without time zone,
    post_sync_update_watermark_value timestamp without time zone,
    post_sync_watermark_integer_value bigint,
    post_sync_record_count bigint,
    sysupdatetime_after_migration timestamp without time zone,
    sql_source_query text COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS public.prod_to_stage_migration_audit
    OWNER to citus;



-- =====================================================
-- Add the new column to existing table
-- =====================================================
ALTER TABLE fact.prod_to_stage_migration_audit
ADD COLUMN IF NOT EXISTS referenced_by jsonb;


-- =====================================================
-- Usage Examples
-- =====================================================

-- Run the procedure
CALL fact.usp_prod_to_stage_migration_audit();

-- Example 1: See both forward and reverse dependencies
SELECT 
    table_schema,
    table_name,
    dependency_level,
    depends_on,           -- Tables this table references
    referenced_by         -- Tables that reference this table
FROM fact.prod_to_stage_migration_audit
ORDER BY dependency_level, table_schema, table_name;

-- Example 2: Find "hub" tables (referenced by many tables)
SELECT 
    table_schema,
    table_name,
    dependency_level,
    jsonb_array_length(COALESCE(referenced_by, '[]'::jsonb)) as reference_count,
    referenced_by
FROM fact.prod_to_stage_migration_audit
WHERE jsonb_array_length(COALESCE(referenced_by, '[]'::jsonb)) > 0
ORDER BY reference_count DESC;

-- Example 3: Find leaf tables (not referenced by anyone)
SELECT 
    table_schema,
    table_name,
    dependency_level,
    depends_on
FROM fact.prod_to_stage_migration_audit
WHERE jsonb_array_length(COALESCE(referenced_by, '[]'::jsonb)) = 0
ORDER BY dependency_level DESC, table_schema, table_name;

-- Example 4: Find independent tables (neither depends on nor referenced by others)
SELECT 
    table_schema,
    table_name
FROM fact.prod_to_stage_migration_audit
WHERE jsonb_array_length(COALESCE(depends_on, '[]'::jsonb)) = 0
  AND jsonb_array_length(COALESCE(referenced_by, '[]'::jsonb)) = 0;

-- Example 5: Table relationship summary
SELECT 
    table_schema,
    table_name,
    dependency_level,
    jsonb_array_length(COALESCE(depends_on, '[]'::jsonb)) as depends_on_count,
    jsonb_array_length(COALESCE(referenced_by, '[]'::jsonb)) as referenced_by_count,
    CASE 
        WHEN jsonb_array_length(COALESCE(depends_on, '[]'::jsonb)) = 0 
             AND jsonb_array_length(COALESCE(referenced_by, '[]'::jsonb)) > 0 
        THEN 'ROOT/DIMENSION'
        WHEN jsonb_array_length(COALESCE(depends_on, '[]'::jsonb)) > 0 
             AND jsonb_array_length(COALESCE(referenced_by, '[]'::jsonb)) = 0 
        THEN 'LEAF/FACT'
        WHEN jsonb_array_length(COALESCE(depends_on, '[]'::jsonb)) > 0 
             AND jsonb_array_length(COALESCE(referenced_by, '[]'::jsonb)) > 0 
        THEN 'INTERMEDIATE'
        ELSE 'ISOLATED'
    END as table_type
FROM fact.prod_to_stage_migration_audit
ORDER BY dependency_level, referenced_by_count DESC, table_schema, table_name;

@and(or(equals(coalesce(activity('GetMaxValues').output.firstRow.key_columns, 'null'), 'null'),
        empty(json(activity('GetMaxValues').output.firstRow.key_columns))),
     equals(activity('GetMaxValues').output.firstRow.record_count, activity('GetMaxValues').output.firstRow.post_migration_record_count))


--CALL fact.usp_prod_to_stage_migration_audit();
SELECT *,-- table_schema, table_name, insert_watermark, insert_watermark_data_type, insert_watermark_value, update_watermark, update_watermark_data_type, update_watermark_value, record_count
       concat('DELETE FROM ', table_schema, '.', table_name, ' WHERE ', insert_watermark, ' >= ''2025-12-02'' :: TIMESTAMP;')
FROM fact.prod_to_stage_migration_audit 
WHERE 1=1
  AND table_name NOT IN ('device','weather','stage_watermark','peripheral','prod_to_stage_migration_audit')
  /* record_count > 100000
  AND insert_watermark is not null
  AND insert_watermark_value is not null 
  AND table_name not in ('deviceevent','deviceevent')*/
ORDER BY dependency_level,-- DESC, 
         dependency_count,-- DESC, 
         table_schema, table_name;

SELECT * FROM dim.datedim
--DELETE FROM fact.transactionitem WHERE sysinserttime >= '2025-12-02' :: TIMESTAMP; --50699
--DELETE FROM fact.vw_offer_analysis WHERE sysinserttime >= '2025-12-02' :: TIMESTAMP; --1157
--DELETE FROM fact.devicetelemetry WHERE sysinserttime >= '2025-12-02' :: TIMESTAMP; --2467
--DELETE FROM fact.itemmodifier WHERE sysinserttime >= '2025-12-02' :: TIMESTAMP; --2298
--DELETE FROM fact.recommendations WHERE sysinserttime >= '2025-12-02' :: TIMESTAMP; --922
--DELETE FROM fact.transactionheader WHERE createddate >= '2025-12-02' :: TIMESTAMP; --31180
--DELETE FROM fact.transactionpayment WHERE sysinserttime >= '2025-12-02' :: TIMESTAMP; --634
--DELETE FROM fact.userbehaviour WHERE createddate >= '2025-12-02' :: TIMESTAMP; --10075861


SELECT MAX(sysinserttime) as max_insert, MAX(sysupdatetime) as max_update FROM fact.transactionitem 
WHERE sysinserttime < '2025-12-08 03:33:32.539425'-- '2025-12-12 13:00:37.781917' :: TIMESTAMP 
   OR sysupdatetime < '2025-12-12 13:06:35.921436'-- '2025-12-12 13:06:35.921436' :: TIMESTAMP --2025-12-08 03:33:32.539425	2025-12-12 13:06:35.921436


-- Table: public.prod_to_stage_migration_audit

-- DROP TABLE IF EXISTS public.prod_to_stage_migration_audit;
