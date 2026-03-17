SELECT count(*)
FROM fact.deviceevent as de 
WHERE lower(de.severity) like '%error%'
--AND de.eventinstant > '2025-12-01'
LIMIT 100

SELECT count(*)
FROM fact.deviceevent as de 
WHERE 1=1 --AND de.severity like '%error%' --31,355
AND de.companyid = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269'
AND de.locationid = 'loc-4e32f55b-d292-4812-a2a9-ebcf2a8c4239'
AND de.eventtoken = '4WN1XA1G1AUO0C6F'-- 'WGT6D5RWS1YVBPD2'
AND de.eventinstant > '2025-12-01'


SELECT *
FROM fact.transactionitem as ti
WHERE ti.transactionheaderid in -- th.ordertotal > 1000
    (SELECT th.transactionheaderid
    FROM fact.transactionheader as th
    WHERE th.ordertotal > 1000)
ORDER BY th.updateddate DESC




SELECT *
FROM fact.itemmodifier as ti
WHERE ti.transactionheaderid in -- th.ordertotal > 1000
    (SELECT th.transactionheaderid
    FROM fact.transactionheader as th
    WHERE th.ordertotal > 1000)
ORDER BY th.updateddate DESC

ALTER TABLE fact.itemmodifier
ADD CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY key (transactionheaderid, itemid, modifiergroupid, modifierid)



SELECT *
FROM fact.cep_incidents as cep
WHERE 1=1 --AND de.severity like '%error%' --31,355
--AND cep.organizationid = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269'
--AND cep.locationid = 'loc-4e32f55b-d292-4812-a2a9-ebcf2a8c4239'
--AND cep.eventtoken = '4WN1XA1G1AUO0C6F'-- 'WGT6D5RWS1YVBPD2'
--AND cep.eventinstant > '2025-12-01'
AND cep.incidentkey is not null

SELECT DISTINCT eventmodule, eventcategory, eventtype
FROM fact.cep_incidents
WHERE 1=1--
--AND eventcategory = 'Error'
--AND cep.incidenttype is not NULL
ORDER BY incidentkey DESC
LIMIT 1000

SELECT *--count(*)
FROM fact.cep_incidents as de 
WHERE de.severity like '%error%'
--AND de.eventinstant > '2025-12-01'
ORDER BY de.eventinstant DESC
LIMIT 100

--INSERT INTO fact.cep_incidents
SELECT de.syscosmosticks,
       de.application,
       de.companyid,
       de.locationid,
       de.deviceid,
       de.moduleid,
       de.datacategory,
       de.actiontype,
       de.eventtoken,
       NULL as incidenttype,
       NULL as incidentcount,
       de.eventinstant,
       NULL as firstoccurred,
       NULL as lastoccurred,
       NULL as notificationtypeid,
       de.eventdata,
       de.syscosmosts,
       de.sysinserttime
FROM fact.deviceevent as de
WHERE 1=1 
  AND lower(de.severity) like '%error%'
  AND NOT EXISTS (SELECT 1 FROM fact.cep_incidents as cep 
                  WHERE cep.organizationid = de.companyid
                    AND cep.locationid = de.locationid
                    AND cep.eventtoken = de.eventtoken
                    AND cep.eventcategory = de.datacategory
                    AND cep.eventtype = de.actiontype
                    AND cep.eventinstant = de.eventinstant)

SELECT DISTINCT de.application FROM fact.deviceevent as de

CREATE INDEX IF NOT EXISTS cep_incidents_uidx
    ON fact.cep_incidents USING btree
    (severity COLLATE pg_catalog."default" ASC NULLS LAST, 
     eventmodule COLLATE pg_catalog."default" ASC NULLS LAST, 
     eventcategory COLLATE pg_catalog."default" ASC NULLS LAST, 
     eventtype COLLATE pg_catalog."default" ASC NULLS LAST,
     organizationid COLLATE pg_catalog."default" ASC NULLS LAST, 
     locationid COLLATE pg_catalog."default" ASC NULLS LAST,
     eventtoken COLLATE pg_catalog."default" ASC NULLS LAST, 
     eventinstant COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


UPDATE fact.cep_incidents
SET severity = de.severity
FROM fact.deviceevent as de 
WHERE cep_incidents.organizationid = de.companyid
  AND cep_incidents.locationid = de.locationid
  AND cep_incidents.eventmodule = de.moduleid 
  AND cep_incidents.eventtoken = de.eventtoken
  AND cep_incidents.eventcategory = de.datacategory
  AND cep_incidents.eventtype = de.actiontype
  AND cep_incidents.eventinstant = de.eventinstant


SELECT COUNT(*)
FROM fact.cep_incidents as cep2 --3,073,516/3,042,054
WHERE NOT EXISTS (
SELECT *, cep.incidentdata :: jsonb ->> 'rawErrorMessage' as raw_error_message
FROM fact.cep_incidents as cep --3,073,516/3,042,054
WHERE 1=1 --AND de.severity like '%error%' --31,355
--AND (cep.eventmodule is null or cep.eventcategory is null or cep.eventtype is null)
--AND cep.organizationid = 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269'
--AND cep.locationid = 'loc-4e32f55b-d292-4812-a2a9-ebcf2a8c4239'
--AND cep.eventtoken = '4WN1XA1G1AUO0C6F'-- 'WGT6D5RWS1YVBPD2'
--AND cep.eventinstant > '2025-12-01'
--AND cep.incidentkey is not null
--AND lower(cep.eventcategory) <> 'order' AND lower(cep.eventtype) <> 'validate' 
--AND lower(cep.eventcategory) <> 'order' 
--AND lower(cep.eventtype) not in ('ordersubmitresponse','validate') --3,036,128/3,042,006
AND (
    (lower(cep.eventmodule) = 'kiosk' AND lower(cep.eventcategory) = 'order' AND lower(cep.eventtype) = 'validate') 
    OR --31,462/3,067,531
    (lower(cep.eventmodule) = 'connector' AND lower(cep.eventcategory) = 'order' AND lower(cep.eventtype) = 'ordersubmitresponse')
   ) --AND cep.eventmodule = cep2.eventmodule AND cep.eventcategory = cep2.eventcategory AND cep.eventtype = cep2.eventtype
--AND dim.is_valid_jsonb(cep.incidentdata) = False
LIMIT 4000
)

ALTER TABLE fact.cep_incidents
ADD COLUMN IF NOT EXISTS severity TEXT COLLATE pg_catalog."default"

SELECT * FROM e where 
e.instant >= '2026-01-10T00:00:00Z'
    AND e.instant <= GetCurrentDateTime()
--////OVF///
  AND ((LOWER(e.module) = 'kiosk'
  AND LOWER(e.category) = 'order'
  AND LOWER(e.type) = 'validate'
  AND LOWER(e.severity) = 'error')
OR
--///OSF////
    (LOWER(e.module) = 'connector'
    AND LOWER(e.category) = 'order'
    AND LOWER(e.type) = 'ordersubmitresponse'
    AND LOWER(e.severity) = 'critical'))