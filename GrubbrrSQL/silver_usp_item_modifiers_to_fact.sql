CALL fact.usp_silver_item_modifiers_to_fact();

SELECT * FROM stg.silver_item_modifiers

SELECT * FROM fact.itemmodifier as im
WHERE im.sysinserttime IS NOT NULL
ORDER BY im.sysinserttime DESC
LIMIT 100

-- Table: fact.itemmodifier

-- DROP TABLE IF EXISTS fact.itemmodifier;

CREATE TABLE IF NOT EXISTS fact.itemmodifier
(
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    orderid text COLLATE pg_catalog."default" NOT NULL,
    itemid text COLLATE pg_catalog."default" NOT NULL,
    modifiergroupid text COLLATE pg_catalog."default" NOT NULL,
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    modifiername text COLLATE pg_catalog."default",
    modifierquantity smallint NOT NULL DEFAULT 1,
    modifierprice numeric(12,3),
    freequantity integer,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    locationid text COLLATE pg_catalog."default",
    businessdate date,
    syscosmosts bigint,
    CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY KEY (transactionheaderid, itemid, modifiergroupid, modifierid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.itemmodifier
    OWNER to citus;

-- Index: idx_fact_itemmodifier_locationid

-- DROP INDEX IF EXISTS fact.idx_fact_itemmodifier_locationid;

CREATE INDEX IF NOT EXISTS idx_fact_itemmodifier_locationid
    ON fact.itemmodifier USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: itemmodifieridx

-- DROP INDEX IF EXISTS fact.itemmodifieridx;

CREATE INDEX IF NOT EXISTS itemmodifieridx
    ON fact.itemmodifier USING btree
    (itemid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: transactionheaderid_idx

-- DROP INDEX IF EXISTS fact.transactionheaderid_idx;

CREATE INDEX IF NOT EXISTS transactionheaderid_idx
    ON fact.itemmodifier USING btree
    (transactionheaderid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


CREATE TABLE IF NOT EXISTS stg.silver_item_modifiers
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
    orderitemid text COLLATE pg_catalog."default",
    itemsessionid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    menu_item_pos_id text COLLATE pg_catalog."default",
    itemname text COLLATE pg_catalog."default",
    categoryid text COLLATE pg_catalog."default",
    categoryname text COLLATE pg_catalog."default",
    category_pos_id text COLLATE pg_catalog."default",
    itemquantity integer,
    usd_itemunitprice numeric(12,3),
    usd_total_item_price numeric(12,3),
    cents_itemunitprice bigint,
    cents_total_item_price bigint,
    items_discount_id text COLLATE pg_catalog."default",
    is_items_discount_hidden_on_receipt boolean,
    items_discounts text COLLATE pg_catalog."default",
    items_upsell_source text COLLATE pg_catalog."default",
    items_reward_source text COLLATE pg_catalog."default",
    items_special_request text COLLATE pg_catalog."default",
    items_concept_id text COLLATE pg_catalog."default",
    items_concept_name text COLLATE pg_catalog."default",
    options_modifierid text COLLATE pg_catalog."default",
    options_modifier_pos_id text COLLATE pg_catalog."default",
    options_modifiername text COLLATE pg_catalog."default",
    options_modifier_code text COLLATE pg_catalog."default",
    options_modifiergroupid text COLLATE pg_catalog."default",
    options_modifiergroupname text COLLATE pg_catalog."default",
    options_modifiergroup_pos_id text COLLATE pg_catalog."default",
    options_modifierquantity integer,
    options_modifierunitprice numeric(12,3),
    options_total_modifierprice numeric(12,3),
    modifier_freequantity integer,
    is_modifier_invisible boolean,
    is_modifier_default boolean,
    order_completion_status text COLLATE pg_catalog."default",
    bronze_filepath text COLLATE pg_catalog."default",
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_item_modifiers
    OWNER to citus;

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