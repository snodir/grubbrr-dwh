-- ============================================================
-- TABLE 5: ml.upsell_analysis
-- Granularity : one row per upsell recommendation event
-- Refresh     : daily
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
-- DROP PROCEDURE IF EXISTS ml.usp_refresh_upsell_analysis(DATE, INTEGER);
-- CALL ml.usp_refresh_upsell_analysis(p_refresh_mode => 1);

--SELECT * FROM ml.upsell_analysis LIMIT 1000;

CREATE TABLE IF NOT EXISTS ml.upsell_analysis (
    organizationid      TEXT COLLATE pg_catalog."default",
    organizationname    TEXT COLLATE pg_catalog."default",
    locationid          TEXT COLLATE pg_catalog."default",
    locationname        TEXT COLLATE pg_catalog."default",
    frequentcustomerid  TEXT COLLATE pg_catalog."default",
    transactionheaderid TEXT COLLATE pg_catalog."default",
    recommendationid    TEXT COLLATE pg_catalog."default",
    offereditem         TEXT COLLATE pg_catalog."default",
    selecteditem        TEXT COLLATE pg_catalog."default",
    item_class_type     INTEGER, -- TEXT COLLATE pg_catalog."default",
    upselltype          TEXT COLLATE pg_catalog."default",
    quantity            INTEGER, --NUMERIC(10,3),
    businessdate        DATE,
    orderdatelocal      TIMESTAMP,
    yyyy                INTEGER,
    mm                  INTEGER,
    dd                  INTEGER,
    hh                  INTEGER,
    ww                  INTEGER,
    sysinserttime       TIMESTAMP
);

/*

CREATE INDEX IF NOT EXISTS ix_ml_ua_yyyy_ww
    ON ml.upsell_analysis (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_ua_locid_yyyy_ww
    ON ml.upsell_analysis (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_ua_businessdate
    ON ml.upsell_analysis (businessdate);

*/
-- ============================================================
-- STORED PROCEDURE: ml.usp_refresh_upsell_analysis
--
-- PURPOSE:
--   Refreshes the ml.upsell_analysis table by joining upsell offer
--   data with transaction headers, org/location info, and menu item
--   classifications. Supports a full historical reload or an
--   incremental refresh from the last loaded date onward.
--
-- PARAMETERS:
--   p_refresh_mode  INT  (default: 1)
--     1 = Incremental – deletes and reloads data from the current
--         max(businessdate) in the target table onward. Ensures the
--         most recent (potentially partial) day is corrected and any
--         new data since the last run is captured.
--     0 = Full load – truncates the entire table and reloads all
--         available history from the source. Use sparingly; intended
--         for initial loads or full reseeds only.
--
-- INCREMENTAL LOGIC:
--   The procedure reads max(businessdate) from ml.upsell_analysis at
--   runtime and stores it in v_max_businessdate. This same value is
--   used for both the DELETE and the source query, guaranteeing they
--   are always in sync regardless of when the proc runs.
--   On a cold start (empty table), v_max_businessdate will be NULL,
--   causing the WHERE filter to evaluate to NULL and load everything —
--   effectively behaving like a full load automatically.
--
-- SOURCE OBJECTS:
--   fact.vw_offer_analysis        – one row per upsell offer/selection event
--   fact.transactionheader        – joined to bring in businessdate, orderdatelocal,
--                                   and frequentcustomerid
--   dim.organizationlocation      – maps locationid to org/location names (type=0 only)
--   dim.menuitem                  – item classification lookup; uses offereditem unless
--                                   it is a category-level offer (prefixed 'cat-'),
--                                   in which case selecteditem is used instead
--
-- TARGET TABLE:
--   ml.upsell_analysis
--
-- OWNER: citus
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_upsell_analysis(
    p_refresh_mode  INT  DEFAULT 1
)
LANGUAGE plpgsql
AS $BODY$
DECLARE
    v_max_businessdate DATE;  -- Holds the current max date in the target table;
                              -- used to anchor both the delete and the source filter
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.upsell_analysis;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.upsell_analysis;

        DELETE FROM ml.upsell_analysis
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM fact.transactionheader
        WHERE (
                p_refresh_mode = 0                        -- full load: no date restriction
                OR businessdate >= v_max_businessdate     -- incremental: from max date onward
        )
    )
    INSERT INTO ml.upsell_analysis
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        oa.locationid,
        ol.locationname,
        th.frequentcustomerid,
        oa.transactionheaderid,
        oa.recommendationid,
        oa.offereditem,
        oa.selecteditem,
        mi.item_class_type,
        oa.upselltype,
        oa.quantity,
        th.businessdate,
        th.orderdatelocal,
        EXTRACT(YEAR  FROM th.businessdate)::INTEGER   AS yyyy,
        EXTRACT(MONTH FROM th.businessdate)::INTEGER   AS mm,
        EXTRACT(DAY   FROM th.businessdate)::INTEGER   AS dd,
        EXTRACT(HOUR  FROM th.orderdatelocal)::INTEGER AS hh,
        EXTRACT(WEEK  FROM th.businessdate)::INTEGER   AS ww,
        NOW()::TIMESTAMP                               AS sysinserttime  -- audit timestamp for when the row was loaded
    FROM fact.vw_offer_analysis AS oa
    INNER JOIN cte AS th
        ON  oa.locationid          = th.locationid
        AND oa.transactionheaderid = th.transactionheaderid
    LEFT JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON oa.locationid = ol.locationid                -- type=0 filters to standard locations only
    LEFT JOIN dim.menuitem AS mi
        ON (
            CASE
                WHEN oa.offereditem NOT LIKE 'cat-%' THEN oa.offereditem  -- item-level offer: use offereditem directly
                ELSE oa.selecteditem                                       -- category-level offer: fall back to what was actually selected
            END
        ) = mi.menuitemid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_upsell_analysis(INT) OWNER TO citus;

WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname,
                    ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '@{pipeline().parameters.p_orgid}'
      AND ol.organizationtype = 0
)
SELECT
    ua.organizationid,
    ua.organizationname,
    ua.locationid,
    ua.locationname,
    ua.frequentcustomerid,
    ua.transactionheaderid,
    ua.recommendationid,
    ua.offereditem,
    ua.selecteditem,
    ua.item_class_type,
    ua.upselltype,
    ua.quantity,
    ua.businessdate,
    ua.orderdatelocal,
    ua.yyyy,
    ua.mm,
    ua.dd,
    ua.hh,
    ua.ww
FROM ml.upsell_analysis AS ua
WHERE ua.locationid IN (SELECT locationid FROM org_loc_lookup)
  AND ua.yyyy = @{item().yearval}
  AND ua.ww   = @{item().weekval}