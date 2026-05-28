SELECT * FROM dim.organization LIMIT 100;

-- Table: dim.organization

-- DROP TABLE IF EXISTS dim.organization;

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
    organizationtype smallint,
    status smallint,
    phonenumber character varying(20) COLLATE pg_catalog."default",
    email character varying(255) COLLATE pg_catalog."default",
    isdeleted boolean DEFAULT false,
    createdon timestamp without time zone,
    createdby character varying(255) COLLATE pg_catalog."default",
    modifiedon timestamp without time zone,
    modifiedby character varying(255) COLLATE pg_catalog."default",
    active boolean,
    timezone character varying(50) COLLATE pg_catalog."default",
    coordinates text COLLATE pg_catalog."default",
    dayofweek integer,
    hour integer,
    minutes integer,
    roundupforcharity boolean,
    is_ecm_enabled boolean,
    is_cep_enabled boolean,
    is_concessionaire_enabled boolean,
    is_smart_upsells_enabled boolean,
    is_feedback_survey_enabled boolean,
    is_digital_menu_board_enabled boolean,
    is_digital_menu_default_format_enabled boolean,
    cep_subscriptions text COLLATE pg_catalog."default",
    sysinserttime TIMESTAMP,
    sysupdatetime TIMESTAMP,
    CONSTRAINT organization_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.organization
OWNER to citus,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;




CREATE TABLE IF NOT EXISTS stg.dim_cep_subscriptions (
    id                  TEXT COLLATE pg_catalog."default",
    cep_subscriptions   TEXT COLLATE pg_catalog."default",
    sysinserttime       TIMESTAMP
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_cep_subscriptions
OWNER TO citus;




CREATE TABLE IF NOT EXISTS stg.dim_organization
(
    id character varying(40) COLLATE pg_catalog."default" NOT NULL,
    name character varying(255) COLLATE pg_catalog."default" NOT NULL,
    address1 character varying(255) COLLATE pg_catalog."default",
    address2 character varying(255) COLLATE pg_catalog."default",
    city character varying(255) COLLATE pg_catalog."default",
    state character varying(255) COLLATE pg_catalog."default",
    zipcode character varying(20) COLLATE pg_catalog."default",
    country character varying(255) COLLATE pg_catalog."default",
    organizationtype smallint,
    status smallint,
    phonenumber character varying(20) COLLATE pg_catalog."default",
    email character varying(255) COLLATE pg_catalog."default",
    isdeleted boolean DEFAULT false,
    createdon timestamp without time zone,
    createdby character varying(255) COLLATE pg_catalog."default",
    modifiedon timestamp without time zone,
    modifiedby character varying(255) COLLATE pg_catalog."default",
    active boolean,
    timezone character varying(50) COLLATE pg_catalog."default",
    coordinates text COLLATE pg_catalog."default",
    dayofweek integer,
    hour integer,
    minutes integer,
    roundupforcharity boolean,
    is_ecm_enabled boolean,
    is_cep_enabled boolean,
    is_concessionaire_enabled boolean,
    is_smart_upsells_enabled boolean,
    is_feedback_survey_enabled boolean,
    is_digital_menu_board_enabled boolean,
    is_digital_menu_default_format_enabled boolean,
    cep_subscriptions text COLLATE pg_catalog."default",
    sysinserttime TIMESTAMP,
    CONSTRAINT organization_pkey PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.dim_organization
    OWNER to citus,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;




CREATE OR REPLACE PROCEDURE dim.usp_refresh_organization()
LANGUAGE plpgsql
AS $$
BEGIN

    INSERT INTO dim.organization (
        id,
        name,
        address1,
        address2,
        city,
        state,
        zipcode,
        country,
        organizationtype,
        status,
        phonenumber,
        email,
        isdeleted,
        createdon,
        createdby,
        modifiedon,
        modifiedby,
        active,
        timezone,
        coordinates,
        dayofweek,
        hour,
        minutes,
        roundupforcharity,
        is_ecm_enabled,
        is_cep_enabled,
        is_concessionaire_enabled,
        is_smart_upsells_enabled,
        is_feedback_survey_enabled,
        is_digital_menu_board_enabled,
        is_digital_menu_default_format_enabled,
        cep_subscriptions,
        sysinserttime
    )
    SELECT
        o.id,
        o.name,
        o.address1,
        o.address2,
        o.city,
        o.state,
        o.zipcode,
        o.country,
        o.organizationtype,
        o.status,
        o.phonenumber,
        o.email,
        o.isdeleted,
        o.createdon,
        o.createdby,
        o.modifiedon,
        o.modifiedby,
        o.active,
        o.timezone,
        o.coordinates,
        o.dayofweek,
        o.hour,
        o.minutes,
        k.round_up_for_charity      AS roundupforcharity,
        o.is_ecm_enabled,
        o.is_cep_enabled,
        o.is_concessionaire_enabled,
        o.is_smart_upsells_enabled,
        o.is_feedback_survey_enabled,
        o.is_digital_menu_board_enabled,
        o.is_digital_menu_default_format_enabled,
        c.cep_subscriptions,
        NOW()
    FROM stg.dim_organization o
    LEFT JOIN dim.kioskdetails k        ON o.id = k.locationid
    LEFT JOIN stg.dim_cep_subscriptions c ON o.id = c.id
    ON CONFLICT (id) DO UPDATE SET
        name                                   = EXCLUDED.name,
        address1                               = EXCLUDED.address1,
        address2                               = EXCLUDED.address2,
        city                                   = EXCLUDED.city,
        state                                  = EXCLUDED.state,
        zipcode                                = EXCLUDED.zipcode,
        country                                = EXCLUDED.country,
        organizationtype                       = EXCLUDED.organizationtype,
        status                                 = EXCLUDED.status,
        phonenumber                            = EXCLUDED.phonenumber,
        email                                  = EXCLUDED.email,
        isdeleted                              = EXCLUDED.isdeleted,
        createdon                              = EXCLUDED.createdon,
        createdby                              = EXCLUDED.createdby,
        modifiedon                             = EXCLUDED.modifiedon,
        modifiedby                             = EXCLUDED.modifiedby,
        active                                 = EXCLUDED.active,
        timezone                               = EXCLUDED.timezone,
        coordinates                            = EXCLUDED.coordinates,
        dayofweek                              = EXCLUDED.dayofweek,
        hour                                   = EXCLUDED.hour,
        minutes                                = EXCLUDED.minutes,
        roundupforcharity                      = EXCLUDED.roundupforcharity,
        is_ecm_enabled                         = EXCLUDED.is_ecm_enabled,
        is_cep_enabled                         = EXCLUDED.is_cep_enabled,
        is_concessionaire_enabled              = EXCLUDED.is_concessionaire_enabled,
        is_smart_upsells_enabled               = EXCLUDED.is_smart_upsells_enabled,
        is_feedback_survey_enabled             = EXCLUDED.is_feedback_survey_enabled,
        is_digital_menu_board_enabled          = EXCLUDED.is_digital_menu_board_enabled,
        is_digital_menu_default_format_enabled = EXCLUDED.is_digital_menu_default_format_enabled,
        cep_subscriptions                      = EXCLUDED.cep_subscriptions,
        sysupdatetime                          = NOW();

END;
$$;

ALTER PROCEDURE dim.usp_refresh_organization() OWNER TO citus;