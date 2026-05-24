--CALL dim.usp_refresh_itemcategory();

SELECT * FROM dim.itemcategory ORDER BY id ASC limit 1000;



-- Table: dim.itemcategory

-- DROP TABLE IF EXISTS dim.itemcategory;

CREATE TABLE IF NOT EXISTS dim.itemcategory
(
    id bigint NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    categoryid text COLLATE pg_catalog."default" NOT NULL,
    categoryname text COLLATE pg_catalog."default" NOT NULL,
    isactive boolean,
    catalogid text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    is_category_deleted BOOLEAN,
    category_created_on TIMESTAMP,
    category_modified_on TIMESTAMP,
    is_alcoholic BOOLEAN,
    number_of_items SMALLINT,
    number_of_sub_categories SMALLINT,
    number_of_item_variations SMALLINT,
    number_of_combos SMALLINT,
    number_of_combo_families SMALLINT,
    CONSTRAINT itemcategory_pk PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.itemcategory
OWNER to citus,
ALTER COLUMN isactive DROP NOT NULL,
ALTER COLUMN isactive DROP DEFAULT;



ALTER TABLE IF EXISTS dim.itemcategory
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS is_category_deleted BOOLEAN,
ADD COLUMN IF NOT EXISTS category_created_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS category_modified_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS is_alcoholic BOOLEAN,
ADD COLUMN IF NOT EXISTS number_of_items SMALLINT,
ADD COLUMN IF NOT EXISTS number_of_sub_categories SMALLINT,
ADD COLUMN IF NOT EXISTS number_of_item_variations SMALLINT,
ADD COLUMN IF NOT EXISTS number_of_combos SMALLINT,
ADD COLUMN IF NOT EXISTS number_of_combo_families SMALLINT;

-- DROP TABLE IF EXISTS stg.dim_itemcategory;

CREATE TABLE IF NOT EXISTS stg.dim_itemcategory
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    categoryid text COLLATE pg_catalog."default" NOT NULL,
    categoryname text COLLATE pg_catalog."default" NOT NULL,
    catalogid text COLLATE pg_catalog."default",
    is_category_active boolean,
    is_category_deleted BOOLEAN,
    category_created_on TIMESTAMP,
    category_modified_on TIMESTAMP,
    is_alcoholic BOOLEAN,
    number_of_items SMALLINT,
    number_of_sub_categories SMALLINT,
    number_of_item_variations SMALLINT,
    number_of_combos SMALLINT,
    number_of_combo_families SMALLINT,
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_itemcategory
    OWNER to citus;


-- One-time sequence setup
CREATE SEQUENCE IF NOT EXISTS dim.itemcategory_id_seq;

SELECT setval(
    'dim.itemcategory_id_seq',
    COALESCE((SELECT MAX(id) FROM dim.itemcategory), 0)
);

ALTER TABLE dim.itemcategory
    ALTER COLUMN id SET DEFAULT nextval('dim.itemcategory_id_seq');


-- Stored Procedure
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



SELECT ctlg.gem_location_id as locationid,
    c.id as categoryid,
    c.name as categoryname,
    c.catalog_id as catalogid,
    c.is_active as is_category_active,
    c.is_deleted as is_category_deleted,
    c.created_on as category_created_on,
    c.modified_on as category_modified_on,
    c.is_alcoholic,
    c.number_of_items,
    c.number_of_sub_categories,
    c.number_of_item_variations,
    c.number_of_combos,
    c.number_of_combo_families,
    NOW() :: TIMESTAMP as sysinserttime
FROM public.category_master as c
INNER JOIN public.catalog as ctlg 
    ON c.catalog_id = ctlg.id
WHERE ctlg.gem_location_id IS NOT NULL 
  AND ctlg.gem_location_id <> ''
LIMIT 1000;