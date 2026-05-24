CREATE OR REPLACE PROCEDURE dim.usp_refresh_<tablename>()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- Step 1: Deduplicate stg, materialise into indexed temp table
    CREATE TEMP TABLE tmp_<tablename> ON COMMIT DROP AS
    SELECT DISTINCT ON (<natural_key>)
        ...
    FROM stg.dim_<tablename>
    ORDER BY <natural_key>, <modified_on_col> DESC NULLS LAST;

    CREATE INDEX ix_tmp_<tablename> ON tmp_<tablename> (<natural_key>);
    ANALYZE tmp_<tablename>;

    -- Step 2: INSERT net new records only
    INSERT INTO dim.<tablename> (...)
    SELECT ...
    FROM tmp_<tablename> t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.<tablename> d
        WHERE d.<natural_key> = t.<natural_key>
    );

    -- Step 3: UPDATE changed records only
    UPDATE dim.<tablename> d
    SET ..., sysupdatetime = NOW()
    FROM tmp_<tablename> t
    WHERE d.<natural_key> = t.<natural_key>
    AND (
        ... IS DISTINCT FROM ...
    );

END;
$BODY$;




DO $BODY$
DECLARE
    t1 TIMESTAMP;
    t2 TIMESTAMP;
    t3 TIMESTAMP;
    t4 TIMESTAMP;
BEGIN
    t1 := clock_timestamp();

    CREATE TEMP TABLE tmp_modifier ON COMMIT DROP AS
    SELECT DISTINCT ON (modifierid) ...
    FROM stg.dim_modifier
    ORDER BY modifierid, modifier_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_modifier_modifierid ON tmp_modifier (modifierid);
    t2 := clock_timestamp();

    INSERT INTO dim.modifier ...
    FROM tmp_modifier t
    WHERE NOT EXISTS (...);
    t3 := clock_timestamp();

    UPDATE dim.modifier d SET ...
    FROM tmp_modifier t
    WHERE ...;
    t4 := clock_timestamp();

    RAISE NOTICE 'Step 1 - Temp table + index : %ms', EXTRACT(MILLISECONDS FROM t2 - t1);
    RAISE NOTICE 'Step 2 - INSERT             : %ms', EXTRACT(MILLISECONDS FROM t3 - t2);
    RAISE NOTICE 'Step 3 - UPDATE             : %ms', EXTRACT(MILLISECONDS FROM t4 - t3);
END;
$BODY$;