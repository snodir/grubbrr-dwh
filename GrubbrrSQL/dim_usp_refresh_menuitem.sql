--CALL dim.usp_refresh_menuitem();

SELECT count(*)
FROM stg.dim_menuitem LIMIT 100; --960,688

SELECT count(*)
FROM dim.menuitem LIMIT 100;  --952,914

SELECT * FROM dim.menuitem
WHERE menuitemid NOT IN (SELECT menuitemid FROM stg.dim_menuitem)

SELECT * FROM stg.dim_menuitem 
WHERE menuitemid NOT IN (SELECT menuitemid FROM dim.menuitem)


-- Table: dim.menuitem

-- DROP TABLE IF EXISTS dim.menuitem;

CREATE TABLE IF NOT EXISTS dim.menuitem
(
    id bigint NOT NULL,
    menuitemid text COLLATE pg_catalog."default" NOT NULL,
    menuitemname text COLLATE pg_catalog."default" NOT NULL,
    guest integer NOT NULL DEFAULT 1,
    effective_date date,
    item_class_type integer,
    entitytype text COLLATE pg_catalog."default",
    calories text COLLATE pg_catalog."default",
    protein numeric,
    sugar numeric,
    fat numeric,
    is_alcoholic boolean,
    is_vegetarian_item boolean,
    is_vegan_item boolean,
    has_allergen boolean,
    is_active boolean,
    is_deleted boolean,
    gms_created_on timestamp without time zone,
    gms_modified_on timestamp without time zone,
    itemunitprice numeric(12,3),
    price_changed_on timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    catalogid text COLLATE pg_catalog."default",
    CONSTRAINT menuitem_pk PRIMARY KEY (id),
    CONSTRAINT menuitemid_unq UNIQUE (menuitemid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.menuitem
    OWNER to citus;

CREATE INDEX IF NOT EXISTS ix_dim_menuitem_catalogid
    ON dim.menuitem USING btree
    (catalogid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


CREATE TABLE IF NOT EXISTS stg.dim_menuitem
(   menuitemid text COLLATE pg_catalog."default" NOT NULL,
    menuitemname text COLLATE pg_catalog."default" NOT NULL,
    entitytype text COLLATE pg_catalog."default",
    calories text COLLATE pg_catalog."default",
    protein numeric,
    sugar numeric,
    fat numeric,
    is_alcoholic boolean,
    is_vegetarian_item boolean,
    is_vegan_item boolean,
    has_allergen boolean,
    item_class_type integer,
    is_active boolean,
    is_deleted boolean,
    gms_created_on timestamp without time zone,
    gms_modified_on timestamp without time zone,
    itemunitprice numeric(12,3),
    price_changed_on timestamp without time zone,
    catalogid text COLLATE pg_catalog."default",
    sysinserttime TIMESTAMP
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_menuitem
    OWNER to citus;


-- One-time sequence setup
CREATE SEQUENCE IF NOT EXISTS dim.menuitem_id_seq;

SELECT setval(
    'dim.menuitem_id_seq',
    COALESCE((SELECT MAX(id) FROM dim.menuitem), 0)
);

ALTER TABLE dim.menuitem
    ALTER COLUMN id SET DEFAULT nextval('dim.menuitem_id_seq');

--CALL dim.usp_refresh_menuitem();



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
