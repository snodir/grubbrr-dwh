SELECT *
FROM dim.datedim as dt
WHERE dt.yearval = 2026
  AND dt.monthval = 5;

CREATE SCHEMA IF NOT EXISTS etl;
--30 days * 24 hours * 2 (events/orders)
SELECT *--, dateid, layer, entity, partition_path, partition_date, partition_year, partition_month, partition_day, partition_hour
FROM etl.bronze_partition_registry
WHERE entity = 'orders'
  --AND dateid >= TO_CHAR(NOW() - INTERVAL '6 hours', 'YYYYMMDDHH24') :: BIGINT  --processed partitions will be skipped anyway by status = 'pending'
  --AND dateid <= TO_CHAR(NOW() - INTERVAL '1 hours', 'YYYYMMDDHH24') :: BIGINT  --1 hour of deduction because of late-arriving files
SELECT LENGTH('orders/raw/2026/05/15/23')


SELECT 
    dateid, 
    layer, 
    entity, 
    partition_path,
    SUBSTRING(partition_path, 1, 21) as partition_date_path,
    partition_date :: TEXT AS partition_date,
    partition_year, 
    partition_month, 
    partition_day, 
    partition_hour,
    SUBSTRING(partition_path, 23, 2) as partition_hh
FROM etl.bronze_partition_registry
WHERE entity = 'orders'
  AND partition_date IN ('2026-05-18' :: DATE, '2026-05-19' :: DATE)
  --AND partition_hour IN (6, 7, 8, 9, 10, 11, 12, 16)
  --AND dateid >= TO_CHAR(NOW() - INTERVAL '54 hours', 'YYYYMMDDHH24') :: BIGINT  --processed partitions will be skipped anyway by status = 'pending'
  --AND dateid <= TO_CHAR(NOW() - INTERVAL '46 hours', 'YYYYMMDDHH24') :: BIGINT  --1 hour of deduction because of late-arriving files
  AND status = 'pending'
ORDER BY dateid;


SELECT 
    dateid, 
    layer, 
    entity, 
    partition_path,
    SUBSTRING(partition_path, 1, 21) as partition_date_path,
    partition_date :: TEXT AS partition_date,
    partition_year, 
    partition_month, 
    partition_day, 
    partition_hour,
    SUBSTRING(partition_path, 23, 2) as partition_hh
FROM etl.bronze_partition_registry
WHERE entity = 'orders'
  AND dateid >= (SELECT coalesce(max(dateid), 2026060108)
                FROM etl.bronze_partition_registry 
                WHERE entity = 'orders' 
                  AND status IN ('completed','not found'))
  AND dateid <= TO_CHAR((NOW() - INTERVAL '1 hour'), 'YYYYMMDDHH24') :: INTEGER
  AND status = 'pending'
ORDER BY dateid
LIMIT 50;

SELECT *
FROM etl.bronze_partition_registry
WHERE entity = 'orders'
  AND dateid > (SELECT coalesce(max(dateid), 2026060100)
                 FROM etl.bronze_partition_registry 
                 WHERE entity = 'orders' 
                   AND status IN ('completed','not found'))
  AND dateid <= TO_CHAR((NOW() - INTERVAL '1 hour'), 'YYYYMMDDHH24') :: INTEGER
  AND status = 'pending'
ORDER BY dateid
LIMIT 24;



UPDATE etl.bronze_partition_registry
SET started_at = NOW() :: TIMESTAMP,
    adf_pipeline_run_id = '@{pipeline().RunId}' :: TEXT
WHERE entity = 'events'
  AND dateid = @{item().dateid};
  
SELECT '@{item().partition_path}' AS partition_path;


DROP TABLE IF EXISTS etl.bronze_partition_registry;
CREATE TABLE IF NOT EXISTS etl.bronze_partition_registry (
    dateid              INTEGER,
    layer               TEXT COLLATE pg_catalog."default",
    entity              TEXT COLLATE pg_catalog."default",
    partition_path      TEXT COLLATE pg_catalog."default",
    partition_date      DATE,
    partition_year      SMALLINT,
    partition_month     SMALLINT,
    partition_day       SMALLINT,
    partition_hour      SMALLINT,
    status              TEXT COLLATE pg_catalog."default" DEFAULT 'pending',
    file_count          INTEGER,
    started_at          TIMESTAMP,
    completed_at        TIMESTAMP,
    adf_pipeline_run_id TEXT COLLATE pg_catalog."default",
    error_message       TEXT COLLATE pg_catalog."default",
    sysinserttime       TIMESTAMP,
    sysupdatetime       TIMESTAMP,
    PRIMARY KEY (entity, dateid)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS etl.bronze_partition_registry
    OWNER TO citus;

--DELETE FROM etl.bronze_partition_registry WHERE entity = 'events'

INSERT INTO etl.bronze_partition_registry
SELECT 
    dt.dateid,
    'bronze' AS layer,
    'events' AS entity,
    CONCAT('events/raw/', 
           SUBSTRING(dt.dateid :: TEXT, 1, 4), '/', 
           SUBSTRING(dt.dateid :: TEXT, 5, 2), '/',
           SUBSTRING(dt.dateid :: TEXT, 7, 2), '/',
           SUBSTRING(dt.dateid :: TEXT, 9, 2)
    ) AS partition_path,
    dt.dayval,
    dt.yearval as partition_year,
    dt.monthval as partition_month,
    SUBSTRING(dt.dateid :: TEXT, 7, 2) :: INTEGER as partition_day,
    SUBSTRING(dt.dateid :: TEXT, 9, 2) :: INTEGER as partition_hour,
    'pending' as status,
    NULL :: INTEGER AS file_count,
    NULL :: TIMESTAMP AS started_at,
    NULL :: TIMESTAMP AS completed_at,
    NULL :: TEXT AS adf_pipeline_run_id,
    NULL :: TEXT AS error_message,
    NOW():: TIMESTAMP as sysinserttime,
    NULL :: TIMESTAMP as sysupdatetime
FROM dim.datedim as dt
WHERE dt.yearval = 2026
  AND dt.monthval = 6

UNION ALL

SELECT 
    dt.dateid,
    'bronze' AS layer,
    'orders' AS entity,
    CONCAT('orders/raw/', 
           SUBSTRING(dt.dateid :: TEXT, 1, 4), '/', 
           SUBSTRING(dt.dateid :: TEXT, 5, 2), '/',
           SUBSTRING(dt.dateid :: TEXT, 7, 2), '/',
           SUBSTRING(dt.dateid :: TEXT, 9, 2)
    ) AS partition_path,
    dt.dayval,
    dt.yearval as partition_year,
    dt.monthval as partition_month,
    SUBSTRING(dt.dateid :: TEXT, 7, 2) :: INTEGER as partition_day,
    SUBSTRING(dt.dateid :: TEXT, 9, 2) :: INTEGER as partition_hour,
    'pending' as status,
    NULL :: INTEGER AS file_count,
    NULL :: TIMESTAMP AS started_at,
    NULL :: TIMESTAMP AS completed_at,
    NULL :: TEXT AS adf_pipeline_run_id,
    NULL :: TEXT AS error_message,
    NOW():: TIMESTAMP as sysinserttime,
    NULL :: TIMESTAMP as sysupdatetime
FROM dim.datedim as dt
WHERE dt.yearval = 2026
  AND dt.monthval = 6;

--SELECT '01'::INTEGER;
