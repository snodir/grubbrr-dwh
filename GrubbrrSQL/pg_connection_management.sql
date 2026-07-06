SELECT * FROM pg_stat_activity;
SELECT pg_cancel_backend(3055839);

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


/*Production GAS:
fact.deviceevent	105 GB	65 GB	298 GB	deviceeventidx	                    2095 MB	    1	    0	        0	    19896	19901	    fact	deviceevent	    deviceeventidx	1	2026-07-01 13:33:33.018953+00	0	0
fact.deviceevent	105 GB	65 GB	298 GB	deviceeventuidx	                    62 GB	    0	    0	        0	    19896	19902	    fact	deviceevent	    deviceeventuidx	0	NULL	0	0
fact.deviceevent	105 GB	65 GB	298 GB	ix_deviceevent_journey_lookup	    291 MB	    0	    0	        0	    19896	23803773	fact	deviceevent	    ix_deviceevent_journey_lookup	0	NULL	0	0
fact.userbehaviour	40 GB	30 GB	69 GB	userbehaviour_pkey	                7430 MB	    6387	8798	    8798	19960	19965	    fact	userbehaviour	userbehaviour_pkey	6387	2026-07-02 03:02:41.94796+00	8798	8798
fact.userbehaviour	40 GB	30 GB	69 GB	userbehaviour_locationid_dateid_idx	22 GB	    51	    21894818	18	    19960	2739075	    fact	userbehaviour	userbehaviour_locationid_dateid_idx	51	2026-06-30 17:35:48.237693+00	21894818	18
*/
-- Kill the entire session (forces rollback if transaction is open)
SELECT pg_terminate_backend(<pid>);

-- Cancel the running query (session stays alive)
SELECT pg_cancel_backend(3050912);

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