/*  Modifier Classification
    public enum ModifierClassificationType
{
    Undefined = 0,
    Protein = 1,
    Side = 2,
    Cheese = 3,
    Topping = 4,
    Sauce = 5,
    Size = 6,
    Prep = 7,
    Other = 8
}
        
    Menu Item Classification

    0=Undefined
    1=Main
    2=Side
    3=Drink
    4=Dessert
    5=Meal
    6=Other
*/
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

/*

CREATE INDEX IF NOT EXISTS ix_ml_me_locationid
    ON ml.menu_entities (locationid);
CREATE INDEX IF NOT EXISTS ix_ml_me_menuitemid
    ON ml.menu_entities (menuitemid);
*/

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








WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname,
                    ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.p_orgid}'
      AND ol.organizationtype = 0
),
order_items AS (
    SELECT
        tr.organizationid,
        tr.locationid,
        tr.menuitemid,
        tr.itemunitprice
    FROM ml.transactions AS tr
    WHERE tr.locationid IN (SELECT locationid FROM org_loc_lookup)
      AND tr.yyyy = @{item().yearval}
      AND tr.ww   = @{item().weekval}
),
org_agg AS (
    SELECT
        organizationid,
        COUNT(*) AS total_items_ordered_within_org_and_week
    FROM order_items
    GROUP BY organizationid
),
org_itm_agg AS (
    SELECT
        organizationid,
        menuitemid,
        COUNT(*) AS item_selection_frequency_within_org_and_week
    FROM order_items
    GROUP BY organizationid, menuitemid
),
loc_agg AS (
    SELECT
        organizationid,
        locationid,
        COUNT(*) AS total_items_ordered_within_loc_and_week
    FROM order_items
    GROUP BY organizationid, locationid
),
loc_itm_agg AS (
    SELECT
        organizationid,
        locationid,
        menuitemid,
        COUNT(*)           AS item_selection_frequency_within_loc_and_week,
        MAX(itemunitprice) AS itemunitprice
    FROM order_items
    GROUP BY organizationid, locationid, menuitemid
),
item_statistics AS (
    SELECT
        lia.organizationid,
        lia.locationid,
        lia.menuitemid,
        lia.itemunitprice,
        lia.item_selection_frequency_within_loc_and_week,
        la.total_items_ordered_within_loc_and_week,
        100 * lia.item_selection_frequency_within_loc_and_week::NUMERIC(8,3)
            / la.total_items_ordered_within_loc_and_week                     AS pct_item_selection_freq_within_loc_and_week,
        oia.item_selection_frequency_within_org_and_week,
        oa.total_items_ordered_within_org_and_week,
        100 * oia.item_selection_frequency_within_org_and_week::NUMERIC(8,3)
            / oa.total_items_ordered_within_org_and_week                     AS pct_item_selection_freq_within_org_and_week
    FROM loc_itm_agg AS lia
    INNER JOIN loc_agg     AS la  ON  lia.organizationid = la.organizationid
                                  AND lia.locationid     = la.locationid
    INNER JOIN org_itm_agg AS oia ON  lia.organizationid = oia.organizationid
                                  AND lia.menuitemid     = oia.menuitemid
    INNER JOIN org_agg     AS oa  ON  lia.organizationid = oa.organizationid
)
SELECT
    me.organizationid,
    me.organizationname,
    me.locationid,
    me.locationname,
    me.categoryid,
    me.categoryname,
    me.menuitemid,
    me.menuitemname,
    me.catalogid,
    COALESCE(its.itemunitprice, me.itemunitprice)              AS itemunitprice,
    me.price_changed_on,
    me.item_class_type,
    me.entitytype,
    me.calories,
    me.protein,
    me.sugar,
    me.fat,
    me.is_alcoholic,
    me.is_vegetarian_item,
    me.is_vegan_item,
    me.has_allergen,
    me.is_active,
    me.is_deleted,
    me.gms_created_on,
    me.gms_modified_on,
    its.item_selection_frequency_within_loc_and_week,
    its.total_items_ordered_within_loc_and_week,
    its.pct_item_selection_freq_within_loc_and_week,
    its.item_selection_frequency_within_org_and_week,
    its.total_items_ordered_within_org_and_week,
    its.pct_item_selection_freq_within_org_and_week
FROM ml.menu_entities AS me
LEFT JOIN item_statistics AS its
    ON  me.organizationid = its.organizationid
    AND me.locationid     = its.locationid
    AND me.menuitemid     = its.menuitemid
WHERE me.locationid IN (SELECT locationid FROM org_loc_lookup)
  AND (
        (
            EXTRACT(YEAR FROM me.gms_created_on)::INTEGER  = @{item().yearval}
            AND EXTRACT(WEEK FROM me.gms_created_on)::INTEGER <= @{item().weekval}
        )
        OR
        (
            EXTRACT(YEAR FROM me.gms_created_on)::INTEGER < @{item().yearval}
        )
  );