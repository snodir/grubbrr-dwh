WITH cte AS
    (SELECT *
     FROM fact.transactionheader AS th
     WHERE th.locationid in
             (SELECT DISTINCT ol.locationid
              FROM dim.organizationlocation AS ol
              WHERE (CASE
                         WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid
                         ELSE ol.locationid
                     END) = '{$pdf_orgid}'
                  AND ol.organizationtype = 0)
         AND th.businessdate >= '2025-01-01'
         AND EXTRACT(WEEK
                     FROM th.businessdate) :: integer = {$pdf_ww})
SELECT DISTINCT ol.organizationid,
                ol.organizationname,
                th.locationid,
                ol.locationname,
                th.kioskid,
                th.transactionheaderid,
                ti.itemid as orderitemid,
                ti.dimmenuitemid as menuitemid,
                ti.itemname,
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
                wh.humidity AS weatherhumidity, wh.condition AS weathercondition, wh.temperature_c AS temperatureincelcius,
                EXTRACT(YEAR FROM th.businessdate) :: integer AS yyyy,
                EXTRACT(MONTH FROM th.businessdate) :: integer AS mm,
                EXTRACT(DAY FROM th.businessdate) :: integer AS dd,
                EXTRACT(HOUR FROM th.orderdatelocal) :: integer AS hh,
                EXTRACT(WEEK FROM th.businessdate) :: integer AS ww
FROM cte as th
LEFT JOIN
    (SELECT *
     FROM dim.organizationlocation
     WHERE organizationtype = 0) as ol on th.locationid = ol.locationid
LEFT JOIN fact.transactionitem as ti on th.transactionheaderid = ti.transactionheaderid
LEFT JOIN dim.vw_weatherhourlydata as wh on th.locationid = wh.locationid and th.businessdate = wh.weatherdate and EXTRACT(HOUR FROM th.orderdatelocal) :: integer = wh.hh
LEFT JOIN dim.itemcategory as ctg on ti.categoryid = ctg.id
LEFT JOIN dim.ordertype as ot on th.ordertype = ot.id

-- View: dim.vw_weatherhourlydata

-- DROP VIEW dim.vw_weatherhourlydata;

SELECT *-- count(*)
FROM dim.vw_weatherhourlydata 
--WHERE locationid = 'loc-8ead49a8-798b-4786-988a-90bbbb4775c7'
ORDER BY weatherdate DESC, hh DESC
LIMIT 1000

CREATE OR REPLACE VIEW dim.vw_weatherhourlydata
 AS
 SELECT w.locationid,
    (w.weatherinfo ->> 'Date'::text)::date AS weatherdate,
    (hour_entry.hour_data ->> 'Hour'::text)::integer AS hh,
    (hour_entry.hour_data ->> 'Humidity'::text)::INTEGER AS humidity,
    hour_entry.hour_data ->> 'Condition'::text AS condition,
    ((hour_entry.hour_data ->> 'TemperatureInCelcius'::text))::numeric(8,2) AS temperature_c,
    (hour_entry.hour_data ->> 'IsHot'::text)::BOOLEAN AS is_hot,
    (hour_entry.hour_data ->> 'IsCalm'::text)::BOOLEAN AS is_calm,
    (hour_entry.hour_data ->> 'IsCold'::text)::BOOLEAN AS is_cold,
    (hour_entry.hour_data ->> 'IsCool'::text)::BOOLEAN AS is_cool,
    (hour_entry.hour_data ->> 'IsMild'::text)::BOOLEAN AS is_mild,
    (hour_entry.hour_data ->> 'IsWarm'::text)::BOOLEAN AS is_warm,
    (hour_entry.hour_data ->> 'RainMm'::text)::numeric(8,2) AS rain_mm,
    (hour_entry.hour_data ->> 'IsSunny'::text)::BOOLEAN AS is_sunny,
    (hour_entry.hour_data ->> 'IsWindy'::text)::BOOLEAN AS is_windy,
    (hour_entry.hour_data ->> 'IsCloudy'::text)::BOOLEAN AS is_cloudy,
    (hour_entry.hour_data ->> 'IsDaytime'::text)::BOOLEAN AS is_daytime,
    (hour_entry.hour_data ->> 'IsRaining'::text)::BOOLEAN AS is_raining,
    (hour_entry.hour_data ->> 'IsSnowing'::text)::BOOLEAN AS is_snowing,
    (hour_entry.hour_data ->> 'IsVeryHot'::text)::BOOLEAN AS is_very_hot,
    (hour_entry.hour_data ->> 'IsFreezing'::text)::BOOLEAN AS is_freezing,
    (hour_entry.hour_data ->> 'IsOvercast'::text)::BOOLEAN AS is_overcast,
    (hour_entry.hour_data ->> 'SnowfallMm'::text)::numeric(8,2) AS snowfall_mm,
    hour_entry.hour_data ->> 'TempBucket'::text AS temp_bucket,
    hour_entry.hour_data ->> 'WindBucket'::text AS wind_bucket,
    (hour_entry.hour_data ->> 'FeelsColder'::text)::BOOLEAN AS feels_colder,
    (hour_entry.hour_data ->> 'FeelsHotter'::text)::BOOLEAN AS feels_hotter,
    hour_entry.hour_data ->> 'FoodWeather'::text AS food_weather,
    (hour_entry.hour_data ->> 'IsHeavyRain'::text)::BOOLEAN AS is_heavy_rain,
    (hour_entry.hour_data ->> 'IsLightRain'::text)::BOOLEAN AS is_light_rain,
    (hour_entry.hour_data ->> 'IsNighttime'::text)::BOOLEAN AS is_nighttime,
    (hour_entry.hour_data ->> 'IsVeryWindy'::text)::BOOLEAN AS is_very_windy,
    (hour_entry.hour_data ->> 'PressureHpa'::text)::numeric(8,2) AS pressure_hpa,
    (hour_entry.hour_data ->> 'WeatherCode'::text)::INTEGER AS weather_code,
    (hour_entry.hour_data ->> 'WindGustKmh'::text)::numeric(8,2) AS wind_gust_kmh,
    (hour_entry.hour_data ->> 'ComfortScore'::text)::INTEGER AS comfort_score,
    hour_entry.hour_data ->> 'DrinkWeather'::text AS drink_weather,
    (hour_entry.hour_data ->> 'WindSpeedKmh'::text)::numeric(8,2) AS wind_speed_kmh,
    hour_entry.hour_data ->> 'ComfortBucket'::text AS comfort_bucket,
    hour_entry.hour_data ->> 'HumidityBucket'::text AS humidity_bucket,
    hour_entry.hour_data ->> 'ConditionBucket'::text AS condition_bucket,
    (hour_entry.hour_data ->> 'IsPrecipitating'::text)::BOOLEAN AS is_precipitating,
    (hour_entry.hour_data ->> 'PrecipitationMm'::text)::numeric(8,2) AS precipitation_mm,
    (hour_entry.hour_data ->> 'VisibilityMeters'::text)::numeric(8,2) AS visibility_meters,
    (hour_entry.hour_data ->> 'CloudCoverPercent'::text)::numeric(8,2) AS cloud_cover_percent,
    (hour_entry.hour_data ->> 'IsUnseasonablyHot'::text)::BOOLEAN AS is_unseasonably_hot,
    (hour_entry.hour_data ->> 'IsUnseasonablyCold'::text)::BOOLEAN AS is_unseasonably_cold,
    (hour_entry.hour_data ->> 'OutdoorDiningScore'::text)::INTEGER AS outdoor_dining_score,
    (hour_entry.hour_data ->> 'WindDirectionDegrees'::text)::INTEGER AS wind_direction_degrees,
    (hour_entry.hour_data ->> 'PrecipitationProbability'::text)::numeric(8,2) AS precipitation_probability,
    (hour_entry.hour_data ->> 'ApparentTemperatureCelsius'::text)::numeric(8,2) AS apparent_temperature_celsius
   FROM dim.weather w
     CROSS JOIN LATERAL jsonb_each(w.weatherinfo -> 'Hours'::text) hour_entry(hour_key, hour_data)
  WHERE w.weatherinfo::text ~~ '{"Date":%'::text;

ALTER TABLE dim.vw_weatherhourlydata
    OWNER TO citus;

SELECT wh.locationid, wh.weatherdate, 
    EXTRACT(YEAR FROM wh.businessdate)::INTEGER AS yyyy,
    EXTRACT(MONTH FROM wh.businessdate)::INTEGER AS mm,
    EXTRACT(DAY FROM wh.businessdate)::INTEGER AS dd,
    EXTRACT(WEEK FROM wh.businessdate)::INTEGER AS ww
FROM dim.vw_weatherhourlydata as wh 
WHERE wh.locationid = ''
  AND EXTRACT(YEAR FROM wh.businessdate)::INTEGER = 2026
  AND EXTRACT(WEEK FROM wh.businessdate)::INTEGER = 1


GRANT ALL ON TABLE dim.vw_weatherhourlydata TO citus;
GRANT SELECT ON TABLE dim.vw_weatherhourlydata TO varshil;

{
  "Date": "2026-01-02T00:00:00",
  "Hours": {
    "0": {
      "Hour": 0,
      "IsHot": false,
      "IsCalm": true,
      "IsCold": false,
      "IsCool": false,
      "IsMild": true,
      "IsWarm": false,
      "RainMm": 0,
      "IsSunny": true,
      "IsWindy": false,
      "Humidity": 69,
      "IsCloudy": false,
      "Condition": "Clear sky",
      "IsDaytime": false,
      "IsRaining": false,
      "IsSnowing": false,
      "IsVeryHot": false,
      "IsFreezing": false,
      "IsOvercast": false,
      "SnowfallMm": 0,
      "TempBucket": "mild",
      "WindBucket": "calm",
      "FeelsColder": false,
      "FeelsHotter": false,
      "FoodWeather": "regular",
      "IsHeavyRain": false,
      "IsLightRain": false,
      "IsNighttime": true,
      "IsVeryWindy": false,
      "PressureHpa": 1005.2,
      "WeatherCode": 0,
      "WindGustKmh": 9.7,
      "ComfortScore": 100,
      "DrinkWeather": "any_drinks",
      "WindSpeedKmh": 3.1,
      "ComfortBucket": "excellent",
      "HumidityBucket": "humid",
      "ConditionBucket": "clear",
      "IsPrecipitating": false,
      "PrecipitationMm": 0,
      "VisibilityMeters": 24140,
      "CloudCoverPercent": 0,
      "IsUnseasonablyHot": true,
      "IsUnseasonablyCold": false,
      "OutdoorDiningScore": 100,
      "TemperatureInCelcius": 22,
      "WindDirectionDegrees": 54,
      "PrecipitationProbability": 0,
      "ApparentTemperatureCelsius": 23.7
    },
    "1": {
      "Hour": 1,
      "IsHot": false,
      "IsCalm": true,
      "IsCold": false,
      "IsCool": false,
      "IsMild": true,
      "IsWarm": false,
      "RainMm": 0,
      "IsSunny": false,
      "IsWindy": false,
      "Humidity": 69,
      "IsCloudy": false,
      "Condition": "Mainly clear",
      "IsDaytime": false,
      "IsRaining": false,
      "IsSnowing": false,
      "IsVeryHot": false,
      "IsFreezing": false,
      "IsOvercast": false,
      "SnowfallMm": 0,
      "TempBucket": "mild",
      "WindBucket": "calm",
      "FeelsColder": false,
      "FeelsHotter": false,
      "FoodWeather": "regular",
      "IsHeavyRain": false,
      "IsLightRain": false,
      "IsNighttime": true,
      "IsVeryWindy": false,
      "PressureHpa": 1005.2,
      "WeatherCode": 1,
      "WindGustKmh": 5.8,
      "ComfortScore": 100,
      "DrinkWeather": "any_drinks",
      "WindSpeedKmh": 1.5,
      "ComfortBucket": "excellent",
      "HumidityBucket": "humid",
      "ConditionBucket": "cloudy",
      "IsPrecipitating": false,
      "PrecipitationMm": 0,
      "VisibilityMeters": 24140,
      "CloudCoverPercent": 11,
      "IsUnseasonablyHot": true,
      "IsUnseasonablyCold": false,
      "OutdoorDiningScore": 100,
      "TemperatureInCelcius": 22,
      "WindDirectionDegrees": 14,
      "PrecipitationProbability": 0,
      "ApparentTemperatureCelsius": 23.9
    }
  },
  "SunsetUtc": "2026-01-02T20:10:00",
  "TempTrend": "",
  "RainComing": false,
  "RainLikely": false,
  "SunriseUtc": "2026-01-02T05:45:00",
  "AvgHumidity": 46.6666666666667,
  "TotalRainMm": 0,
  "RainPeakTime": null,
  "AvgFutureTemp": null,
  "MaxFutureTemp": null,
  "MinFutureTemp": null,
  "OverallBucket": "perfect",
  "YesterdayTemp": null,
  "IsFirstNiceDay": false,
  "AvgTempLastWeek": null,
  "AvgWindSpeedKmh": 8.983333333333333,
  "TotalSnowfallMm": 0,
  "WeatherChanging": false,
  "IsUnusualWeather": false,
  "StormApproaching": false,
  "TempDeltaWeekAvg": null,
  "RainyDaysLastWeek": 0,
  "MaxRainProbability": null,
  "TempDeltaYesterday": null,
  "YesterdayCondition": "",
  "AvgCloudCoverPercent": 20.8333333333333,
  "TotalPrecipitationMm": 0,
  "AvgTemperatureCelsius": 23.204166666666666,
  "IsMuchColderThanUsual": false,
  "IsMuchWarmerThanUsual": false,
  "MaxTemperatureCelsius": 28.9,
  "MinTemperatureCelsius": 18.8,
  "ConditionChangedFromYesterday": false
}

SELECT * FROM dim.vw_weatherhourlydata 
--WHERE temperature_c < -20 
ORDER by weatherdate desc
LIMIT 1000;

SELECT *---COUNT(*)
FROM dim.weather as w
WHERE w.weatherinfo :: text like '{"Date":%'; --11,924
order by 

SELECT extract(HOUR FROM '2025-07-02 01:56:16.123' :: TIMESTAMP) as hh,
      '2025-07-02 00:56:16.123' :: TIMESTAMP