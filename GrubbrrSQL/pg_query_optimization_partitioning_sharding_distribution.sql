SELECT * FROM pg_stat_activity;

-- In your second session, find and kill it:
SELECT *-- pg_cancel_backend(pid)
FROM pg_stat_activity
WHERE query LIKE '%duplicate_key_sets%' AND state = 'active';

SELECT
    pg_size_pretty(pg_relation_size('fact.deviceevent')) AS table_only,
    pg_size_pretty(pg_indexes_size('fact.deviceevent')) AS indexes,
    pg_size_pretty(pg_total_relation_size('fact.deviceevent')) AS total_with_indexes
;

-- Raw table size (no indexes, no TOAST)
SELECT pg_relation_size('fact.deviceevent');

-- Table size including TOAST but excluding indexes
SELECT pg_table_size('your_table');

-- Index size only
SELECT pg_indexes_size('your_table');

-- Total size (table + indexes + TOAST)
SELECT pg_total_relation_size('your_table');


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

--1	private-c-cospos-gas-test-eastus.ya7ggajhjyxy57.postgres.cosmos.azure.com	5432	True	primary

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

