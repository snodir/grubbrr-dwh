CREATE TABLE IF NOT EXISTS fact.devicetelemetry
(
    deviceid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    cpuvalue integer,
    memoryvalue integer,
    telemetrytimemodified timestamp without time zone,
    telemetrytime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE fact.devicetelemetry
    OWNER to citus;

-- Index: fact.idx_devicetelemetry
CREATE INDEX IF NOT EXISTS idx_devicetelemetry
    ON fact.devicetelemetry USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, deviceid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: fact.idx_devicetelemetry_dateid
CREATE INDEX IF NOT EXISTS idx_devicetelemetry_dateid
    ON fact.devicetelemetry USING btree
    (dateid ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: fact.idx_devicetelemetry_locationid
CREATE INDEX IF NOT EXISTS idx_devicetelemetry_locationid
    ON fact.devicetelemetry USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

select * from fact.devicestate order by  limit 1000
select distinct deviceid from fact.devicestate

select * from gsh.devicetelemetry 
where 1=1 
--and locationid = 'loc-7b149de8-32db-46be-883e-fc7db625be7b'
and telemetryvalue <> 'null' and telemetryname in ('cpu','memory') --and telemetryvalue  '0'
order by telemetrytime desc-- telemetryvalue DESC-- dateid desc, deviceid 
limit 1000

select * from fact.devicetelemetry 
where 1=1 
--and locationid = 'loc-7b149de8-32db-46be-883e-fc7db625be7b'
order by dateid desc, deviceid 
limit 1000

select * from fact.deviceevent order by eventinstant desc limit 100
select * from fact.devicestate where lasteventtime is not null order by lasteventtime desc limit 30;

select * 
from fact.devicetelemetry 
where cputimestamp is not null  
order by cputimestamp desc 
limit 1000 --4,407

SELECT DISTINCT SUBSTRING(deviceid, 1, 4)
FROM fact.devicetelemetry as dt;

SELECT * FROM fact.devicetelemetry as dt WHERE dt.deviceid like 'ksk-%' and sysupdatetime is not null ORDER BY sysinserttime DESC LIMIT 100 -- ORDER BY sysinserttime DESC LIMIT 10

SELECT * FROM fact.devicetelemetry as dt WHERE dt.deviceid like 'kds-%'  and sysinserttime is not null ORDER BY sysinserttime DESC LIMIT 100-- ORDER BY sysinserttime DESC LIMIT 10

SELECT * FROM fact.devicetelemetry as dt WHERE (dt.deviceid not like 'ksk-%' AND dt.deviceid not like 'kds-%')  and sysinserttime is not null ORDER BY sysinserttime DESC LIMIT 100-- ORDER BY sysinserttime DESC LIMIT 10



select * from fact.devicetelemetry order by cputimestamp desc limit 10 --4,407

select distinct deviceid, locationid from fact.devicetelemetry 

select * from fact.devicetelemetry --4,407
select count(*) from fact.devicetelemetry --14,393,278
select max(cputimestamp), max(memorytimestamp) from fact.devicetelemetry --4,407

select case when max(cputimestamp) > max(memorytimestamp) 
            then max(memorytimestamp) else max(cputimestamp) end telemetrytime  
from fact.devicetelemetry

select * from fact.watermarktable


select dateid, max(cpuvalue)
from fact.devicetelemetry
group by dateid

select * from fact.devicetelemetrybackup where cpuvalue is not null order by cpuvalue desc limit 1000 --2,677,197
