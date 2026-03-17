CREATE TABLE IF NOT EXISTS gsh.devicehealth_bkp
(
    id bigint NOT NULL DEFAULT nextval('gsh.devicehealth_id_seq'::regclass),
    healthdatatype character varying(50) COLLATE pg_catalog."default" NOT NULL,
    locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    companyid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    deviceid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    devicetype character varying(50) COLLATE pg_catalog."default" NOT NULL,
    status character varying(50) COLLATE pg_catalog."default" NOT NULL,
    statusmessage text COLLATE pg_catalog."default",
    healthdatatime timestamp without time zone NOT NULL,
    statuschangetime timestamp without time zone NOT NULL,
    inserttime timestamp without time zone NOT NULL,
    version character varying(50) COLLATE pg_catalog."default",
    CONSTRAINT devicehealth_bkp_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE gsh.devicehealth_bkp
    OWNER to citus;

insert into gsh.devicehealth_bkp
select * from gsh.devicehealth
WHERE 
LIMIT 100

SELECT *
FROM gsh.devicehealth
WHERE statuschangetime < '4713-01-01 BC' OR statuschangetime > '294276-12-31'
or healthdatatime < '4713-01-01 BC' OR healthdatatime > '294276-12-31';


select count(*) from gsh.devicehealth where healthdatatime <> '-infinity';
select max(id) from gsh.devicehealth_bkp

select cast(id as bigint) as id,
    cast(healthdatatype as text) as healthdatatype,
    cast(locationid as text) as locationid,
    cast(companyid as text) as companyid,
    cast(deviceid as text) as deviceid,
    cast(devicetype as text) as devicetype,
    cast(status as text) as status,
    cast(statusmessage as text) as statusmessage,
    cast(healthdatatime as TIMESTAMP) as healthdatatime,
    cast(statuschangetime as TIMESTAMP) as statuschangetime,
    cast(inserttime as TIMESTAMP) as inserttime,
    cast(version as text) as version
from gsh.devicehealth
where deviceid != 'no-serial'
limit 1000
--21	40	40	40	7	22	55

select * from fact.devicestate order by statuschangetime desc limit 100
select * from fact.pipelinerunstatus


/*
-- Index: gsh.devicehealth_idx
CREATE INDEX IF NOT EXISTS devicehealth_idx
    ON gsh.devicehealth USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST, locationid COLLATE pg_catalog."default" ASC NULLS LAST, companyid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(devicetype, status, healthdatatype, healthdatatime, statuschangetime)
    TABLESPACE pg_default;
-- Index: gsh.deviceid_idx
CREATE INDEX IF NOT EXISTS deviceid_idx
    ON gsh.devicehealth USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: gsh.idx_devicehealth_deviceid
CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid
    ON gsh.devicehealth USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: gsh.idx_devicehealth_deviceid_status_time
CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid_status_time
    ON gsh.devicehealth USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST, status COLLATE pg_catalog."default" ASC NULLS LAST, healthdatatime DESC NULLS FIRST)
    TABLESPACE pg_default;
-- Index: gsh.idx_devicehealth_locationid
CREATE INDEX IF NOT EXISTS idx_devicehealth_locationid
    ON gsh.devicehealth USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
*/