SELECT * FROM dim.organizationlocation LIMIT 1000;
SELECT * FROM stg.dim_organizationlocation LIMIT 1000;
SELECT * FROM dim.userlocation LIMIT 1000;


ALTER TABLE dim.organizationlocation
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;

ALTER TABLE dim.userlocation
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE;


--CALL dim.usp_refresh_organizationlocation();

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
    CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.organizationlocation
    OWNER to citus;

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

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_organizationlocation()
    OWNER TO citus;