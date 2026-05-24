--CALL dim.usp_refresh_modifiergroup_modifier_mapping();

-- Table: dim.modifier_group_mapping

-- DROP TABLE IF EXISTS dim.modifier_group_mapping;

CREATE TABLE IF NOT EXISTS dim.modifier_group_mapping
(
    modifier_mapping_id character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifierid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifiergroupid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    catalogid character varying(50) COLLATE pg_catalog."default",
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_default boolean,
    default_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    min_quantity integer,
    max_quantity integer,
    calories_text text COLLATE pg_catalog."default",
    is_invisible boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id),
    CONSTRAINT modfrgrp_modfr_unq UNIQUE (modifiergroupid, modifierid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.modifier_group_mapping
    OWNER to citus;


-- Table: dim.modifier_group_mapping

-- DROP TABLE IF EXISTS dim.modifier_group_mapping;

CREATE TABLE IF NOT EXISTS stg.dim_modifiergroup_modifier_mapping
(
    modifier_mapping_id character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifierid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifiergroupid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    catalogid character varying(50) COLLATE pg_catalog."default",
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_default boolean,
    default_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    min_quantity integer,
    max_quantity integer,
    calories_text text COLLATE pg_catalog."default",
    is_invisible boolean,
    sysinserttime timestamp without time zone,
    CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id),
    CONSTRAINT modfrgrp_modfr_unq UNIQUE (modifiergroupid, modifierid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_modifiergroup_modifier_mapping
    OWNER to citus;

--DROP PROCEDURE IF EXISTS dim.usp_refresh_modifiergroup_modifier_mapping();
CREATE OR REPLACE PROCEDURE dim.usp_refresh_modifiergroup_modifier_mapping()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    WITH deduped AS (
        SELECT DISTINCT ON (modifier_mapping_id)
            modifier_mapping_id,
            modifierid,
            modifiergroupid,
            catalogid,
            is_mapping_active,
            is_mapping_deleted,
            mapping_created_on,
            mapping_modified_on,
            is_default,
            default_quantity,
            allow_quantity_increment,
            increment_step,
            min_quantity,
            max_quantity,
            calories_text,
            is_invisible
        FROM stg.dim_modifiergroup_modifier_mapping
        ORDER BY modifier_mapping_id, mapping_modified_on DESC NULLS LAST
    )
    INSERT INTO dim.modifier_group_mapping (
        modifier_mapping_id,
        modifierid,
        modifiergroupid,
        catalogid,
        is_mapping_active,
        is_mapping_deleted,
        mapping_created_on,
        mapping_modified_on,
        is_default,
        default_quantity,
        allow_quantity_increment,
        increment_step,
        min_quantity,
        max_quantity,
        calories_text,
        is_invisible,
        sysinserttime
    )
    SELECT
        d.modifier_mapping_id,
        d.modifierid,
        d.modifiergroupid,
        d.catalogid,
        d.is_mapping_active,
        d.is_mapping_deleted,
        d.mapping_created_on,
        d.mapping_modified_on,
        d.is_default,
        d.default_quantity,
        d.allow_quantity_increment,
        d.increment_step,
        d.min_quantity,
        d.max_quantity,
        d.calories_text,
        d.is_invisible,
        NOW()
    FROM deduped d

    ON CONFLICT (modifier_mapping_id) DO UPDATE SET
        modifierid               = EXCLUDED.modifierid,
        modifiergroupid          = EXCLUDED.modifiergroupid,
        catalogid                = EXCLUDED.catalogid,
        is_mapping_active        = EXCLUDED.is_mapping_active,
        is_mapping_deleted       = EXCLUDED.is_mapping_deleted,
        mapping_created_on       = EXCLUDED.mapping_created_on,
        mapping_modified_on      = EXCLUDED.mapping_modified_on,
        is_default               = EXCLUDED.is_default,
        default_quantity         = EXCLUDED.default_quantity,
        allow_quantity_increment = EXCLUDED.allow_quantity_increment,
        increment_step           = EXCLUDED.increment_step,
        min_quantity             = EXCLUDED.min_quantity,
        max_quantity             = EXCLUDED.max_quantity,
        calories_text            = EXCLUDED.calories_text,
        is_invisible             = EXCLUDED.is_invisible,
        sysupdatetime            = NOW()

    WHERE (
        dim.modifier_group_mapping.modifierid               IS DISTINCT FROM EXCLUDED.modifierid               OR
        dim.modifier_group_mapping.modifiergroupid          IS DISTINCT FROM EXCLUDED.modifiergroupid          OR
        dim.modifier_group_mapping.catalogid                IS DISTINCT FROM EXCLUDED.catalogid                OR
        dim.modifier_group_mapping.is_mapping_active        IS DISTINCT FROM EXCLUDED.is_mapping_active        OR
        dim.modifier_group_mapping.is_mapping_deleted       IS DISTINCT FROM EXCLUDED.is_mapping_deleted       OR
        dim.modifier_group_mapping.mapping_created_on       IS DISTINCT FROM EXCLUDED.mapping_created_on       OR
        dim.modifier_group_mapping.mapping_modified_on      IS DISTINCT FROM EXCLUDED.mapping_modified_on      OR
        dim.modifier_group_mapping.is_default               IS DISTINCT FROM EXCLUDED.is_default               OR
        dim.modifier_group_mapping.default_quantity         IS DISTINCT FROM EXCLUDED.default_quantity         OR
        dim.modifier_group_mapping.allow_quantity_increment IS DISTINCT FROM EXCLUDED.allow_quantity_increment OR
        dim.modifier_group_mapping.increment_step           IS DISTINCT FROM EXCLUDED.increment_step           OR
        dim.modifier_group_mapping.min_quantity             IS DISTINCT FROM EXCLUDED.min_quantity             OR
        dim.modifier_group_mapping.max_quantity             IS DISTINCT FROM EXCLUDED.max_quantity             OR
        dim.modifier_group_mapping.calories_text            IS DISTINCT FROM EXCLUDED.calories_text            OR
        dim.modifier_group_mapping.is_invisible             IS DISTINCT FROM EXCLUDED.is_invisible
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_modifiergroup_modifier_mapping()
    OWNER TO citus;