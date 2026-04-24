-- ============================================================
-- TABLE 8: ml.modifier_interactions
-- Granularity : one row per (transaction, order-item, modifier)
-- Refresh     : daily
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_modifier_interactions(p_businessdate => CURRENT_DATE - 1, p_refresh_mode => 0);

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

CREATE INDEX IF NOT EXISTS ix_ml_mi_yyyy_ww
    ON ml.modifier_interactions (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mi_locid_yyyy_ww
    ON ml.modifier_interactions (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_mi_businessdate
    ON ml.modifier_interactions (businessdate);


-- ============================================================
-- STORED PROCEDURE 8: ml.usp_refresh_modifier_interactions
-- Refresh type : DAILY DELETE + INSERT (idempotent) / FULL TRUNCATE + INSERT
-- Parameters   : p_businessdate DATE  (default: yesterday)
--                  The specific calendar day to delete and reload.
--                p_refresh_mode INT   (default: 1)
--                  1 = Incremental – delete/insert for p_businessdate only
--                  0 = Full load   – TRUNCATE the table, then insert ALL history
-- Notes        : Depends on ml.transactions being refreshed first.
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_modifier_interactions(
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
        TRUNCATE TABLE ml.modifier_interactions;
    ELSE
        -- Incremental: idempotent delete for the target day only
        DELETE FROM ml.modifier_interactions
        WHERE businessdate = p_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH trxn_items AS (
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
                p_refresh_mode = 0
                OR tr.businessdate = p_businessdate
        )
    ),
    org_loc_ctlg AS (
        SELECT ol.organizationid, ol.locationid, c.catalogid, c.catalogname
        FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
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
        NULL::TEXT                                              AS parent_modifier_id,
        NULL::INTEGER                                           AS nesting_depth,
        mt.modifierquantity,
        mt.modifierprice,
        mt.freequantity,
        mgm.is_default                                          AS is_modifier_default,
        mg.min_selection                                        AS min_quantity,
        mg.max_selection                                        AS max_quantity,
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 THEN 'optional'
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 THEN 'required'
            WHEN mgm.is_default = TRUE                                                       THEN 'default'
        END                                                     AS selection_type,
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 AND mt.modifierquantity >= 1 THEN 'added'
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'selected'
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'kept'
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity = 0  THEN 'removed'
        END                                                     AS action,
        NULL::TEXT                                              AS session_recorded_at,
        ti.frequentcustomerid,
        olcm.modifier_default_quantity,
        olcm.classification                                     AS modifier_class_type,
        NOW()::TIMESTAMP                                        AS sysinserttime
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
ALTER PROCEDURE ml.usp_refresh_modifier_interactions(DATE, INT) OWNER TO citus;