SELECT *-- wt.watermarktablename, wt.watermarkcolumn, wt.watermarkvalue, wt.ticks, wt.ts
FROM fact.watermarktable as wt;

SELECT * FROM fact.pipelinerunstatus;
/*
1769755658
1769669258
*/

SELECT wt_nge.ts as maxts_nge, wt_gem.ts as maxts_gem
FROM (SELECT * FROM fact.watermarktable WHERE watermarktablename = 'fact.occasionsurveydetail' AND source = 'nge') as wt_nge
INNER JOIN (SELECT * FROM fact.watermarktable WHERE watermarktablename = 'fact.occasionsurveydetail' AND source = 'gem') as wt_gem
        ON wt_nge.watermarktablename = wt_gem.watermarktablename;

UPDATE fact.watermarktable
SET ts = tr.maxts
FROM (SELECT coalesce(max(syscosmosts), 1720000300) as maxts, 'fact.occasionsurveydetail' as tablename FROM fact.occasionsurveydetail WHERE sourceid = 1) as tr 
WHERE watermarktable.watermarktablename = tr.tablename
  AND watermarktable.source = 'nge';

UPDATE fact.watermarktable
SET ts = tr.maxts
FROM (SELECT coalesce(max(syscosmosts), 1720000300) as maxts, 'fact.occasionsurveydetail' as tablename FROM fact.occasionsurveydetail WHERE sourceid = 2) as tr 
WHERE watermarktable.watermarktablename = tr.tablename
  AND watermarktable.source = 'gem';

/*UPDATE fact.watermarktable
SET watermarkvalue = tr.maxts
FROM (SELECT max(lasteventtime) as maxts, 'fact.devicestate' as tablename FROM fact.devicestate) as tr 
WHERE watermarktable.watermarktablename = tr.tablename
  AND watermarktable.source = 'gsh';*/

/*UPDATE fact.watermarktable
SET ts = NULL,
    watermarkvalue = '2026-01-30 19:00:50.711' :: TIMESTAMP
WHERE watermarktablename = 'fact.devicetelemetry'*/

UPDATE fact.watermarktable
SET source = CASE WHEN watermarktablename in ('fact.transactionrefunds','fact.transactionheader','fact.recommendations') THEN 'nge'
                  WHEN watermarktablename in ('dim.abtests','fact.deviceevent','fact.userbehaviour') THEN 'gem'
                  WHEN watermarktablename in ('fact.devicetelemetry','fact.devicestate') THEN 'gsh' END

--1753100010 = 2025-07-21 12:13:30+00
SELECT CURRENT_TIMESTAMP, to_timestamp(1763675405) as sample_ts,
       now(), 
       to_timestamp(1769669258) as now2207, 
       to_timestamp(1753300000) as nge1,
       to_timestamp(1750000010) as nge2,
       to_timestamp(1500000010) as nge3,
       1753063217 - 1752837578 as diff,
       case WHEN '2025-07-21 10:05:54.018869' > '2025-07-21 10:05:54.018868' then 'datetime_is_ok' end is_ts_good,
       EXTRACT(EPOCH FROM TIMESTAMP '2024-05-01 00:00:00')::BIGINT;

--de-1753912232
--ub-1753924223
--th-1753765118

SELECT * fact.watermarktable --WHERE watermarktablename = 'fact.occasionsurveydetail'

ALTER TABLE fact.watermarktable
--ADD source CHARACTER VARYING(10)
ADD CONSTRAINT watermarktablename_pk PRIMARY key (watermarktablename, source)--,
add ticks BIGINT,
add ts BIGINT
select MAX(busdate) as busdate, max(syscosmosts) as syscosmosts from fact.userbehaviour

--DELETE FROM fact.watermarktable 
WHERE watermarktablename = 'fact.ordertiming'

INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn, source, ts/*, ticks*/)
VALUES('fact.transactionheader', 'syscosmosts', 'gem', 1720000300)
      ('fact.ordertiming', 'syscosmosts', 'gem', 1720000300)
      ('fact.occasionsurveydetail', 'syscosmosts', 'nge', 1720000300),
      ('fact.occasionsurveydetail', 'syscosmosts', 'gem', 1720000300)
      ('dim.abtests', 'syscosmosts')
      ('fact.recommendations', 'syscosmosts')
      ('fact.transactionrefunds', 'syscosmosts'),
      ('fact.transactionheader', 'syscosmosts'/*, cast('2025-07-10T09:49:50.168+00:00' as TIMESTAMP), 638877378214374076*/),
      ('fact.deviceevent', 'syscosmosts')

--userbehaviour	busdate	2025-07-17 11:09:22	NULL	1750000010

SELECT *
from fact.deviceevent
where eventinstant :: TIMESTAMP > now()

UPDATE fact.watermarktable
SET ts = tr.maxts
FROM (SELECT max(syscosmosts) as maxts, 'fact.transactionrefunds' as tablename FROM fact.transactionrefunds) as tr 
WHERE watermarktable.watermarktablename = tr.tablename;

SELECT 1 as rn;

SELECT *
from fact.userbehaviour
where busdate is not null
ORDER BY busdate desc 
LIMIT 100

SELECT *
from fact.transactionitem as ti
where ti.transactionheaderid like 'ordevt-%' 
and ti.transactionheaderid in (select transactionheaderid from fact.transactionheader as th where th.orderstatus = 'order-placed' and businessdate = '2025-07-17')
ORDER BY orderdateutc desc 
LIMIT 100

SELECT ub.locationid, ub.ordersessionidentifier, ub.eventtype, count(*)
from fact.userbehaviour as ub
GROUP BY ub.locationid, ub.ordersessionidentifier, ub.eventtype
HAVING COUNT(*) > 1

SELECT max(th.syscosmosts) as maxts, 'transactionheader' as watermarktablename
FROM fact.transactionheader as th

CREATE TABLE IF NOT EXISTS fact.watermarktable
(
    watermarktablename text COLLATE pg_catalog."default" NOT NULL,
    watermarkcolumn text COLLATE pg_catalog."default",
    watermarkvalue timestamp without time zone,
    ticks bigint,
    ts bigint,
    CONSTRAINT watermarktablename_pk PRIMARY KEY (watermarktablename)
)

TABLESPACE pg_default;

ALTER TABLE fact.watermarktable
    OWNER to citus;

ALTER TABLE fact.watermarktable
ADD source CHARACTER VARYING(10)


ALTER TABLE fact.userbehaviour
add syscosmosts BIGINT,
add eventinstant text


ALTER TABLE fact.transactionheader
add syscosmosts BIGINT

ALTER TABLE fact.transactionitem
add syscosmosts BIGINT

update fact.watermarktable
set watermarktablename = concat('fact.', watermarktablename)
where watermarktablename not like 'fact.%'

update fact.watermarktable
set ts = 1500000010
where watermarktablename = 'fact.transactionrefunds'-- in ('fact.transactionheader','fact.userbehaviour','fact.deviceevent')
and 

SELECT * from fact.transactionrefunds

UPDATE fact.transactionrefunds
set syscosmosts = 1500000010
where orderdateutc = (SELECT min() from fact.transactionrefunds)

UPDATE fact.watermarktable
SET ts = tr.maxts
FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.transactionrefunds' as tablename FROM fact.transactionrefunds) as tr 
WHERE watermarktable.watermarktablename = tr.tablename;