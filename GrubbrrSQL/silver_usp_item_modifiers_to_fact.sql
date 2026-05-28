-- ============================================================
-- Stored Procedures: Modifier Fact Tables
-- Schema  : fact
-- Sources : stg.silver_item_modifiers
--           stg.silver_modifier_recommendations
--           stg.silver_modifier_interactions
--           stg.silver_modifier_impressions
-- ============================================================


-- ============================================================
-- 1. fact.usp_load_itemmodifier
--
--    Source  : stg.silver_item_modifiers
--    PK      : (transactionheaderid, itemid, modifiergroupid, modifierid)
--    Strategy: ON CONFLICT DO UPDATE — update mutable fields and
--              advance syscosmosts only when the incoming snapshot
--              is newer than what is already stored.
-- ============================================================
CREATE OR REPLACE PROCEDURE fact.usp_silver_item_modifiers_to_fact()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;

BEGIN

    -- Capture watermark once upfront; subtract 10s as a safety overlap buffer
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.itemmodifier'
      AND source             = 'nge';

    WITH delta AS (
        -- Deduplicate: keep latest Cosmos snapshot per (header, item, group, modifier)
        SELECT DISTINCT ON (
            transactionheaderid,
            orderitemid,
            options_modifiergroupid,
            options_modifierid
        )
            transactionheaderid,
            orderid,
            orderitemid                             AS itemid,
            options_modifiergroupid                 AS modifiergroupid,
            options_modifierid                      AS modifierid,
            options_modifiername                    AS modifiername,
            COALESCE(options_modifierquantity, 1)   AS modifierquantity,
            options_modifierunitprice               AS modifierprice,
            modifier_freequantity                   AS freequantity,
            locationid,
            businessdate :: DATE                    AS businessdate,
            syscosmosts
        FROM stg.silver_item_modifiers
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND options_modifierid      IS NOT NULL
          AND options_modifiergroupid IS NOT NULL
          AND orderitemid             IS NOT NULL
          AND syscosmosts > v_max_syscosmosts
        ORDER BY
            transactionheaderid,
            orderitemid,
            options_modifiergroupid,
            options_modifierid,
            syscosmosts DESC
    )
    INSERT INTO fact.itemmodifier (
        transactionheaderid,
        orderid,
        itemid,
        modifiergroupid,
        modifierid,
        modifiername,
        modifierquantity,
        modifierprice,
        freequantity,
        sysinserttime,
        locationid,
        businessdate,
        syscosmosts
    )
    SELECT
        transactionheaderid,
        orderid,
        itemid,
        modifiergroupid,
        modifierid,
        modifiername,
        modifierquantity,
        modifierprice,
        freequantity,
        NOW() :: TIMESTAMP  AS sysinserttime,
        locationid,
        businessdate,
        syscosmosts
    FROM delta
    ON CONFLICT (transactionheaderid, itemid, modifiergroupid, modifierid)
    DO UPDATE SET
        modifiername     = EXCLUDED.modifiername,
        modifierquantity = EXCLUDED.modifierquantity,
        modifierprice    = EXCLUDED.modifierprice,
        freequantity     = EXCLUDED.freequantity,
        sysupdatetime    = NOW() :: TIMESTAMP,
        -- only advance if incoming snapshot is genuinely newer
        syscosmosts      = GREATEST(EXCLUDED.syscosmosts, fact.itemmodifier.syscosmosts);

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.itemmodifier)
    WHERE watermarktablename = 'fact.itemmodifier'
      AND source             = 'nge';

END;
$BODY$;
ALTER PROCEDURE fact.usp_silver_item_modifiers_to_fact()
    OWNER TO citus;



-- ============================================================
-- 2. fact.usp_load_modifier_recommendations
--
--    Source  : stg.silver_modifier_recommendations
--    PK      : none declared — logical key (locationid, transactionheaderid)
--    Strategy: NOT EXISTS guard + DISTINCT ON dedup in source CTE.
--              modifier_impressions / modifier_interactions arrive as
--              TEXT from ADF toString(); cast to JSONB here.
-- ============================================================
CREATE OR REPLACE PROCEDURE fact.usp_load_modifier_recommendations()
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO fact.modifier_recommendations (
        locationid,
        transactionheaderid,
        ordersessionid,
        orderid,
        modifier_impressions,
        modifier_interactions,
        businessdate,
        orderdateutc,
        frequentcustomerid,
        syscosmosts,
        sysinserttime
    )
    SELECT
        src.locationid,
        src.transactionheaderid,
        src.ordersessionid,
        src.orderid,
        src.modifier_impressions::jsonb,
        src.modifier_interactions::jsonb,
        src.businessdate::date,
        src.orderdateutc,
        src.frequentcustomerid,
        src.syscosmosts,
        NOW()
    FROM (
        SELECT DISTINCT ON (locationid, transactionheaderid)
            *
        FROM stg.silver_modifier_recommendations
        WHERE COALESCE(is_test_order, FALSE) IS NOT TRUE
          -- guard against rows where ADF wrote NULL / empty strings before stringify
          AND modifier_impressions  IS NOT NULL
          AND modifier_interactions IS NOT NULL
        ORDER BY locationid, transactionheaderid, syscosmosts DESC
    ) src
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.modifier_recommendations tgt
        WHERE tgt.locationid          = src.locationid
          AND tgt.transactionheaderid = src.transactionheaderid
    );

END;
$$;


-- ============================================================
-- 3. fact.usp_load_modifier_interactions
--
--    Source  : stg.silver_modifier_interactions  (behavioral events
--              from upsellInformation.modifierInteractions — distinct
--              from the item-option modifiers in silver_item_modifiers)
--    Enrich  : stg.silver_item_modifiers via LATERAL join to back-fill
--              orderitemid, modifiername, modifierquantity, modifierprice,
--              freequantity — columns present on the finalised order but
--              not on the raw interaction event.  LEFT JOIN is intentional:
--              interactions for items removed before checkout will not
--              match and those columns will be NULL.
--    PK      : none declared — logical dedup key:
--              (transactionheaderid, modifiergroupid, modifierid,
--               action, session_recorded_at)
--    Note    : orderdatelocal and sourceid have no source in the silver
--              layer and are left NULL.
-- ============================================================
CREATE OR REPLACE PROCEDURE fact.usp_load_modifier_interactions()
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO fact.modifier_interactions (
        locationid,
        transactionheaderid,
        ordersessionid,
        orderid,
        orderitemid,
        menuitemid,
        modifiergroupid,
        modifierid,
        modifiername,
        parent_modifier_id,
        nesting_depth,
        modifierquantity,
        modifierprice,
        freequantity,
        selection_type,
        action,
        session_recorded_at,
        businessdate,
        frequentcustomerid,
        syscosmosts,
        sysinserttime
        -- orderdatelocal : no timezone mapping in silver layer, left NULL
        -- sourceid        : no source column in staging, left NULL
    )
    SELECT
        src.locationid,
        src.transactionheaderid,
        src.ordersessionid,
        src.orderid,
        enr.orderitemid,
        src.menuitemid,
        src.modifiergroupid,
        src.modifierid,
        enr.options_modifiername                    AS modifiername,
        src.parent_modifier_id,
        src.modifier_interactions_nesting_depth     AS nesting_depth,
        enr.options_modifierquantity                AS modifierquantity,
        enr.options_modifierunitprice               AS modifierprice,
        enr.modifier_freequantity                   AS freequantity,
        src.selection_type,
        src.modifier_interactions_action            AS action,
        src.modifier_interactions_recorded_at       AS session_recorded_at,
        src.businessdate::date                      AS businessdate,
        src.frequentcustomerid,
        src.syscosmosts,
        NOW()
    FROM (
        -- deduplicate: one event row per (transactionheaderid, group, modifier, action, timestamp)
        SELECT DISTINCT ON (
            transactionheaderid,
            modifiergroupid,
            modifierid,
            modifier_interactions_action,
            modifier_interactions_recorded_at
        )
            *
        FROM stg.silver_modifier_interactions
        WHERE COALESCE(is_test_order, FALSE) IS NOT TRUE
        ORDER BY
            transactionheaderid,
            modifiergroupid,
            modifierid,
            modifier_interactions_action,
            modifier_interactions_recorded_at,
            syscosmosts DESC
    ) src
    -- enrich with order-level modifier details; LIMIT 1 guards against
    -- the edge case where the same modifier appears on multiple items
    LEFT JOIN LATERAL (
        SELECT
            im.orderitemid,
            im.options_modifiername,
            im.options_modifierquantity,
            im.options_modifierunitprice,
            im.modifier_freequantity
        FROM stg.silver_item_modifiers im
        WHERE im.transactionheaderid     = src.transactionheaderid
          AND im.menuitemid              = src.menuitemid
          AND im.options_modifierid      = src.modifierid
          AND im.options_modifiergroupid = src.modifiergroupid
        ORDER BY im.syscosmosts DESC
        LIMIT 1
    ) enr ON TRUE
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.modifier_interactions tgt
        WHERE tgt.transactionheaderid         = src.transactionheaderid
          AND tgt.modifiergroupid             = src.modifiergroupid
          AND tgt.modifierid                  = src.modifierid
          AND tgt.action                      = src.modifier_interactions_action
          AND tgt.session_recorded_at         = src.modifier_interactions_recorded_at
    );

END;
$$;


-- ============================================================
-- 4. fact.usp_load_modifier_impressions
--
--    Source  : stg.silver_modifier_impressions
--    PK      : none declared — logical dedup key:
--              (locationid, transactionheaderid, menuitemid, modifierid, position)
--    Strategy: NOT EXISTS guard + DISTINCT ON dedup in source CTE.
--    Note    : score is stored as integer in staging (raw recommendation
--              score from the ML model) and cast to numeric(5,3) in the
--              fact table.  Verify the score scale (e.g. 0–100 vs 0–1)
--              with the DS team and add a divisor here if needed.
--              orderdatelocal has no timezone mapping, left NULL.
-- ============================================================
CREATE OR REPLACE PROCEDURE fact.usp_load_modifier_impressions()
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO fact.modifier_impressions (
        locationid,
        transactionheaderid,
        ordersessionid,
        orderid,
        menuitemid,
        modifierid,
        parent_modifier_id,
        selection_type,
        nesting_depth,
        position,
        score,
        strategy,
        context,
        selected,
        pre_deselected,
        confirmed_removed,
        pre_selected,
        businessdate,
        frequentcustomerid,
        syscosmosts,
        sysinserttime
        -- orderdatelocal : no timezone mapping in silver layer, left NULL
    )
    SELECT
        src.locationid,
        src.transactionheaderid,
        src.ordersessionid,
        src.orderid,
        src.menuitemid,
        src.modifierid,
        src.parentmodifierid                        AS parent_modifier_id,
        src.selection_type,
        src.modifier_impressions_nesting_depth      AS nesting_depth,
        src.position,
        src.score::numeric(5,3),                    -- see scale note above
        src.strategy,
        src.modifier_impressions_context            AS context,
        src.selected,
        src.pre_deselected,
        src.confirmed_removed,
        src.pre_selected,
        src.businessdate::date                      AS businessdate,
        src.frequentcustomerid,
        src.syscosmosts,
        NOW()
    FROM (
        SELECT DISTINCT ON (
            locationid,
            transactionheaderid,
            menuitemid,
            modifierid,
            position
        )
            *
        FROM stg.silver_modifier_impressions
        WHERE COALESCE(is_test_order, FALSE) IS NOT TRUE
          AND modifierid IS NOT NULL
        ORDER BY
            locationid,
            transactionheaderid,
            menuitemid,
            modifierid,
            position,
            syscosmosts DESC
    ) src
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.modifier_impressions tgt
        WHERE tgt.locationid          = src.locationid
          AND tgt.transactionheaderid = src.transactionheaderid
          AND tgt.menuitemid          = src.menuitemid
          AND tgt.modifierid          = src.modifierid
          AND tgt.position            = src.position
    );

END;
$$;


-- ============================================================
-- 5. fact.usp_load_all_modifier_facts   (orchestrator)
--
--    Call order matters:
--      itemmodifier first — modifier_interactions LATERAL join
--      depends on silver_item_modifiers being consistent but the
--      enrichment join is against the staging table, not the fact,
--      so ordering here is for logical clarity only.
-- ============================================================
CREATE OR REPLACE PROCEDURE fact.usp_load_all_modifier_facts()
LANGUAGE plpgsql
AS $$
BEGIN
    CALL fact.usp_load_itemmodifier();
    CALL fact.usp_load_modifier_recommendations();
    CALL fact.usp_load_modifier_interactions();
    CALL fact.usp_load_modifier_impressions();
END;
$$;