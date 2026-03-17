--drop table IF EXISTS dim.organization;
CREATE TABLE IF NOT EXISTS dim.organization
(
    id character varying(40) COLLATE pg_catalog."default" NOT NULL,
    name character varying(255) COLLATE pg_catalog."default" NOT NULL,
    address1 character varying(255) COLLATE pg_catalog."default",
    address2 character varying(255) COLLATE pg_catalog."default",
    city character varying(255) COLLATE pg_catalog."default",
    state character varying(255) COLLATE pg_catalog."default",
    zipcode character varying(20) COLLATE pg_catalog."default",
    country character varying(255) COLLATE pg_catalog."default",
    organizationtype smallint NOT NULL,
    status smallint NOT NULL,
    phonenumber character varying(20) COLLATE pg_catalog."default",
    email character varying(255) COLLATE pg_catalog."default",
    isdeleted boolean DEFAULT false,
    createdon timestamp without time zone NOT NULL,
    createdby character varying(255) COLLATE pg_catalog."default",
    modifiedon timestamp without time zone,
    modifiedby character varying(255) COLLATE pg_catalog."default",
    active boolean NOT NULL,
    timezone character varying(50) COLLATE pg_catalog."default",
    coordinates text COLLATE pg_catalog."default",
    dayofweek integer,
    hour integer,
    minutes integer,
    CONSTRAINT organization_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE dim.organization
    OWNER to citus;

select * from dim.organization

/*insert into dim.organization

--drop table dim.organizationgeography
select * from dim.organizationgeography*/