-- Table: public.catalog

-- DROP TABLE IF EXISTS public.catalog;
/*
SELECT c.id as catalogid,
       c.name as catalogname,
       c.organization_id as organizationid,
       c.is_deleted as is_catalog_deleted,
       c.created_on as catalog_created_on,
       c.modified_on as catalog_modified_on,
       c.gem_company_id,
       c.gem_location_id,
       c.sync_in_progress as is_sync_in_progress,
       c.is_standalone,
       c.is_master,
       c.is_ecm_enabled
FROM public.catalog as c
WHERE c.organization_id <> c.gem_company_id
  AND c.gem_company_id <> ''
*/

/***Modifier Classification
public enum ModifierClassificationType
{
    Undefined = 0,
    Protein = 1,
    Side = 2,
    Cheese = 3,
    Topping = 4,
    Sauce = 5,
    Size = 6,
    Prep = 7,
    Other = 8
}
*/

/***Menu Item Classification
0=Undefined
1=Main
2=Side
3=Drink
4=Dessert
5=Meal
6=Other
*/

SELECT * FROM dim.catalog

--DROP TABLE IF EXISTS dim.catalog;
CREATE TABLE IF NOT EXISTS dim.catalog
(
    catalogid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    catalogname character varying(255) COLLATE pg_catalog."default",
    organizationid character varying(40) COLLATE pg_catalog."default",
    is_catalog_deleted boolean,
    catalog_created_on timestamp without time zone,
    catalog_modified_on timestamp without time zone,
    gem_company_id character varying(255) COLLATE pg_catalog."default",
    gem_location_id character varying(255) COLLATE pg_catalog."default",
    is_sync_in_progress boolean,
    is_standalone boolean,
    is_master boolean,
    is_ecm_enabled boolean,
    CONSTRAINT catalog_pkey PRIMARY KEY (catalogid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.catalog
    OWNER to citus;

-- Table: dim.category_hierarchy

-- DROP TABLE IF EXISTS dim.category_hierarchy;

CREATE TABLE IF NOT EXISTS dim.category_hierarchy
(
    --id bigint NOT NULL,
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
    --CONSTRAINT category_hierarchy_pkey PRIMARY KEY (id),
    CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.category_hierarchy
    OWNER to citus;

ALTER TABLE IF EXISTS dim.category_hierarchy
DROP COLUMN IF EXISTS id;

ALTER TABLE IF EXISTS dim.modifier
DROP COLUMN IF EXISTS modifierkey;

/*
SELECT mm.id as modifierid,
       mm.catalog_id as catalogid,
       mm.name as modifiername,
       mm.min_quantity,
       mm.max_quantity,
       mm.allow_quantity_increment,
       mm.increment_step,
       mm.calories,
       mm.calories_text,
       mm.is_active as is_modifier_active,
       mm.is_deleted as is_modifier_deleted,
       mm.created_on as modifier_created_on,
       mm.modified_on as modifier_modified_on,
       mm.is_default as is_modifier_default,
       mm.default_quantity as modifier_default_quantity,
       mm.is_invisible,
       mm.classification,
       NULL :: numeric(12,3) as price
FROM public.modifier_master as mm
ORDER BY mm.id
LIMIT 100;

*/

-- Table: public.modifier_master

-- DROP TABLE IF EXISTS public.modifier_master;

CREATE TABLE IF NOT EXISTS dim.modifier
(
    --modifierkey BIGINT,
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
    price NUMERIC(12,3),
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT modifier_master_pkey PRIMARY KEY (modifierid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.modifier
    OWNER to citus;

ALTER TABLE IF EXISTS dim.modifier
--DROP COLUMN IF EXISTS modifierkey;
--ADD CONSTRAINT modifierid_unq UNIQUE (modifierid),
--DROP CONSTRAINT modifier_master_pkey
ADD COLUMN IF NOT EXISTS price_changed_on TIMESTAMP;


-- Table: public.modifier_group_modifier_glue

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
    CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.modifier_group_mapping
    OWNER to citus;


ALTER TABLE dim.modifier_group_mapping
ADD CONSTRAINT modfrgrp_modfr_unq UNIQUE (modifiergroupid, modifierid);



CREATE TABLE if not EXISTS dim.item_modifier_group_modifier_mapping(
    catalogid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    menuitemid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifiergroupid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    modifierid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    itm_modgrp_min_selection integer,
    itm_modgrp_max_selection integer,
    itm_modgrp_free_count integer,
    is_itm_modgrp_active boolean,
    is_itm_modgrp_deleted boolean,
    itm_modgrp_created_on timestamp without time zone,
    itm_modgrp_modified_on timestamp without time zone,
    is_itm_modgrp_invisible boolean,
    is_default BOOLEAN,
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    default_quantity integer,
    is_modgrp_modfr_active boolean NOT NULL,
    is_modgrp_modfr_deleted boolean NOT NULL,
    modgrp_modfr_created_on timestamp without time zone,
    modgrp_modfr_modified_on timestamp without time zone,
    is_modgrp_modfr_invisible boolean,
    sysinserttime TIMESTAMP WITHOUT TIME ZONE
);

ALTER TABLE dim.item_modifier_group_modifier_mapping
OWNER to citus;

ALTER TABLE dim.item_modifier_group_modifier_mapping
ADD CONSTRAINT item_modgrp_modfr_unq UNIQUE (menuitemid, modifiergroupid, modifierid)

ALTER TABLE dim.item_modifier_group_modifier_mapping
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;




-- Table: public.modifier_group_master

-- DROP TABLE IF EXISTS public.modifier_group_master;

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
    created_on timestamp without time zone, -- NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified_on timestamp without time zone, -- NOT NULL DEFAULT CURRENT_TIMESTAMP,
    negative_modifier_behavior integer,
    created_by character varying(255) COLLATE pg_catalog."default",
    modified_by character varying(255) COLLATE pg_catalog."default",
    max_aggregate_count integer,
    min_aggregate_count integer,
    increment_step integer,
    slider_mode boolean NOT NULL DEFAULT false,
    slider_mode_modifier boolean NOT NULL DEFAULT false,
    sysinserttime TIMESTAMP,
    sysupdatetime TIMESTAMP,
    CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.modifier_group
    OWNER to citus;

ALTER TABLE IF EXISTS dim.modifier_group
ALTER COLUMN created_on DROP NOT NULL,
ALTER COLUMN modified_on DROP NOT NULL,
ALTER COLUMN created_on DROP DEFAULT,
ALTER COLUMN modified_on DROP DEFAULT;



REVOKE ALL ON TABLE public.modifier_group_master FROM nensi;
REVOKE ALL ON TABLE public.modifier_group_master FROM nsadullaev;

GRANT ALL ON TABLE public.modifier_group_master TO citus;

GRANT INSERT, SELECT, UPDATE ON TABLE public.modifier_group_master TO nensi;

GRANT SELECT ON TABLE public.modifier_group_master TO nsadullaev;
-- Index: idx_modifier_group_master_active_filter

-- DROP INDEX IF EXISTS public.idx_modifier_group_master_active_filter;

CREATE INDEX IF NOT EXISTS idx_modifier_group_master_active_filter
    ON public.modifier_group_master USING btree
    (catalog_id COLLATE pg_catalog."default" ASC NULLS LAST, is_deleted ASC NULLS LAST, is_active ASC NULLS LAST)
    TABLESPACE pg_default
    WHERE is_deleted = false;
-- Index: idx_modifier_group_master_catalog_id_is_deleted

-- DROP INDEX IF EXISTS public.idx_modifier_group_master_catalog_id_is_deleted;

CREATE INDEX IF NOT EXISTS idx_modifier_group_master_catalog_id_is_deleted
    ON public.modifier_group_master USING btree
    (catalog_id COLLATE pg_catalog."default" ASC NULLS LAST, is_deleted ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: idx_modifier_group_master_list_display_name

-- DROP INDEX IF EXISTS public.idx_modifier_group_master_list_display_name;

CREATE INDEX IF NOT EXISTS idx_modifier_group_master_list_display_name
    ON public.modifier_group_master USING btree
    (catalog_id COLLATE pg_catalog."default" ASC NULLS LAST, is_deleted ASC NULLS LAST, display_name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default
    WHERE is_deleted = false;
-- Index: idx_modifier_group_master_list_name

-- DROP INDEX IF EXISTS public.idx_modifier_group_master_list_name;

CREATE INDEX IF NOT EXISTS idx_modifier_group_master_list_name
    ON public.modifier_group_master USING btree
    (catalog_id COLLATE pg_catalog."default" ASC NULLS LAST, is_deleted ASC NULLS LAST, name COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default
    WHERE is_deleted = false;
-- Index: ix_catalog_id_on_modifier_group_master

-- DROP INDEX IF EXISTS public.ix_catalog_id_on_modifier_group_master;

CREATE INDEX IF NOT EXISTS ix_catalog_id_on_modifier_group_master
    ON public.modifier_group_master USING btree
    (catalog_id COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: ix_ple_id_on_modifier_group_master

-- DROP INDEX IF EXISTS public.ix_ple_id_on_modifier_group_master;

CREATE INDEX IF NOT EXISTS ix_ple_id_on_modifier_group_master
    ON public.modifier_group_master USING btree
    (catalog_id COLLATE pg_catalog."default" ASC NULLS LAST, pos_linked_entity_id COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;