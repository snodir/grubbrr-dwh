-- ============================================================
-- TABLE 6: ml.weather
-- Granularity : one row per (location, date, hour)
-- Refresh     : daily (date column = weatherdate)
-- ============================================================

-- ✅ Also correct: positional (no name needed, just pass values in order)
--CALL ml.usp_refresh_weather(p_businessdate => CURRENT_DATE - 1, p_refresh_mode => 0);

--SELECT * FROM ml.weather LIMIT 1000;

CREATE TABLE IF NOT EXISTS ml.weather (
    organizationid               TEXT COLLATE pg_catalog."default",
    organizationname             TEXT COLLATE pg_catalog."default",
    locationid                   TEXT COLLATE pg_catalog."default",
    locationname                 TEXT COLLATE pg_catalog."default",
    weatherdate                  DATE,
    yyyy                         INTEGER,
    mm                           INTEGER,
    dd                           INTEGER,
    ww                           INTEGER,
    hh                           INTEGER,
    humidity                     INTEGER,
    condition                    TEXT COLLATE pg_catalog."default",
    temperature_c                NUMERIC(8,2),
    is_hot                       BOOLEAN,
    is_calm                      BOOLEAN,
    is_cold                      BOOLEAN,
    is_cool                      BOOLEAN,
    is_mild                      BOOLEAN,
    is_warm                      BOOLEAN,
    rain_mm                      NUMERIC(8,2),
    is_sunny                     BOOLEAN,
    is_windy                     BOOLEAN,
    is_cloudy                    BOOLEAN,
    is_daytime                   BOOLEAN,
    is_raining                   BOOLEAN,
    is_snowing                   BOOLEAN,
    is_very_hot                  BOOLEAN,
    is_freezing                  BOOLEAN,
    is_overcast                  BOOLEAN,
    snowfall_mm                  NUMERIC(8,2),
    temp_bucket                  TEXT COLLATE pg_catalog."default",
    wind_bucket                  TEXT COLLATE pg_catalog."default",
    feels_colder                 BOOLEAN,
    feels_hotter                 BOOLEAN,
    food_weather                 TEXT COLLATE pg_catalog."default",
    is_heavy_rain                BOOLEAN,
    is_light_rain                BOOLEAN,
    is_nighttime                 BOOLEAN,
    is_very_windy                BOOLEAN,
    pressure_hpa                 NUMERIC(8,2),
    weather_code                 INTEGER,
    wind_gust_kmh                NUMERIC(8,2),
    comfort_score                INTEGER,
    drink_weather                TEXT COLLATE pg_catalog."default",
    wind_speed_kmh               NUMERIC(8,2),
    comfort_bucket               TEXT COLLATE pg_catalog."default",
    humidity_bucket              TEXT COLLATE pg_catalog."default",
    condition_bucket             TEXT COLLATE pg_catalog."default",
    is_precipitating             BOOLEAN,
    precipitation_mm             NUMERIC(8,2),
    visibility_meters            NUMERIC(8,2),
    cloud_cover_percent          NUMERIC(8,2),
    is_unseasonably_hot          BOOLEAN,
    is_unseasonably_cold         BOOLEAN,
    outdoor_dining_score         INTEGER,
    wind_direction_degrees       INTEGER,
    precipitation_probability    NUMERIC(8,2),
    apparent_temperature_celsius NUMERIC(8,2),
    sysinserttime                TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_ml_wth_yyyy_ww
    ON ml.weather (yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_wth_locid_yyyy_ww
    ON ml.weather (locationid, yyyy, ww);
CREATE INDEX IF NOT EXISTS ix_ml_wth_weatherdate
    ON ml.weather (weatherdate);
CREATE INDEX IF NOT EXISTS ix_ml_wth_locationid_weatherdate_hh
    ON ml.weather (locationid, weatherdate, hh);


-- ============================================================
-- STORED PROCEDURE 6: ml.usp_refresh_weather
-- Refresh type : DAILY DELETE + INSERT (idempotent) / FULL TRUNCATE + INSERT
-- Parameters   : p_businessdate DATE  (default: yesterday)
--                  The specific calendar day to delete and reload.
--                p_refresh_mode INT   (default: 1)
--                  1 = Incremental – delete/insert for p_businessdate only
--                  0 = Full load   – TRUNCATE the table, then insert ALL history
-- Notes        : Date column in output is weatherdate (not businessdate).
-- ============================================================
CREATE OR REPLACE PROCEDURE ml.usp_refresh_weather(
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
        TRUNCATE TABLE ml.weather;
    ELSE
        -- Incremental: idempotent delete for the target day only
        DELETE FROM ml.weather
        WHERE weatherdate = p_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM dim.vw_weatherhourlydata
        WHERE (
                p_refresh_mode = 0
                OR weatherdate = p_businessdate
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
ALTER PROCEDURE ml.usp_refresh_weather(DATE, INT) OWNER TO citus;