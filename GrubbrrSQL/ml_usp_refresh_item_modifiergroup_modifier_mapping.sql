-- ============================================================
-- TABLE 10: ml.item_modifiergroup_modifier_mapping
-- Granularity : one row per (location, menu-item, modifier-group,
--               modifier)
-- Refresh     : full truncate + insert on every run
-- Notes       : Master/reference data only — sourced from dimension
--               tables. Selection frequency stats computed at
--               extraction time from ml.modifier_interactions.
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_item_modifiergroup_modifier_mapping();
--SELECT count(*) FROM dim.item_modifier_group_modifier_mapping LIMIT 1000;
--SELECT * FROM ml.item_modifiergroup_modifier_mapping LIMIT 1000;


CREATE TABLE IF NOT EXISTS ml.item_modifiergroup_modifier_mapping (
    organizationid            TEXT COLLATE pg_catalog."default",
    organizationname          TEXT COLLATE pg_catalog."default",
    locationid                TEXT COLLATE pg_catalog."default",
    locationname              TEXT COLLATE pg_catalog."default",
    catalogid                 TEXT COLLATE pg_catalog."default",
    catalogname               TEXT COLLATE pg_catalog."default",
    menuitemid                TEXT COLLATE pg_catalog."default",
    menuitemname              TEXT COLLATE pg_catalog."default",
    item_class_type           INTEGER,
    modifiergroupid           TEXT COLLATE pg_catalog."default",
    modifiergroupname         TEXT COLLATE pg_catalog."default",
    modifierid                TEXT COLLATE pg_catalog."default",
    modifiername              TEXT COLLATE pg_catalog."default",
    modifier_class_type       INTEGER,
    is_modifier_default       BOOLEAN,
    min_quantity              INTEGER,
    max_quantity              INTEGER,
    allow_quantity_increment  BOOLEAN,
    increment_step            INTEGER,
    modifier_default_quantity INTEGER,
    is_modifier_invisible     BOOLEAN,
    calories                  TEXT COLLATE pg_catalog."default",
    price                     NUMERIC(12,4),
    is_modifier_active        BOOLEAN,
    is_modifier_deleted       BOOLEAN,
    modifier_created_on       TIMESTAMP,
    modifier_modified_on      TIMESTAMP,
    sysinserttime             TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_ml_imm_locationid
    ON ml.item_modifiergroup_modifier_mapping (locationid);
CREATE INDEX IF NOT EXISTS ix_ml_imm_menuitemid
    ON ml.item_modifiergroup_modifier_mapping (menuitemid);
CREATE INDEX IF NOT EXISTS ix_ml_imm_modifierid
    ON ml.item_modifiergroup_modifier_mapping (modifierid);


-- ============================================================
-- STORED PROCEDURE 10: ml.usp_refresh_item_modifiergroup_modifier_mapping
-- Refresh type : FULL TRUNCATE + INSERT on every run
-- Notes        : Pure dimension data — no parameters, no date scoping.
--                Selection frequency stats computed at extraction time.
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Truncate on every run
    -- --------------------------------------------------------
    TRUNCATE TABLE ml.item_modifiergroup_modifier_mapping;

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
    INSERT INTO ml.item_modifiergroup_modifier_mapping
    SELECT
        m.organizationid,
        m.organizationname,
        m.locationid,
        m.locationname,
        m.catalogid,
        m.catalogname,
        imgm.menuitemid,
        mi.menuitemname,
        mi.item_class_type,
        imgm.modifiergroupid,
        mg.modifiergroupname,
        imgm.modifierid,
        m.modifiername,
        m.classification            AS modifier_class_type,
        imgm.is_default             AS is_modifier_default,
        mg.min_selection            AS min_quantity,
        mg.max_selection            AS max_quantity,
        m.allow_quantity_increment,
        m.increment_step,
        m.modifier_default_quantity,
        m.is_invisible              AS is_modifier_invisible,
        m.calories,
        m.price,
        m.is_modifier_active,
        m.is_modifier_deleted,
        m.modifier_created_on,
        m.modifier_modified_on,
        NOW()::TIMESTAMP            AS sysinserttime
    FROM dim.item_modifier_group_modifier_mapping AS imgm
    INNER JOIN org_loc_ctlg_modifiers AS m
        ON  imgm.catalogid  = m.catalogid
        AND imgm.modifierid = m.modifierid
    INNER JOIN dim.menuitem AS mi
        ON imgm.menuitemid = mi.menuitemid
    INNER JOIN dim.modifier_group AS mg
        ON  imgm.catalogid       = mg.catalogid
        AND imgm.modifiergroupid = mg.modifiergroupid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping() OWNER TO citus;