CREATE TABLE IF NOT EXISTS dim.device
(
    id bigint NOT NULL,
    deviceid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    devicetype character varying(50) COLLATE pg_catalog."default" NOT NULL,
    devicename text COLLATE pg_catalog."default",
    locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    companyid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    currentversion character varying(50) COLLATE pg_catalog."default",
    ipaddress character varying(50) COLLATE pg_catalog."default",
    state character varying(50) COLLATE pg_catalog."default" NOT NULL,
    previousstate character varying(50) COLLATE pg_catalog."default",
    statechangedate timestamp without time zone,
    enrollmentdate timestamp without time zone NOT NULL,
    disenrollmentdate timestamp without time zone,
    disenrollmentreason text COLLATE pg_catalog."default",
    testmode boolean DEFAULT false,
    CONSTRAINT device_pkey PRIMARY KEY (id),
    CONSTRAINT device_deviceid_locationid_companyid_key UNIQUE (deviceid, locationid, companyid)
)

TABLESPACE pg_default;

ALTER TABLE dim.device
    OWNER to citus;

-- Index: dim.deviceid_locationid_companyid_idx
CREATE INDEX IF NOT EXISTS deviceid_locationid_companyid_idx
    ON dim.device USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST, locationid COLLATE pg_catalog."default" ASC NULLS LAST, companyid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(devicetype, state, testmode)
    TABLESPACE pg_default;
-- Index: dim.idx_device_id
CREATE INDEX IF NOT EXISTS idx_device_id
    ON dim.device USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: dim.idx_device_location_id
CREATE INDEX IF NOT EXISTS idx_device_location_id
    ON dim.device USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: dim.idx_device_state
CREATE INDEX IF NOT EXISTS idx_device_state
    ON dim.device USING btree
    (state COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: dim.idx_device_testmode
CREATE INDEX IF NOT EXISTS idx_device_testmode
    ON dim.device USING btree
    (testmode ASC NULLS LAST)
    TABLESPACE pg_default;



CREATE TABLE IF NOT EXISTS dim.peripheral
(
    id bigint NOT NULL,
    deviceid bigint,
    peripheralid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    peripheraltype character varying(50) COLLATE pg_catalog."default" NOT NULL,
    state character varying(50) COLLATE pg_catalog."default" NOT NULL,
    previousstate character varying(50) COLLATE pg_catalog."default",
    statechangedate timestamp without time zone,
    description text COLLATE pg_catalog."default",
    model text COLLATE pg_catalog."default",
    serial text COLLATE pg_catalog."default",
    ipaddress character varying(50) COLLATE pg_catalog."default",
    CONSTRAINT peripheral_pkey PRIMARY KEY (id),
    CONSTRAINT peripheral_deviceid_peripheralid_key UNIQUE (deviceid, peripheralid),
    CONSTRAINT peripheral_deviceid_fkey FOREIGN KEY (deviceid)
        REFERENCES dim.device (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE dim.peripheral
    OWNER to citus;

-- Index: dim.peripheral_idx
CREATE INDEX IF NOT EXISTS peripheral_idx
    ON dim.peripheral USING btree
    (deviceid ASC NULLS LAST, peripheralid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(peripheraltype, state, statechangedate)
    TABLESPACE pg_default;




drop TABLE IF EXISTS fact.devicehealth;
CREATE TABLE IF NOT EXISTS fact.devicehealth
(
    id bigint NOT NULL,
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
    devicedatatime timestamp without time zone,
    CONSTRAINT devicehealth_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE fact.devicehealth
    OWNER to citus;

-- Index: fact.devicehealth_idx
CREATE INDEX IF NOT EXISTS devicehealth_idx
    ON fact.devicehealth USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST, locationid COLLATE pg_catalog."default" ASC NULLS LAST, companyid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(devicetype, status, healthdatatype, healthdatatime, statuschangetime)
    TABLESPACE pg_default;
-- Index: fact.deviceid_idx
CREATE INDEX IF NOT EXISTS deviceid_idx
    ON fact.devicehealth USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: fact.idx_devicehealth_deviceid
CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid
    ON fact.devicehealth USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: fact.idx_devicehealth_deviceid_status_time
CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid_status_time
    ON fact.devicehealth USING btree
    (deviceid COLLATE pg_catalog."default" ASC NULLS LAST, status COLLATE pg_catalog."default" ASC NULLS LAST, healthdatatime DESC NULLS FIRST)
    TABLESPACE pg_default;
-- Index: fact.idx_devicehealth_locationid
CREATE INDEX IF NOT EXISTS idx_devicehealth_locationid
    ON fact.devicehealth USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

drop TABLE IF EXISTS fact.peripheralhealth;
CREATE TABLE IF NOT EXISTS fact.peripheralhealth
(
    healthdataid bigint,
    peripheralid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    peripheraltype character varying(50) COLLATE pg_catalog."default" NOT NULL,
    status character varying(50) COLLATE pg_catalog."default" NOT NULL,
    statusmessage text COLLATE pg_catalog."default",
    CONSTRAINT peripheralhealth_healthdataid_peripheralid_key UNIQUE (healthdataid, peripheralid),
    CONSTRAINT peripheralhealth_healthdataid_fkey FOREIGN KEY (healthdataid)
        REFERENCES fact.devicehealth (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE fact.peripheralhealth
    OWNER to citus;

-- Index: fact.peripheralhealth_idx
CREATE INDEX IF NOT EXISTS peripheralhealth_idx
    ON fact.peripheralhealth USING btree
    (healthdataid ASC NULLS LAST, peripheralid COLLATE pg_catalog."default" ASC NULLS LAST)
    INCLUDE(peripheraltype, status)
    TABLESPACE pg_default;