--CALL dim.usp_refresh_modifiergroup();

-- Table: dim.modifier_group

-- DROP TABLE IF EXISTS dim.modifier_group;

CREATE TABLE IF NOT EXISTS dim.modifier_group
(
    modifiergroupid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifiergroupname character varying(510) COLLATE pg_catalog."default" NOT NULL,
    catalogid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    max_selection integer,
    min_selection integer,
    free_count integer,
    pos_linked_entity_id character varying(50) COLLATE pg_catalog."default",
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    negative_modifier_behavior integer,
    created_by character varying(255) COLLATE pg_catalog."default",
    modified_by character varying(255) COLLATE pg_catalog."default",
    max_aggregate_count integer,
    min_aggregate_count integer,
    increment_step integer,
    slider_mode boolean NOT NULL DEFAULT false,
    slider_mode_modifier boolean NOT NULL DEFAULT false,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.modifier_group
    OWNER to citus;
-- Index: ix_dim_modifiergroup_catalogid

-- DROP INDEX IF EXISTS dim.ix_dim_modifiergroup_catalogid;

CREATE INDEX IF NOT EXISTS ix_dim_modifiergroup_catalogid
    ON dim.modifier_group USING btree
    (catalogid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


-- Table: stg.dim_modifiergroup;
-- DROP TABLE IF EXISTS stg.dim_modifiergroup;

CREATE TABLE IF NOT EXISTS stg.dim_modifiergroup
(
    modifiergroupid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifiergroupname character varying(510) COLLATE pg_catalog."default" NOT NULL,
    catalogid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    max_selection integer,
    min_selection integer,
    free_count integer,
    pos_linked_entity_id character varying(50) COLLATE pg_catalog."default",
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    negative_modifier_behavior integer,
    created_by character varying(255) COLLATE pg_catalog."default",
    modified_by character varying(255) COLLATE pg_catalog."default",
    max_aggregate_count integer,
    min_aggregate_count integer,
    increment_step integer,
    slider_mode boolean NOT NULL DEFAULT false,
    slider_mode_modifier boolean NOT NULL DEFAULT false,
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_modifiergroup
    OWNER to citus;


CREATE OR REPLACE PROCEDURE dim.usp_refresh_modifiergroup()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    WITH deduped AS (
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
        ORDER BY modifiergroupid, modified_on DESC NULLS LAST
    )
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
        d.modifiergroupid,
        d.modifiergroupname,
        d.catalogid,
        d.max_selection,
        d.min_selection,
        d.free_count,
        d.pos_linked_entity_id,
        d.is_active,
        d.is_deleted,
        d.created_on,
        d.modified_on,
        d.negative_modifier_behavior,
        d.created_by,
        d.modified_by,
        d.max_aggregate_count,
        d.min_aggregate_count,
        d.increment_step,
        d.slider_mode,
        d.slider_mode_modifier,
        NOW()
    FROM deduped d

    ON CONFLICT (modifiergroupid) DO UPDATE SET
        modifiergroupname          = EXCLUDED.modifiergroupname,
        catalogid                  = EXCLUDED.catalogid,
        max_selection              = EXCLUDED.max_selection,
        min_selection              = EXCLUDED.min_selection,
        free_count                 = EXCLUDED.free_count,
        pos_linked_entity_id       = EXCLUDED.pos_linked_entity_id,
        is_active                  = EXCLUDED.is_active,
        is_deleted                 = EXCLUDED.is_deleted,
        created_on                 = EXCLUDED.created_on,
        modified_on                = EXCLUDED.modified_on,
        negative_modifier_behavior = EXCLUDED.negative_modifier_behavior,
        created_by                 = EXCLUDED.created_by,
        modified_by                = EXCLUDED.modified_by,
        max_aggregate_count        = EXCLUDED.max_aggregate_count,
        min_aggregate_count        = EXCLUDED.min_aggregate_count,
        increment_step             = EXCLUDED.increment_step,
        slider_mode                = EXCLUDED.slider_mode,
        slider_mode_modifier       = EXCLUDED.slider_mode_modifier,
        sysupdatetime              = NOW()

    WHERE (
        dim.modifier_group.modifiergroupname          IS DISTINCT FROM EXCLUDED.modifiergroupname          OR
        dim.modifier_group.catalogid                  IS DISTINCT FROM EXCLUDED.catalogid                  OR
        dim.modifier_group.max_selection              IS DISTINCT FROM EXCLUDED.max_selection              OR
        dim.modifier_group.min_selection              IS DISTINCT FROM EXCLUDED.min_selection              OR
        dim.modifier_group.free_count                 IS DISTINCT FROM EXCLUDED.free_count                 OR
        dim.modifier_group.pos_linked_entity_id       IS DISTINCT FROM EXCLUDED.pos_linked_entity_id       OR
        dim.modifier_group.is_active                  IS DISTINCT FROM EXCLUDED.is_active                  OR
        dim.modifier_group.is_deleted                 IS DISTINCT FROM EXCLUDED.is_deleted                 OR
        dim.modifier_group.created_on                 IS DISTINCT FROM EXCLUDED.created_on                 OR
        dim.modifier_group.modified_on                IS DISTINCT FROM EXCLUDED.modified_on                OR
        dim.modifier_group.negative_modifier_behavior IS DISTINCT FROM EXCLUDED.negative_modifier_behavior OR
        dim.modifier_group.created_by                 IS DISTINCT FROM EXCLUDED.created_by                 OR
        dim.modifier_group.modified_by                IS DISTINCT FROM EXCLUDED.modified_by                OR
        dim.modifier_group.max_aggregate_count        IS DISTINCT FROM EXCLUDED.max_aggregate_count        OR
        dim.modifier_group.min_aggregate_count        IS DISTINCT FROM EXCLUDED.min_aggregate_count        OR
        dim.modifier_group.increment_step             IS DISTINCT FROM EXCLUDED.increment_step             OR
        dim.modifier_group.slider_mode                IS DISTINCT FROM EXCLUDED.slider_mode                OR
        dim.modifier_group.slider_mode_modifier       IS DISTINCT FROM EXCLUDED.slider_mode_modifier
    );

END;
$BODY$;
