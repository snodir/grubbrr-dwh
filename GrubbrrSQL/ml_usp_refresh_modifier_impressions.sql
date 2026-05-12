-- ============================================================
-- TABLE 9: ml.modifier_impressions
-- Granularity : one row per modifier impression event
-- Refresh     : weekly
-- Parquet file: modifier-impressions-yyww.parquet
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_modifier_impressions(p_refresh_mode => 1);
--DROP PROCEDURE IF EXISTS ml.usp_refresh_modifier_impressions(DATE, INTEGER);
--SELECT * FROM ml.modifier_impressions LIMIT 1000;
--SELECT * FROM fact.modifier_impressions LIMIT 1000;

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
    modifierprice       NUMERIC(12,4),
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

WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname,
                    ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.p_orgid}'
      AND ol.organizationtype = 0
)
SELECT
    mi.organizationid,
    mi.organizationname,
    mi.locationname,
    mi.locationid,
    mi.catalogid,
    mi.catalogname,
    mi.businessdate,
    mi.orderdatelocal,
    mi.yyyy,
    mi.ww,
    mi.transactionheaderid,
    mi.ordersessionid,
    mi.orderid,
    mi.menuitemid,
    mi.menuitemname,
    mi.item_class_type,
    mi.modifierid,
    mi.modifiername,
    mi.modifier_class_type,
    mi.parent_modifier_id,
    mi.nesting_depth,
    mi.modifierprice,
    mi.selection_type,
    mi.position,
    mi.score,
    mi.strategy,
    mi.context,
    mi.selected,
    mi.pre_deselected,
    mi.confirmed_removed,
    mi.pre_selected,
    mi.frequentcustomerid
FROM ml.modifier_impressions AS mi
WHERE mi.locationid IN (SELECT locationid FROM org_loc_lookup)
  AND mi.yyyy = @{item().yearval}
  AND mi.ww   = @{item().weekval}