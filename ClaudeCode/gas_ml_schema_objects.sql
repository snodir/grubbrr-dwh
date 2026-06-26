--
-- PostgreSQL database dump
--
/*
\restrict u3VILtlmaBKJ3BRXwuzUWlPXCA5WZEreieiZrmcnEGPglxyt1ZhmLhfR72CT536

-- Dumped from database version 16.9 (Ubuntu 16.9-1.pgdg20.04+1)
-- Dumped by pg_dump version 18.4

-- Started on 2026-06-25 15:26:21

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 76 (class 2615 OID 3042094)
-- Name: ml; Type: SCHEMA; Schema: -; Owner: citus
--
*/
CREATE SCHEMA ml;


ALTER SCHEMA ml OWNER TO citus;

--
-- TOC entry 1563 (class 1255 OID 3363399)
-- Name: usp_refresh_item_modifiergroup_modifier_mapping(text); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(IN p_organizationid text)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(IN p_organizationid text) OWNER TO citus;

--
-- TOC entry 1008 (class 1255 OID 3044530)
-- Name: usp_refresh_menu_entities(); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_menu_entities()
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE ml.usp_refresh_menu_entities() OWNER TO citus;

--
-- TOC entry 1570 (class 1255 OID 3364123)
-- Name: usp_refresh_modifier_impressions(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_modifier_impressions(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE ml.usp_refresh_modifier_impressions(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 597 (class 1255 OID 3364121)
-- Name: usp_refresh_modifier_interactions(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_modifier_interactions(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE ml.usp_refresh_modifier_interactions(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 1468 (class 1255 OID 3363400)
-- Name: usp_refresh_transactions(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_transactions(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE ml.usp_refresh_transactions(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 582 (class 1255 OID 3363402)
-- Name: usp_refresh_upsell_analysis(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_upsell_analysis(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE ml.usp_refresh_upsell_analysis(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 678 (class 1255 OID 3363392)
-- Name: usp_refresh_weather(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_weather(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
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
$$;


ALTER PROCEDURE ml.usp_refresh_weather(IN p_refresh_mode integer) OWNER TO citus;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 480 (class 1259 OID 3048276)
-- Name: item_modifiergroup_modifier_mapping; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.item_modifiergroup_modifier_mapping (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    catalogid text,
    catalogname text,
    menuitemid text,
    menuitemname text,
    item_class_type integer,
    modifiergroupid text,
    modifiergroupname text,
    modifierid text,
    modifiername text,
    modifier_class_type integer,
    is_modifier_default boolean,
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    modifier_default_quantity integer,
    is_modifier_invisible boolean,
    calories text,
    price numeric(12,4),
    is_modifier_active boolean,
    is_modifier_deleted boolean,
    modifier_created_on timestamp without time zone,
    modifier_modified_on timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.item_modifiergroup_modifier_mapping OWNER TO citus;

--
-- TOC entry 476 (class 1259 OID 3044534)
-- Name: menu_entities; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.menu_entities (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    categoryid text,
    categoryname text,
    menuitemid text,
    menuitemname text,
    catalogid text,
    itemunitprice numeric(12,3),
    price_changed_on timestamp without time zone,
    item_class_type integer,
    entitytype text,
    calories text,
    protein numeric(9,2),
    sugar numeric(9,2),
    fat numeric(9,2),
    is_alcoholic boolean,
    is_vegetarian_item boolean,
    is_vegan_item boolean,
    has_allergen boolean,
    is_active boolean,
    is_deleted boolean,
    gms_created_on timestamp without time zone,
    gms_modified_on timestamp without time zone,
    sysinserttime timestamp without time zone,
    average_rating numeric(3,2),
    rating_count integer
);


ALTER TABLE ml.menu_entities OWNER TO citus;

--
-- TOC entry 479 (class 1259 OID 3048261)
-- Name: modifier_impressions; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.modifier_impressions (
    organizationid text,
    organizationname text,
    locationname text,
    locationid text,
    catalogid text,
    catalogname text,
    businessdate date,
    orderdatelocal timestamp without time zone,
    yyyy integer,
    ww integer,
    transactionheaderid text,
    ordersessionid text,
    orderid text,
    menuitemid text,
    menuitemname text,
    item_class_type integer,
    modifierid text,
    modifiername text,
    modifier_class_type integer,
    parent_modifier_id text,
    nesting_depth integer,
    modifierprice numeric(12,3),
    selection_type text,
    "position" integer,
    score numeric(10,4),
    strategy text,
    context text,
    selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    pre_selected boolean,
    frequentcustomerid text,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.modifier_impressions OWNER TO citus;

--
-- TOC entry 478 (class 1259 OID 3048228)
-- Name: modifier_interactions; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.modifier_interactions (
    organizationid text,
    organizationname text,
    locationname text,
    locationid text,
    catalogid text,
    catalogname text,
    businessdate date,
    orderdatelocal timestamp without time zone,
    yyyy integer,
    ww integer,
    transactionheaderid text,
    ordersessionid text,
    orderid text,
    orderitemid text,
    menuitemid text,
    menuitemname text,
    itemquantity integer,
    itemunitprice numeric(12,3),
    item_class_type integer,
    modifiergroupid text,
    modifiergroupname text,
    modifierid text,
    modifiername text,
    parent_modifier_id text,
    nesting_depth integer,
    modifierquantity integer,
    modifierprice numeric(12,3),
    freequantity integer,
    is_modifier_default boolean,
    min_quantity integer,
    max_quantity integer,
    selection_type text,
    action text,
    session_recorded_at text,
    frequentcustomerid text,
    modifier_default_quantity integer,
    modifier_class_type integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.modifier_interactions OWNER TO citus;

--
-- TOC entry 477 (class 1259 OID 3044562)
-- Name: transactions; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.transactions (
    frequentcustomerid text,
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    kioskid text,
    transactionheaderid text,
    ordersessionid text,
    orderid text,
    orderitemid text,
    menuitemid text,
    itemname text,
    upselllevel text,
    item_class_type integer,
    itemquantity integer,
    categoryid text,
    categoryname text,
    itemunitprice numeric(12,3),
    paymentstatus text,
    numberofitems integer,
    numberofpayments integer,
    ordertotal numeric(14,4),
    ordersubtotal numeric(14,4),
    ordertip numeric(14,4),
    ordertax numeric(14,4),
    ordertypelabel text,
    orderdatelocal timestamp without time zone,
    businessdate date,
    weatherhumidity numeric(7,2),
    weathercondition text,
    temperatureincelcius numeric(7,2),
    yyyy integer,
    mm integer,
    dd integer,
    hh integer,
    ww integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.transactions OWNER TO citus;

--
-- TOC entry 474 (class 1259 OID 3042193)
-- Name: upsell_analysis; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.upsell_analysis (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    frequentcustomerid text,
    transactionheaderid text,
    recommendationid text,
    offereditem text,
    selecteditem text,
    item_class_type integer,
    upselltype text,
    quantity integer,
    businessdate date,
    orderdatelocal timestamp without time zone,
    yyyy integer,
    mm integer,
    dd integer,
    hh integer,
    ww integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.upsell_analysis OWNER TO citus;

--
-- TOC entry 475 (class 1259 OID 3042222)
-- Name: weather; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.weather (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    weatherdate date,
    yyyy integer,
    mm integer,
    dd integer,
    ww integer,
    hh integer,
    humidity integer,
    condition text,
    temperature_c numeric(8,2),
    is_hot boolean,
    is_calm boolean,
    is_cold boolean,
    is_cool boolean,
    is_mild boolean,
    is_warm boolean,
    rain_mm numeric(8,2),
    is_sunny boolean,
    is_windy boolean,
    is_cloudy boolean,
    is_daytime boolean,
    is_raining boolean,
    is_snowing boolean,
    is_very_hot boolean,
    is_freezing boolean,
    is_overcast boolean,
    snowfall_mm numeric(8,2),
    temp_bucket text,
    wind_bucket text,
    feels_colder boolean,
    feels_hotter boolean,
    food_weather text,
    is_heavy_rain boolean,
    is_light_rain boolean,
    is_nighttime boolean,
    is_very_windy boolean,
    pressure_hpa numeric(8,2),
    weather_code integer,
    wind_gust_kmh numeric(8,2),
    comfort_score integer,
    drink_weather text,
    wind_speed_kmh numeric(8,2),
    comfort_bucket text,
    humidity_bucket text,
    condition_bucket text,
    is_precipitating boolean,
    precipitation_mm numeric(8,2),
    visibility_meters numeric(8,2),
    cloud_cover_percent numeric(8,2),
    is_unseasonably_hot boolean,
    is_unseasonably_cold boolean,
    outdoor_dining_score integer,
    wind_direction_degrees integer,
    precipitation_probability numeric(8,2),
    apparent_temperature_celsius numeric(8,2),
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.weather OWNER TO citus;

--
-- TOC entry 5999 (class 1259 OID 3050933)
-- Name: ix_ml_imm_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_imm_locationid ON ml.item_modifiergroup_modifier_mapping USING btree (locationid);


--
-- TOC entry 5994 (class 1259 OID 3044539)
-- Name: ix_ml_me_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_me_locationid ON ml.menu_entities USING btree (locationid);


--
-- TOC entry 5995 (class 1259 OID 3044540)
-- Name: ix_ml_me_menuitemid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_me_menuitemid ON ml.menu_entities USING btree (menuitemid);


--
-- TOC entry 5997 (class 1259 OID 3050934)
-- Name: ix_ml_mi_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_mi_locid_yyyy_ww ON ml.modifier_interactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 5998 (class 1259 OID 3050935)
-- Name: ix_ml_mimp_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_mimp_locid_yyyy_ww ON ml.modifier_impressions USING btree (locationid, yyyy, ww);


--
-- TOC entry 5996 (class 1259 OID 3050806)
-- Name: ix_ml_trx_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_trx_locid_yyyy_ww ON ml.transactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 5987 (class 1259 OID 3042200)
-- Name: ix_ml_ua_businessdate; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_ua_businessdate ON ml.upsell_analysis USING btree (businessdate);


--
-- TOC entry 5988 (class 1259 OID 3042199)
-- Name: ix_ml_ua_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_ua_locid_yyyy_ww ON ml.upsell_analysis USING btree (locationid, yyyy, ww);


--
-- TOC entry 5989 (class 1259 OID 3042198)
-- Name: ix_ml_ua_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_ua_yyyy_ww ON ml.upsell_analysis USING btree (yyyy, ww);


--
-- TOC entry 5990 (class 1259 OID 3044148)
-- Name: ix_ml_wth_locationid_weatherdate_hh; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_wth_locationid_weatherdate_hh ON ml.weather USING btree (locationid, weatherdate, hh);


--
-- TOC entry 5991 (class 1259 OID 3042228)
-- Name: ix_ml_wth_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_wth_locid_yyyy_ww ON ml.weather USING btree (locationid, yyyy, ww);


--
-- TOC entry 5992 (class 1259 OID 3042229)
-- Name: ix_ml_wth_weatherdate; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_wth_weatherdate ON ml.weather USING btree (weatherdate);


--
-- TOC entry 5993 (class 1259 OID 3042227)
-- Name: ix_ml_wth_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_wth_yyyy_ww ON ml.weather USING btree (yyyy, ww);


--
-- TOC entry 6174 (class 0 OID 0)
-- Dependencies: 478
-- Name: TABLE modifier_interactions; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.modifier_interactions TO varshil;


-- Completed on 2026-06-25 15:26:35

--
-- PostgreSQL database dump complete
--

--\unrestrict u3VILtlmaBKJ3BRXwuzUWlPXCA5WZEreieiZrmcnEGPglxyt1ZhmLhfR72CT536

