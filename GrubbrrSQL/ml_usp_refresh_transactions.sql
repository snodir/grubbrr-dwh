-- ============================================================
-- TABLE 4: ml.transactions
-- Granularity : one row per (transaction, order-item)
-- Refresh     : daily (keyed by businessdate)
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_transactions(p_businessdate => CURRENT_DATE - 1, p_refresh_mode => 0);

--SELECT * FROM ml.transactions LIMIT 1000;

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
-- STORED PROCEDURE 4: ml.usp_refresh_transactions
-- Refresh type : DAILY DELETE + INSERT (idempotent) / FULL TRUNCATE + INSERT
-- Parameters   : p_businessdate DATE  (default: yesterday)
--                  The specific calendar day to delete and reload.
--                p_refresh_mode INT   (default: 1)
--                  1 = Incremental – delete/insert for p_businessdate only
--                  0 = Full load   – TRUNCATE the table, then insert ALL history
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_transactions(
    p_businessdate  DATE DEFAULT CURRENT_DATE - 1,
    p_refresh_mode  INT  DEFAULT 1
)
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.transactions;
    ELSE
        -- Incremental: idempotent delete for the target day only
        DELETE FROM ml.transactions
        WHERE businessdate = p_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM fact.transactionheader AS th
        WHERE LOWER(th.orderstatus) = 'order-placed'
          AND (
                p_refresh_mode = 0
                OR th.businessdate = p_businessdate
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
    INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON th.locationid = ol.locationid
    INNER JOIN fact.transactionitem AS ti
        ON th.transactionheaderid = ti.transactionheaderid
    LEFT JOIN ml.weather AS wh
        ON  th.locationid          = wh.locationid
        AND th.businessdate        = wh.weatherdate
        AND EXTRACT(HOUR FROM th.orderdatelocal)::INTEGER = wh.hh
    LEFT JOIN dim.itemcategory AS ctg
        ON ti.categoryid = ctg.id
    LEFT JOIN dim.menuitem AS mi
        ON ti.menuitemid = mi.id
    LEFT JOIN dim.ordertype AS ot
        ON th.ordertype = ot.id;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_transactions(DATE, INT) OWNER TO citus;
