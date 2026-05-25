--CALL dim.usp_refresh_catalog();

SELECT * FROM dim.catalog;


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



-- Table: dim.catalog

-- DROP TABLE IF EXISTS dim.catalog;

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
    sysinserttime TIMESTAMP,
    sysupdatetime TIMESTAMP,
    CONSTRAINT catalog_pkey PRIMARY KEY (catalogid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.catalog
    OWNER to citus;


ALTER TABLE IF EXISTS dim.catalog
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

-- Table: dim.catalog

-- DROP TABLE IF EXISTS dim.catalog;

-- Table: dim.catalog

-- DROP TABLE IF EXISTS dim.catalog;

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
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT catalog_pkey PRIMARY KEY (catalogid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.catalog
    OWNER to citus;


CREATE TABLE IF NOT EXISTS stg.dim_catalog
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
    sysinserttime timestamp without time zone,
    CONSTRAINT catalog_pkey PRIMARY KEY (catalogid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_catalog
    OWNER to citus;



CREATE OR REPLACE PROCEDURE dim.usp_refresh_catalog()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    CREATE TEMP TABLE tmp_catalog ON COMMIT DROP AS
    SELECT DISTINCT ON (catalogid)
        catalogid,
        catalogname,
        organizationid,
        is_catalog_deleted,
        catalog_created_on,
        catalog_modified_on,
        gem_company_id,
        gem_location_id,
        is_sync_in_progress,
        is_standalone,
        is_master,
        is_ecm_enabled
    FROM stg.dim_catalog
    ORDER BY catalogid, catalog_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_catalog ON tmp_catalog (catalogid);
    ANALYZE tmp_catalog;

    -- INSERT net new
    INSERT INTO dim.catalog (
        catalogid,
        catalogname,
        organizationid,
        is_catalog_deleted,
        catalog_created_on,
        catalog_modified_on,
        gem_company_id,
        gem_location_id,
        is_sync_in_progress,
        is_standalone,
        is_master,
        is_ecm_enabled,
        sysinserttime
    )
    SELECT
        t.catalogid,
        t.catalogname,
        t.organizationid,
        t.is_catalog_deleted,
        t.catalog_created_on,
        t.catalog_modified_on,
        t.gem_company_id,
        t.gem_location_id,
        t.is_sync_in_progress,
        t.is_standalone,
        t.is_master,
        t.is_ecm_enabled,
        NOW()
    FROM tmp_catalog t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.catalog d
        WHERE d.catalogid = t.catalogid
    );

    -- UPDATE changed
    UPDATE dim.catalog d
    SET
        catalogname         = t.catalogname,
        organizationid      = t.organizationid,
        is_catalog_deleted  = t.is_catalog_deleted,
        catalog_created_on  = t.catalog_created_on,
        catalog_modified_on = t.catalog_modified_on,
        gem_company_id      = t.gem_company_id,
        gem_location_id     = t.gem_location_id,
        is_sync_in_progress = t.is_sync_in_progress,
        is_standalone       = t.is_standalone,
        is_master           = t.is_master,
        is_ecm_enabled      = t.is_ecm_enabled,
        sysupdatetime       = NOW()
    FROM tmp_catalog t
    WHERE d.catalogid = t.catalogid
    AND (
        d.catalogname         IS DISTINCT FROM t.catalogname         OR
        d.organizationid      IS DISTINCT FROM t.organizationid      OR
        d.is_catalog_deleted  IS DISTINCT FROM t.is_catalog_deleted  OR
        d.catalog_created_on  IS DISTINCT FROM t.catalog_created_on  OR
        d.catalog_modified_on IS DISTINCT FROM t.catalog_modified_on OR
        d.gem_company_id      IS DISTINCT FROM t.gem_company_id      OR
        d.gem_location_id     IS DISTINCT FROM t.gem_location_id     OR
        d.is_sync_in_progress IS DISTINCT FROM t.is_sync_in_progress OR
        d.is_standalone       IS DISTINCT FROM t.is_standalone       OR
        d.is_master           IS DISTINCT FROM t.is_master           OR
        d.is_ecm_enabled      IS DISTINCT FROM t.is_ecm_enabled
    );

END;
$BODY$;