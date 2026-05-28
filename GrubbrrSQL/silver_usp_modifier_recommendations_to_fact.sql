--CALL fact.usp_silver_modifier_recommendations_to_fact();

SELECT * FROM stg.silver_modifier_recommendations;
SELECT * FROM fact.modifier_recommendations;

-- Table: fact.modifier_recommendations

-- DROP TABLE IF EXISTS fact.modifier_recommendations;

CREATE TABLE IF NOT EXISTS fact.modifier_recommendations
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    modifier_impressions jsonb,
    modifier_interactions jsonb,
    businessdate date,
    orderdateutc text COLLATE pg_catalog."default",
    orderdatelocal timestamp without time zone,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.modifier_recommendations
    OWNER to citus;

-- Table: stg.silver_modifier_recommendations

-- DROP TABLE IF EXISTS stg.silver_modifier_recommendations;

CREATE TABLE IF NOT EXISTS stg.silver_modifier_recommendations
(
    transactionheaderid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    ordersessionid text COLLATE pg_catalog."default",
    orderdateutc text COLLATE pg_catalog."default",
    businessdate text COLLATE pg_catalog."default",
    syscosmosts bigint,
    locationid text COLLATE pg_catalog."default",
    kioskid text COLLATE pg_catalog."default",
    kiosk_name text COLLATE pg_catalog."default",
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text COLLATE pg_catalog."default",
    modifier_interactions text COLLATE pg_catalog."default",
    modifier_impressions text COLLATE pg_catalog."default",
    order_completion_status text COLLATE pg_catalog."default",
    bronze_filepath text COLLATE pg_catalog."default",
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_modifier_recommendations
    OWNER to citus;

-- ============================================================
-- 2. fact.usp_load_modifier_recommendations
--
--    Source  : stg.silver_modifier_recommendations
--    PK      : none declared — logical key (locationid, transactionheaderid)
--    Strategy: NOT EXISTS guard + DISTINCT ON dedup in source CTE.
--              modifier_impressions / modifier_interactions arrive as
--              TEXT from ADF toString(); cast to JSONB here.
-- ============================================================
CREATE OR REPLACE PROCEDURE fact.usp_silver_modifier_recommendations_to_fact()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;

BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.modifier_recommendations'
      AND source             = 'nge';

    WITH delta AS (
        -- Deduplicate: keep latest snapshot per (locationid, transactionheaderid)
        SELECT DISTINCT ON (locationid, transactionheaderid)
            locationid,
            transactionheaderid,
            ordersessionid,
            orderid,
            modifier_impressions,
            modifier_interactions,      -- intentionally nullable; CosmosDB filter only guards impressions
            businessdate :: DATE        AS businessdate,
            orderdateutc,
            frequentcustomerid,
            syscosmosts
        FROM stg.silver_modifier_recommendations
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND syscosmosts        >  v_max_syscosmosts
          -- mirror CosmosDB source filter: skip orders with no impressions data
          AND modifier_impressions IS NOT NULL
          AND modifier_impressions != '[]'
        ORDER BY locationid, transactionheaderid, syscosmosts DESC
    )
    INSERT INTO fact.modifier_recommendations (
        locationid,
        transactionheaderid,
        ordersessionid,
        orderid,
        modifier_impressions,
        modifier_interactions,
        businessdate,
        orderdateutc,
        orderdatelocal,
        frequentcustomerid,
        syscosmosts,
        sysinserttime
    )
    SELECT
        d.locationid,
        d.transactionheaderid,
        d.ordersessionid,
        d.orderid,
        d.modifier_impressions :: JSONB,
        d.modifier_interactions :: JSONB,
        d.businessdate,
        fact.parse_iso_timestamp(d.orderdateutc)    AS orderdateutc,
        th.orderdatelocal                           AS orderdatelocal,
        d.frequentcustomerid,
        d.syscosmosts,
        NOW() :: TIMESTAMP                          AS sysinserttime
    FROM delta d
    -- Mirror ADF ExistingOrders step: only load if the parent order is already in the fact layer
    INNER JOIN fact.transactionheader th
            ON th.locationid          = d.locationid
           AND th.transactionheaderid = d.transactionheaderid
    -- Mirror ADF NewModfrRecs step (negate:true): skip if already recorded
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.modifier_recommendations mr
        WHERE mr.locationid          = d.locationid
          AND mr.transactionheaderid = d.transactionheaderid
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_recommendations)
    WHERE watermarktablename = 'fact.modifier_recommendations'
      AND source             = 'nge';

END;
$BODY$;
ALTER PROCEDURE fact.usp_silver_modifier_recommendations_to_fact()
    OWNER TO citus;