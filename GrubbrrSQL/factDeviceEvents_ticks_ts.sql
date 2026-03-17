CREATE TABLE IF NOT EXISTS fact.deviceeventtest
(
    application text COLLATE pg_catalog."default" NOT NULL,
    companyid text COLLATE pg_catalog."default" NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    moduleid text COLLATE pg_catalog."default",
    datacategory text COLLATE pg_catalog."default",
    actiontype text COLLATE pg_catalog."default",
    severity text COLLATE pg_catalog."default",
    eventtoken text COLLATE pg_catalog."default",
    eventinstant text COLLATE pg_catalog."default",
    dateid integer,
    username text COLLATE pg_catalog."default",
    userid text COLLATE pg_catalog."default",
    deviceid text COLLATE pg_catalog."default",
    devicename text COLLATE pg_catalog."default",
    summary text COLLATE pg_catalog."default",
    eventdata text COLLATE pg_catalog."default",
    syscosmosticks BIGINT,
    sysinserttime TIMESTAMP
)

TABLESPACE pg_default;

ALTER TABLE fact.deviceevent--test
    OWNER to citus;

ALTER TABLE fact.deviceevent--test
add syscosmosticks BIGINT,
add sysinserttime TIMESTAMP,
add syscosmosts BIGINT


-- Index: fact.deviceeventidx
CREATE INDEX IF NOT EXISTS deviceeventidx
    ON fact.deviceevent USING btree
    (companyid COLLATE pg_catalog."default" ASC NULLS LAST, locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: fact.deviceeventuidx
CREATE INDEX IF NOT EXISTS deviceeventuidx
    ON fact.deviceevent USING btree
    (application COLLATE pg_catalog."default" ASC NULLS LAST, companyid COLLATE pg_catalog."default" ASC NULLS LAST, locationid COLLATE pg_catalog."default" ASC NULLS LAST, moduleid COLLATE pg_catalog."default" ASC NULLS LAST, eventtoken COLLATE pg_catalog."default" ASC NULLS LAST, datacategory COLLATE pg_catalog."default" ASC NULLS LAST, actiontype COLLATE pg_catalog."default" ASC NULLS LAST, eventinstant COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

select * from fact.deviceevent--test
LIMIT 1000

SELECT *--count(*)
from fact.deviceeventtest --37,177,187
order by eventinstant DESC
LIMIT 10

--638877378214374076--
--638877378214374000


SELECT count(*), max(de.syscosmosticks), max(de.syscosmosts), max(de.eventinstant) as maxx, min(de.eventinstant) as minn --37,177,187	2025-06-21T22:32:05.418+00:00	1970-01-01T00:00:27.996+00:00
from fact.deviceevent as de --41511591	638877561130695749	1752159313	2025-07-10T15:10:15.418+00:00	1970-01-01T00:00:27.996+00:00	1970-01-01T00:00:27.996+00:00 --37,177,187  38598558	2025-06-27T19:57:43.605+00:00	1970-01-01T00:00:27.996+00:00

SELECT *
FROM fact.watermarktable as wt
WHERE wt.watermarktablename = 'deviceevent';
--deviceevent	syscosmosts	2025-07-11 02:14:20.757	638877561130695749	1752159313

ALTER TABLE fact.watermarktable
add ticks BIGINT,
add ts BIGINT

SELECT *
FROM fact.deviceevent as de
where de.syscosmosts is not null
ORDER BY de.syscosmosts desc
LIMIT 1000

update fact.watermarktable
set ticks = de.maxticks,
    ts = de.maxts,
    watermarkvalue = de.maxeventinstant
from (select 'deviceevent' as tablename, 
              coalesce(max(syscosmosticks),0) as maxticks, 
              coalesce(max(syscosmosts),0) as maxts,
              case when substring(max(eventinstant), 20, 1) = '.' 
                   then replace(replace(substring(max(eventinstant), 1, 23), 'T', ' '), '+', '0')
                   else substring(max(eventinstant), 1, 19) end :: TIMESTAMP as maxeventinstant
      from fact.deviceevent) as de 
where watermarktable.watermarktablename = de.tablename;

select 1 as rn;
--INSERT INTO fact.watermarktable (watermarktablename, watermarkcolumn/*, watermarkvalue, ticks*/)
--VALUES('deviceevent', 'syscosmosts'/*, cast('2025-07-10T09:49:50.168+00:00' as TIMESTAMP), 638877378214374076*/)

SELECT count(*), max(de.eventinstant) as maxx, min(de.eventinstant) as minn --9,545,648	2025-06-26T15:18:32.982+00:00	1970-01-01T00:00:27.996+00:00
from fact.deviceeventtest as de --9,683,439	2025-07-10T09:49:50.168+00:00	1970-01-01T00:00:27.996+00:00
where de.eventinstant > '2025-06-21T22:32:05.418+00:00' 

select 
from fact.deviceeventtest
where 

INSERT INTO fact.deviceevent(application, companyid, locationid, moduleid, datacategory,
    actiontype, severity, eventtoken, eventinstant, dateid, username, userid, deviceid,
    devicename, summary, eventdata, syscosmosticks, sysinserttime, syscosmosts)
SELECT application, companyid, locationid, moduleid, datacategory,
    actiontype, severity, eventtoken, eventinstant, dateid, username, userid, deviceid,
    devicename, summary, eventdata, syscosmosticks, sysinserttime, syscosmosts
from fact.deviceeventtest as dt
where dt.eventinstant > '2025-07-10T09:49:50.168+00:00'
and not EXISTS (select 1 from fact.deviceevent as de 
                where de.locationid = dt.locationid
                  and de.eventtoken = dt.eventtoken
                  and de.datacategory = dt.datacategory
                  and de.actiontype = dt.actiontype
                  and de.eventinstant = dt.eventinstant) --1,101,501 inserted



SELECT *--count(*)
from fact.deviceevent --37,177,187
