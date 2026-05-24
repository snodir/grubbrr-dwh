-- Table: dim.frequentcustomer

-- DROP TABLE IF EXISTS dim.frequentcustomer;
--CALL dim.usp_refresh_frequentcustomer();


SELECT count(*)
FROM stg.dim_frequentcustomer LIMIT 100; --949,757

SELECT count(*)
FROM dim.frequentcustomer LIMIT 100; --944,838 --946,213


SELECT NOW() as time_now;

CREATE TABLE IF NOT EXISTS stg.dim_frequentcustomer
(
    frequentcustomerid text COLLATE pg_catalog."default" NOT NULL,
    firstname text COLLATE pg_catalog."default",
    lastname text COLLATE pg_catalog."default",
    email text COLLATE pg_catalog."default",
    phone text COLLATE pg_catalog."default",
    source text COLLATE pg_catalog."default",
    organizationid text COLLATE pg_catalog."default",
    createddate text COLLATE pg_catalog."default",
    lastorderdate text COLLATE pg_catalog."default",
    ordercount integer NOT NULL DEFAULT 0,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_frequentcustomer
    OWNER to citus;

--CosmosDb container query
SELECT c.id ?? null as frequentcustomerid,
c.firstName ?? null as firstname,
c.lastName ?? null as lastname,
c.email ?? null as email,
c.phone ?? null as phone,
c.affiliate ?? null as source,
c.organizationId?? null as organizationid,
c.dateCreated ?? null as createddate,
c.dateLastOrder ?? null as lastorderdate,
c.countOrders ?? null as ordercount,
c._ts as syscosmosts
FROM c

-- Table: dim.frequentcustomer

-- DROP TABLE IF EXISTS dim.frequentcustomer;

CREATE TABLE IF NOT EXISTS dim.frequentcustomer
(
    customerkey bigint NOT NULL,
    frequentcustomerid text COLLATE pg_catalog."default" NOT NULL,
    firstname text COLLATE pg_catalog."default",
    lastname text COLLATE pg_catalog."default",
    email text COLLATE pg_catalog."default",
    phone text COLLATE pg_catalog."default",
    source text COLLATE pg_catalog."default",
    organizationid text COLLATE pg_catalog."default",
    createddate text COLLATE pg_catalog."default",
    lastorderdate text COLLATE pg_catalog."default",
    ordercount integer NOT NULL DEFAULT 0,
    amountspent numeric NOT NULL DEFAULT 0,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.frequentcustomer
    OWNER to citus;

-- One-time setup
CREATE SEQUENCE IF NOT EXISTS dim.frequentcustomer_customerkey_seq;

-- Sync to current max to avoid collisions with existing data
SELECT setval(
    'dim.frequentcustomer_customerkey_seq',
    COALESCE((SELECT MAX(customerkey) FROM dim.frequentcustomer), 0)
);

-- Attach to the column
ALTER TABLE dim.frequentcustomer
    ALTER COLUMN customerkey SET DEFAULT nextval('dim.frequentcustomer_customerkey_seq');



--CALL dim.usp_refresh_frequentcustomer();



CREATE OR REPLACE PROCEDURE dim.usp_refresh_frequentcustomer()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    CREATE TEMP TABLE tmp_frequentcustomer ON COMMIT DROP AS
    SELECT DISTINCT ON (frequentcustomerid)
        frequentcustomerid,
        firstname,
        lastname,
        email,
        phone,
        source,
        organizationid,
        createddate,
        lastorderdate,
        ordercount,
        syscosmosts
    FROM stg.dim_frequentcustomer
    ORDER BY frequentcustomerid, sysinserttime DESC NULLS LAST;

    CREATE INDEX ix_tmp_frequentcustomer_id ON tmp_frequentcustomer (frequentcustomerid);

    -- INSERT net new
    INSERT INTO dim.frequentcustomer (
        customerkey,
        frequentcustomerid,
        firstname,
        lastname,
        email,
        phone,
        source,
        organizationid,
        createddate,
        lastorderdate,
        ordercount,
        amountspent,
        syscosmosts,
        sysinserttime
    )
    SELECT
        nextval('dim.frequentcustomer_customerkey_seq'),
        t.frequentcustomerid,
        t.firstname,
        t.lastname,
        t.email,
        t.phone,
        t.source,
        t.organizationid,
        t.createddate,
        t.lastorderdate,
        t.ordercount,
        0,
        t.syscosmosts,
        NOW()
    FROM tmp_frequentcustomer t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.frequentcustomer d
        WHERE d.frequentcustomerid = t.frequentcustomerid
    );

    -- UPDATE changed
    UPDATE dim.frequentcustomer d
    SET
        firstname      = t.firstname,
        lastname       = t.lastname,
        email          = t.email,
        phone          = t.phone,
        source         = t.source,
        organizationid = t.organizationid,
        createddate    = t.createddate,
        lastorderdate  = t.lastorderdate,
        ordercount     = t.ordercount,
        syscosmosts    = t.syscosmosts,
        sysupdatetime  = NOW()
    FROM tmp_frequentcustomer t
    WHERE d.frequentcustomerid = t.frequentcustomerid
    AND (
        d.firstname      IS DISTINCT FROM t.firstname      OR
        d.lastname       IS DISTINCT FROM t.lastname       OR
        d.email          IS DISTINCT FROM t.email          OR
        d.phone          IS DISTINCT FROM t.phone          OR
        d.source         IS DISTINCT FROM t.source         OR
        d.organizationid IS DISTINCT FROM t.organizationid OR
        d.createddate    IS DISTINCT FROM t.createddate    OR
        d.lastorderdate  IS DISTINCT FROM t.lastorderdate  OR
        d.ordercount     IS DISTINCT FROM t.ordercount     OR
        d.syscosmosts    IS DISTINCT FROM t.syscosmosts
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_frequentcustomer()
    OWNER to citus;