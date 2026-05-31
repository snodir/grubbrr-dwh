--CALL dim.usp_refresh_organizationlocation();

SELECT * FROM dim.organization LIMIT 1000;
SELECT * FROM dim.organizationlocation LIMIT 1000;
SELECT * FROM dim.location LIMIT 1000;

SELECT 
    TRIM(SPLIT_PART(REPLACE(REPLACE('(44.97367380000001,-93.2574684)', '(', ''), ')', ''), ',', 1)) as lat,
    TRIM(SPLIT_PART(REPLACE(REPLACE('(44.97367380000001,-93.2574684)', '(', ''), ')', ''), ',', 2)) as long


SELECT * FROM dim.organizationlocation LIMIT 1000;
SELECT * FROM stg.dim_organizationlocation LIMIT 1000;
SELECT * FROM dim.userlocation LIMIT 1000;

ALTER TABLE IF EXISTS dim.organization
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;

ALTER TABLE IF EXISTS dim.organizationlocation
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;

ALTER TABLE IF EXISTS dim.location
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;

ALTER TABLE IF EXISTS dim.userlocation
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE;



CREATE TABLE IF NOT EXISTS dim.organization (
    id character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    address1 character varying(255),
    address2 character varying(255),
    city character varying(255),
    state character varying(255),
    zipcode character varying(20),
    country character varying(255),
    organizationtype smallint,
    status smallint,
    phonenumber character varying(20),
    email character varying(255),
    isdeleted boolean DEFAULT false,
    createdon timestamp without time zone,
    createdby character varying(255),
    modifiedon timestamp without time zone,
    modifiedby character varying(255),
    active boolean,
    timezone character varying(50),
    coordinates text,
    dayofweek integer,
    hour integer,
    minutes integer,
    roundupforcharity boolean,
    is_ecm_enabled boolean,
    is_cep_enabled boolean,
    is_concessionaire_enabled boolean,
    is_smart_upsells_enabled boolean,
    is_feedback_survey_enabled boolean,
    is_digital_menu_board_enabled boolean,
    is_digital_menu_default_format_enabled boolean,
    cep_subscriptions text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);

-- Table: dim.organizationlocation

-- DROP TABLE IF EXISTS dim.organizationlocation;

CREATE TABLE IF NOT EXISTS dim.organizationlocation
(
    organizationid character varying(40) COLLATE pg_catalog."default" NOT NULL,
    organizationname character varying(255) COLLATE pg_catalog."default",
    locationid character varying(40) COLLATE pg_catalog."default" NOT NULL,
    locationname character varying(255) COLLATE pg_catalog."default" NOT NULL,
    organizationtype smallint,
    roundupforcharity boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
    CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.organizationlocation
    OWNER to citus;

CREATE TABLE IF NOT EXISTS dim.location (
    locationid text NOT NULL,
    companyid text NOT NULL,
    locationgroupid text,
    locationname text NOT NULL,
    address1 text,
    address2 text,
    city text,
    state text,
    zipcode text,
    latitude text,
    longitude text,
    timezone text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.location OWNER to citus;

--DROP TABLE IF EXISTS stg.dim_organizationlocation;
CREATE TABLE IF NOT EXISTS stg.dim_organizationlocation
(
    organizationid character varying(40) COLLATE pg_catalog."default" NOT NULL,
    organizationname character varying(255) COLLATE pg_catalog."default",
    locationid character varying(40) COLLATE pg_catalog."default" NOT NULL,
    locationname character varying(255) COLLATE pg_catalog."default" NOT NULL,
    organizationtype smallint,
    sysinserttime TIMESTAMP,
    CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_organizationlocation    
    OWNER to citus;


CREATE INDEX IF NOT EXISTS "IX_organizationid_locationid"
    ON dim.organizationlocation USING btree
    (organizationid COLLATE pg_catalog."default" ASC NULLS LAST, locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(organizationname, locationname)
    TABLESPACE pg_default;
-- Index: idx_organizationlocation_locationid

-- DROP INDEX IF EXISTS dim.idx_organizationlocation_locationid;

CREATE INDEX IF NOT EXISTS idx_organizationlocation_locationid
    ON dim.organizationlocation USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: idx_organizationlocation_organizationid

-- DROP INDEX IF EXISTS dim.idx_organizationlocation_organizationid;

CREATE INDEX IF NOT EXISTS idx_organizationlocation_organizationid
    ON dim.organizationlocation USING btree
    (organizationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;



-- ============================================================
-- dim.organizationlocation  –  Refresh Procedure
-- Source:  stg.dim_organizationlocation  (via ADF Copy Activity)
-- Target:  dim.organizationlocation
-- Natural key / PK : (organizationid, locationid)
-- No surrogate id – composite PK, no sequence required
-- ============================================================


-- ============================================================
-- SECTION 1 – ADD AUDIT COLUMNS TO TARGET TABLE
-- ============================================================

ALTER TABLE dim.organizationlocation
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;


-- ============================================================
-- SECTION 2 – REFRESH STORED PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE dim.usp_refresh_organizationlocation()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- ── Step 1: deduplicate staging ───────────────────────────
    CREATE TEMP TABLE tmp_organizationlocation ON COMMIT DROP AS
    SELECT DISTINCT ON (organizationid, locationid)
        organizationid,
        organizationname,
        locationid,
        locationname,
        organizationtype
        -- roundupforcharity excluded: fully derived in Step 4
        --                             from dim.organization, not from staging
    FROM stg.dim_organizationlocation
    ORDER BY organizationid, locationid, sysinserttime DESC NULLS LAST;

    CREATE INDEX ix_tmp_organizationlocation
        ON tmp_organizationlocation (organizationid, locationid);
    ANALYZE tmp_organizationlocation;

    -- ── Step 2: INSERT net-new org-location mappings ──────────
    INSERT INTO dim.organizationlocation (
        organizationid,
        organizationname,
        locationid,
        locationname,
        organizationtype,
        sysinserttime
        -- roundupforcharity: will be populated by Step 4
    )
    SELECT
        t.organizationid,
        t.organizationname,
        t.locationid,
        t.locationname,
        t.organizationtype,
        NOW()
    FROM tmp_organizationlocation t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.organizationlocation d
        WHERE d.organizationid = t.organizationid
          AND d.locationid     = t.locationid
    );

    -- ── Step 3: UPDATE changed attributes ────────────────────
    -- roundupforcharity intentionally excluded – owned by Step 4.
    -- Only fires when at least one mutable column has changed.
    UPDATE dim.organizationlocation d
    SET
        organizationname = t.organizationname,
        locationname     = t.locationname,
        organizationtype = t.organizationtype,
        sysupdatetime    = NOW()
    FROM tmp_organizationlocation t
    WHERE d.organizationid = t.organizationid
      AND d.locationid     = t.locationid
      AND (
          d.organizationname IS DISTINCT FROM t.organizationname OR
          d.locationname     IS DISTINCT FROM t.locationname     OR
          d.organizationtype IS DISTINCT FROM t.organizationtype
      );

    -- ── Step 4: derive roundupforcharity from dim.organization ─
    -- Org-level flag: if ANY location in the org has roundupforcharity = TRUE
    -- in dim.organization, all rows for that org are flagged TRUE.
    WITH cte AS (
        SELECT DISTINCT
            ol.organizationid,
            ol.locationid,
            SUM(CASE WHEN o.roundupforcharity = TRUE THEN 1 ELSE 0 END)
                OVER (PARTITION BY ol.organizationid) AS org_level_roundup_for_charity
        FROM dim.organizationlocation AS ol
        INNER JOIN dim.organization AS o
               ON ol.locationid = o.id
    )
    UPDATE dim.organizationlocation
    SET roundupforcharity = CASE
                                WHEN cte.org_level_roundup_for_charity > 0 THEN TRUE
                                ELSE FALSE
                            END
    FROM cte
    WHERE organizationlocation.organizationid = cte.organizationid
      AND organizationlocation.locationid     = cte.locationid;

-- ── Step 5: sync dim.location from organizationlocation + organization ──
    -- Scope: organizationtype = 0 (location-level rows only).
    -- Coordinates format in dim.organization: "(26.0940882,-80.2690641)"
    -- No columns added to dim.location — mapping to existing schema only.

    -- 5a: INSERT net-new locations
    INSERT INTO dim.location (
        locationid,
        companyid,          -- ← ol.organizationid
        locationgroupid,    -- no source mapping; NULL
        locationname,       -- ← ol.locationname
        address1,           -- ← o.address1
        address2,           -- ← o.address2
        city,               -- ← o.city
        state,              -- ← o.state
        zipcode,            -- ← o.zipcode
        latitude,           -- ← o.coordinates part 1
        longitude,          -- ← o.coordinates part 2
        timezone,           -- ← o.timezone
        sysinserttime
    )
    SELECT
        ol.locationid,
        ol.organizationid                                                                     AS companyid,
        NULL                                                                                  AS locationgroupid,
        ol.locationname,
        o.address1,
        o.address2,
        o.city,
        o.state,
        o.zipcode,
        TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 1))          AS latitude,
        TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 2))          AS longitude,
        o.timezone,
        NOW()
    FROM dim.organizationlocation ol
    INNER JOIN dim.organization o
            ON ol.locationid = o.id
           AND ol.organizationtype = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.location loc
        WHERE loc.locationid = ol.locationid
    );

    -- 5b: UPDATE changed location-level attributes
    UPDATE dim.location loc
    SET
        locationname  = ol.locationname,
        address1      = o.address1,
        address2      = o.address2,
        city          = o.city,
        state         = o.state,
        zipcode       = o.zipcode,
        latitude      = TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 1)),
        longitude     = TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 2)),
        timezone      = o.timezone,
        sysupdatetime = NOW()
    FROM dim.organizationlocation ol
    INNER JOIN dim.organization o
            ON ol.locationid = o.id
           AND ol.organizationtype = 0
    WHERE loc.locationid = ol.locationid
      AND (
          loc.locationname IS DISTINCT FROM ol.locationname                                                           OR
          loc.address1     IS DISTINCT FROM o.address1                                                                OR
          loc.address2     IS DISTINCT FROM o.address2                                                                OR
          loc.city         IS DISTINCT FROM o.city                                                                    OR
          loc.state        IS DISTINCT FROM o.state                                                                   OR
          loc.zipcode      IS DISTINCT FROM o.zipcode                                                                 OR
          loc.latitude     IS DISTINCT FROM TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 1)) OR
          loc.longitude    IS DISTINCT FROM TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 2)) OR
          loc.timezone     IS DISTINCT FROM o.timezone
      );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_organizationlocation()
    OWNER TO citus;

