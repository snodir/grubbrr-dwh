-- ============================================================
-- TABLE 4: ml.transactions
-- Granularity : one row per (transaction, order-item)
-- Refresh     : daily (keyed by businessdate)
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
-- DROP PROCEDURE IF EXISTS ml.usp_refresh_transactions(DATE, INTEGER);
-- CALL ml.usp_refresh_transactions(p_refresh_mode => 1);

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

/*

CREATE INDEX IF NOT EXISTS ix_ml_trx_yyyy_ww
    ON ml.transactions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_trx_locid_yyyy_ww
    ON ml.transactions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_trx_businessdate
    ON ml.transactions (businessdate);

*/



-- ============================================================
-- STORED PROCEDURE: ml.usp_refresh_transactions
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


WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname,
                    ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.p_orgid}'
      AND ol.organizationtype = 0
)
SELECT
    tr.frequentcustomerid,
    tr.organizationid,
    tr.organizationname,
    tr.locationid,
    tr.locationname,
    tr.kioskid,
    tr.transactionheaderid,
    tr.ordersessionid,
    tr.orderid,
    tr.orderitemid,
    tr.menuitemid,
    tr.itemname,
    tr.upselllevel,
    tr.item_class_type,
    tr.itemquantity,
    tr.categoryid,
    tr.categoryname,
    tr.itemunitprice,
    tr.paymentstatus,
    tr.numberofitems,
    tr.numberofpayments,
    tr.ordertotal,
    tr.ordersubtotal,
    tr.ordertip,
    tr.ordertax,
    tr.ordertypelabel,
    tr.orderdatelocal,
    tr.businessdate,
    tr.weatherhumidity,
    tr.weathercondition,
    tr.temperatureincelcius,
    tr.yyyy,
    tr.mm,
    tr.dd,
    tr.hh,
    tr.ww
FROM ml.transactions AS tr
WHERE tr.locationid IN (SELECT locationid FROM org_loc_lookup)
  AND tr.yyyy = @{item().yearval}
  AND tr.ww   = @{item().weekval}