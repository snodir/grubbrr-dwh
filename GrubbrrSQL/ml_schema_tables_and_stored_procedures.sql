-- ============================================================
-- Smart Upsells ML Training Data
-- Schema: ml
-- Description : 10 dedicated tables + 10 stored procedures
--               to pre-materialise training data daily.
--
-- Static datasets (no weekly param)  - full TRUNCATE + INSERT
--   1.  ml.frequent_customers        frequentcustomers.parquet
--   2.  ml.location_stats            location.parquet
--   3.  ml.master_items              master-items.parquet
--
-- Weekly datasets (p_businessdate)   - DELETE week + INSERT
--   4.  ml.transactions              data-yyww.parquet
--   5.  ml.upsell_analysis           upsell-analysis-yyww.parquet
--   6.  ml.weather                   weather-yyww.parquet
--   7.  ml.menu_entities             menu-entities-yyww.parquet
--   8.  ml.modifier_interactions     modifier-interactions-yyww.parquet
--   9.  ml.modifier_impressions      modifier-impressions-yyww.parquet
--  10.  ml.item_modifier_mapping     item-modifiergroup-modifier-mapping-yyww.parquet
--
-- Scheduling:  All procs are designed to be called daily.
--              Static procs: call without arguments.
--              Weekly procs: call with the target business date
--              (defaults to CURRENT_DATE - 1 when omitted).
--              Each weekly proc is fully idempotent – re-running
--              for the same week deletes and re-inserts safely.
-- ============================================================


-- ============================================================
-- 0. SCHEMA
-- ============================================================
CREATE SCHEMA IF NOT EXISTS ml;


-- ============================================================
-- TABLE 1: ml.frequent_customers
-- Granularity : one row per (organization, frequent-customer)
-- Refresh     : full (no date dimension in output)
-- Parquet file: frequentcustomers.parquet
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.frequent_customers (
    organizationid                    TEXT COLLATE pg_catalog."default",          NOT NULL,
    organizationname                  TEXT COLLATE pg_catalog."default",
    frequentcustomerid                TEXT COLLATE pg_catalog."default",          NOT NULL,
    firstname                         TEXT COLLATE pg_catalog."default",
    lastname                          TEXT COLLATE pg_catalog."default",
    email                             TEXT COLLATE pg_catalog."default",
    phone                             TEXT COLLATE pg_catalog."default",
    source                            TEXT COLLATE pg_catalog."default",
    ordercount                        INTEGER,
    amountspent                       NUMERIC(14,4),
    avg_amount_spent                  NUMERIC(14,4),
    loc_specific_favorite_items_jsonb JSONB,
    overall_favorite_items_jsonb      JSONB,
    static_upsell_stats_jsonb         JSONB,
    sysinserttime                     TIMESTAMP,
    sysupdatetime                     TIMESTAMP,
    CONSTRAINT pk_ml_frequent_customers
        PRIMARY KEY (organizationid, frequentcustomerid)
);

CREATE INDEX IF NOT EXISTS ix_ml_fc_orgid
    ON ml.frequent_customers (organizationid);


-- ============================================================
-- TABLE 2: ml.location_stats
-- Granularity : one row per location
-- Refresh     : full (no date dimension in output)
-- Parquet file: location.parquet
-- Note        : upstream proc fact.usp_location_statistics()
--               is called first to refresh fact.location_statistics
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.location_stats (
    organizationid                     TEXT COLLATE pg_catalog."default",          NOT NULL,
    organizationname                   TEXT COLLATE pg_catalog."default",
    locationid                         TEXT COLLATE pg_catalog."default",          NOT NULL,
    locationname                       TEXT COLLATE pg_catalog."default",
    city                               TEXT COLLATE pg_catalog."default",
    state                              TEXT COLLATE pg_catalog."default",
    country                            TEXT COLLATE pg_catalog."default",
    isactive                           BOOLEAN,
    timezone                           TEXT COLLATE pg_catalog."default",
    order_type_labels                  JSONB,
    loc_item_popularity                JSONB,
    loc_total_order_count              BIGINT,
    loc_total_sales_amount             NUMERIC(16,4),
    loc_avg_order_amount               NUMERIC(12,4),
    org_total_order_count              BIGINT,
    org_total_sales_amount             NUMERIC(16,4),
    org_avg_order_amount               NUMERIC(12,4),
    number_of_frequent_customers       BIGINT,
    orders_placed_by_freq_customers    BIGINT,
    amount_spent_by_freq_customers     NUMERIC(16,4),
    avg_amount_spent_by_freq_customers NUMERIC(12,4),
    sysinserttime                      TIMESTAMP,
    sysupdatetime                      TIMESTAMP,
    CONSTRAINT pk_ml_location_stats
        PRIMARY KEY (locationid)
);

CREATE INDEX IF NOT EXISTS ix_ml_ls_orgid
    ON ml.location_stats (organizationid);


-- ============================================================
-- TABLE 3: ml.master_items
-- Granularity : one row per (location, category, menu-item)
-- Refresh     : full (no date dimension in output)
-- Parquet file: master-items.parquet
-- Note        : upstream proc dim.usp_master_keys_for_duplicate_items()
--               is called first to refresh dim.duplicate_items_master
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.master_items (
    organizationid   TEXT COLLATE pg_catalog."default"      NOT NULL,
    organizationname TEXT COLLATE pg_catalog."default",
    locationid       TEXT COLLATE pg_catalog."default"      NOT NULL,
    locationname     TEXT COLLATE pg_catalog."default",
    catalogid        TEXT COLLATE pg_catalog."default",
    catalogname      TEXT COLLATE pg_catalog."default",
    categoryid       TEXT COLLATE pg_catalog."default"      NOT NULL,
    categoryname     TEXT COLLATE pg_catalog."default",
    menuitemid       TEXT COLLATE pg_catalog."default"      NOT NULL,
    is_item_active   BOOLEAN,
    is_item_deleted  BOOLEAN,
    entitytype       TEXT COLLATE pg_catalog."default",
    item_class_type  TEXT COLLATE pg_catalog."default",
    menuitemname     TEXT COLLATE pg_catalog."default",
    instance_count   BIGINT,
    masteritemid     TEXT COLLATE pg_catalog."default",
    sysinserttime    TIMESTAMP,
    sysupdatetime    TIMESTAMP,
    CONSTRAINT pk_ml_master_items
        PRIMARY KEY (locationid, categoryid, menuitemid)
);

CREATE INDEX IF NOT EXISTS ix_ml_mi_orgid
    ON ml.master_items (organizationid);


-- ============================================================
-- TABLE 4: ml.transactions
-- Granularity : one row per (transaction, order-item)
-- Refresh     : weekly (keyed by yyyy + ww derived from businessdate)
-- Parquet file: data-yyww.parquet
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.transactions (
    frequentcustomerid   TEXT COLLATE pg_catalog."default",
    organizationid       TEXT COLLATE pg_catalog."default",
    organizationname     TEXT COLLATE pg_catalog."default",
    locationid           TEXT COLLATE pg_catalog."default",
    locationname         TEXT COLLATE pg_catalog."default",
    kioskid              TEXT COLLATE pg_catalog."default",
    transactionheaderid  TEXT COLLATE pg_catalog."default",
    orderitemid          TEXT COLLATE pg_catalog."default",
    menuitemid           TEXT COLLATE pg_catalog."default",
    itemname             TEXT COLLATE pg_catalog."default",
    upselllevel          TEXT COLLATE pg_catalog."default",
    item_class_type      TEXT COLLATE pg_catalog."default",
    itemquantity         NUMERIC(10,3),
    categoryid           TEXT COLLATE pg_catalog."default",
    categoryname         TEXT COLLATE pg_catalog."default",
    itemunitprice        NUMERIC(12,4),
    paymentstatus        TEXT COLLATE pg_catalog."default",
    numberofitems        INTEGER,
    numberofpayments     INTEGER,
    ordertotal           NUMERIC(14,4),
    ordersubtotal        NUMERIC(14,4),
    ordertip             NUMERIC(14,4),
    ordertax             NUMERIC(14,4),
    ordertypelabel       TEXT COLLATE pg_catalog."default",
    orderdatelocal       TIMESTAMP,
    businessdate         DATE,
    weatherhumidity      NUMERIC(7,2),
    weathercondition     TEXT COLLATE pg_catalog."default",
    temperatureincelcius NUMERIC(7,2),
    yyyy                 INTEGER,
    mm                   INTEGER,
    dd                   INTEGER,
    hh                   INTEGER,
    ww                   INTEGER,
    sysinserttime        TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_ml_trx_yyyy_ww
    ON ml.transactions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_trx_locid_yyyy_ww
    ON ml.transactions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_trx_businessdate
    ON ml.transactions (businessdate);


-- ============================================================
-- TABLE 5: ml.upsell_analysis
-- Granularity : one row per upsell recommendation event
-- Refresh     : weekly
-- Parquet file: upsell-analysis-yyww.parquet
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.upsell_analysis (
    organizationid      TEXT COLLATE pg_catalog."default",
    organizationname    TEXT COLLATE pg_catalog."default",
    locationid          TEXT COLLATE pg_catalog."default",
    locationname        TEXT COLLATE pg_catalog."default",
    frequentcustomerid  TEXT COLLATE pg_catalog."default",
    transactionheaderid TEXT COLLATE pg_catalog."default",
    recommendationid    TEXT COLLATE pg_catalog."default",
    offereditem         TEXT COLLATE pg_catalog."default",
    selecteditem        TEXT COLLATE pg_catalog."default",
    item_class_type     TEXT COLLATE pg_catalog."default",
    upselltype          TEXT COLLATE pg_catalog."default",
    quantity            NUMERIC(10,3),
    businessdate        DATE,
    orderdatelocal      TIMESTAMP,
    yyyy                INTEGER,
    mm                  INTEGER,
    dd                  INTEGER,
    hh                  INTEGER,
    ww                  INTEGER,
    sysinserttime       TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_ml_ua_yyyy_ww
    ON ml.upsell_analysis (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_ua_locid_yyyy_ww
    ON ml.upsell_analysis (locationid, yyyy, ww);


-- ============================================================
-- TABLE 6: ml.weather
-- Granularity : one row per (location, date, hour)
-- Refresh     : weekly  (date column = weatherdate)
-- Parquet file: weather-yyww.parquet
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.weather (
    organizationid               TEXT COLLATE pg_catalog."default",
    organizationname             TEXT COLLATE pg_catalog."default",
    locationid                   TEXT COLLATE pg_catalog."default",
    locationname                 TEXT COLLATE pg_catalog."default",
    weatherdate                  DATE,
    yyyy                         INTEGER,
    mm                           INTEGER,
    dd                           INTEGER,
    ww                           INTEGER,
    hh                           INTEGER,
    humidity                     NUMERIC(7,2),
    condition                    TEXT COLLATE pg_catalog."default",
    temperature_c                NUMERIC(7,2),
    is_hot                       BOOLEAN,
    is_calm                      BOOLEAN,
    is_cold                      BOOLEAN,
    is_cool                      BOOLEAN,
    is_mild                      BOOLEAN,
    is_warm                      BOOLEAN,
    rain_mm                      NUMERIC(8,2),
    is_sunny                     BOOLEAN,
    is_windy                     BOOLEAN,
    is_cloudy                    BOOLEAN,
    is_daytime                   BOOLEAN,
    is_raining                   BOOLEAN,
    is_snowing                   BOOLEAN,
    is_very_hot                  BOOLEAN,
    is_freezing                  BOOLEAN,
    is_overcast                  BOOLEAN,
    snowfall_mm                  NUMERIC(8,2),
    temp_bucket                  TEXT COLLATE pg_catalog."default",
    wind_bucket                  TEXT COLLATE pg_catalog."default",
    feels_colder                 BOOLEAN,
    feels_hotter                 BOOLEAN,
    food_weather                 BOOLEAN,
    is_heavy_rain                BOOLEAN,
    is_light_rain                BOOLEAN,
    is_nighttime                 BOOLEAN,
    is_very_windy                BOOLEAN,
    pressure_hpa                 NUMERIC(9,2),
    weather_code                 INTEGER,
    wind_gust_kmh                NUMERIC(8,2),
    comfort_score                NUMERIC(7,2),
    drink_weather                BOOLEAN,
    wind_speed_kmh               NUMERIC(8,2),
    comfort_bucket               TEXT COLLATE pg_catalog."default",
    humidity_bucket              TEXT COLLATE pg_catalog."default",
    condition_bucket             TEXT COLLATE pg_catalog."default",
    is_precipitating             BOOLEAN,
    precipitation_mm             NUMERIC(8,2),
    visibility_meters            NUMERIC(10,2),
    cloud_cover_percent          NUMERIC(7,2),
    is_unseasonably_hot          BOOLEAN,
    is_unseasonably_cold         BOOLEAN,
    outdoor_dining_score         NUMERIC(7,2),
    wind_direction_degrees       NUMERIC(7,2),
    precipitation_probability    NUMERIC(7,2),
    apparent_temperature_celsius NUMERIC(7,2),
    sysinserttime                TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_ml_wth_yyyy_ww
    ON ml.weather (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_wth_locid_yyyy_ww
    ON ml.weather (locationid, yyyy, ww);


-- ============================================================
-- TABLE 7: ml.menu_entities
-- Granularity : one row per (location, category, menu-item, week)
-- Refresh     : weekly  (no businessdate column; keyed by yyyy + ww)
-- Parquet file: menu-entities-yyww.parquet
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.menu_entities (
    organizationid                               TEXT COLLATE pg_catalog."default",
    organizationname                             TEXT COLLATE pg_catalog."default",
    locationid                                   TEXT COLLATE pg_catalog."default",
    yyyy                                         INTEGER,
    ww                                           INTEGER,
    locationname                                 TEXT COLLATE pg_catalog."default",
    categoryid                                   TEXT COLLATE pg_catalog."default",
    categoryname                                 TEXT COLLATE pg_catalog."default",
    menuitemid                                   TEXT COLLATE pg_catalog."default",
    unitprice                                    NUMERIC(12,4),
    item_selection_frequency_within_loc_and_week BIGINT,
    total_items_ordered_within_loc_and_week      BIGINT,
    pct_item_selection_freq_within_loc_and_week  NUMERIC(10,4),
    item_selection_frequency_within_org_and_week BIGINT,
    total_items_ordered_within_org_and_week      BIGINT,
    pct_item_selection_freq_within_org_and_week  NUMERIC(10,4),
    menuitemname                                 TEXT COLLATE pg_catalog."default",
    item_class_type                              TEXT COLLATE pg_catalog."default",
    entitytype                                   TEXT COLLATE pg_catalog."default",
    calories                                     NUMERIC(9,2),
    protein                                      NUMERIC(9,2),
    sugar                                        NUMERIC(9,2),
    fat                                          NUMERIC(9,2),
    is_alcoholic                                 BOOLEAN,
    is_vegetarian_item                           BOOLEAN,
    is_vegan_item                                BOOLEAN,
    has_allergen                                 BOOLEAN,
    sysinserttime                                TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_ml_me_yyyy_ww
    ON ml.menu_entities (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_me_locid_yyyy_ww
    ON ml.menu_entities (locationid, yyyy, ww);


-- ============================================================
-- TABLE 8: ml.modifier_interactions
-- Granularity : one row per (transaction, order-item, modifier)
-- Refresh     : weekly
-- Parquet file: modifier-interactions-yyww.parquet
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.modifier_interactions (
    organizationid            TEXT COLLATE pg_catalog."default",
    organizationname          TEXT COLLATE pg_catalog."default",
    locationname              TEXT COLLATE pg_catalog."default",
    locationid                TEXT COLLATE pg_catalog."default",
    catalogid                 TEXT COLLATE pg_catalog."default",
    catalogname               TEXT COLLATE pg_catalog."default",
    businessdate              DATE,
    orderdatelocal            TIMESTAMP,
    yyyy                      INTEGER,
    ww                        INTEGER,
    transactionheaderid       TEXT COLLATE pg_catalog."default",
    ordersessionid            TEXT COLLATE pg_catalog."default",
    orderid                   TEXT COLLATE pg_catalog."default",
    orderitemid               TEXT COLLATE pg_catalog."default",
    menuitemid                TEXT COLLATE pg_catalog."default",
    menuitemname              TEXT COLLATE pg_catalog."default",
    itemquantity              NUMERIC(10,3),
    itemunitprice             NUMERIC(12,4),
    item_class_type           TEXT COLLATE pg_catalog."default",
    modifiergroupid           TEXT COLLATE pg_catalog."default",
    modifiergroupname         TEXT COLLATE pg_catalog."default",
    modifierid                TEXT COLLATE pg_catalog."default",
    modifiername              TEXT COLLATE pg_catalog."default",
    parent_modifier_id        TEXT COLLATE pg_catalog."default",
    nesting_depth             INTEGER,
    modifierquantity          NUMERIC(10,3),
    modifierprice             NUMERIC(12,4),
    freequantity              NUMERIC(10,3),
    is_modifier_default       BOOLEAN,
    min_quantity              INTEGER,
    max_quantity              INTEGER,
    selection_type            TEXT COLLATE pg_catalog."default",
    action                    TEXT COLLATE pg_catalog."default",
    session_recorded_at       TEXT COLLATE pg_catalog."default",
    frequentcustomerid        TEXT COLLATE pg_catalog."default",
    modifier_default_quantity NUMERIC(10,3),
    modifier_class_type       TEXT COLLATE pg_catalog."default",
    sysinserttime             TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_ml_mi_yyyy_ww
    ON ml.modifier_interactions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mi_locid_yyyy_ww
    ON ml.modifier_interactions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mi_businessdate
    ON ml.modifier_interactions (businessdate);


-- ============================================================
-- TABLE 9: ml.modifier_impressions
-- Granularity : one row per modifier impression event
-- Refresh     : weekly
-- Parquet file: modifier-impressions-yyww.parquet
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.modifier_impressions (
    organizationid      TEXT COLLATE pg_catalog."default",
    organizationname    TEXT COLLATE pg_catalog."default",
    locationname        TEXT COLLATE pg_catalog."default",
    locationid          TEXT COLLATE pg_catalog."default",
    catalogid           TEXT COLLATE pg_catalog."default",
    catalogname         TEXT COLLATE pg_catalog."default",
    businessdate        DATE,
    orderdatelocal      TIMESTAMP,
    yyyy                INTEGER,
    ww                  INTEGER,
    transactionheaderid TEXT COLLATE pg_catalog."default",
    ordersessionid      TEXT COLLATE pg_catalog."default",
    orderid             TEXT COLLATE pg_catalog."default",
    menuitemid          TEXT COLLATE pg_catalog."default",
    menuitemname        TEXT COLLATE pg_catalog."default",
    item_class_type     TEXT COLLATE pg_catalog."default",
    modifierid          TEXT COLLATE pg_catalog."default",
    modifiername        TEXT COLLATE pg_catalog."default",
    modifier_class_type TEXT COLLATE pg_catalog."default",
    parent_modifier_id  TEXT COLLATE pg_catalog."default",
    nesting_depth       INTEGER,
    modifierprice       NUMERIC(12,4),
    selection_type      TEXT COLLATE pg_catalog."default",
    position            INTEGER,
    score               NUMERIC(10,4),
    strategy            TEXT COLLATE pg_catalog."default",
    conTEXT COLLATE pg_catalog."default",             TEXT COLLATE pg_catalog."default",
    selected            BOOLEAN,
    pre_deselected      BOOLEAN,
    confirmed_removed   BOOLEAN,
    pre_selected        BOOLEAN,
    frequentcustomerid  TEXT COLLATE pg_catalog."default",
    sysinserttime       TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_ml_mimp_yyyy_ww
    ON ml.modifier_impressions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mimp_locid_yyyy_ww
    ON ml.modifier_impressions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mimp_businessdate
    ON ml.modifier_impressions (businessdate);


-- ============================================================
-- TABLE 10: ml.item_modifier_mapping
-- Granularity : one row per (location, menu-item, modifier-group,
--               modifier, week)
-- Refresh     : weekly  (no businessdate column; keyed by yyyy + ww)
-- Parquet file: item-modifiergroup-modifier-mapping-yyww.parquet
-- ============================================================
CREATE TABLE IF NOT EXISTS ml.item_modifier_mapping (
    organizationid                               TEXT COLLATE pg_catalog."default",
    organizationname                             TEXT COLLATE pg_catalog."default",
    locationid                                   TEXT COLLATE pg_catalog."default",
    locationname                                 TEXT COLLATE pg_catalog."default",
    catalogid                                    TEXT COLLATE pg_catalog."default",
    catalogname                                  TEXT COLLATE pg_catalog."default",
    yyyy                                         INTEGER,
    ww                                           INTEGER,
    menuitemid                                   TEXT COLLATE pg_catalog."default",
    menuitemname                                 TEXT COLLATE pg_catalog."default",
    item_class_type                              TEXT COLLATE pg_catalog."default",
    modifiergroupid                              TEXT COLLATE pg_catalog."default",
    modifiergroupname                            TEXT COLLATE pg_catalog."default",
    modifierid                                   TEXT COLLATE pg_catalog."default",
    modifiername                                 TEXT COLLATE pg_catalog."default",
    modifier_class_type                          TEXT COLLATE pg_catalog."default",
    is_modifier_default                          BOOLEAN,
    min_quantity                                 INTEGER,
    max_quantity                                 INTEGER,
    allow_quantity_increment                     BOOLEAN,
    increment_step                               NUMERIC(10,3),
    modifier_default_quantity                    NUMERIC(10,3),
    is_modifier_invisible                        BOOLEAN,
    calories                                     NUMERIC(9,2),
    is_modifier_active                           BOOLEAN,
    is_modifier_deleted                          BOOLEAN,
    x_times_added_on_to_the_item                 BIGINT,
    mdfr_selection_frequency_within_loc_and_week BIGINT,
    pct_relative_selection_frequency             NUMERIC(10,4),
    sysinserttime                                TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_ml_imm_yyyy_ww
    ON ml.item_modifier_mapping (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_imm_locid_yyyy_ww
    ON ml.item_modifier_mapping (locationid, yyyy, ww);


-- ============================================================
-- STORED PROCEDURE 1: ml.usp_refresh_frequent_customers
-- Refresh type : FULL (TRUNCATE + INSERT)
-- Parquet file : frequentcustomers.parquet
-- Notes        : Org-level data only. Customer loyalty spans the
--                entire organisation, so no location or date filter.
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_frequent_customers()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    TRUNCATE TABLE ml.frequent_customers;

    WITH org_loc_lookup AS (
        SELECT DISTINCT
            ol.organizationid,
            ol.organizationname,
            ol.locationid,
            ol.locationname
        FROM dim.organizationlocation AS ol
        WHERE ol.organizationtype = 0
    ),
    loc_specific_favorite_items AS (
        SELECT
            fc.frequentcustomerid,
            fc.organizationid,
            th.locationid,
            ti.dimmenuitemid,
            MIN(mi.item_class_type)                                                      AS item_class_type,
            COUNT(*)                                                                      AS x_times_selected,
            ROW_NUMBER() OVER (
                PARTITION BY fc.frequentcustomerid, fc.organizationid, th.locationid
                ORDER BY COUNT(*) DESC
            )                                                                             AS item_ranking_within_loc
        FROM dim.frequentcustomer AS fc
        INNER JOIN fact.transactionheader AS th
            ON fc.frequentcustomerid = th.frequentcustomerid
        INNER JOIN fact.transactionitem AS ti
            ON th.locationid = ti.locationid
           AND th.transactionheaderid = ti.transactionheaderid
        INNER JOIN dim.menuitem AS mi
            ON ti.menuitemid = mi.id
        WHERE ti.dimmenuitemid IS NOT NULL
          AND th.locationid IN (SELECT DISTINCT locationid FROM org_loc_lookup)
        GROUP BY fc.frequentcustomerid, fc.organizationid, th.locationid, ti.dimmenuitemid
    ),
    overall_favorite_items AS (
        SELECT
            fc.frequentcustomerid,
            fc.organizationid,
            ti.dimmenuitemid,
            MIN(mi.item_class_type)                                           AS item_class_type,
            COUNT(*)                                                           AS x_times_selected,
            ROW_NUMBER() OVER (
                PARTITION BY fc.frequentcustomerid, fc.organizationid
                ORDER BY COUNT(*) DESC
            )                                                                  AS item_ranking_within_org
        FROM dim.frequentcustomer AS fc
        INNER JOIN fact.transactionheader AS th
            ON fc.frequentcustomerid = th.frequentcustomerid
        INNER JOIN fact.transactionitem AS ti
            ON th.locationid = ti.locationid
           AND th.transactionheaderid = ti.transactionheaderid
        INNER JOIN dim.menuitem AS mi
            ON ti.menuitemid = mi.id
        WHERE ti.dimmenuitemid IS NOT NULL
          AND th.locationid IN (SELECT DISTINCT locationid FROM org_loc_lookup)
        GROUP BY fc.frequentcustomerid, fc.organizationid, ti.dimmenuitemid
    ),
    jsonb_loc_specific_favorite_items AS (
        SELECT
            organizationid,
            frequentcustomerid,
            JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'organizationid',  organizationid,
                    'locationid',      locationid,
                    'menuitemid',      dimmenuitemid,
                    'item_class_type', item_class_type,
                    'x_times_selected',x_times_selected,
                    'item_ranking',    item_ranking_within_loc
                ) ORDER BY x_times_selected DESC
            ) AS loc_specific_favorite_items_jsonb
        FROM loc_specific_favorite_items
        GROUP BY organizationid, frequentcustomerid
    ),
    jsonb_overall_favorite_items AS (
        SELECT
            organizationid,
            frequentcustomerid,
            JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'organizationid',  organizationid,
                    'menuitemid',      dimmenuitemid,
                    'item_class_type', item_class_type,
                    'x_times_selected',x_times_selected,
                    'item_ranking',    item_ranking_within_org
                ) ORDER BY x_times_selected DESC
            ) AS overall_favorite_items_jsonb
        FROM overall_favorite_items
        GROUP BY organizationid, frequentcustomerid
    ),
    static_upsells AS (
        SELECT
            th.frequentcustomerid,
            oa.offereditem,
            MIN(mi.item_class_type)                                              AS item_class_type,
            COUNT(*)                                                              AS x_times_offered,
            SUM(CASE WHEN oa.selecteditem IS NOT NULL THEN 1 ELSE 0 END)         AS x_times_selected
        FROM fact.vw_offer_analysis AS oa
        INNER JOIN (
            SELECT * FROM fact.transactionheader WHERE frequentcustomerid IS NOT NULL
        ) AS th
            ON oa.locationid       = th.locationid
           AND oa.transactionheaderid = th.transactionheaderid
        INNER JOIN dim.menuitem AS mi
            ON oa.offereditem = mi.menuitemid
        WHERE oa.locationid IN (SELECT DISTINCT locationid FROM org_loc_lookup)
        GROUP BY th.frequentcustomerid, oa.offereditem
    ),
    jsonb_static_upsells AS (
        SELECT
            frequentcustomerid,
            JSONB_AGG(
                JSONB_BUILD_OBJECT(
                    'menuitemid',      offereditem,
                    'item_class_type', item_class_type,
                    'x_times_offered', x_times_offered,
                    'x_times_selected',x_times_selected
                ) ORDER BY x_times_selected DESC
            ) AS static_upsell_stats_jsonb
        FROM static_upsells
        GROUP BY frequentcustomerid
    )
    INSERT INTO ml.frequent_customers (
        organizationid,
        organizationname,
        frequentcustomerid,
        firstname,
        lastname,
        email,
        phone,
        source,
        ordercount,
        amountspent,
        avg_amount_spent,
        loc_specific_favorite_items_jsonb,
        overall_favorite_items_jsonb,
        static_upsell_stats_jsonb,
        sysinserttime,
        sysupdatetime
    )
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        fc.frequentcustomerid,
        fc.firstname,
        fc.lastname,
        fc.email,
        fc.phone,
        fc.source,
        fc.ordercount,
        fc.amountspent,
        fc.amountspent / CASE WHEN fc.ordercount > 0 THEN fc.ordercount ELSE 1 END AS avg_amount_spent,
        lfi.loc_specific_favorite_items_jsonb,
        ofi.overall_favorite_items_jsonb,
        su.static_upsell_stats_jsonb,
        NOW()::TIMESTAMP,
        NOW()::TIMESTAMP
    FROM dim.frequentcustomer AS fc
    LEFT JOIN jsonb_loc_specific_favorite_items AS lfi
           ON lfi.organizationid     = fc.organizationid
          AND lfi.frequentcustomerid = fc.frequentcustomerid
    LEFT JOIN jsonb_overall_favorite_items AS ofi
           ON ofi.frequentcustomerid = lfi.frequentcustomerid
          AND ofi.organizationid     = lfi.organizationid
    LEFT JOIN jsonb_static_upsells AS su
           ON su.frequentcustomerid  = lfi.frequentcustomerid
    INNER JOIN (
        SELECT DISTINCT organizationid, organizationname FROM org_loc_lookup
    ) AS ol
        ON fc.organizationid = ol.organizationid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_frequent_customers() OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 2: ml.usp_refresh_location_stats
-- Refresh type : FULL (TRUNCATE + INSERT)
-- Parquet file : location.parquet
-- Notes        : Calls the upstream fact.usp_location_statistics()
--                which refreshes fact.location_statistics, then
--                mirrors all rows into ml.location_stats.
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_location_stats()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- Step 1: refresh the upstream materialised table
    CALL fact.usp_location_statistics();

    -- Step 2: mirror into ml schema (full replace)
    TRUNCATE TABLE ml.location_stats;

    INSERT INTO ml.location_stats (
        organizationid,
        organizationname,
        locationid,
        locationname,
        city,
        state,
        country,
        isactive,
        timezone,
        order_type_labels,
        loc_item_popularity,
        loc_total_order_count,
        loc_total_sales_amount,
        loc_avg_order_amount,
        org_total_order_count,
        org_total_sales_amount,
        org_avg_order_amount,
        number_of_frequent_customers,
        orders_placed_by_freq_customers,
        amount_spent_by_freq_customers,
        avg_amount_spent_by_freq_customers,
        sysinserttime,
        sysupdatetime
    )
    SELECT DISTINCT
        organizationid,
        organizationname,
        locationid,
        locationname,
        city,
        state,
        country,
        isactive,
        timezone,
        order_type_labels,
        loc_item_popularity,
        loc_total_order_count,
        loc_total_sales_amount,
        loc_avg_order_amount,
        org_total_order_count,
        org_total_sales_amount,
        org_avg_order_amount,
        number_of_frequent_customers,
        orders_placed_by_freq_customers,
        amount_spent_by_freq_customers,
        avg_amount_spent_by_freq_customers,
        NOW()::TIMESTAMP,
        NOW()::TIMESTAMP
    FROM fact.location_statistics;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_location_stats() OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 3: ml.usp_refresh_master_items
-- Refresh type : INCREMENTAL INSERT + full mirror
-- Parquet file : master-items.parquet
-- Notes        : Calls dim.usp_master_keys_for_duplicate_items()
--                which incrementally updates dim.duplicate_items_master,
--                then mirrors the complete result set to ml.master_items.
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_master_items()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- Step 1: refresh upstream duplicate-items master table
    CALL dim.usp_master_keys_for_duplicate_items();

    -- Step 2: mirror into ml schema (full replace)
    TRUNCATE TABLE ml.master_items;

    INSERT INTO ml.master_items (
        organizationid,
        organizationname,
        locationid,
        locationname,
        catalogid,
        catalogname,
        categoryid,
        categoryname,
        menuitemid,
        is_item_active,
        is_item_deleted,
        entitytype,
        item_class_type,
        menuitemname,
        instance_count,
        masteritemid,
        sysinserttime,
        sysupdatetime
    )
    SELECT
        dim.organizationid,
        ol.organizationname,
        dim.locationid,
        ol.locationname,
        ctg.catalogid,
        ctg.catalogname,
        dim.categoryid,
        dim.categoryname,
        dim.menuitemid,
        ctg.is_item_active,
        ctg.is_item_deleted,
        dim.entitytype,
        dim.item_class_type,
        dim.menuitemname,
        dim.instance_count,
        dim.masteritemid,
        NOW()::TIMESTAMP,
        NOW()::TIMESTAMP
    FROM dim.duplicate_items_master AS dim
    INNER JOIN (
        SELECT DISTINCT ol.locationid, ol.organizationid, ol.organizationname, ol.locationname
        FROM dim.organizationlocation AS ol
        WHERE ol.organizationtype = 0
    ) AS ol
        ON dim.locationid = ol.locationid
    INNER JOIN dim.category_hierarchy AS ctg
        ON dim.locationid  = ctg.locationid
       AND dim.categoryid  = ctg.categoryid
       AND dim.menuitemid  = ctg.menuitemid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_master_items() OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 4: ml.usp_refresh_transactions
-- Refresh type : WEEKLY DELETE + INSERT (idempotent)
-- Parquet file : data-yyww.parquet
-- Parameter    : p_businessdate DATE (default: yesterday)
--                The ISO year and week are derived from this date.
--                All transaction data for that calendar week is
--                deleted and re-inserted on every call.
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_transactions(
    p_businessdate DATE DEFAULT CURRENT_DATE - 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_yyyy INTEGER := EXTRACT(YEAR FROM p_businessdate)::INTEGER;
    v_ww   INTEGER := EXTRACT(WEEK FROM p_businessdate)::INTEGER;
BEGIN

    -- Idempotent: purge existing data for this ISO week
    DELETE FROM ml.transactions
    WHERE yyyy = v_yyyy
      AND ww   = v_ww;

    -- Insert fresh data for the week
    INSERT INTO ml.transactions (
        frequentcustomerid,
        organizationid,
        organizationname,
        locationid,
        locationname,
        kioskid,
        transactionheaderid,
        orderitemid,
        menuitemid,
        itemname,
        upselllevel,
        item_class_type,
        itemquantity,
        categoryid,
        categoryname,
        itemunitprice,
        paymentstatus,
        numberofitems,
        numberofpayments,
        ordertotal,
        ordersubtotal,
        ordertip,
        ordertax,
        ordertypelabel,
        orderdatelocal,
        businessdate,
        weatherhumidity,
        weathercondition,
        temperatureincelcius,
        yyyy,
        mm,
        dd,
        hh,
        ww,
        sysinserttime
    )
    WITH org_loc_lookup AS (
        SELECT DISTINCT ol.locationid
        FROM dim.organizationlocation AS ol
        WHERE ol.organizationtype = 0
    ),
    cte AS (
        SELECT *
        FROM fact.transactionheader AS th
        WHERE th.locationid IN (SELECT locationid FROM org_loc_lookup)
          AND LOWER(th.orderstatus) = 'order-placed'
          AND EXTRACT(YEAR FROM th.businessdate)::INTEGER = v_yyyy
          AND EXTRACT(WEEK FROM th.businessdate)::INTEGER = v_ww
    )
    SELECT DISTINCT
        th.frequentcustomerid,
        ol.organizationid,
        ol.organizationname,
        th.locationid,
        ol.locationname,
        th.kioskid,
        th.transactionheaderid,
        ti.itemid                                                    AS orderitemid,
        ti.dimmenuitemid                                             AS menuitemid,
        ti.itemname,
        COALESCE(ti.upselllevel, '')                                 AS upselllevel,
        mi.item_class_type,
        ti.itemquantity,
        ti.categoryid,
        ctg.categoryname,
        ti.itemunitprice,
        th.paymentstatus,
        th.numberofitems,
        th.numberofpayments,
        th.ordertotal,
        th.ordersubtotal,
        th.ordertip,
        th.ordertax,
        ot.ordertypelabel,
        th.orderdatelocal,
        th.businessdate,
        wh.humidity                                                  AS weatherhumidity,
        wh.condition                                                 AS weathercondition,
        wh.temperature_c                                             AS temperatureincelcius,
        EXTRACT(YEAR  FROM th.businessdate)::INTEGER                 AS yyyy,
        EXTRACT(MONTH FROM th.businessdate)::INTEGER                 AS mm,
        EXTRACT(DAY   FROM th.businessdate)::INTEGER                 AS dd,
        EXTRACT(HOUR  FROM th.orderdatelocal)::INTEGER               AS hh,
        EXTRACT(WEEK  FROM th.businessdate)::INTEGER                 AS ww,
        NOW()::TIMESTAMP                                             AS sysinserttime
    FROM cte AS th
    LEFT JOIN (
        SELECT * FROM dim.organizationlocation WHERE organizationtype = 0
    ) AS ol
        ON th.locationid = ol.locationid
    LEFT JOIN fact.transactionitem AS ti
        ON th.transactionheaderid = ti.transactionheaderid
    LEFT JOIN dim.vw_weatherhourlydata AS wh
        ON th.locationid  = wh.locationid
       AND th.businessdate = wh.weatherdate
       AND EXTRACT(HOUR FROM th.orderdatelocal)::INTEGER = wh.hh
    LEFT JOIN dim.itemcategory AS ctg
        ON ti.categoryid = ctg.id
    LEFT JOIN dim.menuitem AS mi
        ON ti.menuitemid = mi.id
    LEFT JOIN dim.ordertype AS ot
        ON th.ordertype = ot.id;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_transactions(DATE) OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 5: ml.usp_refresh_upsell_analysis
-- Refresh type : WEEKLY DELETE + INSERT (idempotent)
-- Parquet file : upsell-analysis-yyww.parquet
-- Parameter    : p_businessdate DATE (default: yesterday)
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_upsell_analysis(
    p_businessdate DATE DEFAULT CURRENT_DATE - 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_yyyy INTEGER := EXTRACT(YEAR FROM p_businessdate)::INTEGER;
    v_ww   INTEGER := EXTRACT(WEEK FROM p_businessdate)::INTEGER;
BEGIN

    DELETE FROM ml.upsell_analysis
    WHERE yyyy = v_yyyy
      AND ww   = v_ww;

    INSERT INTO ml.upsell_analysis (
        organizationid,
        organizationname,
        locationid,
        locationname,
        frequentcustomerid,
        transactionheaderid,
        recommendationid,
        offereditem,
        selecteditem,
        item_class_type,
        upselltype,
        quantity,
        businessdate,
        orderdatelocal,
        yyyy,
        mm,
        dd,
        hh,
        ww,
        sysinserttime
    )
    WITH th AS (
        SELECT *
        FROM fact.transactionheader
        WHERE locationid IN (
            SELECT DISTINCT locationid
            FROM dim.organizationlocation
            WHERE organizationtype = 0
        )
          AND EXTRACT(YEAR FROM businessdate)::INTEGER = v_yyyy
          AND EXTRACT(WEEK FROM businessdate)::INTEGER = v_ww
    )
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        oa.locationid,
        ol.locationname,
        th.frequentcustomerid,
        oa.transactionheaderid,
        oa.recommendationid,
        oa.offereditem,
        oa.selecteditem,
        mi.item_class_type,
        oa.upselltype,
        oa.quantity,
        th.businessdate,
        th.orderdatelocal,
        EXTRACT(YEAR  FROM th.businessdate)::INTEGER  AS yyyy,
        EXTRACT(MONTH FROM th.businessdate)::INTEGER  AS mm,
        EXTRACT(DAY   FROM th.businessdate)::INTEGER  AS dd,
        EXTRACT(HOUR  FROM th.orderdatelocal)::INTEGER AS hh,
        EXTRACT(WEEK  FROM th.businessdate)::INTEGER  AS ww,
        NOW()::TIMESTAMP                              AS sysinserttime
    FROM fact.vw_offer_analysis AS oa
    INNER JOIN th
        ON oa.locationid          = th.locationid
       AND oa.transactionheaderid = th.transactionheaderid
    INNER JOIN (
        SELECT * FROM dim.organizationlocation WHERE organizationtype = 0
    ) AS ol
        ON oa.locationid = ol.locationid
    LEFT JOIN dim.menuitem AS mi
        ON (
            CASE
                WHEN oa.offereditem NOT LIKE 'cat-%' THEN oa.offereditem
                ELSE oa.selecteditem
            END
        ) = mi.menuitemid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_upsell_analysis(DATE) OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 6: ml.usp_refresh_weather
-- Refresh type : WEEKLY DELETE + INSERT (idempotent)
-- Parquet file : weather-yyww.parquet
-- Parameter    : p_businessdate DATE (default: yesterday)
-- Notes        : Date column in output is weatherdate (not businessdate).
--                Week is derived from p_businessdate.
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_weather(
    p_businessdate DATE DEFAULT CURRENT_DATE - 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_yyyy INTEGER := EXTRACT(YEAR FROM p_businessdate)::INTEGER;
    v_ww   INTEGER := EXTRACT(WEEK FROM p_businessdate)::INTEGER;
BEGIN

    DELETE FROM ml.weather
    WHERE yyyy = v_yyyy
      AND ww   = v_ww;

    INSERT INTO ml.weather (
        organizationid,
        organizationname,
        locationid,
        locationname,
        weatherdate,
        yyyy,
        mm,
        dd,
        ww,
        hh,
        humidity,
        condition,
        temperature_c,
        is_hot,
        is_calm,
        is_cold,
        is_cool,
        is_mild,
        is_warm,
        rain_mm,
        is_sunny,
        is_windy,
        is_cloudy,
        is_daytime,
        is_raining,
        is_snowing,
        is_very_hot,
        is_freezing,
        is_overcast,
        snowfall_mm,
        temp_bucket,
        wind_bucket,
        feels_colder,
        feels_hotter,
        food_weather,
        is_heavy_rain,
        is_light_rain,
        is_nighttime,
        is_very_windy,
        pressure_hpa,
        weather_code,
        wind_gust_kmh,
        comfort_score,
        drink_weather,
        wind_speed_kmh,
        comfort_bucket,
        humidity_bucket,
        condition_bucket,
        is_precipitating,
        precipitation_mm,
        visibility_meters,
        cloud_cover_percent,
        is_unseasonably_hot,
        is_unseasonably_cold,
        outdoor_dining_score,
        wind_direction_degrees,
        precipitation_probability,
        apparent_temperature_celsius,
        sysinserttime
    )
    WITH wh AS (
        SELECT *
        FROM dim.vw_weatherhourlydata
        WHERE locationid IN (
            SELECT DISTINCT locationid
            FROM dim.organizationlocation
            WHERE organizationtype = 0
        )
          AND EXTRACT(YEAR FROM weatherdate)::INTEGER = v_yyyy
          AND EXTRACT(WEEK FROM weatherdate)::INTEGER = v_ww
    )
    SELECT
        ol.organizationid,
        ol.organizationname,
        wh.locationid,
        ol.locationname,
        wh.weatherdate,
        EXTRACT(YEAR  FROM wh.weatherdate)::INTEGER AS yyyy,
        EXTRACT(MONTH FROM wh.weatherdate)::INTEGER AS mm,
        EXTRACT(DAY   FROM wh.weatherdate)::INTEGER AS dd,
        EXTRACT(WEEK  FROM wh.weatherdate)::INTEGER AS ww,
        wh.hh,
        wh.humidity,
        wh.condition,
        wh.temperature_c,
        wh.is_hot,
        wh.is_calm,
        wh.is_cold,
        wh.is_cool,
        wh.is_mild,
        wh.is_warm,
        wh.rain_mm,
        wh.is_sunny,
        wh.is_windy,
        wh.is_cloudy,
        wh.is_daytime,
        wh.is_raining,
        wh.is_snowing,
        wh.is_very_hot,
        wh.is_freezing,
        wh.is_overcast,
        wh.snowfall_mm,
        wh.temp_bucket,
        wh.wind_bucket,
        wh.feels_colder,
        wh.feels_hotter,
        wh.food_weather,
        wh.is_heavy_rain,
        wh.is_light_rain,
        wh.is_nighttime,
        wh.is_very_windy,
        wh.pressure_hpa,
        wh.weather_code,
        wh.wind_gust_kmh,
        wh.comfort_score,
        wh.drink_weather,
        wh.wind_speed_kmh,
        wh.comfort_bucket,
        wh.humidity_bucket,
        wh.condition_bucket,
        wh.is_precipitating,
        wh.precipitation_mm,
        wh.visibility_meters,
        wh.cloud_cover_percent,
        wh.is_unseasonably_hot,
        wh.is_unseasonably_cold,
        wh.outdoor_dining_score,
        wh.wind_direction_degrees,
        wh.precipitation_probability,
        wh.apparent_temperature_celsius,
        NOW()::TIMESTAMP AS sysinserttime
    FROM wh
    LEFT JOIN (
        SELECT * FROM dim.organizationlocation WHERE organizationtype = 0
    ) AS ol
        ON wh.locationid = ol.locationid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_weather(DATE) OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 7: ml.usp_refresh_menu_entities
-- Refresh type : WEEKLY DELETE + INSERT (idempotent)
-- Parquet file : menu-entities-yyww.parquet
-- Parameter    : p_businessdate DATE (default: yesterday)
-- Notes        : No businessdate in output; keyed by yyyy + ww only.
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_menu_entities(
    p_businessdate DATE DEFAULT CURRENT_DATE - 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_yyyy INTEGER := EXTRACT(YEAR FROM p_businessdate)::INTEGER;
    v_ww   INTEGER := EXTRACT(WEEK FROM p_businessdate)::INTEGER;
BEGIN

    DELETE FROM ml.menu_entities
    WHERE yyyy = v_yyyy
      AND ww   = v_ww;

    INSERT INTO ml.menu_entities (
        organizationid,
        organizationname,
        locationid,
        yyyy,
        ww,
        locationname,
        categoryid,
        categoryname,
        menuitemid,
        unitprice,
        item_selection_frequency_within_loc_and_week,
        total_items_ordered_within_loc_and_week,
        pct_item_selection_freq_within_loc_and_week,
        item_selection_frequency_within_org_and_week,
        total_items_ordered_within_org_and_week,
        pct_item_selection_freq_within_org_and_week,
        menuitemname,
        item_class_type,
        entitytype,
        calories,
        protein,
        sugar,
        fat,
        is_alcoholic,
        is_vegetarian_item,
        is_vegan_item,
        has_allergen,
        sysinserttime
    )
    WITH org_loc_lookup AS (
        SELECT DISTINCT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname
        FROM dim.organizationlocation AS ol
        WHERE ol.organizationtype = 0
    ),
    order_items AS (
        SELECT ti.*, ic.categoryid AS dimcategoryid, ic.categoryname
        FROM (
            SELECT
                ol.organizationid,
                ol.organizationname,
                ol.locationname,
                ti.*
            FROM fact.transactionitem AS ti
            INNER JOIN org_loc_lookup AS ol
                ON ti.locationid = ol.locationid
            WHERE LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
              AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = v_yyyy
              AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = v_ww
        ) AS ti
        INNER JOIN dim.itemcategory AS ic
            ON ti.categoryid = ic.id
    ),
    org_agg AS (
        SELECT organizationid, COUNT(*) AS total_items_ordered_within_org_and_week
        FROM order_items
        GROUP BY organizationid
    ),
    org_itm_agg AS (
        SELECT organizationid, dimmenuitemid, COUNT(*) AS item_selection_frequency_within_org_and_week
        FROM order_items
        GROUP BY organizationid, dimmenuitemid
    ),
    loc_agg AS (
        SELECT organizationid, locationid, COUNT(*) AS total_items_ordered_within_loc_and_week
        FROM order_items
        GROUP BY organizationid, locationid
    ),
    loc_itm_agg AS (
        SELECT
            organizationid,
            locationid,
            dimmenuitemid,
            COUNT(*)        AS item_selection_frequency_within_loc_and_week,
            MAX(itemunitprice) AS itemunitprice
        FROM order_items
        GROUP BY organizationid, locationid, dimmenuitemid
    ),
    item_statistics AS (
        SELECT
            lia.organizationid,
            lia.locationid,
            lia.dimmenuitemid,
            lia.itemunitprice,
            lia.item_selection_frequency_within_loc_and_week,
            la.total_items_ordered_within_loc_and_week,
            100 * lia.item_selection_frequency_within_loc_and_week::NUMERIC(8,3)
                / la.total_items_ordered_within_loc_and_week                         AS pct_item_selection_freq_within_loc_and_week,
            oia.item_selection_frequency_within_org_and_week,
            oa.total_items_ordered_within_org_and_week,
            100 * oia.item_selection_frequency_within_org_and_week::NUMERIC(8,3)
                / oa.total_items_ordered_within_org_and_week                         AS pct_item_selection_freq_within_org_and_week
        FROM loc_itm_agg AS lia
        INNER JOIN loc_agg  AS la  ON lia.organizationid = la.organizationid  AND lia.locationid    = la.locationid
        INNER JOIN org_itm_agg AS oia ON lia.organizationid = oia.organizationid AND lia.dimmenuitemid = oia.dimmenuitemid
        INNER JOIN org_agg  AS oa  ON lia.organizationid = oa.organizationid
    ),
    category_hierarchy AS (
        SELECT
            mi.*,
            ol.organizationid,
            ol.organizationname,
            ctgh.locationid,
            ol.locationname,
            ctgh.categoryid,
            ctgh.categoryname
        FROM dim.menuitem AS mi
        LEFT JOIN dim.category_hierarchy AS ctgh
            ON mi.menuitemid = ctgh.menuitemid
        INNER JOIN org_loc_lookup AS ol
            ON ctgh.locationid = ol.locationid
        WHERE (
            EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER = v_yyyy
            AND EXTRACT(WEEK FROM mi.gms_created_on)::INTEGER <= v_ww
        )
        OR (
            EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER < v_yyyy
        )
    )
    SELECT DISTINCT
        mi.organizationid,
        mi.organizationname,
        COALESCE(mi.locationid, ti.locationid)          AS locationid,
        v_yyyy                                          AS yyyy,
        v_ww                                            AS ww,
        mi.locationname,
        COALESCE(mi.categoryid,   ti.dimcategoryid)     AS categoryid,
        COALESCE(mi.categoryname, ti.categoryname)      AS categoryname,
        COALESCE(mi.menuitemid,   ti.dimmenuitemid)     AS menuitemid,
        COALESCE(its.itemunitprice, ti.itemunitprice)   AS unitprice,
        its.item_selection_frequency_within_loc_and_week,
        its.total_items_ordered_within_loc_and_week,
        its.pct_item_selection_freq_within_loc_and_week,
        its.item_selection_frequency_within_org_and_week,
        its.total_items_ordered_within_org_and_week,
        its.pct_item_selection_freq_within_org_and_week,
        COALESCE(mi.menuitemname, ti.itemname)          AS menuitemname,
        mi.item_class_type,
        mi.entitytype,
        mi.calories,
        mi.protein,
        mi.sugar,
        mi.fat,
        mi.is_alcoholic,
        mi.is_vegetarian_item,
        mi.is_vegan_item,
        mi.has_allergen,
        NOW()::TIMESTAMP                                AS sysinserttime
    FROM category_hierarchy AS mi
    LEFT JOIN order_items AS ti
        ON mi.id         = ti.menuitemid
       AND mi.categoryid = ti.dimcategoryid
    LEFT JOIN item_statistics AS its
        ON ti.organizationid = its.organizationid
       AND ti.locationid     = its.locationid
       AND ti.dimmenuitemid  = its.dimmenuitemid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_menu_entities(DATE) OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 8: ml.usp_refresh_modifier_interactions
-- Refresh type : WEEKLY DELETE + INSERT (idempotent)
-- Parquet file : modifier-interactions-yyww.parquet
-- Parameter    : p_businessdate DATE (default: yesterday)
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_modifier_interactions(
    p_businessdate DATE DEFAULT CURRENT_DATE - 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_yyyy INTEGER := EXTRACT(YEAR FROM p_businessdate)::INTEGER;
    v_ww   INTEGER := EXTRACT(WEEK FROM p_businessdate)::INTEGER;
BEGIN

    DELETE FROM ml.modifier_interactions
    WHERE yyyy = v_yyyy
      AND ww   = v_ww;

    INSERT INTO ml.modifier_interactions (
        organizationid,
        organizationname,
        locationname,
        locationid,
        catalogid,
        catalogname,
        businessdate,
        orderdatelocal,
        yyyy,
        ww,
        transactionheaderid,
        ordersessionid,
        orderid,
        orderitemid,
        menuitemid,
        menuitemname,
        itemquantity,
        itemunitprice,
        item_class_type,
        modifiergroupid,
        modifiergroupname,
        modifierid,
        modifiername,
        parent_modifier_id,
        nesting_depth,
        modifierquantity,
        modifierprice,
        freequantity,
        is_modifier_default,
        min_quantity,
        max_quantity,
        selection_type,
        action,
        session_recorded_at,
        frequentcustomerid,
        modifier_default_quantity,
        modifier_class_type,
        sysinserttime
    )
    WITH org_loc_lookup AS (
        SELECT DISTINCT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname
        FROM dim.organizationlocation AS ol
        WHERE ol.organizationtype = 0
    ),
    org_loc_ctlg AS (
        SELECT ol.*, c.catalogid, c.catalogname
        FROM org_loc_lookup AS ol
        INNER JOIN dim.catalog AS c
            ON ol.organizationid = c.organizationid
           AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        SELECT m.*, olc.organizationid, olc.organizationname, olc.locationid, olc.locationname, olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
        WHERE (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER = v_yyyy
            AND EXTRACT(WEEK FROM m.modifier_created_on)::INTEGER <= v_ww
        )
        OR (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER < v_yyyy
        )
    ),
    trxn_items AS (
        SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.*
        FROM fact.transactionitem AS ti
        INNER JOIN org_loc_lookup AS ol
            ON ti.locationid = ol.locationid
        WHERE LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
          AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = v_yyyy
          AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = v_ww
    )
    SELECT
        olcm.organizationid,
        olcm.organizationname,
        olcm.locationname,
        olcm.locationid,
        olcm.catalogid,
        olcm.catalogname,
        ti.businessdate,
        ti.orderdatelocal,
        v_yyyy                                                  AS yyyy,
        v_ww                                                    AS ww,
        mt.transactionheaderid,
        ti.ordersessionid,
        mt.orderid,
        mt.itemid                                               AS orderitemid,
        ti.dimmenuitemid                                        AS menuitemid,
        mi.menuitemname,
        ti.itemquantity,
        ti.itemunitprice,
        mi.item_class_type,
        mt.modifiergroupid,
        mg.modifiergroupname,
        mt.modifierid,
        mt.modifiername,
        NULL::TEXT COLLATE pg_catalog."default",                                              AS parent_modifier_id,
        NULL::INTEGER                                           AS nesting_depth,
        mt.modifierquantity,
        mt.modifierprice,
        mt.freequantity,
        mgm.is_default                                          AS is_modifier_default,
        mg.min_selection                                        AS min_quantity,
        mg.max_selection                                        AS max_quantity,
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 THEN 'optional'
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 THEN 'required'
            WHEN mgm.is_default = TRUE                                                       THEN 'default'
        END                                                     AS selection_type,
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 AND mt.modifierquantity >= 1 THEN 'added'
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'selected'
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'kept'
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity = 0  THEN 'removed'
        END                                                     AS action,
        NULL::TEXT COLLATE pg_catalog."default",                                              AS session_recorded_at,
        ti.frequentcustomerid,
        olcm.modifier_default_quantity,
        olcm.classification                                     AS modifier_class_type,
        NOW()::TIMESTAMP                                        AS sysinserttime
    FROM fact.itemmodifier AS mt
    INNER JOIN trxn_items AS ti
        ON mt.transactionheaderid = ti.transactionheaderid
       AND mt.itemid              = ti.itemid
    INNER JOIN org_loc_ctlg_modifiers AS olcm
        ON ti.locationid = olcm.locationid
       AND mt.modifierid = olcm.modifierid
    INNER JOIN dim.menuitem AS mi
        ON mi.menuitemid = ti.dimmenuitemid
    LEFT JOIN dim.modifier_group_mapping AS mgm
        ON mgm.modifiergroupid = mt.modifiergroupid
       AND mgm.modifierid      = mt.modifierid
    LEFT JOIN dim.modifier_group AS mg
        ON mg.modifiergroupid = mt.modifiergroupid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_modifier_interactions(DATE) OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 9: ml.usp_refresh_modifier_impressions
-- Refresh type : WEEKLY DELETE + INSERT (idempotent)
-- Parquet file : modifier-impressions-yyww.parquet
-- Parameter    : p_businessdate DATE (default: yesterday)
-- Notes        : Source is fact.modifier_impressions (not fact.itemmodifier).
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_modifier_impressions(
    p_businessdate DATE DEFAULT CURRENT_DATE - 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_yyyy INTEGER := EXTRACT(YEAR FROM p_businessdate)::INTEGER;
    v_ww   INTEGER := EXTRACT(WEEK FROM p_businessdate)::INTEGER;
BEGIN

    DELETE FROM ml.modifier_impressions
    WHERE yyyy = v_yyyy
      AND ww   = v_ww;

    INSERT INTO ml.modifier_impressions (
        organizationid,
        organizationname,
        locationname,
        locationid,
        catalogid,
        catalogname,
        businessdate,
        orderdatelocal,
        yyyy,
        ww,
        transactionheaderid,
        ordersessionid,
        orderid,
        menuitemid,
        menuitemname,
        item_class_type,
        modifierid,
        modifiername,
        modifier_class_type,
        parent_modifier_id,
        nesting_depth,
        modifierprice,
        selection_type,
        position,
        score,
        strategy,
        conTEXT COLLATE pg_catalog."default",
        selected,
        pre_deselected,
        confirmed_removed,
        pre_selected,
        frequentcustomerid,
        sysinserttime
    )
    WITH org_loc_lookup AS (
        SELECT DISTINCT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname
        FROM dim.organizationlocation AS ol
        WHERE ol.organizationtype = 0
    ),
    org_loc_ctlg AS (
        SELECT ol.*, c.catalogid, c.catalogname
        FROM org_loc_lookup AS ol
        INNER JOIN dim.catalog AS c
            ON ol.organizationid = c.organizationid
           AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        SELECT m.*, olc.organizationid, olc.organizationname, olc.locationid, olc.locationname, olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
        WHERE (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER = v_yyyy
            AND EXTRACT(WEEK FROM m.modifier_created_on)::INTEGER <= v_ww
        )
        OR (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER < v_yyyy
        )
    ),
    trxn_items AS (
        SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.*
        FROM fact.modifier_impressions AS ti
        INNER JOIN org_loc_lookup AS ol
            ON ti.locationid = ol.locationid
        WHERE LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
          AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = v_yyyy
          AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = v_ww
    )
    SELECT
        olcm.organizationid,
        olcm.organizationname,
        olcm.locationname,
        olcm.locationid,
        olcm.catalogid,
        olcm.catalogname,
        m.businessdate,
        m.orderdatelocal,
        v_yyyy                  AS yyyy,
        v_ww                    AS ww,
        m.transactionheaderid,
        m.ordersessionid,
        m.orderid,
        m.menuitemid,
        mi.menuitemname,
        mi.item_class_type,
        m.modifierid,
        olcm.modifiername,
        olcm.classification     AS modifier_class_type,
        m.parent_modifier_id,
        m.nesting_depth,
        olcm.price              AS modifierprice,
        m.selection_type,
        m.position,
        m.score,
        m.strategy,
        m.conTEXT COLLATE pg_catalog."default",
        m.selected,
        m.pre_deselected,
        m.confirmed_removed,
        m.pre_selected,
        m.frequentcustomerid,
        NOW()::TIMESTAMP        AS sysinserttime
    FROM trxn_items AS m
    INNER JOIN org_loc_ctlg_modifiers AS olcm
        ON m.locationid  = olcm.locationid
       AND m.modifierid  = olcm.modifierid
    INNER JOIN dim.menuitem AS mi
        ON mi.menuitemid = m.menuitemid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_modifier_impressions(DATE) OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 10: ml.usp_refresh_item_modifier_mapping
-- Refresh type : WEEKLY DELETE + INSERT (idempotent)
-- Parquet file : item-modifiergroup-modifier-mapping-yyww.parquet
-- Parameter    : p_businessdate DATE (default: yesterday)
-- Notes        : No businessdate in output; keyed by yyyy + ww only.
--                Combines catalog modifier metadata with weekly
--                transaction-based selection frequency stats.
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_item_modifier_mapping(
    p_businessdate DATE DEFAULT CURRENT_DATE - 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_yyyy INTEGER := EXTRACT(YEAR FROM p_businessdate)::INTEGER;
    v_ww   INTEGER := EXTRACT(WEEK FROM p_businessdate)::INTEGER;
BEGIN

    DELETE FROM ml.item_modifier_mapping
    WHERE yyyy = v_yyyy
      AND ww   = v_ww;

    INSERT INTO ml.item_modifier_mapping (
        organizationid,
        organizationname,
        locationid,
        locationname,
        catalogid,
        catalogname,
        yyyy,
        ww,
        menuitemid,
        menuitemname,
        item_class_type,
        modifiergroupid,
        modifiergroupname,
        modifierid,
        modifiername,
        modifier_class_type,
        is_modifier_default,
        min_quantity,
        max_quantity,
        allow_quantity_increment,
        increment_step,
        modifier_default_quantity,
        is_modifier_invisible,
        calories,
        is_modifier_active,
        is_modifier_deleted,
        x_times_added_on_to_the_item,
        mdfr_selection_frequency_within_loc_and_week,
        pct_relative_selection_frequency,
        sysinserttime
    )
    WITH org_loc_lookup AS (
        SELECT DISTINCT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname
        FROM dim.organizationlocation AS ol
        WHERE ol.organizationtype = 0
    ),
    org_loc_ctlg AS (
        SELECT ol.*, c.catalogid, c.catalogname
        FROM org_loc_lookup AS ol
        INNER JOIN dim.catalog AS c
            ON ol.organizationid = c.organizationid
           AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        SELECT m.*, olc.organizationid, olc.organizationname, olc.locationid, olc.locationname, olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
        WHERE (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER = v_yyyy
            AND EXTRACT(WEEK FROM m.modifier_created_on)::INTEGER <= v_ww
        )
        OR (
            EXTRACT(YEAR FROM m.modifier_created_on)::INTEGER < v_yyyy
        )
    ),
    trxn_items AS (
        SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.*
        FROM fact.transactionitem AS ti
        INNER JOIN org_loc_lookup AS ol
            ON ti.locationid = ol.locationid
        WHERE LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
          AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = v_yyyy
          AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = v_ww
    ),
    trxn_modifiers AS (
        SELECT
            ti.organizationid,
            ti.organizationname,
            ti.locationname,
            ti.locationid,
            ti.businessdate,
            ti.orderdatelocal,
            m.transactionheaderid,
            m.itemid            AS orderitemid,
            ti.dimmenuitemid    AS menuitemid,
            ti.itemquantity,
            ti.itemunitprice,
            m.modifiergroupid,
            m.modifierid,
            m.modifiername,
            m.modifierquantity,
            m.modifierprice,
            m.freequantity
        FROM fact.itemmodifier AS m
        INNER JOIN trxn_items AS ti
            ON m.transactionheaderid = ti.transactionheaderid
           AND m.itemid              = ti.itemid
    ),
    loc_mdfr_agg AS (
        SELECT
            organizationid,
            locationid,
            modifierid,
            COUNT(*)         AS mdfr_selection_frequency_within_loc_and_week,
            MAX(modifierprice) AS modifierprice
        FROM trxn_modifiers
        GROUP BY organizationid, locationid, modifierid
    ),
    loc_mdfr_itm AS (
        SELECT
            organizationid,
            locationid,
            modifierid,
            menuitemid,
            COUNT(*)         AS x_times_added_on_to_the_item,
            ROW_NUMBER() OVER (
                PARTITION BY organizationid, locationid, modifierid
                ORDER BY COUNT(*) DESC
            )                AS mdfr_selection_ranking
        FROM trxn_modifiers
        GROUP BY organizationid, locationid, modifierid, menuitemid
    )
    SELECT
        m.organizationid,
        m.organizationname,
        m.locationid,
        m.locationname,
        m.catalogid,
        m.catalogname,
        v_yyyy                                        AS yyyy,
        v_ww                                          AS ww,
        imgm.menuitemid,
        mi.menuitemname,
        mi.item_class_type,
        imgm.modifiergroupid,
        mg.modifiergroupname,
        imgm.modifierid,
        m.modifiername,
        m.classification                              AS modifier_class_type,
        imgm.is_default                               AS is_modifier_default,
        mg.min_selection                              AS min_quantity,
        mg.max_selection                              AS max_quantity,
        m.allow_quantity_increment,
        m.increment_step,
        m.modifier_default_quantity,
        m.is_invisible                                AS is_modifier_invisible,
        m.calories,
        m.is_modifier_active,
        m.is_modifier_deleted,
        lmi.x_times_added_on_to_the_item,
        lma.mdfr_selection_frequency_within_loc_and_week,
        ROUND(
            100 * CAST(lmi.x_times_added_on_to_the_item AS NUMERIC(9,3))
            / lma.mdfr_selection_frequency_within_loc_and_week,
            3
        )                                             AS pct_relative_selection_frequency,
        NOW()::TIMESTAMP                              AS sysinserttime
    FROM dim.item_modifier_group_modifier_mapping AS imgm
    INNER JOIN org_loc_ctlg_modifiers AS m
        ON imgm.catalogid  = m.catalogid
       AND imgm.modifierid = m.modifierid
    INNER JOIN dim.menuitem AS mi
        ON imgm.menuitemid = mi.menuitemid
    INNER JOIN dim.modifier_group AS mg
        ON imgm.catalogid      = mg.catalogid
       AND imgm.modifiergroupid = mg.modifiergroupid
    LEFT JOIN loc_mdfr_itm AS lmi
        ON m.organizationid  = lmi.organizationid
       AND m.locationid       = lmi.locationid
       AND imgm.modifierid    = lmi.modifierid
       AND imgm.menuitemid    = lmi.menuitemid
    LEFT JOIN loc_mdfr_agg AS lma
        ON m.organizationid  = lma.organizationid
       AND m.locationid       = lma.locationid
       AND imgm.modifierid    = lma.modifierid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_item_modifier_mapping(DATE) OWNER TO citus;


-- ============================================================
-- OWNERSHIP: transfer all ml objects to citus role
-- ============================================================
ALTER SCHEMA ml OWNER TO citus;


-- ============================================================
-- USAGE EXAMPLES
-- ============================================================
/*
-- Run all static refreshes (call once daily, e.g. at 02:00 AM):
CALL ml.usp_refresh_frequent_customers();
CALL ml.usp_refresh_location_stats();
CALL ml.usp_refresh_master_items();

-- Run all weekly refreshes for yesterday (default):
CALL ml.usp_refresh_transactions();
CALL ml.usp_refresh_upsell_analysis();
CALL ml.usp_refresh_weather();
CALL ml.usp_refresh_menu_entities();
CALL ml.usp_refresh_modifier_interactions();
CALL ml.usp_refresh_modifier_impressions();
CALL ml.usp_refresh_item_modifier_mapping();

-- Backfill a specific date / week:
CALL ml.usp_refresh_transactions('2026-01-07');
CALL ml.usp_refresh_upsell_analysis('2026-01-07');
-- ... etc.

-- ADF Copy Activity source queries (replace :yyyy and :ww with ADF params):
-- SELECT * FROM ml.transactions              WHERE yyyy = {yyyy} AND ww = {ww} AND locationid = '{orgid_or_locid}';
-- SELECT * FROM ml.upsell_analysis           WHERE yyyy = {yyyy} AND ww = {ww} AND locationid = '{orgid_or_locid}';
-- SELECT * FROM ml.weather                   WHERE yyyy = {yyyy} AND ww = {ww} AND locationid = '{orgid_or_locid}';
-- SELECT * FROM ml.menu_entities             WHERE yyyy = {yyyy} AND ww = {ww} AND locationid = '{orgid_or_locid}';
-- SELECT * FROM ml.modifier_interactions     WHERE yyyy = {yyyy} AND ww = {ww} AND locationid = '{orgid_or_locid}';
-- SELECT * FROM ml.modifier_impressions      WHERE yyyy = {yyyy} AND ww = {ww} AND locationid = '{orgid_or_locid}';
-- SELECT * FROM ml.item_modifier_mapping     WHERE yyyy = {yyyy} AND ww = {ww} AND locationid = '{orgid_or_locid}';
-- SELECT * FROM ml.frequent_customers        WHERE organizationid = '{orgid}';
-- SELECT * FROM ml.location_stats            WHERE (CASE WHEN '{orgid}' NOT LIKE 'loc-%' THEN organizationid ELSE locationid END) = '{orgid}';
-- SELECT * FROM ml.master_items              WHERE (CASE WHEN '{orgid}' NOT LIKE 'loc-%' THEN organizationid ELSE locationid END) = '{orgid}';
*/
