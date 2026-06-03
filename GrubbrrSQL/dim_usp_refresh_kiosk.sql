--CALL dim.usp_refresh_kiosk();


ALTER TABLE IF EXISTS dim.kiosk
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;



-- ============================================================
-- dim.kiosk  –  Staging Table + Refresh Procedure
-- Source:  gsh.device  (via ADF Copy Activity)
-- Target:  dim.kiosk
-- Pattern: ADF Copy Activity → stg.dim_kiosk → usp → dim.kiosk
-- Natural key : (locationid, kioskid)  [CONSTRAINT kiosk_uidx]
-- Surrogate key: id BIGINT  (sequence-based)
-- ============================================================


-- ============================================================
-- SECTION 1 – STAGING TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS stg.dim_kiosk
(
    locationid          TEXT                        NOT NULL,
    kioskid             TEXT                        NOT NULL,
    kioskname           TEXT,
    appversion          TEXT,
    istestkiosk         BOOLEAN,
    devicetype          CHARACTER VARYING(50),
    devicecreatedon     TIMESTAMP WITHOUT TIME ZONE,
    devicedeletedon     TIMESTAMP WITHOUT TIME ZONE,
    sysinserttime       TIMESTAMP WITHOUT TIME ZONE
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_kiosk
    OWNER TO citus;

TRUNCATE TABLE stg.dim_kiosk;

-- ============================================================
-- SECTION 2 – SEQUENCE SETUP (one-time)
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS dim.kiosk_id_seq;

SELECT setval(
    'dim.kiosk_id_seq',
    COALESCE((SELECT MAX(id) FROM dim.kiosk), 0)
);

ALTER TABLE IF EXISTS dim.kiosk
    ALTER COLUMN id SET DEFAULT nextval('dim.kiosk_id_seq');

-- Run this to add audit columns to dim.kiosk:
ALTER TABLE IF EXISTS dim.kiosk
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;


-- ============================================================
-- SECTION 3 – REFRESH STORED PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE dim.usp_refresh_kiosk()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- ── Step 1: deduplicate staging ───────────────────────────
    CREATE TEMP TABLE tmp_kiosk ON COMMIT DROP AS
    SELECT DISTINCT ON (locationid, kioskid)
        locationid,
        kioskid,
        kioskname,
        appversion,
        istestkiosk,
        COALESCE(devicetype, 'kiosk') AS devicetype,
        devicecreatedon,
        devicedeletedon
    FROM stg.dim_kiosk
    ORDER BY locationid, kioskid, devicecreatedon DESC NULLS LAST;

    CREATE INDEX ix_tmp_kiosk ON tmp_kiosk (locationid, kioskid);
    ANALYZE tmp_kiosk;

    -- ── Step 2: INSERT net-new devices ────────────────────────
    -- serialnumber: no source mapping in this pipeline, left NULL
    INSERT INTO dim.kiosk (
        id,
        locationid,
        kioskid,
        kioskname,
        appversion,
        istestkiosk,
        devicetype,
        devicecreatedon,
        devicedeletedon,
        sysinserttime
    )
    SELECT
        nextval('dim.kiosk_id_seq'),
        t.locationid,
        t.kioskid,
        t.kioskname,
        t.appversion,
        t.istestkiosk,
        t.devicetype,
        t.devicecreatedon,
        t.devicedeletedon,
        NOW()
    FROM tmp_kiosk t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.kiosk d
        WHERE d.locationid = t.locationid
          AND d.kioskid    = t.kioskid
    );

    -- ── Step 3: UPDATE changed attributes ────────────────────
    -- serialnumber intentionally excluded – no source value.
    -- Only fires when at least one mutable column has changed.
    UPDATE dim.kiosk d
    SET
        kioskname       = t.kioskname,
        appversion      = t.appversion,
        istestkiosk     = t.istestkiosk,
        devicetype      = t.devicetype,
        devicecreatedon = t.devicecreatedon,
        devicedeletedon = t.devicedeletedon,
        sysupdatetime   = NOW()
    FROM tmp_kiosk t
    WHERE d.locationid = t.locationid
      AND d.kioskid    = t.kioskid
      AND (
          d.kioskname       IS DISTINCT FROM t.kioskname       OR
          d.appversion      IS DISTINCT FROM t.appversion      OR
          d.istestkiosk     IS DISTINCT FROM t.istestkiosk     OR
          d.devicetype      IS DISTINCT FROM t.devicetype      OR
          d.devicecreatedon IS DISTINCT FROM t.devicecreatedon OR
          d.devicedeletedon IS DISTINCT FROM t.devicedeletedon
      );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_kiosk()
    OWNER TO citus;


-- ============================================================
-- Source query (for ADF Copy Activity reference)
-- ============================================================
-- SELECT DISTINCT
--        locationid,
--        deviceid            AS kioskid,
--        devicename          AS kioskname,
--        currentversion      AS appversion,
--        testmode            AS istestkiosk,
--        lower(devicetype)   AS devicetype,
--        enrollmentdate      AS devicecreatedon,
--        disenrollmentdate   AS devicedeletedon,
--        NOW()::TIMESTAMP    AS sysinserttime
-- FROM gsh.device;