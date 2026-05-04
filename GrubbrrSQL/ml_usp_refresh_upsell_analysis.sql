-- ============================================================
-- TABLE 5: ml.upsell_analysis
-- Granularity : one row per upsell recommendation event
-- Refresh     : daily
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_upsell_analysis(p_businessdate => CURRENT_DATE - 1, p_refresh_mode => 0);

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
-- STORED PROCEDURE 5: ml.usp_refresh_upsell_analysis
-- Refresh type : DAILY DELETE + INSERT (idempotent) / FULL TRUNCATE + INSERT
-- Parameters   : p_businessdate DATE  (default: yesterday)
--                  The specific calendar day to delete and reload.
--                p_refresh_mode INT   (default: 1)
--                  1 = Incremental – delete/insert for p_businessdate only
--                  0 = Full load   – TRUNCATE the table, then insert ALL history
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_upsell_analysis(
    p_businessdate  DATE DEFAULT CURRENT_DATE - 1,
    p_refresh_mode  INT  DEFAULT 1
)
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.upsell_analysis;
    ELSE
        -- Incremental: idempotent delete for the target day only
        DELETE FROM ml.upsell_analysis
        WHERE businessdate = p_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM fact.transactionheader
        WHERE (
                p_refresh_mode = 0
                OR businessdate = p_businessdate
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
        NOW()::TIMESTAMP                               AS sysinserttime
    FROM fact.vw_offer_analysis AS oa
    INNER JOIN cte AS th
        ON  oa.locationid          = th.locationid
        AND oa.transactionheaderid = th.transactionheaderid
    LEFT JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON oa.locationid = ol.locationid
    LEFT JOIN dim.menuitem AS mi
        ON (
            CASE
                WHEN oa.offereditem NOT LIKE 'cat-%' THEN oa.offereditem
                ELSE oa.selecteditem
            END
        ) = mi.menuitemid;

END;
$BODY$;
ALTER PROCEDURE ml.usp_refresh_upsell_analysis(DATE, INT) OWNER TO citus;


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