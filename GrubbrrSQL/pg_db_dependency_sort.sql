-- =====================================================
-- STEP 1: Analyze Table Dependencies by Level
-- Using pg_catalog instead of information_schema for better permissions
-- =====================================================

CREATE OR REPLACE VIEW public.vw_db_dependency_sort
AS

WITH RECURSIVE table_dependencies AS (
    -- Get all base tables in the schema
    SELECT DISTINCT
        n.nspname::text AS table_schema,
        c.relname::text AS table_name
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' -- regular tables only
        AND n.nspname IN ('public')
        AND n.nspname NOT LIKE 'pg_temp_%'
        AND n.nspname NOT LIKE 'pg_toast_temp_%'
),
foreign_keys AS (
    -- Extract all foreign key relationships using pg_constraint
    SELECT DISTINCT
        n1.nspname::text AS table_schema,
        c1.relname::text AS referencing_table,
        c2.relname::text AS referenced_table
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c1 ON con.conrelid = c1.oid
    JOIN pg_catalog.pg_namespace n1 ON c1.relnamespace = n1.oid
    JOIN pg_catalog.pg_class c2 ON con.confrelid = c2.oid
    WHERE con.contype = 'f' -- foreign key constraints
        AND n1.nspname IN ('public')
),
dependency_graph AS (
    -- Build the complete dependency graph
    SELECT 
        td.table_schema,
        td.table_name,
        COALESCE(array_agg(DISTINCT fk.referenced_table) 
            FILTER (WHERE fk.referenced_table IS NOT NULL), ARRAY[]::text[]) AS depends_on
    FROM table_dependencies td
    LEFT JOIN foreign_keys fk 
        ON td.table_name = fk.referencing_table 
        AND td.table_schema = fk.table_schema
    GROUP BY td.table_schema, td.table_name
),
table_keys AS (
    -- Get Primary Key or Unique Key columns using pg_constraint
    SELECT 
        n.nspname::text AS table_schema,
        c.relname::text AS table_name,
        CASE 
            WHEN con.contype = 'p' THEN 'PRIMARY KEY'
            WHEN con.contype = 'u' THEN 'UNIQUE'
        END AS constraint_type,
        array_agg(a.attname::text ORDER BY array_position(con.conkey, a.attnum)) AS key_columns,
        CASE 
            WHEN con.contype = 'p' THEN 1
            WHEN con.contype = 'u' THEN 2
        END AS key_priority
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c ON con.conrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(con.conkey)
    WHERE con.contype IN ('p', 'u') -- primary key or unique
        AND n.nspname IN ('public')
    GROUP BY n.nspname, c.relname, con.contype, con.conname
),
best_keys AS (
    -- Select the best key for each table (PK preferred over UNIQUE)
    SELECT DISTINCT ON (table_schema, table_name)
        table_schema,
        table_name,
        constraint_type,
        key_columns
    FROM table_keys
    ORDER BY table_schema, table_name, key_priority
),
dependency_levels AS (
    -- Level 0: Tables with no dependencies
    SELECT 
        dg.table_schema,
        dg.table_name,
        0 AS dependency_level,
        dg.depends_on,
        ARRAY[dg.table_name] AS dependency_chain,
        bk.key_columns,
        bk.constraint_type AS key_type
    FROM dependency_graph dg
    LEFT JOIN best_keys bk
        ON dg.table_schema = bk.table_schema
        AND dg.table_name = bk.table_name
    WHERE cardinality(dg.depends_on) = 0
    
    UNION ALL
    
    -- Recursive: Calculate levels for dependent tables
    SELECT 
        dg.table_schema,
        dg.table_name,
        dl.dependency_level + 1 AS dependency_level,
        dg.depends_on,
        dl.dependency_chain || dg.table_name AS dependency_chain,
        bk.key_columns,
        bk.constraint_type AS key_type
    FROM dependency_graph dg
    JOIN dependency_levels dl 
        ON dg.table_schema = dl.table_schema
        AND dl.table_name = ANY(dg.depends_on)
    LEFT JOIN best_keys bk
        ON dg.table_schema = bk.table_schema
        AND dg.table_name = bk.table_name
    WHERE NOT dg.table_name = ANY(dl.dependency_chain) -- Prevent circular dependencies
)
SELECT DISTINCT
    dependency_level,
    table_schema,
    table_name,
    depends_on,
    COALESCE(array_length(depends_on, 1), 0) AS dependency_count,
    key_columns,
    key_type
FROM dependency_levels
WHERE dependency_level = (
    -- Get the maximum level for each table (in case of multiple paths)
    SELECT MAX(dl2.dependency_level)
    FROM dependency_levels dl2
    WHERE dl2.table_name = dependency_levels.table_name
        AND dl2.table_schema = dependency_levels.table_schema
)
ORDER BY dependency_level, table_schema, table_name;

-- =====================================================
-- STEP 2: Generate Migration Order Summary
-- =====================================================

SELECT 
    dependency_level,
    COUNT(*) AS table_count,
    string_agg(table_name, ', ' ORDER BY table_name) AS tables
FROM (
    SELECT 
        dependency_level,
        table_schema,
        table_name,
        depends_on
    FROM dependency_levels
    WHERE dependency_level = (
        SELECT MAX(dl2.dependency_level)
        FROM dependency_levels dl2
        WHERE dl2.table_name = dependency_levels.table_name
            AND dl2.table_schema = dependency_levels.table_schema
    )
) AS ordered_tables
GROUP BY dependency_level
ORDER BY dependency_level;

-- =====================================================
-- STEP 3: Detect Circular Dependencies (if any)
-- =====================================================

WITH dependency_graph AS (
    SELECT 
        n1.nspname::text AS table_schema,
        c1.relname::text AS referencing_table,
        c2.relname::text AS referenced_table
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c1 ON con.conrelid = c1.oid
    JOIN pg_catalog.pg_namespace n1 ON c1.relnamespace = n1.oid
    JOIN pg_catalog.pg_class c2 ON con.confrelid = c2.oid
    WHERE con.contype = 'f'
        AND n1.nspname IN ('public')
)
SELECT DISTINCT
    dg1.referencing_table AS table_a,
    dg1.referenced_table AS table_b,
    'Circular dependency detected' AS issue
FROM dependency_graph dg1
JOIN dependency_graph dg2
    ON dg1.referencing_table = dg2.referenced_table
    AND dg1.referenced_table = dg2.referencing_table
WHERE dg1.referencing_table < dg2.referencing_table
ORDER BY table_a, table_b;