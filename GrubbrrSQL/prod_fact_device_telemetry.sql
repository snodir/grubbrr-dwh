drop table IF EXISTS fact.devicetelemetry;
CREATE TABLE IF NOT EXISTS fact.devicetelemetry
(
    deviceid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    dateid integer,
    cpuvalue integer,
    memoryvalue integer,
    cputimestamp timestamp without time zone,
    memorytimestamp timestamp without time zone
)

TABLESPACE pg_default;


insert into fact.devicetelemetrybackup
select * from fact.devicetelemetry

select distinct deviceid from fact.devicestate
select * from fact.devicetelemetry order by deviceid, locationid, dateid desc limit 1000 --2,677,197
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

select cpu.* 
from (
    select T.deviceid,
        T.locationid,
        T.dateid,
        T.cpuvalue as cpuvalue,
        T.telemetrytime as cputimestamp,
        row_number() over(partition by T.deviceid, T.locationid, T.dateid order by T.cpuvalue desc, T.telemetrytime desc) as rownum
        --'devicetelemetry' as tablename
    from fact.devicetelemetrybackup as T
) as cpu
where cpu.rownum = 1;

select mem.* 
from (
    select T.deviceid,
        T.locationid,
        T.dateid,
        T.memoryvalue as memoryvalue,
        T.telemetrytime as memorytimestamp,
        row_number() over(partition by T.deviceid, T.locationid, T.dateid order by T.memoryvalue desc, T.telemetrytime desc) as rownum
        --'devicetelemetry' as tablename
    from fact.devicetelemetrybackup as T 
) as mem
where mem.rownum = 1;


insert into fact.devicetelemetry
select coalesce(c.deviceid, m.deviceid),
       COALESCE(c.locationid, m.locationid),
       COALESCE(c.dateid, m.dateid),
       c.cpuvalue,
       m.memoryvalue,
       c.cputimestamp,
       m.memorytimestamp
from cputel as c 
full outer JOIN memtel as m 
on c.deviceid = m.deviceid and
   c.locationid = m.locationid and 
   c.dateid = m.dateid

