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