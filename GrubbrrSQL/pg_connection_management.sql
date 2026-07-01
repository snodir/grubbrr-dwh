SELECT * FROM pg_stat_activity;

SELECT pid, usename, state, state_change
FROM pg_stat_activity
WHERE state = 'idle'; --AND state_change < NOW() - INTERVAL '5 minutes';

SELECT CONCAT(schemaname, '.', relname) AS table_name,
       pg_size_pretty(pg_relation_size(CONCAT(schemaname, '.', relname))) AS table_only,
       pg_size_pretty(pg_indexes_size(CONCAT(schemaname, '.', relname))) AS indexes,
       pg_size_pretty(pg_total_relation_size(CONCAT(schemaname, '.', relname))) AS total_with_indexes,
       indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
       idx_scan AS times_used,
       idx_tup_read AS rows_read_from_index,
       idx_tup_fetch AS rows_fetched_from_table,
       *
FROM pg_stat_user_indexes
WHERE 1=1
  AND schemaname = 'fact'
  AND relname    IN ('deviceevent', 'userbehaviour')
ORDER BY table_name;
--2,858,904 --idx_scan

-- Kill the entire session (forces rollback if transaction is open)
SELECT pg_terminate_backend(<pid>);

-- Cancel the running query (session stays alive)
SELECT pg_cancel_backend(<pid>);

DO
$$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT pid
        FROM pg_stat_activity
        WHERE state = 'idle'-- AND state_change < NOW() - INTERVAL '5 minutes'
    LOOP
        EXECUTE 'SELECT pg_terminate_backend(' || r.pid || ')';
    END LOOP;
END
$$;

-- Check for blocking locks
SELECT 
    blocked.pid,
    blocked.query AS blocked_query,
    blocking.pid AS blocking_pid,
    blocking.query AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocking 
    ON blocking.pid = ANY(pg_blocking_pids(blocked.pid))
WHERE cardinality(pg_blocking_pids(blocked.pid)) > 0;

SELECT pg_terminate_backend(<blocking_pid>);

SELECT pid,
       usename,
       application_name,
       state,
       wait_event_type,
       wait_event,
       now() - query_start AS duration,
       query
FROM   pg_stat_activity
WHERE  datname = current_database()
  --AND  state != 'idle'
ORDER BY duration DESC;