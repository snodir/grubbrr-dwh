select  deviceid
,locationid
,telemetryname
--,telemetrytime
,to_char(telemetrytime, 'YYYYMMDDHH24') as dateid
,max(telemetryvalue) as MAXVALUE
from gsh.devicetelemetry
where 1=1
and telemetryname IN ('cpu','memory') 
and deviceid != 'no-serial'
and telemetryvalue not like '%null%'
and to_char(telemetrytime, 'YYYYMMDDHH24') between '2024121200' and '2024121223'
group by locationid, deviceid, telemetryname, to_char(telemetrytime, 'YYYYMMDDHH24')
order by locationid, deviceid, telemetryname
LIMIT 1000

select T2.* 
from (
    select T.deviceid,
        T.locationid,
        T.telemetryname,
        T.telemetryvalue,
        T.telemetrytime,
        T.dateid,
        row_number() over(partition by T.deviceid, T.locationid, T.telemetryname, T.dateid order by T.telemetryvalue desc, T.telemetrytime desc) as rownum
    from (
        select deviceid,
            locationid,
            telemetryname,
            telemetryvalue,
            telemetrytime,
            to_char(telemetrytime, 'YYYYMMDDHH24') as dateid
        from gsh.devicetelemetry 
        where 1=1
        and telemetryname IN ('cpu','memory') 
        and deviceid != 'no-serial'
        and telemetryvalue not like '%null%'
        ) as T
) as T2
where T2.rownum = 1

select count(*) -- telemetryname
from gsh.devicetelemetry 
where telemetryvalue not like '%null%' --N/NN 568,874/1,090,902


select deviceid,
       locationid,
       telemetryname,
       max(telemetryvalue) as maxvalue,
       --telemetrytime,
       to_char(telemetrytime, 'YYYYMMDDHH24') as dateid
from gsh.devicetelemetry 
where 1=1
and telemetryname IN ('cpu','memory') 
and deviceid != 'no-serial'
and telemetryvalue not like '%null%'
group by deviceid,
       locationid,
       telemetryname,
       to_char(telemetrytime, 'YYYYMMDDHH24')

select deviceid,
            locationid,
            telemetryname,
            telemetryvalue,
            telemetrytime,
            to_char(telemetrytime, 'YYYYMMDDHH24') as dateid
            --max(telemetryvalue) over(partition by deviceid, locationid, telemetryname, to_char(telemetrytime, 'YYYYMMDDHH24')) as maxvalue
            /*cast(EXTRACT(YEAR from telemetrytime) as TEXT),
            cast(EXTRACT(MONTH from telemetrytime) as text),
            cast(EXTRACT(DAY from telemetrytime) as text),
            cast(EXTRACT(HOUR from telemetrytime) as text)*/
        from gsh.devicetelemetry 
        where 1=1
        and telemetryname IN ('cpu','memory') 
        and deviceid != 'no-serial'
        and telemetryvalue not like '%null%'

select case when '0.38432854544005557' > '0.3785941854136008' then 'correct' end


select T2.* 
from (
    select T.deviceid,
        T.locationid,
        T.telemetryvalue as cpuvalue,
        T.telemetrytime as cputimestamp,
        T.dateid,
        row_number() over(partition by T.deviceid, T.locationid, T.dateid order by T.telemetryvalue desc, T.telemetrytime desc) as rownum
    from (
        select deviceid,
            locationid,
            telemetryvalue,
            telemetrytime,
            to_char(telemetrytime, 'YYYYMMDDHH24') as dateid
        from gsh.devicetelemetry 
        where 1=1
        and telemetryname = 'cpu'
        and deviceid != 'no-serial'
        and telemetryvalue not like '%null%'
        ) as T
) as T2
where T2.rownum = 1

select T2.* 
from (
    select T.deviceid,
        T.locationid,
        T.telemetryvalue as memoryvalue,
        T.telemetrytime as memorytimestamp,
        T.dateid,
        row_number() over(partition by T.deviceid, T.locationid, T.dateid order by T.telemetryvalue desc, T.telemetrytime desc) as rownum
    from (
        select deviceid,
            locationid,
            telemetryvalue,
            telemetrytime,
            to_char(telemetrytime, 'YYYYMMDDHH24') as dateid
        from gsh.devicetelemetry 
        where 1=1
        and telemetryname = 'memory' --4,470
        and deviceid != 'no-serial'
        and telemetryvalue not like '%null%'
        ) as T
) as T2
where T2.rownum = 1


select max(telemetryvalue)
from gsh.devicetelemetry 
where locationid = 'loc-72cd6945-5b7c-4fa5-942b-ee3ec8f21881'
and to_char(telemetrytime, 'YYYYMMDDHH24') = '2025011515'
and deviceid = 'e26edd9f-841a-4a0f-9fd6-be17b480597e'
and telemetryname = 'cpu'

select max(telemetryvalue)
from gsh.devicetelemetry 
where locationid = 'loc-72cd6945-5b7c-4fa5-942b-ee3ec8f21881'
and to_char(telemetrytime, 'YYYYMMDDHH24') = '2025011515'
and deviceid = 'e26edd9f-841a-4a0f-9fd6-be17b480597e'
and telemetryname = 'memory'

select * from gsh.devicetelemetry
where telemetryname in ('cpu','memory')
limit 1000

select distinct to_char('2025-01-31T11:44:10.325', 'YYYYMMDDHH24') as dateid 

select count(*)
from gsh.devicehealth as dh
inner join (select * from gsh.device where state  not in ('New','Deleted')) as d
on d.deviceid = dh.deviceid
where dh.deviceid != 'no-serial' --and cast(healthdatatime as date) between '2025-02-07' and '2025-02-10'
order by healthdatatime desc
limit 10

select * 
from gsh.device
--where deviceid != 'no-serial'
order by enrollmentdate desc
LIMIT 10
