-- ============================================================
-- Staging DDLs derived from ADF Dataflow: Orders Bronze → Silver
-- Schema: stg
-- Generated from: BronzeOrdersToSilverParquet dataflow sinks
-- ============================================================

CREATE SCHEMA IF NOT EXISTS stg;

-- ============================================================
-- 1. stg.silver_transaction_header
--    Source sink: SilverTrxnHeaderParquet
--    Branch: BronzeOrdersJson → TrxnHeaderColumns → SilverTransformTime
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.silver_transaction_header (
    -- Order identity
    transactionheaderid         TEXT COLLATE pg_catalog."default",
    orderid                     TEXT COLLATE pg_catalog."default",
    ordersessionid              TEXT COLLATE pg_catalog."default",
    orderdateutc                TEXT COLLATE pg_catalog."default",
    businessdate                TEXT COLLATE pg_catalog."default",
    syscosmosts                 BIGINT,

    -- Location / kiosk
    locationid                  TEXT COLLATE pg_catalog."default",
    kioskid                     TEXT COLLATE pg_catalog."default",
    kiosk_name                  TEXT COLLATE pg_catalog."default",
    kiosk_mode                  INTEGER,
    channel                     INTEGER,

    -- Concept
    concept_id                  TEXT COLLATE pg_catalog."default",
    concept_name                TEXT COLLATE pg_catalog."default",

    -- Order classification
    ordertype                   TEXT COLLATE pg_catalog."default",
    order_type_label            TEXT COLLATE pg_catalog."default",
    order_completion_status     TEXT COLLATE pg_catalog."default",
    pos_submission_status       INTEGER,
    is_send_to_pos_failed       BOOLEAN,
    is_test_order               BOOLEAN,

    -- Customer / identity
    frequentcustomerid          TEXT COLLATE pg_catalog."default",
    customername                TEXT COLLATE pg_catalog."default",
    client_ip_address           TEXT COLLATE pg_catalog."default",
    order_identity_order_token  TEXT COLLATE pg_catalog."default",
    order_identity_pos_order_token TEXT COLLATE pg_catalog."default",
    order_identity_phone        TEXT COLLATE pg_catalog."default",
    order_identity_phone_country_code TEXT COLLATE pg_catalog."default",
    order_identity_email        TEXT COLLATE pg_catalog."default",
    order_identity_table_tent   TEXT COLLATE pg_catalog."default",
    order_identity_device_imei  TEXT COLLATE pg_catalog."default",

    -- Guest & receipt
    guest_count                 INTEGER,
    guest_check_code            TEXT COLLATE pg_catalog."default",
    genesis_fiscal_fields       TEXT COLLATE pg_catalog."default",
    order_language              TEXT COLLATE pg_catalog."default",
    receipt_printing_type       TEXT COLLATE pg_catalog."default",

    -- Loyalty
    loyalty_transaction_id      TEXT COLLATE pg_catalog."default",
    loyalty_payment_transaction_id TEXT COLLATE pg_catalog."default",
    loyalty_earned_points       TEXT COLLATE pg_catalog."default",

    -- Local currency
    local_currency_code         TEXT COLLATE pg_catalog."default",
    local_currency_additional_info TEXT COLLATE pg_catalog."default",

    -- USD totals
    usd_amount                  NUMERIC(12,3),
    usd_subtotal                NUMERIC(12,3),
    usd_tax                     NUMERIC(12,3),
    usd_tip                     NUMERIC(12,3),
    usd_discount                NUMERIC(12,3),
    usd_reward                  NUMERIC(12,3),
    usd_service_charge          NUMERIC(12,3),
    usd_charity_amount          NUMERIC(12,3),

    -- Cent totals
    cents_amount                BIGINT,
    cents_subtotal              BIGINT,  -- mapped from usd_subtotal cents counterpart (not in totalsCents, kept for symmetry)
    cents_tax                   BIGINT,
    cents_tip                   BIGINT,
    cents_discount              BIGINT,
    cents_reward                BIGINT,
    cents_service_charge        BIGINT,
    cents_charity_amount        BIGINT,

    -- Lineage
    bronze_filepath             TEXT COLLATE pg_catalog."default",
    silver_transform_time       TEXT COLLATE pg_catalog."default",
    silver_folderpath           TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_transaction_header
    OWNER to citus;

-- ============================================================
-- 2. stg.silver_transaction_item
--    Source sink: SilverTrxnItemParquet
--    Branch: BronzeOrdersJson → TrxnItemColumns → flattenItemsArray → SilverTransformTime2
-- ============================================================
DROP TABLE IF EXISTS stg.silver_transaction_item;
CREATE TABLE IF NOT EXISTS stg.silver_transaction_item (
    -- Order / session identity
    transactionheaderid             TEXT COLLATE pg_catalog."default",
    orderid                         TEXT COLLATE pg_catalog."default",
    ordersessionid                  TEXT COLLATE pg_catalog."default",
    orderdateutc                    TEXT COLLATE pg_catalog."default",
    businessdate                    TEXT COLLATE pg_catalog."default",
    syscosmosts                     BIGINT,

    -- Location / kiosk
    locationid                      TEXT COLLATE pg_catalog."default",
    kioskid                         TEXT COLLATE pg_catalog."default",
    kiosk_name                      TEXT COLLATE pg_catalog."default",
    kiosk_mode                      INTEGER,
    is_test_order                   BOOLEAN,

    -- Item identity
    orderitemid                     TEXT COLLATE pg_catalog."default",
    itemsessionid                   TEXT COLLATE pg_catalog."default",
    menuitemid                      TEXT COLLATE pg_catalog."default",
    menu_item_pos_id                TEXT COLLATE pg_catalog."default",
    itemname                        TEXT COLLATE pg_catalog."default",
    categoryid                      TEXT COLLATE pg_catalog."default",
    categoryname                    TEXT COLLATE pg_catalog."default",
    category_pos_id                 TEXT COLLATE pg_catalog."default",

    -- Concept
    items_concept_id                TEXT COLLATE pg_catalog."default",
    items_concept_name              TEXT COLLATE pg_catalog."default",

    -- Pricing
    itemquantity                    INTEGER,
    usd_itemunitprice               NUMERIC(12,3),
    usd_total_item_price            NUMERIC(12,3),
    cents_itemunitprice             BIGINT,
    cents_total_item_price          BIGINT,

    -- Modifiers (kept as JSONB since array is further unrolled in a separate sink)
    modifier_options                         TEXT COLLATE pg_catalog."default",

    -- Discounts
    items_discount_id               TEXT COLLATE pg_catalog."default",
    is_items_discount_hidden_on_receipt BOOLEAN,
    items_discounts                 TEXT COLLATE pg_catalog."default",

    -- ML / upsell / loyalty signals
    items_upsell_source             TEXT COLLATE pg_catalog."default",
    items_reward_source             TEXT COLLATE pg_catalog."default",
    items_special_request           TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status         TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                 TEXT COLLATE pg_catalog."default",
    silver_transform_time           TEXT COLLATE pg_catalog."default",
    silver_folderpath               TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_transaction_item
    OWNER to citus;

-- ============================================================
-- 3. stg.silver_item_modifier
--    Source sink: SilverTrxnItemModifiersParquet
--    Branch: flattenItemsArray → FlattenModifiers → SilverTransformTime3
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.silver_item_modifier (
    -- Order / session identity
    transactionheaderid                 TEXT COLLATE pg_catalog."default",
    orderid                             TEXT COLLATE pg_catalog."default",
    ordersessionid                      TEXT COLLATE pg_catalog."default",
    orderdateutc                        TEXT COLLATE pg_catalog."default",
    businessdate                        TEXT COLLATE pg_catalog."default",
    syscosmosts                         BIGINT,

    -- Location / kiosk
    locationid                          TEXT COLLATE pg_catalog."default",
    kioskid                             TEXT COLLATE pg_catalog."default",
    kiosk_name                          TEXT COLLATE pg_catalog."default",
    kiosk_mode                          INTEGER,
    is_test_order                       BOOLEAN,

    -- Parent item identity
    orderitemid                         TEXT COLLATE pg_catalog."default",
    itemsessionid                       TEXT COLLATE pg_catalog."default",
    menuitemid                          TEXT COLLATE pg_catalog."default",
    menu_item_pos_id                    TEXT COLLATE pg_catalog."default",
    itemname                            TEXT COLLATE pg_catalog."default",
    categoryid                          TEXT COLLATE pg_catalog."default",
    categoryname                        TEXT COLLATE pg_catalog."default",
    category_pos_id                     TEXT COLLATE pg_catalog."default",

    -- Parent item pricing
    itemquantity                        INTEGER,
    usd_itemunitprice                   NUMERIC(12,3),
    usd_total_item_price                NUMERIC(12,3),
    cents_itemunitprice                 BIGINT,
    cents_total_item_price              BIGINT,

    -- Parent item discounts
    items_discount_id                   TEXT COLLATE pg_catalog."default",
    is_items_discount_hidden_on_receipt BOOLEAN,
    items_discounts                     TEXT COLLATE pg_catalog."default",

    -- Parent item signals
    items_upsell_source                 TEXT COLLATE pg_catalog."default",
    items_reward_source                 TEXT COLLATE pg_catalog."default",
    items_special_request               TEXT COLLATE pg_catalog."default",
    items_concept_id                    TEXT COLLATE pg_catalog."default",
    items_concept_name                  TEXT COLLATE pg_catalog."default",

    -- Modifier identity
    options_modifierid                  TEXT COLLATE pg_catalog."default",
    options_modifier_pos_id             TEXT COLLATE pg_catalog."default",
    options_modifiername                TEXT COLLATE pg_catalog."default",
    options_modifier_code               TEXT COLLATE pg_catalog."default",
    options_modifiergroupid             TEXT COLLATE pg_catalog."default",
    options_modifiergroupname           TEXT COLLATE pg_catalog."default",
    options_modifiergroup_pos_id        TEXT COLLATE pg_catalog."default",

    -- Modifier pricing
    options_modifierquantity            INTEGER,
    options_modifierunitprice           NUMERIC(12,3),
    options_total_modifierprice         NUMERIC(12,3),
    modifier_freequantity               INTEGER,

    -- Modifier flags
    is_modifier_invisible               BOOLEAN,
    is_modifier_default                 BOOLEAN,

    -- Order status
    order_completion_status             TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                     TEXT COLLATE pg_catalog."default",
    silver_transform_time               TEXT COLLATE pg_catalog."default",
    silver_folderpath                   TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_item_modifier
    OWNER to citus;

-- ============================================================
-- 4. stg.silver_transaction_payment
--    Source sink: SilverTrxnPaymentsParquet
--    Branch: BronzeOrdersJson → TrxnPaymentsColumns → flattenPayments → SilverTransformTime4
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.silver_transaction_payment (
    -- Order / session identity
    transactionheaderid             TEXT COLLATE pg_catalog."default",
    orderid                         TEXT COLLATE pg_catalog."default",
    ordersessionid                  TEXT COLLATE pg_catalog."default",
    orderdateutc                    TEXT COLLATE pg_catalog."default",
    businessdate                    TEXT COLLATE pg_catalog."default",
    syscosmosts                     BIGINT,

    -- Location / kiosk
    locationid                      TEXT COLLATE pg_catalog."default",
    kioskid                         TEXT COLLATE pg_catalog."default",
    kiosk_name                      TEXT COLLATE pg_catalog."default",
    kiosk_mode                      INTEGER,
    is_test_order                   BOOLEAN,

    -- Payment core
    payment_transactionid           TEXT COLLATE pg_catalog."default",
    payment_method                  TEXT COLLATE pg_catalog."default",
    payment_status                  TEXT COLLATE pg_catalog."default",
    payment_amount                  NUMERIC(12,3),
    payment_tender_id               TEXT COLLATE pg_catalog."default",
    payment_integration_id          TEXT COLLATE pg_catalog."default",
    payment_integration_label       TEXT COLLATE pg_catalog."default",
    payment_card_name               TEXT COLLATE pg_catalog."default",
    payment_card_number             TEXT COLLATE pg_catalog."default",
    is_amazon_one_payment           BOOLEAN,

    -- Card detail (from tenderInfo.cardInfo)
    card_info_card_type             TEXT COLLATE pg_catalog."default",
    card_info_last_four             TEXT COLLATE pg_catalog."default",
    card_info_masked_card_number    TEXT COLLATE pg_catalog."default",
    card_info_zip_code              TEXT COLLATE pg_catalog."default",
    card_info_expiration_month      TEXT COLLATE pg_catalog."default",
    card_info_expiration_year       TEXT COLLATE pg_catalog."default",
    card_info_processor_auth_code   TEXT COLLATE pg_catalog."default",
    card_info_available_balance     NUMERIC(12,3),

    -- Settlement / capture (string blobs from source)
    payment_capture_details         TEXT COLLATE pg_catalog."default",
    payment_settlement_details      TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status         TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                 TEXT COLLATE pg_catalog."default",
    silver_transform_time           TEXT COLLATE pg_catalog."default",
    silver_folderpath               TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_transaction_payment
    OWNER to citus;

-- ============================================================
-- 5. stg.silver_transaction_combo_item
--    Source sink: SilverTrxnItemComboItemsParquet
--    Branch: BronzeOrdersJson → TrxnComboColumns → flattenCombosArray
--            → flattenComponentSelectionsArray → SilverTransformTime5
-- ============================================================
--DROP TABLE stg.silver_transaction_combo_item
CREATE TABLE IF NOT EXISTS stg.silver_transaction_combo_items (
    -- Order / session identity
    transactionheaderid                     TEXT COLLATE pg_catalog."default",
    orderid                                 TEXT COLLATE pg_catalog."default",
    ordersessionid                          TEXT COLLATE pg_catalog."default",
    orderdateutc                            TEXT COLLATE pg_catalog."default",
    businessdate                            TEXT COLLATE pg_catalog."default",
    syscosmosts                             BIGINT,

    -- Location / kiosk
    locationid                              TEXT COLLATE pg_catalog."default",
    kioskid                                 TEXT COLLATE pg_catalog."default",
    kiosk_name                              TEXT COLLATE pg_catalog."default",
    kiosk_mode                              INTEGER,
    is_test_order                           BOOLEAN,

    -- Combo identity
    combo_id                                TEXT COLLATE pg_catalog."default",
    combo_pos_id                            TEXT COLLATE pg_catalog."default",
    combo_name                              TEXT COLLATE pg_catalog."default",
    combo_order_item_id                     TEXT COLLATE pg_catalog."default",
    combo_item_session_id                   TEXT COLLATE pg_catalog."default",
    combo_concept_id                        TEXT COLLATE pg_catalog."default",
    combo_concept_name                      TEXT COLLATE pg_catalog."default",

    -- Combo pricing (source defines these as double despite "cents" naming)
    cents_combo_unit_price                  NUMERIC(12,3),
    cents_combo_total_price                 NUMERIC(12,3),
    combo_quantity                          INTEGER,

    -- Combo signals
    combo_special_request                   TEXT COLLATE pg_catalog."default",
    combo_upsell_source                     TEXT COLLATE pg_catalog."default",
    combo_reward_source                     TEXT COLLATE pg_catalog."default",

    -- Component selection identity
    component_id                            TEXT COLLATE pg_catalog."default",
    component_pos_id                        TEXT COLLATE pg_catalog."default",
    component_name                          TEXT COLLATE pg_catalog."default",

    -- Component item identity
    component_item_order_item_id            TEXT COLLATE pg_catalog."default",
    component_item_menu_item_id             TEXT COLLATE pg_catalog."default",
    component_item_name                     TEXT COLLATE pg_catalog."default",
    component_item_menu_item_pos_id         TEXT COLLATE pg_catalog."default",
    component_item_session_id               TEXT COLLATE pg_catalog."default",
    component_item_concept_id              TEXT COLLATE pg_catalog."default",
    component_item_concept_name            TEXT COLLATE pg_catalog."default",

    -- Component item pricing
    component_item_quantity                 INTEGER,
    component_item_price                    NUMERIC(12,3),
    component_item_unit_price               NUMERIC(12,3),
    component_item_cents_unit_price         BIGINT,
    component_item_total_price              NUMERIC(12,3),
    component_item_cents_total_price        BIGINT,

    -- Component item signals
    component_item_special_request          TEXT COLLATE pg_catalog."default",
    component_item_upsell_source            TEXT COLLATE pg_catalog."default",
    component_item_reward_source            TEXT COLLATE pg_catalog."default",
    component_item_discount_id              TEXT COLLATE pg_catalog."default",
    is_component_item_discount_hidden_on_receipt BOOLEAN,
    component_item_discounts                TEXT COLLATE pg_catalog."default",

    -- Sub-items within component selections (nested array → JSONB)
    component_selections_items              TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status                 TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                         TEXT COLLATE pg_catalog."default",
    silver_transform_time                   TEXT COLLATE pg_catalog."default",
    silver_folderpath                       TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;


ALTER TABLE IF EXISTS stg.silver_transaction_combo_items
    OWNER to citus;

-- ============================================================
-- 6. stg.silver_upsell_recommendation
--    Source sink: SilverUpsellRecommendationsParquet
--    Branch: BronzeOrdersJson → ItemUpsellRecommColumns → flattenUpsellPrompt → SilverTransformTime6
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.silver_upsell_recommendations (
    -- Order / session identity
    transactionheaderid         TEXT COLLATE pg_catalog."default",
    orderid                     TEXT COLLATE pg_catalog."default",
    ordersessionid              TEXT COLLATE pg_catalog."default",
    orderdateutc                TEXT COLLATE pg_catalog."default",
    businessdate                TEXT COLLATE pg_catalog."default",
    syscosmosts                 BIGINT,

    -- Location / kiosk
    locationid                  TEXT COLLATE pg_catalog."default",
    kioskid                     TEXT COLLATE pg_catalog."default",
    kiosk_name                  TEXT COLLATE pg_catalog."default",
    kiosk_mode                  INTEGER,
    is_test_order               BOOLEAN,

    -- Upsell prompt
    recommendationid            TEXT COLLATE pg_catalog."default",
    prompttimestamp             TEXT COLLATE pg_catalog."default",
    modal_version               TEXT COLLATE pg_catalog."default",

    -- Offered and selected items (nested arrays → JSONB)
    offered_items               TEXT COLLATE pg_catalog."default",
    selected_items              TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status     TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath             TEXT COLLATE pg_catalog."default",
    silver_transform_time       TEXT COLLATE pg_catalog."default",
    silver_folderpath           TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_upsell_recommendations
    OWNER to citus;

-- ============================================================
-- 7. stg.silver_modifier_recommendation
--    Source sink: SilverModifierRecommendationsParquet
--    Branch: BronzeOrdersJson → ModifierRecommendations → SilverTransformTime7
--    Note: raw modifier_interactions + modifier_impressions arrays,
--          before the further unrolling that produces sinks 8 and 9.
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.silver_modifier_recommendations (
    -- Order / session identity
    transactionheaderid         TEXT COLLATE pg_catalog."default",
    orderid                     TEXT COLLATE pg_catalog."default",
    ordersessionid              TEXT COLLATE pg_catalog."default",
    orderdateutc                TEXT COLLATE pg_catalog."default",
    businessdate                TEXT COLLATE pg_catalog."default",
    syscosmosts                 BIGINT,

    -- Location / kiosk
    locationid                  TEXT COLLATE pg_catalog."default",
    kioskid                     TEXT COLLATE pg_catalog."default",
    kiosk_name                  TEXT COLLATE pg_catalog."default",
    kiosk_mode                  INTEGER,
    is_test_order               BOOLEAN,

    -- Raw nested arrays (not further unrolled in this sink)
    modifier_interactions       TEXT COLLATE pg_catalog."default",
    modifier_impressions        TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status     TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath             TEXT COLLATE pg_catalog."default",
    silver_transform_time       TEXT COLLATE pg_catalog."default",
    silver_folderpath           TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;


ALTER TABLE IF EXISTS stg.silver_modifier_recommendations
    OWNER to citus;

-- ============================================================
-- 8. stg.silver_modifier_interaction
--    Source sink: SilverModifierInteractionsParquet
--    Branch: ModifierRecommendations → ModifierInteractions → SilverTransformTime8
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.silver_modifier_interactions (
    -- Order / session identity
    transactionheaderid                     TEXT COLLATE pg_catalog."default",
    orderid                                 TEXT COLLATE pg_catalog."default",
    ordersessionid                          TEXT COLLATE pg_catalog."default",
    orderdateutc                            TEXT COLLATE pg_catalog."default",
    businessdate                            TEXT COLLATE pg_catalog."default",
    syscosmosts                             BIGINT,

    -- Location / kiosk
    locationid                              TEXT COLLATE pg_catalog."default",
    kioskid                                 TEXT COLLATE pg_catalog."default",
    kiosk_name                              TEXT COLLATE pg_catalog."default",
    kiosk_mode                              INTEGER,
    is_test_order                           BOOLEAN,

    -- Interaction detail
    menuitemid                              TEXT COLLATE pg_catalog."default",
    modifierid                              TEXT COLLATE pg_catalog."default",
    modifiergroupid                         TEXT COLLATE pg_catalog."default",
    parent_modifier_id                      TEXT COLLATE pg_catalog."default",
    selection_type                          TEXT COLLATE pg_catalog."default",
    modifier_interactions_action            TEXT COLLATE pg_catalog."default",
    modifier_interactions_recorded_at       TEXT COLLATE pg_catalog."default",
    modifier_interactions_nesting_depth     INTEGER,

    -- Order status
    order_completion_status                 TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                         TEXT COLLATE pg_catalog."default",
    silver_transform_time                   TEXT COLLATE pg_catalog."default",
    silver_folderpath                       TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_modifier_interactions
    OWNER to citus;

-- ============================================================
-- 9. stg.silver_modifier_impression
--    Source sink: SilverModifierImpressionsParquet
--    Branch: ModifierRecommendations → ModifierImpressions
--            → ImpressionRecommendations → SilverTransformTime9
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.silver_modifier_impressions (
    -- Order / session identity
    transactionheaderid                     TEXT COLLATE pg_catalog."default",
    orderid                                 TEXT COLLATE pg_catalog."default",
    ordersessionid                          TEXT COLLATE pg_catalog."default",
    orderdateutc                            TEXT COLLATE pg_catalog."default",
    businessdate                            TEXT COLLATE pg_catalog."default",
    syscosmosts                             BIGINT,

    -- Location / kiosk
    locationid                              TEXT COLLATE pg_catalog."default",
    kioskid                                 TEXT COLLATE pg_catalog."default",
    kiosk_name                              TEXT COLLATE pg_catalog."default",
    kiosk_mode                              INTEGER,
    is_test_order                           BOOLEAN,

    -- Impression context
    menuitemid                              TEXT COLLATE pg_catalog."default",
    parentmodifierid                        TEXT COLLATE pg_catalog."default",
    selection_type                          TEXT COLLATE pg_catalog."default",
    modifier_impressions_nesting_depth      INTEGER,
    modifier_impressions_context            TEXT COLLATE pg_catalog."default",
    strategy                                TEXT COLLATE pg_catalog."default",

    -- Recommendation row (unrolled from recommendations array)
    modifierid                              TEXT COLLATE pg_catalog."default",
    score                                   INTEGER,
    position                                INTEGER,
    selected                                BOOLEAN,
    pre_selected                            BOOLEAN,
    pre_deselected                          BOOLEAN,
    confirmed_removed                       BOOLEAN,

    -- Order status
    order_completion_status                 TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                         TEXT COLLATE pg_catalog."default",
    silver_transform_time                   TEXT COLLATE pg_catalog."default",
    silver_folderpath                       TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_modifier_impressions
    OWNER to citus;