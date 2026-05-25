-- Dimension Refresh Stored Procedures

CREATE OR REPLACE PROCEDURE dim.usp_refresh_catalog()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    CREATE TEMP TABLE tmp_catalog ON COMMIT DROP AS
    SELECT DISTINCT ON (catalogid)
        catalogid,
        catalogname,
        organizationid,
        is_catalog_deleted,
        catalog_created_on,
        catalog_modified_on,
        gem_company_id,
        gem_location_id,
        is_sync_in_progress,
        is_standalone,
        is_master,
        is_ecm_enabled
    FROM stg.dim_catalog
    ORDER BY catalogid, catalog_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_catalog ON tmp_catalog (catalogid);
    ANALYZE tmp_catalog;

    -- INSERT net new
    INSERT INTO dim.catalog (
        catalogid,
        catalogname,
        organizationid,
        is_catalog_deleted,
        catalog_created_on,
        catalog_modified_on,
        gem_company_id,
        gem_location_id,
        is_sync_in_progress,
        is_standalone,
        is_master,
        is_ecm_enabled,
        sysinserttime
    )
    SELECT
        t.catalogid,
        t.catalogname,
        t.organizationid,
        t.is_catalog_deleted,
        t.catalog_created_on,
        t.catalog_modified_on,
        t.gem_company_id,
        t.gem_location_id,
        t.is_sync_in_progress,
        t.is_standalone,
        t.is_master,
        t.is_ecm_enabled,
        NOW()
    FROM tmp_catalog t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.catalog d
        WHERE d.catalogid = t.catalogid
    );

    -- UPDATE changed
    UPDATE dim.catalog d
    SET
        catalogname         = t.catalogname,
        organizationid      = t.organizationid,
        is_catalog_deleted  = t.is_catalog_deleted,
        catalog_created_on  = t.catalog_created_on,
        catalog_modified_on = t.catalog_modified_on,
        gem_company_id      = t.gem_company_id,
        gem_location_id     = t.gem_location_id,
        is_sync_in_progress = t.is_sync_in_progress,
        is_standalone       = t.is_standalone,
        is_master           = t.is_master,
        is_ecm_enabled      = t.is_ecm_enabled,
        sysupdatetime       = NOW()
    FROM tmp_catalog t
    WHERE d.catalogid = t.catalogid
    AND (
        d.catalogname         IS DISTINCT FROM t.catalogname         OR
        d.organizationid      IS DISTINCT FROM t.organizationid      OR
        d.is_catalog_deleted  IS DISTINCT FROM t.is_catalog_deleted  OR
        d.catalog_created_on  IS DISTINCT FROM t.catalog_created_on  OR
        d.catalog_modified_on IS DISTINCT FROM t.catalog_modified_on OR
        d.gem_company_id      IS DISTINCT FROM t.gem_company_id      OR
        d.gem_location_id     IS DISTINCT FROM t.gem_location_id     OR
        d.is_sync_in_progress IS DISTINCT FROM t.is_sync_in_progress OR
        d.is_standalone       IS DISTINCT FROM t.is_standalone       OR
        d.is_master           IS DISTINCT FROM t.is_master           OR
        d.is_ecm_enabled      IS DISTINCT FROM t.is_ecm_enabled
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_catalog()
    OWNER TO citus;



CREATE OR REPLACE PROCEDURE dim.usp_refresh_menuitem()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    CREATE TEMP TABLE tmp_menuitem ON COMMIT DROP AS
    SELECT DISTINCT ON (menuitemid)
        menuitemid,
        menuitemname,
        entitytype,
        calories,
        protein,
        sugar,
        fat,
        is_alcoholic,
        is_vegetarian_item,
        is_vegan_item,
        has_allergen,
        item_class_type,
        is_active,
        is_deleted,
        gms_created_on,
        gms_modified_on,
        itemunitprice,
        price_changed_on,
        catalogid
    FROM stg.dim_menuitem
    ORDER BY menuitemid, gms_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_menuitem_id ON tmp_menuitem (menuitemid);

    -- INSERT net new
    INSERT INTO dim.menuitem (
        id,
        menuitemid,
        menuitemname,
        guest,
        effective_date,
        entitytype,
        calories,
        protein,
        sugar,
        fat,
        is_alcoholic,
        is_vegetarian_item,
        is_vegan_item,
        has_allergen,
        item_class_type,
        is_active,
        is_deleted,
        gms_created_on,
        gms_modified_on,
        itemunitprice,
        price_changed_on,
        catalogid,
        sysinserttime
    )
    SELECT
        nextval('dim.menuitem_id_seq'),
        t.menuitemid,
        t.menuitemname,
        1,
        NULL,
        t.entitytype,
        t.calories,
        t.protein,
        t.sugar,
        t.fat,
        t.is_alcoholic,
        t.is_vegetarian_item,
        t.is_vegan_item,
        t.has_allergen,
        t.item_class_type,
        t.is_active,
        t.is_deleted,
        t.gms_created_on,
        t.gms_modified_on,
        t.itemunitprice,
        t.price_changed_on,
        t.catalogid,
        NOW()
    FROM tmp_menuitem t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.menuitem d
        WHERE d.menuitemid = t.menuitemid
    );

    -- UPDATE changed
    UPDATE dim.menuitem d
    SET
        menuitemname       = t.menuitemname,
        entitytype         = t.entitytype,
        calories           = t.calories,
        protein            = t.protein,
        sugar              = t.sugar,
        fat                = t.fat,
        is_alcoholic       = t.is_alcoholic,
        is_vegetarian_item = t.is_vegetarian_item,
        is_vegan_item      = t.is_vegan_item,
        has_allergen       = t.has_allergen,
        item_class_type    = t.item_class_type,
        is_active          = t.is_active,
        is_deleted         = t.is_deleted,
        gms_created_on     = t.gms_created_on,
        gms_modified_on    = t.gms_modified_on,
        itemunitprice      = t.itemunitprice,
        price_changed_on   = t.price_changed_on,
        catalogid          = t.catalogid,
        sysupdatetime      = NOW()
    FROM tmp_menuitem t
    WHERE d.menuitemid = t.menuitemid
    AND (
        d.menuitemname       IS DISTINCT FROM t.menuitemname       OR
        d.entitytype         IS DISTINCT FROM t.entitytype         OR
        d.calories           IS DISTINCT FROM t.calories           OR
        d.protein            IS DISTINCT FROM t.protein            OR
        d.sugar              IS DISTINCT FROM t.sugar              OR
        d.fat                IS DISTINCT FROM t.fat                OR
        d.is_alcoholic       IS DISTINCT FROM t.is_alcoholic       OR
        d.is_vegetarian_item IS DISTINCT FROM t.is_vegetarian_item OR
        d.is_vegan_item      IS DISTINCT FROM t.is_vegan_item      OR
        d.has_allergen       IS DISTINCT FROM t.has_allergen       OR
        d.item_class_type    IS DISTINCT FROM t.item_class_type    OR
        d.is_active          IS DISTINCT FROM t.is_active          OR
        d.is_deleted         IS DISTINCT FROM t.is_deleted         OR
        d.gms_created_on     IS DISTINCT FROM t.gms_created_on     OR
        d.gms_modified_on    IS DISTINCT FROM t.gms_modified_on    OR
        d.itemunitprice      IS DISTINCT FROM t.itemunitprice      OR
        d.price_changed_on   IS DISTINCT FROM t.price_changed_on   OR
        d.catalogid          IS DISTINCT FROM t.catalogid
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_menuitem()
    OWNER to citus;




CREATE OR REPLACE PROCEDURE dim.usp_refresh_itemcategory()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    CREATE TEMP TABLE tmp_itemcategory ON COMMIT DROP AS
    SELECT DISTINCT ON (locationid, categoryid)
        locationid,
        categoryid,
        categoryname,
        is_category_active,
        catalogid,
        is_category_deleted,
        category_created_on,
        category_modified_on,
        is_alcoholic,
        number_of_items,
        number_of_sub_categories,
        number_of_item_variations,
        number_of_combos,
        number_of_combo_families
    FROM stg.dim_itemcategory
    ORDER BY locationid, categoryid, category_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_itemcategory ON tmp_itemcategory (locationid, categoryid);
    ANALYZE tmp_itemcategory;

    -- INSERT net new
    INSERT INTO dim.itemcategory (
        id,
        locationid,
        categoryid,
        categoryname,
        isactive,
        catalogid,
        is_category_deleted,
        category_created_on,
        category_modified_on,
        is_alcoholic,
        number_of_items,
        number_of_sub_categories,
        number_of_item_variations,
        number_of_combos,
        number_of_combo_families,
        sysinserttime
    )
    SELECT
        nextval('dim.itemcategory_id_seq'),
        t.locationid,
        t.categoryid,
        t.categoryname,
        t.is_category_active,
        t.catalogid,
        t.is_category_deleted,
        t.category_created_on,
        t.category_modified_on,
        t.is_alcoholic,
        t.number_of_items,
        t.number_of_sub_categories,
        t.number_of_item_variations,
        t.number_of_combos,
        t.number_of_combo_families,
        NOW()
    FROM tmp_itemcategory t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.itemcategory d
        WHERE d.locationid = t.locationid
        AND   d.categoryid = t.categoryid
    );

    -- UPDATE changed
    UPDATE dim.itemcategory d
    SET
        categoryname             = t.categoryname,
        isactive                 = t.is_category_active,
        catalogid                = t.catalogid,
        is_category_deleted      = t.is_category_deleted,
        category_created_on      = t.category_created_on,
        category_modified_on     = t.category_modified_on,
        is_alcoholic             = t.is_alcoholic,
        number_of_items          = t.number_of_items,
        number_of_sub_categories = t.number_of_sub_categories,
        number_of_item_variations = t.number_of_item_variations,
        number_of_combos         = t.number_of_combos,
        number_of_combo_families = t.number_of_combo_families,
        sysupdatetime            = NOW()
    FROM tmp_itemcategory t
    WHERE d.locationid = t.locationid
    AND   d.categoryid = t.categoryid
    AND (
        d.categoryname             IS DISTINCT FROM t.categoryname             OR
        d.isactive                 IS DISTINCT FROM t.is_category_active       OR
        d.catalogid                IS DISTINCT FROM t.catalogid                OR
        d.is_category_deleted      IS DISTINCT FROM t.is_category_deleted      OR
        d.category_created_on      IS DISTINCT FROM t.category_created_on      OR
        d.category_modified_on     IS DISTINCT FROM t.category_modified_on     OR
        d.is_alcoholic             IS DISTINCT FROM t.is_alcoholic             OR
        d.number_of_items          IS DISTINCT FROM t.number_of_items          OR
        d.number_of_sub_categories IS DISTINCT FROM t.number_of_sub_categories OR
        d.number_of_item_variations IS DISTINCT FROM t.number_of_item_variations OR
        d.number_of_combos         IS DISTINCT FROM t.number_of_combos         OR
        d.number_of_combo_families IS DISTINCT FROM t.number_of_combo_families
    );

END;
$BODY$;


ALTER PROCEDURE dim.usp_refresh_itemcategory()
    OWNER to citus;




CREATE OR REPLACE PROCEDURE dim.usp_refresh_category_hierarchy()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    CREATE TEMP TABLE tmp_category_hierarchy ON COMMIT DROP AS
    SELECT DISTINCT ON (locationid, categoryid, menuitemid)
        organizationid,
        locationid,
        mapping_created_on,
        mapping_modified_on,
        is_mapping_active,
        is_mapping_deleted,
        catalogid,
        catalogname,
        catalog_created_on,
        catalog_modified_on,
        is_catalog_active,
        is_catalog_deleted,
        categoryid,
        categoryname,
        category_created_on,
        category_modified_on,
        is_category_active,
        is_category_deleted,
        menuitemid,
        entitytype,
        item_class_type,
        menuitemname,
        item_created_on,
        item_modified_on,
        is_item_active,
        is_item_deleted,
        syscosmosts
    FROM stg.dim_category_hierarchy
    ORDER BY locationid, categoryid, menuitemid, mapping_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_category_hierarchy ON tmp_category_hierarchy (locationid, categoryid, menuitemid);

    -- INSERT net new
    INSERT INTO dim.category_hierarchy (
        organizationid,
        locationid,
        mapping_created_on,
        mapping_modified_on,
        is_mapping_active,
        is_mapping_deleted,
        catalogid,
        catalogname,
        catalog_created_on,
        catalog_modified_on,
        is_catalog_active,
        is_catalog_deleted,
        categoryid,
        categoryname,
        category_created_on,
        category_modified_on,
        is_category_active,
        is_category_deleted,
        menuitemid,
        entitytype,
        item_class_type,
        menuitemname,
        item_created_on,
        item_modified_on,
        is_item_active,
        is_item_deleted,
        syscosmosts,
        sysinserttime
    )
    SELECT
        t.organizationid,
        t.locationid,
        t.mapping_created_on,
        t.mapping_modified_on,
        t.is_mapping_active,
        t.is_mapping_deleted,
        t.catalogid,
        t.catalogname,
        t.catalog_created_on,
        t.catalog_modified_on,
        t.is_catalog_active,
        t.is_catalog_deleted,
        t.categoryid,
        t.categoryname,
        t.category_created_on,
        t.category_modified_on,
        t.is_category_active,
        t.is_category_deleted,
        t.menuitemid,
        t.entitytype,
        t.item_class_type,
        t.menuitemname,
        t.item_created_on,
        t.item_modified_on,
        t.is_item_active,
        t.is_item_deleted,
        t.syscosmosts,
        NOW()
    FROM tmp_category_hierarchy t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.category_hierarchy d
        WHERE d.locationid  = t.locationid
        AND   d.categoryid  = t.categoryid
        AND   d.menuitemid  = t.menuitemid
    );

    -- UPDATE changed
    UPDATE dim.category_hierarchy d
    SET
        organizationid       = t.organizationid,
        mapping_created_on   = t.mapping_created_on,
        mapping_modified_on  = t.mapping_modified_on,
        is_mapping_active    = t.is_mapping_active,
        is_mapping_deleted   = t.is_mapping_deleted,
        catalogid            = t.catalogid,
        catalogname          = t.catalogname,
        catalog_created_on   = t.catalog_created_on,
        catalog_modified_on  = t.catalog_modified_on,
        is_catalog_active    = t.is_catalog_active,
        is_catalog_deleted   = t.is_catalog_deleted,
        categoryname         = t.categoryname,
        category_created_on  = t.category_created_on,
        category_modified_on = t.category_modified_on,
        is_category_active   = t.is_category_active,
        is_category_deleted  = t.is_category_deleted,
        entitytype           = t.entitytype,
        item_class_type      = t.item_class_type,
        menuitemname         = t.menuitemname,
        item_created_on      = t.item_created_on,
        item_modified_on     = t.item_modified_on,
        is_item_active       = t.is_item_active,
        is_item_deleted      = t.is_item_deleted,
        syscosmosts          = t.syscosmosts,
        sysupdatetime        = NOW()
    FROM tmp_category_hierarchy t
    WHERE d.locationid  = t.locationid
    AND   d.categoryid  = t.categoryid
    AND   d.menuitemid  = t.menuitemid
    AND (
        d.organizationid       IS DISTINCT FROM t.organizationid       OR
        d.mapping_created_on   IS DISTINCT FROM t.mapping_created_on   OR
        d.mapping_modified_on  IS DISTINCT FROM t.mapping_modified_on  OR
        d.is_mapping_active    IS DISTINCT FROM t.is_mapping_active    OR
        d.is_mapping_deleted   IS DISTINCT FROM t.is_mapping_deleted   OR
        d.catalogid            IS DISTINCT FROM t.catalogid            OR
        d.catalogname          IS DISTINCT FROM t.catalogname          OR
        d.catalog_created_on   IS DISTINCT FROM t.catalog_created_on   OR
        d.catalog_modified_on  IS DISTINCT FROM t.catalog_modified_on  OR
        d.is_catalog_active    IS DISTINCT FROM t.is_catalog_active    OR
        d.is_catalog_deleted   IS DISTINCT FROM t.is_catalog_deleted   OR
        d.categoryname         IS DISTINCT FROM t.categoryname         OR
        d.category_created_on  IS DISTINCT FROM t.category_created_on  OR
        d.category_modified_on IS DISTINCT FROM t.category_modified_on OR
        d.is_category_active   IS DISTINCT FROM t.is_category_active   OR
        d.is_category_deleted  IS DISTINCT FROM t.is_category_deleted  OR
        d.entitytype           IS DISTINCT FROM t.entitytype           OR
        d.item_class_type      IS DISTINCT FROM t.item_class_type      OR
        d.menuitemname         IS DISTINCT FROM t.menuitemname         OR
        d.item_created_on      IS DISTINCT FROM t.item_created_on      OR
        d.item_modified_on     IS DISTINCT FROM t.item_modified_on     OR
        d.is_item_active       IS DISTINCT FROM t.is_item_active       OR
        d.is_item_deleted      IS DISTINCT FROM t.is_item_deleted      OR
        d.syscosmosts          IS DISTINCT FROM t.syscosmosts
    );

END;
$BODY$;


ALTER PROCEDURE dim.usp_refresh_category_hierarchy()
    OWNER to citus;




CREATE OR REPLACE PROCEDURE dim.usp_refresh_frequentcustomer()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    CREATE TEMP TABLE tmp_frequentcustomer ON COMMIT DROP AS
    SELECT DISTINCT ON (frequentcustomerid)
        frequentcustomerid,
        firstname,
        lastname,
        email,
        phone,
        source,
        organizationid,
        createddate,
        lastorderdate,
        ordercount,
        syscosmosts
    FROM stg.dim_frequentcustomer
    ORDER BY frequentcustomerid, sysinserttime DESC NULLS LAST;

    CREATE INDEX ix_tmp_frequentcustomer_id ON tmp_frequentcustomer (frequentcustomerid);

    -- INSERT net new
    INSERT INTO dim.frequentcustomer (
        customerkey,
        frequentcustomerid,
        firstname,
        lastname,
        email,
        phone,
        source,
        organizationid,
        createddate,
        lastorderdate,
        ordercount,
        amountspent,
        syscosmosts,
        sysinserttime
    )
    SELECT
        nextval('dim.frequentcustomer_customerkey_seq'),
        t.frequentcustomerid,
        t.firstname,
        t.lastname,
        t.email,
        t.phone,
        t.source,
        t.organizationid,
        t.createddate,
        t.lastorderdate,
        t.ordercount,
        0,
        t.syscosmosts,
        NOW()
    FROM tmp_frequentcustomer t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.frequentcustomer d
        WHERE d.frequentcustomerid = t.frequentcustomerid
    );

    -- UPDATE changed
    UPDATE dim.frequentcustomer d
    SET
        firstname      = t.firstname,
        lastname       = t.lastname,
        email          = t.email,
        phone          = t.phone,
        source         = t.source,
        organizationid = t.organizationid,
        createddate    = t.createddate,
        lastorderdate  = t.lastorderdate,
        ordercount     = t.ordercount,
        syscosmosts    = t.syscosmosts,
        sysupdatetime  = NOW()
    FROM tmp_frequentcustomer t
    WHERE d.frequentcustomerid = t.frequentcustomerid
    AND (
        d.firstname      IS DISTINCT FROM t.firstname      OR
        d.lastname       IS DISTINCT FROM t.lastname       OR
        d.email          IS DISTINCT FROM t.email          OR
        d.phone          IS DISTINCT FROM t.phone          OR
        d.source         IS DISTINCT FROM t.source         OR
        d.organizationid IS DISTINCT FROM t.organizationid OR
        d.createddate    IS DISTINCT FROM t.createddate    OR
        d.lastorderdate  IS DISTINCT FROM t.lastorderdate  OR
        d.ordercount     IS DISTINCT FROM t.ordercount     OR
        d.syscosmosts    IS DISTINCT FROM t.syscosmosts
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_frequentcustomer()
    OWNER to citus;



CREATE OR REPLACE PROCEDURE dim.usp_refresh_modifier()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- -------------------------------------------------------
    -- Step 1: Deduplicate stg into a temp table
    -- -------------------------------------------------------
    CREATE TEMP TABLE tmp_modifier ON COMMIT DROP AS
    SELECT DISTINCT ON (modifierid)
        modifierid,
        catalogid,
        modifiername,
        min_quantity,
        max_quantity,
        allow_quantity_increment,
        increment_step,
        calories,
        calories_text,
        is_modifier_active,
        is_modifier_deleted,
        modifier_created_on,
        modifier_modified_on,
        is_modifier_default,
        modifier_default_quantity,
        is_invisible,
        classification,
        price,
        price_changed_on
    FROM stg.dim_modifier
    ORDER BY modifierid, modifier_modified_on DESC NULLS LAST;

    -- Index on temp table to speed up JOIN in steps below
    CREATE INDEX ix_tmp_modifier_modifierid ON tmp_modifier (modifierid);

    -- -------------------------------------------------------
    -- Step 2: INSERT net new records only
    -- -------------------------------------------------------
    INSERT INTO dim.modifier (
        modifierid,
        catalogid,
        modifiername,
        min_quantity,
        max_quantity,
        allow_quantity_increment,
        increment_step,
        calories,
        calories_text,
        is_modifier_active,
        is_modifier_deleted,
        modifier_created_on,
        modifier_modified_on,
        is_modifier_default,
        modifier_default_quantity,
        is_invisible,
        classification,
        price,
        price_changed_on,
        sysinserttime
    )
    SELECT
        t.modifierid,
        t.catalogid,
        t.modifiername,
        t.min_quantity,
        t.max_quantity,
        t.allow_quantity_increment,
        t.increment_step,
        t.calories,
        t.calories_text,
        t.is_modifier_active,
        t.is_modifier_deleted,
        t.modifier_created_on,
        t.modifier_modified_on,
        t.is_modifier_default,
        t.modifier_default_quantity,
        t.is_invisible,
        t.classification,
        t.price,
        t.price_changed_on,
        NOW()
    FROM tmp_modifier t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.modifier d
        WHERE d.modifierid = t.modifierid
    );

    -- -------------------------------------------------------
    -- Step 3: UPDATE only changed records
    -- -------------------------------------------------------
    UPDATE dim.modifier d
    SET
        catalogid                = t.catalogid,
        modifiername             = t.modifiername,
        min_quantity             = t.min_quantity,
        max_quantity             = t.max_quantity,
        allow_quantity_increment = t.allow_quantity_increment,
        increment_step           = t.increment_step,
        calories                 = t.calories,
        calories_text            = t.calories_text,
        is_modifier_active       = t.is_modifier_active,
        is_modifier_deleted      = t.is_modifier_deleted,
        modifier_created_on      = t.modifier_created_on,
        modifier_modified_on     = t.modifier_modified_on,
        is_modifier_default      = t.is_modifier_default,
        modifier_default_quantity = t.modifier_default_quantity,
        is_invisible             = t.is_invisible,
        classification           = t.classification,
        price                    = t.price,
        price_changed_on         = t.price_changed_on,
        sysupdatetime            = NOW()
    FROM tmp_modifier t
    WHERE d.modifierid = t.modifierid
    AND (
        d.catalogid                IS DISTINCT FROM t.catalogid                OR
        d.modifiername             IS DISTINCT FROM t.modifiername             OR
        d.min_quantity             IS DISTINCT FROM t.min_quantity             OR
        d.max_quantity             IS DISTINCT FROM t.max_quantity             OR
        d.allow_quantity_increment IS DISTINCT FROM t.allow_quantity_increment OR
        d.increment_step           IS DISTINCT FROM t.increment_step           OR
        d.calories                 IS DISTINCT FROM t.calories                 OR
        d.calories_text            IS DISTINCT FROM t.calories_text            OR
        d.is_modifier_active       IS DISTINCT FROM t.is_modifier_active       OR
        d.is_modifier_deleted      IS DISTINCT FROM t.is_modifier_deleted      OR
        d.modifier_created_on      IS DISTINCT FROM t.modifier_created_on      OR
        d.modifier_modified_on     IS DISTINCT FROM t.modifier_modified_on     OR
        d.is_modifier_default      IS DISTINCT FROM t.is_modifier_default      OR
        d.modifier_default_quantity IS DISTINCT FROM t.modifier_default_quantity OR
        d.is_invisible             IS DISTINCT FROM t.is_invisible             OR
        d.classification           IS DISTINCT FROM t.classification           OR
        d.price                    IS DISTINCT FROM t.price                    OR
        d.price_changed_on         IS DISTINCT FROM t.price_changed_on
    );

END;
$BODY$;



ALTER PROCEDURE dim.usp_refresh_modifier()
    OWNER to citus;



CREATE OR REPLACE PROCEDURE dim.usp_refresh_modifiergroup()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    CREATE TEMP TABLE tmp_modifier_group ON COMMIT DROP AS
    SELECT DISTINCT ON (modifiergroupid)
        modifiergroupid,
        modifiergroupname,
        catalogid,
        max_selection,
        min_selection,
        free_count,
        pos_linked_entity_id,
        is_active,
        is_deleted,
        created_on,
        modified_on,
        negative_modifier_behavior,
        created_by,
        modified_by,
        max_aggregate_count,
        min_aggregate_count,
        increment_step,
        slider_mode,
        slider_mode_modifier
    FROM stg.dim_modifiergroup
    ORDER BY modifiergroupid, modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_modifier_group_id ON tmp_modifier_group (modifiergroupid);

    -- INSERT net new
    INSERT INTO dim.modifier_group (
        modifiergroupid,
        modifiergroupname,
        catalogid,
        max_selection,
        min_selection,
        free_count,
        pos_linked_entity_id,
        is_active,
        is_deleted,
        created_on,
        modified_on,
        negative_modifier_behavior,
        created_by,
        modified_by,
        max_aggregate_count,
        min_aggregate_count,
        increment_step,
        slider_mode,
        slider_mode_modifier,
        sysinserttime
    )
    SELECT
        t.modifiergroupid,
        t.modifiergroupname,
        t.catalogid,
        t.max_selection,
        t.min_selection,
        t.free_count,
        t.pos_linked_entity_id,
        t.is_active,
        t.is_deleted,
        t.created_on,
        t.modified_on,
        t.negative_modifier_behavior,
        t.created_by,
        t.modified_by,
        t.max_aggregate_count,
        t.min_aggregate_count,
        t.increment_step,
        t.slider_mode,
        t.slider_mode_modifier,
        NOW()
    FROM tmp_modifier_group t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.modifier_group d
        WHERE d.modifiergroupid = t.modifiergroupid
    );

    -- UPDATE changed
    UPDATE dim.modifier_group d
    SET
        modifiergroupname          = t.modifiergroupname,
        catalogid                  = t.catalogid,
        max_selection              = t.max_selection,
        min_selection              = t.min_selection,
        free_count                 = t.free_count,
        pos_linked_entity_id       = t.pos_linked_entity_id,
        is_active                  = t.is_active,
        is_deleted                 = t.is_deleted,
        created_on                 = t.created_on,
        modified_on                = t.modified_on,
        negative_modifier_behavior = t.negative_modifier_behavior,
        created_by                 = t.created_by,
        modified_by                = t.modified_by,
        max_aggregate_count        = t.max_aggregate_count,
        min_aggregate_count        = t.min_aggregate_count,
        increment_step             = t.increment_step,
        slider_mode                = t.slider_mode,
        slider_mode_modifier       = t.slider_mode_modifier,
        sysupdatetime              = NOW()
    FROM tmp_modifier_group t
    WHERE d.modifiergroupid = t.modifiergroupid
    AND (
        d.modifiergroupname          IS DISTINCT FROM t.modifiergroupname          OR
        d.catalogid                  IS DISTINCT FROM t.catalogid                  OR
        d.max_selection              IS DISTINCT FROM t.max_selection              OR
        d.min_selection              IS DISTINCT FROM t.min_selection              OR
        d.free_count                 IS DISTINCT FROM t.free_count                 OR
        d.pos_linked_entity_id       IS DISTINCT FROM t.pos_linked_entity_id       OR
        d.is_active                  IS DISTINCT FROM t.is_active                  OR
        d.is_deleted                 IS DISTINCT FROM t.is_deleted                 OR
        d.created_on                 IS DISTINCT FROM t.created_on                 OR
        d.modified_on                IS DISTINCT FROM t.modified_on                OR
        d.negative_modifier_behavior IS DISTINCT FROM t.negative_modifier_behavior OR
        d.created_by                 IS DISTINCT FROM t.created_by                 OR
        d.modified_by                IS DISTINCT FROM t.modified_by                OR
        d.max_aggregate_count        IS DISTINCT FROM t.max_aggregate_count        OR
        d.min_aggregate_count        IS DISTINCT FROM t.min_aggregate_count        OR
        d.increment_step             IS DISTINCT FROM t.increment_step             OR
        d.slider_mode                IS DISTINCT FROM t.slider_mode                OR
        d.slider_mode_modifier       IS DISTINCT FROM t.slider_mode_modifier
    );

END;
$BODY$;



ALTER PROCEDURE dim.usp_refresh_modifiergroup()
    OWNER to citus;


CREATE OR REPLACE PROCEDURE dim.usp_refresh_modifiergroup_modifier_mapping()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    CREATE TEMP TABLE tmp_modifier_group ON COMMIT DROP AS
    SELECT DISTINCT ON (modifiergroupid)
        modifiergroupid,
        modifiergroupname,
        catalogid,
        max_selection,
        min_selection,
        free_count,
        pos_linked_entity_id,
        is_active,
        is_deleted,
        created_on,
        modified_on,
        negative_modifier_behavior,
        created_by,
        modified_by,
        max_aggregate_count,
        min_aggregate_count,
        increment_step,
        slider_mode,
        slider_mode_modifier
    FROM stg.dim_modifiergroup
    ORDER BY modifiergroupid, modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_modifier_group_id ON tmp_modifier_group (modifiergroupid);

    -- INSERT net new
    INSERT INTO dim.modifier_group (
        modifiergroupid,
        modifiergroupname,
        catalogid,
        max_selection,
        min_selection,
        free_count,
        pos_linked_entity_id,
        is_active,
        is_deleted,
        created_on,
        modified_on,
        negative_modifier_behavior,
        created_by,
        modified_by,
        max_aggregate_count,
        min_aggregate_count,
        increment_step,
        slider_mode,
        slider_mode_modifier,
        sysinserttime
    )
    SELECT
        t.modifiergroupid,
        t.modifiergroupname,
        t.catalogid,
        t.max_selection,
        t.min_selection,
        t.free_count,
        t.pos_linked_entity_id,
        t.is_active,
        t.is_deleted,
        t.created_on,
        t.modified_on,
        t.negative_modifier_behavior,
        t.created_by,
        t.modified_by,
        t.max_aggregate_count,
        t.min_aggregate_count,
        t.increment_step,
        t.slider_mode,
        t.slider_mode_modifier,
        NOW()
    FROM tmp_modifier_group t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.modifier_group d
        WHERE d.modifiergroupid = t.modifiergroupid
    );

    -- UPDATE changed
    UPDATE dim.modifier_group d
    SET
        modifiergroupname          = t.modifiergroupname,
        catalogid                  = t.catalogid,
        max_selection              = t.max_selection,
        min_selection              = t.min_selection,
        free_count                 = t.free_count,
        pos_linked_entity_id       = t.pos_linked_entity_id,
        is_active                  = t.is_active,
        is_deleted                 = t.is_deleted,
        created_on                 = t.created_on,
        modified_on                = t.modified_on,
        negative_modifier_behavior = t.negative_modifier_behavior,
        created_by                 = t.created_by,
        modified_by                = t.modified_by,
        max_aggregate_count        = t.max_aggregate_count,
        min_aggregate_count        = t.min_aggregate_count,
        increment_step             = t.increment_step,
        slider_mode                = t.slider_mode,
        slider_mode_modifier       = t.slider_mode_modifier,
        sysupdatetime              = NOW()
    FROM tmp_modifier_group t
    WHERE d.modifiergroupid = t.modifiergroupid
    AND (
        d.modifiergroupname          IS DISTINCT FROM t.modifiergroupname          OR
        d.catalogid                  IS DISTINCT FROM t.catalogid                  OR
        d.max_selection              IS DISTINCT FROM t.max_selection              OR
        d.min_selection              IS DISTINCT FROM t.min_selection              OR
        d.free_count                 IS DISTINCT FROM t.free_count                 OR
        d.pos_linked_entity_id       IS DISTINCT FROM t.pos_linked_entity_id       OR
        d.is_active                  IS DISTINCT FROM t.is_active                  OR
        d.is_deleted                 IS DISTINCT FROM t.is_deleted                 OR
        d.created_on                 IS DISTINCT FROM t.created_on                 OR
        d.modified_on                IS DISTINCT FROM t.modified_on                OR
        d.negative_modifier_behavior IS DISTINCT FROM t.negative_modifier_behavior OR
        d.created_by                 IS DISTINCT FROM t.created_by                 OR
        d.modified_by                IS DISTINCT FROM t.modified_by                OR
        d.max_aggregate_count        IS DISTINCT FROM t.max_aggregate_count        OR
        d.min_aggregate_count        IS DISTINCT FROM t.min_aggregate_count        OR
        d.increment_step             IS DISTINCT FROM t.increment_step             OR
        d.slider_mode                IS DISTINCT FROM t.slider_mode                OR
        d.slider_mode_modifier       IS DISTINCT FROM t.slider_mode_modifier
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_modifiergroup_modifier_mapping()
    OWNER TO citus;