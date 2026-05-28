CALL dim.usp_refresh_dim_location_kiosk_details();

-- Table: dim.kioskdetails

-- DROP TABLE IF EXISTS dim.kioskdetails;

--SELECT * FROM dim.kioskdetails LIMIT 100;

SELECT * FROM dim.kioskdetails LIMIT 100;
SELECT * FROM stg.dim_location_kiosks LIMIT 100;
SELECT * FROM stg.dim_pos_provider LIMIT 100;
SELECT * FROM stg.dim_loyalty_configuration LIMIT 100;
SELECT * FROM stg.dim_payment_provider LIMIT 100;
SELECT * FROM stg.dim_kiosk_config LIMIT 100;
SELECT * FROM stg.dim_kiosk_appearance LIMIT 100;
SELECT NOW()

ALTER TABLE IF EXISTS dim.kioskdetails
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

CREATE TABLE IF NOT EXISTS dim.kioskdetails
(
    id text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,
    kiosks text COLLATE pg_catalog."default",
    devicetype text COLLATE pg_catalog."default",
    syncversion text COLLATE pg_catalog."default",
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    pos_provider text COLLATE pg_catalog."default",
    loyalty_provider text COLLATE pg_catalog."default",
    payment_provider text COLLATE pg_catalog."default",
    scanners text COLLATE pg_catalog."default",
    item_special_request text COLLATE pg_catalog."default",
    legal_copy_enabled boolean,
    ada_configuration text COLLATE pg_catalog."default",
    calculate_default_modifier_price boolean,
    track_kiosk_user_behavior boolean,
    loyalty_feature boolean,
    pickup_flow boolean,
    pos_auto_applied_discount boolean,
    search_functionality_enabled boolean,
    recent_orders_enabled boolean,
    play_card_config text COLLATE pg_catalog."default",
    round_up_for_charity boolean,
    calories_enabled boolean,
    scan_and_go_enabled boolean,
    age_verification text COLLATE pg_catalog."default",
    tips_settings text COLLATE pg_catalog."default",
    business_hours_config text COLLATE pg_catalog."default",
    order_types text COLLATE pg_catalog."default",
    localization text COLLATE pg_catalog."default",
    kiosk_receipt_settings text COLLATE pg_catalog."default",
    kiosk_fonts text COLLATE pg_catalog."default",
    kiosk_appearance_text_overrides text COLLATE pg_catalog."default",
    kiosk_appearance_style_options text COLLATE pg_catalog."default",
    loyalty_display_settings text COLLATE pg_catalog."default",
    preorder_popup_enabled boolean,
    preorder_popup_text text COLLATE pg_catalog."default",
    disclaimer_text text COLLATE pg_catalog."default",
    order_limit_config text COLLATE pg_catalog."default",
    menu_behavior_config text COLLATE pg_catalog."default",
    perform_pos_status_check boolean,
    CONSTRAINT locationid_pkey PRIMARY KEY (locationid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.kioskdetails
    OWNER to citus;


-- Stage 1: Location Kiosks (core dim rows)
CREATE TABLE IF NOT EXISTS stg.dim_location_kiosks (
    id              TEXT,
    locationid      TEXT,
    companyid       TEXT,
    devicetype      TEXT,
    syncversion     TEXT,
    kiosks          TEXT,
    syscosmosts     BIGINT,
    sysinserttime   TIMESTAMP
);

ALTER TABLE IF EXISTS stg.dim_location_kiosks
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;


-- Stage 2: POS Provider
CREATE TABLE IF NOT EXISTS stg.dim_pos_provider (
    locationid      TEXT,
    pos_provider    TEXT,
    syscosmosts     BIGINT,
    sysinserttime   TIMESTAMP
);

ALTER TABLE IF EXISTS stg.dim_pos_provider
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;

-- Stage 3: Loyalty Configuration
CREATE TABLE IF NOT EXISTS stg.dim_loyalty_configuration (
    locationid          TEXT,
    loyalty_provider    TEXT,
    syscosmosts         BIGINT,
    sysinserttime       TIMESTAMP
);

ALTER TABLE IF EXISTS stg.dim_loyalty_configuration
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;

-- Stage 4: Payment Provider
CREATE TABLE IF NOT EXISTS stg.dim_payment_provider (
    locationid          TEXT,
    payment_provider    TEXT,
    syscosmosts         BIGINT,
    sysinserttime       TIMESTAMP
);


ALTER TABLE IF EXISTS stg.dim_payment_provider
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;

-- Stage 5: Kiosk Config (scanner flags + feature flags)
CREATE TABLE IF NOT EXISTS stg.dim_kiosk_config (
    locationid                      TEXT,
    scanners                        TEXT,
    item_special_request            TEXT,
    legal_copy_enabled              BOOLEAN,
    ada_configuration               TEXT,
    calculate_default_modifier_price BOOLEAN,
    track_kiosk_user_behavior       BOOLEAN,
    loyalty_feature                 BOOLEAN,
    pickup_flow                     BOOLEAN,
    pos_auto_applied_discount       BOOLEAN,
    search_functionality_enabled    BOOLEAN,
    recent_orders_enabled           BOOLEAN,
    play_card_config                TEXT,
    round_up_for_charity            BOOLEAN,
    calories_enabled                BOOLEAN,
    scan_and_go_enabled             BOOLEAN,
    age_verification                TEXT,
    tips_settings                   TEXT,
    business_hours_config           TEXT,
    order_types                     TEXT,
    localization                    TEXT,
    loyalty_display_settings        TEXT,
    preorder_popup_enabled          BOOLEAN,
    preorder_popup_text             TEXT,
    disclaimer_text                 TEXT,
    order_limit_config              TEXT,
    menu_behavior_config            TEXT,
    perform_pos_status_check        BOOLEAN,
    syscosmosts                     BIGINT,
    sysinserttime                   TIMESTAMP
);

ALTER TABLE IF EXISTS stg.dim_kiosk_config
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;

-- Stage 6: Kiosk Appearance
CREATE TABLE IF NOT EXISTS stg.dim_kiosk_appearance (
    locationid                      TEXT,
    kiosk_receipt_settings          TEXT,
    kiosk_fonts                     TEXT,
    kiosk_appearance_text_overrides TEXT,
    kiosk_appearance_style_options  TEXT,
    syscosmosts                     BIGINT,
    sysinserttime                   TIMESTAMP
);


ALTER TABLE IF EXISTS stg.dim_kiosk_appearance
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;


--SELECT SUBSTRING('pid-square' FROM 5)



CREATE OR REPLACE PROCEDURE dim.usp_refresh_location_kiosk_details()
LANGUAGE plpgsql
AS $$
BEGIN

    ---------------------------------------------------------------------------
    -- STEP 1: UPSERT core kiosk rows from stg.dim_location_kiosks
    ---------------------------------------------------------------------------
    INSERT INTO dim.kioskdetails (
        id,
        locationid,
        devicetype,
        syncversion,
        kiosks,
        syscosmosts,
        sysinserttime
    )
    SELECT
        id,
        locationid,
        devicetype,
        syncversion,
        kiosks,
        syscosmosts,
        NOW()
    FROM stg.dim_location_kiosks
    ON CONFLICT (locationid) DO UPDATE SET
        id             = EXCLUDED.id,
        devicetype     = EXCLUDED.devicetype,
        syncversion    = EXCLUDED.syncversion,
        kiosks         = EXCLUDED.kiosks,
        syscosmosts    = EXCLUDED.syscosmosts,
        sysupdatetime  = NOW();

    ---------------------------------------------------------------------------
    -- STEP 2: UPDATE pos_provider from stg.dim_pos_provider
    ---------------------------------------------------------------------------
    WITH deduped AS (
        SELECT DISTINCT ON (locationid, pos_provider)
            locationid,
            CASE
                WHEN LOWER(pos_provider) LIKE 'pid-%'
                    THEN SUBSTRING(pos_provider FROM 5)
                ELSE pos_provider
            END AS pos_provider
        FROM stg.dim_pos_provider
        ORDER BY locationid, pos_provider, syscosmosts DESC
    ),
    aggregated AS (
        SELECT
            locationid,
            JSONB_AGG(pos_provider)::TEXT AS pos_provider
        FROM deduped
        GROUP BY locationid
    )
    UPDATE dim.kioskdetails d
    SET
        pos_provider  = a.pos_provider,
        sysupdatetime = NOW()
    FROM aggregated a
    WHERE d.locationid = a.locationid;

    ---------------------------------------------------------------------------
    -- STEP 3: UPDATE loyalty_provider from stg.dim_loyalty_configuration
    ---------------------------------------------------------------------------
    WITH deduped AS (
        SELECT DISTINCT ON (locationid, loyalty_provider)
            locationid,
            loyalty_provider
        FROM stg.dim_loyalty_configuration
        ORDER BY locationid, loyalty_provider, syscosmosts DESC
    ),
    aggregated AS (
        SELECT
            locationid,
            JSONB_AGG(loyalty_provider)::TEXT AS loyalty_provider
        FROM deduped
        GROUP BY locationid
    )
    UPDATE dim.kioskdetails d
    SET
        loyalty_provider = a.loyalty_provider,
        sysupdatetime    = NOW()
    FROM aggregated a
    WHERE d.locationid = a.locationid;

    ---------------------------------------------------------------------------
    -- STEP 4: UPDATE payment_provider from stg.dim_payment_provider
    ---------------------------------------------------------------------------
    WITH deduped AS (
        SELECT DISTINCT ON (locationid, payment_provider)
            locationid,
            CASE
                WHEN LOWER(payment_provider) LIKE 'payment-integration-%'
                    THEN SUBSTRING(payment_provider FROM 21)
                ELSE payment_provider
            END AS payment_provider
        FROM stg.dim_payment_provider
        ORDER BY locationid, payment_provider, syscosmosts DESC
    ),
    aggregated AS (
        SELECT
            locationid,
            JSONB_AGG(payment_provider)::TEXT AS payment_provider
        FROM deduped
        GROUP BY locationid
    )
    UPDATE dim.kioskdetails d
    SET
        payment_provider = a.payment_provider,
        sysupdatetime    = NOW()
    FROM aggregated a
    WHERE d.locationid = a.locationid;

    ---------------------------------------------------------------------------
    -- STEP 5: UPDATE kiosk config + feature flags from stg.dim_kiosk_config
    ---------------------------------------------------------------------------
    WITH latest AS (
        SELECT DISTINCT ON (locationid)
            locationid,
            scanners,
            item_special_request,
            legal_copy_enabled,
            ada_configuration,
            calculate_default_modifier_price,
            track_kiosk_user_behavior,
            loyalty_feature,
            pickup_flow,
            pos_auto_applied_discount,
            search_functionality_enabled,
            recent_orders_enabled,
            play_card_config,
            round_up_for_charity,
            calories_enabled,
            scan_and_go_enabled,
            age_verification,
            tips_settings,
            business_hours_config,
            order_types,
            localization,
            loyalty_display_settings,
            preorder_popup_enabled,
            preorder_popup_text,
            disclaimer_text,
            order_limit_config,
            menu_behavior_config,
            perform_pos_status_check
        FROM stg.dim_kiosk_config
        ORDER BY locationid, syscosmosts DESC
    )
    UPDATE dim.kioskdetails d
    SET
        scanners                         = l.scanners,
        item_special_request             = l.item_special_request,
        legal_copy_enabled               = l.legal_copy_enabled,
        ada_configuration                = l.ada_configuration,
        calculate_default_modifier_price = l.calculate_default_modifier_price,
        track_kiosk_user_behavior        = l.track_kiosk_user_behavior,
        loyalty_feature                  = l.loyalty_feature,
        pickup_flow                      = l.pickup_flow,
        pos_auto_applied_discount        = l.pos_auto_applied_discount,
        search_functionality_enabled     = l.search_functionality_enabled,
        recent_orders_enabled            = l.recent_orders_enabled,
        play_card_config                 = l.play_card_config,
        round_up_for_charity             = l.round_up_for_charity,
        calories_enabled                 = l.calories_enabled,
        scan_and_go_enabled              = l.scan_and_go_enabled,
        age_verification                 = l.age_verification,
        tips_settings                    = l.tips_settings,
        business_hours_config            = l.business_hours_config,
        order_types                      = l.order_types,
        localization                     = l.localization,
        loyalty_display_settings         = l.loyalty_display_settings,
        preorder_popup_enabled           = l.preorder_popup_enabled,
        preorder_popup_text              = l.preorder_popup_text,
        disclaimer_text                  = l.disclaimer_text,
        order_limit_config               = l.order_limit_config,
        menu_behavior_config             = l.menu_behavior_config,
        perform_pos_status_check         = l.perform_pos_status_check,
        sysupdatetime                    = NOW()
    FROM latest l
    WHERE d.locationid = l.locationid;

    ---------------------------------------------------------------------------
    -- STEP 6: UPDATE appearance fields from stg.dim_kiosk_appearance
    ---------------------------------------------------------------------------
    WITH latest AS (
        SELECT DISTINCT ON (locationid)
            locationid,
            kiosk_receipt_settings,
            kiosk_fonts,
            kiosk_appearance_text_overrides,
            kiosk_appearance_style_options
        FROM stg.dim_kiosk_appearance
        ORDER BY locationid, syscosmosts DESC
    )
    UPDATE dim.kioskdetails d
    SET
        kiosk_receipt_settings          = l.kiosk_receipt_settings,
        kiosk_fonts                     = l.kiosk_fonts,
        kiosk_appearance_text_overrides = l.kiosk_appearance_text_overrides,
        kiosk_appearance_style_options  = l.kiosk_appearance_style_options,
        sysupdatetime                   = NOW()
    FROM latest l
    WHERE d.locationid = l.locationid;

END;
$$;

ALTER PROCEDURE dim.usp_refresh_location_kiosk_details() OWNER TO citus;