-- =============================================================================
-- silver_usp_load_all_to_fact.sql
-- Delta-load stored procedures: stg.silver_* → fact.*
-- Schema  : fact
-- Platform: PostgreSQL 16 on Citus
-- Owner   : citus
-- =============================================================================
--
-- EXISTING PROCEDURE (not duplicated here):
--   fact.usp_silver_to_fact_transaction_header()
--   → see GrubbrrSQL/silver_usp_load_transactions_and_events.sql
--
-- PROCEDURES IN THIS FILE:
--   1. fact.usp_silver_to_fact_transaction_item()
--        stg.silver_transaction_item        → fact.transactionitem
--   2. fact.usp_silver_to_fact_item_modifier()
--        stg.silver_item_modifiers          → fact.itemmodifier
--   3. fact.usp_silver_to_fact_transaction_payment()
--        stg.silver_transaction_payment     → fact.transactionpayment
--   4. fact.usp_silver_to_fact_combo_items()
--        stg.silver_transaction_combo_items → fact.transactionitem
--                                             (itemtype = 'combo_component')
--   5. fact.usp_silver_to_fact_recommendations()
--        stg.silver_upsell_recommendations  → fact.recommendations
--                                          → fact.vw_offer_analysis (unnested)
--   6. fact.usp_silver_to_fact_modifier_interactions()
--        stg.silver_modifier_interactions   → fact.modifier_interactions
--   7. fact.usp_silver_to_fact_deviceevent()
--        stg.silver_kiosk_events            → fact.deviceevent
--   8. fact.usp_silver_to_fact_cep_incidents()
--        stg.silver_cep_incidents           → fact.cep_incidents
--
-- SKIPPED (no matching fact table in current schema DDL):
--   stg.silver_modifier_recommendations — raw intermediate; already feeds
--        silver_modifier_interactions and silver_modifier_impressions via ADF
--   stg.silver_modifier_impressions     — no fact.modifier_impressions table
--        found in current DDL; create the target table first, then add a proc
--
-- DELTA PATTERN (consistent across all procedures):
--   1. Filter test records : is_test_order = FALSE OR is_test_order IS NULL
--   2. Deduplicate         : ROW_NUMBER() OVER (PARTITION BY <bk> ORDER BY syscosmosts DESC) = 1
--   3. Skip existing rows  : NOT EXISTS (SELECT 1 FROM fact.<t> WHERE <pk match>)
--
-- TIMESTAMP PARSING HELPER (used inline throughout):
--   Handles ISO-8601 with or without milliseconds / timezone suffix:
--     CASE WHEN substring(<col>, 20, 1) = '.'
--          THEN replace(replace(substring(<col>, 1, 23), 'T', ' '), '+', '0')
--          ELSE replace(substring(<col>, 1, 19), 'T', ' ')
--     END :: TIMESTAMP
-- =============================================================================


-- =============================================================================
-- 1. fact.usp_silver_to_fact_transaction_item
--    Source : stg.silver_transaction_item
--    Target : fact.transactionitem
--    Grain  : one row per (transactionheaderid, orderitemid, itemname)
--    PK     : (transactionheaderid, itemid, itemname)
--    Notes  :
--      • menuitemid (text) looked up in dim.menuitem → bigint surrogate
--      • categoryid (text) looked up in dim.itemcategory → bigint surrogate
--      • combo items are NOT loaded here — see proc 4
-- =============================================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_to_fact_transaction_item()
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO fact.transactionitem (
        transactionheaderid,
        categoryid,
        menuitemid,
        itemid,
        comboid,
        ordersessionid,
        itemsessionid,
        itemname,
        itemquantity,
        itemunitprice,
        upselllevel,
        upsellpromptitemid,
        orderid,
        itemtype,
        orderdateutc,
        sysinserttime,
        sysupdatetime,
        dimmenuitemid,
        locationid,
        orderdatelocal,
        businessdate
    )
    WITH delta_items AS (
        SELECT
            si.transactionheaderid,
            si.orderitemid                                          AS itemid,
            si.itemsessionid,
            si.itemname,
            si.itemquantity :: SMALLINT,
            si.usd_itemunitprice :: NUMERIC(12,3)                  AS itemunitprice,
            si.items_upsell_source                                  AS upselllevel,
            si.orderid,
            si.ordersessionid,
            si.locationid,
            si.menuitemid                                           AS dimmenuitemid,
            si.categoryid                                           AS src_categoryid,
            -- Normalise UTC string: strip milliseconds / tz suffix
            CASE WHEN substring(si.orderdateutc, 20, 1) = '.'
                 THEN replace(replace(substring(si.orderdateutc, 1, 23), 'T', ' '), '+', '0')
                 ELSE replace(substring(si.orderdateutc, 1, 19), 'T', ' ')
            END                                                     AS orderdateutc_clean,
            si.businessdate :: DATE                                 AS businessdate,
            ROW_NUMBER() OVER (
                PARTITION BY si.locationid, si.transactionheaderid, si.orderitemid
                ORDER BY si.syscosmosts DESC
            )                                                       AS row_num
        FROM stg.silver_transaction_item si
        WHERE (si.is_test_order = FALSE OR si.is_test_order IS NULL)
          AND si.orderitemid IS NOT NULL
          AND si.itemname    IS NOT NULL
    ),
    qualified_items AS (
        SELECT
            d.*,
            ic.id                                                   AS categoryid,
            mi.id                                                   AS menuitemid,
            d.orderdateutc_clean :: TIMESTAMPTZ AT TIME ZONE l.timezone
                                                                    AS orderdatelocal
        FROM delta_items d
        LEFT JOIN dim.location     l  ON l.locationid  = d.locationid
        LEFT JOIN dim.itemcategory ic ON ic.locationid = d.locationid
                                     AND ic.categoryid = d.src_categoryid
        LEFT JOIN dim.menuitem     mi ON mi.locationid = d.locationid
                                     AND mi.menuitemid = d.dimmenuitemid
        WHERE d.row_num = 1
          AND NOT EXISTS (
              SELECT 1 FROM fact.transactionitem ti
               WHERE ti.transactionheaderid = d.transactionheaderid
                 AND ti.itemid              = d.itemid
                 AND ti.itemname            = d.itemname
          )
    )
    SELECT
        transactionheaderid,
        categoryid,
        menuitemid,
        itemid,
        NULL :: TEXT                    AS comboid,
        ordersessionid,
        itemsessionid,
        itemname,
        itemquantity,
        itemunitprice,
        upselllevel,
        NULL :: TEXT                    AS upsellpromptitemid,
        orderid,
        'standard' :: TEXT              AS itemtype,
        orderdateutc_clean              AS orderdateutc,
        NOW() :: TIMESTAMP              AS sysinserttime,
        NOW() :: TIMESTAMP              AS sysupdatetime,
        dimmenuitemid,
        locationid,
        orderdatelocal,
        businessdate
    FROM qualified_items;

END;
$$;

ALTER PROCEDURE fact.usp_silver_to_fact_transaction_item() OWNER TO citus;


-- =============================================================================
-- 2. fact.usp_silver_to_fact_item_modifier
--    Source : stg.silver_item_modifiers
--    Target : fact.itemmodifier
--    Grain  : one row per (transactionheaderid, orderitemid, modifiergroupid, modifierid)
--    PK     : (transactionheaderid, itemid, modifiergroupid, modifierid)
-- =============================================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_to_fact_item_modifier()
LANGUAGE plpgsql
AS $$
BEGIN

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
        sysupdatetime
    )
    WITH delta_modifiers AS (
        SELECT
            sm.transactionheaderid,
            sm.orderid,
            sm.orderitemid                                          AS itemid,
            sm.options_modifiergroupid                             AS modifiergroupid,
            sm.options_modifierid                                  AS modifierid,
            sm.options_modifiername                                AS modifiername,
            sm.options_modifierquantity :: SMALLINT                AS modifierquantity,
            sm.options_total_modifierprice :: NUMERIC(12,3)        AS modifierprice,
            sm.modifier_freequantity                               AS freequantity,
            ROW_NUMBER() OVER (
                PARTITION BY sm.transactionheaderid, sm.orderitemid,
                             sm.options_modifiergroupid, sm.options_modifierid
                ORDER BY sm.syscosmosts DESC
            )                                                       AS row_num
        FROM stg.silver_item_modifiers sm
        WHERE (sm.is_test_order = FALSE OR sm.is_test_order IS NULL)
          AND sm.orderitemid            IS NOT NULL
          AND sm.options_modifiergroupid IS NOT NULL
          AND sm.options_modifierid      IS NOT NULL
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
        NOW() :: TIMESTAMP              AS sysinserttime,
        NOW() :: TIMESTAMP              AS sysupdatetime
    FROM delta_modifiers
    WHERE row_num = 1
      AND NOT EXISTS (
          SELECT 1 FROM fact.itemmodifier im
           WHERE im.transactionheaderid = delta_modifiers.transactionheaderid
             AND im.itemid              = delta_modifiers.itemid
             AND im.modifiergroupid     = delta_modifiers.modifiergroupid
             AND im.modifierid          = delta_modifiers.modifierid
      );

END;
$$;

ALTER PROCEDURE fact.usp_silver_to_fact_item_modifier() OWNER TO citus;


-- =============================================================================
-- 3. fact.usp_silver_to_fact_transaction_payment
--    Source : stg.silver_transaction_payment
--    Target : fact.transactionpayment
--    Grain  : one row per (transactionheaderid, paymentintegrationid, paymentid)
--    Unique : transactionpaymentuidx on (transactionheaderid, paymentintegrationid, paymentid)
-- =============================================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_to_fact_transaction_payment()
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO fact.transactionpayment (
        transactionheaderid,
        paymentintegrationid,
        paymentid,
        paymentamt,
        orderid,
        locationid,
        kioskid,
        paymentmethod,
        paymentintegrationlabel,
        orderdateutc,
        paymentcardtype,
        sysinserttime,
        sysupdatetime
    )
    WITH delta_payments AS (
        SELECT
            sp.transactionheaderid,
            sp.payment_integration_id                              AS paymentintegrationid,
            sp.payment_transactionid                               AS paymentid,
            sp.payment_amount :: NUMERIC(12,3)                     AS paymentamt,
            sp.orderid,
            sp.locationid,
            sp.kioskid,
            sp.payment_method                                      AS paymentmethod,
            sp.payment_integration_label                           AS paymentintegrationlabel,
            CASE WHEN substring(sp.orderdateutc, 20, 1) = '.'
                 THEN replace(replace(substring(sp.orderdateutc, 1, 23), 'T', ' '), '+', '0')
                 ELSE replace(substring(sp.orderdateutc, 1, 19), 'T', ' ')
            END                                                     AS orderdateutc,
            sp.card_info_card_type                                 AS paymentcardtype,
            ROW_NUMBER() OVER (
                PARTITION BY sp.transactionheaderid,
                             sp.payment_integration_id,
                             sp.payment_transactionid
                ORDER BY sp.syscosmosts DESC
            )                                                       AS row_num
        FROM stg.silver_transaction_payment sp
        WHERE (sp.is_test_order = FALSE OR sp.is_test_order IS NULL)
          AND sp.payment_integration_id IS NOT NULL
    )
    SELECT
        transactionheaderid,
        paymentintegrationid,
        paymentid,
        paymentamt,
        orderid,
        locationid,
        kioskid,
        paymentmethod,
        paymentintegrationlabel,
        orderdateutc,
        paymentcardtype,
        NOW() :: TIMESTAMP              AS sysinserttime,
        NOW() :: TIMESTAMP              AS sysupdatetime
    FROM delta_payments
    WHERE row_num = 1
      AND NOT EXISTS (
          SELECT 1 FROM fact.transactionpayment tp
           WHERE tp.transactionheaderid  = delta_payments.transactionheaderid
             AND tp.paymentintegrationid = delta_payments.paymentintegrationid
             AND tp.paymentid            = delta_payments.paymentid
      );

END;
$$;

ALTER PROCEDURE fact.usp_silver_to_fact_transaction_payment() OWNER TO citus;


-- =============================================================================
-- 4. fact.usp_silver_to_fact_combo_items
--    Source : stg.silver_transaction_combo_items
--    Target : fact.transactionitem  (same table as proc 1, different grain)
--    Grain  : one row per (transactionheaderid, component_item_order_item_id, component_item_name)
--    PK     : (transactionheaderid, itemid, itemname)
--    Notes  :
--      • Each row in silver is one component item within a combo
--      • comboid = combo_order_item_id (the parent combo container)
--      • itemtype is set to 'combo_component' to distinguish from standard items
--      • categoryid is not tracked at the component level in silver → NULL
-- =============================================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_to_fact_combo_items()
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO fact.transactionitem (
        transactionheaderid,
        categoryid,
        menuitemid,
        itemid,
        comboid,
        ordersessionid,
        itemsessionid,
        itemname,
        itemquantity,
        itemunitprice,
        upselllevel,
        upsellpromptitemid,
        orderid,
        itemtype,
        orderdateutc,
        sysinserttime,
        sysupdatetime,
        dimmenuitemid,
        locationid,
        orderdatelocal,
        businessdate
    )
    WITH delta_combos AS (
        SELECT
            sc.transactionheaderid,
            sc.component_item_order_item_id                        AS itemid,
            sc.combo_order_item_id                                 AS comboid,
            sc.ordersessionid,
            sc.component_item_session_id                           AS itemsessionid,
            sc.component_item_name                                 AS itemname,
            sc.component_item_quantity :: SMALLINT                 AS itemquantity,
            sc.component_item_unit_price :: NUMERIC(12,3)          AS itemunitprice,
            sc.component_item_upsell_source                        AS upselllevel,
            sc.orderid,
            sc.locationid,
            sc.component_item_menu_item_id                         AS dimmenuitemid,
            CASE WHEN substring(sc.orderdateutc, 20, 1) = '.'
                 THEN replace(replace(substring(sc.orderdateutc, 1, 23), 'T', ' '), '+', '0')
                 ELSE replace(substring(sc.orderdateutc, 1, 19), 'T', ' ')
            END                                                     AS orderdateutc_clean,
            sc.businessdate :: DATE                                 AS businessdate,
            ROW_NUMBER() OVER (
                PARTITION BY sc.transactionheaderid,
                             sc.component_item_order_item_id,
                             sc.component_item_name
                ORDER BY sc.syscosmosts DESC
            )                                                       AS row_num
        FROM stg.silver_transaction_combo_items sc
        WHERE (sc.is_test_order = FALSE OR sc.is_test_order IS NULL)
          AND sc.component_item_order_item_id IS NOT NULL
          AND sc.component_item_name          IS NOT NULL
    ),
    qualified_combos AS (
        SELECT
            d.*,
            mi.id                                                   AS menuitemid,
            d.orderdateutc_clean :: TIMESTAMPTZ AT TIME ZONE l.timezone
                                                                    AS orderdatelocal
        FROM delta_combos d
        LEFT JOIN dim.location l  ON l.locationid  = d.locationid
        LEFT JOIN dim.menuitem mi ON mi.locationid = d.locationid
                                 AND mi.menuitemid = d.dimmenuitemid
        WHERE d.row_num = 1
          AND NOT EXISTS (
              SELECT 1 FROM fact.transactionitem ti
               WHERE ti.transactionheaderid = d.transactionheaderid
                 AND ti.itemid              = d.itemid
                 AND ti.itemname            = d.itemname
          )
    )
    SELECT
        transactionheaderid,
        NULL :: BIGINT                  AS categoryid,      -- not tracked per component in silver
        menuitemid,
        itemid,
        comboid,
        ordersessionid,
        itemsessionid,
        itemname,
        itemquantity,
        itemunitprice,
        upselllevel,
        NULL :: TEXT                    AS upsellpromptitemid,
        orderid,
        'combo_component' :: TEXT       AS itemtype,
        orderdateutc_clean              AS orderdateutc,
        NOW() :: TIMESTAMP              AS sysinserttime,
        NOW() :: TIMESTAMP              AS sysupdatetime,
        dimmenuitemid,
        locationid,
        orderdatelocal,
        businessdate
    FROM qualified_combos;

END;
$$;

ALTER PROCEDURE fact.usp_silver_to_fact_combo_items() OWNER TO citus;


-- =============================================================================
-- 5. fact.usp_silver_to_fact_recommendations
--    Source : stg.silver_upsell_recommendations
--    Target : fact.recommendations      (header — one row per recommendation prompt)
--           : fact.vw_offer_analysis    (detail — one row per offered item, unnested)
--    PK (recommendations)    : (locationid, transactionheaderid, recommendationid)
--    PK (vw_offer_analysis)  : (transactionheaderid, recommendationid, offereditem)
--    Notes  :
--      • offered_items / selected_items arrive as TEXT JSON arrays → cast to JSONB
--      • dim.is_valid_jsonb() guards against malformed JSON
--      • isconverted = TRUE when at least one item was selected
--      • vw_offer_analysis is loaded from fact.recommendations (after header insert)
--        so the FK constraint is always satisfied
--      • upselltype / upsellgroupid / upsellgroupname are not available in silver
-- =============================================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_to_fact_recommendations()
LANGUAGE plpgsql
AS $$
BEGIN

    -- ── Step 1: load recommendation headers ──────────────────────────────────
    INSERT INTO fact.recommendations (
        transactionheaderid,
        locationid,
        recommendationid,
        offereditems,
        selecteditems,
        isconverted,
        prompttimestamp,
        sysinserttime,
        syscosmosts
    )
    WITH delta_recs AS (
        SELECT
            sr.transactionheaderid,
            sr.locationid,
            sr.recommendationid,
            CASE WHEN dim.is_valid_jsonb(sr.offered_items)
                 THEN sr.offered_items :: JSONB
                 ELSE '[]' :: JSONB
            END                                                     AS offereditems,
            CASE WHEN dim.is_valid_jsonb(sr.selected_items)
                 THEN sr.selected_items :: JSONB
                 ELSE NULL :: JSONB
            END                                                     AS selecteditems,
            sr.prompttimestamp,
            sr.syscosmosts,
            ROW_NUMBER() OVER (
                PARTITION BY sr.locationid, sr.transactionheaderid, sr.recommendationid
                ORDER BY sr.syscosmosts DESC
            )                                                       AS row_num
        FROM stg.silver_upsell_recommendations sr
        WHERE (sr.is_test_order = FALSE OR sr.is_test_order IS NULL)
          AND sr.recommendationid IS NOT NULL
    )
    SELECT
        transactionheaderid,
        locationid,
        recommendationid,
        offereditems,
        selecteditems,
        -- isconverted: TRUE when selecteditems is a non-empty array
        CASE WHEN selecteditems IS NOT NULL
              AND jsonb_array_length(selecteditems) > 0
             THEN TRUE
             ELSE FALSE
        END                                                         AS isconverted,
        prompttimestamp,
        NOW() :: TIMESTAMP                                          AS sysinserttime,
        syscosmosts
    FROM delta_recs
    WHERE row_num = 1
      AND NOT EXISTS (
          SELECT 1 FROM fact.recommendations r
           WHERE r.locationid          = delta_recs.locationid
             AND r.transactionheaderid = delta_recs.transactionheaderid
             AND r.recommendationid    = delta_recs.recommendationid
      );

    -- ── Step 2: unnest offered items into fact.vw_offer_analysis ─────────────
    INSERT INTO fact.vw_offer_analysis (
        locationid,
        transactionheaderid,
        recommendationid,
        offereditem,
        selecteditem,
        upselltype,
        upsellgroupid,
        upsellgroupname,
        quantity,
        prompttimestamp,
        upsellprompttime,
        syscosmosts,
        sysinserttime
    )
    SELECT
        r.locationid,
        r.transactionheaderid,
        r.recommendationid,
        t.offereditem,
        -- selecteditem: the offered item if it appears in the selecteditems array
        CASE WHEN r.selecteditems @> jsonb_build_array(t.offereditem)
             THEN t.offereditem
             ELSE NULL
        END                                                         AS selecteditem,
        NULL :: CHARACTER VARYING(50)                               AS upselltype,
        NULL :: CHARACTER VARYING(50)                               AS upsellgroupid,
        NULL :: TEXT                                                AS upsellgroupname,
        1                                                           AS quantity,
        r.prompttimestamp,
        -- best-effort timestamp parse from prompttimestamp
        CASE WHEN r.prompttimestamp IS NOT NULL
             THEN (
                 CASE WHEN substring(r.prompttimestamp, 20, 1) = '.'
                      THEN replace(replace(substring(r.prompttimestamp, 1, 23), 'T', ' '), '+', '0')
                      ELSE replace(substring(r.prompttimestamp, 1, 19), 'T', ' ')
                 END
             ) :: TIMESTAMP
             ELSE NULL
        END                                                         AS upsellprompttime,
        r.syscosmosts,
        NOW() :: TIMESTAMP                                          AS sysinserttime
    FROM fact.recommendations r
    CROSS JOIN LATERAL jsonb_array_elements_text(r.offereditems) AS t(offereditem)
    WHERE jsonb_array_length(r.offereditems) > 0
      AND NOT EXISTS (
          SELECT 1 FROM fact.vw_offer_analysis v
           WHERE v.transactionheaderid = r.transactionheaderid
             AND v.recommendationid    = r.recommendationid
             AND v.offereditem         = t.offereditem
      );

END;
$$;

ALTER PROCEDURE fact.usp_silver_to_fact_recommendations() OWNER TO citus;


-- =============================================================================
-- 6. fact.usp_silver_to_fact_modifier_interactions
--    Source : stg.silver_modifier_interactions
--    Target : fact.modifier_interactions
--    Grain  : one UI interaction event per (transactionheaderid, menuitemid,
--              modifiergroupid, modifierid)
--    PK     : (transactionheaderid, orderitemid, modifiergroupid, modifierid)
--    Notes  :
--      • silver_modifier_interactions tracks session-level UI events (add/remove
--        modifier clicks), NOT the final modifier selection per order item.
--        The silver table has menuitemid (which menu item was being customised)
--        but NOT orderitemid (the specific line-item instance).
--      • orderitemid in fact is fulfilled with menuitemid as a proxy.
--        If a future silver schema exposes orderitemid, update the mapping here.
--      • modifiername, modifierprice, freequantity are not available in silver;
--        they can be enriched later via dim.modifier if needed.
-- =============================================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_to_fact_modifier_interactions()
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
        modifierquantity,
        modifierprice,
        freequantity,
        selectiontype,
        action,
        businessdate,
        orderdatelocal,
        frequentcustomerid,
        sysinserttime,
        sysupdatetime
    )
    WITH delta_interactions AS (
        SELECT
            si.locationid,
            si.transactionheaderid,
            si.ordersessionid,
            si.orderid,
            si.menuitemid                                           AS orderitemid,   -- proxy; see note above
            si.menuitemid,
            si.modifiergroupid,
            si.modifierid,
            si.selection_type                                       AS selectiontype,
            si.modifier_interactions_action                         AS action,
            si.businessdate :: DATE                                 AS businessdate,
            CASE WHEN substring(si.orderdateutc, 20, 1) = '.'
                 THEN replace(replace(substring(si.orderdateutc, 1, 23), 'T', ' '), '+', '0')
                 ELSE replace(substring(si.orderdateutc, 1, 19), 'T', ' ')
            END                                                     AS orderdateutc_clean,
            ROW_NUMBER() OVER (
                PARTITION BY si.transactionheaderid, si.menuitemid,
                             si.modifiergroupid, si.modifierid
                ORDER BY si.syscosmosts DESC
            )                                                       AS row_num
        FROM stg.silver_modifier_interactions si
        WHERE (si.is_test_order = FALSE OR si.is_test_order IS NULL)
          AND si.modifiergroupid IS NOT NULL
          AND si.modifierid      IS NOT NULL
    ),
    qualified_interactions AS (
        SELECT
            d.*,
            d.orderdateutc_clean :: TIMESTAMPTZ AT TIME ZONE l.timezone
                                                                    AS orderdatelocal
        FROM delta_interactions d
        LEFT JOIN dim.location l ON l.locationid = d.locationid
        WHERE d.row_num = 1
          AND NOT EXISTS (
              SELECT 1 FROM fact.modifier_interactions mi
               WHERE mi.transactionheaderid = d.transactionheaderid
                 AND mi.orderitemid         = d.orderitemid
                 AND mi.modifiergroupid     = d.modifiergroupid
                 AND mi.modifierid          = d.modifierid
          )
    )
    SELECT
        locationid,
        transactionheaderid,
        ordersessionid,
        orderid,
        orderitemid,
        menuitemid,
        modifiergroupid,
        modifierid,
        NULL :: TEXT                    AS modifiername,
        1 :: SMALLINT                   AS modifierquantity,
        NULL :: NUMERIC(12,3)           AS modifierprice,
        NULL :: INTEGER                 AS freequantity,
        selectiontype,
        action,
        businessdate,
        orderdatelocal,
        NULL :: TEXT                    AS frequentcustomerid,
        NOW() :: TIMESTAMP              AS sysinserttime,
        NOW() :: TIMESTAMP              AS sysupdatetime
    FROM qualified_interactions;

END;
$$;

ALTER PROCEDURE fact.usp_silver_to_fact_modifier_interactions() OWNER TO citus;


-- =============================================================================
-- 7. fact.usp_silver_to_fact_deviceevent
--    Source : stg.silver_kiosk_events
--    Target : fact.deviceevent
--    Grain  : one row per UI/session event (application, companyid, locationid,
--              eventmodule, token, eventcategory, eventtype, eventinstant)
--    PK     : none (fact.deviceevent has no PK constraint)
--    Unique : deviceeventuidx on (application, companyid, locationid, moduleid,
--              eventtoken, datacategory, actiontype, eventinstant)  [non-unique index]
--    Notes  :
--      • fact.deviceevent has a FK to dim.organizationlocation(organizationid, locationid)
--        using (companyid, locationid) — the proc filters rows where this pair is
--        not yet registered to avoid FK violations.
--      • dateid is derived from eventinstant parsed to local hour (YYYYMMDDHH24).
--        Since eventinstant is UTC, dateid will be UTC-hour based; apply timezone
--        conversion via dim.location if local dateid is required.
-- =============================================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_to_fact_deviceevent()
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO fact.deviceevent (
        application,
        companyid,
        locationid,
        moduleid,
        datacategory,
        actiontype,
        severity,
        eventtoken,
        eventinstant,
        dateid,
        username,
        userid,
        deviceid,
        devicename,
        summary,
        eventdata,
        syscosmosticks,
        syscosmosts,
        sysinserttime
    )
    WITH delta_events AS (
        SELECT
            ke.application,
            ke.companyid,
            ke.locationid,
            ke.eventmodule                                          AS moduleid,
            ke.eventcategory                                        AS datacategory,
            ke.eventtype                                            AS actiontype,
            ke.severity,
            ke.token                                                AS eventtoken,
            ke.eventinstant,
            -- dateid: YYYYMMDDHH24 from parsed eventinstant (UTC)
            CAST(
                TO_CHAR(
                    (CASE WHEN substring(ke.eventinstant, 20, 1) = '.'
                          THEN replace(replace(substring(ke.eventinstant, 1, 23), 'T', ' '), '+', '0')
                          ELSE replace(substring(ke.eventinstant, 1, 19), 'T', ' ')
                     END) :: TIMESTAMP,
                    'YYYYMMDDHH24'
                )
            AS INTEGER)                                             AS dateid,
            ke.username,
            ke.userid,
            ke.device                                               AS deviceid,
            ke.devicename,
            ke.summary,
            ke.data                                                 AS eventdata,
            ke.syscosmosticks,
            ke.syscosmosts,
            ROW_NUMBER() OVER (
                PARTITION BY ke.application, ke.companyid, ke.locationid,
                             ke.eventmodule, ke.token,
                             ke.eventcategory, ke.eventtype, ke.eventinstant
                ORDER BY ke.syscosmosts DESC
            )                                                       AS row_num
        FROM stg.silver_kiosk_events ke
        -- only load events for org/location pairs already registered
        WHERE EXISTS (
            SELECT 1 FROM dim.organizationlocation ol
             WHERE ol.organizationid = ke.companyid
               AND ol.locationid     = ke.locationid
        )
    )
    SELECT
        application,
        companyid,
        locationid,
        moduleid,
        datacategory,
        actiontype,
        severity,
        eventtoken,
        eventinstant,
        dateid,
        username,
        userid,
        deviceid,
        devicename,
        summary,
        eventdata,
        syscosmosticks,
        syscosmosts,
        NOW() :: TIMESTAMP              AS sysinserttime
    FROM delta_events
    WHERE row_num = 1
      AND NOT EXISTS (
          SELECT 1 FROM fact.deviceevent de
           WHERE de.companyid   = delta_events.companyid
             AND de.locationid  = delta_events.locationid
             AND de.eventtoken  = delta_events.eventtoken
             AND de.actiontype  = delta_events.actiontype
             AND de.eventinstant = delta_events.eventinstant
      );

END;
$$;

ALTER PROCEDURE fact.usp_silver_to_fact_deviceevent() OWNER TO citus;


-- =============================================================================
-- 8. fact.usp_silver_to_fact_cep_incidents
--    Source : stg.silver_cep_incidents
--    Target : fact.cep_incidents
--    Grain  : one row per connector/CEP event occurrence
--    PK     : incidentkey BIGINT (surrogate, no identity sequence in current DDL)
--    Notes  :
--      • silver_cep_incidents captures raw event rows from the CEP/connector stream.
--        It does NOT yet carry incidenttype, incidentcount, firstoccurred, or
--        notificationtypeid — these are derived or enriched downstream.
--      • incidenttype is left NULL; enrich via a downstream UPDATE if needed.
--      • firstoccurred = lastoccurred = parsed eventinstant (single event per row).
--      • incidentcount defaults to 1.
--      • incidentkey surrogate: ROW_NUMBER() + current MAX(incidentkey).
-- =============================================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_to_fact_cep_incidents()
LANGUAGE plpgsql
AS $$
DECLARE
    v_max_key BIGINT;
BEGIN

    SELECT COALESCE(MAX(incidentkey), 0) INTO v_max_key FROM fact.cep_incidents;

    INSERT INTO fact.cep_incidents (
        incidentkey,
        application,
        organizationid,
        locationid,
        deviceid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidenttype,
        incidentcount,
        eventinstant,
        firstoccurred,
        lastoccurred,
        notificationtypeid,
        incidentdata,
        syscosmosts,
        sysinserttime,
        severity
    )
    WITH delta_incidents AS (
        SELECT
            sc.application,
            sc.companyid                                            AS organizationid,
            sc.locationid,
            sc.device                                               AS deviceid,
            sc.eventmodule,
            sc.eventcategory,
            sc.eventtype,
            sc.token                                                AS eventtoken,
            sc.eventinstant,
            sc.data                                                 AS incidentdata,
            sc.syscosmosts,
            sc.severity,
            ROW_NUMBER() OVER (
                PARTITION BY sc.companyid, sc.locationid,
                             sc.eventtype, sc.token, sc.eventinstant
                ORDER BY sc.syscosmosts DESC
            )                                                       AS row_num
        FROM stg.silver_cep_incidents sc
        WHERE sc.eventinstant IS NOT NULL
    ),
    qualified_incidents AS (
        SELECT
            d.*,
            (CASE WHEN substring(d.eventinstant, 20, 1) = '.'
                  THEN replace(replace(substring(d.eventinstant, 1, 23), 'T', ' '), '+', '0')
                  ELSE replace(substring(d.eventinstant, 1, 19), 'T', ' ')
             END) :: TIMESTAMP                                      AS eventinstant_ts
        FROM delta_incidents d
        WHERE d.row_num = 1
          AND NOT EXISTS (
              SELECT 1 FROM fact.cep_incidents ci
               WHERE ci.organizationid = d.organizationid
                 AND ci.locationid     = d.locationid
                 AND ci.eventtype      = d.eventtype
                 AND ci.eventtoken     = d.eventtoken
                 AND ci.eventinstant   = d.eventinstant
          )
    )
    SELECT
        -- surrogate key: offset from current max
        ROW_NUMBER() OVER (ORDER BY q.syscosmosts, q.eventinstant)
            + v_max_key                                             AS incidentkey,
        q.application,
        q.organizationid,
        q.locationid,
        q.deviceid,
        q.eventmodule,
        q.eventcategory,
        q.eventtype,
        q.eventtoken,
        NULL :: TEXT                    AS incidenttype,
        1                               AS incidentcount,
        q.eventinstant,
        q.eventinstant_ts               AS firstoccurred,
        q.eventinstant_ts               AS lastoccurred,
        NULL :: TEXT                    AS notificationtypeid,
        q.incidentdata,
        q.syscosmosts,
        NOW() :: TIMESTAMP              AS sysinserttime,
        q.severity
    FROM qualified_incidents q;

END;
$$;

ALTER PROCEDURE fact.usp_silver_to_fact_cep_incidents() OWNER TO citus;


-- =============================================================================
-- EXECUTION ORDER
-- Run in this sequence per pipeline trigger to respect FK dependencies:
--
--   CALL fact.usp_silver_to_fact_transaction_header();   -- existing proc
--   CALL fact.usp_silver_to_fact_transaction_item();     -- proc 1 (depends on header)
--   CALL fact.usp_silver_to_fact_combo_items();          -- proc 4 (depends on header)
--   CALL fact.usp_silver_to_fact_item_modifier();        -- proc 2 (depends on item)
--   CALL fact.usp_silver_to_fact_transaction_payment();  -- proc 3 (depends on header)
--   CALL fact.usp_silver_to_fact_recommendations();      -- proc 5 (depends on header)
--   CALL fact.usp_silver_to_fact_modifier_interactions();-- proc 6 (independent)
--   CALL fact.usp_silver_to_fact_deviceevent();          -- proc 7 (depends on dim.organizationlocation)
--   CALL fact.usp_silver_to_fact_cep_incidents();        -- proc 8 (independent)
-- =============================================================================
