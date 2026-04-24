-- ============================================================
-- TABLE 9: ml.modifier_impressions
-- Granularity : one row per modifier impression event
-- Refresh     : weekly
-- Parquet file: modifier-impressions-yyww.parquet
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_modifier_impressions(p_businessdate => CURRENT_DATE - 1, p_refresh_mode => 0);

--SELECT * FROM ml.modifier_impressions LIMIT 1000;


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

CREATE INDEX IF NOT EXISTS ix_ml_mimp_yyyy_ww
    ON ml.modifier_impressions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mimp_locid_yyyy_ww
    ON ml.modifier_impressions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mimp_businessdate
    ON ml.modifier_impressions (businessdate);


-- ============================================================
-- STORED PROCEDURE 9: ml.usp_refresh_modifier_impressions
-- Refresh type : DAILY DELETE + INSERT (idempotent) / FULL TRUNCATE + INSERT
-- Parameters   : p_businessdate DATE  (default: yesterday)
--                  The specific calendar day to delete and reload.
--                p_refresh_mode INT   (default: 1)
--                  1 = Incremental – delete/insert for p_businessdate only
--                  0 = Full load   – TRUNCATE the table, then insert ALL history
-- Notes        : Source is fact.modifier_impressions (not fact.itemmodifier).
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_modifier_impressions(
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
        TRUNCATE TABLE ml.modifier_impressions;
    ELSE
        -- Incremental: idempotent delete for the target day only
        DELETE FROM ml.modifier_impressions
        WHERE businessdate = p_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH org_loc_ctlg AS (
        SELECT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname,
               c.catalogid, c.catalogname
        FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
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
        NOW()::TIMESTAMP                            AS sysinserttime
    FROM fact.modifier_impressions AS m
    INNER JOIN org_loc_ctlg_modifiers AS olcm
        ON  m.locationid = olcm.locationid
        AND m.modifierid = olcm.modifierid
    INNER JOIN dim.menuitem AS mi
        ON mi.menuitemid = m.menuitemid
    WHERE LOWER(m.transactionheaderid) LIKE 'ordevt-%'
      AND (
            p_refresh_mode = 0
            OR m.businessdate = p_businessdate
      );

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_modifier_impressions(DATE, INT) OWNER TO citus;


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