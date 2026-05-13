-- ============================================================
-- TABLE 8: ml.modifier_interactions
-- Granularity : one row per (transaction, order-item, modifier)
-- Refresh     : daily
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_modifier_interactions(p_refresh_mode => 0);
--DROP PROCEDURE IF EXISTS ml.usp_refresh_modifier_interactions(DATE, INT);
--SELECT count(*) FROM ml.modifier_interactions --P=6,323,406
--SELECT * FROM ml.modifier_interactions LIMIT 1000; 


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
    itemunitprice             NUMERIC(12,4),
    item_class_type           INTEGER,
    modifiergroupid           TEXT COLLATE pg_catalog."default",
    modifiergroupname         TEXT COLLATE pg_catalog."default",
    modifierid                TEXT COLLATE pg_catalog."default",
    modifiername              TEXT COLLATE pg_catalog."default",
    parent_modifier_id        TEXT COLLATE pg_catalog."default",
    nesting_depth             INTEGER,
    modifierquantity          INTEGER,
    modifierprice             NUMERIC(12,4),
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


/*
CREATE INDEX IF NOT EXISTS ix_ml_mi_yyyy_ww
    ON ml.modifier_interactions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mi_locid_yyyy_ww
    ON ml.modifier_interactions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mi_businessdate
    ON ml.modifier_interactions (businessdate);

*/
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
    mi.orderitemid,
    mi.menuitemid,
    mi.menuitemname,
    mi.itemquantity,
    mi.itemunitprice,
    mi.item_class_type,
    mi.modifiergroupid,
    mi.modifiergroupname,
    mi.modifierid,
    mi.modifiername,
    mi.parent_modifier_id,
    mi.nesting_depth,
    mi.modifierquantity,
    mi.modifierprice,
    mi.freequantity,
    mi.is_modifier_default,
    mi.min_quantity,
    mi.max_quantity,
    mi.selection_type,
    mi.action,
    mi.session_recorded_at,
    mi.frequentcustomerid,
    mi.modifier_default_quantity,
    mi.modifier_class_type
FROM ml.modifier_interactions AS mi
WHERE mi.locationid IN (SELECT locationid FROM org_loc_lookup)
  AND mi.yyyy = @{item().yearval}
  AND mi.ww   = @{item().weekval}