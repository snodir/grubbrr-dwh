SELECT * FROM stg.silver_transaction_item;
SELECT * FROM stg.silver_transaction_combo_items;

CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_item_to_fact()
LANGUAGE plpgsql
AS $BODY$
BEGIN

WITH delta_items AS (
SELECT
    si.transactionheaderid,
    si.orderitemid AS itemid,
    si.itemsessionid,
    si.itemname,
    si.itemquantity :: SMALLINT AS itemquantity,
    si.usd_itemunitprice :: NUMERIC(12,3) AS itemunitprice,
    si.items_upsell_source AS upselllevel,
    si.orderid,
    si.ordersessionid,
    si.locationid,
    si.menuitemid AS dimmenuitemid,
    si.categoryid AS src_categoryid,
            -- Normalise UTC string: strip milliseconds / tz suffix
    fact.parse_iso_timestamp(si.orderdateutc) AS orderdateutc_clean,
    si.businessdate :: DATE AS businessdate,
    si.syscosmosts,
    sth.frequentcustomerid,
    ROW_NUMBER() OVER (
                PARTITION BY si.transactionheaderid, si.orderitemid, si.itemname
                ORDER BY si.syscosmosts DESC
            )                                                       AS row_num
FROM stg.silver_transaction_item si
LEFT JOIN stg.lookup_silver_transaction_header as sth 
    ON si.locationid = sth.locationid
    AND si.transactionheaderid = sth.transactionheaderid
WHERE (si.is_test_order = False OR si.is_test_order IS NULL)
  AND NOT EXISTS (
       SELECT 1 FROM fact.transactionitem AS ti
       WHERE ti.transactionheaderid = si.transactionheaderid
         AND ti.itemid              = si.orderitemid
         AND ti.itemname            = si.itemname
          )
  AND EXISTS (
       SELECT 1 FROM fact.transactionheader AS th
       WHERE th.locationid = si.locationid
         AND th.transactionheaderid = si.transactionheaderid
  )
), qualified_items AS (
SELECT
    d.*,
    ic.id AS categoryid,
    mi.id AS menuitemid,
    d.orderdateutc_clean :: TIMESTAMPTZ AT TIME ZONE l.timezone AS orderdatelocal
FROM delta_items AS d
LEFT JOIN dim.organization AS l  
    ON l.id  = d.locationid
LEFT JOIN dim.itemcategory AS ic 
    ON ic.locationid = d.locationid
    AND ic.categoryid = d.src_categoryid
LEFT JOIN dim.menuitem AS mi 
    ON mi.menuitemid = d.dimmenuitemid
WHERE d.row_num = 1
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
    orderdateutc,
    sysinserttime,
    dimmenuitemid,
    locationid,
    orderdatelocal,
    businessdate,
    syscosmosts,
    frequentcustomerid
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
        --NOW() :: TIMESTAMP              AS sysupdatetime,
        dimmenuitemid,
        locationid,
        orderdatelocal,
        businessdate,
        syscosmosts,
        frequentcustomerid
    FROM qualified_items;

END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_to_fact_transaction_item() OWNER TO citus;



