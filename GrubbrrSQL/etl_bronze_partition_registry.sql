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

SELECT 
    dateid, 
    layer, 
    entity, 
    partition_path,
    SUBSTRING(partition_path, 1, 21) as partition_date_path,
    partition_date, 
    partition_year, 
    partition_month, 
    partition_day, 
    partition_hour
FROM etl.bronze_partition_registry
WHERE entity = 'orders'
  AND dateid >= TO_CHAR(NOW() - INTERVAL '32 hours', 'YYYYMMDDHH24') :: BIGINT  --processed partitions will be skipped anyway by status = 'pending'
  AND dateid <= TO_CHAR(NOW() - INTERVAL '24 hours', 'YYYYMMDDHH24') :: BIGINT  --1 hour of deduction because of late-arriving files
  AND status = 'pending'
ORDER BY dateid;


SELECT 
    dateid, 
    layer, 
    entity, 
    partition_path,
    SUBSTRING(partition_path, 1, 21) as partition_date_path,
    partition_date, 
    partition_year, 
    partition_month, 
    partition_day, 
    partition_hour
FROM etl.bronze_partition_registry
WHERE entity = 'orders'
  AND dateid >= (SELECT max(dateid) 
                 FROM etl.bronze_partition_registry 
                 WHERE entity = 'orders' 
                   AND status = 'completed')
  AND status = 'pending'
ORDER BY dateid
LIMIT 6

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
  AND dt.monthval = 5

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
  AND dt.monthval = 5;

--SELECT '01'::INTEGER;
