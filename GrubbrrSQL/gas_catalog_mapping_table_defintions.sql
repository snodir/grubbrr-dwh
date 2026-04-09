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
DROP COLUMN IF EXISTS modifierkey;
--ADD CONSTRAINT modifierid_unq UNIQUE (modifierid);
--DROP CONSTRAINT modifier_master_pkey


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