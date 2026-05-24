-- Table: dim.frequentcustomer

-- DROP TABLE IF EXISTS dim.frequentcustomer;
--CALL dim.usp_refresh_frequentcustomer();

SELECT * FROM stg.dim_frequentcustomer

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
        s.frequentcustomerid,
        s.firstname,
        s.lastname,
        s.email,
        s.phone,
        s.source,
        s.organizationid,
        s.createddate,
        s.lastorderdate,
        s.ordercount,
        0,
        s.syscosmosts,
        NOW()
    FROM stg.dim_frequentcustomer s

    ON CONFLICT (frequentcustomerid) DO UPDATE SET
        firstname      = EXCLUDED.firstname,
        lastname       = EXCLUDED.lastname,
        email          = EXCLUDED.email,
        phone          = EXCLUDED.phone,
        source         = EXCLUDED.source,
        organizationid = EXCLUDED.organizationid,
        createddate    = EXCLUDED.createddate,
        lastorderdate  = EXCLUDED.lastorderdate,
        ordercount     = EXCLUDED.ordercount,
        syscosmosts    = EXCLUDED.syscosmosts,
        sysupdatetime  = NOW()

    WHERE (
        dim.frequentcustomer.firstname      IS DISTINCT FROM EXCLUDED.firstname      OR
        dim.frequentcustomer.lastname       IS DISTINCT FROM EXCLUDED.lastname       OR
        dim.frequentcustomer.email          IS DISTINCT FROM EXCLUDED.email          OR
        dim.frequentcustomer.phone          IS DISTINCT FROM EXCLUDED.phone          OR
        dim.frequentcustomer.source         IS DISTINCT FROM EXCLUDED.source         OR
        dim.frequentcustomer.organizationid IS DISTINCT FROM EXCLUDED.organizationid OR
        dim.frequentcustomer.createddate    IS DISTINCT FROM EXCLUDED.createddate    OR
        dim.frequentcustomer.lastorderdate  IS DISTINCT FROM EXCLUDED.lastorderdate  OR
        dim.frequentcustomer.ordercount     IS DISTINCT FROM EXCLUDED.ordercount     OR
        dim.frequentcustomer.syscosmosts    IS DISTINCT FROM EXCLUDED.syscosmosts
    );

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_frequentcustomer()
    OWNER to citus;