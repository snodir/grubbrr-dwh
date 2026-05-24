--CALL dim.usp_refresh_modifier(); --28s

SELECT count(*)
FROM stg.dim_modifier LIMIT 100; --949,757

SELECT count(*)
FROM dim.modifier LIMIT 100; --944,838 --946,213


-- Table: dim.modifier

-- DROP TABLE IF EXISTS dim.modifier;

CREATE TABLE IF NOT EXISTS dim.modifier
(
    modifierid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    catalogid character varying(50) COLLATE pg_catalog."default",
    modifiername character varying(255) COLLATE pg_catalog."default",
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    calories text COLLATE pg_catalog."default" NOT NULL,
    calories_text text COLLATE pg_catalog."default",
    is_modifier_active boolean NOT NULL,
    is_modifier_deleted boolean NOT NULL,
    modifier_created_on timestamp without time zone,
    modifier_modified_on timestamp without time zone,
    is_modifier_default boolean,
    modifier_default_quantity integer,
    is_invisible boolean,
    classification integer,
    price numeric(12,3),
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    price_changed_on timestamp without time zone,
    CONSTRAINT modifierid_unq UNIQUE (modifierid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.modifier
    OWNER to citus;
-- Index: ix_dim_modifier_catalogid

-- DROP INDEX IF EXISTS dim.ix_dim_modifier_catalogid;

CREATE INDEX IF NOT EXISTS ix_dim_modifier_catalogid
    ON dim.modifier USING btree
    (catalogid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


CREATE TABLE IF NOT EXISTS stg.dim_modifier
(
    modifierid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    catalogid character varying(50) COLLATE pg_catalog."default",
    modifiername character varying(255) COLLATE pg_catalog."default",
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    calories text COLLATE pg_catalog."default" NOT NULL,
    calories_text text COLLATE pg_catalog."default",
    is_modifier_active boolean NOT NULL,
    is_modifier_deleted boolean NOT NULL,
    modifier_created_on timestamp without time zone,
    modifier_modified_on timestamp without time zone,
    is_modifier_default boolean,
    modifier_default_quantity integer,
    is_invisible boolean,
    classification integer,
    price numeric(12,3),
    price_changed_on timestamp without time zone,
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_modifier
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