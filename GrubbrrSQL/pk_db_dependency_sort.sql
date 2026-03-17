-- =====================================================
-- STEP 1: Analyze Table Dependencies by Level
-- =====================================================
-- This query categorizes tables into dependency levels:
-- Level 0: Tables with no foreign keys (independent)
-- Level 1: Tables depending only on Level 0 tables
-- Level 2: Tables depending on Level 0 or 1, etc.

WITH RECURSIVE table_dependencies AS (
    -- Get all base tables in the schema
    SELECT DISTINCT
        t.table_schema::text,
        t.table_name::text,
        ARRAY[]::text[] AS depends_on
    FROM information_schema.tables t
    WHERE t.table_schema IN ('public')
        AND t.table_type = 'BASE TABLE'
),
foreign_keys AS (
    -- Extract all foreign key relationships
    SELECT DISTINCT
        tc.table_schema::text,
        tc.table_name::text AS referencing_table,
        ccu.table_name::text AS referenced_table
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu
        ON tc.constraint_name = ccu.constraint_name
        AND tc.table_schema = ccu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema IN ('public')
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
    -- Get Primary Key or Unique Key columns for each table
    SELECT 
        tc.table_schema::text,
        tc.table_name::text,
        tc.constraint_type::text,
        array_agg(kcu.column_name::text ORDER BY kcu.ordinal_position) AS key_columns,
        -- Prioritize PRIMARY KEY over UNIQUE
        CASE 
            WHEN tc.constraint_type = 'PRIMARY KEY' THEN 1
            WHEN tc.constraint_type = 'UNIQUE' THEN 2
        END AS key_priority
    FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
        AND tc.table_name = kcu.table_name
    WHERE tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
        AND tc.table_schema IN ('public')
    GROUP BY tc.table_schema, tc.table_name, tc.constraint_type, tc.constraint_name
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
-- Groups tables by dependency level for easy reference

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
-- These tables need special handling (disable/enable constraints)

WITH dependency_graph AS (
    SELECT 
        tc.table_name AS referencing_table,
        ccu.table_name AS referenced_table
    FROM information_schema.table_constraints tc
    JOIN information_schema.constraint_column_usage ccu
        ON tc.constraint_name = ccu.constraint_name
        AND tc.table_schema = ccu.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY'
        AND tc.table_schema IN ('public')
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