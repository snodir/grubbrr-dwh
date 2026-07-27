-- ============================================================
-- Stored Procedures: ml schema
-- Extracted from gas_db_merged_20260530.sql
-- Generated: 2026-05-30
-- ============================================================


--
-- TOC entry 1530 (class 1255 OID 3363399)
-- Name: usp_refresh_item_modifiergroup_modifier_mapping(text); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE OR REPLACE PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(IN p_organizationid text)
    LANGUAGE plpgsql
    AS $BODY$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Delete only rows for this organization on every run
    -- --------------------------------------------------------
    WITH org_loc_lookup AS (
        SELECT organizationid, organizationname, locationid, locationname
        FROM dim.organizationlocation
        WHERE CASE WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = p_organizationid
          AND organizationtype = 0
    )
    DELETE FROM ml.item_modifiergroup_modifier_mapping
    WHERE locationid IN (SELECT locationid FROM org_loc_lookup);

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH org_loc_ctlg AS (
        SELECT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname,
               c.catalogid, c.catalogname
        FROM (
            SELECT * FROM dim.organizationlocation
            WHERE CASE WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = p_organizationid
              AND organizationtype = 0 
        ) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        SELECT
            m.*,
            olc.organizationid,
            olc.organizationname,
            olc.locationid,
            olc.locationname,
            --olc.catalogid,
            olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
    )
    INSERT INTO ml.item_modifiergroup_modifier_mapping
    SELECT
        m.organizationid,
        m.organizationname,
        m.locationid,
        m.locationname,
        m.catalogid,
        m.catalogname,
        imgm.menuitemid,
        mi.menuitemname,
        mi.item_class_type,
        imgm.modifiergroupid,
        mg.modifiergroupname,
        imgm.modifierid,
        m.modifiername,
        m.classification            AS modifier_class_type,
        imgm.is_default             AS is_modifier_default,
        mg.min_selection            AS min_quantity,
        mg.max_selection            AS max_quantity,
        m.allow_quantity_increment,
        m.increment_step,
        m.modifier_default_quantity,
        m.is_invisible              AS is_modifier_invisible,
        m.calories,
        m.price,
        m.is_modifier_active,
        m.is_modifier_deleted,
        m.modifier_created_on,
        m.modifier_modified_on,
        NOW()::TIMESTAMP            AS sysinserttime
    FROM dim.item_modifier_group_modifier_mapping AS imgm
    INNER JOIN org_loc_ctlg_modifiers AS m
        ON  imgm.catalogid  = m.catalogid
        AND imgm.modifierid = m.modifierid
    INNER JOIN dim.menuitem AS mi
        ON imgm.catalogid = mi.catalogid
        AND imgm.menuitemid = mi.menuitemid
    INNER JOIN dim.modifier_group AS mg
        ON  imgm.catalogid       = mg.catalogid
        AND imgm.modifiergroupid = mg.modifiergroupid;

END;
$BODY$;


ALTER PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(IN p_organizationid text) OWNER TO citus;

--
-- TOC entry 981 (class 1255 OID 3044530)
-- Name: usp_refresh_menu_entities(); Type: PROCEDURE; Schema: ml; Owner: citus
--
-- CALL ml.usp_refresh_menu_entities();
CREATE OR REPLACE PROCEDURE ml.usp_refresh_menu_entities()
    LANGUAGE plpgsql
    AS $BODY$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Truncate on every run
    -- --------------------------------------------------------
    TRUNCATE TABLE ml.menu_entities;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH category_hierarchy AS (
        SELECT
            mi.*,
            ol.organizationid,
            ol.organizationname,
            ctgh.locationid,
            ol.locationname,
            ctgh.categoryid,
            ctgh.categoryname
        FROM dim.menuitem AS mi
        LEFT JOIN dim.category_hierarchy AS ctgh
            ON mi.menuitemid = ctgh.menuitemid
        INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
            ON ctgh.locationid = ol.locationid
    )
    INSERT INTO ml.menu_entities
    SELECT DISTINCT
        mi.organizationid,
        mi.organizationname,
        mi.locationid,
        mi.locationname,
        mi.categoryid,
        mi.categoryname,
        mi.menuitemid,
        mi.menuitemname,
        mi.catalogid,
        mi.itemunitprice,
        mi.price_changed_on,
        mi.item_class_type,
        mi.entitytype,
        mi.calories,
        mi.protein,
        mi.sugar,
        mi.fat,
        mi.is_alcoholic,
        mi.is_vegetarian_item,
        mi.is_vegan_item,
        mi.has_allergen,
        mi.is_active,
        mi.is_deleted,
        mi.gms_created_on,
        mi.gms_modified_on,
        NOW()::TIMESTAMP     AS sysinserttime,
        mi.average_rating,
        mi.rating_count
    FROM category_hierarchy AS mi;

END;
$BODY$;


ALTER PROCEDURE ml.usp_refresh_menu_entities() OWNER TO citus;

--
-- TOC entry 1537 (class 1255 OID 3364123)
-- Name: usp_refresh_modifier_impressions(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE OR REPLACE PROCEDURE ml.usp_refresh_modifier_impressions(IN p_refresh_mode integer DEFAULT 1)
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
        TRUNCATE TABLE ml.modifier_impressions;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.modifier_impressions;

        DELETE FROM ml.modifier_impressions
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH org_loc_ctlg AS (
        -- Resolve each org+location to its corresponding catalog.
        -- Type=0 filters to standard locations only.
        SELECT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname,
               c.catalogid, c.catalogname
        FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        -- Enrich each modifier with its catalog and location context
        -- so it can be joined to impression events by locationid + modifierid.
        SELECT
            m.*,
            olc.organizationid,
            olc.organizationname,
            olc.locationid,
            olc.locationname,
            --olc.catalogid,
            olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
    )
    INSERT INTO ml.modifier_impressions
    SELECT
        olcm.organizationid,
        olcm.organizationname,
        olcm.locationname,
        olcm.locationid,
        olcm.catalogid,
        olcm.catalogname,
        m.businessdate,
        m.orderdatelocal,
        EXTRACT(YEAR FROM m.businessdate)::INTEGER  AS yyyy,
        EXTRACT(WEEK FROM m.businessdate)::INTEGER  AS ww,
        m.transactionheaderid,
        m.ordersessionid,
        m.orderid,
        m.menuitemid,
        mi.menuitemname,
        mi.item_class_type,
        m.modifierid,
        olcm.modifiername,
        olcm.classification                         AS modifier_class_type,
        m.parent_modifier_id,
        m.nesting_depth,
        olcm.price                                  AS modifierprice,
        m.selection_type,
        m.position,
        m.score,
        m.strategy,
        m.context,
        m.selected,
        m.pre_deselected,
        m.confirmed_removed,
        m.pre_selected,
        m.frequentcustomerid,
        NOW()::TIMESTAMP                            AS sysinserttime  -- audit timestamp for when the row was loaded
    FROM fact.modifier_impressions AS m
    INNER JOIN org_loc_ctlg_modifiers AS olcm
        ON  m.locationid = olcm.locationid
        AND m.modifierid = olcm.modifierid
    INNER JOIN dim.menuitem AS mi
        ON mi.menuitemid = m.menuitemid
    WHERE LOWER(m.transactionheaderid) LIKE 'ordevt-%'  -- exclude non-order events (e.g. kiosk idle sessions)
      AND (
            p_refresh_mode = 0                          -- full load: no date restriction
            OR m.businessdate >= v_max_businessdate     -- incremental: from max date onward
      );

END;
$BODY$;


ALTER PROCEDURE ml.usp_refresh_modifier_impressions(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 572 (class 1255 OID 3364121)
-- Name: usp_refresh_modifier_interactions(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE OR REPLACE PROCEDURE ml.usp_refresh_modifier_interactions(IN p_refresh_mode integer DEFAULT 1)
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
        TRUNCATE TABLE ml.modifier_interactions;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.modifier_interactions;

        DELETE FROM ml.modifier_interactions
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH trxn_items AS (
        -- Pull the relevant transaction item fields from ml.transactions.
        -- This is the date-filtered entry point for the entire query.
        SELECT
            tr.organizationid,
            tr.organizationname,
            tr.locationid,
            tr.locationname,
            tr.businessdate,
            tr.orderdatelocal,
            tr.transactionheaderid,
            tr.ordersessionid,
            tr.orderid,
            tr.orderitemid,
            tr.menuitemid,
            tr.itemquantity,
            tr.itemunitprice,
            tr.frequentcustomerid
        FROM ml.transactions AS tr
        WHERE (
                p_refresh_mode = 0                       -- full load: no date restriction
                OR tr.businessdate >= v_max_businessdate -- incremental: from max date onward
        )
    ),
    org_loc_ctlg AS (
        -- Resolve each org+location to its corresponding catalog.
        -- Type=0 filters to standard locations only.
        SELECT ol.organizationid, ol.locationid, c.catalogid, c.catalogname
        FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        -- Enrich each modifier with its catalog and location context
        -- so it can be joined to transaction items by locationid + modifierid.
        SELECT
            m.*,
            olc.organizationid,
            olc.locationid,
            olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
    )
    INSERT INTO ml.modifier_interactions
    SELECT
        ti.organizationid,
        ti.organizationname,
        ti.locationname,
        ti.locationid,
        olcm.catalogid,
        olcm.catalogname,
        ti.businessdate,
        ti.orderdatelocal,
        EXTRACT(YEAR FROM ti.businessdate)::INTEGER             AS yyyy,
        EXTRACT(WEEK FROM ti.businessdate)::INTEGER             AS ww,
        mt.transactionheaderid,
        ti.ordersessionid,
        ti.orderid,
        mt.itemid                                               AS orderitemid,
        ti.menuitemid,
        mi.menuitemname,
        ti.itemquantity,
        ti.itemunitprice,
        mi.item_class_type,
        mt.modifiergroupid,
        mg.modifiergroupname,
        mt.modifierid,
        mt.modifiername,
        NULL::TEXT                                              AS parent_modifier_id,   -- reserved for future nested modifier support
        NULL::INTEGER                                           AS nesting_depth,        -- reserved for future nested modifier support
        mt.modifierquantity,
        mt.modifierprice,
        mt.freequantity,
        mgm.is_default                                          AS is_modifier_default,
        mg.min_selection                                        AS min_quantity,
        mg.max_selection                                        AS max_quantity,
        -- Classify whether the modifier was optional, required, or a default selection
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 THEN 'optional'
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 THEN 'required'
            WHEN mgm.is_default = TRUE                                                       THEN 'default'
        END                                                     AS selection_type,
        -- Classify the action the customer took on this modifier
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 AND mt.modifierquantity >= 1 THEN 'added'    -- customer explicitly added an optional modifier
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'selected'  -- customer selected a required modifier
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'kept'      -- customer left the default modifier in place
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity = 0  THEN 'removed'   -- customer actively removed a default modifier
        END                                                     AS action,
        NULL::TEXT                                              AS session_recorded_at,  -- reserved for future session tracking
        ti.frequentcustomerid,
        olcm.modifier_default_quantity,
        olcm.classification                                     AS modifier_class_type,
        NOW()::TIMESTAMP                                        AS sysinserttime         -- audit timestamp for when the row was loaded
    FROM fact.itemmodifier AS mt
    INNER JOIN trxn_items AS ti
        ON  mt.transactionheaderid = ti.transactionheaderid
        AND mt.itemid              = ti.orderitemid
    INNER JOIN org_loc_ctlg_modifiers AS olcm
        ON  ti.locationid = olcm.locationid
        AND mt.modifierid = olcm.modifierid
    INNER JOIN dim.menuitem AS mi
        ON mi.menuitemid = ti.menuitemid
    LEFT JOIN dim.modifier_group_mapping AS mgm
        ON  mgm.modifiergroupid = mt.modifiergroupid
        AND mgm.modifierid      = mt.modifierid
    LEFT JOIN dim.modifier_group AS mg
        ON mg.modifiergroupid = mt.modifiergroupid;

END;
$BODY$;


ALTER PROCEDURE ml.usp_refresh_modifier_interactions(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 1435 (class 1255 OID 3363400)
-- Name: usp_refresh_transactions(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE OR REPLACE PROCEDURE ml.usp_refresh_transactions(IN p_refresh_mode integer DEFAULT 1)
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
        TRUNCATE TABLE ml.transactions;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.transactions;

        DELETE FROM ml.transactions
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM fact.transactionheader AS th
        WHERE LOWER(th.orderstatus) = 'order-placed'   -- exclude cancelled, pending, etc.
          AND (
                p_refresh_mode = 0                     -- full load: no date restriction
                OR th.businessdate >= v_max_businessdate  -- incremental: from max date onward
          )
    )
    INSERT INTO ml.transactions
    SELECT DISTINCT
        th.frequentcustomerid,
        ol.organizationid,
        ol.organizationname,
        th.locationid,
        ol.locationname,
        th.kioskid,
        th.transactionheaderid,
        th.ordersessionid,
        th.orderid,
        ti.itemid                                                    AS orderitemid,
        ti.dimmenuitemid                                             AS menuitemid,
        ti.itemname,
        COALESCE(ti.upselllevel, '')                                 AS upselllevel,  -- default to empty string if no upsell
        mi.item_class_type,
        ti.itemquantity,
        ti.categoryid,
        ctg.categoryname,
        ti.itemunitprice,
        th.paymentstatus,
        th.numberofitems,
        th.numberofpayments,
        th.ordertotal,
        th.ordersubtotal,
        th.ordertip,
        th.ordertax,
        ot.ordertypelabel,
        th.orderdatelocal,
        th.businessdate,
        wh.humidity                                                  AS weatherhumidity,     -- weather at time of order
        wh.condition                                                 AS weathercondition,
        wh.temperature_c                                             AS temperatureincelcius,
        EXTRACT(YEAR  FROM th.businessdate)::INTEGER                 AS yyyy,
        EXTRACT(MONTH FROM th.businessdate)::INTEGER                 AS mm,
        EXTRACT(DAY   FROM th.businessdate)::INTEGER                 AS dd,
        EXTRACT(HOUR  FROM th.orderdatelocal)::INTEGER               AS hh,
        EXTRACT(WEEK  FROM th.businessdate)::INTEGER                 AS ww,
        NOW()::TIMESTAMP                                             AS sysinserttime  -- audit timestamp for when the row was loaded
    FROM cte AS th
    INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON th.locationid = ol.locationid                            -- type=0 filters to standard locations only
    INNER JOIN fact.transactionitem AS ti
        ON th.transactionheaderid = ti.transactionheaderid          -- expand header to one row per item
    LEFT JOIN ml.weather AS wh
        ON  th.locationid          = wh.locationid
        AND th.businessdate        = wh.weatherdate
        AND EXTRACT(HOUR FROM th.orderdatelocal)::INTEGER = wh.hh  -- match weather to the exact hour of the order
    LEFT JOIN dim.itemcategory AS ctg
        ON ti.categoryid = ctg.id
    LEFT JOIN dim.menuitem AS mi
        ON ti.menuitemid = mi.id
    LEFT JOIN dim.ordertype AS ot
        ON th.ordertype = ot.id;

END;
$BODY$;


ALTER PROCEDURE ml.usp_refresh_transactions(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 558 (class 1255 OID 3363402)
-- Name: usp_refresh_upsell_analysis(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE OR REPLACE PROCEDURE ml.usp_refresh_upsell_analysis(IN p_refresh_mode integer DEFAULT 1)
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


ALTER PROCEDURE ml.usp_refresh_upsell_analysis(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 653 (class 1255 OID 3363392)
-- Name: usp_refresh_weather(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE OR REPLACE PROCEDURE ml.usp_refresh_weather(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $BODY$
DECLARE
    v_max_weatherdate DATE;
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.weather;
    ELSE
        -- Incremental: capture the current max date, delete it,
        -- then reload from that date forward (picks up any new data too)
        SELECT MAX(weatherdate) INTO v_max_weatherdate FROM ml.weather;

        DELETE FROM ml.weather
        WHERE weatherdate >= v_max_weatherdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM dim.vw_weatherhourlydata
        WHERE (
            p_refresh_mode = 0
            OR weatherdate >= v_max_weatherdate
        )
    )
    INSERT INTO ml.weather
    SELECT
        ol.organizationid,
        ol.organizationname,
        cte.locationid,
        ol.locationname,
        cte.weatherdate,
        EXTRACT(YEAR  FROM cte.weatherdate)::INTEGER AS yyyy,
        EXTRACT(MONTH FROM cte.weatherdate)::INTEGER AS mm,
        EXTRACT(DAY   FROM cte.weatherdate)::INTEGER AS dd,
        EXTRACT(WEEK  FROM cte.weatherdate)::INTEGER AS ww,
        cte.hh,
        cte.humidity,
        cte.condition,
        cte.temperature_c,
        cte.is_hot,
        cte.is_calm,
        cte.is_cold,
        cte.is_cool,
        cte.is_mild,
        cte.is_warm,
        cte.rain_mm,
        cte.is_sunny,
        cte.is_windy,
        cte.is_cloudy,
        cte.is_daytime,
        cte.is_raining,
        cte.is_snowing,
        cte.is_very_hot,
        cte.is_freezing,
        cte.is_overcast,
        cte.snowfall_mm,
        cte.temp_bucket,
        cte.wind_bucket,
        cte.feels_colder,
        cte.feels_hotter,
        cte.food_weather,
        cte.is_heavy_rain,
        cte.is_light_rain,
        cte.is_nighttime,
        cte.is_very_windy,
        cte.pressure_hpa,
        cte.weather_code,
        cte.wind_gust_kmh,
        cte.comfort_score,
        cte.drink_weather,
        cte.wind_speed_kmh,
        cte.comfort_bucket,
        cte.humidity_bucket,
        cte.condition_bucket,
        cte.is_precipitating,
        cte.precipitation_mm,
        cte.visibility_meters,
        cte.cloud_cover_percent,
        cte.is_unseasonably_hot,
        cte.is_unseasonably_cold,
        cte.outdoor_dining_score,
        cte.wind_direction_degrees,
        cte.precipitation_probability,
        cte.apparent_temperature_celsius,
        NOW()::TIMESTAMP                             AS sysinserttime
    FROM cte
    LEFT JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON cte.locationid = ol.locationid;

END;
$BODY$;


ALTER PROCEDURE ml.usp_refresh_weather(IN p_refresh_mode integer) OWNER TO citus;

CREATE OR REPLACE PROCEDURE ml.usp_refresh_item_modifier_matching(
    p_organizationid  TEXT,
    p_tsr_threshold   NUMERIC  DEFAULT 70,
    p_trgm_prefilter  NUMERIC  DEFAULT 0.40
)
LANGUAGE plpgsql AS $BODY$
DECLARE
    v_mod_count   INT;
    v_item_count  INT;
    v_match_count INT;
BEGIN

    -- ----------------------------------------------------------------
    -- Purge existing matches for this org before rebuild
    -- ----------------------------------------------------------------
    DELETE FROM ml.modifier_item_match
    WHERE CASE
        WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid
        ELSE locationid
    END = p_organizationid;

    -- ----------------------------------------------------------------
    -- Step 1+2: modifier_id_to_name + _filter_modifiers()
    -- Collapse to one row per modifierid — locationid/catalogid use MIN()
    -- since the same modifier can appear at multiple locations within an org
    -- modifiergroup_occurrence_count = COUNT(DISTINCT modifiergroupid) across all
    -- locations — this is the list-length signal from the Python pipeline
    -- ----------------------------------------------------------------
    CREATE TEMP TABLE tmp_filtered_modifiers ON COMMIT DROP AS
    SELECT
        organizationid,
        --organizationname,
        locationid,
        --locationname,
        catalogid,
        --catalogname,
        modifierid,
        modifiername,
        norm_ts_name,
        MIN(price)                                  AS modifier_price,
        BOOL_OR(is_modifier_default)                AS modifier_is_default,
        MIN(calories)                               AS modifier_calories,
        MAX(max_quantity)                           AS modifier_max_quantity,
        MIN(min_quantity)                           AS modifier_min_quantity,
        COUNT(DISTINCT modifiergroupid)             AS modifiergroup_occurrence_count
    FROM ml.item_modifiergroup_modifier_mapping
    WHERE locationid IN 
        (SELECT locationid FROM dim.organizationlocation 
         WHERE CASE WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = p_organizationid
           AND organizationtype = 0)
      AND is_modifier_deleted = FALSE
      AND is_modifier_active  = TRUE
      AND lower(modifiergroupname) NOT LIKE '%level%'
      AND lower(modifiergroupname) NOT LIKE '%change%'
      AND lower(modifiergroupname) NOT LIKE '%sauce choice%'
      AND lower(modifiername)      NOT LIKE 'no %'
    GROUP BY
        organizationid, --organizationname,
        locationid, --locationname,
        catalogid, --catalogname,
        modifierid, modifiername, norm_ts_name;
/*
    GET DIAGNOSTICS v_mod_count = ROW_COUNT;
    RAISE NOTICE 'ItemModifierMatching[%]: % modifiers after group/keyword filtering',
                 p_organizationid, v_mod_count;
*/
    -- ----------------------------------------------------------------
    -- Step 3: master_items
    -- Deduplicate by menuitemid — same item can appear at multiple locations
    -- ----------------------------------------------------------------
    CREATE TEMP TABLE tmp_master_items ON COMMIT DROP AS
    SELECT DISTINCT ON (menuitemid)
        catalogid,
        menuitemid,
        menuitemname,
        norm_ts_name,
        itemunitprice,
        entitytype,
        calories,
        categoryid,
        categoryname,
        is_alcoholic,
        is_vegetarian_item,
        is_vegan_item,
        has_allergen,
        average_rating,
        rating_count
    FROM ml.menu_entities
    WHERE locationid IN 
        (SELECT locationid FROM dim.organizationlocation 
         WHERE CASE WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = p_organizationid
           AND organizationtype = 0)
      AND is_deleted    = FALSE
      AND menuitemname  IS NOT NULL
    ORDER BY menuitemid, sysinserttime DESC;

    /*GET DIAGNOSTICS v_item_count = ROW_COUNT;
    RAISE NOTICE 'ItemModifierMatching[%]: % master items from menu_entities',
                 p_organizationid, v_item_count;*/

    CREATE INDEX ON tmp_master_items USING GIN (norm_ts_name gin_trgm_ops);
    ANALYZE tmp_master_items;
    ANALYZE tmp_filtered_modifiers;

    -- ----------------------------------------------------------------
    -- Step 4: collect ALL matches above threshold
    -- No DISTINCT ON here — one modifier can match multiple items,
    -- all of which go into the matched_menuitems JSONB array
    -- ----------------------------------------------------------------
    CREATE TEMP TABLE tmp_matches ON COMMIT DROP AS
    SELECT
        fm.organizationid,
        --fm.organizationname,
        fm.locationid,
        --fm.locationname,
        fm.catalogid,
        --fm.catalogname,
        fm.modifierid,
        fm.modifiername,
        fm.modifiergroup_occurrence_count,
        fm.modifier_price,
        fm.modifier_is_default,
        fm.modifier_calories,
        fm.modifier_max_quantity,
        fm.modifier_min_quantity,
        mi.menuitemid                                               AS matched_menuitemid,
        mi.menuitemname                                             AS matched_menuitemname,
        dim.token_sort_ratio(fm.modifiername, mi.menuitemname)      AS tsr_score,
        CASE
            WHEN dim.ml_normalize(mi.menuitemname)
                    LIKE '%' || dim.ml_normalize(fm.modifiername) || '%'
             AND dim.ml_normalize(fm.modifiername)
                 <> dim.ml_normalize(mi.menuitemname)
                THEN 'item_extends_modifier'
            WHEN dim.ml_normalize(fm.modifiername)  ~ '\y(small|regular|large)\y'
             AND dim.ml_normalize(mi.menuitemname)  !~ '\y(small|regular|large)\y'
                THEN 'modifier_adds_size'
            WHEN dim.ml_normalize(fm.modifiername)
                    ~ '\y(vanilla|chocolate|strawberry|blueberry|cucumber|hibiscus|lavender)\y'
             AND dim.ml_normalize(mi.menuitemname)
                    !~ '\y(vanilla|chocolate|strawberry|blueberry|cucumber|hibiscus|lavender)\y'
                THEN 'modifier_adds_flavor'
            ELSE 'near_equal'
        END                                                         AS match_direction,
        mi.itemunitprice,
        mi.entitytype,
        mi.calories,
        mi.categoryid,
        mi.categoryname,
        mi.is_alcoholic,
        mi.is_vegetarian_item,
        mi.is_vegan_item,
        mi.has_allergen,
        mi.average_rating,
        mi.rating_count,
        (   dim.ml_normalize(fm.modifiername)  ~ '\y(small|regular|large)\y'
        AND dim.ml_normalize(mi.menuitemname) !~ '\y(small|regular|large)\y'
        )                                                           AS is_size_variant
    FROM tmp_filtered_modifiers fm
    CROSS JOIN LATERAL (
        SELECT
            menuitemid, menuitemname, itemunitprice, entitytype, calories,
            categoryid, categoryname, is_alcoholic, is_vegetarian_item,
            is_vegan_item, has_allergen, average_rating, rating_count
        FROM   tmp_master_items
        WHERE  catalogid = fm.catalogid 
          AND  norm_ts_name % fm.norm_ts_name
          AND  similarity(norm_ts_name, fm.norm_ts_name) >= p_trgm_prefilter
        ORDER  BY similarity(norm_ts_name, fm.norm_ts_name) DESC
        LIMIT  10
    ) mi
    WHERE dim.token_sort_ratio(fm.modifiername, mi.menuitemname) >= p_tsr_threshold;

    -- ----------------------------------------------------------------
    -- Step 5: aggregate into one row per modifier and upsert
    -- Flat columns carry the best match (highest tsr_score)
    -- matched_menuitems JSONB carries all matches sorted best-first
    -- ----------------------------------------------------------------
    INSERT INTO ml.modifier_item_match (
        organizationid,
        --organizationname,
        locationid,
        --locationname,
        catalogid,
        --catalogname,
        modifierid,
        modifiername,
        matched_menuitemid,
        matched_menuitemname,
        tsr_score,
        match_confidence_tier,
        match_direction,
        matched_menuitems,
        modifiergroup_occurrence_count,
        modifier_price,
        price_delta,
        item_price,
        item_entity_type,
        item_calories,
        item_categoryid,
        item_categoryname,
        item_is_alcoholic,
        item_is_vegetarian,
        item_is_vegan,
        item_has_allergen,
        item_average_rating,
        item_rating_count,
        modifier_is_default,
        modifier_calories,
        modifier_max_quantity,
        modifier_min_quantity,
        is_size_variant,
        matched_at
    )
    SELECT
        organizationid,
        --organizationname,
        locationid,
        --locationname,
        catalogid,
        --catalogname,
        modifierid,
        modifiername,
        -- best match flat columns
        (array_agg(matched_menuitemid   ORDER BY tsr_score DESC))[1] AS matched_menuitemid,
        (array_agg(matched_menuitemname ORDER BY tsr_score DESC))[1] AS matched_menuitemname,
        MAX(tsr_score)                                               AS tsr_score,
        CASE
            WHEN MAX(tsr_score) >= 90 THEN 'high'
            WHEN MAX(tsr_score) >= 75 THEN 'medium'
            ELSE 'review'
        END                                                          AS match_confidence_tier,
        (array_agg(match_direction      ORDER BY tsr_score DESC))[1],
        -- all matches as JSONB array, sorted best-first
        jsonb_agg(
            jsonb_build_object(
                'menuitemid',       matched_menuitemid,
                'menuitemname',     matched_menuitemname,
                'tsr_score',        tsr_score,
                'match_direction',  match_direction,
                'item_price',       itemunitprice
            )
            ORDER BY tsr_score DESC
        )                                                            AS matched_menuitems,
        MAX(modifiergroup_occurrence_count)                          AS modifiergroup_occurrence_count,
        MIN(modifier_price)                                          AS modifier_price,
        -- item features from best match
        (array_agg(itemunitprice        ORDER BY tsr_score DESC))[1] - MIN(modifier_price) as price_delta,
        (array_agg(itemunitprice        ORDER BY tsr_score DESC))[1] AS item_price,
        (array_agg(entitytype           ORDER BY tsr_score DESC))[1] AS item_entity_type,
        (array_agg(calories             ORDER BY tsr_score DESC))[1] AS item_calories,
        (array_agg(categoryid           ORDER BY tsr_score DESC))[1] AS item_categoryid,
        (array_agg(categoryname         ORDER BY tsr_score DESC))[1] AS item_categoryname,
        BOOL_OR(is_alcoholic)       AS item_is_alcoholic,
        BOOL_OR(is_vegetarian_item) AS item_is_vegetarian,
        BOOL_OR(is_vegan_item)      AS item_is_vegan,
        BOOL_OR(has_allergen)       AS item_has_allergen,
        MAX(average_rating)         AS item_average_rating,
        MAX(rating_count)           AS item_rating_count,
        -- modifier features
        BOOL_OR(modifier_is_default) AS modifier_is_default,
        MIN(modifier_calories)      AS modifier_calories,
        MAX(modifier_max_quantity)  AS modifier_max_quantity,
        MIN(modifier_min_quantity)  AS modifier_min_quantity,
        BOOL_OR(is_size_variant)    AS is_size_variant,
        NOW()
    FROM tmp_matches
    GROUP BY
        organizationid, --organizationname,
        locationid, --locationname,
        catalogid, --catalogname,
        modifierid, modifiername
    ON CONFLICT (organizationid, locationid, catalogid, modifierid) DO UPDATE SET
        --organizationname       = EXCLUDED.organizationname,
        locationid             = EXCLUDED.locationid,
        --locationname           = EXCLUDED.locationname,
        catalogid              = EXCLUDED.catalogid,
        --catalogname            = EXCLUDED.catalogname,
        modifiername           = EXCLUDED.modifiername,
        matched_menuitemid     = EXCLUDED.matched_menuitemid,
        matched_menuitemname   = EXCLUDED.matched_menuitemname,
        tsr_score              = EXCLUDED.tsr_score,
        match_confidence_tier  = EXCLUDED.match_confidence_tier,
        match_direction        = EXCLUDED.match_direction,
        matched_menuitems      = EXCLUDED.matched_menuitems,
modifiergroup_occurrence_count = EXCLUDED.modifiergroup_occurrence_count,
        modifier_price         = EXCLUDED.modifier_price,
        price_delta            = EXCLUDED.price_delta,
        item_price             = EXCLUDED.item_price,
        item_entity_type       = EXCLUDED.item_entity_type,
        item_calories          = EXCLUDED.item_calories,
        item_categoryid        = EXCLUDED.item_categoryid,
        item_categoryname      = EXCLUDED.item_categoryname,
        item_is_alcoholic      = EXCLUDED.item_is_alcoholic,
        item_is_vegetarian     = EXCLUDED.item_is_vegetarian,
        item_is_vegan          = EXCLUDED.item_is_vegan,
        item_has_allergen      = EXCLUDED.item_has_allergen,
        item_average_rating    = EXCLUDED.item_average_rating,
        item_rating_count      = EXCLUDED.item_rating_count,
        modifier_is_default    = EXCLUDED.modifier_is_default,
        modifier_calories      = EXCLUDED.modifier_calories,
        modifier_max_quantity  = EXCLUDED.modifier_max_quantity,
        modifier_min_quantity  = EXCLUDED.modifier_min_quantity,
        is_size_variant        = EXCLUDED.is_size_variant,
        matched_at             = EXCLUDED.matched_at;
        -- match_confidence_tier and price_delta are GENERATED — updated automatically

    /*GET DIAGNOSTICS v_match_count = ROW_COUNT;
    RAISE NOTICE 'ItemModifierMatching[%]: % modifiers matched (threshold=%s%%)',
                 p_organizationid, v_match_count, p_tsr_threshold;*/

    DROP TABLE IF EXISTS tmp_matches;
    DROP TABLE IF EXISTS tmp_filtered_modifiers;
    DROP TABLE IF EXISTS tmp_master_items;

END;
$BODY$;

ALTER PROCEDURE ml.usp_refresh_item_modifier_matching(TEXT, NUMERIC, NUMERIC)
    OWNER TO citus;
