-- ============================================================
-- TABLE 7: ml.menu_entities
-- Granularity : one row per (location, category, menu-item)
-- Refresh     : full truncate + insert on every run
-- Notes       : Master/reference data only — sourced from dimension
--               tables. Metrics computed at extraction time from
--               ml.transactions.
-- ============================================================


-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_menu_entities();

--SELECT * FROM dim.menuitem ORDER BY id DESC LIMIT 100;
--SELECT * FROM ml.menu_entities LIMIT 100;

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
    itemunitprice      NUMERIC(12,4),
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

CREATE INDEX IF NOT EXISTS ix_ml_me_locationid
    ON ml.menu_entities (locationid);
CREATE INDEX IF NOT EXISTS ix_ml_me_menuitemid
    ON ml.menu_entities (menuitemid);


-- ============================================================
-- STORED PROCEDURE 7: ml.usp_refresh_menu_entities
-- Refresh type : FULL TRUNCATE + INSERT on every run
-- Notes        : Pure dimension data — no parameters, no date scoping.
--                No dependency on ml.transactions.
--                Metrics and trends computed at extraction time.
-- ============================================================
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