--Schema(Column structure) changed
--drop table if EXISTS fact.devicetelemetry;
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
