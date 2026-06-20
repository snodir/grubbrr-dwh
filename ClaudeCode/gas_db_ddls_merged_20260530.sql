-- ============================================================
-- Merged schema: gas_db_backup_20260530 + alter_table_add_alter_columns
-- Generated: 2026-05-30
-- ============================================================


--
-- PostgreSQL database dump
--
/*
\restrict VFfQD00ditWwDSVTzvrOfGRggS3PfSQDVme4BEMRffIDxSUJxEDWUYHdIpBBv5N

-- Dumped from database version 16.9 (Ubuntu 16.9-1.pgdg20.04+1)
-- Dumped by pg_dump version 18.3

-- Started on 2026-05-30 14:13:40

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;
*/
--
-- TOC entry 64 (class 2615 OID 32802)
-- Name: dim; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA IF NOT EXISTS dim;


ALTER SCHEMA dim OWNER TO citus;

--
-- TOC entry 47 (class 2615 OID 3338276)
-- Name: etl; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA IF NOT EXISTS etl;


ALTER SCHEMA etl OWNER TO citus;

--
-- TOC entry 65 (class 2615 OID 32810)
-- Name: fact; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA IF NOT EXISTS fact;


ALTER SCHEMA fact OWNER TO citus;

--
-- TOC entry 76 (class 2615 OID 3042094)
-- Name: ml; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA IF NOT EXISTS ml;


ALTER SCHEMA ml OWNER TO citus;

--
-- TOC entry 62 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA IF NOT EXISTS public;


--ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 6561 (class 0 OID 0)
-- Dependencies: 62
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

--COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 61 (class 2615 OID 420272)
-- Name: stg; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA IF NOT EXISTS stg;


ALTER SCHEMA stg OWNER TO citus;


--
-- TOC entry 1085 (class 1255 OID 740034)
-- Name: array_to_text(jsonb); Type: FUNCTION; Schema: dim; Owner: citus
--

CREATE OR REPLACE FUNCTION dim.array_to_text(a jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
    SELECT initcap(replace(replace(replace(a::text, '[', ''), ']', ''), '"', ''));
$$;


ALTER FUNCTION dim.array_to_text(a jsonb) OWNER TO citus;

--
-- TOC entry 688 (class 1255 OID 748068)
-- Name: is_valid_jsonb(text); Type: FUNCTION; Schema: dim; Owner: citus
--

CREATE OR REPLACE FUNCTION dim.is_valid_jsonb(input text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
BEGIN
    PERFORM input::jsonb;
    RETURN TRUE;
EXCEPTION WHEN others THEN
    RETURN FALSE;
END;
$$;


ALTER FUNCTION dim.is_valid_jsonb(input text) OWNER TO citus;


CREATE OR REPLACE FUNCTION fact.safe_conversion_to_jsonb(p_input TEXT)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $BODY$
BEGIN
    RETURN p_input::jsonb;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$BODY$;

ALTER FUNCTION fact.safe_conversion_to_jsonb(TEXT) OWNER TO citus;

--
-- TOC entry 1457 (class 1255 OID 3568570)
-- Name: parse_iso_timestamp(text); Type: FUNCTION; Schema: fact; Owner: citus
--

CREATE OR REPLACE FUNCTION fact.parse_iso_timestamp(ts_string text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $BODY$
    SELECT CASE WHEN substring(ts_string, 20, 1) = '.'
                THEN replace(replace(substring(ts_string, 1, 23), 'T', ' '), '+', '0')
                ELSE replace(substring(ts_string, 1, 19), 'T', ' ')
           END;
$BODY$;


ALTER FUNCTION fact.parse_iso_timestamp(ts_string text) OWNER TO citus;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 410 (class 1259 OID 345584)
-- Name: abtests; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.abtests (
    abtestid bigint NOT NULL,
    organizationid text,
    locationid text,
    experimentid text,
    experimentname text,
    variantid text,
    variantname text,
    ordersessionid text,
    deviceid text,
    devicename text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.abtests OWNER TO citus;

-- Schema evolution: dim.abtests
ALTER TABLE IF EXISTS dim.abtests
    OWNER to citus;

--
-- TOC entry 379 (class 1259 OID 32819)
-- Name: datedim; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.datedim (
    dateid integer NOT NULL,
    datets timestamp without time zone NOT NULL,
    hourofday text NOT NULL,
    dayval date NOT NULL,
    daynum smallint NOT NULL,
    dayname text NOT NULL,
    weekval integer NOT NULL,
    monthval integer NOT NULL,
    monthname text NOT NULL,
    quarterval integer NOT NULL,
    yearval integer NOT NULL,
    daypart text NOT NULL,
    dayofyear smallint NOT NULL
);


ALTER TABLE IF EXISTS dim.datedim OWNER TO citus;

--
-- TOC entry 386 (class 1259 OID 32912)
-- Name: businessdate; Type: VIEW; Schema: dim; Owner: citus
--

CREATE OR REPLACE VIEW dim.businessdate AS
 WITH base AS (
         WITH cur AS (
                 SELECT d.dateid,
                    d.datets,
                    d.hourofday,
                    d.dayval,
                    d.daynum,
                    d.dayname,
                    d.weekval,
                    d.monthval,
                    d.monthname,
                    d.quarterval,
                    d.yearval,
                    d.daypart,
                    d.dayofyear
                   FROM dim.datedim d
                  WHERE ((d.yearval)::numeric = EXTRACT(year FROM now()))
                ), pre AS (
                 SELECT d.dateid,
                    d.datets,
                    d.hourofday,
                    d.dayval,
                    d.daynum,
                    d.dayname,
                    d.weekval,
                    d.monthval,
                    d.monthname,
                    d.quarterval,
                    d.yearval,
                    d.daypart,
                    d.dayofyear
                   FROM dim.datedim d
                  WHERE ((d.yearval)::numeric = EXTRACT(year FROM (now() - '1 year'::interval)))
                )
         SELECT DISTINCT (((p.yearval || to_char((c.dayval)::timestamp with time zone, 'MMDD'::text)) || "substring"(c.hourofday, 1, 2)))::integer AS dateid,
            p.hourofday,
            p.daynum,
            p.dayname,
            p.weekval,
            c.monthval,
            c.monthname,
            c.quarterval,
            p.yearval,
            p.daypart
           FROM (cur c
             LEFT JOIN pre p ON (((p.weekval = c.weekval) AND (p.dayname = c.dayname) AND (p.hourofday = c.hourofday))))
          ORDER BY p.daypart, c.quarterval, p.dayname
        )
 SELECT base.dateid,
    base.hourofday,
    base.daynum,
    base.dayname,
    base.weekval,
    base.monthval,
    base.monthname,
    base.quarterval,
    base.yearval,
    base.daypart
   FROM base
UNION
 SELECT d.dateid,
    d.hourofday,
    d.daynum,
    d.dayname,
    d.weekval,
    d.monthval,
    d.monthname,
    d.quarterval,
    d.yearval,
    d.daypart
   FROM dim.datedim d
  WHERE ((d.yearval)::numeric = EXTRACT(year FROM now()))
  ORDER BY 1, 2, 4;


ALTER VIEW dim.businessdate OWNER TO citus;

--
-- TOC entry 447 (class 1259 OID 2178862)
-- Name: catalog; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.catalog (
    catalogid character varying(50) NOT NULL,
    catalogname character varying(255),
    organizationid character varying(40),
    is_catalog_deleted boolean,
    catalog_created_on timestamp without time zone,
    catalog_modified_on timestamp without time zone,
    gem_company_id character varying(255),
    gem_location_id character varying(255),
    is_sync_in_progress boolean,
    is_standalone boolean,
    is_master boolean,
    is_ecm_enabled boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.catalog OWNER TO citus;

-- Schema evolution: dim.catalog

ALTER TABLE IF EXISTS dim.catalog
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

--
-- TOC entry 445 (class 1259 OID 2039150)
-- Name: category_hierarchy; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.category_hierarchy (
    organizationid text,
    locationid text NOT NULL,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    catalogid text,
    catalogname text,
    catalog_created_on timestamp without time zone,
    catalog_modified_on timestamp without time zone,
    is_catalog_active boolean,
    is_catalog_deleted boolean,
    categoryid text NOT NULL,
    categoryname text,
    category_created_on timestamp without time zone,
    category_modified_on timestamp without time zone,
    is_category_active boolean,
    is_category_deleted boolean,
    menuitemid text,
    entitytype text,
    item_class_type integer,
    menuitemname text,
    item_created_on timestamp without time zone,
    item_modified_on timestamp without time zone,
    is_item_active boolean,
    is_item_deleted boolean,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.category_hierarchy OWNER TO citus;

-- Schema evolution: dim.category_hierarchy

ALTER TABLE IF EXISTS dim.category_hierarchy
DROP COLUMN IF EXISTS id;

--
-- TOC entry 378 (class 1259 OID 32811)
-- Name: company; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.company (
    companyid text NOT NULL,
    companyname text NOT NULL,
    businessemail text,
    businessphone text,
    businesstype text,
    address1 text,
    address2 text,
    city text,
    state text,
    zipcode text
);


ALTER TABLE IF EXISTS dim.company OWNER TO citus;
*/
--
-- TOC entry 416 (class 1259 OID 413623)
-- Name: device; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.device (
    id bigint NOT NULL,
    deviceid character varying(50) NOT NULL,
    devicetype character varying(50) NOT NULL,
    devicename text,
    locationid character varying(50) NOT NULL,
    companyid character varying(50) NOT NULL,
    currentversion character varying(50),
    ipaddress character varying(50),
    state character varying(50) NOT NULL,
    previousstate character varying(50),
    statechangedate timestamp without time zone,
    enrollmentdate timestamp without time zone NOT NULL,
    disenrollmentdate timestamp without time zone,
    disenrollmentreason text,
    testmode boolean DEFAULT false
);


ALTER TABLE IF EXISTS dim.device OWNER TO citus;
*/
--
-- TOC entry 446 (class 1259 OID 2039929)
-- Name: duplicate_items_master; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.duplicate_items_master (
    organizationid text,
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text,
    menuitemid text,
    entitytype text,
    item_class_type integer,
    menuitemname text,
    instance_count integer,
    masteritemid text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.duplicate_items_master OWNER TO citus;

-- Schema evolution: dim.duplicate_items_master
ALTER TABLE IF EXISTS dim.duplicate_items_master
    OWNER to citus;

--
-- TOC entry 500 (class 1259 OID 3600415)
-- Name: element_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS dim.element_elementid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.element_elementid_seq OWNER TO citus;

--
-- TOC entry 380 (class 1259 OID 32829)
-- Name: element; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.element (
    elementid integer DEFAULT nextval('dim.element_elementid_seq'::regclass) NOT NULL,
    sourceelementid text,
    elementname text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.element OWNER TO citus;

ALTER TABLE IF EXISTS dim.element
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;


ALTER TABLE IF EXISTS dim.element
    ALTER COLUMN elementid SET DEFAULT nextval('dim.element_elementid_seq');

--
-- TOC entry 421 (class 1259 OID 419500)
-- Name: experiment; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.experiment (
    dimkey integer NOT NULL,
    data jsonb
);


ALTER TABLE IF EXISTS dim.experiment OWNER TO citus;

--
-- TOC entry 420 (class 1259 OID 419499)
-- Name: experiment_dimkey_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS dim.experiment_dimkey_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.experiment_dimkey_seq OWNER TO citus;

--
-- TOC entry 6578 (class 0 OID 0)
-- Dependencies: 420
-- Name: experiment_dimkey_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.experiment_dimkey_seq OWNED BY dim.experiment.dimkey;
*/

--
-- TOC entry 404 (class 1259 OID 180315)
-- Name: feedbackrating; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.feedbackrating (
    rating text,
    ratingdesc text
);


ALTER TABLE IF EXISTS dim.feedbackrating OWNER TO citus;

--
-- TOC entry 403 (class 1259 OID 180310)
-- Name: feedbackstatus; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.feedbackstatus (
    surveytransstatus text,
    statusdesc text
);


ALTER TABLE IF EXISTS dim.feedbackstatus OWNER TO citus;

--
-- TOC entry 486 (class 1259 OID 3586033)
-- Name: frequentcustomer_customerkey_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS dim.frequentcustomer_customerkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.frequentcustomer_customerkey_seq OWNER TO citus;

--
-- TOC entry 407 (class 1259 OID 245826)
-- Name: frequentcustomer; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.frequentcustomer (
    customerkey bigint DEFAULT nextval('dim.frequentcustomer_customerkey_seq'::regclass) NOT NULL,
    frequentcustomerid text NOT NULL,
    firstname text,
    lastname text,
    email text,
    phone text,
    source text,
    organizationid text,
    createddate text,
    lastorderdate text,
    ordercount integer DEFAULT 0 NOT NULL,
    amountspent numeric DEFAULT 0 NOT NULL,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.frequentcustomer OWNER TO citus;

-- Schema evolution: dim.frequentcustomer
ALTER TABLE IF EXISTS dim.frequentcustomer
    ALTER COLUMN customerkey SET DEFAULT nextval('dim.frequentcustomer_customerkey_seq');

--
-- TOC entry 469 (class 1259 OID 3418396)
-- Name: frequentcustomer_bkp; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.frequentcustomer_bkp (
    customerkey bigint NOT NULL,
    frequentcustomerid text NOT NULL,
    firstname text,
    lastname text,
    email text,
    phone text,
    source text,
    organizationid text,
    createddate text,
    lastorderdate text,
    ordercount integer DEFAULT 0 NOT NULL,
    amountspent numeric DEFAULT 0 NOT NULL,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.frequentcustomer_bkp OWNER TO citus;
*/
--
-- TOC entry 438 (class 1259 OID 762124)
-- Name: grubbrr_source_lookup; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.grubbrr_source_lookup (
    id integer NOT NULL,
    source text,
    description text
);


ALTER TABLE IF EXISTS dim.grubbrr_source_lookup OWNER TO citus;

-- Schema evolution: dim.grubbrr_source_lookup
ALTER TABLE IF EXISTS dim.grubbrr_source_lookup
ALTER COLUMN source TYPE TEXT COLLATE pg_catalog."default",
ALTER COLUMN description TYPE TEXT COLLATE pg_catalog."default";

--
-- TOC entry 440 (class 1259 OID 862882)
-- Name: holidays; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.holidays (
    holiday_name character varying(50),
    celebrated_date timestamp without time zone,
    month integer,
    day integer,
    holiday_type character varying(20),
    religion character varying(20),
    is_public boolean,
    is_dynamic boolean
);


ALTER TABLE IF EXISTS dim.holidays OWNER TO citus;
*/
--
-- TOC entry 451 (class 1259 OID 2669323)
-- Name: item_modifier_group_modifier_mapping; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.item_modifier_group_modifier_mapping (
    catalogid character varying(50) NOT NULL,
    menuitemid character varying(50) NOT NULL,
    modifiergroupid character varying(50) NOT NULL,
    modifierid character varying(50) NOT NULL,
    itm_modgrp_min_selection integer,
    itm_modgrp_max_selection integer,
    itm_modgrp_free_count integer,
    is_itm_modgrp_active boolean,
    is_itm_modgrp_deleted boolean,
    itm_modgrp_created_on timestamp without time zone,
    itm_modgrp_modified_on timestamp without time zone,
    is_itm_modgrp_invisible boolean,
    is_default boolean,
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    default_quantity integer,
    is_modgrp_modfr_active boolean NOT NULL,
    is_modgrp_modfr_deleted boolean NOT NULL,
    modgrp_modfr_created_on timestamp without time zone,
    modgrp_modfr_modified_on timestamp without time zone,
    is_modgrp_modfr_invisible boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.item_modifier_group_modifier_mapping OWNER TO citus;

-- Schema evolution: dim.item_modifier_group_modifier_mapping
ALTER TABLE IF EXISTS dim.item_modifier_group_modifier_mapping
    OWNER to citus;
ALTER TABLE IF EXISTS dim.item_modifier_group_modifier_mapping
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

--
-- TOC entry 493 (class 1259 OID 3587571)
-- Name: itemcategory_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

/*CREATE SEQUENCE IF NOT EXISTS dim.itemcategory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.itemcategory_id_seq OWNER TO citus;
*/
--
-- TOC entry 381 (class 1259 OID 32837)
-- Name: itemcategory; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.itemcategory (
    id bigint DEFAULT nextval('dim.itemcategory_id_seq'::regclass) NOT NULL,
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text NOT NULL,
    isactive boolean,
    catalogid text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    is_category_deleted boolean,
    category_created_on timestamp without time zone,
    category_modified_on timestamp without time zone,
    is_alcoholic boolean,
    number_of_items smallint,
    number_of_sub_categories smallint,
    number_of_item_variations smallint,
    number_of_combos smallint,
    number_of_combo_families smallint
);


ALTER TABLE IF EXISTS dim.itemcategory OWNER TO citus;


-- Schema evolution: dim.itemcategory

ALTER TABLE IF EXISTS dim.itemcategory
ALTER COLUMN isactive DROP NOT NULL,
ALTER COLUMN isactive DROP DEFAULT,
ADD COLUMN IF NOT EXISTS catalogid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS is_category_deleted BOOLEAN,
ADD COLUMN IF NOT EXISTS category_created_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS category_modified_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS is_alcoholic BOOLEAN,
ADD COLUMN IF NOT EXISTS number_of_items SMALLINT,
ADD COLUMN IF NOT EXISTS number_of_sub_categories SMALLINT,
ADD COLUMN IF NOT EXISTS number_of_item_variations SMALLINT,
ADD COLUMN IF NOT EXISTS number_of_combos SMALLINT,
ADD COLUMN IF NOT EXISTS number_of_combo_families SMALLINT;

--ALTER TABLE IF EXISTS dim.itemcategory
--    ALTER COLUMN id SET DEFAULT nextval('dim.itemcategory_id_seq');

--
-- TOC entry 428 (class 1259 OID 514411)
-- Name: itemcategory_bkp; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.itemcategory_bkp (
    id bigint NOT NULL,
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text NOT NULL,
    isactive boolean DEFAULT true NOT NULL
);


ALTER TABLE IF EXISTS dim.itemcategory_bkp OWNER TO citus;
*/
--
-- TOC entry 432 (class 1259 OID 665518)
-- Name: itemcategorymapping; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.itemcategorymapping (
    categoryid character varying(50) NOT NULL,
    menuitemid character varying(50),
    subcategoryid character varying(50),
    isactive boolean,
    isdeleted boolean,
    modifiedon timestamp without time zone,
    locationid text,
    categoryname text,
    menuitemname text
);


ALTER TABLE IF EXISTS dim.itemcategorymapping OWNER TO citus;

--
-- TOC entry 497 (class 1259 OID 3594939)
-- Name: kiosk_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS dim.kiosk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.kiosk_id_seq OWNER TO citus;

--
-- TOC entry 408 (class 1259 OID 311950)
-- Name: kiosk; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.kiosk (
    id bigint DEFAULT nextval('dim.kiosk_id_seq'::regclass) NOT NULL,
    locationid text NOT NULL,
    kioskid text NOT NULL,
    kioskname text,
    serialnumber text,
    appversion text,
    istestkiosk boolean,
    devicetype character varying(50) DEFAULT 'kiosk'::character varying NOT NULL,
    devicecreatedon timestamp without time zone,
    devicedeletedon timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.kiosk OWNER TO citus;

ALTER TABLE IF EXISTS dim.kiosk
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;


--ALTER TABLE IF EXISTS dim.kiosk
--    ALTER COLUMN id SET DEFAULT nextval('dim.kiosk_id_seq');


--
-- TOC entry 431 (class 1259 OID 586491)
-- Name: kioskdetails; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.kioskdetails (
    id text,
    locationid text NOT NULL,
    kiosks text,
    devicetype text,
    syncversion text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    pos_provider text,
    loyalty_provider text,
    payment_provider text,
    scanners text,
    item_special_request text,
    legal_copy_enabled boolean,
    ada_configuration text,
    calculate_default_modifier_price boolean,
    track_kiosk_user_behavior boolean,
    loyalty_feature boolean,
    pickup_flow boolean,
    pos_auto_applied_discount boolean,
    search_functionality_enabled boolean,
    recent_orders_enabled boolean,
    play_card_config text,
    round_up_for_charity boolean,
    calories_enabled boolean,
    scan_and_go_enabled boolean,
    age_verification text,
    tips_settings text,
    business_hours_config text,
    order_types text,
    localization text,
    kiosk_receipt_settings text,
    kiosk_fonts text,
    kiosk_appearance_text_overrides text,
    kiosk_appearance_style_options text,
    loyalty_display_settings text,
    preorder_popup_enabled boolean,
    preorder_popup_text text,
    disclaimer_text text,
    order_limit_config text,
    menu_behavior_config text,
    perform_pos_status_check boolean,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.kioskdetails OWNER TO citus;

-- Schema evolution: dim.kioskdetails
ALTER TABLE IF EXISTS dim.kioskdetails
ADD COLUMN IF NOT EXISTS item_special_request TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS legal_copy_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS ada_configuration TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS calculate_default_modifier_price BOOLEAN,
ADD COLUMN IF NOT EXISTS track_kiosk_user_behavior BOOLEAN,
ADD COLUMN IF NOT EXISTS loyalty_feature BOOLEAN,
ADD COLUMN IF NOT EXISTS pickup_flow BOOLEAN,
ADD COLUMN IF NOT EXISTS pos_auto_applied_discount BOOLEAN,
ADD COLUMN IF NOT EXISTS search_functionality_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS recent_orders_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS play_card_config TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS round_up_for_charity BOOLEAN,
ADD COLUMN IF NOT EXISTS calories_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS scan_and_go_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS age_verification TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS tips_settings TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS business_hours_config TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS order_types TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS localization TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS kiosk_receipt_settings TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS kiosk_fonts TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS kiosk_appearance_text_overrides TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS kiosk_appearance_style_options TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS loyalty_display_settings TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS preorder_popup_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS preorder_popup_text TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS disclaimer_text TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS order_limit_config TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS menu_behavior_config TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS perform_pos_status_check BOOLEAN,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

--
-- TOC entry 382 (class 1259 OID 32863)
-- Name: location; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.location (
    locationid text NOT NULL,
    companyid text NOT NULL,
    locationgroupid text,
    locationname text NOT NULL,
    address1 text,
    address2 text,
    city text,
    state text,
    zipcode text,
    latitude text,
    longitude text,
    timezone text,
    sysinserttime TIMESTAMP,
    sysupdatetime TIMESTAMP
);


ALTER TABLE IF EXISTS dim.location OWNER TO citus;

ALTER TABLE dim.location
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;

--
-- TOC entry 409 (class 1259 OID 327009)
-- Name: locationcatalog; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.locationcatalog (
    id bigint NOT NULL,
    organizationid text NOT NULL,
    locationid text NOT NULL,
    locationname text,
    catalogid text,
    timezone text,
    menuid text
);


ALTER TABLE IF EXISTS dim.locationcatalog OWNER TO citus;
*/
--
-- TOC entry 437 (class 1259 OID 695503)
-- Name: menuentities; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.menuentities (
    catalogid text NOT NULL,
    entityid text NOT NULL,
    entitytype text NOT NULL,
    brand text NOT NULL,
    displayname text,
    description text,
    calories integer,
    protein numeric,
    sugar numeric,
    fat numeric,
    servingsize text,
    price numeric(6,2),
    mealavailability text[],
    modifiers text[],
    tags text[],
    promptcontext text,
    embedding double precision[],
    currency text,
    updatedon timestamp without time zone NOT NULL,
    categories text[],
    tagsreviewedon timestamp without time zone,
    tagsreviewederror text,
    organizationid text,
    locationid text,
    categoryid text,
    item_class_type integer
);


ALTER TABLE IF EXISTS dim.menuentities OWNER TO citus;
*/
--
-- TOC entry 487 (class 1259 OID 3586041)
-- Name: menuitem_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS dim.menuitem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.menuitem_id_seq OWNER TO citus;

--
-- TOC entry 413 (class 1259 OID 359366)
-- Name: menuitem; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.menuitem (
    id bigint DEFAULT nextval('dim.menuitem_id_seq'::regclass) NOT NULL,
    menuitemid text NOT NULL,
    menuitemname text NOT NULL,
    guest integer DEFAULT 1 NOT NULL,
    effective_date date,
    item_class_type integer,
    entitytype text,
    calories text,
    protein numeric,
    sugar numeric,
    fat numeric,
    is_alcoholic boolean,
    is_vegetarian_item boolean,
    is_vegan_item boolean,
    has_allergen boolean,
    is_active boolean,
    is_deleted boolean,
    gms_created_on timestamp without time zone,
    gms_modified_on timestamp without time zone,
    itemunitprice numeric(12,3),
    price_changed_on timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    catalogid text,
    average_rating NUMERIC(3,2),
    rating_count INTEGER
);


ALTER TABLE IF EXISTS dim.menuitem OWNER TO citus;

ALTER TABLE IF EXISTS dim.menuitem
    ALTER COLUMN id SET DEFAULT nextval('dim.menuitem_id_seq');


-- Schema evolution: dim.menuitem

ALTER TABLE IF EXISTS dim.menuitem
ADD COLUMN IF NOT EXISTS item_class_type integer,
ADD COLUMN IF NOT EXISTS entitytype TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS calories TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS protein numeric,
ADD COLUMN IF NOT EXISTS sugar numeric,
ADD COLUMN IF NOT EXISTS fat numeric,
ADD COLUMN IF NOT EXISTS is_alcoholic BOOLEAN,
ADD COLUMN IF NOT EXISTS is_vegetarian_item BOOLEAN,
ADD COLUMN IF NOT EXISTS is_vegan_item BOOLEAN,
ADD COLUMN IF NOT EXISTS has_allergen BOOLEAN,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN,
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN,
ADD COLUMN IF NOT EXISTS gms_created_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS gms_modified_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS itemunitprice NUMERIC(12, 3),
ADD COLUMN IF NOT EXISTS price_changed_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP,
ADD COLUMN IF NOT EXISTS catalogid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS average_rating NUMERIC(3,2),
ADD COLUMN IF NOT EXISTS rating_count INTEGER;


--
-- TOC entry 448 (class 1259 OID 2196057)
-- Name: modifier; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.modifier (
    modifierid character varying(50) NOT NULL,
    catalogid character varying(50),
    modifiername character varying(255),
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    calories text NOT NULL,
    calories_text text,
    is_modifier_active boolean NOT NULL,
    is_modifier_deleted boolean NOT NULL,
    modifier_created_on timestamp without time zone,
    modifier_modified_on timestamp without time zone,
    is_modifier_default boolean,
    modifier_default_quantity integer,
    is_invisible boolean,
    classification integer,
    price numeric(12,3),
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    price_changed_on timestamp without time zone
);


ALTER TABLE IF EXISTS dim.modifier OWNER TO citus;

-- Schema evolution: dim.modifier

ALTER TABLE IF EXISTS dim.modifier
DROP COLUMN IF EXISTS modifierkey,
ADD COLUMN IF NOT EXISTS price_changed_on TIMESTAMP;

--
-- TOC entry 457 (class 1259 OID 2951551)
-- Name: modifier_group; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.modifier_group (
    modifiergroupid character varying(50) NOT NULL,
    modifiergroupname character varying(510) NOT NULL,
    catalogid character varying(50) NOT NULL,
    max_selection integer,
    min_selection integer,
    free_count integer,
    pos_linked_entity_id character varying(50),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    negative_modifier_behavior integer,
    created_by character varying(255),
    modified_by character varying(255),
    max_aggregate_count integer,
    min_aggregate_count integer,
    increment_step integer,
    slider_mode boolean DEFAULT false NOT NULL,
    slider_mode_modifier boolean DEFAULT false NOT NULL,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.modifier_group OWNER TO citus;

-- Schema evolution: dim.modifier_group


--
-- TOC entry 449 (class 1259 OID 2196809)
-- Name: modifier_group_mapping; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.modifier_group_mapping (
    modifier_mapping_id character varying(50) NOT NULL,
    modifierid character varying(50) NOT NULL,
    modifiergroupid character varying(50) NOT NULL,
    catalogid character varying(50),
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_default boolean,
    default_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    min_quantity integer,
    max_quantity integer,
    calories_text text,
    is_invisible boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.modifier_group_mapping OWNER TO citus;

-- Schema evolution: dim.modifier_group_mapping
ALTER TABLE IF EXISTS dim.modifier_group_mapping
    OWNER to citus;

--
-- TOC entry 504 (class 1259 OID 3608697)
-- Name: occasionsurvey_surveykey_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS dim.occasionsurvey_surveykey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.occasionsurvey_surveykey_seq OWNER TO citus;

--
-- TOC entry 466 (class 1259 OID 3087656)
-- Name: occasionsurvey; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.occasionsurvey (
    surveykey bigint DEFAULT nextval('dim.occasionsurvey_surveykey_seq'::regclass) NOT NULL,
    organizationid text NOT NULL,
    surveyid text NOT NULL,
    surveyname text,
    surveytype integer,
    question_type integer,
    selection_type integer,
    survey_status integer,
    is_deleted boolean,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.occasionsurvey OWNER TO citus;


ALTER TABLE IF EXISTS dim.occasionsurvey
    ALTER COLUMN surveytype TYPE INTEGER USING surveytype::INTEGER,
    ALTER COLUMN surveykey DROP IDENTITY IF EXISTS,
    ALTER COLUMN surveykey SET DEFAULT nextval('dim.occasionsurvey_surveykey_seq');


-- Schema evolution: dim.occasionsurvey

ALTER TABLE IF EXISTS dim.occasionsurvey
ADD COLUMN IF NOT EXISTS question_type INTEGER,
ADD COLUMN IF NOT EXISTS selection_type INTEGER,
ADD COLUMN IF NOT EXISTS survey_status INTEGER, 
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN, 
ADD COLUMN IF NOT EXISTS created_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS modified_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

--
-- TOC entry 498 (class 1259 OID 3598983)
-- Name: ordertype_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS dim.ordertype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.ordertype_id_seq OWNER TO citus;

--
-- TOC entry 383 (class 1259 OID 32880)
-- Name: ordertype; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.ordertype (
    id bigint DEFAULT nextval('dim.ordertype_id_seq'::regclass) NOT NULL,
    locationid text NOT NULL,
    kioskid text NOT NULL,
    ordertypeid text NOT NULL,
    ordertypelabel text NOT NULL,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.ordertype OWNER TO citus;

--ALTER TABLE IF EXISTS dim.ordertype
--    ALTER COLUMN id SET DEFAULT nextval('dim.ordertype_id_seq');

ALTER TABLE IF EXISTS dim.ordertype
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;


--
-- TOC entry 433 (class 1259 OID 672293)
-- Name: ordertype_bkp; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.ordertype_bkp (
    id bigint NOT NULL,
    locationid text NOT NULL,
    kioskid text NOT NULL,
    ordertypeid text NOT NULL,
    ordertypelabel text NOT NULL
);


ALTER TABLE IF EXISTS dim.ordertype_bkp OWNER TO citus;
*/
--
-- TOC entry 422 (class 1259 OID 431156)
-- Name: organization; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.organization (
    id character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    address1 character varying(255),
    address2 character varying(255),
    city character varying(255),
    state character varying(255),
    zipcode character varying(20),
    country character varying(255),
    organizationtype smallint,
    status smallint,
    phonenumber character varying(20),
    email character varying(255),
    isdeleted boolean DEFAULT false,
    createdon timestamp without time zone,
    createdby character varying(255),
    modifiedon timestamp without time zone,
    modifiedby character varying(255),
    active boolean,
    timezone character varying(50),
    coordinates text,
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
    cep_subscriptions text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.organization OWNER TO citus;

-- Schema evolution: dim.organization
ALTER TABLE IF EXISTS dim.organization
ADD COLUMN IF NOT EXISTS cep_subscriptions TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

--
-- TOC entry 384 (class 1259 OID 32888)
-- Name: organizationlocation; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.organizationlocation (
    organizationid character varying(40) NOT NULL,
    organizationname character varying(255),
    locationid character varying(40) NOT NULL,
    locationname character varying(255) NOT NULL,
    organizationtype smallint,
    roundupforcharity boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.organizationlocation OWNER TO citus;

-- Schema evolution: dim.organizationlocation
ALTER TABLE IF EXISTS dim.organizationlocation
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;

--
-- TOC entry 417 (class 1259 OID 413638)
-- Name: peripheral; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.peripheral (
    id bigint NOT NULL,
    deviceid bigint,
    peripheralid character varying(50) NOT NULL,
    peripheraltype character varying(50) NOT NULL,
    state character varying(50) NOT NULL,
    previousstate character varying(50),
    statechangedate timestamp without time zone,
    description text,
    model text,
    serial text,
    ipaddress character varying(50)
);


ALTER TABLE IF EXISTS dim.peripheral OWNER TO citus;
*/
--
-- TOC entry 427 (class 1259 OID 471773)
-- Name: upsellgrouplookup; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.upsellgrouplookup (
    upsellgroupid character varying(50) NOT NULL,
    upsellgroupname text,
    isactive boolean,
    createdon timestamp without time zone,
    modifiedon timestamp without time zone,
    catalogid text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.upsellgrouplookup OWNER TO citus;

ALTER TABLE IF EXISTS dim.upsellgrouplookup
ADD COLUMN IF NOT EXISTS catalogid text COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;


--
-- TOC entry 400 (class 1259 OID 103200)
-- Name: userlocation; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.userlocation (
    userid character varying(40) NOT NULL,
    locationid character varying(40) NOT NULL,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.userlocation OWNER TO citus;

-- Schema evolution: dim.userlocation
ALTER TABLE IF EXISTS dim.userlocation
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE;

--
-- TOC entry 501 (class 1259 OID 3601732)
-- Name: view_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS dim.view_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.view_id_seq OWNER TO citus;

--
-- TOC entry 385 (class 1259 OID 32906)
-- Name: view; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.view (
    viewid integer DEFAULT nextval('dim.view_id_seq'::regclass),
    viewname text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.view OWNER TO citus;

ALTER TABLE IF EXISTS dim.view
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;


ALTER TABLE IF EXISTS dim.view
    ALTER COLUMN viewid SET DEFAULT nextval('dim.view_id_seq');


--
-- TOC entry 439 (class 1259 OID 806155)
-- Name: vw_grubbrrinstallbase; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.vw_grubbrrinstallbase (
    organization_id character varying(50) NOT NULL,
    organization_name text NOT NULL,
    location_id character varying(50) NOT NULL,
    location_name text NOT NULL,
    kiosk_id character varying(50) NOT NULL,
    kiosk_name text,
    kiosk_hardware_id character varying(50),
    kiosk_software_version character varying(50),
    os_type character varying(50),
    serial_number character varying(50),
    is_test_mode boolean,
    is_demo_kiosk boolean,
    is_test_mode_on boolean,
    last_login_time timestamp without time zone,
    last_sync_time timestamp without time zone,
    device_created_on timestamp without time zone,
    device_deleted_on timestamp without time zone,
    is_test_kiosk boolean,
    device_type character varying(50),
    is_activated boolean,
    payment_integration_configs jsonb,
    printer_configs jsonb,
    kiosk_activation character varying(50),
    is_kiosk_deleted boolean,
    kiosk_mode character varying(10),
    kiosk_logging integer,
    is_goast_kiosk boolean,
    loyalty_login_otp character varying(50),
    pos_provider jsonb,
    payment_provider jsonb,
    payment_device_type character varying(50),
    loyalty_provider jsonb,
    scanners jsonb,
    organization_status character varying(20),
    location_status character varying(20),
    is_org_active boolean,
    is_loc_active boolean,
    is_org_deleted boolean,
    is_loc_deleted boolean,
    org_go_live_date timestamp without time zone,
    loc_go_live_date timestamp without time zone,
    org_created_date timestamp without time zone,
    loc_created_date timestamp without time zone,
    is_org_ecm_enabled boolean,
    is_org_cep_enabled boolean,
    is_org_concessionaire_enabled boolean,
    is_org_smart_upsells_enabled boolean,
    is_org_feedback_survey_enabled boolean,
    is_org_digital_menu_board_enabled boolean,
    is_org_digital_menu_default_format_enabled boolean,
    is_loc_ecm_enabled boolean,
    is_loc_cep_enabled boolean,
    is_loc_concessionaire_enabled boolean,
    is_loc_smart_upsells_enabled boolean,
    is_loc_feedback_survey_enabled boolean,
    is_loc_digital_menu_board_enabled boolean,
    is_loc_digital_menu_default_format_enabled boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    item_special_request jsonb,
    legal_copy_enabled boolean,
    ada_configuration jsonb,
    calculate_default_modifier_price boolean,
    track_kiosk_user_behavior boolean,
    loyalty_feature boolean,
    pickup_flow boolean,
    pos_auto_applied_discount boolean,
    search_functionality_enabled boolean,
    recent_orders_enabled boolean,
    play_card_config jsonb,
    round_up_for_charity boolean,
    calories_enabled boolean,
    scan_and_go_enabled boolean,
    age_verification jsonb,
    tips_enabled boolean,
    apply_before_taxes boolean,
    auto_print_enabled boolean,
    include_pos_order_number boolean,
    show_qr_code_when_print_receipt_fails boolean,
    print_modifier_group_names boolean,
    print_default_modifiers boolean,
    print_free_modifiers boolean,
    print_priced_modifiers boolean,
    enable_email_receipts boolean,
    enable_sms_receipt boolean,
    qr_code_for_receipt boolean,
    show_screensaver boolean,
    business_hours_show_message boolean,
    business_hours_enabled boolean,
    pos_hours_enabled boolean,
    quantity_limit_per_item integer,
    quantity_limit_per_order integer,
    max_discount_per_order integer,
    show_item_asis_option boolean,
    enable_minimum_order_total boolean,
    auto_apply_min_qty_to_first_modifier boolean,
    show_make_it_a_meal_option boolean,
    enable_combo_auto_skip boolean,
    number_of_item_upsell_prompts_per_order integer,
    can_enter_code_for_discount boolean,
    can_scan_qr_code_for_discount boolean,
    can_select_from_list_for_discount boolean,
    enabled_languages jsonb,
    display_modifier_group_restriction boolean,
    allow_user_to_collapse_or_expand_modifier_groups boolean,
    show_modifier_group_names_on_order_review boolean,
    show_default_modifier_on_order_review boolean,
    auto_expand_modifier_group boolean,
    enable_nested_modifier_indentation boolean,
    open_nested_modifiers_in_popup boolean,
    category_header_display_mode text,
    category_header_logo_display_mode text,
    show_item_description boolean,
    category_name_position text,
    hide_sold_out_item_and_modifier_on_kiosk boolean,
    make_category_sidebar_translucent boolean,
    enable_single_step_subcategory_flow boolean,
    remove_category_highlighted_border boolean,
    enable_extended_combo_mode boolean,
    button_style text,
    show_discount_code_button boolean,
    make_item_combo_images_rounded boolean,
    show_loyalty_points_on_header boolean,
    show_card_accepted_payment_options boolean,
    show_google_pay_accepted_payment_options boolean,
    show_apple_pay_accepted_payment_options boolean,
    show_cash_accepted_payment_options boolean,
    show_tap_to_order_cta boolean,
    use_text_for_cta boolean,
    use_image_for_cta boolean,
    choose_a_currency jsonb,
    choose_a_locale text,
    order_number_start integer,
    allotment integer,
    negative_modifier_behavior jsonb,
    disclaimer_text text,
    preorder_popup_enabled boolean,
    preorder_popup_text text,
    order_types_identity_config jsonb,
    show_category_highlighted_color boolean,
    cep_subscriptions jsonb,
    perform_pos_status_check boolean
);


ALTER TABLE IF EXISTS dim.vw_grubbrrinstallbase OWNER TO citus;

-- Schema evolution: dim.vw_grubbrrinstallbase
ALTER TABLE IF EXISTS dim.vw_grubbrrinstallbase-- kioskdetails
ADD COLUMN IF NOT EXISTS item_special_request jsonb,
ADD COLUMN IF NOT EXISTS legal_copy_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS ada_configuration jsonb,
ADD COLUMN IF NOT EXISTS calculate_default_modifier_price BOOLEAN,
ADD COLUMN IF NOT EXISTS track_kiosk_user_behavior BOOLEAN,
ADD COLUMN IF NOT EXISTS loyalty_feature BOOLEAN,
ADD COLUMN IF NOT EXISTS pickup_flow BOOLEAN,
ADD COLUMN IF NOT EXISTS pos_auto_applied_discount BOOLEAN,
ADD COLUMN IF NOT EXISTS search_functionality_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS recent_orders_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS play_card_config jsonb,
ADD COLUMN IF NOT EXISTS round_up_for_charity BOOLEAN,
ADD COLUMN IF NOT EXISTS calories_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS scan_and_go_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS age_verification jsonb,
ADD COLUMN IF NOT EXISTS tips_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS apply_before_taxes BOOLEAN,
ADD COLUMN IF NOT EXISTS auto_print_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS include_pos_order_number BOOLEAN,
ADD COLUMN IF NOT EXISTS show_qr_code_when_print_receipt_fails BOOLEAN,
ADD COLUMN IF NOT EXISTS print_modifier_group_names BOOLEAN,
ADD COLUMN IF NOT EXISTS print_default_modifiers BOOLEAN,
ADD COLUMN IF NOT EXISTS print_free_modifiers BOOLEAN,
ADD COLUMN IF NOT EXISTS print_priced_modifiers BOOLEAN,
ADD COLUMN IF NOT EXISTS enable_email_receipts BOOLEAN,
ADD COLUMN IF NOT EXISTS enable_sms_receipt BOOLEAN,
ADD COLUMN IF NOT EXISTS qr_code_for_receipt BOOLEAN,
ADD COLUMN IF NOT EXISTS show_screensaver BOOLEAN,
ADD COLUMN IF NOT EXISTS business_hours_show_message BOOLEAN,
ADD COLUMN IF NOT EXISTS business_hours_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS pos_hours_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS quantity_limit_per_item INTEGER,
ADD COLUMN IF NOT EXISTS quantity_limit_per_order INTEGER,
ADD COLUMN IF NOT EXISTS max_discount_per_order INTEGER,
ADD COLUMN IF NOT EXISTS show_item_asis_option BOOLEAN,
ADD COLUMN IF NOT EXISTS enable_minimum_order_total BOOLEAN,
ADD COLUMN IF NOT EXISTS auto_apply_min_qty_to_first_modifier BOOLEAN,
ADD COLUMN IF NOT EXISTS show_make_it_a_meal_option BOOLEAN,
ADD COLUMN IF NOT EXISTS enable_combo_auto_skip BOOLEAN,
ADD COLUMN IF NOT EXISTS number_of_item_upsell_prompts_per_order INTEGER,
ADD COLUMN IF NOT EXISTS can_enter_code_for_discount BOOLEAN,
ADD COLUMN IF NOT EXISTS can_scan_qr_code_for_discount BOOLEAN,
ADD COLUMN IF NOT EXISTS can_select_from_list_for_discount BOOLEAN,
ADD COLUMN IF NOT EXISTS enabled_languages jsonb,
ADD COLUMN IF NOT EXISTS display_modifier_group_restriction BOOLEAN,
ADD COLUMN IF NOT EXISTS allow_user_to_collapse_or_expand_modifier_groups BOOLEAN,
ADD COLUMN IF NOT EXISTS show_modifier_group_names_on_order_review BOOLEAN,
ADD COLUMN IF NOT EXISTS show_default_modifier_on_order_review BOOLEAN,
ADD COLUMN IF NOT EXISTS auto_expand_modifier_group BOOLEAN,
ADD COLUMN IF NOT EXISTS enable_nested_modifier_indentation BOOLEAN,
ADD COLUMN IF NOT EXISTS open_nested_modifiers_in_popup BOOLEAN,
ADD COLUMN IF NOT EXISTS category_header_display_mode TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS category_header_logo_display_mode TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS show_item_description BOOLEAN,
ADD COLUMN IF NOT EXISTS category_name_position TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS hide_sold_out_item_and_modifier_on_kiosk BOOLEAN,
ADD COLUMN IF NOT EXISTS make_category_sidebar_translucent BOOLEAN,
ADD COLUMN IF NOT EXISTS enable_single_step_subcategory_flow BOOLEAN,
ADD COLUMN IF NOT EXISTS remove_category_highlighted_border BOOLEAN,
ADD COLUMN IF NOT EXISTS enable_extended_combo_mode BOOLEAN,
ADD COLUMN IF NOT EXISTS button_style TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS show_discount_code_button BOOLEAN,
ADD COLUMN IF NOT EXISTS make_item_combo_images_rounded BOOLEAN,
ADD COLUMN IF NOT EXISTS show_loyalty_points_on_header BOOLEAN,
ADD COLUMN IF NOT EXISTS show_card_accepted_payment_options BOOLEAN,
ADD COLUMN IF NOT EXISTS show_google_pay_accepted_payment_options BOOLEAN,
ADD COLUMN IF NOT EXISTS show_apple_pay_accepted_payment_options BOOLEAN,
ADD COLUMN IF NOT EXISTS show_cash_accepted_payment_options BOOLEAN,
ADD COLUMN IF NOT EXISTS show_tap_to_order_cta BOOLEAN,
ADD COLUMN IF NOT EXISTS use_text_for_cta BOOLEAN,
ADD COLUMN IF NOT EXISTS use_image_for_cta BOOLEAN,
ADD COLUMN IF NOT EXISTS choose_a_currency jsonb,
ADD COLUMN IF NOT EXISTS choose_a_locale TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS order_number_start INTEGER,
ADD COLUMN IF NOT EXISTS allotment INTEGER,
ADD COLUMN IF NOT EXISTS negative_modifier_behavior jsonb,
ADD COLUMN IF NOT EXISTS disclaimer_text TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS preorder_popup_enabled BOOLEAN,
ADD COLUMN IF NOT EXISTS preorder_popup_text TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS order_types_identity_config jsonb,
ADD COLUMN IF NOT EXISTS show_category_highlighted_color BOOLEAN,
ADD COLUMN IF NOT EXISTS cep_subscriptions jsonb,
ADD COLUMN IF NOT EXISTS perform_pos_status_check BOOLEAN;

--
-- TOC entry 468 (class 1259 OID 3327442)
-- Name: vw_grubbrrinstallbase_all_devices; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.vw_grubbrrinstallbase_all_devices (
    organization_id character varying(50) NOT NULL,
    organization_name text NOT NULL,
    location_id character varying(50) NOT NULL,
    location_name text NOT NULL,
    kiosk_id character varying(50) NOT NULL,
    kiosk_name text,
    kiosk_hardware_id character varying(50),
    kiosk_software_version character varying(50),
    os_type character varying(50),
    serial_number character varying(50),
    is_test_mode boolean,
    is_demo_kiosk boolean,
    is_test_mode_on boolean,
    last_login_time timestamp without time zone,
    last_sync_time timestamp without time zone,
    device_created_on timestamp without time zone,
    device_deleted_on timestamp without time zone,
    is_test_kiosk boolean,
    device_type character varying(50),
    is_activated boolean,
    payment_integration_configs jsonb,
    printer_configs jsonb,
    kiosk_activation character varying(50),
    is_kiosk_deleted boolean,
    kiosk_mode character varying(10),
    kiosk_logging integer,
    is_goast_kiosk boolean,
    loyalty_login_otp character varying(50),
    pos_provider jsonb,
    payment_provider jsonb,
    payment_device_type character varying(50),
    loyalty_provider jsonb,
    scanners jsonb,
    organization_status character varying(20),
    location_status character varying(20),
    is_org_active boolean,
    is_loc_active boolean,
    is_org_deleted boolean,
    is_loc_deleted boolean,
    org_go_live_date timestamp without time zone,
    loc_go_live_date timestamp without time zone,
    org_created_date timestamp without time zone,
    loc_created_date timestamp without time zone,
    is_org_ecm_enabled boolean,
    is_org_cep_enabled boolean,
    is_org_concessionaire_enabled boolean,
    is_org_smart_upsells_enabled boolean,
    is_org_feedback_survey_enabled boolean,
    is_org_digital_menu_board_enabled boolean,
    is_org_digital_menu_default_format_enabled boolean,
    is_loc_ecm_enabled boolean,
    is_loc_cep_enabled boolean,
    is_loc_concessionaire_enabled boolean,
    is_loc_smart_upsells_enabled boolean,
    is_loc_feedback_survey_enabled boolean,
    is_loc_digital_menu_board_enabled boolean,
    is_loc_digital_menu_default_format_enabled boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    item_special_request jsonb,
    legal_copy_enabled boolean,
    ada_configuration jsonb,
    calculate_default_modifier_price boolean,
    track_kiosk_user_behavior boolean,
    loyalty_feature boolean,
    pickup_flow boolean,
    pos_auto_applied_discount boolean,
    search_functionality_enabled boolean,
    recent_orders_enabled boolean,
    play_card_config jsonb,
    round_up_for_charity boolean,
    calories_enabled boolean,
    scan_and_go_enabled boolean,
    age_verification jsonb,
    tips_enabled boolean,
    apply_before_taxes boolean,
    auto_print_enabled boolean,
    include_pos_order_number boolean,
    show_qr_code_when_print_receipt_fails boolean,
    print_modifier_group_names boolean,
    print_default_modifiers boolean,
    print_free_modifiers boolean,
    print_priced_modifiers boolean,
    enable_email_receipts boolean,
    enable_sms_receipt boolean,
    qr_code_for_receipt boolean,
    show_screensaver boolean,
    business_hours_show_message boolean,
    business_hours_enabled boolean,
    pos_hours_enabled boolean,
    quantity_limit_per_item integer,
    quantity_limit_per_order integer,
    max_discount_per_order integer,
    show_item_asis_option boolean,
    enable_minimum_order_total boolean,
    auto_apply_min_qty_to_first_modifier boolean,
    show_make_it_a_meal_option boolean,
    enable_combo_auto_skip boolean,
    number_of_item_upsell_prompts_per_order integer,
    can_enter_code_for_discount boolean,
    can_scan_qr_code_for_discount boolean,
    can_select_from_list_for_discount boolean,
    enabled_languages jsonb,
    display_modifier_group_restriction boolean,
    allow_user_to_collapse_or_expand_modifier_groups boolean,
    show_modifier_group_names_on_order_review boolean,
    show_default_modifier_on_order_review boolean,
    auto_expand_modifier_group boolean,
    enable_nested_modifier_indentation boolean,
    open_nested_modifiers_in_popup boolean,
    category_header_display_mode text,
    category_header_logo_display_mode text,
    show_item_description boolean,
    category_name_position text,
    hide_sold_out_item_and_modifier_on_kiosk boolean,
    make_category_sidebar_translucent boolean,
    enable_single_step_subcategory_flow boolean,
    remove_category_highlighted_border boolean,
    enable_extended_combo_mode boolean,
    button_style text,
    show_discount_code_button boolean,
    make_item_combo_images_rounded boolean,
    show_loyalty_points_on_header boolean,
    show_card_accepted_payment_options boolean,
    show_google_pay_accepted_payment_options boolean,
    show_apple_pay_accepted_payment_options boolean,
    show_cash_accepted_payment_options boolean,
    show_tap_to_order_cta boolean,
    use_text_for_cta boolean,
    use_image_for_cta boolean,
    choose_a_currency jsonb,
    choose_a_locale text,
    order_number_start integer,
    allotment integer,
    negative_modifier_behavior jsonb,
    disclaimer_text text,
    preorder_popup_enabled boolean,
    preorder_popup_text text,
    order_types_identity_config jsonb,
    show_category_highlighted_color boolean,
    cep_subscriptions jsonb,
    perform_pos_status_check boolean
);


ALTER TABLE IF EXISTS dim.vw_grubbrrinstallbase_all_devices OWNER TO citus;

--
-- TOC entry 415 (class 1259 OID 393489)
-- Name: weather; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE IF NOT EXISTS dim.weather (
    organizationid text,
    locationid text NOT NULL,
    city text,
    timezone text,
    apicalldate date NOT NULL,
    locationinfo jsonb,
    weatherinfo jsonb,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


--ALTER TABLE IF EXISTS dim.weather OWNER TO citus;

--
-- TOC entry 444 (class 1259 OID 1236960)
-- Name: vw_weatherhourlydata; Type: VIEW; Schema: dim; Owner: citus
--

CREATE OR REPLACE VIEW dim.vw_weatherhourlydata AS
 SELECT w.locationid,
    ((w.weatherinfo ->> 'Date'::text))::date AS weatherdate,
    ((hour_entry.hour_data ->> 'Hour'::text))::integer AS hh,
    ((hour_entry.hour_data ->> 'Humidity'::text))::integer AS humidity,
    (hour_entry.hour_data ->> 'Condition'::text) AS condition,
    ((hour_entry.hour_data ->> 'TemperatureInCelcius'::text))::numeric(8,2) AS temperature_c,
    ((hour_entry.hour_data ->> 'IsHot'::text))::boolean AS is_hot,
    ((hour_entry.hour_data ->> 'IsCalm'::text))::boolean AS is_calm,
    ((hour_entry.hour_data ->> 'IsCold'::text))::boolean AS is_cold,
    ((hour_entry.hour_data ->> 'IsCool'::text))::boolean AS is_cool,
    ((hour_entry.hour_data ->> 'IsMild'::text))::boolean AS is_mild,
    ((hour_entry.hour_data ->> 'IsWarm'::text))::boolean AS is_warm,
    ((hour_entry.hour_data ->> 'RainMm'::text))::numeric(8,2) AS rain_mm,
    ((hour_entry.hour_data ->> 'IsSunny'::text))::boolean AS is_sunny,
    ((hour_entry.hour_data ->> 'IsWindy'::text))::boolean AS is_windy,
    ((hour_entry.hour_data ->> 'IsCloudy'::text))::boolean AS is_cloudy,
    ((hour_entry.hour_data ->> 'IsDaytime'::text))::boolean AS is_daytime,
    ((hour_entry.hour_data ->> 'IsRaining'::text))::boolean AS is_raining,
    ((hour_entry.hour_data ->> 'IsSnowing'::text))::boolean AS is_snowing,
    ((hour_entry.hour_data ->> 'IsVeryHot'::text))::boolean AS is_very_hot,
    ((hour_entry.hour_data ->> 'IsFreezing'::text))::boolean AS is_freezing,
    ((hour_entry.hour_data ->> 'IsOvercast'::text))::boolean AS is_overcast,
    ((hour_entry.hour_data ->> 'SnowfallMm'::text))::numeric(8,2) AS snowfall_mm,
    (hour_entry.hour_data ->> 'TempBucket'::text) AS temp_bucket,
    (hour_entry.hour_data ->> 'WindBucket'::text) AS wind_bucket,
    ((hour_entry.hour_data ->> 'FeelsColder'::text))::boolean AS feels_colder,
    ((hour_entry.hour_data ->> 'FeelsHotter'::text))::boolean AS feels_hotter,
    (hour_entry.hour_data ->> 'FoodWeather'::text) AS food_weather,
    ((hour_entry.hour_data ->> 'IsHeavyRain'::text))::boolean AS is_heavy_rain,
    ((hour_entry.hour_data ->> 'IsLightRain'::text))::boolean AS is_light_rain,
    ((hour_entry.hour_data ->> 'IsNighttime'::text))::boolean AS is_nighttime,
    ((hour_entry.hour_data ->> 'IsVeryWindy'::text))::boolean AS is_very_windy,
    ((hour_entry.hour_data ->> 'PressureHpa'::text))::numeric(8,2) AS pressure_hpa,
    ((hour_entry.hour_data ->> 'WeatherCode'::text))::integer AS weather_code,
    ((hour_entry.hour_data ->> 'WindGustKmh'::text))::numeric(8,2) AS wind_gust_kmh,
    ((hour_entry.hour_data ->> 'ComfortScore'::text))::integer AS comfort_score,
    (hour_entry.hour_data ->> 'DrinkWeather'::text) AS drink_weather,
    ((hour_entry.hour_data ->> 'WindSpeedKmh'::text))::numeric(8,2) AS wind_speed_kmh,
    (hour_entry.hour_data ->> 'ComfortBucket'::text) AS comfort_bucket,
    (hour_entry.hour_data ->> 'HumidityBucket'::text) AS humidity_bucket,
    (hour_entry.hour_data ->> 'ConditionBucket'::text) AS condition_bucket,
    ((hour_entry.hour_data ->> 'IsPrecipitating'::text))::boolean AS is_precipitating,
    ((hour_entry.hour_data ->> 'PrecipitationMm'::text))::numeric(8,2) AS precipitation_mm,
    ((hour_entry.hour_data ->> 'VisibilityMeters'::text))::numeric(8,2) AS visibility_meters,
    ((hour_entry.hour_data ->> 'CloudCoverPercent'::text))::numeric(8,2) AS cloud_cover_percent,
    ((hour_entry.hour_data ->> 'IsUnseasonablyHot'::text))::boolean AS is_unseasonably_hot,
    ((hour_entry.hour_data ->> 'IsUnseasonablyCold'::text))::boolean AS is_unseasonably_cold,
    ((hour_entry.hour_data ->> 'OutdoorDiningScore'::text))::integer AS outdoor_dining_score,
    ((hour_entry.hour_data ->> 'WindDirectionDegrees'::text))::integer AS wind_direction_degrees,
    ((hour_entry.hour_data ->> 'PrecipitationProbability'::text))::numeric(8,2) AS precipitation_probability,
    ((hour_entry.hour_data ->> 'ApparentTemperatureCelsius'::text))::numeric(8,2) AS apparent_temperature_celsius
   FROM (dim.weather w
     CROSS JOIN LATERAL jsonb_each((w.weatherinfo -> 'Hours'::text)) hour_entry(hour_key, hour_data))
  WHERE ((w.weatherinfo)::text ~~ '{"Date":%'::text);


ALTER VIEW dim.vw_weatherhourlydata OWNER TO citus;

--
-- TOC entry 387 (class 1259 OID 32917)
-- Name: vworganizationlocation; Type: VIEW; Schema: dim; Owner: citus
--
/*
CREATE OR REPLACE VIEW dim.vworganizationlocation AS
 WITH base AS (
         WITH cur AS (
                 SELECT d.dateid,
                    d.datets,
                    d.hourofday,
                    d.dayval,
                    d.daynum,
                    d.dayname,
                    d.weekval,
                    d.monthval,
                    d.monthname,
                    d.quarterval,
                    d.yearval,
                    d.daypart,
                    d.dayofyear
                   FROM dim.datedim d
                  WHERE ((d.yearval)::numeric = EXTRACT(year FROM now()))
                ), pre AS (
                 SELECT d.dateid,
                    d.datets,
                    d.hourofday,
                    d.dayval,
                    d.daynum,
                    d.dayname,
                    d.weekval,
                    d.monthval,
                    d.monthname,
                    d.quarterval,
                    d.yearval,
                    d.daypart,
                    d.dayofyear
                   FROM dim.datedim d
                  WHERE ((d.yearval)::numeric = EXTRACT(year FROM (now() - '1 year'::interval)))
                )
         SELECT DISTINCT (((p.yearval || to_char((c.dayval)::timestamp with time zone, 'MMDD'::text)) || "substring"(c.hourofday, 1, 2)))::integer AS dateid,
            p.hourofday,
            p.daynum,
            p.dayname,
            p.weekval,
            c.monthval,
            c.monthname,
            c.quarterval,
            p.yearval,
            p.daypart
           FROM (cur c
             LEFT JOIN pre p ON (((p.weekval = c.weekval) AND (p.dayname = c.dayname) AND (p.hourofday = c.hourofday))))
          ORDER BY p.daypart, c.quarterval, p.dayname
        )
 SELECT base.dateid,
    base.hourofday,
    base.daynum,
    base.dayname,
    base.weekval,
    base.monthval,
    base.monthname,
    base.quarterval,
    base.yearval,
    base.daypart
   FROM base
UNION
 SELECT d.dateid,
    d.hourofday,
    d.daynum,
    d.dayname,
    d.weekval,
    d.monthval,
    d.monthname,
    d.quarterval,
    d.yearval,
    d.daypart
   FROM dim.datedim d
  WHERE ((d.yearval)::numeric = EXTRACT(year FROM now()))
  ORDER BY 1, 2, 4;


ALTER VIEW dim.vworganizationlocation OWNER TO citus;
*/
--
-- TOC entry 414 (class 1259 OID 387340)
-- Name: weather_bkp; Type: TABLE; Schema: dim; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS dim.weather_bkp (
    organizationid text,
    locationid text NOT NULL,
    city text,
    timezone text,
    businessdate date NOT NULL,
    weatherinfo jsonb,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS dim.weather_bkp OWNER TO citus;
*/
--
-- TOC entry 474 (class 1259 OID 3518722)
-- Name: bronze_partition_registry; Type: TABLE; Schema: etl; Owner: citus
--

CREATE TABLE IF NOT EXISTS etl.bronze_partition_registry (
    dateid integer NOT NULL,
    layer text,
    entity text NOT NULL,
    partition_path text,
    partition_date date,
    partition_year smallint,
    partition_month smallint,
    partition_day smallint,
    partition_hour smallint,
    status text DEFAULT 'pending'::text,
    file_count integer,
    started_at timestamp without time zone,
    completed_at timestamp without time zone,
    adf_pipeline_run_id text,
    error_message text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS etl.bronze_partition_registry OWNER TO citus;

--
-- TOC entry 443 (class 1259 OID 1071621)
-- Name: cep_incidents; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.gem_failed_order_job_notifications
(
    incidentid          BIGINT,
    application         TEXT    COLLATE pg_catalog."default",
    organizationid      TEXT    COLLATE pg_catalog."default",
    locationid          TEXT    COLLATE pg_catalog."default",
    eventmodule         TEXT    COLLATE pg_catalog."default",
    eventcategory       TEXT    COLLATE pg_catalog."default",
    eventtype           TEXT    COLLATE pg_catalog."default",
    eventtoken          TEXT    COLLATE pg_catalog."default",
    incidentcount       INTEGER,
    firstoccurred       TEXT    COLLATE pg_catalog."default",
    lastoccurred        TEXT    COLLATE pg_catalog."default",
    incidenttype        TEXT    COLLATE pg_catalog."default",
    notificationtypeid  TEXT    COLLATE pg_catalog."default",
    syscosmosts         BIGINT,
    sysinserttime       TIMESTAMP WITHOUT TIME ZONE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.gem_failed_order_job_notifications OWNER TO citus;

CREATE TABLE IF NOT EXISTS fact.cep_incidents (
    incidentkey bigint,
    application text,
    organizationid text,
    locationid text,
    deviceid text,
    eventmodule text,
    eventcategory text,
    eventtype text,
    eventtoken text,
    incidenttype text,
    incidentcount integer,
    eventinstant text,
    firstoccurred timestamp without time zone,
    lastoccurred timestamp without time zone,
    notificationtypeid text,
    incidentdata text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    severity text
);


ALTER TABLE IF EXISTS fact.cep_incidents OWNER TO citus;

-- Schema evolution: fact.cep_incidents

ALTER TABLE IF EXISTS fact.cep_incidents
ADD COLUMN IF NOT EXISTS severity TEXT COLLATE pg_catalog."default";

--
-- TOC entry 435 (class 1259 OID 693385)
-- Name: customer_menu_preferences; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.customer_menu_preferences (
    organizationid character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    frequentcustomerid character varying(50) NOT NULL,
    day_parts character varying(20) NOT NULL,
    itemid character varying(50),
    itemtype character varying(50),
    item_selection_frequency integer,
    itemtags jsonb,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS fact.customer_menu_preferences OWNER TO citus;

--
-- TOC entry 388 (class 1259 OID 32922)
-- Name: deviceevent; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.deviceevent (
    application text NOT NULL,
    companyid text NOT NULL,
    locationid text NOT NULL,
    moduleid text,
    datacategory text,
    actiontype text,
    severity text,
    eventtoken text,
    eventinstant text,
    dateid integer,
    username text,
    userid text,
    deviceid text,
    devicename text,
    summary text,
    eventdata text,
    syscosmosticks bigint,
    sysinserttime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE IF EXISTS fact.deviceevent OWNER TO citus;

--
-- TOC entry 418 (class 1259 OID 413945)
-- Name: devicehealth; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.devicehealth (
    id bigint NOT NULL,
    healthdatatype character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    companyid character varying(50) NOT NULL,
    deviceid character varying(50) NOT NULL,
    devicetype character varying(50) NOT NULL,
    status character varying(50) NOT NULL,
    statusmessage text,
    healthdatatime timestamp without time zone NOT NULL,
    statuschangetime timestamp without time zone NOT NULL,
    inserttime timestamp without time zone NOT NULL,
    version character varying(50),
    devicedatatime timestamp without time zone
);


ALTER TABLE IF EXISTS fact.devicehealth OWNER TO citus;

--
-- TOC entry 517 (class 1259 OID 3650129)
-- Name: devicestate_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS fact.devicestate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.devicestate_id_seq OWNER TO citus;

--
-- TOC entry 389 (class 1259 OID 32929)
-- Name: devicestate; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.devicestate (
    id bigint DEFAULT nextval('fact.devicestate_id_seq'::regclass) NOT NULL,
    companyid      TEXT,
    locationid     TEXT,
    deviceid       TEXT,
    dateid         INTEGER,
    state          TEXT,
    lasteventtime  TIMESTAMP,
    statuschangetime TIMESTAMP,
    duration       NUMERIC(10,3),
    sysinserttime  TIMESTAMP,
    status         TEXT, --added on 2026-06-19 for enhanced System Health Report
    statusmessage  TEXT, --added on 2026-06-19 for enhanced System Health Report
    healthdatatype TEXT, --added on 2026-06-19 for enhanced System Health Report
    sysupdatetime  TIMESTAMP,
    CONSTRAINT locationid_deviceid_lasteventtime_pkey PRIMARY KEY (locationid, deviceid, lasteventtime)
);


ALTER TABLE IF EXISTS fact.devicestate OWNER TO citus;

-- Schema evolution: fact.devicestate
ALTER TABLE IF EXISTS fact.devicestate
ALTER COLUMN duration TYPE NUMERIC(10,3),
ADD COLUMN IF NOT EXISTS sysinserttime  TIMESTAMP,
ADD COLUMN IF NOT EXISTS status         TEXT,  --added on 2026-06-19 for enhanced System Health Report
ADD COLUMN IF NOT EXISTS statusmessage  TEXT,  --added on 2026-06-19 for enhanced System Health Report
ADD COLUMN IF NOT EXISTS healthdatatype TEXT,  --added on 2026-06-19 for enhanced System Health Report
ADD COLUMN IF NOT EXISTS sysupdatetime  TIMESTAMP;


ALTER TABLE IF EXISTS fact.devicestate
    ALTER COLUMN id SET DEFAULT nextval('fact.devicestate_id_seq');


--
-- TOC entry 401 (class 1259 OID 159814)
-- Name: devicetelemetry; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.devicetelemetry (
    deviceid text NOT NULL,
    locationid text NOT NULL,
    dateid integer NOT NULL,
    cpuvalue numeric(10,5),
    memoryvalue numeric(10,5),
    cputimestamp timestamp without time zone,
    memorytimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT devicetelemetry_pkey PRIMARY KEY (locationid, deviceid, dateid)
);


ALTER TABLE IF EXISTS fact.devicetelemetry OWNER TO citus;

-- Schema evolution: fact.devicetelemetry
ALTER TABLE IF EXISTS fact.devicetelemetry
ALTER COLUMN cpuvalue TYPE NUMERIC(10,5),
ALTER COLUMN memoryvalue TYPE NUMERIC(10,5),
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

--
-- TOC entry 390 (class 1259 OID 32945)
-- Name: itemmodifier; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.itemmodifier (
    transactionheaderid text NOT NULL,
    orderid text NOT NULL,
    itemid text NOT NULL,
    modifiergroupid text NOT NULL,
    modifierid text NOT NULL,
    modifiername text,
    modifierquantity smallint DEFAULT 1 NOT NULL,
    modifierprice numeric(12,3),
    freequantity integer,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    locationid text,
    businessdate date,
    syscosmosts bigint
);


ALTER TABLE IF EXISTS fact.itemmodifier OWNER TO citus;

-- Schema evolution: fact.itemmodifier
ALTER TABLE IF EXISTS fact.itemmodifier
ALTER COLUMN modifierprice TYPE NUMERIC(12,3),
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS locationid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS businessdate DATE,
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT;

--
-- TOC entry 411 (class 1259 OID 352106)
-- Name: itemssurvey; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.itemssurvey (
    organizationid text,
    locationid text,
    dateid integer,
    surveyid text,
    surveytransid text,
    orderid text,
    itemid text,
    itemrating text,
    surveytransstatus text,
    surveyissuedtimestamp text,
    surveycompletedtimestamp text,
    surveylocaltimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    nge_syscosmosts bigint,
    ordersessionid text,
    gem_event_category text,
    gem_event_type text,
    is_responded boolean,
    gem_syscosmosts bigint,
    gem_event_instant text,
    sysupdatetime timestamp without time zone,
    sourceid integer
);


ALTER TABLE IF EXISTS fact.itemssurvey OWNER TO citus;

-- Schema evolution: fact.itemssurvey
ALTER TABLE IF EXISTS fact.itemssurvey
ADD COLUMN IF NOT EXISTS nge_syscosmosts BIGINT,
ADD COLUMN IF NOT EXISTS ordersessionid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS gem_event_category TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS gem_event_type TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS is_responded BOOLEAN,
ADD COLUMN IF NOT EXISTS gem_syscosmosts BIGINT,
ADD COLUMN IF NOT EXISTS gem_event_instant TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sourceid INTEGER;

--
-- TOC entry 436 (class 1259 OID 693393)
-- Name: location_menu_preferences; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.location_menu_preferences (
    organizationid character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    day_parts character varying(20) NOT NULL,
    itemid character varying(50),
    itemtype character varying(50),
    item_selection_frequency integer,
    itemtags jsonb,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS fact.location_menu_preferences OWNER TO citus;

--
-- TOC entry 450 (class 1259 OID 2247991)
-- Name: location_statistics; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.location_statistics (
    organizationid character varying(50),
    organizationname character varying(255),
    locationid character varying(50),
    locationname character varying(255),
    city character varying(255),
    state character varying(255),
    country character varying(255),
    isactive boolean,
    timezone character varying(255),
    order_type_labels jsonb,
    loc_item_popularity jsonb,
    loc_total_order_count integer,
    loc_total_sales_amount numeric(12,3),
    loc_avg_order_amount numeric(12,3),
    org_total_order_count integer,
    org_total_sales_amount numeric(12,3),
    org_avg_order_amount numeric(12,3),
    number_of_frequent_customers integer,
    orders_placed_by_freq_customers integer,
    amount_spent_by_freq_customers numeric(12,3),
    avg_amount_spent_by_freq_customers numeric(12,3),
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS fact.location_statistics OWNER TO citus;

-- Schema evolution: fact.location_statistics
ALTER TABLE IF EXISTS fact.location_statistics
OWNER to citus;

--
-- TOC entry 454 (class 1259 OID 2874472)
-- Name: modifier_impressions; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.modifier_impressions (
    locationid text NOT NULL,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    menuitemid text,
    modifierid text NOT NULL,
    parent_modifier_id text,
    selection_type text,
    nesting_depth integer,
    "position" integer,
    score numeric(5,3),
    strategy text,
    context text,
    selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    pre_selected boolean,
    businessdate date,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS fact.modifier_impressions OWNER TO citus;

-- Schema evolution: fact.modifier_impressions
ALTER TABLE IF EXISTS fact.modifier_impressions
    OWNER to citus;

--
-- TOC entry 455 (class 1259 OID 2874493)
-- Name: modifier_interactions; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.modifier_interactions (
    locationid text,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    orderitemid text,
    menuitemid text,
    modifiergroupid text NOT NULL,
    modifierid text NOT NULL,
    modifiername text,
    parent_modifier_id text,
    nesting_depth integer,
    modifierquantity integer,
    modifierprice numeric(12,3),
    freequantity integer,
    selection_type text,
    action text,
    session_recorded_at text,
    businessdate date,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    sourceid integer
);


ALTER TABLE IF EXISTS fact.modifier_interactions OWNER TO citus;

ALTER TABLE IF EXISTS fact.modifier_interactions
DROP CONSTRAINT IF EXISTS trxnid_menuitemid_modfrgrpid_modfrid_pk;

-- Schema evolution: fact.modifier_interactions
ALTER TABLE IF EXISTS fact.modifier_interactions
--DROP COLUMN IF EXISTS source,
ALTER COLUMN menuitemid DROP NOT NULL,
ADD COLUMN IF NOT EXISTS sourceid INTEGER;

--
-- TOC entry 453 (class 1259 OID 2860510)
-- Name: modifier_recommendations; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.modifier_recommendations (
    locationid text NOT NULL,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    modifier_impressions jsonb,
    modifier_interactions jsonb,
    businessdate date,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS fact.modifier_recommendations OWNER TO citus;

-- Schema evolution: fact.modifier_recommendations
ALTER TABLE IF EXISTS fact.modifier_recommendations
OWNER TO citus;

--
-- TOC entry 412 (class 1259 OID 352111)
-- Name: occasionsurveydetail; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.occasionsurveydetail (
    organizationid text,
    locationid text,
    dateid integer,
    surveyid text,
    surveytransid text,
    orderid text,
    surveyrating text,
    surveytransstatus text,
    surveyissuedtimestamp text,
    surveycompletedtimestamp text,
    surveylocaltimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    syscosmosts bigint,
    sourceid integer,
    surveytype integer,
    ordersessionid text
);


ALTER TABLE IF EXISTS fact.occasionsurveydetail OWNER TO citus;

-- Schema evolution: fact.occasionsurveydetail
ALTER TABLE IF EXISTS fact.occasionsurveydetail
--ADD CONSTRAINT locationid_orderid_pk PRIMARY key (locationid, orderid),
ALTER COLUMN surveytransid DROP NOT NULL,
ADD COLUMN IF NOT EXISTS surveytype INTEGER,
ADD COLUMN IF NOT EXISTS ordersessionid TEXT COLLATE pg_catalog."default";

--
-- TOC entry 519 (class 1259 OID 3654113)
-- Name: ordertiming_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS fact.ordertiming_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.ordertiming_id_seq OWNER TO citus;

--
-- TOC entry 391 (class 1259 OID 32952)
-- Name: ordertiming; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.ordertiming (
    id bigint DEFAULT nextval('fact.ordertiming_id_seq'::regclass) NOT NULL,
    companyid text,
    locationid text,
    eventtoken text,
    dateid integer,
    deviceid text,
    sessionstart timestamp without time zone,
    menustart timestamp without time zone,
    itemstart timestamp without time zone,
    checkoutstart timestamp without time zone,
    paymentstart timestamp without time zone,
    paymentend timestamp without time zone,
    orderend timestamp without time zone,
    starttomenu numeric(7,3),
    menutoitem numeric(7,3),
    itemtocheckout numeric(7,3),
    checkouttopayment numeric(7,3),
    paytopaid numeric(7,3),
    payendtoend numeric(7,3),
    starttocheckout numeric(7,3),
    checkouttoend numeric(7,3),
    totalordertime numeric(7,3),
    sysinserttime timestamp without time zone,
    syscosmosts bigint,
    sysupdatetime TIMESTAMP,
    CONSTRAINT ordertiming_pkey PRIMARY KEY (id),    
    CONSTRAINT locationid_eventtoken_unq UNIQUE (locationid, eventtoken)

);


ALTER TABLE IF EXISTS fact.ordertiming OWNER TO citus;

ALTER TABLE IF EXISTS fact.ordertiming
    ALTER COLUMN id SET DEFAULT nextval('fact.ordertiming_id_seq');

-- Schema evolution: fact.ordertiming
ALTER TABLE IF EXISTS fact.ordertiming
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

--
-- TOC entry 419 (class 1259 OID 413957)
-- Name: peripheralhealth; Type: TABLE; Schema: fact; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS fact.peripheralhealth (
    healthdataid bigint,
    peripheralid character varying(50) NOT NULL,
    peripheraltype character varying(50) NOT NULL,
    status character varying(50) NOT NULL,
    statusmessage text
);


ALTER TABLE IF EXISTS fact.peripheralhealth OWNER TO citus;
*/
--
-- TOC entry 392 (class 1259 OID 32959)
-- Name: peripheralstate; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.peripheralstate (
    deviceid text,
    peripheralid text,
    peripheraltype text,
    state text,
    statestart timestamp with time zone,
    stateend timestamp with time zone,
    duration interval
);


ALTER TABLE IF EXISTS fact.peripheralstate OWNER TO citus;

--
-- TOC entry 393 (class 1259 OID 32965)
-- Name: pipelinerunstatus; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.pipelinerunstatus (
    pipelinename text NOT NULL,
    pipelinerunid character varying(100) NOT NULL,
    pipelinetriggertime timestamp without time zone NOT NULL,
    issuccess boolean,
    pipelinecompletedtime timestamp without time zone,
    correlationid character varying(100),
    pipelinestatus character varying(50),
    pipelinemessage text,
    triggeredbyuserid character varying(100)
);


ALTER TABLE IF EXISTS fact.pipelinerunstatus OWNER TO citus;

--
-- TOC entry 442 (class 1259 OID 888761)
-- Name: pos_sales_details; Type: TABLE; Schema: fact; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS fact.pos_sales_details (
    id bigint NOT NULL,
    businessdate date NOT NULL,
    posorderplaced bigint NOT NULL,
    possales numeric(7,3) DEFAULT 0 NOT NULL,
    postips numeric(7,3) DEFAULT 0,
    locationid text NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(255),
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    modified_by character varying(255),
    is_active boolean DEFAULT false NOT NULL
);


ALTER TABLE IF EXISTS fact.pos_sales_details OWNER TO citus;

--
-- TOC entry 441 (class 1259 OID 888760)
-- Name: pos_sales_details_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS fact.pos_sales_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.pos_sales_details_id_seq OWNER TO citus;

ALTER TABLE IF EXISTS fact.pos_sales_details

    ALTER COLUMN id SET DEFAULT nextval('fact.pos_sales_details_id_seq');
*/
--
-- TOC entry 424 (class 1259 OID 454561)
-- Name: recommendations; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.recommendations (
    transactionheaderid character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    recommendationid character varying(50) NOT NULL,
    offereditems jsonb,
    selecteditems jsonb,
    isconverted boolean,
    prompttimestamp text,
    sysinserttime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE IF EXISTS fact.recommendations OWNER TO citus;

--
-- TOC entry 423 (class 1259 OID 454469)
-- Name: recommendations_bkp; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.recommendations_bkp (
    transactionheaderid character varying(50) NOT NULL,
    recommendationid character varying(50) NOT NULL,
    offereditems jsonb,
    selecteditems jsonb,
    isconverted boolean,
    prompttimestamp text,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS fact.recommendations_bkp OWNER TO citus;

--
-- TOC entry 458 (class 1259 OID 2987102)
-- Name: sent_surveys; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.sent_surveys (
    organizationid text,
    locationid text NOT NULL,
    ordersessionid text NOT NULL,
    orderid text,
    gem_event_category text,
    gem_event_type text,
    survey_metadata jsonb,
    is_responded boolean,
    gem_event_instant text,
    gem_syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE IF EXISTS fact.sent_surveys OWNER TO citus;

-- Schema evolution: fact.sent_surveys
ALTER TABLE IF EXISTS fact.sent_surveys
    OWNER to citus;

--
-- TOC entry 394 (class 1259 OID 32970)
-- Name: timingsdatalake; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.timingsdatalake (
    containername text NOT NULL,
    timing_value timestamp without time zone
);


ALTER TABLE IF EXISTS fact.timingsdatalake OWNER TO citus;

--
-- TOC entry 499 (class 1259 OID 3600411)
-- Name: transactionheader_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS fact.transactionheader_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.transactionheader_id_seq OWNER TO citus;

--
-- TOC entry 395 (class 1259 OID 32977)
-- Name: transactionheader; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.transactionheader (
    id bigint DEFAULT nextval('fact.transactionheader_id_seq'::regclass) NOT NULL,
    transactionheaderid text NOT NULL,
    orderid text,
    locationid text NOT NULL,
    kioskid text,
    ordersessionid text,
    dateid integer,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    orderstatus text,
    ordertype integer,
    numberofitems smallint,
    numberofpayments smallint,
    ordersredeemedrewards numeric(12,3),
    ordersubtotal numeric(12,3),
    ordertotal numeric(12,3),
    ordertax numeric(12,3),
    ordertip numeric(12,3),
    orderdiscount numeric(12,3),
    orderbalance numeric(12,3),
    paymentstatus text,
    sourcefile text DEFAULT 'NGE'::text NOT NULL,
    createddate timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updateddate timestamp without time zone,
    orderstarttime timestamp without time zone,
    reviewordertime timestamp without time zone,
    checkouttime timestamp without time zone,
    paystarttime timestamp without time zone,
    sessionendtime timestamp without time zone,
    precheckouttime numeric(7,3),
    postcheckouttime numeric(7,3),
    menupagetime numeric(7,3),
    reviewpagetime numeric(7,3),
    paymentpagetime numeric(7,3),
    totalordertime numeric(7,3),
    businessdate date,
    frequentcustomerid text,
    abtestid bigint,
    channel text,
    guestcount integer,
    charityamount numeric(12,3),
    syscosmosts bigint,
    sourceid integer,
    orderservicecharge numeric(12,3) DEFAULT 0.000,
    customername character varying(100)
);


ALTER TABLE IF EXISTS fact.transactionheader OWNER TO citus;

ALTER TABLE IF EXISTS fact.transactionheader
    ALTER COLUMN id SET DEFAULT nextval('fact.transactionheader_id_seq');


-- Schema evolution: fact.transactionheader
ALTER TABLE IF EXISTS fact.transactionheader
ADD COLUMN IF NOT EXISTS sourceid INTEGER,
ADD COLUMN IF NOT EXISTS orderservicecharge NUMERIC(12, 3) DEFAULT 0.000,
ALTER COLUMN ordersredeemedrewards TYPE NUMERIC(12, 3),
ALTER COLUMN ordersubtotal TYPE NUMERIC(12, 3),
ALTER COLUMN ordertotal TYPE NUMERIC(12, 3),
ALTER COLUMN ordertax TYPE NUMERIC(12, 3),
ALTER COLUMN ordertip TYPE NUMERIC(12, 3),
ALTER COLUMN orderdiscount TYPE NUMERIC(12, 3),
ALTER COLUMN orderbalance TYPE NUMERIC(12, 3),
ALTER COLUMN charityamount TYPE NUMERIC(12, 3),
ADD COLUMN IF NOT EXISTS customername CHARACTER VARYING(100) COLLATE pg_catalog."default",
ALTER COLUMN updateddate DROP NOT NULL,
ALTER COLUMN updateddate DROP DEFAULT;

--
-- TOC entry 396 (class 1259 OID 32988)
-- Name: transactionitem; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.transactionitem (
    transactionheaderid text NOT NULL,
    categoryid bigint,
    menuitemid bigint,
    itemid text NOT NULL,
    comboid text,
    ordersessionid text NOT NULL,
    itemsessionid text,
    itemname text NOT NULL,
    itemquantity smallint DEFAULT 1,
    itemunitprice numeric(12,3),
    upselllevel text,
    upsellpromptitemid text,
    orderid text NOT NULL,
    itemtype text,
    customize boolean,
    upgrade boolean,
    asis boolean,
    itemselectedtime timestamp without time zone,
    addtocarttime timestamp without time zone,
    totaltime numeric(7,3),
    orderdateutc text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    dimmenuitemid character varying(50),
    locationid character varying(50),
    orderdatelocal timestamp without time zone,
    businessdate date,
    syscosmosts bigint,
    frequentcustomerid text
);


ALTER TABLE IF EXISTS fact.transactionitem OWNER TO citus;

-- Schema evolution: fact.transactionitem
ALTER TABLE IF EXISTS fact.transactionitem
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE,
ADD COLUMN IF NOT EXISTS dimmenuitemid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS locationid TEXT COLLATE pg_catalog."default",
ALTER COLUMN itemunitprice TYPE NUMERIC(12,3),
ADD COLUMN IF NOT EXISTS orderdatelocal TIMESTAMP,
ADD COLUMN IF NOT EXISTS businessdate DATE,
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT,
ADD COLUMN IF NOT EXISTS frequentcustomerid TEXT COLLATE pg_catalog."default";

--
-- TOC entry 397 (class 1259 OID 32997)
-- Name: transactionpayment; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.transactionpayment (
    transactionheaderid text NOT NULL,
    paymentintegrationid text NOT NULL,
    paymentid text,
    paymentamt numeric(12,3),
    orderid text NOT NULL,
    locationid character varying(50),
    kioskid character varying(50),
    paymentmethod character varying(50),
    paymentintegrationlabel text,
    orderdateutc text,
    sysinserttime timestamp without time zone,
    paymentcardtype character varying(50),
    sysupdatetime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE IF EXISTS fact.transactionpayment OWNER TO citus;

-- Schema evolution: fact.transactionpayment
ALTER TABLE IF EXISTS fact.transactionpayment
ADD COLUMN IF NOT EXISTS orderdateutc text,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS paymentcardtype character varying(50),
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP,
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT,
ALTER COLUMN paymentamt TYPE NUMERIC(12,3);

--
-- TOC entry 429 (class 1259 OID 542773)
-- Name: transactionrefunds; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.transactionrefunds (
    transactionheaderid character varying(50) NOT NULL,
    orderid character varying(50),
    locationid character varying(50),
    refundtransactionid character varying(50),
    paymentid character varying(50),
    refundamount numeric(7,3),
    refundtype character varying(50),
    orderdateutc text,
    sysinserttime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE IF EXISTS fact.transactionrefunds OWNER TO citus;

ALTER TABLE IF EXISTS fact.transactionrefunds
ADD COLUMN IF NOT EXISTS orderdateutc text,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT;

--
-- TOC entry 502 (class 1259 OID 3601741)
-- Name: userbehaviour_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

CREATE SEQUENCE IF NOT EXISTS fact.userbehaviour_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.userbehaviour_id_seq OWNER TO citus;

--
-- TOC entry 398 (class 1259 OID 33004)
-- Name: userbehaviour; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.userbehaviour (
    id bigint DEFAULT nextval('fact.userbehaviour_id_seq'::regclass) NOT NULL,
    busdate timestamp without time zone,
    locationid text,
    dateid integer,
    daypart text,
    ordertype bigint,
    eventtype text,
    ordersessionidentifier text,
    viewidentifier integer,
    itemsessionidentifier text,
    elementidentifier integer,
    quantity integer,
    createddate timestamp without time zone,
    syscosmosts bigint,
    eventinstant text,
    eventcategory text,
    sysupdatetime timestamp without time zone,
    deviceid       TEXT,
    syscosmosticks BIGINT,
    eventdata      TEXT
);


ALTER TABLE IF EXISTS fact.userbehaviour OWNER TO citus;

-- Schema evolution: fact.userbehaviour
ALTER TABLE IF EXISTS fact.userbehaviour
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT,
ADD COLUMN IF NOT EXISTS eventinstant text,
ADD COLUMN IF NOT EXISTS eventcategory TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP,
ADD COLUMN IF NOT EXISTS deviceid TEXT,
ADD COLUMN IF NOT EXISTS syscosmosticks BIGINT,
ADD COLUMN IF NOT EXISTS eventdata TEXT;


ALTER TABLE IF EXISTS fact.userbehaviour
    ALTER COLUMN id SET DEFAULT nextval('fact.userbehaviour_id_seq');


--
-- TOC entry 425 (class 1259 OID 459790)
-- Name: userbehaviour_exceptions; Type: TABLE; Schema: fact; Owner: citus
--
/*
CREATE TABLE IF NOT EXISTS fact.userbehaviour_exceptions (
    id bigint NOT NULL,
    busdate timestamp without time zone,
    locationid text,
    dateid integer,
    daypart text,
    ordertype bigint,
    eventtype text,
    ordersessionidentifier text,
    viewidentifier integer,
    itemsessionidentifier text,
    elementidentifier integer,
    quantity integer,
    createddate timestamp without time zone
);


ALTER TABLE IF EXISTS fact.userbehaviour_exceptions OWNER TO citus;
*/
--
-- TOC entry 402 (class 1259 OID 165825)
-- Name: usercheckedin; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.usercheckedin (
    organizationid text NOT NULL,
    locationid text NOT NULL,
    kioskid text,
    ordersessionid text,
    dateid integer,
    ordertimestamp text,
    orderid text NOT NULL,
    customername text,
    customerphone text,
    orderstatus text,
    ordertotal numeric(7,3),
    paymentstatus text,
    amountpaid numeric(7,3),
    paymentmethod text,
    paymentcardtype text,
    sysinserttime timestamp without time zone,
    orderdatelocal timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE IF EXISTS fact.usercheckedin OWNER TO citus;

ALTER TABLE IF EXISTS fact.usercheckedin
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS orderdatelocal TIMESTAMP,
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT;

--
-- TOC entry 434 (class 1259 OID 676689)
-- Name: vw_offer_analysis; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.vw_offer_analysis (
    locationid character varying(50) NOT NULL,
    transactionheaderid character varying(50) NOT NULL,
    recommendationid character varying(50) NOT NULL,
    offereditem character varying(50) NOT NULL,
    selecteditem character varying(50),
    upselltype character varying(50),
    upsellgroupid character varying(50),
    upsellgroupname text,
    quantity integer,
    prompttimestamp text,
    upsellprompttime timestamp without time zone,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    offereditem_upselllevel    TEXT,
    offered_promptitemid       TEXT,
    offered_upsellgroupid      TEXT,
    selecteditem_upselllevel   TEXT,
    selected_promptitemid      TEXT,
    selected_upsellgroupid     TEXT
);


ALTER TABLE IF EXISTS fact.vw_offer_analysis OWNER TO citus;

-- Add 6 new columns to fact.vw_offer_analysis

ALTER TABLE IF EXISTS fact.vw_offer_analysis 
ADD COLUMN IF NOT EXISTS offereditem_upselllevel    TEXT,
ADD COLUMN IF NOT EXISTS offered_promptitemid       TEXT,
ADD COLUMN IF NOT EXISTS offered_upsellgroupid      TEXT,
ADD COLUMN IF NOT EXISTS selecteditem_upselllevel   TEXT,
ADD COLUMN IF NOT EXISTS selected_promptitemid      TEXT,
ADD COLUMN IF NOT EXISTS selected_upsellgroupid     TEXT,
ADD COLUMN IF NOT EXISTS sysupdatetime              TIMESTAMP;


--
-- TOC entry 399 (class 1259 OID 33011)
-- Name: watermarktable; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE IF NOT EXISTS fact.watermarktable (
    watermarktablename text NOT NULL,
    watermarkcolumn text,
    watermarkvalue timestamp without time zone,
    ticks bigint,
    ts bigint,
    source character varying(50) NOT NULL,
    sysinserttime TIMESTAMP,
    sysupdatetime TIMESTAMP
);


ALTER TABLE IF EXISTS fact.watermarktable OWNER TO citus;

-- Schema evolution: fact.watermarktable
ALTER TABLE IF EXISTS fact.watermarktable
ALTER COLUMN source TYPE CHARACTER VARYING(50),
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

--
-- TOC entry 465 (class 1259 OID 3048276)
-- Name: item_modifiergroup_modifier_mapping; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE IF NOT EXISTS ml.item_modifiergroup_modifier_mapping (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    catalogid text,
    catalogname text,
    menuitemid text,
    menuitemname text,
    item_class_type integer,
    modifiergroupid text,
    modifiergroupname text,
    modifierid text,
    modifiername text,
    modifier_class_type integer,
    is_modifier_default boolean,
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    modifier_default_quantity integer,
    is_modifier_invisible boolean,
    calories text,
    price numeric(12,4),
    is_modifier_active boolean,
    is_modifier_deleted boolean,
    modifier_created_on timestamp without time zone,
    modifier_modified_on timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS ml.item_modifiergroup_modifier_mapping OWNER TO citus;

--
-- TOC entry 461 (class 1259 OID 3044534)
-- Name: menu_entities; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE IF NOT EXISTS ml.menu_entities (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    categoryid text,
    categoryname text,
    menuitemid text,
    menuitemname text,
    catalogid text,
    itemunitprice numeric(12,3),
    price_changed_on timestamp without time zone,
    item_class_type integer,
    entitytype text,
    calories text,
    protein numeric(9,2),
    sugar numeric(9,2),
    fat numeric(9,2),
    is_alcoholic boolean,
    is_vegetarian_item boolean,
    is_vegan_item boolean,
    has_allergen boolean,
    is_active boolean,
    is_deleted boolean,
    gms_created_on timestamp without time zone,
    gms_modified_on timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS ml.menu_entities OWNER TO citus;

--
-- TOC entry 464 (class 1259 OID 3048261)
-- Name: modifier_impressions; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE IF NOT EXISTS ml.modifier_impressions (
    organizationid text,
    organizationname text,
    locationname text,
    locationid text,
    catalogid text,
    catalogname text,
    businessdate date,
    orderdatelocal timestamp without time zone,
    yyyy integer,
    ww integer,
    transactionheaderid text,
    ordersessionid text,
    orderid text,
    menuitemid text,
    menuitemname text,
    item_class_type integer,
    modifierid text,
    modifiername text,
    modifier_class_type integer,
    parent_modifier_id text,
    nesting_depth integer,
    modifierprice numeric(12,3),
    selection_type text,
    "position" integer,
    score numeric(10,4),
    strategy text,
    context text,
    selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    pre_selected boolean,
    frequentcustomerid text,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS ml.modifier_impressions OWNER TO citus;

--
-- TOC entry 463 (class 1259 OID 3048228)
-- Name: modifier_interactions; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE IF NOT EXISTS ml.modifier_interactions (
    organizationid text,
    organizationname text,
    locationname text,
    locationid text,
    catalogid text,
    catalogname text,
    businessdate date,
    orderdatelocal timestamp without time zone,
    yyyy integer,
    ww integer,
    transactionheaderid text,
    ordersessionid text,
    orderid text,
    orderitemid text,
    menuitemid text,
    menuitemname text,
    itemquantity integer,
    itemunitprice numeric(12,3),
    item_class_type integer,
    modifiergroupid text,
    modifiergroupname text,
    modifierid text,
    modifiername text,
    parent_modifier_id text,
    nesting_depth integer,
    modifierquantity integer,
    modifierprice numeric(12,3),
    freequantity integer,
    is_modifier_default boolean,
    min_quantity integer,
    max_quantity integer,
    selection_type text,
    action text,
    session_recorded_at text,
    frequentcustomerid text,
    modifier_default_quantity integer,
    modifier_class_type integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS ml.modifier_interactions OWNER TO citus;

--
-- TOC entry 462 (class 1259 OID 3044562)
-- Name: transactions; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE IF NOT EXISTS ml.transactions (
    frequentcustomerid text,
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    kioskid text,
    transactionheaderid text,
    ordersessionid text,
    orderid text,
    orderitemid text,
    menuitemid text,
    itemname text,
    upselllevel text,
    item_class_type integer,
    itemquantity integer,
    categoryid text,
    categoryname text,
    itemunitprice numeric(12,3),
    paymentstatus text,
    numberofitems integer,
    numberofpayments integer,
    ordertotal numeric(14,4),
    ordersubtotal numeric(14,4),
    ordertip numeric(14,4),
    ordertax numeric(14,4),
    ordertypelabel text,
    orderdatelocal timestamp without time zone,
    businessdate date,
    weatherhumidity numeric(7,2),
    weathercondition text,
    temperatureincelcius numeric(7,2),
    yyyy integer,
    mm integer,
    dd integer,
    hh integer,
    ww integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS ml.transactions OWNER TO citus;

--
-- TOC entry 459 (class 1259 OID 3042193)
-- Name: upsell_analysis; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE IF NOT EXISTS ml.upsell_analysis (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    frequentcustomerid text,
    transactionheaderid text,
    recommendationid text,
    offereditem text,
    selecteditem text,
    item_class_type integer,
    upselltype text,
    quantity integer,
    businessdate date,
    orderdatelocal timestamp without time zone,
    yyyy integer,
    mm integer,
    dd integer,
    hh integer,
    ww integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS ml.upsell_analysis OWNER TO citus;

--
-- TOC entry 460 (class 1259 OID 3042222)
-- Name: weather; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE IF NOT EXISTS ml.weather (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    weatherdate date,
    yyyy integer,
    mm integer,
    dd integer,
    ww integer,
    hh integer,
    humidity integer,
    condition text,
    temperature_c numeric(8,2),
    is_hot boolean,
    is_calm boolean,
    is_cold boolean,
    is_cool boolean,
    is_mild boolean,
    is_warm boolean,
    rain_mm numeric(8,2),
    is_sunny boolean,
    is_windy boolean,
    is_cloudy boolean,
    is_daytime boolean,
    is_raining boolean,
    is_snowing boolean,
    is_very_hot boolean,
    is_freezing boolean,
    is_overcast boolean,
    snowfall_mm numeric(8,2),
    temp_bucket text,
    wind_bucket text,
    feels_colder boolean,
    feels_hotter boolean,
    food_weather text,
    is_heavy_rain boolean,
    is_light_rain boolean,
    is_nighttime boolean,
    is_very_windy boolean,
    pressure_hpa numeric(8,2),
    weather_code integer,
    wind_gust_kmh numeric(8,2),
    comfort_score integer,
    drink_weather text,
    wind_speed_kmh numeric(8,2),
    comfort_bucket text,
    humidity_bucket text,
    condition_bucket text,
    is_precipitating boolean,
    precipitation_mm numeric(8,2),
    visibility_meters numeric(8,2),
    cloud_cover_percent numeric(8,2),
    is_unseasonably_hot boolean,
    is_unseasonably_cold boolean,
    outdoor_dining_score integer,
    wind_direction_degrees integer,
    precipitation_probability numeric(8,2),
    apparent_temperature_celsius numeric(8,2),
    sysinserttime timestamp without time zone
);


ALTER TABLE IF EXISTS ml.weather OWNER TO citus;



--
-- TOC entry 495 (class 1259 OID 3588996)
-- Name: dim_catalog; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_catalog (
    catalogid character varying(50) NOT NULL,
    catalogname character varying(255),
    organizationid character varying(40),
    is_catalog_deleted boolean,
    catalog_created_on timestamp without time zone,
    catalog_modified_on timestamp without time zone,
    gem_company_id character varying(255),
    gem_location_id character varying(255),
    is_sync_in_progress boolean,
    is_standalone boolean,
    is_master boolean,
    is_ecm_enabled boolean,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_catalog OWNER TO citus;

-- Schema evolution: stg.dim_catalog
ALTER TABLE IF EXISTS stg.dim_catalog
    OWNER to citus;

--
-- TOC entry 489 (class 1259 OID 3586057)
-- Name: dim_category_hierarchy; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_category_hierarchy (
    organizationid text,
    locationid text NOT NULL,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    catalogid text,
    catalogname text,
    catalog_created_on timestamp without time zone,
    catalog_modified_on timestamp without time zone,
    is_catalog_active boolean,
    is_catalog_deleted boolean,
    categoryid text NOT NULL,
    categoryname text,
    category_created_on timestamp without time zone,
    category_modified_on timestamp without time zone,
    is_category_active boolean,
    is_category_deleted boolean,
    menuitemid text,
    entitytype text,
    item_class_type integer,
    menuitemname text,
    item_created_on timestamp without time zone,
    item_modified_on timestamp without time zone,
    is_item_active boolean,
    is_item_deleted boolean,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_category_hierarchy OWNER TO citus;

-- Schema evolution: stg.dim_category_hierarchy
ALTER TABLE IF EXISTS stg.dim_category_hierarchy
    OWNER to citus;

--
-- TOC entry 515 (class 1259 OID 3644487)
-- Name: dim_cep_subscriptions; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_cep_subscriptions (
    id text,
    cep_subscriptions text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_cep_subscriptions OWNER TO citus;

--
-- TOC entry 485 (class 1259 OID 3584732)
-- Name: dim_frequentcustomer; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_frequentcustomer (
    frequentcustomerid text NOT NULL,
    firstname text,
    lastname text,
    email text,
    phone text,
    source text,
    organizationid text,
    createddate text,
    lastorderdate text,
    ordercount integer DEFAULT 0 NOT NULL,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_frequentcustomer OWNER TO citus;

-- Schema evolution: stg.dim_frequentcustomer
ALTER TABLE IF EXISTS stg.dim_frequentcustomer
    OWNER to citus;

--
-- TOC entry 494 (class 1259 OID 3587579)
-- Name: dim_itemcategory; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_itemcategory (
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text NOT NULL,
    catalogid text,
    is_category_active boolean,
    is_category_deleted boolean,
    category_created_on timestamp without time zone,
    category_modified_on timestamp without time zone,
    is_alcoholic boolean,
    number_of_items smallint,
    number_of_sub_categories smallint,
    number_of_item_variations smallint,
    number_of_combos smallint,
    number_of_combo_families smallint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_itemcategory OWNER TO citus;

--
-- TOC entry 496 (class 1259 OID 3594934)
-- Name: dim_kiosk; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_kiosk (
    locationid text NOT NULL,
    kioskid text NOT NULL,
    kioskname text,
    appversion text,
    istestkiosk boolean,
    devicetype character varying(50),
    devicecreatedon timestamp without time zone,
    devicedeletedon timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_kiosk OWNER TO citus;

--
-- TOC entry 513 (class 1259 OID 3631109)
-- Name: dim_kiosk_appearance; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_kiosk_appearance (
    locationid text,
    kiosk_receipt_settings text,
    kiosk_fonts text,
    kiosk_appearance_text_overrides text,
    kiosk_appearance_style_options text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_kiosk_appearance OWNER TO citus;

--
-- TOC entry 512 (class 1259 OID 3631104)
-- Name: dim_kiosk_config; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_kiosk_config (
    locationid text,
    scanners text,
    item_special_request text,
    legal_copy_enabled boolean,
    ada_configuration text,
    calculate_default_modifier_price boolean,
    track_kiosk_user_behavior boolean,
    loyalty_feature boolean,
    pickup_flow boolean,
    pos_auto_applied_discount boolean,
    search_functionality_enabled boolean,
    recent_orders_enabled boolean,
    play_card_config text,
    round_up_for_charity boolean,
    calories_enabled boolean,
    scan_and_go_enabled boolean,
    age_verification text,
    tips_settings text,
    business_hours_config text,
    order_types text,
    localization text,
    loyalty_display_settings text,
    preorder_popup_enabled boolean,
    preorder_popup_text text,
    disclaimer_text text,
    order_limit_config text,
    menu_behavior_config text,
    perform_pos_status_check boolean,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_kiosk_config OWNER TO citus;

--
-- TOC entry 508 (class 1259 OID 3631084)
-- Name: dim_location_kiosks; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_location_kiosks (
    id text,
    locationid text,
    companyid text,
    devicetype text,
    syncversion text,
    kiosks text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_location_kiosks OWNER TO citus;

--
-- TOC entry 510 (class 1259 OID 3631094)
-- Name: dim_loyalty_configuration; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_loyalty_configuration (
    locationid text,
    loyalty_provider text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_loyalty_configuration OWNER TO citus;

--
-- TOC entry 488 (class 1259 OID 3586044)
-- Name: dim_menuitem; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_menuitem (
    menuitemid text NOT NULL,
    menuitemname text NOT NULL,
    entitytype text,
    calories text,
    protein numeric,
    sugar numeric,
    fat numeric,
    is_alcoholic boolean,
    is_vegetarian_item boolean,
    is_vegan_item boolean,
    has_allergen boolean,
    item_class_type integer,
    is_active boolean,
    is_deleted boolean,
    gms_created_on timestamp without time zone,
    gms_modified_on timestamp without time zone,
    itemunitprice numeric(12,3),
    price_changed_on timestamp without time zone,
    catalogid text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_menuitem OWNER TO citus;

-- Schema evolution: stg.dim_menuitem
ALTER TABLE IF EXISTS stg.dim_menuitem
    OWNER to citus;

--
-- TOC entry 490 (class 1259 OID 3586064)
-- Name: dim_modifier; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_modifier (
    modifierid character varying(50) NOT NULL,
    catalogid character varying(50),
    modifiername character varying(255),
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    calories text NOT NULL,
    calories_text text,
    is_modifier_active boolean NOT NULL,
    is_modifier_deleted boolean NOT NULL,
    modifier_created_on timestamp without time zone,
    modifier_modified_on timestamp without time zone,
    is_modifier_default boolean,
    modifier_default_quantity integer,
    is_invisible boolean,
    classification integer,
    price numeric(12,3),
    price_changed_on timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_modifier OWNER TO citus;

-- Schema evolution: stg.dim_modifier
ALTER TABLE IF EXISTS stg.dim_modifier
    OWNER to citus;

--
-- TOC entry 491 (class 1259 OID 3586070)
-- Name: dim_modifiergroup; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_modifiergroup (
    modifiergroupid character varying(50) NOT NULL,
    modifiergroupname character varying(510) NOT NULL,
    catalogid character varying(50) NOT NULL,
    max_selection integer,
    min_selection integer,
    free_count integer,
    pos_linked_entity_id character varying(50),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    negative_modifier_behavior integer,
    created_by character varying(255),
    modified_by character varying(255),
    max_aggregate_count integer,
    min_aggregate_count integer,
    increment_step integer,
    slider_mode boolean DEFAULT false NOT NULL,
    slider_mode_modifier boolean DEFAULT false NOT NULL,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_modifiergroup OWNER TO citus;

-- Schema evolution: stg.dim_modifiergroup
ALTER TABLE IF EXISTS stg.dim_modifiergroup
    OWNER to citus;

--
-- TOC entry 492 (class 1259 OID 3586080)
-- Name: dim_modifiergroup_modifier_mapping; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_modifiergroup_modifier_mapping (
    modifier_mapping_id character varying(50) NOT NULL,
    modifierid character varying(50) NOT NULL,
    modifiergroupid character varying(50) NOT NULL,
    catalogid character varying(50),
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_default boolean,
    default_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    min_quantity integer,
    max_quantity integer,
    calories_text text,
    is_invisible boolean,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_modifiergroup_modifier_mapping OWNER TO citus;

-- Schema evolution: stg.dim_modifiergroup_modifier_mapping
ALTER TABLE IF EXISTS stg.dim_modifiergroup_modifier_mapping
    OWNER to citus;

--
-- TOC entry 505 (class 1259 OID 3608712)
-- Name: dim_occasionsurvey; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_occasionsurvey (
    organizationid text NOT NULL,
    surveyid text NOT NULL,
    surveyname text,
    surveytype integer,
    question_type integer,
    selection_type integer,
    survey_status integer,
    is_deleted boolean,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_occasionsurvey OWNER TO citus;

--
-- TOC entry 514 (class 1259 OID 3644479)
-- Name: dim_organization; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_organization (
    id character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    address1 character varying(255),
    address2 character varying(255),
    city character varying(255),
    state character varying(255),
    zipcode character varying(20),
    country character varying(255),
    organizationtype smallint,
    status smallint,
    phonenumber character varying(20),
    email character varying(255),
    isdeleted boolean DEFAULT false,
    createdon timestamp without time zone,
    createdby character varying(255),
    modifiedon timestamp without time zone,
    modifiedby character varying(255),
    active boolean,
    timezone character varying(50),
    coordinates text,
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
    cep_subscriptions text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_organization OWNER TO citus;

--
-- TOC entry 503 (class 1259 OID 3605517)
-- Name: dim_organizationlocation; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_organizationlocation (
    organizationid character varying(40) NOT NULL,
    organizationname character varying(255),
    locationid character varying(40) NOT NULL,
    locationname character varying(255) NOT NULL,
    organizationtype smallint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_organizationlocation OWNER TO citus;

--
-- TOC entry 511 (class 1259 OID 3631099)
-- Name: dim_payment_provider; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_payment_provider (
    locationid text,
    payment_provider text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_payment_provider OWNER TO citus;

--
-- TOC entry 509 (class 1259 OID 3631089)
-- Name: dim_pos_provider; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.dim_pos_provider (
    locationid text,
    pos_provider text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_pos_provider OWNER TO citus;

--
-- TOC entry 516 (class 1259 OID 3648879)
-- Name: fact_devicestate; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.fact_devicestate (
    id bigint,
    healthdatatype text,
    locationid text,
    companyid text,
    deviceid text,
    devicetype text,
    status text,
    statusmessage text,
    healthdatatime timestamp without time zone,
    statuschangetime timestamp without time zone,
    inserttime timestamp without time zone,
    version text,
    devicedatatime timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.fact_devicestate OWNER TO citus;

--
-- TOC entry 518 (class 1259 OID 3650133)
-- Name: fact_devicetelemetry; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.fact_devicetelemetry (
    deviceid text,
    locationid text,
    dateid integer,
    cpuvalue numeric(10,5),
    memoryvalue numeric(10,5),
    cputimestamp timestamp without time zone,
    memorytimestamp timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.fact_devicetelemetry OWNER TO citus;

--
-- TOC entry 507 (class 1259 OID 3614573)
-- Name: fact_itemssurvey; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.fact_itemssurvey (
    locationid text,
    dateid integer,
    surveyid text,
    surveytransid text,
    orderid text,
    itemid text,
    itemrating text,
    surveytransstatus text,
    surveyissuedtimestamp text,
    surveycompletedtimestamp text,
    surveylocaltimestamp timestamp without time zone,
    nge_syscosmosts bigint,
    sourceid integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.fact_itemssurvey OWNER TO citus;

--
-- TOC entry 506 (class 1259 OID 3608723)
-- Name: fact_occasionsurveydetail; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.fact_occasionsurveydetail (
    locationid text,
    dateid integer,
    surveyid text,
    surveytransid text,
    orderid text,
    surveyrating text,
    surveytransstatus text,
    surveyissuedtimestamp text,
    surveycompletedtimestamp text,
    surveylocaltimestamp timestamp without time zone,
    syscosmosts bigint,
    sourceid integer,
    surveytype integer,
    ordersessionid text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.fact_occasionsurveydetail OWNER TO citus;

--
-- TOC entry 430 (class 1259 OID 583797)
-- Name: kioskdetails; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.kioskdetails (
    id text,
    locationid text,
    kiosks text,
    devicetype text,
    syncversion text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.kioskdetails OWNER TO citus;

--
-- TOC entry 477 (class 1259 OID 3568572)
-- Name: lookup_silver_transaction_header; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.lookup_silver_transaction_header (
    id integer,
    transactionheaderid text,
    orderid text,
    locationid text,
    kioskid text,
    ordersessionid text,
    dateid integer,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    orderstatus text,
    ordertype integer,
    numberofitems smallint,
    numberofpayments smallint,
    ordersredeemedrewards numeric(12,3),
    ordersubtotal numeric(12,3),
    ordertotal numeric(12,3),
    ordertax numeric(12,3),
    ordertip numeric(12,3),
    orderdiscount numeric(12,3),
    orderbalance numeric(12,3),
    paymentstatus text,
    sourcefile text,
    createddate timestamp without time zone,
    charityamount numeric(12,3),
    orderservicecharge numeric(12,3),
    businessdate date,
    syscosmosts bigint,
    channel text,
    guestcount integer,
    frequentcustomerid text,
    customername text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.lookup_silver_transaction_header OWNER TO citus;

--
-- TOC entry 452 (class 1259 OID 2849148)
-- Name: modifier_recommendation_sessions; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.modifier_recommendation_sessions (
    locationid text NOT NULL,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    modifier_impressions text,
    modifier_interactions text,
    businessdate date,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE stg.modifier_recommendation_sessions OWNER TO citus;

-- Schema evolution: stg.modifier_recommendation_sessions
ALTER TABLE stg.modifier_recommendation_sessions
OWNER TO citus;

--
-- TOC entry 426 (class 1259 OID 461038)
-- Name: recommendations; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.recommendations (
    transactionheaderid character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    recommendationid character varying(50) NOT NULL,
    offereditems text,
    selecteditems text,
    prompttimestamp text,
    sysinserttime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE stg.recommendations OWNER TO citus;

--
-- TOC entry 456 (class 1259 OID 2944480)
-- Name: sent_surveys; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.sent_surveys (
    organizationid text,
    locationid text NOT NULL,
    ordersessionid text NOT NULL,
    orderid text,
    gem_event_category text,
    gem_event_type text,
    survey_metadata text,
    is_responded boolean,
    gem_event_instant text,
    gem_syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE stg.sent_surveys OWNER TO citus;

-- Schema evolution: stg.sent_surveys
ALTER TABLE IF EXISTS stg.sent_surveys
    OWNER to citus;

--
-- TOC entry 472 (class 1259 OID 3499461)
-- Name: silver_cep_incidents; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_cep_incidents (
    id text,
    application text,
    companyid text,
    locationid text,
    eventmodule text,
    eventcategory text,
    eventtype text,
    severity text,
    token text,
    eventinstant text,
    username text,
    userid text,
    device text,
    devicename text,
    summary text,
    data text,
    syscosmosticks bigint,
    syscosmosts bigint,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_cep_incidents OWNER TO citus;

ALTER TABLE stg.silver_cep_incidents
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

--
-- TOC entry 478 (class 1259 OID 3570048)
-- Name: silver_item_modifiers; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_item_modifiers (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    orderitemid text,
    itemsessionid text,
    menuitemid text,
    menu_item_pos_id text,
    itemname text,
    categoryid text,
    categoryname text,
    category_pos_id text,
    itemquantity integer,
    usd_itemunitprice numeric(12,3),
    usd_total_item_price numeric(12,3),
    cents_itemunitprice bigint,
    cents_total_item_price bigint,
    items_discount_id text,
    is_items_discount_hidden_on_receipt boolean,
    items_discounts text,
    items_upsell_source text,
    items_reward_source text,
    items_special_request text,
    items_concept_id text,
    items_concept_name text,
    options_modifierid text,
    options_modifier_pos_id text,
    options_modifiername text,
    options_modifier_code text,
    options_modifiergroupid text,
    options_modifiergroupname text,
    options_modifiergroup_pos_id text,
    options_modifierquantity integer,
    options_modifierunitprice numeric(12,3),
    options_total_modifierprice numeric(12,3),
    modifier_freequantity integer,
    is_modifier_invisible boolean,
    is_modifier_default boolean,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_item_modifiers OWNER TO citus;

ALTER TABLE IF EXISTS stg.silver_item_modifiers
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

--
-- TOC entry 471 (class 1259 OID 3499456)
-- Name: silver_kiosk_events; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_kiosk_events (
    id text,
    application text,
    companyid text,
    locationid text,
    eventmodule text,
    eventcategory text,
    eventtype text,
    severity text,
    token text,
    eventinstant text,
    username text,
    userid text,
    device text,
    devicename text,
    summary text,
    data text,
    syscosmosticks bigint,
    syscosmosts bigint,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_kiosk_events OWNER TO citus;

ALTER TABLE stg.silver_kiosk_events
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

-- Table: stg.silver_kiosk_events

-- DROP TABLE IF EXISTS stg.silver_all_gem_events;

CREATE TABLE IF NOT EXISTS stg.silver_all_gem_events
(
    id text COLLATE pg_catalog."default",
    application text COLLATE pg_catalog."default",
    companyid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    eventmodule text COLLATE pg_catalog."default",
    eventcategory text COLLATE pg_catalog."default",
    eventtype text COLLATE pg_catalog."default",
    severity text COLLATE pg_catalog."default",
    token text COLLATE pg_catalog."default",
    eventinstant text COLLATE pg_catalog."default",
    username text COLLATE pg_catalog."default",
    userid text COLLATE pg_catalog."default",
    device text COLLATE pg_catalog."default",
    devicename text COLLATE pg_catalog."default",
    summary text COLLATE pg_catalog."default",
    data text COLLATE pg_catalog."default",
    syscosmosticks bigint,
    syscosmosts bigint,
    bronze_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_all_gem_events
    OWNER to citus;


--DROP TABLE --IF EXISTS stg.silver_all_transaction_entities;
CREATE TABLE IF NOT EXISTS stg.silver_all_transaction_entities (
    -- ── Cosmos / system metadata ──────────────────────────────────────────
    "_attachments"                        TEXT,
    "_etag"                               TEXT,
    "_rid"                                TEXT,
    "_self"                               TEXT,
    "_lsn"                                BIGINT,
    "_ts"                                 BIGINT,

    -- ── Order header scalars ──────────────────────────────────────────────
    "id"                                  TEXT,
    "orderId"                             TEXT,
    "locationId"                          TEXT,
    "businessDate"                        TEXT,
    "orderDate"                           TEXT,
    "orderType"                           TEXT,
    "orderTypeLabel"                      TEXT,
    "channel"                             INTEGER,
    "conceptId"                           TEXT,
    "conceptName"                         TEXT,
    "kioskSessionId"                      TEXT,
    "clientIpAddress"                     TEXT,
    "guestCount"                          INTEGER,
    "gusetCheckImageLink"                 TEXT,   -- preserved source typo
    "isFailedToSendToPos"                 BOOLEAN,
    "isTestOrder"                         BOOLEAN,
    "posSubmissionStatus"                 INTEGER,
    "originalTransactionId"               TEXT,
    "refundTransactionId"                 TEXT,
    "refundType"                          TEXT,
    "refundedAmount"                      NUMERIC(12,3),
    "rawResponse"                         TEXT,
    "receiptImage"                        TEXT,
    "orderReceiptUrl"                     TEXT,
    "orderReceiptPdfUrl"                  TEXT,
    "type"                                TEXT,

    -- ── Loyalty scalars ───────────────────────────────────────────────────
    "loyaltyProviderTransactionId"        TEXT,
    "loyaltyProviderPaymentTransactionId" TEXT,

    -- ── Complex / nested  →  TEXT ─────────────────────────────────────────
    "kioskSource"                         TEXT,
    "orderIdentity"                       TEXT,
    "loyaltyUser"                         TEXT,
    "localCurrencyDetails"                TEXT,
    "totals"                              TEXT,
    "totalsCents"                         TEXT,
    "receiptDetails"                      TEXT,
    "concepts"                            TEXT,
    "items"                               TEXT,
    "combos"                              TEXT,
    "discounts"                           TEXT,
    "paymentDetails"                      TEXT,
    "redeemedRewards"                     TEXT,
    "upsellInformation"                   TEXT,

    --New Fields--
    "resolvedAt"                          TEXT,
    "thirdPartyOrderId"                   TEXT,
    -- ── Pipeline metadata ─────────────────────────────────────────────────
    "bronze_folderpath"                   TEXT,
    "sysinserttime"                       TEXT
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_all_transaction_entities
    OWNER TO citus;

-- Index: ix_silver_kiosk_events_syscosmosts

-- DROP INDEX IF EXISTS stg.ix_silver_kiosk_events_syscosmosts;

-- Index: ix_silver_kiosk_events_syscosmosts_brin

-- DROP INDEX IF EXISTS stg.ix_silver_kiosk_events_syscosmosts_brin;

CREATE INDEX IF NOT EXISTS ix_silver_all_gem_events_syscosmosts_brin
    ON stg.silver_all_gem_events USING brin
    (syscosmosts)
    WITH (pages_per_range=128)
    TABLESPACE pg_default;


CREATE TABLE IF NOT EXISTS stg.gem_failed_order_job_notifications
(
    incidentid          TEXT    COLLATE pg_catalog."default",
    application         TEXT    COLLATE pg_catalog."default",
    organizationid      TEXT    COLLATE pg_catalog."default",
    locationid          TEXT    COLLATE pg_catalog."default",
    eventmodule         TEXT    COLLATE pg_catalog."default",
    eventcategory       TEXT    COLLATE pg_catalog."default",
    eventtype           TEXT    COLLATE pg_catalog."default",
    eventtoken          TEXT    COLLATE pg_catalog."default",
    incidentcount       INTEGER,
    firstoccurred       TEXT    COLLATE pg_catalog."default",
    lastoccurred        TEXT    COLLATE pg_catalog."default",
    incidenttype        TEXT    COLLATE pg_catalog."default",
    notificationtypeid  TEXT    COLLATE pg_catalog."default",
    syscosmosts         BIGINT,
    sysinserttime       TIMESTAMP WITHOUT TIME ZONE
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.gem_failed_order_job_notifications OWNER TO citus;

--
-- TOC entry 483 (class 1259 OID 3571370)
-- Name: silver_modifier_impressions; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_modifier_impressions (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    menuitemid text,
    parentmodifierid text,
    selection_type text,
    modifier_impressions_nesting_depth integer,
    modifier_impressions_context text,
    strategy text,
    modifierid text,
    score integer,
    "position" integer,
    selected boolean,
    pre_selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_modifier_impressions OWNER TO citus;

ALTER TABLE IF EXISTS stg.silver_modifier_impressions
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

--
-- TOC entry 482 (class 1259 OID 3571365)
-- Name: silver_modifier_interactions; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_modifier_interactions (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    menuitemid text,
    modifierid text,
    modifiergroupid text,
    parent_modifier_id text,
    selection_type text,
    modifier_interactions_action text,
    modifier_interactions_recorded_at text,
    modifier_interactions_nesting_depth integer,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_modifier_interactions OWNER TO citus;

ALTER TABLE IF EXISTS stg.silver_modifier_interactions
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;


--
-- TOC entry 481 (class 1259 OID 3571360)
-- Name: silver_modifier_recommendations; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_modifier_recommendations (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    modifier_interactions text,
    modifier_impressions text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_modifier_recommendations OWNER TO citus;

ALTER TABLE IF EXISTS stg.silver_modifier_recommendations
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

--
-- TOC entry 484 (class 1259 OID 3580160)
-- Name: silver_transaction_combo_items; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_transaction_combo_items (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    combo_id text,
    combo_pos_id text,
    combo_name text,
    combo_order_item_id text,
    combo_item_session_id text,
    combo_concept_id text,
    combo_concept_name text,
    cents_combo_unit_price bigint,
    cents_combo_total_price bigint,
    combo_quantity integer,
    combo_special_request text,
    combo_upsell_source text,
    combo_reward_source text,
    component_id text,
    component_pos_id text,
    component_name text,
    component_item_order_item_id text,
    component_item_menu_item_id text,
    component_item_name text,
    component_item_menu_item_pos_id text,
    component_item_session_id text,
    component_item_concept_id text,
    component_item_concept_name text,
    component_item_quantity integer,
    component_item_price numeric(12,3),
    component_item_unit_price numeric(12,3),
    component_item_cents_unit_price bigint,
    component_item_total_price numeric(12,3),
    component_item_cents_total_price bigint,
    component_item_special_request text,
    component_item_upsell_source text,
    component_item_reward_source text,
    component_item_discount_id text,
    is_component_item_discount_hidden_on_receipt boolean,
    component_item_discounts text,
    component_selections_items text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_transaction_combo_items OWNER TO citus;

ALTER TABLE IF EXISTS stg.silver_transaction_combo_items
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;




--
-- TOC entry 473 (class 1259 OID 3518689)
-- Name: silver_transaction_header; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_transaction_header (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    channel integer,
    items_array text,
    payments_array text,
    numberofitems smallint,
    numberofpayments smallint,
    concept_id text,
    concept_name text,
    ordertype text,
    order_type_label text,
    order_completion_status text,
    pos_submission_status integer,
    is_send_to_pos_failed boolean,
    is_test_order boolean,
    frequentcustomerid text,
    customername text,
    client_ip_address text,
    order_identity_order_token text,
    order_identity_pos_order_token text,
    order_identity_phone text,
    order_identity_phone_country_code text,
    order_identity_email text,
    order_identity_table_tent text,
    order_identity_device_imei text,
    guest_count integer,
    guest_check_code text,
    genesis_fiscal_fields text,
    order_language text,
    receipt_printing_type text,
    loyalty_transaction_id text,
    loyalty_payment_transaction_id text,
    loyalty_earned_points text,
    local_currency_code text,
    local_currency_additional_info text,
    usd_amount numeric(12,3),
    usd_subtotal numeric(12,3),
    usd_tax numeric(12,3),
    usd_tip numeric(12,3),
    usd_discount numeric(12,3),
    usd_reward numeric(12,3),
    usd_service_charge numeric(12,3),
    usd_charity_amount numeric(12,3),
    cents_amount bigint,
    cents_subtotal bigint,
    cents_tax bigint,
    cents_tip bigint,
    cents_discount bigint,
    cents_reward bigint,
    cents_service_charge bigint,
    cents_charity_amount bigint,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    discounts_array                             text COLLATE pg_catalog."default",
    combos_array                                text COLLATE pg_catalog."default",
    redeemed_rewards_array                      text COLLATE pg_catalog."default",
    concepts_array                              text COLLATE pg_catalog."default",
    upsell_prompt_array                         text COLLATE pg_catalog."default",
    modifier_interactions_array                 text COLLATE pg_catalog."default",
    modifier_impressions_array                  text COLLATE pg_catalog."default",
    loyalty_user_object                         text COLLATE pg_catalog."default",
    receipt_details_object                      text COLLATE pg_catalog."default",
    kiosk_source_object                         text COLLATE pg_catalog."default",
    local_currency_details_object               text COLLATE pg_catalog."default",
    order_identity_object                       text COLLATE pg_catalog."default",
    totals_object                               text COLLATE pg_catalog."default",
    totals_cents_object                         text COLLATE pg_catalog."default",
    bronze_folderpath                           text COLLATE pg_catalog."default"
);


ALTER TABLE stg.silver_transaction_header OWNER TO citus;


ALTER TABLE IF EXISTS stg.silver_transaction_header
    ADD COLUMN IF NOT EXISTS discounts_array                             text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS combos_array                                text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS redeemed_rewards_array                      text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS concepts_array                              text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS upsell_prompt_array                         text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS modifier_interactions_array                 text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS modifier_impressions_array                  text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS loyalty_user_object                         text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS receipt_details_object                      text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS kiosk_source_object                         text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS local_currency_details_object               text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS order_identity_object                       text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS totals_object                               text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS totals_cents_object                         text COLLATE pg_catalog."default",
    ADD COLUMN IF NOT EXISTS bronze_folderpath                           text COLLATE pg_catalog."default";

--
-- TOC entry 479 (class 1259 OID 3570053)
-- Name: silver_transaction_item; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_transaction_item (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    orderitemid text,
    itemsessionid text,
    menuitemid text,
    menu_item_pos_id text,
    itemname text,
    categoryid text,
    categoryname text,
    category_pos_id text,
    items_concept_id text,
    items_concept_name text,
    itemquantity integer,
    usd_itemunitprice numeric(12,3),
    usd_total_item_price numeric(12,3),
    cents_itemunitprice bigint,
    cents_total_item_price bigint,
    modifier_options text,
    items_discount_id text,
    is_items_discount_hidden_on_receipt boolean,
    items_discounts text,
    items_upsell_source text,
    items_reward_source text,
    items_special_request text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_transaction_item OWNER TO citus;

ALTER TABLE IF EXISTS stg.silver_transaction_item
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;
--
-- TOC entry 470 (class 1259 OID 3428544)
-- Name: silver_transaction_payment; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_transaction_payment (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    payment_transactionid text,
    payment_method text,
    payment_status text,
    payment_amount numeric(12,3),
    payment_tender_id text,
    payment_integration_id text,
    payment_integration_label text,
    payment_card_name text,
    payment_card_number text,
    is_amazon_one_payment boolean,
    card_info_card_type text,
    card_info_last_four text,
    card_info_masked_card_number text,
    card_info_zip_code text,
    card_info_expiration_month text,
    card_info_expiration_year text,
    card_info_processor_auth_code text,
    card_info_available_balance numeric(12,3),
    payment_capture_details text,
    payment_settlement_details text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_transaction_payment OWNER TO citus;

ALTER TABLE IF EXISTS stg.silver_transaction_payment
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

--
-- TOC entry 475 (class 1259 OID 3531845)
-- Name: silver_transaction_refunds; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_transaction_refunds (
    locationid text,
    transactionheaderid text NOT NULL,
    orderid text,
    original_transaction_id text,
    refund_transaction_id text,
    refund_type text,
    refunded_amount numeric(12,3),
    order_completion_status text,
    orderdateutc text,
    syscosmosts bigint,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_transaction_refunds OWNER TO citus;

ALTER TABLE IF EXISTS stg.silver_transaction_refunds
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;


--
-- TOC entry 480 (class 1259 OID 3571355)
-- Name: silver_upsell_recommendations; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.silver_upsell_recommendations (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    recommendationid text,
    prompttimestamp text,
    modal_version text,
    offered_items text,
    selected_items text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone,
    bronze_folderpath TEXT
);


ALTER TABLE stg.silver_upsell_recommendations OWNER TO citus;

ALTER TABLE IF EXISTS stg.silver_upsell_recommendations
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

--
-- TOC entry 476 (class 1259 OID 3567138)
-- Name: temp_silver_transaction_header; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.temp_silver_transaction_header (
    id integer,
    transactionheaderid text,
    orderid text,
    locationid text,
    kioskid text,
    ordersessionid text,
    dateid integer,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    orderstatus text,
    ordertype integer,
    numberofitems smallint,
    numberofpayments smallint,
    ordersredeemedrewards numeric(12,3),
    ordersubtotal numeric(12,3),
    ordertotal numeric(12,3),
    ordertax numeric(12,3),
    ordertip numeric(12,3),
    orderdiscount numeric(12,3),
    orderbalance numeric(12,3),
    paymentstatus text,
    sourcefile text,
    createddate timestamp without time zone,
    charityamount numeric(12,3),
    orderservicecharge numeric(12,3),
    businessdate date,
    syscosmosts bigint,
    channel text,
    guestcount integer,
    frequentcustomerid text,
    customername text
);


ALTER TABLE stg.temp_silver_transaction_header OWNER TO citus;

--
-- TOC entry 467 (class 1259 OID 3244112)
-- Name: transactionheader; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE IF NOT EXISTS stg.transactionheader (
    id text NOT NULL,
    kiosksessionid text,
    orderid text,
    locationid text,
    type text,
    ordertype text,
    ordertypelabel text,
    channel integer,
    orderdate text,
    businessdate text,
    guestcount integer,
    possubmissionstatus integer,
    isfailedtosendtopos boolean,
    istestorder boolean,
    clientipaddress text,
    conceptid text,
    conceptname text,
    loyaltyuser text,
    loyaltyprovidertransactionid text,
    loyaltyproviderpaymenttransactionid text,
    receiptimage text,
    orderreceipturl text,
    orderreceiptpdfurl text,
    guestcheckimagelink text,
    totals text,
    totalscents text,
    localcurrencydetails text,
    orderidentity text,
    kiosksource text,
    upsellinformation text,
    receiptdetails text,
    items text,
    combos text,
    paymentdetails text,
    redeemedrewards text,
    discounts text,
    concepts text,
    sys_rid text,
    sys_self text,
    sys_etag text,
    sys_attachments text,
    sys_lsn bigint,
    syscosmosts bigint,
    bronze_filepath text
);


ALTER TABLE stg.transactionheader OWNER TO citus;


-- ================================================================
-- SOURCE TABLES
-- ================================================================

-- Covers: partition filter + type filter on all 9 sections
--         + DELETE WHERE bronze_folderpath in FLUSH
-- Composite wins over single-column because type appears in every WHERE
CREATE INDEX IF NOT EXISTS idx_stg_silver_all_trxn_ent_folderpath_type
ON stg.silver_all_transaction_entities ("bronze_folderpath", "type");

-- Covers: partition filter + FLUSH DELETE
-- LOWER() filters on application/eventmodule are cheap after partition reduces the set
CREATE INDEX IF NOT EXISTS idx_stg_silver_all_gem_events_folderpath
ON stg.silver_all_gem_events ("bronze_folderpath");


-- ================================================================
-- TARGET TABLES — NOT EXISTS subquery lookups
-- usp_distribute_silver_transaction_entities
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_hdr_txid_loc
ON stg.silver_transaction_header (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_pmt_txid_loc
ON stg.silver_transaction_payment (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_item_txid_loc
ON stg.silver_transaction_item (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_item_mod_txid_loc
ON stg.silver_item_modifiers (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_combo_txid_loc
ON stg.silver_transaction_combo_items (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_upsell_rec_txid_loc
ON stg.silver_upsell_recommendations (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_mod_rec_txid_loc
ON stg.silver_modifier_recommendations (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_mod_imp_txid_loc
ON stg.silver_modifier_impressions (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_mod_int_txid_loc
ON stg.silver_modifier_interactions (locationid, transactionheaderid);

CREATE INDEX IF NOT EXISTS idx_stg_silver_trxn_ref_txid_loc
ON stg.silver_transaction_refunds (locationid, transactionheaderid);


-- ================================================================
-- TARGET TABLES — NOT EXISTS subquery lookups
-- usp_distribute_silver_gem_events
-- ================================================================

CREATE INDEX IF NOT EXISTS idx_stg_silver_kiosk_events_id_loc
ON stg.silver_kiosk_events (locationid, id);

CREATE INDEX IF NOT EXISTS idx_stg_silver_cep_incidents_id_loc
ON stg.silver_cep_incidents (locationid, id);
--
-- TOC entry 6128 (class 2604 OID 419503)
-- Name: experiment dimkey; Type: DEFAULT; Schema: dim; Owner: citus
--

--ALTER TABLE ONLY dim.experiment ALTER COLUMN dimkey SET DEFAULT nextval('dim.experiment_dimkey_seq'::regclass);




--
-- TOC entry 6306 (class 2606 OID 2178868)
-- Name: catalog catalog_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--
/*
ALTER TABLE ONLY dim.catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (catalogid);


--
-- TOC entry 6150 (class 2606 OID 32817)
-- Name: company company_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (companyid);


--
-- TOC entry 6153 (class 2606 OID 32825)
-- Name: datedim datedim_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.datedim
    ADD CONSTRAINT datedim_pk PRIMARY KEY (dateid);


--
-- TOC entry 6239 (class 2606 OID 413632)
-- Name: device device_deviceid_locationid_companyid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_deviceid_locationid_companyid_key UNIQUE (deviceid, locationid, companyid);


--
-- TOC entry 6241 (class 2606 OID 413630)
-- Name: device device_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_pkey PRIMARY KEY (id);


--
-- TOC entry 6157 (class 2606 OID 32835)
-- Name: element dimelement_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.element
    ADD CONSTRAINT dimelement_pkey PRIMARY KEY (elementid);


--
-- TOC entry 6263 (class 2606 OID 419507)
-- Name: experiment experiment_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.experiment
    ADD CONSTRAINT experiment_pkey PRIMARY KEY (dimkey);


--
-- TOC entry 6222 (class 2606 OID 779308)
-- Name: frequentcustomer frequent_customer_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer
    ADD CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6343 (class 2606 OID 3418404)
-- Name: frequentcustomer_bkp frequentcustomer_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer_bkp
    ADD CONSTRAINT frequentcustomer_bkp_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6296 (class 2606 OID 762128)
-- Name: grubbrr_source_lookup grubbrr_source_lookup_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.grubbrr_source_lookup
    ADD CONSTRAINT grubbrr_source_lookup_pkey PRIMARY KEY (id);


--
-- TOC entry 6315 (class 2606 OID 2888241)
-- Name: item_modifier_group_modifier_mapping item_modgrp_modfr_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.item_modifier_group_modifier_mapping
    ADD CONSTRAINT item_modgrp_modfr_unq UNIQUE (menuitemid, modifiergroupid, modifierid);


--
-- TOC entry 6279 (class 2606 OID 514418)
-- Name: itemcategory_bkp itemcategory_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory_bkp
    ADD CONSTRAINT itemcategory_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 6161 (class 2606 OID 32844)
-- Name: itemcategory itemcategory_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory
    ADD CONSTRAINT itemcategory_pk PRIMARY KEY (id);


--
-- TOC entry 6224 (class 2606 OID 311956)
-- Name: kiosk kiosk_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_pk PRIMARY KEY (id);


--
-- TOC entry 6226 (class 2606 OID 311958)
-- Name: kiosk kiosk_uidx; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_uidx UNIQUE (locationid, kioskid);


--
-- TOC entry 6302 (class 2606 OID 2047632)
-- Name: category_hierarchy location_category_menuitem_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.category_hierarchy
    ADD CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6228 (class 2606 OID 327015)
-- Name: locationcatalog location_ctlg_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.locationcatalog
    ADD CONSTRAINT location_ctlg_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 6235 (class 2606 OID 387346)
-- Name: weather_bkp location_date_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.weather_bkp
    ADD CONSTRAINT location_date_bkp_pk PRIMARY KEY (locationid, businessdate);


--
-- TOC entry 6237 (class 2606 OID 393495)
-- Name: weather location_date_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.weather
    ADD CONSTRAINT location_date_pk PRIMARY KEY (locationid, apicalldate);


--
-- TOC entry 6164 (class 2606 OID 32869)
-- Name: location location_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.location
    ADD CONSTRAINT location_pk PRIMARY KEY (companyid, locationid);


--
-- TOC entry 6304 (class 2606 OID 2047655)
-- Name: duplicate_items_master locationid_categoryid_menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.duplicate_items_master
    ADD CONSTRAINT locationid_categoryid_menuitemid_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6298 (class 2606 OID 806161)
-- Name: vw_grubbrrinstallbase locationid_deviceid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase
    ADD CONSTRAINT locationid_deviceid_pk PRIMARY KEY (location_id, kiosk_id);


--
-- TOC entry 6341 (class 2606 OID 3327448)
-- Name: vw_grubbrrinstallbase_all_devices locationid_kioskid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase_all_devices
    ADD CONSTRAINT locationid_kioskid_pk PRIMARY KEY (location_id, kiosk_id);


--
-- TOC entry 6282 (class 2606 OID 594665)
-- Name: kioskdetails locationid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kioskdetails
    ADD CONSTRAINT locationid_pkey PRIMARY KEY (locationid);


--
-- TOC entry 6294 (class 2606 OID 695509)
-- Name: menuentities menuentities_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuentities
    ADD CONSTRAINT menuentities_pkey PRIMARY KEY (entityid);


--
-- TOC entry 6231 (class 2606 OID 359373)
-- Name: menuitem menuitem_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitem_pk PRIMARY KEY (id);


--
-- TOC entry 6233 (class 2606 OID 779647)
-- Name: menuitem menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitemid_unq UNIQUE (menuitemid);


--
-- TOC entry 6311 (class 2606 OID 2951718)
-- Name: modifier_group_mapping modfrgrp_modfr_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group_mapping
    ADD CONSTRAINT modfrgrp_modfr_unq UNIQUE (modifiergroupid, modifierid);


--
-- TOC entry 6320 (class 2606 OID 2951561)
-- Name: modifier_group modifier_group_master_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group
    ADD CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid);


--
-- TOC entry 6313 (class 2606 OID 2196815)
-- Name: modifier_group_mapping modifier_group_modifier_glue_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group_mapping
    ADD CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id);


--
-- TOC entry 6309 (class 2606 OID 2888243)
-- Name: modifier modifierid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier
    ADD CONSTRAINT modifierid_unq UNIQUE (modifierid);


--
-- TOC entry 6284 (class 2606 OID 672299)
-- Name: ordertype_bkp ordertype_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype_bkp
    ADD CONSTRAINT ordertype_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 6168 (class 2606 OID 32886)
-- Name: ordertype ordertype_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype
    ADD CONSTRAINT ordertype_pk PRIMARY KEY (id);


--
-- TOC entry 6265 (class 2606 OID 431163)
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- TOC entry 6173 (class 2606 OID 775937)
-- Name: organizationlocation organizationid_locationid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organizationlocation
    ADD CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 6248 (class 2606 OID 413646)
-- Name: peripheral peripheral_deviceid_peripheralid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_peripheralid_key UNIQUE (deviceid, peripheralid);


--
-- TOC entry 6251 (class 2606 OID 413644)
-- Name: peripheral peripheral_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_pkey PRIMARY KEY (id);


--
-- TOC entry 6337 (class 2606 OID 3087662)
-- Name: occasionsurvey survey_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.occasionsurvey
    ADD CONSTRAINT survey_pkey PRIMARY KEY (surveykey);


--
-- TOC entry 6275 (class 2606 OID 471809)
-- Name: upsellgrouplookup upsellgroupid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.upsellgrouplookup
    ADD CONSTRAINT upsellgroupid_pkey PRIMARY KEY (upsellgroupid);


--
-- TOC entry 6209 (class 2606 OID 103204)
-- Name: userlocation userlocation_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.userlocation
    ADD CONSTRAINT userlocation_pkey PRIMARY KEY (userid, locationid);


--
-- TOC entry 6346 (class 2606 OID 3518729)
-- Name: bronze_partition_registry bronze_partition_registry_pkey; Type: CONSTRAINT; Schema: etl; Owner: citus
--

ALTER TABLE ONLY etl.bronze_partition_registry
    ADD CONSTRAINT bronze_partition_registry_pkey PRIMARY KEY (entity, dateid);


--
-- TOC entry 6254 (class 2606 OID 413951)
-- Name: devicehealth devicehealth_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicehealth
    ADD CONSTRAINT devicehealth_pkey PRIMARY KEY (id);


--
-- TOC entry 6211 (class 2606 OID 3650141)
-- Name: devicetelemetry devicetelemetry_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT devicetelemetry_pkey PRIMARY KEY (locationid, deviceid, dateid);


--
-- TOC entry 6289 (class 2606 OID 694784)
-- Name: location_menu_preferences location_dayparts_itemid_itemtype_unq; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.location_menu_preferences
    ADD CONSTRAINT location_dayparts_itemid_itemtype_unq UNIQUE (locationid, day_parts, itemid, itemtype);


--
-- TOC entry 6267 (class 2606 OID 775712)
-- Name: recommendations locationid_trxnid_recommendationid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT locationid_trxnid_recommendationid_pk PRIMARY KEY (locationid, transactionheaderid, recommendationid);


--
-- TOC entry 6188 (class 2606 OID 32958)
-- Name: ordertiming ordertiming_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.ordertiming
    ADD CONSTRAINT ordertiming_pkey PRIMARY KEY (id);


--
-- TOC entry 6260 (class 2606 OID 413963)
-- Name: peripheralhealth peripheralhealth_healthdataid_peripheralid_key; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.peripheralhealth
    ADD CONSTRAINT peripheralhealth_healthdataid_peripheralid_key UNIQUE (healthdataid, peripheralid);


--
-- TOC entry 6300 (class 2606 OID 888772)
-- Name: pos_sales_details pos_sales_details_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.pos_sales_details
    ADD CONSTRAINT pos_sales_details_pkey PRIMARY KEY (id);


--
-- TOC entry 6322 (class 2606 OID 2987108)
-- Name: sent_surveys sent_surveys_ordersessionid_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.sent_surveys
    ADD CONSTRAINT sent_surveys_ordersessionid_pkey PRIMARY KEY (locationid, ordersessionid);


--
-- TOC entry 6192 (class 2606 OID 32976)
-- Name: timingsdatalake timingsdatalake_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.timingsdatalake
    ADD CONSTRAINT timingsdatalake_pkey PRIMARY KEY (containername);


--
-- TOC entry 6196 (class 2606 OID 294801)
-- Name: transactionheader transactionheader_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT transactionheader_pkey PRIMARY KEY (locationid, transactionheaderid);


--
-- TOC entry 6269 (class 2606 OID 454567)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 6199 (class 2606 OID 57357)
-- Name: transactionitem transactionitem_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT transactionitem_pkey PRIMARY KEY (transactionheaderid, itemid, itemname);


--
-- TOC entry 6186 (class 2606 OID 1175206)
-- Name: itemmodifier trxnid_itemid_mdfrgrpid_mdfrid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemmodifier
    ADD CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY KEY (transactionheaderid, itemid, modifiergroupid, modifierid);


--
-- TOC entry 6287 (class 2606 OID 676695)
-- Name: vw_offer_analysis trxnid_recommendationid_itemid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT trxnid_recommendationid_itemid_uidx UNIQUE (transactionheaderid, recommendationid, offereditem);


--
-- TOC entry 6271 (class 2606 OID 459796)
-- Name: userbehaviour_exceptions userbehaviour_exceptions_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour_exceptions
    ADD CONSTRAINT userbehaviour_exceptions_pkey PRIMARY KEY (id);


--
-- TOC entry 6205 (class 2606 OID 33010)
-- Name: userbehaviour userbehaviour_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour
    ADD CONSTRAINT userbehaviour_pkey PRIMARY KEY (id);


--
-- TOC entry 6216 (class 2606 OID 3652822)
-- Name: usercheckedin usercheckedin_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.usercheckedin
    ADD CONSTRAINT usercheckedin_pkey PRIMARY KEY (locationid, orderid);


--
-- TOC entry 6207 (class 2606 OID 3583307)
-- Name: watermarktable watermarktablename_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.watermarktable
    ADD CONSTRAINT watermarktablename_pk PRIMARY KEY (watermarktablename, source);




--
-- TOC entry 6358 (class 2606 OID 3589002)
-- Name: dim_catalog catalog_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (catalogid);


--
-- TOC entry 6348 (class 2606 OID 3584739)
-- Name: dim_frequentcustomer frequent_customer_pk; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_frequentcustomer
    ADD CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6350 (class 2606 OID 3586063)
-- Name: dim_category_hierarchy location_category_menuitem_unq; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_category_hierarchy
    ADD CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6354 (class 2606 OID 3586088)
-- Name: dim_modifiergroup_modifier_mapping modfrgrp_modfr_unq; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_modifiergroup_modifier_mapping
    ADD CONSTRAINT modfrgrp_modfr_unq UNIQUE (modifiergroupid, modifierid);


--
-- TOC entry 6352 (class 2606 OID 3586079)
-- Name: dim_modifiergroup modifier_group_master_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_modifiergroup
    ADD CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid);


--
-- TOC entry 6356 (class 2606 OID 3586086)
-- Name: dim_modifiergroup_modifier_mapping modifier_group_modifier_glue_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_modifiergroup_modifier_mapping
    ADD CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id);


--
-- TOC entry 6362 (class 2606 OID 3644486)
-- Name: dim_organization organization_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- TOC entry 6360 (class 2606 OID 3605523)
-- Name: dim_organizationlocation organizationid_locationid_pk; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_organizationlocation
    ADD CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 6339 (class 2606 OID 3244118)
-- Name: transactionheader pk_transactionheader; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.transactionheader
    ADD CONSTRAINT pk_transactionheader PRIMARY KEY (id);


--
-- TOC entry 6317 (class 2606 OID 2959149)
-- Name: sent_surveys sent_surveys_ordersessionid_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.sent_surveys
    ADD CONSTRAINT sent_surveys_ordersessionid_pkey PRIMARY KEY (locationid, ordersessionid);


--
-- TOC entry 6273 (class 2606 OID 461044)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 6151 (class 1259 OID 32826)
-- Name: IX_dateid_datets; Type: INDEX; Schema: dim; Owner: citus
--

*/


CREATE INDEX IF NOT EXISTS "IX_dateid_datets" ON dim.datedim USING btree (dateid, datets);


--
-- TOC entry 6169 (class 1259 OID 32893)
-- Name: IX_organizationid_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS "IX_organizationid_locationid" ON dim.organizationlocation USING btree (organizationid, locationid) INCLUDE (organizationname, locationname);


--
-- TOC entry 6148 (class 1259 OID 32818)
-- Name: company_id_idx; Type: INDEX; Schema: dim; Owner: citus
--

-- CREATE INDEX IF NOT EXISTS company_id_idx ON dim.company USING btree (companyid);


--
-- TOC entry 6242 (class 1259 OID 413633)
-- Name: deviceid_locationid_companyid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS deviceid_locationid_companyid_idx ON dim.device USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, state, testmode);


--
-- TOC entry 6162 (class 1259 OID 32870)
-- Name: dim_location_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS dim_location_idx ON dim.location USING btree (locationid);


--
-- TOC entry 6154 (class 1259 OID 32827)
-- Name: idx_datedim_dateid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_datedim_dateid ON dim.datedim USING btree (dateid);


--
-- TOC entry 6155 (class 1259 OID 32828)
-- Name: idx_datedim_datets; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_datedim_datets ON dim.datedim USING btree (datets);


--
-- TOC entry 6243 (class 1259 OID 413634)
-- Name: idx_device_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_device_id ON dim.device USING btree (deviceid);


--
-- TOC entry 6244 (class 1259 OID 413635)
-- Name: idx_device_location_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_device_location_id ON dim.device USING btree (locationid);


--
-- TOC entry 6245 (class 1259 OID 413636)
-- Name: idx_device_state; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_device_state ON dim.device USING btree (state);


--
-- TOC entry 6246 (class 1259 OID 413637)
-- Name: idx_device_testmode; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_device_testmode ON dim.device USING btree (testmode);


--
-- TOC entry 6290 (class 1259 OID 695510)
-- Name: idx_menuentities_catalog; Type: INDEX; Schema: dim; Owner: citus
--

--CREATE INDEX IF NOT EXISTS idx_menuentities_catalog ON dim.menuentities USING btree (catalogid);


--
-- TOC entry 6291 (class 1259 OID 695512)
-- Name: idx_menuentities_mealavail; Type: INDEX; Schema: dim; Owner: citus
--

--CREATE INDEX IF NOT EXISTS idx_menuentities_mealavail ON dim.menuentities USING gin (mealavailability);


--
-- TOC entry 6292 (class 1259 OID 695511)
-- Name: idx_menuentities_tags; Type: INDEX; Schema: dim; Owner: citus
--

--CREATE INDEX IF NOT EXISTS idx_menuentities_tags ON dim.menuentities USING gin (tags);


--
-- TOC entry 6170 (class 1259 OID 32894)
-- Name: idx_organizationlocation_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_organizationlocation_locationid ON dim.organizationlocation USING btree (locationid);


--
-- TOC entry 6171 (class 1259 OID 32895)
-- Name: idx_organizationlocation_organizationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_organizationlocation_organizationid ON dim.organizationlocation USING btree (organizationid);


--
-- TOC entry 6174 (class 1259 OID 32911)
-- Name: idx_view_viewid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_view_viewid ON dim.view USING btree (viewid);


--
-- TOC entry 6276 (class 1259 OID 514419)
-- Name: itemcategory_bkp_idx; Type: INDEX; Schema: dim; Owner: citus
--

-- CREATE UNIQUE INDEX IF NOT EXISTS itemcategory_bkp_idx ON dim.itemcategory_bkp USING btree (locationid, categoryid);


--
-- TOC entry 6277 (class 1259 OID 514420)
-- Name: itemcategory_bkp_locationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

-- CREATE INDEX IF NOT EXISTS itemcategory_bkp_locationid_idx ON dim.itemcategory_bkp USING btree (locationid) INCLUDE (categoryid, isactive);


--
-- TOC entry 6158 (class 1259 OID 32845)
-- Name: itemcategory_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX IF NOT EXISTS itemcategory_idx ON dim.itemcategory USING btree (locationid, categoryid);


--
-- TOC entry 6159 (class 1259 OID 263819)
-- Name: itemcategory_locationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS itemcategory_locationid_idx ON dim.itemcategory USING btree (locationid) INCLUDE (categoryid, isactive);


--
-- TOC entry 6229 (class 1259 OID 3399343)
-- Name: ix_dim_menuitem_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_dim_menuitem_catalogid ON dim.menuitem USING btree (catalogid);


--
-- TOC entry 6307 (class 1259 OID 3399344)
-- Name: ix_dim_modifier_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_dim_modifier_catalogid ON dim.modifier USING btree (catalogid);


--
-- TOC entry 6318 (class 1259 OID 3399345)
-- Name: ix_dim_modifiergroup_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_dim_modifiergroup_catalogid ON dim.modifier_group USING btree (catalogid);


--
-- TOC entry 6165 (class 1259 OID 263829)
-- Name: locationgroupid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS locationgroupid_idx ON dim.location USING btree (locationgroupid);


--
-- TOC entry 6166 (class 1259 OID 32887)
-- Name: order_type_uidx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX IF NOT EXISTS order_type_uidx ON dim.ordertype USING btree (locationid, kioskid, ordertypeid);


--
-- TOC entry 6249 (class 1259 OID 413652)
-- Name: peripheral_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS peripheral_idx ON dim.peripheral USING btree (deviceid, peripheralid) INCLUDE (peripheraltype, state, statechangedate);


--
-- TOC entry 6218 (class 1259 OID 263813)
-- Name: rating_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS rating_idx ON dim.feedbackrating USING btree (rating) INCLUDE (ratingdesc);


--
-- TOC entry 6217 (class 1259 OID 263814)
-- Name: surveytransstatus_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX IF NOT EXISTS surveytransstatus_idx ON dim.feedbackstatus USING btree (surveytransstatus) INCLUDE (statusdesc);


--
-- TOC entry 6175 (class 1259 OID 32927)
-- Name: deviceeventidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS deviceeventidx ON fact.deviceevent USING btree (companyid, locationid);


--
-- TOC entry 6176 (class 1259 OID 32928)
-- Name: deviceeventuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS deviceeventuidx ON fact.deviceevent USING btree (application, companyid, locationid, moduleid, eventtoken, datacategory, actiontype, eventinstant);


--
-- TOC entry 6252 (class 1259 OID 413952)
-- Name: devicehealth_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS devicehealth_idx ON fact.devicehealth USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, status, healthdatatype, healthdatatime, statuschangetime);


--
-- TOC entry 6255 (class 1259 OID 413953)
-- Name: deviceid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS deviceid_idx ON fact.devicehealth USING btree (deviceid);


--
-- TOC entry 6256 (class 1259 OID 413954)
-- Name: idx_devicehealth_deviceid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid ON fact.devicehealth USING btree (deviceid);


--
-- TOC entry 6257 (class 1259 OID 413955)
-- Name: idx_devicehealth_deviceid_status_time; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid_status_time ON fact.devicehealth USING btree (deviceid, status, healthdatatime DESC);


--
-- TOC entry 6258 (class 1259 OID 413956)
-- Name: idx_devicehealth_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicehealth_locationid ON fact.devicehealth USING btree (locationid);


--
-- TOC entry 6179 (class 1259 OID 32934)
-- Name: idx_devicestate; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicestate ON fact.devicestate USING btree (locationid, companyid, deviceid) WITH (deduplicate_items='true');


--
-- TOC entry 6180 (class 1259 OID 32935)
-- Name: idx_devicestate_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicestate_dateid ON fact.devicestate USING btree (dateid);


--
-- TOC entry 6181 (class 1259 OID 32936)
-- Name: idx_devicestate_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicestate_locationid ON fact.devicestate USING btree (locationid);


--
-- TOC entry 6212 (class 1259 OID 159819)
-- Name: idx_devicetelemetry; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicetelemetry ON fact.devicetelemetry USING btree (locationid, deviceid);


--
-- TOC entry 6213 (class 1259 OID 159820)
-- Name: idx_devicetelemetry_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicetelemetry_dateid ON fact.devicetelemetry USING btree (dateid);


--
-- TOC entry 6214 (class 1259 OID 159821)
-- Name: idx_devicetelemetry_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_devicetelemetry_locationid ON fact.devicetelemetry USING btree (locationid);


--
-- TOC entry 6182 (class 1259 OID 3584720)
-- Name: idx_fact_itemmodifier_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_fact_itemmodifier_locationid ON fact.itemmodifier USING btree (locationid);


--
-- TOC entry 6190 (class 1259 OID 309287)
-- Name: idx_fact_pipelinerunstatus_correlationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_fact_pipelinerunstatus_correlationid ON fact.pipelinerunstatus USING btree (correlationid) INCLUDE (pipelinestatus);


--
-- TOC entry 6197 (class 1259 OID 3583313)
-- Name: idx_fact_transactionitem_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_fact_transactionitem_locationid ON fact.transactionitem USING btree (locationid);


--
-- TOC entry 6200 (class 1259 OID 3583314)
-- Name: idx_fact_transactionpayment_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_fact_transactionpayment_locationid ON fact.transactionpayment USING btree (locationid);


--
-- TOC entry 6280 (class 1259 OID 547181)
-- Name: idx_transactionrefunds_headerid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS idx_transactionrefunds_headerid ON fact.transactionrefunds USING btree (transactionheaderid);


--
-- TOC entry 6183 (class 1259 OID 32951)
-- Name: itemmodifieridx; Type: INDEX; Schema: fact; Owner: citus
--

--CREATE INDEX IF NOT EXISTS itemmodifieridx ON fact.itemmodifier USING btree (itemid);


--
-- TOC entry 6177 (class 1259 OID 2198165)
-- Name: ix_deviceevent_journey_lookup; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_deviceevent_journey_lookup ON fact.deviceevent USING btree (locationid, dateid, datacategory, eventtoken) WHERE ((datacategory = 'insight'::text) AND (actiontype = ANY (ARRAY['CategorySelected'::text, 'SubCategorySelected'::text, 'RegularItemSelected'::text, 'ItemRemoved'::text, 'ModifierGroupSelected'::text, 'ModifierSelected'::text, 'ModifierUnselected'::text])));


--
-- TOC entry 6178 (class 1259 OID 3605477)
-- Name: ix_deviceevent_syscosmosts_brin; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_deviceevent_syscosmosts_brin ON fact.deviceevent USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6193 (class 1259 OID 3617347)
-- Name: ix_transactionheader_syscosmosts_brin; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_transactionheader_syscosmosts_brin ON fact.transactionheader USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6202 (class 1259 OID 3617344)
-- Name: ix_userbehaviour_syscosmosts_brin; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_userbehaviour_syscosmosts_brin ON fact.userbehaviour USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6285 (class 1259 OID 676696)
-- Name: locationid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS locationid_idx ON fact.vw_offer_analysis USING btree (locationid);


--
-- TOC entry 6261 (class 1259 OID 413969)
-- Name: peripheralhealth_idx; Type: INDEX; Schema: fact; Owner: citus
--

--CREATE INDEX IF NOT EXISTS peripheralhealth_idx ON fact.peripheralhealth USING btree (healthdataid, peripheralid) INCLUDE (peripheraltype, status);


--
-- TOC entry 6189 (class 1259 OID 32964)
-- Name: peripheralstate_uidx; Type: INDEX; Schema: fact; Owner: citus
--

--CREATE UNIQUE INDEX peripheralstate_uidx ON fact.peripheralstate USING btree (deviceid, peripheralid, state, statestart);


--
-- TOC entry 6194 (class 1259 OID 263880)
-- Name: transactionheader_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS transactionheader_locationid_dateid_idx ON fact.transactionheader USING btree (locationid, dateid) INCLUDE (orderstatus, ordertype, businessdate);


--
-- TOC entry 6184 (class 1259 OID 263867)
-- Name: transactionheaderid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS transactionheaderid_idx ON fact.itemmodifier USING btree (transactionheaderid);


--
-- TOC entry 6201 (class 1259 OID 33003)
-- Name: transactionpaymentuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS transactionpaymentuidx ON fact.transactionpayment USING btree (transactionheaderid, paymentintegrationid, paymentid);


--
-- TOC entry 6203 (class 1259 OID 263900)
-- Name: userbehaviour_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX IF NOT EXISTS userbehaviour_locationid_dateid_idx ON fact.userbehaviour USING btree (locationid, dateid) INCLUDE (ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier);


--
-- TOC entry 6335 (class 1259 OID 3050933)
-- Name: ix_ml_imm_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_imm_locationid ON ml.item_modifiergroup_modifier_mapping USING btree (locationid);


--
-- TOC entry 6330 (class 1259 OID 3044539)
-- Name: ix_ml_me_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_me_locationid ON ml.menu_entities USING btree (locationid);


--
-- TOC entry 6331 (class 1259 OID 3044540)
-- Name: ix_ml_me_menuitemid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_me_menuitemid ON ml.menu_entities USING btree (menuitemid);


--
-- TOC entry 6333 (class 1259 OID 3050934)
-- Name: ix_ml_mi_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_mi_locid_yyyy_ww ON ml.modifier_interactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6334 (class 1259 OID 3050935)
-- Name: ix_ml_mimp_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_mimp_locid_yyyy_ww ON ml.modifier_impressions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6332 (class 1259 OID 3050806)
-- Name: ix_ml_trx_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_trx_locid_yyyy_ww ON ml.transactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6323 (class 1259 OID 3042200)
-- Name: ix_ml_ua_businessdate; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_ua_businessdate ON ml.upsell_analysis USING btree (businessdate);


--
-- TOC entry 6324 (class 1259 OID 3042199)
-- Name: ix_ml_ua_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_ua_locid_yyyy_ww ON ml.upsell_analysis USING btree (locationid, yyyy, ww);


--
-- TOC entry 6325 (class 1259 OID 3042198)
-- Name: ix_ml_ua_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_ua_yyyy_ww ON ml.upsell_analysis USING btree (yyyy, ww);


--
-- TOC entry 6326 (class 1259 OID 3044148)
-- Name: ix_ml_wth_locationid_weatherdate_hh; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_wth_locationid_weatherdate_hh ON ml.weather USING btree (locationid, weatherdate, hh);


--
-- TOC entry 6327 (class 1259 OID 3042228)
-- Name: ix_ml_wth_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_wth_locid_yyyy_ww ON ml.weather USING btree (locationid, yyyy, ww);


--
-- TOC entry 6328 (class 1259 OID 3042229)
-- Name: ix_ml_wth_weatherdate; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_wth_weatherdate ON ml.weather USING btree (weatherdate);


--
-- TOC entry 6329 (class 1259 OID 3042227)
-- Name: ix_ml_wth_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_ml_wth_yyyy_ww ON ml.weather USING btree (yyyy, ww);


--
-- TOC entry 6344 (class 1259 OID 3605478)
-- Name: ix_silver_kiosk_events_syscosmosts_brin; Type: INDEX; Schema: stg; Owner: citus
--

CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_syscosmosts_brin ON stg.silver_kiosk_events USING brin (syscosmosts) WITH (pages_per_range='128');

-- New indexes from schema evolution file
CREATE INDEX IF NOT EXISTS idx_fact_transactionitem_locationid
    ON fact.transactionitem(locationid);
CREATE INDEX IF NOT EXISTS idx_fact_transactionpayment_locationid
    ON fact.transactionpayment(locationid);
CREATE INDEX IF NOT EXISTS idx_fact_itemmodifier_locationid
    ON fact.itemmodifier(locationid);
CREATE INDEX IF NOT EXISTS ix_dim_menuitem_catalogid
    ON dim.menuitem(catalogid);
CREATE INDEX IF NOT EXISTS ix_dim_modifier_catalogid
    ON dim.modifier(catalogid);
CREATE INDEX IF NOT EXISTS ix_dim_modifiergroup_catalogid
    ON dim.modifier_group(catalogid);



--
-- TOC entry 6384 (class 2606 OID 3327449)
-- Name: vw_grubbrrinstallbase_all_devices organizationid_locationid_fk; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--
/*
ALTER TABLE ONLY dim.vw_grubbrrinstallbase_all_devices
    ADD CONSTRAINT organizationid_locationid_fk FOREIGN KEY (organization_id, location_id) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6379 (class 2606 OID 413647)
-- Name: peripheral peripheral_deviceid_fkey; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES dim.device(id);


--
-- TOC entry 6367 (class 2606 OID 514947)
-- Name: transactionitem categoryid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT categoryid_fk FOREIGN KEY (categoryid) REFERENCES dim.itemcategory(id);


--
-- TOC entry 6372 (class 2606 OID 788239)
-- Name: devicetelemetry location_deviceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT location_deviceid_fk FOREIGN KEY (locationid, deviceid) REFERENCES dim.kiosk(locationid, kioskid);


--
-- TOC entry 6381 (class 2606 OID 775338)
-- Name: recommendations location_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6373 (class 2606 OID 788249)
-- Name: devicetelemetry locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6364 (class 2606 OID 775954)
-- Name: transactionheader locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6368 (class 2606 OID 779636)
-- Name: transactionitem locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6374 (class 2606 OID 784801)
-- Name: itemssurvey locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6376 (class 2606 OID 784796)
-- Name: occasionsurveydetail locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6369 (class 2606 OID 2970909)
-- Name: transactionitem locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6371 (class 2606 OID 775974)
-- Name: transactionpayment locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionpayment
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6382 (class 2606 OID 775984)
-- Name: vw_offer_analysis locationid_trxnid_recommendationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT locationid_trxnid_recommendationid_fk FOREIGN KEY (locationid, transactionheaderid, recommendationid) REFERENCES fact.recommendations(locationid, transactionheaderid, recommendationid);


--
-- TOC entry 6370 (class 2606 OID 359444)
-- Name: transactionitem menuitemid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT menuitemid_fk FOREIGN KEY (menuitemid) REFERENCES dim.menuitem(id);


--
-- TOC entry 6365 (class 2606 OID 775964)
-- Name: transactionheader ordertype_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT ordertype_fk FOREIGN KEY (ordertype) REFERENCES dim.ordertype(id);


--
-- TOC entry 6363 (class 2606 OID 788254)
-- Name: deviceevent orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.deviceevent
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (companyid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6375 (class 2606 OID 788219)
-- Name: itemssurvey orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6377 (class 2606 OID 788224)
-- Name: occasionsurveydetail orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6380 (class 2606 OID 413964)
-- Name: peripheralhealth peripheralhealth_healthdataid_fkey; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.peripheralhealth
    ADD CONSTRAINT peripheralhealth_healthdataid_fkey FOREIGN KEY (healthdataid) REFERENCES fact.devicehealth(id);


--
-- TOC entry 6383 (class 2606 OID 779648)
-- Name: vw_offer_analysis selecteditem_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT selecteditem_fk FOREIGN KEY (selecteditem) REFERENCES dim.menuitem(menuitemid);


--
-- TOC entry 6378 (class 2606 OID 774836)
-- Name: occasionsurveydetail sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);


--
-- TOC entry 6366 (class 2606 OID 787892)
-- Name: transactionheader sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);

*/

-- TOC entry 6559 (class 0 OID 0)
-- Dependencies: 64
-- Name: SCHEMA dim; Type: ACL; Schema: -; Owner: citus
--


/*
GRANT USAGE ON SCHEMA dim TO dhanraj;
GRANT USAGE ON SCHEMA dim TO varshil;


--
-- TOC entry 6560 (class 0 OID 0)
-- Dependencies: 65
-- Name: SCHEMA fact; Type: ACL; Schema: -; Owner: citus
--

GRANT USAGE ON SCHEMA fact TO dhanraj;
GRANT USAGE ON SCHEMA fact TO varshil;


--
-- TOC entry 6562 (class 0 OID 0)
-- Dependencies: 62
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA public TO citus WITH GRANT OPTION;
SET SESSION AUTHORIZATION citus;
GRANT USAGE ON SCHEMA public TO varshil;
RESET SESSION AUTHORIZATION;




--
-- TOC entry 6571 (class 0 OID 0)
-- Dependencies: 410
-- Name: TABLE abtests; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.abtests TO varshil;


--
-- TOC entry 6572 (class 0 OID 0)
-- Dependencies: 379
-- Name: TABLE datedim; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.datedim TO dhanraj;
GRANT SELECT ON TABLE dim.datedim TO varshil;


--
-- TOC entry 6573 (class 0 OID 0)
-- Dependencies: 386
-- Name: TABLE businessdate; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.businessdate TO dhanraj;
GRANT SELECT ON TABLE dim.businessdate TO varshil;


--
-- TOC entry 6574 (class 0 OID 0)
-- Dependencies: 378
-- Name: TABLE company; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.company TO dhanraj;
GRANT SELECT ON TABLE dim.company TO varshil;


--
-- TOC entry 6575 (class 0 OID 0)
-- Dependencies: 416
-- Name: TABLE device; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.device TO varshil;


--
-- TOC entry 6576 (class 0 OID 0)
-- Dependencies: 380
-- Name: TABLE element; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.element TO dhanraj;
GRANT SELECT ON TABLE dim.element TO varshil;


--
-- TOC entry 6577 (class 0 OID 0)
-- Dependencies: 421
-- Name: TABLE experiment; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.experiment TO varshil;


--
-- TOC entry 6579 (class 0 OID 0)
-- Dependencies: 404
-- Name: TABLE feedbackrating; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackrating TO varshil;


--
-- TOC entry 6580 (class 0 OID 0)
-- Dependencies: 403
-- Name: TABLE feedbackstatus; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackstatus TO varshil;


--
-- TOC entry 6581 (class 0 OID 0)
-- Dependencies: 407
-- Name: TABLE frequentcustomer; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.frequentcustomer TO varshil;


--
-- TOC entry 6582 (class 0 OID 0)
-- Dependencies: 438
-- Name: TABLE grubbrr_source_lookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.grubbrr_source_lookup TO varshil;


--
-- TOC entry 6583 (class 0 OID 0)
-- Dependencies: 381
-- Name: TABLE itemcategory; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory TO dhanraj;
GRANT SELECT ON TABLE dim.itemcategory TO varshil;


--
-- TOC entry 6584 (class 0 OID 0)
-- Dependencies: 428
-- Name: TABLE itemcategory_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory_bkp TO varshil;


--
-- TOC entry 6585 (class 0 OID 0)
-- Dependencies: 432
-- Name: TABLE itemcategorymapping; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategorymapping TO varshil;


--
-- TOC entry 6586 (class 0 OID 0)
-- Dependencies: 408
-- Name: TABLE kiosk; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kiosk TO varshil;


--
-- TOC entry 6587 (class 0 OID 0)
-- Dependencies: 431
-- Name: TABLE kioskdetails; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kioskdetails TO varshil;


--
-- TOC entry 6588 (class 0 OID 0)
-- Dependencies: 382
-- Name: TABLE location; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.location TO dhanraj;
GRANT SELECT ON TABLE dim.location TO varshil;


--
-- TOC entry 6589 (class 0 OID 0)
-- Dependencies: 409
-- Name: TABLE locationcatalog; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.locationcatalog TO varshil;


--
-- TOC entry 6590 (class 0 OID 0)
-- Dependencies: 437
-- Name: TABLE menuentities; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuentities TO varshil;


--
-- TOC entry 6591 (class 0 OID 0)
-- Dependencies: 413
-- Name: TABLE menuitem; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuitem TO varshil;


--
-- TOC entry 6592 (class 0 OID 0)
-- Dependencies: 383
-- Name: TABLE ordertype; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype TO dhanraj;
GRANT SELECT ON TABLE dim.ordertype TO varshil;


--
-- TOC entry 6593 (class 0 OID 0)
-- Dependencies: 433
-- Name: TABLE ordertype_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype_bkp TO varshil;


--
-- TOC entry 6594 (class 0 OID 0)
-- Dependencies: 422
-- Name: TABLE organization; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organization TO varshil;


--
-- TOC entry 6595 (class 0 OID 0)
-- Dependencies: 384
-- Name: TABLE organizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.organizationlocation TO varshil;


--
-- TOC entry 6596 (class 0 OID 0)
-- Dependencies: 417
-- Name: TABLE peripheral; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.peripheral TO varshil;


--
-- TOC entry 6597 (class 0 OID 0)
-- Dependencies: 427
-- Name: TABLE upsellgrouplookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.upsellgrouplookup TO varshil;


--
-- TOC entry 6598 (class 0 OID 0)
-- Dependencies: 400
-- Name: TABLE userlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.userlocation TO varshil;


--
-- TOC entry 6599 (class 0 OID 0)
-- Dependencies: 385
-- Name: TABLE view; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.view TO dhanraj;
GRANT SELECT ON TABLE dim.view TO varshil;


--
-- TOC entry 6600 (class 0 OID 0)
-- Dependencies: 415
-- Name: TABLE weather; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather TO varshil;


--
-- TOC entry 6601 (class 0 OID 0)
-- Dependencies: 444
-- Name: TABLE vw_weatherhourlydata; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vw_weatherhourlydata TO varshil;


--
-- TOC entry 6602 (class 0 OID 0)
-- Dependencies: 387
-- Name: TABLE vworganizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vworganizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.vworganizationlocation TO varshil;


--
-- TOC entry 6603 (class 0 OID 0)
-- Dependencies: 414
-- Name: TABLE weather_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather_bkp TO varshil;


--
-- TOC entry 6604 (class 0 OID 0)
-- Dependencies: 443
-- Name: TABLE cep_incidents; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.cep_incidents TO dhanraj;


--
-- TOC entry 6605 (class 0 OID 0)
-- Dependencies: 435
-- Name: TABLE customer_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.customer_menu_preferences TO varshil;


--
-- TOC entry 6606 (class 0 OID 0)
-- Dependencies: 388
-- Name: TABLE deviceevent; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.deviceevent TO dhanraj;
GRANT SELECT ON TABLE fact.deviceevent TO varshil;


--
-- TOC entry 6607 (class 0 OID 0)
-- Dependencies: 418
-- Name: TABLE devicehealth; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicehealth TO varshil;


--
-- TOC entry 6608 (class 0 OID 0)
-- Dependencies: 389
-- Name: TABLE devicestate; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicestate TO dhanraj;
GRANT SELECT ON TABLE fact.devicestate TO varshil;


--
-- TOC entry 6609 (class 0 OID 0)
-- Dependencies: 401
-- Name: TABLE devicetelemetry; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicetelemetry TO varshil;


--
-- TOC entry 6610 (class 0 OID 0)
-- Dependencies: 390
-- Name: TABLE itemmodifier; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemmodifier TO dhanraj;
GRANT SELECT ON TABLE fact.itemmodifier TO varshil;


--
-- TOC entry 6611 (class 0 OID 0)
-- Dependencies: 411
-- Name: TABLE itemssurvey; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemssurvey TO varshil;


--
-- TOC entry 6612 (class 0 OID 0)
-- Dependencies: 436
-- Name: TABLE location_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.location_menu_preferences TO varshil;


--
-- TOC entry 6613 (class 0 OID 0)
-- Dependencies: 412
-- Name: TABLE occasionsurveydetail; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.occasionsurveydetail TO varshil;


--
-- TOC entry 6614 (class 0 OID 0)
-- Dependencies: 391
-- Name: TABLE ordertiming; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.ordertiming TO dhanraj;
GRANT SELECT ON TABLE fact.ordertiming TO varshil;


--
-- TOC entry 6615 (class 0 OID 0)
-- Dependencies: 419
-- Name: TABLE peripheralhealth; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.peripheralhealth TO varshil;


--
-- TOC entry 6616 (class 0 OID 0)
-- Dependencies: 392
-- Name: TABLE peripheralstate; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.peripheralstate TO dhanraj;
GRANT SELECT ON TABLE fact.peripheralstate TO varshil;


--
-- TOC entry 6617 (class 0 OID 0)
-- Dependencies: 393
-- Name: TABLE pipelinerunstatus; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.pipelinerunstatus TO dhanraj;
GRANT SELECT ON TABLE fact.pipelinerunstatus TO varshil;


--
-- TOC entry 6618 (class 0 OID 0)
-- Dependencies: 424
-- Name: TABLE recommendations; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.recommendations TO varshil;


--
-- TOC entry 6619 (class 0 OID 0)
-- Dependencies: 423
-- Name: TABLE recommendations_bkp; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.recommendations_bkp TO varshil;


--
-- TOC entry 6620 (class 0 OID 0)
-- Dependencies: 394
-- Name: TABLE timingsdatalake; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.timingsdatalake TO dhanraj;
GRANT SELECT ON TABLE fact.timingsdatalake TO varshil;


--
-- TOC entry 6621 (class 0 OID 0)
-- Dependencies: 395
-- Name: TABLE transactionheader; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionheader TO dhanraj;
GRANT SELECT ON TABLE fact.transactionheader TO varshil;


--
-- TOC entry 6622 (class 0 OID 0)
-- Dependencies: 396
-- Name: TABLE transactionitem; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionitem TO dhanraj;
GRANT SELECT ON TABLE fact.transactionitem TO varshil;


--
-- TOC entry 6623 (class 0 OID 0)
-- Dependencies: 397
-- Name: TABLE transactionpayment; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionpayment TO dhanraj;
GRANT SELECT ON TABLE fact.transactionpayment TO varshil;


--
-- TOC entry 6624 (class 0 OID 0)
-- Dependencies: 429
-- Name: TABLE transactionrefunds; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionrefunds TO varshil;


--
-- TOC entry 6625 (class 0 OID 0)
-- Dependencies: 398
-- Name: TABLE userbehaviour; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour TO dhanraj;
GRANT SELECT ON TABLE fact.userbehaviour TO varshil;


--
-- TOC entry 6626 (class 0 OID 0)
-- Dependencies: 425
-- Name: TABLE userbehaviour_exceptions; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour_exceptions TO varshil;


--
-- TOC entry 6627 (class 0 OID 0)
-- Dependencies: 402
-- Name: TABLE usercheckedin; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.usercheckedin TO varshil;


--
-- TOC entry 6628 (class 0 OID 0)
-- Dependencies: 434
-- Name: TABLE vw_offer_analysis; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.vw_offer_analysis TO varshil;


--
-- TOC entry 6629 (class 0 OID 0)
-- Dependencies: 399
-- Name: TABLE watermarktable; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.watermarktable TO dhanraj;
GRANT SELECT ON TABLE fact.watermarktable TO varshil;


--
-- TOC entry 6630 (class 0 OID 0)
-- Dependencies: 463
-- Name: TABLE modifier_interactions; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.modifier_interactions TO varshil;




-- Completed on 2026-05-30 14:14:07

--
-- PostgreSQL database dump complete
--

\unrestrict VFfQD00ditWwDSVTzvrOfGRggS3PfSQDVme4BEMRffIDxSUJxEDWUYHdIpBBv5N
*/
