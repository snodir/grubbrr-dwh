SELECT *
    /*logicalrelid::text AS table_name,
    distribution_column,
    partmethod*/
FROM pg_dist_partition
WHERE logicalrelid::text LIKE '%transactionheader%';

-- Check which node you're on
SELECT citus_is_coordinator();