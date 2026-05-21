-- ============================================================
-- 0. SCHEMA
-- ============================================================
CREATE SCHEMA IF NOT EXISTS ml;
/*
CALL ml.usp_refresh_weather(p_refresh_mode => 0);
CALL ml.usp_refresh_menu_entities();
CALL ml.usp_refresh_transactions(p_refresh_mode => 0);
CALL ml.usp_refresh_upsell_analysis(p_refresh_mode => 0);
CALL ml.usp_refresh_modifier_interactions(p_refresh_mode => 0);
CALL ml.usp_refresh_modifier_impressions(p_refresh_mode => 0);


ALTER TABLE ml.menu_entities
ALTER COLUMN itemunitprice TYPE NUMERIC(12,3);

ALTER TABLE ml.transactions
ALTER COLUMN itemunitprice TYPE NUMERIC(12,3);

ALTER TABLE ml.modifier_interactions
ALTER COLUMN itemunitprice TYPE NUMERIC(12,3),
ALTER COLUMN modifierprice TYPE NUMERIC(12,3);

ALTER TABLE ml.modifier_impressions
ALTER COLUMN modifierprice TYPE NUMERIC(12,3);
*/
-- ============================================================
-- STORED PROCEDURE 1: ml.usp_refresh_weather
-- Refresh type : DAILY DELETE + INSERT (idempotent) / FULL TRUNCATE + INSERT
-- Parameters   : p_refresh_mode INT   (default: 1)
--                  1 = Incremental – delete/insert for p_businessdate only
--                  0 = Full load   – TRUNCATE the table, then insert ALL history
-- Notes        : Date column in output is weatherdate (not businessdate).
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
    humidity                     INTEGER,
    condition                    TEXT COLLATE pg_catalog."default",
    temperature_c                NUMERIC(8,2),
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
    food_weather                 TEXT COLLATE pg_catalog."default",
    is_heavy_rain                BOOLEAN,
    is_light_rain                BOOLEAN,
    is_nighttime                 BOOLEAN,
    is_very_windy                BOOLEAN,
    pressure_hpa                 NUMERIC(8,2),
    weather_code                 INTEGER,
    wind_gust_kmh                NUMERIC(8,2),
    comfort_score                INTEGER,
    drink_weather                TEXT COLLATE pg_catalog."default",
    wind_speed_kmh               NUMERIC(8,2),
    comfort_bucket               TEXT COLLATE pg_catalog."default",
    humidity_bucket              TEXT COLLATE pg_catalog."default",
    condition_bucket             TEXT COLLATE pg_catalog."default",
    is_precipitating             BOOLEAN,
    precipitation_mm             NUMERIC(8,2),
    visibility_meters            NUMERIC(8,2),
    cloud_cover_percent          NUMERIC(8,2),
    is_unseasonably_hot          BOOLEAN,
    is_unseasonably_cold         BOOLEAN,
    outdoor_dining_score         INTEGER,
    wind_direction_degrees       INTEGER,
    precipitation_probability    NUMERIC(8,2),
    apparent_temperature_celsius NUMERIC(8,2),
    sysinserttime                TIMESTAMP
);

/*

CREATE INDEX IF NOT EXISTS ix_ml_wth_yyyy_ww
    ON ml.weather (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_wth_locid_yyyy_ww
    ON ml.weather (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_wth_weatherdate
    ON ml.weather (weatherdate);
CREATE INDEX IF NOT EXISTS ix_ml_wth_locationid_weatherdate_hh
    ON ml.weather (locationid, weatherdate, hh);
*/

CREATE OR REPLACE PROCEDURE ml.usp_refresh_weather(
    p_refresh_mode  INT  DEFAULT 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_max_weatherdate DATE;
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.weather;
    ELSE
        -- Incremental: capture the current max date, delete it,
        -- then reload from that date forward (picks up any new data too)
        SELECT MAX(weatherdate) INTO v_max_weatherdate FROM ml.weather;

        DELETE FROM ml.weather
        WHERE weatherdate >= v_max_weatherdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM dim.vw_weatherhourlydata
        WHERE (
            p_refresh_mode = 0
            OR weatherdate >= v_max_weatherdate
        )
    )
    INSERT INTO ml.weather
    SELECT
        ol.organizationid,
        ol.organizationname,
        cte.locationid,
        ol.locationname,
        cte.weatherdate,
        EXTRACT(YEAR  FROM cte.weatherdate)::INTEGER AS yyyy,
        EXTRACT(MONTH FROM cte.weatherdate)::INTEGER AS mm,
        EXTRACT(DAY   FROM cte.weatherdate)::INTEGER AS dd,
        EXTRACT(WEEK  FROM cte.weatherdate)::INTEGER AS ww,
        cte.hh,
        cte.humidity,
        cte.condition,
        cte.temperature_c,
        cte.is_hot,
        cte.is_calm,
        cte.is_cold,
        cte.is_cool,
        cte.is_mild,
        cte.is_warm,
        cte.rain_mm,
        cte.is_sunny,
        cte.is_windy,
        cte.is_cloudy,
        cte.is_daytime,
        cte.is_raining,
        cte.is_snowing,
        cte.is_very_hot,
        cte.is_freezing,
        cte.is_overcast,
        cte.snowfall_mm,
        cte.temp_bucket,
        cte.wind_bucket,
        cte.feels_colder,
        cte.feels_hotter,
        cte.food_weather,
        cte.is_heavy_rain,
        cte.is_light_rain,
        cte.is_nighttime,
        cte.is_very_windy,
        cte.pressure_hpa,
        cte.weather_code,
        cte.wind_gust_kmh,
        cte.comfort_score,
        cte.drink_weather,
        cte.wind_speed_kmh,
        cte.comfort_bucket,
        cte.humidity_bucket,
        cte.condition_bucket,
        cte.is_precipitating,
        cte.precipitation_mm,
        cte.visibility_meters,
        cte.cloud_cover_percent,
        cte.is_unseasonably_hot,
        cte.is_unseasonably_cold,
        cte.outdoor_dining_score,
        cte.wind_direction_degrees,
        cte.precipitation_probability,
        cte.apparent_temperature_celsius,
        NOW()::TIMESTAMP                             AS sysinserttime
    FROM cte
    LEFT JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON cte.locationid = ol.locationid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_weather(INT) OWNER TO citus;






-- ============================================================
-- STORED PROCEDURE 2: ml.usp_refresh_menu_entities
-- Refresh type : FULL TRUNCATE + INSERT on every run
-- Notes        : Pure dimension data — no parameters, no date scoping.
--                No dependency on ml.transactions.
--                Metrics and trends computed at extraction time.
-- ============================================================

DROP TABLE IF EXISTS ml.menu_entities;
CREATE TABLE IF NOT EXISTS ml.menu_entities (
    organizationid     TEXT COLLATE pg_catalog."default",
    organizationname   TEXT COLLATE pg_catalog."default",
    locationid         TEXT COLLATE pg_catalog."default",
    locationname       TEXT COLLATE pg_catalog."default",
    categoryid         TEXT COLLATE pg_catalog."default",
    categoryname       TEXT COLLATE pg_catalog."default",
    menuitemid         TEXT COLLATE pg_catalog."default",
    menuitemname       TEXT COLLATE pg_catalog."default",
    catalogid          TEXT COLLATE pg_catalog."default",
    itemunitprice      NUMERIC(12,3),
    price_changed_on   TIMESTAMP,
    item_class_type    INTEGER,
    entitytype         TEXT COLLATE pg_catalog."default",
    calories           TEXT COLLATE pg_catalog."default", --NUMERIC(9,2),
    protein            NUMERIC(9,2),
    sugar              NUMERIC(9,2),
    fat                NUMERIC(9,2),
    is_alcoholic       BOOLEAN,
    is_vegetarian_item BOOLEAN,
    is_vegan_item      BOOLEAN,
    has_allergen       BOOLEAN,
    is_active          BOOLEAN,
    is_deleted         BOOLEAN,
    gms_created_on     TIMESTAMP,
    gms_modified_on    TIMESTAMP,
    sysinserttime      TIMESTAMP
);

/*

CREATE INDEX IF NOT EXISTS ix_ml_me_locationid
    ON ml.menu_entities (locationid);
CREATE INDEX IF NOT EXISTS ix_ml_me_menuitemid
    ON ml.menu_entities (menuitemid);
*/



CREATE OR REPLACE PROCEDURE ml.usp_refresh_menu_entities()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Truncate on every run
    -- --------------------------------------------------------
    TRUNCATE TABLE ml.menu_entities;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH category_hierarchy AS (
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
        INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
            ON ctgh.locationid = ol.locationid
    )
    INSERT INTO ml.menu_entities
    SELECT DISTINCT
        mi.organizationid,
        mi.organizationname,
        mi.locationid,
        mi.locationname,
        mi.categoryid,
        mi.categoryname,
        mi.menuitemid,
        mi.menuitemname,
        mi.catalogid,
        mi.itemunitprice,
        mi.price_changed_on,
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
        mi.is_active,
        mi.is_deleted,
        mi.gms_created_on,
        mi.gms_modified_on,
        NOW()::TIMESTAMP     AS sysinserttime
    FROM category_hierarchy AS mi;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_menu_entities() OWNER TO citus;


-- ============================================================
-- STORED PROCEDURE 3: ml.usp_refresh_item_modifiergroup_modifier_mapping
-- Refresh type : FULL TRUNCATE + INSERT on every run
-- Notes        : Pure dimension data — no parameters, no date scoping.
--                Selection frequency stats computed at extraction time.
-- ============================================================


CREATE TABLE IF NOT EXISTS ml.item_modifiergroup_modifier_mapping (
    organizationid            TEXT COLLATE pg_catalog."default",
    organizationname          TEXT COLLATE pg_catalog."default",
    locationid                TEXT COLLATE pg_catalog."default",
    locationname              TEXT COLLATE pg_catalog."default",
    catalogid                 TEXT COLLATE pg_catalog."default",
    catalogname               TEXT COLLATE pg_catalog."default",
    menuitemid                TEXT COLLATE pg_catalog."default",
    menuitemname              TEXT COLLATE pg_catalog."default",
    item_class_type           INTEGER,
    modifiergroupid           TEXT COLLATE pg_catalog."default",
    modifiergroupname         TEXT COLLATE pg_catalog."default",
    modifierid                TEXT COLLATE pg_catalog."default",
    modifiername              TEXT COLLATE pg_catalog."default",
    modifier_class_type       INTEGER,
    is_modifier_default       BOOLEAN,
    min_quantity              INTEGER,
    max_quantity              INTEGER,
    allow_quantity_increment  BOOLEAN,
    increment_step            INTEGER,
    modifier_default_quantity INTEGER,
    is_modifier_invisible     BOOLEAN,
    calories                  TEXT COLLATE pg_catalog."default",
    price                     NUMERIC(12,3),
    is_modifier_active        BOOLEAN,
    is_modifier_deleted       BOOLEAN,
    modifier_created_on       TIMESTAMP,
    modifier_modified_on      TIMESTAMP,
    sysinserttime             TIMESTAMP
);

/*

CREATE INDEX IF NOT EXISTS ix_ml_imm_locationid
    ON ml.item_modifiergroup_modifier_mapping (locationid);
CREATE INDEX IF NOT EXISTS ix_ml_imm_menuitemid
    ON ml.item_modifiergroup_modifier_mapping (menuitemid);
CREATE INDEX IF NOT EXISTS ix_ml_imm_modifierid
    ON ml.item_modifiergroup_modifier_mapping (modifierid);
*/




CREATE OR REPLACE PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(
    p_organizationid TEXT  -- or replace INT with the appropriate type (e.g. UUID, BIGINT)
)
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Delete only rows for this organization on every run
    -- --------------------------------------------------------
    WITH org_loc_lookup AS (
        SELECT organizationid, organizationname, locationid, locationname
        FROM dim.organizationlocation
        WHERE CASE WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = p_organizationid
          AND organizationtype = 0
    )
    DELETE FROM ml.item_modifiergroup_modifier_mapping
    WHERE locationid IN (SELECT locationid FROM org_loc_lookup);

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH org_loc_ctlg AS (
        SELECT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname,
               c.catalogid, c.catalogname
        FROM (
            SELECT * FROM dim.organizationlocation
            WHERE CASE WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = p_organizationid
              AND organizationtype = 0 
        ) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        SELECT
            m.*,
            olc.organizationid,
            olc.organizationname,
            olc.locationid,
            olc.locationname,
            --olc.catalogid,
            olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
    )
    INSERT INTO ml.item_modifiergroup_modifier_mapping
    SELECT
        m.organizationid,
        m.organizationname,
        m.locationid,
        m.locationname,
        m.catalogid,
        m.catalogname,
        imgm.menuitemid,
        mi.menuitemname,
        mi.item_class_type,
        imgm.modifiergroupid,
        mg.modifiergroupname,
        imgm.modifierid,
        m.modifiername,
        m.classification            AS modifier_class_type,
        imgm.is_default             AS is_modifier_default,
        mg.min_selection            AS min_quantity,
        mg.max_selection            AS max_quantity,
        m.allow_quantity_increment,
        m.increment_step,
        m.modifier_default_quantity,
        m.is_invisible              AS is_modifier_invisible,
        m.calories,
        m.price,
        m.is_modifier_active,
        m.is_modifier_deleted,
        m.modifier_created_on,
        m.modifier_modified_on,
        NOW()::TIMESTAMP            AS sysinserttime
    FROM dim.item_modifier_group_modifier_mapping AS imgm
    INNER JOIN org_loc_ctlg_modifiers AS m
        ON  imgm.catalogid  = m.catalogid
        AND imgm.modifierid = m.modifierid
    INNER JOIN dim.menuitem AS mi
        ON imgm.catalogid = mi.catalogid
        AND imgm.menuitemid = mi.menuitemid
    INNER JOIN dim.modifier_group AS mg
        ON  imgm.catalogid       = mg.catalogid
        AND imgm.modifiergroupid = mg.modifiergroupid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(TEXT) OWNER TO citus;




-- ============================================================
-- STORED PROCEDURE 4: ml.usp_refresh_transactions
--
-- PURPOSE:
--   Refreshes the ml.transactions table from the source fact and
--   dimension tables. Supports two modes: a full historical reload
--   or an incremental refresh that picks up from where the last
--   successful load left off.
--
-- PARAMETERS:
--   p_refresh_mode  INT  (default: 1)
--     1 = Incremental – deletes and reloads data from the current
--         max(businessdate) in the target table onward. This ensures
--         the most recent (potentially partial) day is always corrected,
--         and any new data since the last run is captured.
--     0 = Full load – truncates the entire table and reloads all
--         available history from the source. Use sparingly; intended
--         for initial loads or full reseeds only.
--
-- INCREMENTAL LOGIC:
--   The procedure reads max(businessdate) from ml.transactions at
--   runtime and stores it in v_max_businessdate. This same value is
--   used for both the DELETE and the source query, guaranteeing they
--   are always in sync regardless of when the proc runs.
--   On a cold start (empty table), v_max_businessdate will be NULL,
--   causing the WHERE filter to evaluate to NULL and load everything —
--   effectively behaving like a full load automatically.
--
-- SOURCE OBJECTS:
--   fact.transactionheader        – one row per order, filtered to 'order-placed' status
--   fact.transactionitem          – one row per line item within an order
--   dim.organizationlocation      – maps locationid to org/location names (type=0 only)
--   dim.itemcategory              – category name lookup for each item
--   dim.menuitem                  – menu item classification lookup
--   dim.ordertype                 – human-readable order type label
--   ml.weather                    – hourly weather data joined by location + date + hour
--
-- TARGET TABLE:
--   ml.transactions
--
-- OWNER: citus
-- ============================================================
-- DROP TABLE IF EXISTS ml.transactions
CREATE TABLE IF NOT EXISTS ml.transactions (
    frequentcustomerid   TEXT COLLATE pg_catalog."default",
    organizationid       TEXT COLLATE pg_catalog."default",
    organizationname     TEXT COLLATE pg_catalog."default",
    locationid           TEXT COLLATE pg_catalog."default",
    locationname         TEXT COLLATE pg_catalog."default",
    kioskid              TEXT COLLATE pg_catalog."default",
    transactionheaderid  TEXT COLLATE pg_catalog."default",
    ordersessionid       TEXT COLLATE pg_catalog."default",
    orderid              TEXT COLLATE pg_catalog."default",
    orderitemid          TEXT COLLATE pg_catalog."default",
    menuitemid           TEXT COLLATE pg_catalog."default",
    itemname             TEXT COLLATE pg_catalog."default",
    upselllevel          TEXT COLLATE pg_catalog."default",
    item_class_type      INTEGER,
    itemquantity         INTEGER,
    categoryid           TEXT COLLATE pg_catalog."default",
    categoryname         TEXT COLLATE pg_catalog."default",
    itemunitprice        NUMERIC(12,3),
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

/*

CREATE INDEX IF NOT EXISTS ix_ml_trx_yyyy_ww
    ON ml.transactions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_trx_locid_yyyy_ww
    ON ml.transactions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_trx_businessdate
    ON ml.transactions (businessdate);

*/

CREATE OR REPLACE PROCEDURE ml.usp_refresh_transactions(
    p_refresh_mode  INT  DEFAULT 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_max_businessdate DATE;  -- Holds the current max date in the target table;
                              -- used to anchor both the delete and the source filter
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.transactions;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.transactions;

        DELETE FROM ml.transactions
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM fact.transactionheader AS th
        WHERE LOWER(th.orderstatus) = 'order-placed'   -- exclude cancelled, pending, etc.
          AND (
                p_refresh_mode = 0                     -- full load: no date restriction
                OR th.businessdate >= v_max_businessdate  -- incremental: from max date onward
          )
    )
    INSERT INTO ml.transactions
    SELECT DISTINCT
        th.frequentcustomerid,
        ol.organizationid,
        ol.organizationname,
        th.locationid,
        ol.locationname,
        th.kioskid,
        th.transactionheaderid,
        th.ordersessionid,
        th.orderid,
        ti.itemid                                                    AS orderitemid,
        ti.dimmenuitemid                                             AS menuitemid,
        ti.itemname,
        COALESCE(ti.upselllevel, '')                                 AS upselllevel,  -- default to empty string if no upsell
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
        wh.humidity                                                  AS weatherhumidity,     -- weather at time of order
        wh.condition                                                 AS weathercondition,
        wh.temperature_c                                             AS temperatureincelcius,
        EXTRACT(YEAR  FROM th.businessdate)::INTEGER                 AS yyyy,
        EXTRACT(MONTH FROM th.businessdate)::INTEGER                 AS mm,
        EXTRACT(DAY   FROM th.businessdate)::INTEGER                 AS dd,
        EXTRACT(HOUR  FROM th.orderdatelocal)::INTEGER               AS hh,
        EXTRACT(WEEK  FROM th.businessdate)::INTEGER                 AS ww,
        NOW()::TIMESTAMP                                             AS sysinserttime  -- audit timestamp for when the row was loaded
    FROM cte AS th
    INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON th.locationid = ol.locationid                            -- type=0 filters to standard locations only
    INNER JOIN fact.transactionitem AS ti
        ON th.transactionheaderid = ti.transactionheaderid          -- expand header to one row per item
    LEFT JOIN ml.weather AS wh
        ON  th.locationid          = wh.locationid
        AND th.businessdate        = wh.weatherdate
        AND EXTRACT(HOUR FROM th.orderdatelocal)::INTEGER = wh.hh  -- match weather to the exact hour of the order
    LEFT JOIN dim.itemcategory AS ctg
        ON ti.categoryid = ctg.id
    LEFT JOIN dim.menuitem AS mi
        ON ti.menuitemid = mi.id
    LEFT JOIN dim.ordertype AS ot
        ON th.ordertype = ot.id;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_transactions(INTEGER) OWNER TO citus;





-- ============================================================
-- STORED PROCEDURE: ml.usp_refresh_upsell_analysis
--
-- PURPOSE:
--   Refreshes the ml.upsell_analysis table by joining upsell offer
--   data with transaction headers, org/location info, and menu item
--   classifications. Supports a full historical reload or an
--   incremental refresh from the last loaded date onward.
--
-- PARAMETERS:
--   p_refresh_mode  INT  (default: 1)
--     1 = Incremental – deletes and reloads data from the current
--         max(businessdate) in the target table onward. Ensures the
--         most recent (potentially partial) day is corrected and any
--         new data since the last run is captured.
--     0 = Full load – truncates the entire table and reloads all
--         available history from the source. Use sparingly; intended
--         for initial loads or full reseeds only.
--
-- INCREMENTAL LOGIC:
--   The procedure reads max(businessdate) from ml.upsell_analysis at
--   runtime and stores it in v_max_businessdate. This same value is
--   used for both the DELETE and the source query, guaranteeing they
--   are always in sync regardless of when the proc runs.
--   On a cold start (empty table), v_max_businessdate will be NULL,
--   causing the WHERE filter to evaluate to NULL and load everything —
--   effectively behaving like a full load automatically.
--
-- SOURCE OBJECTS:
--   fact.vw_offer_analysis        – one row per upsell offer/selection event
--   fact.transactionheader        – joined to bring in businessdate, orderdatelocal,
--                                   and frequentcustomerid
--   dim.organizationlocation      – maps locationid to org/location names (type=0 only)
--   dim.menuitem                  – item classification lookup; uses offereditem unless
--                                   it is a category-level offer (prefixed 'cat-'),
--                                   in which case selecteditem is used instead
--
-- TARGET TABLE:
--   ml.upsell_analysis
--
-- OWNER: citus
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
    item_class_type     INTEGER, -- TEXT COLLATE pg_catalog."default",
    upselltype          TEXT COLLATE pg_catalog."default",
    quantity            INTEGER, --NUMERIC(10,3),
    businessdate        DATE,
    orderdatelocal      TIMESTAMP,
    yyyy                INTEGER,
    mm                  INTEGER,
    dd                  INTEGER,
    hh                  INTEGER,
    ww                  INTEGER,
    sysinserttime       TIMESTAMP
);

/*

CREATE INDEX IF NOT EXISTS ix_ml_ua_yyyy_ww
    ON ml.upsell_analysis (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_ua_locid_yyyy_ww
    ON ml.upsell_analysis (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_ua_businessdate
    ON ml.upsell_analysis (businessdate);

*/

CREATE OR REPLACE PROCEDURE ml.usp_refresh_upsell_analysis(
    p_refresh_mode  INT  DEFAULT 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_max_businessdate DATE;  -- Holds the current max date in the target table;
                              -- used to anchor both the delete and the source filter
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.upsell_analysis;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.upsell_analysis;

        DELETE FROM ml.upsell_analysis
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM fact.transactionheader
        WHERE (
                p_refresh_mode = 0                        -- full load: no date restriction
                OR businessdate >= v_max_businessdate     -- incremental: from max date onward
        )
    )
    INSERT INTO ml.upsell_analysis
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
        EXTRACT(YEAR  FROM th.businessdate)::INTEGER   AS yyyy,
        EXTRACT(MONTH FROM th.businessdate)::INTEGER   AS mm,
        EXTRACT(DAY   FROM th.businessdate)::INTEGER   AS dd,
        EXTRACT(HOUR  FROM th.orderdatelocal)::INTEGER AS hh,
        EXTRACT(WEEK  FROM th.businessdate)::INTEGER   AS ww,
        NOW()::TIMESTAMP                               AS sysinserttime  -- audit timestamp for when the row was loaded
    FROM fact.vw_offer_analysis AS oa
    INNER JOIN cte AS th
        ON  oa.locationid          = th.locationid
        AND oa.transactionheaderid = th.transactionheaderid
    LEFT JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON oa.locationid = ol.locationid                -- type=0 filters to standard locations only
    LEFT JOIN dim.menuitem AS mi
        ON (
            CASE
                WHEN oa.offereditem NOT LIKE 'cat-%' THEN oa.offereditem  -- item-level offer: use offereditem directly
                ELSE oa.selecteditem                                       -- category-level offer: fall back to what was actually selected
            END
        ) = mi.menuitemid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_upsell_analysis(INT) OWNER TO citus;



-- ============================================================
-- STORED PROCEDURE: ml.usp_refresh_modifier_interactions
--
-- PURPOSE:
--   Refreshes the ml.modifier_interactions table by expanding
--   transaction items into their individual modifier selections.
--   Enriches each modifier interaction with group rules, selection
--   type classification, and the action taken (added, removed,
--   kept, selected). Supports a full historical reload or an
--   incremental refresh from the last loaded date onward.
--
-- PARAMETERS:
--   p_refresh_mode  INT  (default: 1)
--     1 = Incremental – deletes and reloads data from the current
--         max(businessdate) in the target table onward. Ensures the
--         most recent (potentially partial) day is corrected and any
--         new data since the last run is captured.
--     0 = Full load – truncates the entire table and reloads all
--         available history from the source. Use sparingly; intended
--         for initial loads or full reseeds only.
--
-- INCREMENTAL LOGIC:
--   The procedure reads max(businessdate) from ml.modifier_interactions
--   at runtime and stores it in v_max_businessdate. This same value is
--   used for both the DELETE and the source query, guaranteeing they
--   are always in sync regardless of when the proc runs.
--   On a cold start (empty table), v_max_businessdate will be NULL,
--   causing the WHERE filter to evaluate to NULL and load everything —
--   effectively behaving like a full load automatically.
--
-- DEPENDENCIES:
--   ml.transactions must be refreshed before running this procedure,
--   as it is used as the primary transaction source in the trxn_items CTE.
--
-- SOURCE OBJECTS:
--   ml.transactions               – pre-aggregated transaction items (must be current)
--   fact.itemmodifier             – one row per modifier applied to a transaction item
--   dim.organizationlocation      – maps locationid to org/location names (type=0 only)
--   dim.catalog                   – links org+location to a catalog
--   dim.modifier                  – modifier definitions and classifications
--   dim.menuitem                  – menu item name and class type lookup
--   dim.modifier_group_mapping    – maps modifiers to their groups, including is_default flag
--   dim.modifier_group            – modifier group rules (min/max selection quantities)
--
-- TARGET TABLE:
--   ml.modifier_interactions
--
-- OWNER: citus
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
    itemquantity              INTEGER,
    itemunitprice             NUMERIC(12,3),
    item_class_type           INTEGER,
    modifiergroupid           TEXT COLLATE pg_catalog."default",
    modifiergroupname         TEXT COLLATE pg_catalog."default",
    modifierid                TEXT COLLATE pg_catalog."default",
    modifiername              TEXT COLLATE pg_catalog."default",
    parent_modifier_id        TEXT COLLATE pg_catalog."default",
    nesting_depth             INTEGER,
    modifierquantity          INTEGER,
    modifierprice             NUMERIC(12,3),
    freequantity              INTEGER,
    is_modifier_default       BOOLEAN,
    min_quantity              INTEGER,
    max_quantity              INTEGER,
    selection_type            TEXT COLLATE pg_catalog."default",
    action                    TEXT COLLATE pg_catalog."default",
    session_recorded_at       TEXT COLLATE pg_catalog."default",
    frequentcustomerid        TEXT COLLATE pg_catalog."default",
    modifier_default_quantity INTEGER,
    modifier_class_type       INTEGER,
    sysinserttime             TIMESTAMP
);

-- 1. Grant USAGE on the schema (allows access to object names)
--GRANT USAGE ON SCHEMA ml TO varshil;
--GRANT SELECT ON TABLE ml.modifier_interactions TO varshil;

/*
CREATE INDEX IF NOT EXISTS ix_ml_mi_yyyy_ww
    ON ml.modifier_interactions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mi_locid_yyyy_ww
    ON ml.modifier_interactions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mi_businessdate
    ON ml.modifier_interactions (businessdate);

*/

CREATE OR REPLACE PROCEDURE ml.usp_refresh_modifier_interactions(
    p_refresh_mode  INT  DEFAULT 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_max_businessdate DATE;  -- Holds the current max date in the target table;
                              -- used to anchor both the delete and the source filter
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.modifier_interactions;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.modifier_interactions;

        DELETE FROM ml.modifier_interactions
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH trxn_items AS (
        -- Pull the relevant transaction item fields from ml.transactions.
        -- This is the date-filtered entry point for the entire query.
        SELECT
            tr.organizationid,
            tr.organizationname,
            tr.locationid,
            tr.locationname,
            tr.businessdate,
            tr.orderdatelocal,
            tr.transactionheaderid,
            tr.ordersessionid,
            tr.orderid,
            tr.orderitemid,
            tr.menuitemid,
            tr.itemquantity,
            tr.itemunitprice,
            tr.frequentcustomerid
        FROM ml.transactions AS tr
        WHERE (
                p_refresh_mode = 0                       -- full load: no date restriction
                OR tr.businessdate >= v_max_businessdate -- incremental: from max date onward
        )
    ),
    org_loc_ctlg AS (
        -- Resolve each org+location to its corresponding catalog.
        -- Type=0 filters to standard locations only.
        SELECT ol.organizationid, ol.locationid, c.catalogid, c.catalogname
        FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        -- Enrich each modifier with its catalog and location context
        -- so it can be joined to transaction items by locationid + modifierid.
        SELECT
            m.*,
            olc.organizationid,
            olc.locationid,
            olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
    )
    INSERT INTO ml.modifier_interactions
    SELECT
        ti.organizationid,
        ti.organizationname,
        ti.locationname,
        ti.locationid,
        olcm.catalogid,
        olcm.catalogname,
        ti.businessdate,
        ti.orderdatelocal,
        EXTRACT(YEAR FROM ti.businessdate)::INTEGER             AS yyyy,
        EXTRACT(WEEK FROM ti.businessdate)::INTEGER             AS ww,
        mt.transactionheaderid,
        ti.ordersessionid,
        ti.orderid,
        mt.itemid                                               AS orderitemid,
        ti.menuitemid,
        mi.menuitemname,
        ti.itemquantity,
        ti.itemunitprice,
        mi.item_class_type,
        mt.modifiergroupid,
        mg.modifiergroupname,
        mt.modifierid,
        mt.modifiername,
        NULL::TEXT                                              AS parent_modifier_id,   -- reserved for future nested modifier support
        NULL::INTEGER                                           AS nesting_depth,        -- reserved for future nested modifier support
        mt.modifierquantity,
        mt.modifierprice,
        mt.freequantity,
        mgm.is_default                                          AS is_modifier_default,
        mg.min_selection                                        AS min_quantity,
        mg.max_selection                                        AS max_quantity,
        -- Classify whether the modifier was optional, required, or a default selection
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 THEN 'optional'
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 THEN 'required'
            WHEN mgm.is_default = TRUE                                                       THEN 'default'
        END                                                     AS selection_type,
        -- Classify the action the customer took on this modifier
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 AND mt.modifierquantity >= 1 THEN 'added'    -- customer explicitly added an optional modifier
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'selected'  -- customer selected a required modifier
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'kept'      -- customer left the default modifier in place
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity = 0  THEN 'removed'   -- customer actively removed a default modifier
        END                                                     AS action,
        NULL::TEXT                                              AS session_recorded_at,  -- reserved for future session tracking
        ti.frequentcustomerid,
        olcm.modifier_default_quantity,
        olcm.classification                                     AS modifier_class_type,
        NOW()::TIMESTAMP                                        AS sysinserttime         -- audit timestamp for when the row was loaded
    FROM fact.itemmodifier AS mt
    INNER JOIN trxn_items AS ti
        ON  mt.transactionheaderid = ti.transactionheaderid
        AND mt.itemid              = ti.orderitemid
    INNER JOIN org_loc_ctlg_modifiers AS olcm
        ON  ti.locationid = olcm.locationid
        AND mt.modifierid = olcm.modifierid
    INNER JOIN dim.menuitem AS mi
        ON mi.menuitemid = ti.menuitemid
    LEFT JOIN dim.modifier_group_mapping AS mgm
        ON  mgm.modifiergroupid = mt.modifiergroupid
        AND mgm.modifierid      = mt.modifierid
    LEFT JOIN dim.modifier_group AS mg
        ON mg.modifiergroupid = mt.modifiergroupid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_modifier_interactions(INT) OWNER TO citus;





-- ============================================================
-- STORED PROCEDURE: ml.usp_refresh_modifier_impressions
--
-- PURPOSE:
--   Refreshes the ml.modifier_impressions table by enriching raw
--   modifier impression events with org/location context, modifier
--   definitions, and menu item classifications. Each row represents
--   a single modifier being shown to a customer during an order
--   session, along with whether it was selected, pre-selected,
--   removed, etc. Supports a full historical reload or an incremental
--   refresh from the last loaded date onward.
--
-- PARAMETERS:
--   p_refresh_mode  INT  (default: 1)
--     1 = Incremental – deletes and reloads data from the current
--         max(businessdate) in the target table onward. Ensures the
--         most recent (potentially partial) day is corrected and any
--         new data since the last run is captured.
--     0 = Full load – truncates the entire table and reloads all
--         available history from the source. Use sparingly; intended
--         for initial loads or full reseeds only.
--
-- INCREMENTAL LOGIC:
--   The procedure reads max(businessdate) from ml.modifier_impressions
--   at runtime and stores it in v_max_businessdate. This same value is
--   used for both the DELETE and the source query, guaranteeing they
--   are always in sync regardless of when the proc runs.
--   On a cold start (empty table), v_max_businessdate will be NULL,
--   causing the WHERE filter to evaluate to NULL and load everything —
--   effectively behaving like a full load automatically.
--
-- SOURCE OBJECTS:
--   fact.modifier_impressions     – one row per modifier shown during an order session;
--                                   filtered to rows whose transactionheaderid begins
--                                   with 'ordevt-' to exclude non-order events
--   dim.organizationlocation      – maps locationid to org/location names (type=0 only)
--   dim.catalog                   – links org+location to a catalog
--   dim.modifier                  – modifier definitions, pricing, and classifications
--   dim.menuitem                  – menu item name and class type lookup
--
-- TARGET TABLE:
--   ml.modifier_impressions
--
-- OWNER: citus
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
    item_class_type     INTEGER,
    modifierid          TEXT COLLATE pg_catalog."default",
    modifiername        TEXT COLLATE pg_catalog."default",
    modifier_class_type INTEGER,
    parent_modifier_id  TEXT COLLATE pg_catalog."default",
    nesting_depth       INTEGER,
    modifierprice       NUMERIC(12,3),
    selection_type      TEXT COLLATE pg_catalog."default",
    position            INTEGER,
    score               NUMERIC(10,4),
    strategy            TEXT COLLATE pg_catalog."default",
    context             TEXT COLLATE pg_catalog."default",
    selected            BOOLEAN,
    pre_deselected      BOOLEAN,
    confirmed_removed   BOOLEAN,
    pre_selected        BOOLEAN,
    frequentcustomerid  TEXT COLLATE pg_catalog."default",
    sysinserttime       TIMESTAMP
);

/*

CREATE INDEX IF NOT EXISTS ix_ml_mimp_yyyy_ww
    ON ml.modifier_impressions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mimp_locid_yyyy_ww
    ON ml.modifier_impressions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mimp_businessdate
    ON ml.modifier_impressions (businessdate);

*/

CREATE OR REPLACE PROCEDURE ml.usp_refresh_modifier_impressions(
    p_refresh_mode  INT  DEFAULT 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_max_businessdate DATE;  -- Holds the current max date in the target table;
                              -- used to anchor both the delete and the source filter
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.modifier_impressions;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.modifier_impressions;

        DELETE FROM ml.modifier_impressions
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH org_loc_ctlg AS (
        -- Resolve each org+location to its corresponding catalog.
        -- Type=0 filters to standard locations only.
        SELECT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname,
               c.catalogid, c.catalogname
        FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        -- Enrich each modifier with its catalog and location context
        -- so it can be joined to impression events by locationid + modifierid.
        SELECT
            m.*,
            olc.organizationid,
            olc.organizationname,
            olc.locationid,
            olc.locationname,
            --olc.catalogid,
            olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
    )
    INSERT INTO ml.modifier_impressions
    SELECT
        olcm.organizationid,
        olcm.organizationname,
        olcm.locationname,
        olcm.locationid,
        olcm.catalogid,
        olcm.catalogname,
        m.businessdate,
        m.orderdatelocal,
        EXTRACT(YEAR FROM m.businessdate)::INTEGER  AS yyyy,
        EXTRACT(WEEK FROM m.businessdate)::INTEGER  AS ww,
        m.transactionheaderid,
        m.ordersessionid,
        m.orderid,
        m.menuitemid,
        mi.menuitemname,
        mi.item_class_type,
        m.modifierid,
        olcm.modifiername,
        olcm.classification                         AS modifier_class_type,
        m.parent_modifier_id,
        m.nesting_depth,
        olcm.price                                  AS modifierprice,
        m.selection_type,
        m.position,
        m.score,
        m.strategy,
        m.context,
        m.selected,
        m.pre_deselected,
        m.confirmed_removed,
        m.pre_selected,
        m.frequentcustomerid,
        NOW()::TIMESTAMP                            AS sysinserttime  -- audit timestamp for when the row was loaded
    FROM fact.modifier_impressions AS m
    INNER JOIN org_loc_ctlg_modifiers AS olcm
        ON  m.locationid = olcm.locationid
        AND m.modifierid = olcm.modifierid
    INNER JOIN dim.menuitem AS mi
        ON mi.menuitemid = m.menuitemid
    WHERE LOWER(m.transactionheaderid) LIKE 'ordevt-%'  -- exclude non-order events (e.g. kiosk idle sessions)
      AND (
            p_refresh_mode = 0                          -- full load: no date restriction
            OR m.businessdate >= v_max_businessdate     -- incremental: from max date onward
      );

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_modifier_impressions(INT) OWNER TO citus;
