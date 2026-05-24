--CALL dim.usp_refresh_modifiergroup();


SELECT count(*)
FROM stg.dim_modifiergroup LIMIT 100; --544,525

SELECT count(*)
FROM dim.modifier_group LIMIT 100; --544,184 --544,525

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
    sysinserttime timestamp without time zone,
    CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_modifiergroup
    OWNER to citus;

--ALTER TABLE IF EXISTS stg.dim_modifiergroup
--ADD CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid)

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