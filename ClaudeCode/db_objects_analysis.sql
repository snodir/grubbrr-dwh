-- =============================================================================
-- db_objects_analysis.sql
-- Grubbrr DWH — PostgreSQL (Citus) Metadata Queries
-- Source DDLs: GrubbrrSQL/gas_db_backup.sql, merged_schema.sql,
--              stg_silver_table_definitions_ddls.sql,
--              ml_schema_tables_and_stored_procedures.sql
--
-- Run each section independently against the live GAS database.
-- All queries are READ-ONLY (SELECT only).
-- =============================================================================


-- =============================================================================
-- SECTION 1: Schema Summary
-- Count of tables, views, functions, and procedures per schema
-- =============================================================================

SELECT
    n.nspname                                                    AS schema_name,
    COUNT(DISTINCT t.relname)
        FILTER (WHERE t.relkind = 'r')                          AS table_count,
    COUNT(DISTINCT t.relname)
        FILTER (WHERE t.relkind = 'v')                          AS view_count,
    COUNT(DISTINCT t.relname)
        FILTER (WHERE t.relkind = 'm')                          AS materialized_view_count,
    COUNT(DISTINCT p.proname)
        FILTER (WHERE p.prokind = 'f')                          AS function_count,
    COUNT(DISTINCT p.proname)
        FILTER (WHERE p.prokind = 'p')                          AS procedure_count
FROM pg_catalog.pg_namespace n
LEFT JOIN pg_catalog.pg_class      t ON t.relnamespace = n.oid
LEFT JOIN pg_catalog.pg_proc       p ON p.pronamespace = n.oid
WHERE n.nspname IN ('dim', 'fact', 'stg', 'ml', 'etl')
GROUP BY n.nspname
ORDER BY n.nspname;


-- =============================================================================
-- SECTION 2: All Tables with Approximate Row Counts
-- Uses pg_stat_user_tables for live estimates (no full scan)
-- =============================================================================

SELECT
    schemaname                                                   AS schema_name,
    relname                                                      AS table_name,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || relname))
                                                                 AS total_size,
    n_live_tup                                                   AS approx_row_count,
    last_analyze                                                 AS last_analyzed,
    last_autoanalyze                                             AS last_autoanalyzed
FROM pg_stat_user_tables
WHERE schemaname IN ('dim', 'fact', 'stg', 'ml', 'etl')
ORDER BY schemaname, relname;


-- =============================================================================
-- SECTION 3: All Columns
-- Full column inventory: table, column name, position, data type, nullable, default
-- =============================================================================

SELECT
    table_schema                                                 AS schema_name,
    table_name,
    ordinal_position                                             AS col_position,
    column_name,
    data_type,
    character_maximum_length                                     AS max_length,
    numeric_precision,
    numeric_scale,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema IN ('dim', 'fact', 'stg', 'ml', 'etl')
ORDER BY table_schema, table_name, ordinal_position;


-- =============================================================================
-- SECTION 4: Primary Keys and Unique Constraints
-- =============================================================================

SELECT
    tc.table_schema                                              AS schema_name,
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    STRING_AGG(kcu.column_name, ', ' ORDER BY kcu.ordinal_position)
                                                                 AS key_columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage  kcu
    ON kcu.constraint_name = tc.constraint_name
   AND kcu.table_schema    = tc.table_schema
   AND kcu.table_name      = tc.table_name
WHERE tc.table_schema   IN ('dim', 'fact', 'stg', 'ml', 'etl')
  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
GROUP BY tc.table_schema, tc.table_name, tc.constraint_name, tc.constraint_type
ORDER BY tc.table_schema, tc.table_name, tc.constraint_type, tc.constraint_name;


-- =============================================================================
-- SECTION 5: All Indexes
-- Index name, type, columns, uniqueness, partial-index predicate
-- =============================================================================

SELECT
    schemaname                                                   AS schema_name,
    tablename                                                    AS table_name,
    indexname                                                    AS index_name,
    indexdef                                                     AS index_definition,
    CASE WHEN indexdef ILIKE '%UNIQUE%' THEN 'YES' ELSE 'NO' END AS is_unique,
    CASE WHEN indexdef ILIKE '%WHERE%'  THEN 'YES' ELSE 'NO' END AS is_partial
FROM pg_indexes
WHERE schemaname IN ('dim', 'fact', 'stg', 'ml', 'etl')
ORDER BY schemaname, tablename, indexname;


-- =============================================================================
-- SECTION 6: Views (definition included)
-- =============================================================================

SELECT
    table_schema                                                 AS schema_name,
    table_name                                                   AS view_name,
    view_definition
FROM information_schema.views
WHERE table_schema IN ('dim', 'fact', 'stg', 'ml', 'etl')
ORDER BY table_schema, table_name;


-- =============================================================================
-- SECTION 7: Functions and Procedures
-- Name, language, return type, argument types, first 500 chars of source
-- =============================================================================

SELECT
    n.nspname                                                    AS schema_name,
    p.proname                                                    AS routine_name,
    CASE p.prokind
        WHEN 'f' THEN 'FUNCTION'
        WHEN 'p' THEN 'PROCEDURE'
        WHEN 'a' THEN 'AGGREGATE'
        WHEN 'w' THEN 'WINDOW'
        ELSE p.prokind::text
    END                                                          AS routine_type,
    l.lanname                                                    AS language,
    pg_catalog.pg_get_function_result(p.oid)                    AS return_type,
    pg_catalog.pg_get_function_arguments(p.oid)                 AS arguments,
    LEFT(p.prosrc, 500)                                         AS source_preview
FROM pg_catalog.pg_proc      p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
JOIN pg_catalog.pg_language  l ON l.oid = p.prolang
WHERE n.nspname IN ('dim', 'fact', 'stg', 'ml', 'etl')
ORDER BY n.nspname, p.proname;


-- =============================================================================
-- SECTION 8: Data Type Distribution
-- Count of columns per data type across the entire warehouse
-- =============================================================================

SELECT
    table_schema                                                 AS schema_name,
    data_type,
    COUNT(*)                                                     AS column_count
FROM information_schema.columns
WHERE table_schema IN ('dim', 'fact', 'stg', 'ml', 'etl')
GROUP BY table_schema, data_type
ORDER BY table_schema, column_count DESC;


-- =============================================================================
-- SECTION 9: Tables Without Primary Keys
-- Potential data quality risk — no PK means no guaranteed uniqueness
-- =============================================================================

SELECT
    c.table_schema                                               AS schema_name,
    c.table_name,
    COUNT(c.column_name)                                         AS column_count
FROM information_schema.columns c
WHERE c.table_schema IN ('dim', 'fact', 'stg', 'ml', 'etl')
  AND c.table_name NOT IN (
      SELECT kcu.table_name
      FROM information_schema.table_constraints  tc
      JOIN information_schema.key_column_usage   kcu
          ON kcu.constraint_name = tc.constraint_name
         AND kcu.table_schema    = tc.table_schema
      WHERE tc.table_schema   IN ('dim', 'fact', 'stg', 'ml', 'etl')
        AND tc.constraint_type  = 'PRIMARY KEY'
  )
GROUP BY c.table_schema, c.table_name
ORDER BY c.table_schema, c.table_name;


-- =============================================================================
-- SECTION 10: Column Name Pattern Search
-- Find all *id, *date*, *time*, *amount*, *status* columns across the warehouse
-- Useful for understanding join keys and common measure columns
-- =============================================================================

SELECT
    table_schema                                                 AS schema_name,
    table_name,
    column_name,
    data_type,
    CASE
        WHEN column_name ILIKE '%id'      THEN 'identifier'
        WHEN column_name ILIKE '%date%'   THEN 'date/time'
        WHEN column_name ILIKE '%time%'   THEN 'date/time'
        WHEN column_name ILIKE '%ts%'     THEN 'date/time'
        WHEN column_name ILIKE '%amount%' THEN 'measure'
        WHEN column_name ILIKE '%total%'  THEN 'measure'
        WHEN column_name ILIKE '%count%'  THEN 'measure'
        WHEN column_name ILIKE '%price%'  THEN 'measure'
        WHEN column_name ILIKE '%status%' THEN 'status/flag'
        WHEN column_name ILIKE 'is_%'     THEN 'status/flag'
        ELSE 'other'
    END                                                          AS column_category
FROM information_schema.columns
WHERE table_schema IN ('dim', 'fact', 'stg', 'ml', 'etl')
  AND (
       column_name ILIKE '%id'
    OR column_name ILIKE '%date%'
    OR column_name ILIKE '%time%'
    OR column_name ILIKE '%ts%'
    OR column_name ILIKE '%amount%'
    OR column_name ILIKE '%total%'
    OR column_name ILIKE '%count%'
    OR column_name ILIKE '%price%'
    OR column_name ILIKE '%status%'
    OR column_name ILIKE 'is_%'
  )
ORDER BY table_schema, table_name, column_name;
