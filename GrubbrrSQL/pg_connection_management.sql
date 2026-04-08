SELECT * FROM pg_stat_activity;

SELECT pid, usename, state, state_change
FROM pg_stat_activity
WHERE state = 'idle'; --AND state_change < NOW() - INTERVAL '5 minutes';


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