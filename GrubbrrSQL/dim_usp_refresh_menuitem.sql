--CALL dim.usp_refresh_menuitem();

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

    WITH deduped AS (
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
            catalogid,
            sysinserttime
        FROM stg.dim_menuitem
        ORDER BY menuitemid, gms_modified_on DESC NULLS LAST
    )
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
        d.menuitemid,
        d.menuitemname,
        1,
        NULL,
        d.entitytype,
        d.calories,
        d.protein,
        d.sugar,
        d.fat,
        d.is_alcoholic,
        d.is_vegetarian_item,
        d.is_vegan_item,
        d.has_allergen,
        d.item_class_type,
        d.is_active,
        d.is_deleted,
        d.gms_created_on,
        d.gms_modified_on,
        d.itemunitprice,
        d.price_changed_on,
        d.catalogid,
        NOW()
    FROM deduped d

    ON CONFLICT (menuitemid) DO UPDATE SET
        menuitemname       = EXCLUDED.menuitemname,
        entitytype         = EXCLUDED.entitytype,
        calories           = EXCLUDED.calories,
        protein            = EXCLUDED.protein,
        sugar              = EXCLUDED.sugar,
        fat                = EXCLUDED.fat,
        is_alcoholic       = EXCLUDED.is_alcoholic,
        is_vegetarian_item = EXCLUDED.is_vegetarian_item,
        is_vegan_item      = EXCLUDED.is_vegan_item,
        has_allergen       = EXCLUDED.has_allergen,
        item_class_type    = EXCLUDED.item_class_type,
        is_active          = EXCLUDED.is_active,
        is_deleted         = EXCLUDED.is_deleted,
        gms_created_on     = EXCLUDED.gms_created_on,
        gms_modified_on    = EXCLUDED.gms_modified_on,
        itemunitprice      = EXCLUDED.itemunitprice,
        price_changed_on   = EXCLUDED.price_changed_on,
        catalogid          = EXCLUDED.catalogid,
        sysupdatetime      = NOW()

    WHERE (
        dim.menuitem.menuitemname       IS DISTINCT FROM EXCLUDED.menuitemname       OR
        dim.menuitem.entitytype         IS DISTINCT FROM EXCLUDED.entitytype         OR
        dim.menuitem.calories           IS DISTINCT FROM EXCLUDED.calories           OR
        dim.menuitem.protein            IS DISTINCT FROM EXCLUDED.protein            OR
        dim.menuitem.sugar              IS DISTINCT FROM EXCLUDED.sugar              OR
        dim.menuitem.fat                IS DISTINCT FROM EXCLUDED.fat                OR
        dim.menuitem.is_alcoholic       IS DISTINCT FROM EXCLUDED.is_alcoholic       OR
        dim.menuitem.is_vegetarian_item IS DISTINCT FROM EXCLUDED.is_vegetarian_item OR
        dim.menuitem.is_vegan_item      IS DISTINCT FROM EXCLUDED.is_vegan_item      OR
        dim.menuitem.has_allergen       IS DISTINCT FROM EXCLUDED.has_allergen       OR
        dim.menuitem.item_class_type    IS DISTINCT FROM EXCLUDED.item_class_type    OR
        dim.menuitem.is_active          IS DISTINCT FROM EXCLUDED.is_active          OR
        dim.menuitem.is_deleted         IS DISTINCT FROM EXCLUDED.is_deleted         OR
        dim.menuitem.gms_created_on     IS DISTINCT FROM EXCLUDED.gms_created_on     OR
        dim.menuitem.gms_modified_on    IS DISTINCT FROM EXCLUDED.gms_modified_on    OR
        dim.menuitem.itemunitprice      IS DISTINCT FROM EXCLUDED.itemunitprice      OR
        dim.menuitem.price_changed_on   IS DISTINCT FROM EXCLUDED.price_changed_on   OR
        dim.menuitem.catalogid          IS DISTINCT FROM EXCLUDED.catalogid
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_menuitem()
    OWNER to citus;