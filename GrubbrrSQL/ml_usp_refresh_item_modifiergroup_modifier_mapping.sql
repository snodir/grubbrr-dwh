-- ============================================================
-- TABLE 10: ml.item_modifiergroup_modifier_mapping
-- Granularity : one row per (location, menu-item, modifier-group,
--               modifier)
-- Refresh     : full truncate + insert on every run
-- Notes       : Master/reference data only — sourced from dimension
--               tables. Selection frequency stats computed at
--               extraction time from ml.modifier_interactions.
-- ============================================================

/*
	"firstRow": {
		"organizationid": "org-490e23ce-6f23-4d3d-8544-8728f0965cfc",
		"organizationname": "Houston Hot Chicken",
		"locationid": "loc-bc017a27-667a-4bcd-b10c-a0e21794d992",
		"locationname": "Phoenix - Camelback"
	},
*/

-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_item_modifiergroup_modifier_mapping('org-490e23ce-6f23-4d3d-8544-8728f0965cfc');
--SELECT count(*) FROM dim.item_modifier_group_modifier_mapping LIMIT 1000;
--SELECT * FROM ml.item_modifiergroup_modifier_mapping LIMIT 1000;

SELECT count(*) 
FROM dim.item_modifier_group_modifier_mapping LIMIT 100 --355,226

SELECT count(*)
FROM dim.menuitem --ORDER BY id DESC --206,905
LIMIT 100

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

/*

CREATE INDEX IF NOT EXISTS ix_ml_imm_locationid
    ON ml.item_modifiergroup_modifier_mapping (locationid);
CREATE INDEX IF NOT EXISTS ix_ml_imm_menuitemid
    ON ml.item_modifiergroup_modifier_mapping (menuitemid);
CREATE INDEX IF NOT EXISTS ix_ml_imm_modifierid
    ON ml.item_modifiergroup_modifier_mapping (modifierid);
*/

-- ============================================================
-- STORED PROCEDURE 10: ml.usp_refresh_item_modifiergroup_modifier_mapping
-- Refresh type : FULL TRUNCATE + INSERT on every run
-- Notes        : Pure dimension data — no parameters, no date scoping.
--                Selection frequency stats computed at extraction time.
-- ============================================================

CREATE OR REPLACE PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(
    p_organizationid TEXT  -- or replace INT with the appropriate type (e.g. UUID, BIGINT)
)
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Delete only rows for this organization on every run
    -- --------------------------------------------------------
    DELETE FROM ml.item_modifiergroup_modifier_mapping
    WHERE organizationid = p_organizationid;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH org_loc_ctlg AS (
        SELECT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname,
               c.catalogid, c.catalogname
        FROM (
            SELECT * FROM dim.organizationlocation
            WHERE organizationid = p_organizationid  -- filter applied here
              AND organizationtype = 0 
        ) AS ol
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
ALTER PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(TEXT) OWNER TO citus;

/*

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

*/

WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname,
                    ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.p_orgid}'
      AND ol.organizationtype = 0
),
trxn_modifiers AS (
    SELECT
        mi.organizationid,
        mi.locationid,
        mi.menuitemid,
        mi.modifierid,
        mi.modifierquantity,
        mi.modifierprice
    FROM ml.modifier_interactions AS mi
    WHERE mi.locationid IN (SELECT locationid FROM org_loc_lookup)
      AND mi.yyyy = @{item().yearval}
      AND mi.ww   = @{item().weekval}
),
loc_mdfr_agg AS (
    SELECT
        organizationid,
        locationid,
        modifierid,
        COUNT(*)           AS mdfr_selection_frequency_within_loc_and_week,
        MAX(modifierprice) AS modifierprice
    FROM trxn_modifiers
    GROUP BY organizationid, locationid, modifierid
),
loc_mdfr_itm AS (
    SELECT
        organizationid,
        locationid,
        modifierid,
        menuitemid,
        COUNT(*) AS x_times_added_on_to_the_item,
        ROW_NUMBER() OVER (
            PARTITION BY organizationid, locationid, modifierid
            ORDER BY COUNT(*) DESC
        )        AS mdfr_selection_ranking
    FROM trxn_modifiers
    GROUP BY organizationid, locationid, modifierid, menuitemid
)
SELECT
    imm.organizationid,
    imm.organizationname,
    imm.locationid,
    imm.locationname,
    imm.catalogid,
    imm.catalogname,
    imm.menuitemid,
    imm.menuitemname,
    imm.item_class_type,
    imm.modifiergroupid,
    imm.modifiergroupname,
    imm.modifierid,
    imm.modifiername,
    imm.modifier_class_type,
    imm.is_modifier_default,
    imm.min_quantity,
    imm.max_quantity,
    imm.allow_quantity_increment,
    imm.increment_step,
    imm.modifier_default_quantity,
    imm.is_modifier_invisible,
    imm.calories,
    imm.price,
    imm.is_modifier_active,
    imm.is_modifier_deleted,
    imm.modifier_created_on,
    imm.modifier_modified_on,
    lmi.x_times_added_on_to_the_item,
    lma.mdfr_selection_frequency_within_loc_and_week,
    ROUND(
        100 * CAST(lmi.x_times_added_on_to_the_item AS NUMERIC(9,3))
        / lma.mdfr_selection_frequency_within_loc_and_week,
        3
    )          AS pct_relative_selection_frequency
FROM ml.item_modifiergroup_modifier_mapping AS imm
LEFT JOIN loc_mdfr_itm AS lmi
    ON  imm.organizationid = lmi.organizationid
    AND imm.locationid     = lmi.locationid
    AND imm.modifierid     = lmi.modifierid
    AND imm.menuitemid     = lmi.menuitemid
LEFT JOIN loc_mdfr_agg AS lma
    ON  imm.organizationid = lma.organizationid
    AND imm.locationid     = lma.locationid
    AND imm.modifierid     = lma.modifierid
WHERE imm.locationid IN (SELECT locationid FROM org_loc_lookup)
  AND (
        (
            EXTRACT(YEAR FROM imm.modifier_created_on)::INTEGER  = @{item().yearval}
            AND EXTRACT(WEEK FROM imm.modifier_created_on)::INTEGER <= @{item().weekval}
        )
        OR
        (
            EXTRACT(YEAR FROM imm.modifier_created_on)::INTEGER < @{item().yearval}
        )
  );