CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_item_to_fact()
LANGUAGE plpgsql
AS $BODY$
BEGIN

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
), qualified_items AS (
SELECT
    d.*,
    ic.id                                                   AS categoryid,
    mi.id                                                   AS menuitemid,
    d.orderdateutc_clean :: TIMESTAMPTZ AT TIME ZONE l.timezone
                                                                    AS orderdatelocal
FROM delta_items d
LEFT JOIN dim.location AS l  
    ON l.locationid  = d.locationid
LEFT JOIN dim.itemcategory ic 
    ON ic.locationid = d.locationid
     ic.categoryid = d.src_categoryid
LEFT JOIN dim.menuitem mi 
    ON mi.locationid = d.locationid
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
        'Item' :: TEXT              AS itemtype,
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
