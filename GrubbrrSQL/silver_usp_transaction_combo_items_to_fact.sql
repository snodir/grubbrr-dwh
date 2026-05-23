SELECT * FROM stg.silver_transaction_combo_items;

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
AS $BODY$
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
