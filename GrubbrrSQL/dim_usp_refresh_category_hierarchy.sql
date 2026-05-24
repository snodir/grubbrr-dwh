--CALL dim.usp_refresh_category_hierarchy();
/*
SELECT now() as now1
UNION ALL
SELECT now() as now2;
*/

-- Table: dim.category_hierarchy

-- DROP TABLE IF EXISTS dim.category_hierarchy;

CREATE TABLE IF NOT EXISTS dim.category_hierarchy
(
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    catalogid text COLLATE pg_catalog."default",
    catalogname text COLLATE pg_catalog."default",
    catalog_created_on timestamp without time zone,
    catalog_modified_on timestamp without time zone,
    is_catalog_active boolean,
    is_catalog_deleted boolean,
    categoryid text COLLATE pg_catalog."default" NOT NULL,
    categoryname text COLLATE pg_catalog."default",
    category_created_on timestamp without time zone,
    category_modified_on timestamp without time zone,
    is_category_active boolean,
    is_category_deleted boolean,
    menuitemid text COLLATE pg_catalog."default",
    entitytype text COLLATE pg_catalog."default",
    item_class_type integer,
    menuitemname text COLLATE pg_catalog."default",
    item_created_on timestamp without time zone,
    item_modified_on timestamp without time zone,
    is_item_active boolean,
    is_item_deleted boolean,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.category_hierarchy
    OWNER to citus;


-- Table: dim.category_hierarchy

-- DROP TABLE IF EXISTS stg.dim_category_hierarchy;

CREATE TABLE IF NOT EXISTS stg.dim_category_hierarchy
(
    organizationid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    catalogid text COLLATE pg_catalog."default",
    catalogname text COLLATE pg_catalog."default",
    catalog_created_on timestamp without time zone,
    catalog_modified_on timestamp without time zone,
    is_catalog_active boolean,
    is_catalog_deleted boolean,
    categoryid text COLLATE pg_catalog."default" NOT NULL,
    categoryname text COLLATE pg_catalog."default",
    category_created_on timestamp without time zone,
    category_modified_on timestamp without time zone,
    is_category_active boolean,
    is_category_deleted boolean,
    menuitemid text COLLATE pg_catalog."default",
    entitytype text COLLATE pg_catalog."default",
    item_class_type integer,
    menuitemname text COLLATE pg_catalog."default",
    item_created_on timestamp without time zone,
    item_modified_on timestamp without time zone,
    is_item_active boolean,
    is_item_deleted boolean,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_category_hierarchy
    OWNER to citus;




CREATE OR REPLACE PROCEDURE dim.usp_refresh_category_hierarchy()
LANGUAGE plpgsql
AS $BODY$
BEGIN

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
    WITH deduped AS (
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
            syscosmosts,
            sysinserttime
        FROM stg.dim_category_hierarchy
        ORDER BY locationid, categoryid, menuitemid, mapping_modified_on DESC NULLS LAST
    )
    SELECT
        d.organizationid,
        d.locationid,
        d.mapping_created_on,
        d.mapping_modified_on,
        d.is_mapping_active,
        d.is_mapping_deleted,
        d.catalogid,
        d.catalogname,
        d.catalog_created_on,
        d.catalog_modified_on,
        d.is_catalog_active,
        d.is_catalog_deleted,
        d.categoryid,
        d.categoryname,
        d.category_created_on,
        d.category_modified_on,
        d.is_category_active,
        d.is_category_deleted,
        d.menuitemid,
        d.entitytype,
        d.item_class_type,
        d.menuitemname,
        d.item_created_on,
        d.item_modified_on,
        d.is_item_active,
        d.is_item_deleted,
        d.syscosmosts,
        NOW()
    FROM deduped d

    ON CONFLICT (locationid, categoryid, menuitemid) DO UPDATE SET
        organizationid       = EXCLUDED.organizationid,
        mapping_created_on   = EXCLUDED.mapping_created_on,
        mapping_modified_on  = EXCLUDED.mapping_modified_on,
        is_mapping_active    = EXCLUDED.is_mapping_active,
        is_mapping_deleted   = EXCLUDED.is_mapping_deleted,
        catalogid            = EXCLUDED.catalogid,
        catalogname          = EXCLUDED.catalogname,
        catalog_created_on   = EXCLUDED.catalog_created_on,
        catalog_modified_on  = EXCLUDED.catalog_modified_on,
        is_catalog_active    = EXCLUDED.is_catalog_active,
        is_catalog_deleted   = EXCLUDED.is_catalog_deleted,
        categoryname         = EXCLUDED.categoryname,
        category_created_on  = EXCLUDED.category_created_on,
        category_modified_on = EXCLUDED.category_modified_on,
        is_category_active   = EXCLUDED.is_category_active,
        is_category_deleted  = EXCLUDED.is_category_deleted,
        entitytype           = EXCLUDED.entitytype,
        item_class_type      = EXCLUDED.item_class_type,
        menuitemname         = EXCLUDED.menuitemname,
        item_created_on      = EXCLUDED.item_created_on,
        item_modified_on     = EXCLUDED.item_modified_on,
        is_item_active       = EXCLUDED.is_item_active,
        is_item_deleted      = EXCLUDED.is_item_deleted,
        syscosmosts          = EXCLUDED.syscosmosts,
        sysupdatetime        = NOW()

    WHERE (
        dim.category_hierarchy.organizationid       IS DISTINCT FROM EXCLUDED.organizationid       OR
        dim.category_hierarchy.mapping_created_on   IS DISTINCT FROM EXCLUDED.mapping_created_on   OR
        dim.category_hierarchy.mapping_modified_on  IS DISTINCT FROM EXCLUDED.mapping_modified_on  OR
        dim.category_hierarchy.is_mapping_active    IS DISTINCT FROM EXCLUDED.is_mapping_active    OR
        dim.category_hierarchy.is_mapping_deleted   IS DISTINCT FROM EXCLUDED.is_mapping_deleted   OR
        dim.category_hierarchy.catalogid            IS DISTINCT FROM EXCLUDED.catalogid            OR
        dim.category_hierarchy.catalogname          IS DISTINCT FROM EXCLUDED.catalogname          OR
        dim.category_hierarchy.catalog_created_on   IS DISTINCT FROM EXCLUDED.catalog_created_on   OR
        dim.category_hierarchy.catalog_modified_on  IS DISTINCT FROM EXCLUDED.catalog_modified_on  OR
        dim.category_hierarchy.is_catalog_active    IS DISTINCT FROM EXCLUDED.is_catalog_active    OR
        dim.category_hierarchy.is_catalog_deleted   IS DISTINCT FROM EXCLUDED.is_catalog_deleted   OR
        dim.category_hierarchy.categoryname         IS DISTINCT FROM EXCLUDED.categoryname         OR
        dim.category_hierarchy.category_created_on  IS DISTINCT FROM EXCLUDED.category_created_on  OR
        dim.category_hierarchy.category_modified_on IS DISTINCT FROM EXCLUDED.category_modified_on OR
        dim.category_hierarchy.is_category_active   IS DISTINCT FROM EXCLUDED.is_category_active   OR
        dim.category_hierarchy.is_category_deleted  IS DISTINCT FROM EXCLUDED.is_category_deleted  OR
        dim.category_hierarchy.entitytype           IS DISTINCT FROM EXCLUDED.entitytype           OR
        dim.category_hierarchy.item_class_type      IS DISTINCT FROM EXCLUDED.item_class_type      OR
        dim.category_hierarchy.menuitemname         IS DISTINCT FROM EXCLUDED.menuitemname         OR
        dim.category_hierarchy.item_created_on      IS DISTINCT FROM EXCLUDED.item_created_on      OR
        dim.category_hierarchy.item_modified_on     IS DISTINCT FROM EXCLUDED.item_modified_on     OR
        dim.category_hierarchy.is_item_active       IS DISTINCT FROM EXCLUDED.is_item_active       OR
        dim.category_hierarchy.is_item_deleted      IS DISTINCT FROM EXCLUDED.is_item_deleted      OR
        dim.category_hierarchy.syscosmosts          IS DISTINCT FROM EXCLUDED.syscosmosts
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_category_hierarchy()
    OWNER to citus;