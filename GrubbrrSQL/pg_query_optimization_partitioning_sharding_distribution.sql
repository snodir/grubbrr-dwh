SELECT *
    /*logicalrelid::text AS table_name,
    distribution_column,
    partmethod*/
FROM pg_dist_partition
WHERE logicalrelid::text LIKE '%transactionheader%';

-- Check which node you're on
SELECT citus_is_coordinator();

-- See coordinator + worker nodes
SELECT nodeid, nodename, nodeport, isactive, noderole
FROM pg_dist_node;

SELECT * FROM citus_tables
WHERE table_name = 'fact.transactionheader'::regclass;

SELECT
    logicalrelid::text                                          AS table_name,
    CASE partmethod
        WHEN 'h' THEN 'distributed (hash)'
        WHEN 'r' THEN 'distributed (range)'
        WHEN 'n' THEN 'reference'
    END                                                         AS table_type,
    column_to_column_name(logicalrelid, partkey)               AS distribution_column,
    colocationid                                                AS colocation_group
FROM pg_dist_partition
WHERE logicalrelid::text LIKE 'fact.%'
   OR logicalrelid::text LIKE 'dim.%'
ORDER BY logicalrelid::text;

