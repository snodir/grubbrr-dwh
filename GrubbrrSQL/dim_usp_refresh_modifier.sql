--CALL dim.usp_refresh_modifier();

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

    WITH deduped AS (
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
            price_changed_on,
            sysinserttime
        FROM stg.dim_modifier
        ORDER BY modifierid, modifier_modified_on DESC NULLS LAST
    )
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
        d.modifierid,
        d.catalogid,
        d.modifiername,
        d.min_quantity,
        d.max_quantity,
        d.allow_quantity_increment,
        d.increment_step,
        d.calories,
        d.calories_text,
        d.is_modifier_active,
        d.is_modifier_deleted,
        d.modifier_created_on,
        d.modifier_modified_on,
        d.is_modifier_default,
        d.modifier_default_quantity,
        d.is_invisible,
        d.classification,
        d.price,
        d.price_changed_on,
        NOW()
    FROM deduped d

    ON CONFLICT (modifierid) DO UPDATE SET
        catalogid                 = EXCLUDED.catalogid,
        modifiername              = EXCLUDED.modifiername,
        min_quantity              = EXCLUDED.min_quantity,
        max_quantity              = EXCLUDED.max_quantity,
        allow_quantity_increment  = EXCLUDED.allow_quantity_increment,
        increment_step            = EXCLUDED.increment_step,
        calories                  = EXCLUDED.calories,
        calories_text             = EXCLUDED.calories_text,
        is_modifier_active        = EXCLUDED.is_modifier_active,
        is_modifier_deleted       = EXCLUDED.is_modifier_deleted,
        modifier_created_on       = EXCLUDED.modifier_created_on,
        modifier_modified_on      = EXCLUDED.modifier_modified_on,
        is_modifier_default       = EXCLUDED.is_modifier_default,
        modifier_default_quantity = EXCLUDED.modifier_default_quantity,
        is_invisible              = EXCLUDED.is_invisible,
        classification            = EXCLUDED.classification,
        price                     = EXCLUDED.price,
        price_changed_on          = EXCLUDED.price_changed_on,
        sysupdatetime             = NOW()

    WHERE (
        dim.modifier.catalogid                IS DISTINCT FROM EXCLUDED.catalogid                OR
        dim.modifier.modifiername             IS DISTINCT FROM EXCLUDED.modifiername             OR
        dim.modifier.min_quantity             IS DISTINCT FROM EXCLUDED.min_quantity             OR
        dim.modifier.max_quantity             IS DISTINCT FROM EXCLUDED.max_quantity             OR
        dim.modifier.allow_quantity_increment IS DISTINCT FROM EXCLUDED.allow_quantity_increment OR
        dim.modifier.increment_step           IS DISTINCT FROM EXCLUDED.increment_step           OR
        dim.modifier.calories                 IS DISTINCT FROM EXCLUDED.calories                 OR
        dim.modifier.calories_text            IS DISTINCT FROM EXCLUDED.calories_text            OR
        dim.modifier.is_modifier_active       IS DISTINCT FROM EXCLUDED.is_modifier_active       OR
        dim.modifier.is_modifier_deleted      IS DISTINCT FROM EXCLUDED.is_modifier_deleted      OR
        dim.modifier.modifier_created_on      IS DISTINCT FROM EXCLUDED.modifier_created_on      OR
        dim.modifier.modifier_modified_on     IS DISTINCT FROM EXCLUDED.modifier_modified_on     OR
        dim.modifier.is_modifier_default      IS DISTINCT FROM EXCLUDED.is_modifier_default      OR
        dim.modifier.modifier_default_quantity IS DISTINCT FROM EXCLUDED.modifier_default_quantity OR
        dim.modifier.is_invisible             IS DISTINCT FROM EXCLUDED.is_invisible             OR
        dim.modifier.classification           IS DISTINCT FROM EXCLUDED.classification           OR
        dim.modifier.price                    IS DISTINCT FROM EXCLUDED.price                    OR
        dim.modifier.price_changed_on         IS DISTINCT FROM EXCLUDED.price_changed_on
    );

END;
$BODY$;