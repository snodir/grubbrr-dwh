SELECT * FROM stg.silver_transaction_item;
SELECT * FROM stg.silver_transaction_combo_items;
SELECT * FROM fact.transactionitem 
WHERE transactionheaderid LIKE 'ordevt-%' 
  AND sysinserttime IS NOT NULL 
ORDER BY sysinserttime DESC 
LIMIT 1000

CALL fact.usp_silver_transaction_item_to_fact();


ALTER TABLE IF EXISTS stg.silver_transaction_item
OWNER TO citus,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;

-- PROCEDURE: fact.usp_silver_transaction_item_to_fact()
--
-- Consolidates all three item streams into fact.transactionitem:
--   itemtype = 'item'           → stg.silver_transaction_item
--   itemtype = 'combo'          → stg.silver_transaction_combo_items (combo header, deduplicated)
--   itemtype = 'combocomponent' → stg.silver_transaction_combo_items (one row per component)
--
-- Notes:
--   menuitemid FK is NULL for combo headers  (no combo_menuitemid in silver)
--   categoryid FK is NULL for combo components (no component_item_category_id in silver)
--   cents_combo_unit_price divided by 100.0 to convert to USD

-- DROP PROCEDURE IF EXISTS fact.usp_silver_transaction_item_to_fact();

CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_item_to_fact()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(MAX(syscosmosts) - 10, 0)
    INTO v_max_syscosmosts
    FROM fact.transactionitem;

    WITH delta_items AS (

        SELECT * FROM (
            SELECT DISTINCT ON (
                transactionheaderid,
                COALESCE(orderitemid, itemsessionid, menuitemid),
                itemname
            )
                transactionheaderid,
                orderid,
                locationid,
                ordersessionid,
                itemsessionid,
                COALESCE(orderitemid, itemsessionid, menuitemid)                    AS itemid,
                menuitemid                                                           AS raw_menuitemid,
                itemname,
                itemquantity                :: SMALLINT                             AS itemquantity,
                usd_itemunitprice           :: NUMERIC(12,3)                        AS itemunitprice,
                categoryid                                                           AS raw_categoryid,
                (NULLIF(items_upsell_source, '') :: json ->> 'upsellLevelType')     AS upselllevel,
                (NULLIF(items_upsell_source, '') :: json ->> 'upsellPromptItemId')  AS upsellpromptitemid,
                NULL :: TEXT                                                         AS comboid,
                'item' :: TEXT                                                       AS itemtype,
                businessdate                :: DATE                                 AS businessdate,
                fact.parse_iso_timestamp(orderdateutc)                              AS orderdateutc,
                frequentcustomerid,
                syscosmosts
            FROM stg.silver_transaction_item
            WHERE syscosmosts > v_max_syscosmosts
              AND (is_test_order = false OR is_test_order IS NULL)
            ORDER BY
                transactionheaderid,
                COALESCE(orderitemid, itemsessionid, menuitemid),
                itemname,
                syscosmosts DESC
        ) regular_items

        UNION ALL

        SELECT * FROM (
            SELECT DISTINCT ON (
                transactionheaderid,
                combo_order_item_id,
                combo_name
            )
                transactionheaderid,
                orderid,
                locationid,
                ordersessionid,
                combo_item_session_id                                                AS itemsessionid,
                combo_order_item_id                                                  AS itemid,
                NULL :: TEXT                                                         AS raw_menuitemid,
                combo_name                                                           AS itemname,
                combo_quantity              :: SMALLINT                              AS itemquantity,
                (cents_combo_unit_price / 100.0) :: NUMERIC(12,3)                    AS itemunitprice,
                NULL :: TEXT                                                         AS raw_categoryid,
                (NULLIF(combo_upsell_source, '') :: json ->> 'upsellLevelType')      AS upselllevel,
                (NULLIF(combo_upsell_source, '') :: json ->> 'upsellPromptItemId')   AS upsellpromptitemid,
                combo_id                                                             AS comboid,
                'combo' :: TEXT                                                      AS itemtype,
                businessdate                :: DATE                                  AS businessdate,
                fact.parse_iso_timestamp(orderdateutc)                               AS orderdateutc,
                frequentcustomerid,
                syscosmosts
            FROM stg.silver_transaction_combo_items
            WHERE syscosmosts > v_max_syscosmosts
              AND (is_test_order = false OR is_test_order IS NULL)
            ORDER BY
                transactionheaderid,
                combo_order_item_id,
                combo_name,
                syscosmosts DESC
        ) combo_headers

        UNION ALL

        SELECT * FROM (
            SELECT DISTINCT ON (
                transactionheaderid,
                component_item_order_item_id,
                component_item_name
            )
                transactionheaderid,
                orderid,
                locationid,
                ordersessionid,
                component_item_session_id                                            AS itemsessionid,
                component_item_order_item_id                                         AS itemid,
                component_item_menu_item_id                                          AS raw_menuitemid,
                component_item_name                                                  AS itemname,
                component_item_quantity     :: SMALLINT                             AS itemquantity,
                component_item_unit_price   :: NUMERIC(12,3)                        AS itemunitprice,
                NULL :: TEXT                                                         AS raw_categoryid,
                (NULLIF(component_item_upsell_source, '') :: json ->> 'upsellLevelType')    AS upselllevel,
                (NULLIF(component_item_upsell_source, '') :: json ->> 'upsellPromptItemId') AS upsellpromptitemid,
                combo_id                                                             AS comboid,
                'combocomponent' :: TEXT                                             AS itemtype,
                businessdate                :: DATE                                 AS businessdate,
                fact.parse_iso_timestamp(orderdateutc)                              AS orderdateutc,
                frequentcustomerid,
                syscosmosts
            FROM stg.silver_transaction_combo_items
            WHERE syscosmosts > v_max_syscosmosts
              AND (is_test_order = false OR is_test_order IS NULL)
              AND component_item_order_item_id IS NOT NULL
              AND component_item_name          IS NOT NULL
            ORDER BY
                transactionheaderid,
                component_item_order_item_id,
                component_item_name,
                syscosmosts DESC
        ) combo_components

    ), resolved AS MATERIALIZED (

        SELECT
            di.transactionheaderid,
            di.orderid,
            di.locationid,
            di.ordersessionid,
            di.itemsessionid,
            di.itemid,
            di.itemname,
            di.itemquantity,
            di.itemunitprice,
            di.raw_menuitemid                                                       AS dimmenuitemid,
            mi.id                                                                   AS menuitemid,
            ic.id                                                                   AS categoryid,
            di.upselllevel,
            di.upsellpromptitemid,
            di.comboid,
            di.itemtype,
            di.businessdate,
            di.orderdateutc,
            di.frequentcustomerid,
            di.syscosmosts
        FROM delta_items AS di
        LEFT JOIN dim.menuitem AS mi
            ON  mi.menuitemid  = di.raw_menuitemid
        LEFT JOIN dim.itemcategory AS ic
            ON  ic.locationid  = di.locationid
            AND ic.categoryid  = di.raw_categoryid

    ), gem_events AS (

        -- Scoped to only sessions present in the current delta batch
        -- to avoid a full scan of fact.userbehaviour
        SELECT
            ub.locationid,
            ub.ordersessionidentifier,
            ub.eventtype,
            busdate AS eventtime
        FROM fact.userbehaviour ub
        WHERE ub.eventtype IN (
            'ItemCustomizeClicked', 'CustomizeItemSelected', 'ComboCustomizeClicked',
            'RegularItemSelected',  'ComboComponentItemSelected', 'AddToCartClicked',
            'ComboSizeSelected',    'ComboItemSelected',          'AddAsIsSelected'
        )
          AND EXISTS (
              SELECT 1
              FROM resolved r
              WHERE r.ordersessionid = ub.ordersessionidentifier
                AND r.locationid     = ub.locationid
          )

    ), item_timing AS (

        SELECT
            r.transactionheaderid,
            r.itemid,
            r.itemname,
            r.itemtype,
            r.ordersessionid,
            r.itemsessionid,
            MAX(CASE WHEN ge.eventtype IN ('AddToCartClicked', 'AddAsIsSelected')
                THEN ge.eventtime END)                                              AS addtocarttime,
            MAX(CASE WHEN ge.eventtype IN (
                'RegularItemSelected', 'ComboComponentItemSelected',
                'ComboComponentSelected', 'ComboItemSelected')
                THEN ge.eventtime END)                                              AS itemselectedtime,
            SUM(CASE WHEN ge.eventtype IN (
                'CustomizeItemSelected', 'ComboCustomizeClicked', 'ItemCustomizeClicked')
                THEN 1 ELSE 0 END)                                                 AS customize_count,
            SUM(CASE WHEN ge.eventtype = 'ComboSizeSelected'
                THEN 1 ELSE 0 END)                                                 AS upgrade_count
        FROM resolved r
        LEFT JOIN gem_events ge
            ON  ge.ordersessionidentifier = r.ordersessionid
            AND ge.locationid             = r.locationid
        GROUP BY
            r.transactionheaderid, r.itemid, r.itemname,
            r.itemtype, r.ordersessionid, r.itemsessionid

    )
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
        customize,
        upgrade,
        asis,
        itemselectedtime,
        addtocarttime,
        totaltime,
        orderdateutc,
        orderdatelocal,
        businessdate,
        sysinserttime,
        sysupdatetime,
        locationid,
        dimmenuitemid,
        syscosmosts,
        frequentcustomerid
    )
    SELECT
        r.transactionheaderid,
        r.categoryid,
        r.menuitemid,
        r.itemid,
        r.comboid,
        r.ordersessionid,
        r.itemsessionid,
        r.itemname,
        r.itemquantity,
        r.itemunitprice,
        r.upselllevel,
        r.upsellpromptitemid,
        r.orderid,
        r.itemtype,
        COALESCE(t.customize_count, 0) >= 1                                         AS customize,
        COALESCE(t.upgrade_count,   0) >= 1                                         AS upgrade,
        COALESCE(t.customize_count, 0) <  1                                         AS asis,
        t.itemselectedtime,
        t.addtocarttime,
        ABS(COALESCE(
            EXTRACT(EPOCH FROM (t.addtocarttime - t.itemselectedtime)) :: NUMERIC(7,3),
            0
        ))                                                                           AS totaltime,
        r.orderdateutc,
        (r.orderdateutc :: TIMESTAMPTZ AT TIME ZONE org.timezone) :: TIMESTAMP      AS orderdatelocal,
        r.businessdate,
        NOW() :: TIMESTAMP                                                           AS sysinserttime,
        NOW() :: TIMESTAMP                                                           AS sysupdatetime,
        r.locationid,
        r.dimmenuitemid,
        r.syscosmosts,
        r.frequentcustomerid
    FROM resolved AS r
    LEFT JOIN item_timing AS t
        ON  t.transactionheaderid = r.transactionheaderid
        AND t.itemid              = r.itemid
        AND t.itemname            = r.itemname
        AND t.itemtype            = r.itemtype
        AND t.ordersessionid      = r.ordersessionid
        AND t.itemsessionid       = r.itemsessionid
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = r.locationid
        AND th.transactionheaderid = r.transactionheaderid
    LEFT JOIN dim.organization AS org
        ON  org.id = r.locationid
    --WHERE NOT EXISTS (
    --    SELECT 1
    --    FROM fact.transactionitem AS ti
    --    WHERE ti.transactionheaderid = r.transactionheaderid
    --      AND ti.itemid              = r.itemid
    --      AND ti.itemname            = r.itemname
    --)
    ON CONFLICT (transactionheaderid, itemid, itemname)
    DO UPDATE SET
        customize        = EXCLUDED.customize,
        upgrade          = EXCLUDED.upgrade,
        asis             = EXCLUDED.asis,
        itemselectedtime = EXCLUDED.itemselectedtime,
        addtocarttime    = EXCLUDED.addtocarttime,
        totaltime        = EXCLUDED.totaltime,
        sysupdatetime    = NOW() :: TIMESTAMP
    WHERE
        fact.transactionitem.itemselectedtime IS NULL
        OR fact.transactionitem.addtocarttime IS NULL;
END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_transaction_item_to_fact()
    OWNER TO citus;