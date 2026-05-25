-- ============================================================
-- dim_kiosk_details  –  Staging Tables + Refresh Procedure
-- Pattern : ADF Copy Activity  →  staging.*  →  sp  →  public.dim_kiosk_details
-- All transformation logic (dedup, array_agg, prefix strip, etc.)
-- moved from ADF Data Flow into the stored procedure below.
-- ============================================================


-- ============================================================
-- SECTION 1 – RAW STAGING TABLES
-- One table per Copy Activity source.
-- Schema mirrors the Cosmos DB query output exactly – no transforms.
-- Truncated by each Copy Activity before load (or by the proc).
-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;

-- ------------------------------------------------------------
-- 1a. stg_location_kiosks
--     Source: ngeLocationKiosks  (c.type = 'kiosks')
-- ------------------------------------------------------------
DROP TABLE IF EXISTS stg.location_kiosks;
CREATE TABLE stg.location_kiosks
(
    id              TEXT,
    locationid      TEXT,
    companyid       TEXT,
    devicetype      TEXT,
    syncversion     TEXT,
    kiosks          TEXT,       -- toString(c.kiosks) – JSON string
    syscosmosts     BIGINT
);

-- ------------------------------------------------------------
-- 1b. stg_pos_provider
--     Source: posProvider  (c.integrationDefinitionId, isDeleted=false)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS stg.pos_provider;
CREATE TABLE stg.pos_provider
(
    locationid      TEXT,
    pos_provider    TEXT,       -- raw integrationDefinitionId, may have 'pid-' prefix
    syscosmosts     BIGINT
);

-- ------------------------------------------------------------
-- 1c. stg_loyalty_configuration
--     Source: ngeLoyaltyConfiguration
-- ------------------------------------------------------------
DROP TABLE IF EXISTS stg.loyalty_configuration;
CREATE TABLE stg.loyalty_configuration
(
    locationid          TEXT,
    loyalty_provider    TEXT,
    syscosmosts         BIGINT
);

-- ------------------------------------------------------------
-- 1d. stg_payment_provider
--     Source: ngePaymentProvider  (c.type = 'kiosk-config', join paymentIntegrations)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS stg.payment_provider;
CREATE TABLE stg.payment_provider
(
    locationid          TEXT,
    payment_provider    TEXT,       -- raw paymentIntegrationId, may have 'payment-integration-' prefix
    syscosmosts         BIGINT
);

-- ------------------------------------------------------------
-- 1e. stg_kiosk_config
--     Source: ngeKioskScanner  (c.type = 'kiosk-config')
--     All complex fields land as raw TEXT (JSON strings)
-- ------------------------------------------------------------
DROP TABLE IF EXISTS stg.kiosk_config;
CREATE TABLE stg.kiosk_config
(
    locationid                          TEXT,
    syscosmosts                         BIGINT,

    -- booleans
    legal_copy_enabled                  BOOLEAN,
    calculate_default_modifier_price    BOOLEAN,
    track_kiosk_user_behavior           BOOLEAN,
    loyalty_feature                     BOOLEAN,
    pickup_flow                         BOOLEAN,
    pos_auto_applied_discount           BOOLEAN,
    search_functionality_enabled        BOOLEAN,
    recent_orders_enabled               BOOLEAN,
    round_up_for_charity                BOOLEAN,
    calories_enabled                    BOOLEAN,
    scan_and_go_enabled                 BOOLEAN,
    preorder_popup_enabled              BOOLEAN,
    perform_pos_status_check            BOOLEAN,

    -- JSON / text blobs (Copy Activity lands these as raw strings)
    scanners                            TEXT,
    item_special_request                TEXT,
    ada_configuration                   TEXT,
    play_card_config                    TEXT,
    age_verification                    TEXT,
    tips_settings                       TEXT,
    business_hours_config               TEXT,
    order_types                         TEXT,
    localization                        TEXT,
    loyalty_display_settings            TEXT,
    order_limit_config                  TEXT,
    menu_behavior_config                TEXT,
    preorder_popup_text                 TEXT,
    disclaimer_text                     TEXT
);


-- ============================================================
-- SECTION 2 – MAIN DIMENSION TABLE  (unchanged from before)
-- ============================================================
CREATE TABLE IF NOT EXISTS dim.kioskdetails
(
    id                                  TEXT,
    locationid                          TEXT            NOT NULL,
    companyid                           TEXT,
    devicetype                          TEXT,
    syncversion                         TEXT,
    kiosks                              TEXT,
    syscosmosts                         BIGINT,
    sysinserttime                       TIMESTAMPTZ,

    pos_provider                        TEXT,
    number_of_pos_providers             INTEGER,
    loyalty_provider                    TEXT,
    payment_provider                    TEXT,

    legal_copy_enabled                  BOOLEAN,
    calculate_default_modifier_price    BOOLEAN,
    track_kiosk_user_behavior           BOOLEAN,
    loyalty_feature                     BOOLEAN,
    pickup_flow                         BOOLEAN,
    pos_auto_applied_discount           BOOLEAN,
    search_functionality_enabled        BOOLEAN,
    recent_orders_enabled               BOOLEAN,
    round_up_for_charity                BOOLEAN,
    calories_enabled                    BOOLEAN,
    scan_and_go_enabled                 BOOLEAN,
    preorder_popup_enabled              BOOLEAN,
    perform_pos_status_check            BOOLEAN,

    scanners                            TEXT,
    item_special_request                TEXT,
    ada_configuration                   TEXT,
    play_card_config                    TEXT,
    age_verification                    TEXT,
    tips_settings                       TEXT,
    business_hours_config               TEXT,
    order_types                         TEXT,
    localization                        TEXT,
    loyalty_display_settings            TEXT,
    order_limit_config                  TEXT,
    menu_behavior_config                TEXT,
    preorder_popup_text                 TEXT,
    disclaimer_text                     TEXT,

    -- reserved for future sources
    kiosk_receipt_settings              TEXT,
    kiosk_fonts                         TEXT,
    kiosk_appearance_text_overrides     TEXT,
    kiosk_appearance_style_options      TEXT,

    -- DWH audit
    dwh_insert_time                     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    dwh_update_time                     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT pk_dim_kiosk_details PRIMARY KEY (locationid)
);

CREATE INDEX IF NOT EXISTS idx_dim_kiosk_details_companyid
    ON public.dim_kiosk_details (companyid);

CREATE INDEX IF NOT EXISTS idx_dim_kiosk_details_syscosmosts
    ON public.dim_kiosk_details (syscosmosts);

-- SELECT create_distributed_table('public.dim_kiosk_details', 'locationid');


-- ============================================================
-- SECTION 3 – STORED PROCEDURE
--
-- Replicates all Data Flow transformation steps:
--
--   POS provider
--     1. Deduplicate (locationid, pos_provider) – keep row with max syscosmosts
--     2. Strip 'pid-' prefix
--     3. array_agg per locationid  →  pos_provider text[], count  →  number_of_pos_providers
--
--   Loyalty provider
--     1. Deduplicate (locationid, loyalty_provider) – keep row with max syscosmosts
--     2. array_agg per locationid
--
--   Payment provider
--     1. Deduplicate (locationid, payment_provider) – keep row with max syscosmosts
--     2. Strip 'payment-integration-' prefix
--     3. array_agg per locationid
--
--   Kiosk config
--     1. Deduplicate per locationid – keep row with max syscosmosts (DISTINCT ON)
--
--   Location kiosks
--     1. DISTINCT on id (source query already uses SELECT DISTINCT)
--
--   Final step: upsert everything into public.dim_kiosk_details
-- ============================================================
CREATE OR REPLACE PROCEDURE public.sp_refresh_dim_kiosk_details()
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_rows_upserted     INTEGER := 0;
    v_start_time        TIMESTAMPTZ := NOW();
BEGIN

    -- ----------------------------------------------------------
    -- Step 1 – Base kiosk records (most recent per id)
    -- Mirrors: ngeLocationKiosks  →  toString  →  OnlyNeeded
    -- ----------------------------------------------------------
    -- Step 2 – POS providers aggregated per location
    -- Mirrors: posProvider  →  RowNum  →  RecentItems
    --          →  ListOfPOS  →  ArrayToString  (prefix strip + collect)
    -- ----------------------------------------------------------
    -- Step 3 – Loyalty providers aggregated per location
    -- Mirrors: ngeLoyaltyConfiguration  →  RN  →  MostRecent
    --          →  ListOfLoyaltyPrvd  →  ArrayToStr
    -- ----------------------------------------------------------
    -- Step 4 – Payment providers aggregated per location
    -- Mirrors: ngePaymentProvider  →  RowNumber  →  MostRecents
    --          →  ListOfPaymentPrvd  →  ArrayToString2  (prefix strip + collect)
    -- ----------------------------------------------------------
    -- Step 5 – Most-recent kiosk config per location
    -- Mirrors: ngeKioskScanner  →  RowNumber1  →  RecentState  →  ArrToString
    -- ----------------------------------------------------------

    WITH

    -- ── Base kiosks ───────────────────────────────────────────
    base AS (
        SELECT DISTINCT ON (id)
            id,
            locationid,
            companyid,
            devicetype,
            syncversion,
            kiosks,
            syscosmosts,
            NOW() AS sysinserttime
        FROM stg.location_kiosks
        WHERE locationid IS NOT NULL
        ORDER BY id, syscosmosts DESC
    ),

    -- ── POS providers ─────────────────────────────────────────
    -- 1. Deduplicate at (locationid, pos_provider) level, most recent wins
    pos_deduped AS (
        SELECT DISTINCT ON (locationid, pos_provider)
            locationid,
            CASE
                WHEN pos_provider LIKE 'pid-%'
                THEN substring(pos_provider FROM 5)   -- strips 'pid-' (4 chars)
                ELSE pos_provider
            END AS pos_provider
        FROM stg.pos_provider
        WHERE locationid IS NOT NULL
        ORDER BY locationid, pos_provider, syscosmosts DESC
    ),
    -- 2. Aggregate to one row per location
    pos_agg AS (
        SELECT
            locationid,
            -- replace(replace(toString(array), ' ', ''), '\', '') equivalent:
            replace(
                replace(
                    array_to_string(array_agg(pos_provider ORDER BY pos_provider), ','),
                ' ', ''),
            '\', '')                            AS pos_provider,
            count(*)::INTEGER                   AS number_of_pos_providers
        FROM pos_deduped
        GROUP BY locationid
    ),

    -- ── Loyalty providers ────────────────────────────────────
    loyalty_deduped AS (
        SELECT DISTINCT ON (locationid, loyalty_provider)
            locationid,
            loyalty_provider
        FROM stg.loyalty_configuration
        WHERE locationid IS NOT NULL
        ORDER BY locationid, loyalty_provider, syscosmosts DESC
    ),
    loyalty_agg AS (
        SELECT
            locationid,
            replace(
                replace(
                    array_to_string(array_agg(loyalty_provider ORDER BY loyalty_provider), ','),
                ' ', ''),
            '\', '')                            AS loyalty_provider
        FROM loyalty_deduped
        GROUP BY locationid
    ),

    -- ── Payment providers ────────────────────────────────────
    payment_deduped AS (
        SELECT DISTINCT ON (locationid, payment_provider)
            locationid,
            CASE
                WHEN payment_provider LIKE 'payment-integration-%'
                THEN substring(payment_provider FROM 21)  -- strips 'payment-integration-' (20 chars)
                ELSE payment_provider
            END AS payment_provider
        FROM stg.payment_provider
        WHERE locationid IS NOT NULL
        ORDER BY locationid, payment_provider, syscosmosts DESC
    ),
    payment_agg AS (
        SELECT
            locationid,
            replace(
                replace(
                    array_to_string(array_agg(payment_provider ORDER BY payment_provider), ','),
                ' ', ''),
            '\', '')                            AS payment_provider
        FROM payment_deduped
        GROUP BY locationid
    ),

    -- ── Kiosk config – most recent row per location ───────────
    kiosk_config AS (
        SELECT DISTINCT ON (locationid)
            locationid,
            legal_copy_enabled,
            calculate_default_modifier_price,
            track_kiosk_user_behavior,
            loyalty_feature,
            pickup_flow,
            pos_auto_applied_discount,
            search_functionality_enabled,
            recent_orders_enabled,
            round_up_for_charity,
            calories_enabled,
            scan_and_go_enabled,
            preorder_popup_enabled,
            perform_pos_status_check,
            scanners,
            item_special_request,
            ada_configuration,
            play_card_config,
            age_verification,
            tips_settings,
            business_hours_config,
            order_types,
            localization,
            loyalty_display_settings,
            order_limit_config,
            menu_behavior_config,
            preorder_popup_text,
            disclaimer_text
        FROM stg.kiosk_config
        WHERE locationid IS NOT NULL
        ORDER BY locationid, syscosmosts DESC
    ),

    -- ── Final join – all sources on locationid ────────────────
    combined AS (
        SELECT
            b.id,
            b.locationid,
            b.companyid,
            b.devicetype,
            b.syncversion,
            b.kiosks,
            b.syscosmosts,
            b.sysinserttime,

            p.pos_provider,
            p.number_of_pos_providers,
            l.loyalty_provider,
            py.payment_provider,

            kc.legal_copy_enabled,
            kc.calculate_default_modifier_price,
            kc.track_kiosk_user_behavior,
            kc.loyalty_feature,
            kc.pickup_flow,
            kc.pos_auto_applied_discount,
            kc.search_functionality_enabled,
            kc.recent_orders_enabled,
            kc.round_up_for_charity,
            kc.calories_enabled,
            kc.scan_and_go_enabled,
            kc.preorder_popup_enabled,
            kc.perform_pos_status_check,
            kc.scanners,
            kc.item_special_request,
            kc.ada_configuration,
            kc.play_card_config,
            kc.age_verification,
            kc.tips_settings,
            kc.business_hours_config,
            kc.order_types,
            kc.localization,
            kc.loyalty_display_settings,
            kc.order_limit_config,
            kc.menu_behavior_config,
            kc.preorder_popup_text,
            kc.disclaimer_text
        FROM            base            b
        LEFT JOIN       pos_agg         p   ON p.locationid   = b.locationid
        LEFT JOIN       loyalty_agg     l   ON l.locationid   = b.locationid
        LEFT JOIN       payment_agg     py  ON py.locationid  = b.locationid
        LEFT JOIN       kiosk_config    kc  ON kc.locationid  = b.locationid
    )

    -- ── Upsert into main dim ──────────────────────────────────
    INSERT INTO public.dim_kiosk_details
    (
        id, locationid, companyid, devicetype, syncversion, kiosks,
        syscosmosts, sysinserttime,
        pos_provider, number_of_pos_providers, loyalty_provider, payment_provider,
        legal_copy_enabled, calculate_default_modifier_price, track_kiosk_user_behavior,
        loyalty_feature, pickup_flow, pos_auto_applied_discount,
        search_functionality_enabled, recent_orders_enabled, round_up_for_charity,
        calories_enabled, scan_and_go_enabled, preorder_popup_enabled, perform_pos_status_check,
        scanners, item_special_request, ada_configuration, play_card_config, age_verification,
        tips_settings, business_hours_config, order_types, localization,
        loyalty_display_settings, order_limit_config, menu_behavior_config,
        preorder_popup_text, disclaimer_text,
        dwh_insert_time, dwh_update_time
    )
    SELECT
        id, locationid, companyid, devicetype, syncversion, kiosks,
        syscosmosts, sysinserttime,
        pos_provider, number_of_pos_providers, loyalty_provider, payment_provider,
        legal_copy_enabled, calculate_default_modifier_price, track_kiosk_user_behavior,
        loyalty_feature, pickup_flow, pos_auto_applied_discount,
        search_functionality_enabled, recent_orders_enabled, round_up_for_charity,
        calories_enabled, scan_and_go_enabled, preorder_popup_enabled, perform_pos_status_check,
        scanners, item_special_request, ada_configuration, play_card_config, age_verification,
        tips_settings, business_hours_config, order_types, localization,
        loyalty_display_settings, order_limit_config, menu_behavior_config,
        preorder_popup_text, disclaimer_text,
        NOW(), NOW()
    FROM combined

    ON CONFLICT (locationid) DO UPDATE SET
        id                                  = EXCLUDED.id,
        companyid                           = EXCLUDED.companyid,
        devicetype                          = EXCLUDED.devicetype,
        syncversion                         = EXCLUDED.syncversion,
        kiosks                              = EXCLUDED.kiosks,
        syscosmosts                         = EXCLUDED.syscosmosts,
        sysinserttime                       = EXCLUDED.sysinserttime,
        pos_provider                        = EXCLUDED.pos_provider,
        number_of_pos_providers             = EXCLUDED.number_of_pos_providers,
        loyalty_provider                    = EXCLUDED.loyalty_provider,
        payment_provider                    = EXCLUDED.payment_provider,
        legal_copy_enabled                  = EXCLUDED.legal_copy_enabled,
        calculate_default_modifier_price    = EXCLUDED.calculate_default_modifier_price,
        track_kiosk_user_behavior           = EXCLUDED.track_kiosk_user_behavior,
        loyalty_feature                     = EXCLUDED.loyalty_feature,
        pickup_flow                         = EXCLUDED.pickup_flow,
        pos_auto_applied_discount           = EXCLUDED.pos_auto_applied_discount,
        search_functionality_enabled        = EXCLUDED.search_functionality_enabled,
        recent_orders_enabled               = EXCLUDED.recent_orders_enabled,
        round_up_for_charity                = EXCLUDED.round_up_for_charity,
        calories_enabled                    = EXCLUDED.calories_enabled,
        scan_and_go_enabled                 = EXCLUDED.scan_and_go_enabled,
        preorder_popup_enabled              = EXCLUDED.preorder_popup_enabled,
        perform_pos_status_check            = EXCLUDED.perform_pos_status_check,
        scanners                            = EXCLUDED.scanners,
        item_special_request                = EXCLUDED.item_special_request,
        ada_configuration                   = EXCLUDED.ada_configuration,
        play_card_config                    = EXCLUDED.play_card_config,
        age_verification                    = EXCLUDED.age_verification,
        tips_settings                       = EXCLUDED.tips_settings,
        business_hours_config               = EXCLUDED.business_hours_config,
        order_types                         = EXCLUDED.order_types,
        localization                        = EXCLUDED.localization,
        loyalty_display_settings            = EXCLUDED.loyalty_display_settings,
        order_limit_config                  = EXCLUDED.order_limit_config,
        menu_behavior_config                = EXCLUDED.menu_behavior_config,
        preorder_popup_text                 = EXCLUDED.preorder_popup_text,
        disclaimer_text                     = EXCLUDED.disclaimer_text,
        dwh_update_time                     = NOW();

    GET DIAGNOSTICS v_rows_upserted = ROW_COUNT;

    -- ── Truncate staging after successful load ────────────────
    TRUNCATE TABLE
        stg.location_kiosks,
        stg.pos_provider,
        stg.loyalty_configuration,
        stg.payment_provider,
        stg.kiosk_config;

    RAISE NOTICE 'sp_refresh_dim_kiosk_details  |  rows upserted: %  |  duration: % ms',
        v_rows_upserted,
        EXTRACT(MILLISECONDS FROM (NOW() - v_start_time))::INTEGER;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'sp_refresh_dim_kiosk_details failed: %', SQLERRM;
END;
$BODY$;

-- ============================================================
-- ADF Pipeline order:
--   1. Copy Activity  →  stg.location_kiosks       (pre: truncate table)
--   2. Copy Activity  →  stg.pos_provider           (pre: truncate table)
--   3. Copy Activity  →  stg.loyalty_configuration  (pre: truncate table)
--   4. Copy Activity  →  stg.payment_provider       (pre: truncate table)
--   5. Copy Activity  →  stg.kiosk_config           (pre: truncate table)
--   6. Stored Procedure Activity  →  CALL public.sp_refresh_dim_kiosk_details();
-- ============================================================