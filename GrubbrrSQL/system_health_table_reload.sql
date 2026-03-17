select * from dim.menuitem order by id

select * from dim.view
/*SELECT *
FROM c
WHERE c.module = 'kiosk'
AND c.category = 'insight'
and c.instant > '2024-06-23'
and c.data like '%\"view\":\"\"%'
order by c._ts desc
*/

select *-- count(*)-- * 11,295,728
from gsh.devicetelemetry 
where 1=1 -- 
AND locationid = 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc'
AND telemetryname in ('cpu','memory') AND telemetryvalue <> 'null'
AND (deviceid like 'ksk-%' and deviceid like 'kds-%')  -- AGENTS
--AND deviceid like 'ksk-%' --KIOSKS
--AND deviceid like 'kds-%' --KDS
--AND telemetryvalue like '%MB%'
AND telemetrytime is not null
--AND sysupdatetime is not null
ORDER BY telemetrytime DESC-- telemetryvalue DESC, 
LIMIT 1000;

select *-- count(*)-- * 11,295,728
from gsh.devicehealth 
where 1=1 -- 
AND locationid = 'loc-1bd9d30d-4aac-4da1-b65c-bd8ffe4a1101'
AND deviceid = 'ksk-39111721'
ORDER BY healthdatatime DESC
LIMIT 1000; 

--loc-4dddadfb-bfde-40d6-950f-6409fd35bdfe

SELECT *,
       cast((EXTRACT(EPOCH FROM lasteventtime :: TIMESTAMP) - EXTRACT(EPOCH FROM statuschangetime :: TIMESTAMP)) / 60 AS NUMERIC(10,3)) as diff_in_minutes
       --max(cast((EXTRACT(EPOCH FROM lasteventtime :: TIMESTAMP) - EXTRACT(EPOCH FROM statuschangetime :: TIMESTAMP)) / 60 AS NUMERIC(10,3))) as diff_in_minutes
FROM fact.devicestate as ds
WHERE 1=1 --
--and ds.companyid = 'org-c9616111-4382-4704-bf5e-b4ec300a4a92'
--AND ds.locationid = 'loc-1bd9d30d-4aac-4da1-b65c-bd8ffe4a1101'-- 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc'-- 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc'
AND lasteventtime > '2026-02-01' :: TIMESTAMP
ORDER BY ds.lasteventtime DESC
--org-c9616111-4382-4704-bf5e-b4ec300a4a92	Umrschlkr Burger Co	loc-fc13a3c5-167a-45fc-b6b5-6ac401f88ced	Rolla, MO	0	False
LIMIT 1000

/*DELETE --FROM fact.--devicestate as ds
WHERE 1=1 --
--and ds.companyid = 'org-c9616111-4382-4704-bf5e-b4ec300a4a92'
--AND ds.locationid = 'loc-1bd9d30d-4aac-4da1-b65c-bd8ffe4a1101'-- 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc'-- 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc'
AND ds.lasteventtime > '2026-02-01' :: TIMESTAMP;*/


SELECT *,
       case status when 0 then 'Draft' when 1 then 'Onboarding' when 2 then 'Live' when 3 then 'Cancelled' end as location_status
FROM dim.organization
WHERE id = 'loc-1bd9d30d-4aac-4da1-b65c-bd8ffe4a1101'

SELECT DISTINCT o.id, o.name, k.kioskid, k.kioskname, o.organizationtype, o.status,
       CASE o.status 
       WHEN 0 THEN 'Draft' 
       WHEN 1 then 'Onboarding' 
       WHEN 2 then 'Live' 
       WHEN 3 then 'Cancelled' END as location_status
FROM dim.organization as o
INNER JOIN dim.kiosk as k 
        ON o.id = k.locationid
WHERE o.active = True 
  AND o.status = 2
  AND k.istestkiosk = False
  AND o.id = 'loc-1bd9d30d-4aac-4da1-b65c-bd8ffe4a1101'


SELECT * FROM dim.location 
WHERE locationid = 'loc-1bd9d30d-4aac-4da1-b65c-bd8ffe4a1101'

SELECT * FROM dim.kiosk
WHERE locationid = 'loc-1bd9d30d-4aac-4da1-b65c-bd8ffe4a1101'

SELECT *
FROM dim.kioskdetails
WHERE locationid = 'loc-4dddadfb-bfde-40d6-950f-6409fd35bdfe'

SELECT *
FROM dim.vw_grubbrrinstallbase
WHERE location_id = 'loc-1bd9d30d-4aac-4da1-b65c-bd8ffe4a1101'
AND kiosk_id = 'ksk-28893379'

/*
ksk-02601281
ksk-13944079
ksk-53480907
ksk-87911995
ksk-94732799
*/

select *-- count(*)-- max(cpuvalue), max(memoryvalue),
from fact.devicetelemetry 
where 1=1
--AND locationid = 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc'-- 'loc-c7ce66a2-3f71-4d3c-a017-608886b7536d'
--AND (deviceid like not 'ksk-%' and deviceid not like 'kds-%')  -- AGENTS
--AND deviceid like 'ksk-%' --KIOSKS 
AND (cputimestamp > '2026-02-01' :: TIMESTAMP OR memorytimestamp > '2026-02-01' :: TIMESTAMP)
--AND (cpuvalue > 1 or memoryvalue > 1)
--AND deviceid like 'kds-%' --KDS
--AND cputimestamp is not null
--AND sysupdatetime is not null
ORDER BY cputimestamp DESC
LIMIT 1000

select case when max(cputimestamp) > max(memorytimestamp) 
            then max(memorytimestamp) else max(cputimestamp) end telemetrytime  
from fact.devicetelemetry

/*DELETE FROM --fact.devicetelemetry 
where 1=1
--AND locationid = 'loc-4d9abab8-1ac9-4486-90f8-fcfb26d830fc'-- 'loc-c7ce66a2-3f71-4d3c-a017-608886b7536d'
--AND (deviceid like not 'ksk-%' and deviceid not like 'kds-%')  -- AGENTS
--AND deviceid like 'ksk-%' --KIOSKS 
AND (cputimestamp > '2026-02-01' :: TIMESTAMP OR memorytimestamp > '2026-02-01' :: TIMESTAMP)*/


SELECT EXTRACT(EPOCH FROM '2025-01-01 00:01:00.000' :: TIMESTAMP),  
       EXTRACT(EPOCH FROM '2025-01-01 00:00:00.000' :: TIMESTAMP),
       EXTRACT(EPOCH FROM '2025-01-01 00:01:00.000' :: TIMESTAMP) - EXTRACT(EPOCH FROM '2025-01-01 00:00:00.000' :: TIMESTAMP) as diff_in_seconds,
       (EXTRACT(EPOCH FROM '2025-01-01 00:01:00.000' :: TIMESTAMP) - EXTRACT(EPOCH FROM '2025-01-01 00:00:00.000' :: TIMESTAMP)) / 60 as diff_in_minutes,
       cast((EXTRACT(EPOCH FROM '2025-01-01 00:01:00.000' :: TIMESTAMP) - EXTRACT(EPOCH FROM '2025-01-01 00:00:00.000' :: TIMESTAMP)) / 60 AS NUMERIC(10,3)) as diff_in_minutes

ALTER TABLE fact.devicestate
ALTER COLUMN duration TYPE NUMERIC(10,3);


--UPDATE fact.devicestate
--SET duration = cast((EXTRACT(EPOCH FROM lasteventtime :: TIMESTAMP) - EXTRACT(EPOCH FROM statuschangetime :: TIMESTAMP)) / 60 AS NUMERIC(10,3))
--WHERE lasteventtime > statuschangetime

SELECT DISTINCT gb.location_id, gb.kiosk_id, gb.location_status, gb.kiosk_mode
FROM dim.vw_grubbrrinstallbase as gb
WHERE 1=1
AND gb.location_status = 'Live'
AND gb.kiosk_mode = 'Live'

UPDATE fact.devicetelemetry
SET cpuvalue = CASE WHEN cpuvalue > 1 THEN cpuvalue / 100 ELSE cpuvalue END,
    memoryvalue = CASE WHEN memoryvalue > 1 THEN memoryvalue / 100 ELSE memoryvalue END
WHERE 1=1
--AND locationid = 'loc-c7ce66a2-3f71-4d3c-a017-608886b7536d'
AND (deviceid not like 'ksk-%' and deviceid not like 'kds-%')  -- AGENTS


SELECT *
FROM information_schema.columns as isc
WHERE isc.table_name = 'devicestate'

SELECT *
FROM dim.organizationlocation as ol
WHERE ol.organizationname like '%Umrs%'

SELECT * 
FROM c
where 1=1
and c.category= 'Session'
and c.type= 'Started'
order by c._ts desc

select * from fact.pipelinerunstatus

select * from fact.userbehaviour
select * from fact.devicetelemetry
select * from fact.devicestate order by lasteventtime desc limit 1000
select * from fact.watermarktable
select * from fact.deviceevent limit 10
select * from fact.usercheckedin

/*update fact.watermarktable
set watermarkvalue = (select MAX(lasteventtime) as lasteventtime from fact.devicestate)
where watermarktablename = 'devicestate'

--insert into fact.watermarktable(watermarktablename, watermarkcolumn, watermarkvalue) values
('userbehaviour','busdate','1900-01-01 00:00:00.000'),
('devicetelemetry','telemetrytime','1900-01-01 00:00:00.000'),
('devicestate','lasteventtime','1900-01-01 00:00:00.000')*/