SELECT * FROM dim.view LIMIT 1000;

--CALL dim.usp_refresh_view();

-- ============================================================
-- dim.view – Sequence Setup + Refresh Procedure
-- Source  : stg.silver_kiosk_events
--           WHERE eventmodule = 'kiosk' AND eventcategory = 'insight'
-- Target  : dim.view
-- Natural key  : viewname (text) — extracted from eventdata.view JSON field
-- Surrogate key: viewid  (integer, sequence-based)
-- Pattern : INSERT-only, no mutable attributes
-- ADF notes:
--   sourceDim CosmosDB filter: module='kiosk', category='insight', instant>'2024-06-23'
--   MAX(viewid)+keyGenerate → replaced by sequence nextval()
--   Dedup: GROUP BY viewidentifier1 in ADF → DISTINCT in temp table
--   Negate exists → NOT EXISTS guard
-- Execution order: must run BEFORE usp_silver_userbehaviour_to_fact
--   (fact.userbehaviour lookups dim.view for viewidentifier FK)
-- ============================================================


-- ============================================================
-- SECTION 1 – SEQUENCE SETUP (one-time, safe to re-run)
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS dim.view_id_seq;

SELECT setval(
    'dim.view_id_seq',
    COALESCE((SELECT MAX(viewid) FROM dim.view), 0)
);

ALTER TABLE dim.view
    ALTER COLUMN viewid SET DEFAULT nextval('dim.view_id_seq');

ALTER TABLE dim.view
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;


-- ============================================================
-- SECTION 2 – REFRESH STORED PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE dim.usp_refresh_view()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- ── Step 1: extract distinct view names from insight events ──
    -- Mirrors ADF: sourceDim → parse1 (data.view) → select2 → aggregate3
    -- NULL/blank view names excluded — no useful dimension value to store

    CREATE TEMP TABLE tmp_view ON COMMIT DROP AS
    SELECT DISTINCT
        NULLIF(TRIM(data::jsonb->>'view'), '') AS viewname
    FROM stg.silver_kiosk_events as ke
    WHERE ke.eventmodule      = 'kiosk'
      AND ke.eventcategory    = 'insight'
      AND ke.data             IS NOT NULL
      AND ke.data             <> ''
      AND NULLIF(TRIM(data::jsonb->>'view'), '') IS NOT NULL;

    CREATE INDEX ix_tmp_view ON tmp_view (viewname);
    ANALYZE tmp_view;


    -- ── Step 2: INSERT net-new view names ────────────────────
    -- Mirrors ADF exists5 (negate exists against DimView on viewname)

    INSERT INTO dim.view (viewid, viewname, sysinserttime)
    SELECT
        nextval('dim.view_id_seq'),
        t.viewname,
        NOW()::TIMESTAMP
    FROM tmp_view t
    WHERE NOT EXISTS (
        SELECT 1
        FROM dim.view v
        WHERE v.viewname = t.viewname
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_view()
    OWNER TO citus;