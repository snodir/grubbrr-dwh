SELECT * FROM dim.element as el ORDER BY el.elementid DESC LIMIT 1000;

CALL dim.usp_refresh_element();

-- ============================================================
-- dim.element – Sequence Setup + Refresh Procedure
-- Source  : stg.silver_kiosk_events
--           WHERE eventmodule = 'kiosk' AND eventcategory = 'insight'
-- Target  : dim.element
-- Natural key  : (elementname, sourceelementid)
--               extracted from data.element + data.elementId JSON fields
-- Surrogate key: elementid (integer, sequence-based)
-- Pattern : INSERT-only, no mutable attributes
-- ADF notes:
--   sourceElement CosmosDB filter: same as sourceDim (module+insight+instant cutoff)
--   MAX(elementid)+keyGenerate → replaced by sequence nextval()
--   filter1: isNull(elementidentifier1)==false → exclude NULL sourceelementid rows
--   Defaults: empty string '' → 'None' for both elementname and sourceelementid
--   Negate exists ON (sourceelementid, elementname) → NOT EXISTS guard
--   Dedup: GROUP BY (elementname1, elementidentifier1) → DISTINCT in temp table
-- Execution order: must run BEFORE usp_silver_userbehaviour_to_fact
--   (fact.userbehaviour lookups dim.element for elementidentifier FK)
-- ============================================================


-- ============================================================
-- SECTION 1 – SEQUENCE SETUP (one-time, safe to re-run)
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS dim.element_id_seq;

SELECT setval(
    'dim.element_id_seq',
    COALESCE((SELECT MAX(elementid) FROM dim.element), 0)
);

ALTER TABLE dim.element
    ALTER COLUMN elementid SET DEFAULT nextval('dim.element_id_seq');

ALTER TABLE dim.element
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;


-- ============================================================
-- SECTION 2 – REFRESH STORED PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE dim.usp_refresh_element()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- ── Step 1: extract distinct elements from insight events ──
    -- Mirrors ADF: sourceElement → parse2 → select3 → derivedColumn10 → filter1 → aggregate4
    --
    -- Empty string defaults mirror ADF derivedColumn10:
    --   elementidentifier1 = case(elementidentifier=='','None',elementidentifier)
    --   elementname1       = case(elementname=='','None',elementname)
    --
    -- filter1 mirror: WHERE sourceelementid IS NOT NULL
    --   (ADF: isNull(elementidentifier1)==false — excludes rows where
    --    JSON had no elementId field at all, distinct from empty string → 'None')

    CREATE TEMP TABLE tmp_element ON COMMIT DROP AS
    SELECT DISTINCT
        COALESCE(NULLIF(TRIM(data::jsonb->>'element'),   ''), 'None') AS elementname,
        COALESCE(NULLIF(TRIM(data::jsonb->>'elementId'), ''), 'None') AS sourceelementid
    FROM stg.silver_kiosk_events as ke
    WHERE ke.eventmodule      = 'kiosk'
      AND ke.eventcategory    = 'insight'
      AND ke.data             IS NOT NULL
      AND ke.data             <> ''
      -- Mirrors ADF filter1: exclude rows where elementId parsed to NULL
      AND (ke.data::jsonb)->>'elementId' IS NOT NULL;

    CREATE INDEX ix_tmp_element ON tmp_element (elementname, sourceelementid);
    ANALYZE tmp_element;


    -- ── Step 2: INSERT net-new elements ──────────────────────
    -- Mirrors ADF exists6 negate exists ON
    --   (elementidentifier1==sourceelementid && elementname1==elementname)

    INSERT INTO dim.element (elementid, sourceelementid, elementname, sysinserttime)
    SELECT
        nextval('dim.element_id_seq'),
        t.sourceelementid,
        t.elementname,
        NOW()::TIMESTAMP
    FROM tmp_element t
    WHERE NOT EXISTS (
        SELECT 1
        FROM dim.element e
        WHERE e.sourceelementid = t.sourceelementid
          AND e.elementname     = t.elementname
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_element()
    OWNER TO citus;