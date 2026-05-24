--CALL dim.usp_refresh_category_hierarchy();
/*
SELECT now() as now1
UNION ALL
SELECT now() as now2;
*/

SELECT count(*)
FROM stg.dim_category_hierarchy LIMIT 100; --612,772

SELECT count(*)
FROM dim.category_hierarchy LIMIT 100; --622,691 --623,026


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