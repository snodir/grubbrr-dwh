-- =============================================================================
-- PostgreSQL database schema — merged
-- Dumped from database version 16.9 (Ubuntu 16.9-1.pgdg20.04+1)
-- ALTER TABLE ADD COLUMN statements placed after constraints and indexes
-- Order per table: CREATE TABLE → OWNER → constraints → indexes → ALTER ADD COLUMN
-- =============================================================================

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

-- -----------------------------------------------------------------------------
-- SCHEMAS
-- -----------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS dim;
ALTER SCHEMA dim OWNER TO citus;

CREATE SCHEMA IF NOT EXISTS fact;
ALTER SCHEMA fact OWNER TO citus;

CREATE SCHEMA IF NOT EXISTS stg;
ALTER SCHEMA stg OWNER TO citus;

-- =============================================================================
-- FUNCTIONS  (defined before tables that reference them)
-- =============================================================================

CREATE OR REPLACE FUNCTION dim.is_valid_jsonb(input text)
RETURNS boolean
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  PERFORM input::jsonb;
  RETURN TRUE;
EXCEPTION WHEN others THEN
  RETURN FALSE;
END;
$$;
ALTER FUNCTION dim.is_valid_jsonb(input text) OWNER TO citus;

CREATE OR REPLACE FUNCTION dim.array_to_text(a jsonb)
RETURNS text
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN initcap(replace(replace(replace((a :: text), '[', ''), ']', ''), '"', ''));
END;
$$;

ALTER FUNCTION dim.array_to_text(a jsonb) OWNER TO citus;

CREATE OR REPLACE FUNCTION fact.updatewatermark(tablename text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  watermarkvalue timestamp without time zone;
BEGIN
  SELECT MAX(healthdatatime) INTO watermarkvalue FROM fact.devicestate;
  UPDATE fact.watermarktable SET watermarkvalue = watermarkvalue WHERE watermarktablename = tablename;
  RETURN;
END;
$$;


ALTER FUNCTION fact.updatewatermark(tablename text) OWNER TO citus;

CREATE OR REPLACE FUNCTION fact.fn_getdata(aty text, dc text, modid text, appli text)
RETURNS TABLE(
  companyid text, locationid text, eventtoken text, dateid integer,
  deviceid text, eventinstant timestamp without time zone, duration_type text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT e.companyid, e.locationid, e.eventtoken, e.dateid, e.deviceid,
    MIN(e.eventinstant::timestamp without time zone) AS eventinstant,
    'starttocheckout'::text AS duration_type
  FROM fact.deviceevent e
  WHERE e.actiontype = aty AND e.datacategory = dc AND e.moduleid = modid AND e.application = appli
  GROUP BY e.companyid, e.locationid, e.eventtoken, e.dateid, e.deviceid;
END;
$$;

ALTER FUNCTION fact.fn_getdata(aty text, dc text, modid text, appli text) OWNER TO citus;

-- =============================================================================
-- dim SCHEMA TABLES
-- =============================================================================

SET default_tablespace = '';
SET default_table_access_method = heap;

-- -----------------------------------------------------------------------------
-- dim.company
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.company OWNER TO citus;
ALTER TABLE ONLY dim.company ADD CONSTRAINT company_pkey PRIMARY KEY (companyid);
CREATE INDEX IF NOT EXISTS company_id_idx ON dim.company USING btree (companyid);

-- -----------------------------------------------------------------------------
-- dim.datedim
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.datedim OWNER TO citus;
ALTER TABLE ONLY dim.datedim ADD CONSTRAINT datedim_pk PRIMARY KEY (dateid);
CREATE INDEX IF NOT EXISTS "IX_dateid_datets" ON dim.datedim USING btree (dateid, datets);
CREATE INDEX IF NOT EXISTS idx_datedim_dateid ON dim.datedim USING btree (dateid);
CREATE INDEX IF NOT EXISTS idx_datedim_datets ON dim.datedim USING btree (datets);

-- -----------------------------------------------------------------------------
-- dim.element
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.element (
  elementid integer NOT NULL,
  sourceelementid text,
  elementname text
);
ALTER TABLE dim.element OWNER TO citus;
ALTER TABLE ONLY dim.element ADD CONSTRAINT dimelement_pkey PRIMARY KEY (elementid);

-- -----------------------------------------------------------------------------
-- dim.location
-- -----------------------------------------------------------------------------
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
  timezone text
);
ALTER TABLE dim.location OWNER TO citus;
ALTER TABLE ONLY dim.location ADD CONSTRAINT location_pk PRIMARY KEY (companyid, locationid);
CREATE INDEX IF NOT EXISTS dim_location_idx ON dim.location USING btree (locationid);
CREATE INDEX IF NOT EXISTS locationgroupid_idx ON dim.location USING btree (locationgroupid);

-- -----------------------------------------------------------------------------
-- dim.ordertype
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.ordertype (
  id bigint NOT NULL,
  locationid text NOT NULL,
  kioskid text NOT NULL,
  ordertypeid text NOT NULL,
  ordertypelabel text NOT NULL
);
ALTER TABLE dim.ordertype OWNER TO citus;
ALTER TABLE ONLY dim.ordertype ADD CONSTRAINT ordertype_pk PRIMARY KEY (id);
CREATE UNIQUE INDEX IF NOT EXISTS order_type_uidx ON dim.ordertype USING btree (locationid, kioskid, ordertypeid);

-- -----------------------------------------------------------------------------
-- dim.ordertype_bkp
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.ordertype_bkp (
  id bigint NOT NULL,
  locationid text NOT NULL,
  kioskid text NOT NULL,
  ordertypeid text NOT NULL,
  ordertypelabel text NOT NULL
);
ALTER TABLE dim.ordertype_bkp OWNER TO citus;
ALTER TABLE ONLY dim.ordertype_bkp ADD CONSTRAINT ordertype_bkp_pk PRIMARY KEY (id);

-- -----------------------------------------------------------------------------
-- dim.view
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.view (
  viewid integer,
  viewname text
);
ALTER TABLE dim.view OWNER TO citus;
CREATE INDEX IF NOT EXISTS idx_view_viewid ON dim.view USING btree (viewid);

-- -----------------------------------------------------------------------------
-- dim.itemcategory
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.itemcategory (
  id bigint NOT NULL,
  locationid text NOT NULL,
  categoryid text NOT NULL,
  categoryname text NOT NULL,
  isactive boolean DEFAULT true NOT NULL
);
ALTER TABLE dim.itemcategory OWNER TO citus;
ALTER TABLE ONLY dim.itemcategory ADD CONSTRAINT itemcategory_pk PRIMARY KEY (id);
CREATE UNIQUE INDEX IF NOT EXISTS itemcategory_idx ON dim.itemcategory USING btree (locationid, categoryid);
CREATE INDEX IF NOT EXISTS itemcategory_locationid_idx ON dim.itemcategory USING btree (locationid) INCLUDE (categoryid, isactive);

-- -----------------------------------------------------------------------------
-- dim.itemcategory_bkp
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.itemcategory_bkp (
  id bigint NOT NULL,
  locationid text NOT NULL,
  categoryid text NOT NULL,
  categoryname text NOT NULL,
  isactive boolean DEFAULT true NOT NULL
);
ALTER TABLE dim.itemcategory_bkp OWNER TO citus;
ALTER TABLE ONLY dim.itemcategory_bkp ADD CONSTRAINT itemcategory_bkp_pk PRIMARY KEY (id);
CREATE UNIQUE INDEX IF NOT EXISTS itemcategory_bkp_idx ON dim.itemcategory_bkp USING btree (locationid, categoryid);
CREATE INDEX IF NOT EXISTS itemcategory_bkp_locationid_idx ON dim.itemcategory_bkp USING btree (locationid) INCLUDE (categoryid, isactive);

-- -----------------------------------------------------------------------------
-- dim.itemcategorymapping
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.itemcategorymapping OWNER TO citus;

-- -----------------------------------------------------------------------------
-- dim.organization
-- -----------------------------------------------------------------------------
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
  cep_subscriptions text
);
ALTER TABLE dim.organization OWNER TO citus;
ALTER TABLE ONLY dim.organization ADD CONSTRAINT organization_pkey PRIMARY KEY (id);
ALTER TABLE dim.organization
  ADD COLUMN IF NOT EXISTS cep_subscriptions TEXT COLLATE pg_catalog."default";

-- -----------------------------------------------------------------------------
-- dim.organizationlocation
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.organizationlocation (
  organizationid character varying(40) NOT NULL,
  organizationname character varying(255),
  locationid character varying(40) NOT NULL,
  locationname character varying(255) NOT NULL,
  organizationtype smallint,
  roundupforcharity boolean
);
ALTER TABLE dim.organizationlocation OWNER TO citus;
ALTER TABLE ONLY dim.organizationlocation ADD CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid);
CREATE INDEX IF NOT EXISTS "IX_organizationid_locationid" ON dim.organizationlocation USING btree (organizationid, locationid) INCLUDE (organizationname, locationname);
CREATE INDEX IF NOT EXISTS idx_organizationlocation_locationid ON dim.organizationlocation USING btree (locationid);
CREATE INDEX IF NOT EXISTS idx_organizationlocation_organizationid ON dim.organizationlocation USING btree (organizationid);

-- -----------------------------------------------------------------------------
-- dim.userlocation
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.userlocation (
  userid character varying(40) NOT NULL,
  locationid character varying(40) NOT NULL
);
ALTER TABLE dim.userlocation OWNER TO citus;
ALTER TABLE ONLY dim.userlocation ADD CONSTRAINT userlocation_pkey PRIMARY KEY (userid, locationid);

-- -----------------------------------------------------------------------------
-- dim.feedbackrating
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.feedbackrating (
  rating text,
  ratingdesc text
);
ALTER TABLE dim.feedbackrating OWNER TO citus;
CREATE INDEX IF NOT EXISTS rating_idx ON dim.feedbackrating USING btree (rating) INCLUDE (ratingdesc);

-- -----------------------------------------------------------------------------
-- dim.feedbackstatus
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.feedbackstatus (
  surveytransstatus text,
  statusdesc text
);
ALTER TABLE dim.feedbackstatus OWNER TO citus;
CREATE INDEX IF NOT EXISTS surveytransstatus_idx ON dim.feedbackstatus USING btree (surveytransstatus) INCLUDE (statusdesc);

-- -----------------------------------------------------------------------------
-- dim.occasionsurvey
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.occasionsurvey (
  surveykey bigint NOT NULL,
  organizationid text NOT NULL,
  surveyid text NOT NULL,
  surveyname text,
  surveytype text
);
ALTER TABLE dim.occasionsurvey OWNER TO citus;
ALTER TABLE dim.occasionsurvey ALTER COLUMN surveykey ADD GENERATED BY DEFAULT AS IDENTITY (
  SEQUENCE NAME dim.occasionsurvey_surveykey_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1
);
ALTER TABLE ONLY dim.occasionsurvey ADD CONSTRAINT survey_pkey PRIMARY KEY (surveykey);
ALTER TABLE ONLY dim.occasionsurvey ADD CONSTRAINT orgid_surveyid_pk UNIQUE (organizationid, surveyid);
CREATE INDEX IF NOT EXISTS organizationid_idx ON dim.occasionsurvey USING btree (organizationid);
CREATE INDEX IF NOT EXISTS surveyid_idx ON dim.occasionsurvey USING btree (surveyid) INCLUDE (surveyname, surveytype);

-- -----------------------------------------------------------------------------
-- dim.frequentcustomer
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.frequentcustomer (
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
ALTER TABLE dim.frequentcustomer OWNER TO citus;
ALTER TABLE ONLY dim.frequentcustomer ADD CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid);

-- -----------------------------------------------------------------------------
-- dim.kiosk
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.kiosk (
  id bigint NOT NULL,
  locationid text NOT NULL,
  kioskid text NOT NULL,
  kioskname text,
  serialnumber text,
  appversion text,
  istestkiosk boolean,
  devicetype character varying(50) DEFAULT 'kiosk'::character varying NOT NULL,
  devicecreatedon timestamp without time zone,
  devicedeletedon timestamp without time zone
);
ALTER TABLE dim.kiosk OWNER TO citus;
ALTER TABLE ONLY dim.kiosk ADD CONSTRAINT kiosk_pk PRIMARY KEY (id);
ALTER TABLE ONLY dim.kiosk ADD CONSTRAINT kiosk_uidx UNIQUE (locationid, kioskid);

-- -----------------------------------------------------------------------------
-- dim.kioskdetails
-- -----------------------------------------------------------------------------
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
  perform_pos_status_check boolean
);
ALTER TABLE dim.kioskdetails OWNER TO citus;
ALTER TABLE ONLY dim.kioskdetails ADD CONSTRAINT locationid_pkey PRIMARY KEY (locationid);
ALTER TABLE dim.kioskdetails
  ADD COLUMN IF NOT EXISTS item_special_request text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS legal_copy_enabled BOOLEAN,
  ADD COLUMN IF NOT EXISTS ada_configuration text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS calculate_default_modifier_price BOOLEAN,
  ADD COLUMN IF NOT EXISTS track_kiosk_user_behavior BOOLEAN,
  ADD COLUMN IF NOT EXISTS loyalty_feature BOOLEAN,
  ADD COLUMN IF NOT EXISTS pickup_flow BOOLEAN,
  ADD COLUMN IF NOT EXISTS pos_auto_applied_discount BOOLEAN,
  ADD COLUMN IF NOT EXISTS search_functionality_enabled BOOLEAN,
  ADD COLUMN IF NOT EXISTS recent_orders_enabled BOOLEAN,
  ADD COLUMN IF NOT EXISTS play_card_config text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS round_up_for_charity BOOLEAN,
  ADD COLUMN IF NOT EXISTS calories_enabled BOOLEAN,
  ADD COLUMN IF NOT EXISTS scan_and_go_enabled BOOLEAN,
  ADD COLUMN IF NOT EXISTS age_verification text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS tips_settings text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS business_hours_config text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS order_types text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS localization text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS kiosk_receipt_settings text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS kiosk_fonts text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS kiosk_appearance_text_overrides text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS kiosk_appearance_style_options text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS loyalty_display_settings text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS preorder_popup_enabled BOOLEAN,
  ADD COLUMN IF NOT EXISTS preorder_popup_text text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS disclaimer_text text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS order_limit_config text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS menu_behavior_config text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS perform_pos_status_check BOOLEAN;

-- -----------------------------------------------------------------------------
-- dim.locationcatalog
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.locationcatalog (
  id bigint NOT NULL,
  organizationid text NOT NULL,
  locationid text NOT NULL,
  locationname text,
  catalogid text,
  timezone text,
  menuid text
);
ALTER TABLE dim.locationcatalog OWNER TO citus;
ALTER TABLE ONLY dim.locationcatalog ADD CONSTRAINT location_ctlg_pk PRIMARY KEY (organizationid, locationid);

-- -----------------------------------------------------------------------------
-- dim.menuitem
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.menuitem (
  id bigint NOT NULL,
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
  sysupdatetime timestamp without time zone
);
ALTER TABLE dim.menuitem OWNER TO citus;
ALTER TABLE ONLY dim.menuitem ADD CONSTRAINT menuitem_pk PRIMARY KEY (id);
ALTER TABLE ONLY dim.menuitem ADD CONSTRAINT menuitemid_unq UNIQUE (menuitemid);
ALTER TABLE dim.menuitem
  ADD COLUMN IF NOT EXISTS item_class_type integer,
  ADD COLUMN IF NOT EXISTS entitytype text COLLATE pg_catalog."default",
  ADD COLUMN IF NOT EXISTS calories text COLLATE pg_catalog."default",
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
  ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

-- -----------------------------------------------------------------------------
-- dim.menuentities
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.menuentities OWNER TO citus;
ALTER TABLE ONLY dim.menuentities ADD CONSTRAINT menuentities_pkey PRIMARY KEY (entityid);
CREATE INDEX IF NOT EXISTS idx_menuentities_catalog ON dim.menuentities USING btree (catalogid);
CREATE INDEX IF NOT EXISTS idx_menuentities_tags ON dim.menuentities USING gin (tags);
CREATE INDEX IF NOT EXISTS idx_menuentities_mealavail ON dim.menuentities USING gin (mealavailability);

-- -----------------------------------------------------------------------------
-- dim.device
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.device OWNER TO citus;
ALTER TABLE ONLY dim.device ADD CONSTRAINT device_pkey PRIMARY KEY (id);
ALTER TABLE ONLY dim.device ADD CONSTRAINT device_deviceid_locationid_companyid_key UNIQUE (deviceid, locationid, companyid);
CREATE INDEX IF NOT EXISTS deviceid_locationid_companyid_idx ON dim.device USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, state, testmode);
CREATE INDEX IF NOT EXISTS idx_device_id ON dim.device USING btree (deviceid);
CREATE INDEX IF NOT EXISTS idx_device_location_id ON dim.device USING btree (locationid);
CREATE INDEX IF NOT EXISTS idx_device_state ON dim.device USING btree (state);
CREATE INDEX IF NOT EXISTS idx_device_testmode ON dim.device USING btree (testmode);

-- -----------------------------------------------------------------------------
-- dim.peripheral
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.peripheral OWNER TO citus;
ALTER TABLE ONLY dim.peripheral ADD CONSTRAINT peripheral_pkey PRIMARY KEY (id);
ALTER TABLE ONLY dim.peripheral ADD CONSTRAINT peripheral_deviceid_peripheralid_key UNIQUE (deviceid, peripheralid);
ALTER TABLE ONLY dim.peripheral ADD CONSTRAINT peripheral_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES dim.device(id);
CREATE INDEX IF NOT EXISTS peripheral_idx ON dim.peripheral USING btree (deviceid, peripheralid) INCLUDE (peripheraltype, state, statechangedate);

-- -----------------------------------------------------------------------------
-- dim.experiment
-- -----------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS dim.experiment_dimkey_seq AS integer START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1;
ALTER SEQUENCE dim.experiment_dimkey_seq OWNER TO citus;

CREATE TABLE IF NOT EXISTS dim.experiment (
  dimkey integer NOT NULL DEFAULT nextval('dim.experiment_dimkey_seq'::regclass),
  data jsonb
);
ALTER TABLE dim.experiment OWNER TO citus;
ALTER SEQUENCE dim.experiment_dimkey_seq OWNED BY dim.experiment.dimkey;
ALTER TABLE ONLY dim.experiment ADD CONSTRAINT experiment_pkey PRIMARY KEY (dimkey);

-- -----------------------------------------------------------------------------
-- dim.abtests
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.abtests OWNER TO citus;

-- -----------------------------------------------------------------------------
-- dim.upsellgrouplookup
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.upsellgrouplookup (
  upsellgroupid character varying(50) NOT NULL,
  upsellgroupname text,
  isactive boolean,
  createdon timestamp without time zone,
  modifiedon timestamp without time zone
);
ALTER TABLE dim.upsellgrouplookup OWNER TO citus;
ALTER TABLE ONLY dim.upsellgrouplookup ADD CONSTRAINT upsellgroupid_pkey PRIMARY KEY (upsellgroupid);

-- -----------------------------------------------------------------------------
-- dim.grubbrr_source_lookup
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.grubbrr_source_lookup (
  id integer NOT NULL,
  source character varying(10),
  description character varying(50)
);
ALTER TABLE dim.grubbrr_source_lookup OWNER TO citus;
ALTER TABLE ONLY dim.grubbrr_source_lookup ADD CONSTRAINT grubbrr_source_lookup_pkey PRIMARY KEY (id);

-- -----------------------------------------------------------------------------
-- dim.holidays
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.holidays OWNER TO citus;

-- -----------------------------------------------------------------------------
-- dim.weather_bkp
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.weather_bkp OWNER TO citus;
ALTER TABLE ONLY dim.weather_bkp ADD CONSTRAINT location_date_bkp_pk PRIMARY KEY (locationid, businessdate);

-- -----------------------------------------------------------------------------
-- dim.weather
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.weather OWNER TO citus;
ALTER TABLE ONLY dim.weather ADD CONSTRAINT location_date_pk PRIMARY KEY (locationid, apicalldate);

-- -----------------------------------------------------------------------------
-- dim.category_hierarchy
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.category_hierarchy (
  id BIGINT,
  organizationid TEXT COLLATE pg_catalog."default",
  locationid text COLLATE pg_catalog."default" NOT NULL,
  mapping_created_on TIMESTAMP,
  mapping_modified_on TIMESTAMP,
  is_mapping_active BOOLEAN,
  is_mapping_deleted BOOLEAN,
  catalogid TEXT COLLATE pg_catalog."default",
  catalogname TEXT COLLATE pg_catalog."default",
  catalog_created_on TIMESTAMP,
  catalog_modified_on TIMESTAMP,
  is_catalog_active BOOLEAN,
  is_catalog_deleted BOOLEAN,
  categoryid text COLLATE pg_catalog."default" NOT NULL,
  categoryname text COLLATE pg_catalog."default",
  category_created_on TIMESTAMP,
  category_modified_on TIMESTAMP,
  is_category_active BOOLEAN,
  is_category_deleted BOOLEAN,
  menuitemid TEXT COLLATE pg_catalog."default",
  entitytype TEXT COLLATE pg_catalog."default",
  item_class_type INTEGER,
  menuitemname TEXT COLLATE pg_catalog."default",
  item_created_on TIMESTAMP,
  item_modified_on TIMESTAMP,
  is_item_active BOOLEAN,
  is_item_deleted BOOLEAN,
  syscosmosts BIGINT,
  sysinserttime TIMESTAMP,
  sysupdatetime TIMESTAMP,
  CONSTRAINT category_hierarchy_pkey PRIMARY KEY (id),
  CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid)
) TABLESPACE pg_default;
ALTER TABLE dim.category_hierarchy OWNER TO citus;

-- -----------------------------------------------------------------------------
-- dim.duplicate_items_master
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.duplicate_items_master (
  organizationid TEXT COLLATE pg_catalog."default",
  locationid text COLLATE pg_catalog."default" NOT NULL,
  categoryid text COLLATE pg_catalog."default" NOT NULL,
  categoryname text COLLATE pg_catalog."default",
  menuitemid TEXT COLLATE pg_catalog."default",
  entitytype TEXT COLLATE pg_catalog."default",
  item_class_type INTEGER,
  menuitemname TEXT COLLATE pg_catalog."default",
  instance_count INTEGER,
  masteritemid TEXT COLLATE pg_catalog."default",
  sysinserttime TIMESTAMP,
  sysupdatetime TIMESTAMP,
  CONSTRAINT locationid_categoryid_menuitemid_unq UNIQUE (locationid, categoryid, menuitemid)
) TABLESPACE pg_default;
ALTER TABLE dim.duplicate_items_master OWNER TO citus;

-- -----------------------------------------------------------------------------
-- dim.catalog
-- -----------------------------------------------------------------------------
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
  CONSTRAINT catalog_pkey PRIMARY KEY (catalogid)
) TABLESPACE pg_default;
ALTER TABLE dim.catalog OWNER TO citus;

-- -----------------------------------------------------------------------------
-- dim.modifier
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim.modifier (
  modifierkey BIGINT,
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
  price NUMERIC(12,3),
  sysinserttime timestamp without time zone,
  sysupdatetime timestamp without time zone,
  CONSTRAINT modifier_master_pkey PRIMARY KEY (modifierid)
) TABLESPACE pg_default;
ALTER TABLE dim.modifier OWNER TO citus;

-- -----------------------------------------------------------------------------
-- dim.modifier_group_mapping
-- -----------------------------------------------------------------------------
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
  sysupdatetime timestamp without time zone,
  CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id)
) TABLESPACE pg_default;
ALTER TABLE dim.modifier_group_mapping OWNER TO citus;

-- -----------------------------------------------------------------------------
-- dim.item_modifier_group_modifier_mapping
-- -----------------------------------------------------------------------------
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
  is_default BOOLEAN,
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
  sysinserttime TIMESTAMP WITHOUT TIME ZONE
);
ALTER TABLE dim.item_modifier_group_modifier_mapping OWNER TO citus;

-- -----------------------------------------------------------------------------
-- dim.vw_grubbrrinstallbase
-- -----------------------------------------------------------------------------
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
ALTER TABLE dim.vw_grubbrrinstallbase OWNER TO citus;
ALTER TABLE ONLY dim.vw_grubbrrinstallbase ADD CONSTRAINT locationid_deviceid_pk PRIMARY KEY (location_id, kiosk_id);
ALTER TABLE dim.vw_grubbrrinstallbase
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

-- =============================================================================
-- fact SCHEMA TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- fact.watermarktable
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.watermarktable (
  watermarktablename text NOT NULL,
  watermarkcolumn text,
  watermarkvalue timestamp without time zone,
  ticks bigint,
  ts bigint,
  source character varying(10) NOT NULL
);
ALTER TABLE fact.watermarktable OWNER TO citus;
ALTER TABLE ONLY fact.watermarktable ADD CONSTRAINT watermarktablename_pk PRIMARY KEY (watermarktablename, source);

-- -----------------------------------------------------------------------------
-- fact.pipelinerunstatus
-- -----------------------------------------------------------------------------
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
ALTER TABLE fact.pipelinerunstatus OWNER TO citus;
CREATE INDEX IF NOT EXISTS idx_fact_pipelinerunstatus_correlationid ON fact.pipelinerunstatus USING btree (correlationid) INCLUDE (pipelinestatus);

-- -----------------------------------------------------------------------------
-- fact.timingsdatalake
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.timingsdatalake (
  containername text NOT NULL,
  timing_value timestamp without time zone
);
ALTER TABLE fact.timingsdatalake OWNER TO citus;
ALTER TABLE ONLY fact.timingsdatalake ADD CONSTRAINT timingsdatalake_pkey PRIMARY KEY (containername);

-- -----------------------------------------------------------------------------
-- fact.deviceevent
-- -----------------------------------------------------------------------------
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
ALTER TABLE fact.deviceevent OWNER TO citus;
ALTER TABLE ONLY fact.deviceevent ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (companyid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);
CREATE INDEX IF NOT EXISTS deviceeventidx ON fact.deviceevent USING btree (companyid, locationid);
CREATE INDEX IF NOT EXISTS deviceeventuidx ON fact.deviceevent USING btree (application, companyid, locationid, moduleid, eventtoken, datacategory, actiontype, eventinstant);
CREATE INDEX IF NOT EXISTS ix_deviceevent_journey_lookup ON fact.deviceevent USING btree (locationid, dateid, datacategory, eventtoken)
  WHERE (datacategory = 'insight'::text AND actiontype = ANY (ARRAY[
    'CategorySelected'::text, 'SubCategorySelected'::text, 'RegularItemSelected'::text,
    'ItemRemoved'::text, 'ModifierGroupSelected'::text, 'ModifierSelected'::text, 'ModifierUnselected'::text
  ]));

-- -----------------------------------------------------------------------------
-- fact.devicestate
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.devicestate (
  id bigint NOT NULL,
  companyid text,
  locationid text,
  deviceid text,
  dateid integer,
  state text,
  lasteventtime timestamp without time zone,
  statuschangetime timestamp without time zone,
  duration numeric(10,3),
  sysinserttime timestamp without time zone
);
ALTER TABLE fact.devicestate OWNER TO citus;
CREATE INDEX IF NOT EXISTS idx_devicestate ON fact.devicestate USING btree (locationid, companyid, deviceid) WITH (deduplicate_items='true');
CREATE INDEX IF NOT EXISTS idx_devicestate_dateid ON fact.devicestate USING btree (dateid);
CREATE INDEX IF NOT EXISTS idx_devicestate_locationid ON fact.devicestate USING btree (locationid);
ALTER TABLE fact.devicestate
  ALTER COLUMN duration TYPE NUMERIC(10,3),
  ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;

-- -----------------------------------------------------------------------------
-- fact.devicetelemetry
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.devicetelemetry (
  deviceid text,
  locationid text,
  dateid integer,
  cpuvalue numeric(10,5),
  memoryvalue numeric(10,5),
  cputimestamp timestamp without time zone,
  memorytimestamp timestamp without time zone,
  sysinserttime timestamp without time zone,
  sysupdatetime timestamp without time zone
);
ALTER TABLE fact.devicetelemetry OWNER TO citus;
ALTER TABLE ONLY fact.devicetelemetry ADD CONSTRAINT location_deviceid_fk FOREIGN KEY (locationid, deviceid) REFERENCES dim.kiosk(locationid, kioskid);
ALTER TABLE ONLY fact.devicetelemetry ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);
CREATE INDEX IF NOT EXISTS idx_devicetelemetry ON fact.devicetelemetry USING btree (locationid, deviceid);
CREATE INDEX IF NOT EXISTS idx_devicetelemetry_dateid ON fact.devicetelemetry USING btree (dateid);
CREATE INDEX IF NOT EXISTS idx_devicetelemetry_locationid ON fact.devicetelemetry USING btree (locationid);
ALTER TABLE fact.devicetelemetry
  ALTER COLUMN cpuvalue TYPE NUMERIC(10,5),
  ALTER COLUMN memoryvalue TYPE NUMERIC(10,5),
  ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
  ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;

-- -----------------------------------------------------------------------------
-- fact.devicehealth
-- -----------------------------------------------------------------------------
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
ALTER TABLE fact.devicehealth OWNER TO citus;
ALTER TABLE ONLY fact.devicehealth ADD CONSTRAINT devicehealth_pkey PRIMARY KEY (id);
CREATE INDEX IF NOT EXISTS devicehealth_idx ON fact.devicehealth USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, status, healthdatatype, healthdatatime, statuschangetime);
CREATE INDEX IF NOT EXISTS deviceid_idx ON fact.devicehealth USING btree (deviceid);
CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid ON fact.devicehealth USING btree (deviceid);
CREATE INDEX IF NOT EXISTS idx_devicehealth_deviceid_status_time ON fact.devicehealth USING btree (deviceid, status, healthdatatime DESC);
CREATE INDEX IF NOT EXISTS idx_devicehealth_locationid ON fact.devicehealth USING btree (locationid);

-- -----------------------------------------------------------------------------
-- fact.peripheralhealth
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.peripheralhealth (
  healthdataid bigint,
  peripheralid character varying(50) NOT NULL,
  peripheraltype character varying(50) NOT NULL,
  status character varying(50) NOT NULL,
  statusmessage text
);
ALTER TABLE fact.peripheralhealth OWNER TO citus;
ALTER TABLE ONLY fact.peripheralhealth ADD CONSTRAINT peripheralhealth_healthdataid_peripheralid_key UNIQUE (healthdataid, peripheralid);
ALTER TABLE ONLY fact.peripheralhealth ADD CONSTRAINT peripheralhealth_healthdataid_fkey FOREIGN KEY (healthdataid) REFERENCES fact.devicehealth(id);
CREATE INDEX IF NOT EXISTS peripheralhealth_idx ON fact.peripheralhealth USING btree (healthdataid, peripheralid) INCLUDE (peripheraltype, status);

-- -----------------------------------------------------------------------------
-- fact.peripheralstate
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.peripheralstate (
  deviceid text,
  peripheralid text,
  peripheraltype text,
  state text,
  statestart timestamp with time zone,
  stateend timestamp with time zone,
  duration interval
);
ALTER TABLE fact.peripheralstate OWNER TO citus;
CREATE UNIQUE INDEX IF NOT EXISTS peripheralstate_uidx ON fact.peripheralstate USING btree (deviceid, peripheralid, state, statestart);

-- -----------------------------------------------------------------------------
-- fact.ordertiming
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.ordertiming (
  id bigint NOT NULL,
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
  syscosmosts bigint
);
ALTER TABLE fact.ordertiming OWNER TO citus;
ALTER TABLE ONLY fact.ordertiming ADD CONSTRAINT ordertiming_pkey PRIMARY KEY (id);
ALTER TABLE fact.ordertiming
  ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
  ADD COLUMN IF NOT EXISTS syscosmosts BIGINT;

-- -----------------------------------------------------------------------------
-- fact.transactionheader
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.transactionheader (
  id bigint NOT NULL,
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
  updateddate timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
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
ALTER TABLE fact.transactionheader OWNER TO citus;
ALTER TABLE ONLY fact.transactionheader ADD CONSTRAINT transactionheader_pkey PRIMARY KEY (locationid, transactionheaderid);
ALTER TABLE ONLY fact.transactionheader ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);
ALTER TABLE ONLY fact.transactionheader ADD CONSTRAINT ordertype_fk FOREIGN KEY (ordertype) REFERENCES dim.ordertype(id);
ALTER TABLE ONLY fact.transactionheader ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);
CREATE INDEX IF NOT EXISTS transactionheader_locationid_dateid_idx ON fact.transactionheader USING btree (locationid, dateid) INCLUDE (orderstatus, ordertype, businessdate);
ALTER TABLE fact.transactionheader
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
  ADD COLUMN IF NOT EXISTS customername CHARACTER VARYING(100) COLLATE pg_catalog."default";

-- -----------------------------------------------------------------------------
-- fact.transactionitem
-- -----------------------------------------------------------------------------
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
  businessdate date
);
ALTER TABLE fact.transactionitem OWNER TO citus;
ALTER TABLE ONLY fact.transactionitem ADD CONSTRAINT transactionitem_pkey PRIMARY KEY (transactionheaderid, itemid, itemname);
ALTER TABLE ONLY fact.transactionitem ADD CONSTRAINT categoryid_fk FOREIGN KEY (categoryid) REFERENCES dim.itemcategory(id);
ALTER TABLE ONLY fact.transactionitem ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);
ALTER TABLE ONLY fact.transactionitem ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);
ALTER TABLE ONLY fact.transactionitem ADD CONSTRAINT menuitemid_fk FOREIGN KEY (menuitemid) REFERENCES dim.menuitem(id);
CREATE INDEX IF NOT EXISTS idx_transactionitem_headerid ON fact.transactionitem USING btree (transactionheaderid);
CREATE INDEX IF NOT EXISTS idx_transactionitemtest_headerid ON fact.transactionitem USING btree (transactionheaderid);
ALTER TABLE fact.transactionitem
  ALTER COLUMN itemunitprice TYPE NUMERIC(12,3),
  ADD COLUMN IF NOT EXISTS orderdatelocal TIMESTAMP,
  ADD COLUMN IF NOT EXISTS businessdate DATE;

-- -----------------------------------------------------------------------------
-- fact.transactionitemtest
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.transactionitemtest (
  transactionheaderid text NOT NULL,
  categoryid bigint,
  menuitemid bigint,
  itemid text NOT NULL,
  comboid text,
  ordersessionid text NOT NULL,
  itemsessionid text,
  itemname text NOT NULL,
  itemquantity smallint DEFAULT 1,
  itemunitprice numeric(7,3),
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
  dateid integer,
  orderdateutc text,
  sysinserttime timestamp without time zone,
  sysupdatetime timestamp without time zone
);
ALTER TABLE fact.transactionitemtest OWNER TO citus;
ALTER TABLE ONLY fact.transactionitemtest ADD CONSTRAINT transactionitemtest_pkey PRIMARY KEY (transactionheaderid, itemid, itemname);

-- -----------------------------------------------------------------------------
-- fact.itemmodifier
-- -----------------------------------------------------------------------------
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
  sysupdatetime timestamp without time zone
);
ALTER TABLE fact.itemmodifier OWNER TO citus;
ALTER TABLE ONLY fact.itemmodifier ADD CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY KEY (transactionheaderid, itemid, modifiergroupid, modifierid);
CREATE INDEX IF NOT EXISTS itemmodifieridx ON fact.itemmodifier USING btree (itemid);
CREATE INDEX IF NOT EXISTS transactionheaderid_idx ON fact.itemmodifier USING btree (transactionheaderid);
ALTER TABLE fact.itemmodifier
  ALTER COLUMN modifierprice TYPE NUMERIC(12,3);

-- -----------------------------------------------------------------------------
-- fact.transactionpayment
-- -----------------------------------------------------------------------------
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
  sysupdatetime timestamp without time zone
);
ALTER TABLE fact.transactionpayment OWNER TO citus;
ALTER TABLE ONLY fact.transactionpayment ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);
CREATE INDEX IF NOT EXISTS transactionpayment_orderid_idx ON fact.transactionpayment USING btree (orderid);
CREATE INDEX IF NOT EXISTS transactionpaymentuidx ON fact.transactionpayment USING btree (transactionheaderid, paymentintegrationid, paymentid);
ALTER TABLE fact.transactionpayment
  ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP,
  ALTER COLUMN paymentamt TYPE NUMERIC(12,3);

-- -----------------------------------------------------------------------------
-- fact.transactionrefunds
-- -----------------------------------------------------------------------------
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
ALTER TABLE fact.transactionrefunds OWNER TO citus;
CREATE INDEX IF NOT EXISTS idx_transactionrefunds_headerid ON fact.transactionrefunds USING btree (transactionheaderid);

-- -----------------------------------------------------------------------------
-- fact.userbehaviour
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.userbehaviour (
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
  createddate timestamp without time zone,
  syscosmosts bigint,
  eventinstant text,
  eventcategory text
);
ALTER TABLE fact.userbehaviour OWNER TO citus;
ALTER TABLE ONLY fact.userbehaviour ADD CONSTRAINT userbehaviour_pkey PRIMARY KEY (id);
CREATE INDEX IF NOT EXISTS userbehaviour_locationid_dateid_idx ON fact.userbehaviour USING btree (locationid, dateid) INCLUDE (ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier);
ALTER TABLE fact.userbehaviour
  ADD COLUMN IF NOT EXISTS eventcategory text COLLATE pg_catalog."default";

-- -----------------------------------------------------------------------------
-- fact.userbehaviour_exceptions
-- -----------------------------------------------------------------------------
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
ALTER TABLE fact.userbehaviour_exceptions OWNER TO citus;
ALTER TABLE ONLY fact.userbehaviour_exceptions ADD CONSTRAINT userbehaviour_exceptions_pkey PRIMARY KEY (id);

-- -----------------------------------------------------------------------------
-- fact.usercheckedin
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.usercheckedin (
  organizationid text NOT NULL,
  locationid text NOT NULL,
  kioskid text,
  ordersessionid text,
  dateid integer,
  ordertimestamp text,
  orderid text,
  customername text,
  customerphone text,
  orderstatus text,
  ordertotal numeric(7,3),
  paymentstatus text,
  amountpaid numeric(7,3),
  paymentmethod text,
  paymentcardtype text,
  sysinserttime timestamp without time zone,
  orderdatelocal timestamp without time zone
);
ALTER TABLE fact.usercheckedin OWNER TO citus;

-- -----------------------------------------------------------------------------
-- fact.recommendations_bkp
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.recommendations_bkp (
  transactionheaderid character varying(50) NOT NULL,
  recommendationid character varying(50) NOT NULL,
  offereditems jsonb,
  selecteditems jsonb,
  isconverted boolean,
  prompttimestamp text,
  sysinserttime timestamp without time zone
);
ALTER TABLE fact.recommendations_bkp OWNER TO citus;

-- -----------------------------------------------------------------------------
-- fact.recommendations
-- -----------------------------------------------------------------------------
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
ALTER TABLE fact.recommendations OWNER TO citus;
ALTER TABLE ONLY fact.recommendations ADD CONSTRAINT locationid_trxnid_recommendationid_pk PRIMARY KEY (locationid, transactionheaderid, recommendationid);
ALTER TABLE ONLY fact.recommendations ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);
ALTER TABLE ONLY fact.recommendations ADD CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);

-- -----------------------------------------------------------------------------
-- fact.vw_offer_analysis
-- -----------------------------------------------------------------------------
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
  sysinserttime timestamp without time zone
);
ALTER TABLE fact.vw_offer_analysis OWNER TO citus;
ALTER TABLE ONLY fact.vw_offer_analysis ADD CONSTRAINT trxnid_recommendationid_itemid_uidx UNIQUE (transactionheaderid, recommendationid, offereditem);
ALTER TABLE ONLY fact.vw_offer_analysis ADD CONSTRAINT locationid_trxnid_recommendationid_fk FOREIGN KEY (locationid, transactionheaderid, recommendationid) REFERENCES fact.recommendations(locationid, transactionheaderid, recommendationid);
ALTER TABLE ONLY fact.vw_offer_analysis ADD CONSTRAINT selecteditem_fk FOREIGN KEY (selecteditem) REFERENCES dim.menuitem(menuitemid);
CREATE INDEX IF NOT EXISTS locationid_idx ON fact.vw_offer_analysis USING btree (locationid);

-- -----------------------------------------------------------------------------
-- fact.itemssurvey
-- -----------------------------------------------------------------------------
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
  sysinserttime timestamp without time zone
);
ALTER TABLE fact.itemssurvey OWNER TO citus;
ALTER TABLE ONLY fact.itemssurvey ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);
ALTER TABLE ONLY fact.itemssurvey ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);
ALTER TABLE ONLY fact.itemssurvey ADD CONSTRAINT orgid_surveyid_fk FOREIGN KEY (organizationid, surveyid) REFERENCES dim.occasionsurvey(organizationid, surveyid);

-- -----------------------------------------------------------------------------
-- fact.occasionsurveydetail
-- -----------------------------------------------------------------------------
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
ALTER TABLE fact.occasionsurveydetail OWNER TO citus;
ALTER TABLE ONLY fact.occasionsurveydetail ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);
ALTER TABLE ONLY fact.occasionsurveydetail ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);
ALTER TABLE ONLY fact.occasionsurveydetail ADD CONSTRAINT orgid_surveyid_fk FOREIGN KEY (organizationid, surveyid) REFERENCES dim.occasionsurvey(organizationid, surveyid);
ALTER TABLE ONLY fact.occasionsurveydetail ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);
ALTER TABLE fact.occasionsurveydetail
  ALTER COLUMN surveytransid DROP NOT NULL,
  ADD COLUMN IF NOT EXISTS surveytype INTEGER;

-- -----------------------------------------------------------------------------
-- fact.customer_menu_preferences
-- -----------------------------------------------------------------------------
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
ALTER TABLE fact.customer_menu_preferences OWNER TO citus;

-- -----------------------------------------------------------------------------
-- fact.location_menu_preferences
-- -----------------------------------------------------------------------------
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
ALTER TABLE fact.location_menu_preferences OWNER TO citus;
ALTER TABLE ONLY fact.location_menu_preferences ADD CONSTRAINT location_dayparts_itemid_itemtype_unq UNIQUE (locationid, day_parts, itemid, itemtype);

-- -----------------------------------------------------------------------------
-- fact.location_statistics
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.location_statistics (
  organizationid character varying(50),
  organizationname character varying(255),
  locationid character varying(50),
  locationname character varying(255),
  city character varying(255),
  state character varying(255),
  country character varying(255),
  isactive BOOLEAN,
  timezone character varying(255),
  order_type_labels jsonb,
  loc_item_popularity jsonb,
  loc_total_order_count INTEGER,
  loc_total_sales_amount NUMERIC(12,3),
  loc_avg_order_amount NUMERIC(12,3),
  org_total_order_count INTEGER,
  org_total_sales_amount NUMERIC(12,3),
  org_avg_order_amount NUMERIC(12,3),
  number_of_frequent_customers INTEGER,
  orders_placed_by_freq_customers INTEGER,
  amount_spent_by_freq_customers NUMERIC(12,3),
  avg_amount_spent_by_freq_customers NUMERIC(12,3),
  sysupdatetime TIMESTAMP
);
ALTER TABLE fact.location_statistics OWNER TO citus;

-- -----------------------------------------------------------------------------
-- fact.modifier_interactions
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.modifier_interactions (
  locationid text NOT NULL,
  transactionheaderid text NOT NULL,
  ordersessionid text,
  orderid text,
  orderitemid text NOT NULL,
  menuitemid text,
  modifiergroupid text NOT NULL,
  modifierid text NOT NULL,
  modifiername text,
  modifierquantity smallint,
  modifierprice numeric(12,3),
  freequantity integer,
  selectiontype text,
  action text,
  businessdate date,
  orderdatelocal timestamp without time zone,
  frequentcustomerid text,
  sysinserttime timestamp without time zone,
  sysupdatetime timestamp without time zone,
  CONSTRAINT trxnid_itemid_modfrgrpid_modfrid_pk PRIMARY KEY (transactionheaderid, orderitemid, modifiergroupid, modifierid)
);
ALTER TABLE fact.modifier_interactions OWNER TO citus;

-- -----------------------------------------------------------------------------
-- fact.cep_incidents
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.cep_incidents (
  incidentkey BIGINT,
  application TEXT,
  organizationid TEXT,
  locationid TEXT,
  deviceid TEXT,
  eventmodule TEXT,
  eventcategory TEXT,
  eventtype TEXT,
  eventtoken TEXT,
  incidenttype TEXT,
  incidentcount INTEGER,
  eventinstant TEXT,
  firstoccurred TIMESTAMP,
  lastoccurred TIMESTAMP,
  notificationtypeid TEXT,
  incidentdata TEXT,
  syscosmosts BIGINT,
  sysinserttime TIMESTAMP,
  severity TEXT
);
ALTER TABLE fact.cep_incidents OWNER TO citus;
ALTER TABLE fact.cep_incidents
  ADD COLUMN IF NOT EXISTS severity TEXT COLLATE pg_catalog."default";

-- -----------------------------------------------------------------------------
-- fact.pos_sales_details
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fact.pos_sales_details (
  id bigint NOT NULL GENERATED ALWAYS AS IDENTITY (SEQUENCE NAME fact.pos_sales_details_id_seq START WITH 1 INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1),
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
ALTER TABLE fact.pos_sales_details OWNER TO citus;
ALTER TABLE ONLY fact.pos_sales_details ADD CONSTRAINT pos_sales_details_pkey PRIMARY KEY (id);

-- =============================================================================
-- stg SCHEMA TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- stg.kioskdetails
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- stg.recommendations
-- -----------------------------------------------------------------------------
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
ALTER TABLE ONLY stg.recommendations ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);

-- =============================================================================
-- VIEWS
-- =============================================================================

DROP VIEW IF EXISTS public.vw_transactiondetails;

CREATE OR REPLACE VIEW dim.businessdate AS
WITH base AS (
  WITH cur AS (
    SELECT d.dateid, d.datets, d.hourofday, d.dayval, d.daynum, d.dayname,
           d.weekval, d.monthval, d.monthname, d.quarterval, d.yearval, d.daypart, d.dayofyear
    FROM dim.datedim d WHERE (d.yearval)::numeric = EXTRACT(year FROM now())
  ), pre AS (
    SELECT d.dateid, d.datets, d.hourofday, d.dayval, d.daynum, d.dayname,
           d.weekval, d.monthval, d.monthname, d.quarterval, d.yearval, d.daypart, d.dayofyear
    FROM dim.datedim d WHERE (d.yearval)::numeric = EXTRACT(year FROM (now() - '1 year'::interval))
  )
  SELECT DISTINCT
    (((p.yearval || to_char((c.dayval)::timestamp with time zone, 'MMDD'::text)) || substring(c.hourofday, 1, 2)))::integer AS dateid,
    p.hourofday, p.daynum, p.dayname, p.weekval, c.monthval, c.monthname, c.quarterval, p.yearval, p.daypart
  FROM cur c LEFT JOIN pre p ON (p.weekval = c.weekval AND p.dayname = c.dayname AND p.hourofday = c.hourofday)
  ORDER BY p.daypart, c.quarterval, p.dayname
)
SELECT base.dateid, base.hourofday, base.daynum, base.dayname, base.weekval,
       base.monthval, base.monthname, base.quarterval, base.yearval, base.daypart
FROM base
UNION
SELECT d.dateid, d.hourofday, d.daynum, d.dayname, d.weekval,
       d.monthval, d.monthname, d.quarterval, d.yearval, d.daypart
FROM dim.datedim d WHERE (d.yearval)::numeric = EXTRACT(year FROM now())
ORDER BY 1, 2, 4;
ALTER VIEW dim.businessdate OWNER TO citus;

CREATE OR REPLACE VIEW dim.vworganizationlocation AS
WITH base AS (
  WITH cur AS (
    SELECT d.dateid, d.datets, d.hourofday, d.dayval, d.daynum, d.dayname,
           d.weekval, d.monthval, d.monthname, d.quarterval, d.yearval, d.daypart, d.dayofyear
    FROM dim.datedim d WHERE (d.yearval)::numeric = EXTRACT(year FROM now())
  ), pre AS (
    SELECT d.dateid, d.datets, d.hourofday, d.dayval, d.daynum, d.dayname,
           d.weekval, d.monthval, d.monthname, d.quarterval, d.yearval, d.daypart, d.dayofyear
    FROM dim.datedim d WHERE (d.yearval)::numeric = EXTRACT(year FROM (now() - '1 year'::interval))
  )
  SELECT DISTINCT
    (((p.yearval || to_char((c.dayval)::timestamp with time zone, 'MMDD'::text)) || substring(c.hourofday, 1, 2)))::integer AS dateid,
    p.hourofday, p.daynum, p.dayname, p.weekval, c.monthval, c.monthname, c.quarterval, p.yearval, p.daypart
  FROM cur c LEFT JOIN pre p ON (p.weekval = c.weekval AND p.dayname = c.dayname AND p.hourofday = c.hourofday)
  ORDER BY p.daypart, c.quarterval, p.dayname
)
SELECT base.dateid, base.hourofday, base.daynum, base.dayname, base.weekval,
       base.monthval, base.monthname, base.quarterval, base.yearval, base.daypart
FROM base
UNION
SELECT d.dateid, d.hourofday, d.daynum, d.dayname, d.weekval,
       d.monthval, d.monthname, d.quarterval, d.yearval, d.daypart
FROM dim.datedim d WHERE (d.yearval)::numeric = EXTRACT(year FROM now())
ORDER BY 1, 2, 4;
ALTER VIEW dim.vworganizationlocation OWNER TO citus;

CREATE OR REPLACE VIEW dim.vw_weatherhourlydata AS
SELECT w.locationid,
  (w.weatherinfo ->> 'Date'::text)::date AS weatherdate,
  (hour_entry.hour_data ->> 'Hour'::text)::integer AS hh,
  (hour_entry.hour_data ->> 'Humidity'::text)::INTEGER AS humidity,
  hour_entry.hour_data ->> 'Condition'::text AS condition,
  (hour_entry.hour_data ->> 'TemperatureInCelcius'::text)::numeric(8,2) AS temperature_c,
  (hour_entry.hour_data ->> 'IsHot'::text)::BOOLEAN AS is_hot,
  (hour_entry.hour_data ->> 'IsCalm'::text)::BOOLEAN AS is_calm,
  (hour_entry.hour_data ->> 'IsCold'::text)::BOOLEAN AS is_cold,
  (hour_entry.hour_data ->> 'IsCool'::text)::BOOLEAN AS is_cool,
  (hour_entry.hour_data ->> 'IsMild'::text)::BOOLEAN AS is_mild,
  (hour_entry.hour_data ->> 'IsWarm'::text)::BOOLEAN AS is_warm,
  (hour_entry.hour_data ->> 'RainMm'::text)::numeric(8,2) AS rain_mm,
  (hour_entry.hour_data ->> 'IsSunny'::text)::BOOLEAN AS is_sunny,
  (hour_entry.hour_data ->> 'IsWindy'::text)::BOOLEAN AS is_windy,
  (hour_entry.hour_data ->> 'IsCloudy'::text)::BOOLEAN AS is_cloudy,
  (hour_entry.hour_data ->> 'IsDaytime'::text)::BOOLEAN AS is_daytime,
  (hour_entry.hour_data ->> 'IsRaining'::text)::BOOLEAN AS is_raining,
  (hour_entry.hour_data ->> 'IsSnowing'::text)::BOOLEAN AS is_snowing,
  (hour_entry.hour_data ->> 'IsVeryHot'::text)::BOOLEAN AS is_very_hot,
  (hour_entry.hour_data ->> 'IsFreezing'::text)::BOOLEAN AS is_freezing,
  (hour_entry.hour_data ->> 'IsOvercast'::text)::BOOLEAN AS is_overcast,
  (hour_entry.hour_data ->> 'SnowfallMm'::text)::numeric(8,2) AS snowfall_mm,
  hour_entry.hour_data ->> 'TempBucket'::text AS temp_bucket,
  hour_entry.hour_data ->> 'WindBucket'::text AS wind_bucket,
  (hour_entry.hour_data ->> 'FeelsColder'::text)::BOOLEAN AS feels_colder,
  (hour_entry.hour_data ->> 'FeelsHotter'::text)::BOOLEAN AS feels_hotter,
  hour_entry.hour_data ->> 'FoodWeather'::text AS food_weather,
  (hour_entry.hour_data ->> 'IsHeavyRain'::text)::BOOLEAN AS is_heavy_rain,
  (hour_entry.hour_data ->> 'IsLightRain'::text)::BOOLEAN AS is_light_rain,
  (hour_entry.hour_data ->> 'IsNighttime'::text)::BOOLEAN AS is_nighttime,
  (hour_entry.hour_data ->> 'IsVeryWindy'::text)::BOOLEAN AS is_very_windy,
  (hour_entry.hour_data ->> 'PressureHpa'::text)::numeric(8,2) AS pressure_hpa,
  (hour_entry.hour_data ->> 'WeatherCode'::text)::INTEGER AS weather_code,
  (hour_entry.hour_data ->> 'WindGustKmh'::text)::numeric(8,2) AS wind_gust_kmh,
  (hour_entry.hour_data ->> 'ComfortScore'::text)::INTEGER AS comfort_score,
  hour_entry.hour_data ->> 'DrinkWeather'::text AS drink_weather,
  (hour_entry.hour_data ->> 'WindSpeedKmh'::text)::numeric(8,2) AS wind_speed_kmh,
  hour_entry.hour_data ->> 'ComfortBucket'::text AS comfort_bucket,
  hour_entry.hour_data ->> 'HumidityBucket'::text AS humidity_bucket,
  hour_entry.hour_data ->> 'ConditionBucket'::text AS condition_bucket,
  (hour_entry.hour_data ->> 'IsPrecipitating'::text)::BOOLEAN AS is_precipitating,
  (hour_entry.hour_data ->> 'PrecipitationMm'::text)::numeric(8,2) AS precipitation_mm,
  (hour_entry.hour_data ->> 'VisibilityMeters'::text)::numeric(8,2) AS visibility_meters,
  (hour_entry.hour_data ->> 'CloudCoverPercent'::text)::numeric(8,2) AS cloud_cover_percent,
  (hour_entry.hour_data ->> 'IsUnseasonablyHot'::text)::BOOLEAN AS is_unseasonably_hot,
  (hour_entry.hour_data ->> 'IsUnseasonablyCold'::text)::BOOLEAN AS is_unseasonably_cold,
  (hour_entry.hour_data ->> 'OutdoorDiningScore'::text)::INTEGER AS outdoor_dining_score,
  (hour_entry.hour_data ->> 'WindDirectionDegrees'::text)::INTEGER AS wind_direction_degrees,
  (hour_entry.hour_data ->> 'PrecipitationProbability'::text)::numeric(8,2) AS precipitation_probability,
  (hour_entry.hour_data ->> 'ApparentTemperatureCelsius'::text)::numeric(8,2) AS apparent_temperature_celsius
FROM dim.weather w
CROSS JOIN LATERAL jsonb_each(w.weatherinfo -> 'Hours'::text) hour_entry(hour_key, hour_data)
WHERE w.weatherinfo::text LIKE '{"Date":%'::text;
ALTER TABLE dim.vw_weatherhourlydata OWNER TO citus;

-- =============================================================================
-- STORED PROCEDURES
-- =============================================================================

CREATE OR REPLACE PROCEDURE fact.getsalesreport(
  IN _organizationid text, IN _startdate text, IN _enddate text,
  OUT transactioncount integer, OUT salestotal numeric, OUT avgtransaction numeric,
  OUT avgguest numeric, OUT avgguesttransaction numeric, OUT loyaltysales numeric, OUT loyaltypct numeric
)
LANGUAGE plpgsql AS $$
BEGIN
  SELECT COUNT(th.transactionheaderid),
    COALESCE(SUM(th.ordertotal), 0),
    COALESCE(SUM(th.ordertotal)::float / NULLIF(COUNT(th.transactionheaderid), 0), 0),
    CASE WHEN SUM(mi.totalguests) = 0 THEN 0 ELSE COALESCE(SUM(th.ordertotal)::float / SUM(mi.totalguests), 0) END,
    CASE WHEN COUNT(th.transactionheaderid) = 0 THEN 0 ELSE COALESCE(SUM(mi.totalguests)::float / COUNT(th.transactionheaderid), 0) END,
    0.000, 0.0
  INTO transactioncount, salestotal, avgtransaction, avgguest, avgguesttransaction, loyaltysales, loyaltypct
  FROM fact.transactionheader AS th
  INNER JOIN dim.datedim AS dd ON dd.dateid = th.dateid
  INNER JOIN dim.organizationlocation AS ol ON ol.locationid = th.locationid
  LEFT JOIN (
    SELECT th.transactionheaderid, COUNT(*) AS totalguests
    FROM fact.transactionheader AS th
    INNER JOIN dim.datedim AS dd ON dd.dateid = th.dateid
    INNER JOIN fact.transactionitem AS ti ON ti.transactionheaderid = th.transactionheaderid
    INNER JOIN dim.menuitem AS mi ON mi.id = ti.menuitemid AND mi.guest = 1
    INNER JOIN dim.organizationlocation AS ol ON ol.locationid = th.locationid
    WHERE ol.organizationid = _organizationid
      AND LOWER(th.orderstatus) = 'order-placed'
      AND dd.datets BETWEEN _startdate::timestamp with time zone AND _enddate::timestamp with time zone
    GROUP BY th.transactionheaderid
  ) AS mi ON mi.transactionheaderid = th.transactionheaderid
  WHERE ol.organizationid = _organizationid
    AND LOWER(th.orderstatus) = 'order-placed'
    AND dd.datets BETWEEN _startdate::timestamp with time zone AND _enddate::timestamp with time zone;
END;
$$;
ALTER PROCEDURE fact.getsalesreport(IN text, IN text, IN text, OUT integer, OUT numeric, OUT numeric, OUT numeric, OUT numeric, OUT numeric, OUT numeric) OWNER TO citus;

CREATE OR REPLACE PROCEDURE fact.usp_update_datetime_fields()
LANGUAGE plpgsql AS $BODY$
BEGIN
  UPDATE fact.transactionheader
     SET orderdatelocal = ((transactionheader.orderdateutc)::timestamp with time zone AT TIME ZONE l.timezone)
  FROM (SELECT DISTINCT location.locationid,
          CASE WHEN (location.timezone IS NULL OR location.timezone = '') THEN 'America/New_York' ELSE location.timezone END AS timezone
        FROM dim.location) l
  WHERE l.locationid = transactionheader.locationid AND transactionheader.orderdatelocal IS NULL;

  UPDATE fact.transactionheader
     SET orderdatelocal = ((transactionheader.orderdateutc)::timestamp with time zone AT TIME ZONE 'America/New_York')
  WHERE transactionheader.orderdatelocal IS NULL;

  UPDATE fact.transactionheader
     SET dateid = (to_char(transactionheader.orderdatelocal, 'YYYYMMDDHH24'))::integer
  WHERE transactionheader.dateid IS NULL;

  UPDATE fact.transactionheader
     SET businessdate = (transactionheader.orderdatelocal)::date
  WHERE transactionheader.businessdate IS NULL;

  UPDATE fact.transactionheader
     SET abtestid = abtests.abtestid
  FROM dim.abtests
  WHERE abtests.ordersessionid = transactionheader.ordersessionid AND transactionheader.abtestid IS NULL;

  UPDATE fact.transactionitem
     SET orderdatelocal = ((transactionitem.orderdateutc)::timestamp with time zone AT TIME ZONE l.timezone)
  FROM (SELECT DISTINCT location.locationid,
          CASE WHEN (location.timezone IS NULL OR location.timezone = '') THEN 'America/New_York' ELSE location.timezone END AS timezone
        FROM dim.location) l
  WHERE l.locationid = transactionitem.locationid AND transactionitem.orderdatelocal IS NULL;

  UPDATE fact.transactionitem
     SET orderdatelocal = ((transactionitem.orderdateutc)::timestamp with time zone AT TIME ZONE 'America/New_York')
  WHERE transactionitem.orderdatelocal IS NULL;

  UPDATE fact.transactionitem
     SET businessdate = (transactionitem.orderdatelocal)::date
  WHERE transactionitem.businessdate IS NULL;
END;
$BODY$;
ALTER PROCEDURE fact.usp_update_datetime_fields() OWNER TO citus;

CREATE OR REPLACE PROCEDURE dim.usp_grubbrr_install_base()
LANGUAGE sql AS $BODY$

TRUNCATE TABLE dim.vw_grubbrrinstallbase;

WITH order_types_identities AS (
  SELECT locationid,
    order_type.order_key::TEXT AS order_type_id,
    (order_type.order_data ->> 'label')::TEXT AS label,
    (order_type.order_data ->> 'externalDeliveryMode')::TEXT AS external_delivery_mode,
    (order_type.order_data ->> 'enabled')::BOOLEAN AS order_type_enabled,
    (order_type.order_data ->> 'posChannel')::TEXT AS pos_channel,
    (order_type.order_data -> 'orderIdentity' ->> 'orderIdentityMode')::INTEGER AS order_identity_mode,
    (order_type.order_data -> 'orderIdentity' ->> 'customerIdentityMode')::INTEGER AS customer_identity_mode,
    (order_type.order_data -> 'orderIdentity' -> 'customerIdentityModes')::jsonb AS customer_identity_modes,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'askBeforeOrder')::BOOLEAN AS ask_before_order,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeCustomerNameOptional')::BOOLEAN AS make_customer_name_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makePhoneNumberOptional')::BOOLEAN AS make_phone_number_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeEmailOptional')::BOOLEAN AS make_email_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeDateOfBirthOptional')::BOOLEAN AS make_date_of_birth_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeLastFourSsnOptional')::BOOLEAN AS make_last_four_ssn_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeAddressLine1Optional')::BOOLEAN AS make_address_line1_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeAddressLine2Optional')::BOOLEAN AS make_address_line2_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeCityOptional')::BOOLEAN AS make_city_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeStateOptional')::BOOLEAN AS make_state_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeZipCodeOptional')::BOOLEAN AS make_zipcode_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeCountryOptional')::BOOLEAN AS make_country_optional
  FROM (SELECT locationid, order_types FROM dim.kioskdetails WHERE dim.is_valid_jsonb(order_types)) AS kd
  CROSS JOIN LATERAL jsonb_each(kd.order_types::jsonb -> 'options') AS order_type(order_key, order_data)
), json_order_types AS (
  SELECT locationid,
    jsonb_build_object(
      'order_type_id', order_type_id, 'label', label,
      'external_delivery_mode', external_delivery_mode, 'order_type_enabled', order_type_enabled,
      'pos_channel', pos_channel, 'order_identity_mode', order_identity_mode,
      'customer_identity_mode', customer_identity_mode, 'customer_identity_modes', customer_identity_modes,
      'ask_before_order', ask_before_order, 'make_customer_name_optional', make_customer_name_optional,
      'make_phone_number_optional', make_phone_number_optional, 'make_email_optional', make_email_optional,
      'make_date_of_birth_optional', make_date_of_birth_optional, 'make_last_four_ssn_optional', make_last_four_ssn_optional,
      'make_address_line1_optional', make_address_line1_optional, 'make_address_line2_optional', make_address_line2_optional,
      'make_city_optional', make_city_optional, 'make_state_optional', make_state_optional,
      'make_zipcode_optional', make_zipcode_optional, 'make_country_optional', make_country_optional
    ) AS order_type_config
  FROM order_types_identities
), array_order_types AS (
  SELECT locationid, to_jsonb(array_agg(order_type_config)) AS order_types_identity_config
  FROM json_order_types GROUP BY locationid
), device_details AS (
  SELECT
    kiosk_entry.kiosk_key::TEXT AS kiosk_id,
    (kiosk_entry.kiosk_data ->> 'name') AS kiosk_name,
    (kiosk_entry.kiosk_data ->> 'kioskHardwareId') AS kiosk_hardware_id,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'appVersion') AS kiosk_software_version,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'deviceType') AS os_type,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'serialNumber') AS serial_number,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'lastLoginTime')::TIMESTAMP AS last_login_time,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'testMode')::BOOLEAN AS is_test_mode,
    (kiosk_entry.kiosk_data ->> 'lastSync')::TIMESTAMP AS last_sync_time,
    (kiosk_entry.kiosk_data ->> 'isDemoDevice')::BOOLEAN AS is_demo_kiosk,
    (kiosk_entry.kiosk_data ->> 'isTestModeOn')::BOOLEAN AS is_test_mode_on,
    kd.locationid AS location_id,
    (kiosk_entry.kiosk_data ->> 'companyId') AS organization_id,
    (kiosk_entry.kiosk_data ->> 'activated')::BOOLEAN AS is_activated,
    (kiosk_entry.kiosk_data -> 'paymentIntegrationConfigs')::jsonb AS payment_integration_configs,
    (kiosk_entry.kiosk_data -> 'printerConfigurations')::jsonb AS printer_configs,
    (kiosk_entry.kiosk_data ->> 'kioskActivation')::INTEGER AS kiosk_activation,
    (kiosk_entry.kiosk_data ->> 'kioskMode')::INTEGER AS kiosk_mode,
    (kiosk_entry.kiosk_data ->> 'kioskLogging')::INTEGER AS kiosk_logging,
    (kiosk_entry.kiosk_data ->> 'isGoastKisok')::BOOLEAN AS is_goast_kiosk,
    (kiosk_entry.kiosk_data ->> 'loyaltyLoginOtp') AS loyalty_login_otp,
    kd.pos_provider::jsonb AS pos_provider, kd.loyalty_provider::jsonb AS loyalty_provider,
    kd.payment_provider::jsonb AS payment_provider, kd.scanners::jsonb AS scanners,
    kd.item_special_request::jsonb AS item_special_request, kd.legal_copy_enabled::BOOLEAN AS legal_copy_enabled,
    kd.ada_configuration::jsonb AS ada_configuration, kd.calculate_default_modifier_price::BOOLEAN AS calculate_default_modifier_price,
    kd.track_kiosk_user_behavior::BOOLEAN AS track_kiosk_user_behavior, kd.loyalty_feature::BOOLEAN AS loyalty_feature,
    kd.pickup_flow::BOOLEAN AS pickup_flow, kd.pos_auto_applied_discount::BOOLEAN AS pos_auto_applied_discount,
    kd.search_functionality_enabled::BOOLEAN AS search_functionality_enabled, kd.recent_orders_enabled::BOOLEAN AS recent_orders_enabled,
    kd.play_card_config::jsonb AS play_card_config, kd.round_up_for_charity::BOOLEAN AS round_up_for_charity,
    kd.calories_enabled::BOOLEAN AS calories_enabled, kd.scan_and_go_enabled::BOOLEAN AS scan_and_go_enabled,
    kd.age_verification::jsonb AS age_verification,
    (kd.tips_settings::jsonb ->> 'enableTips')::BOOLEAN AS tips_enabled,
    (kd.tips_settings::jsonb ->> 'applyBeforeTaxes')::BOOLEAN AS apply_before_taxes,
    (kd.kiosk_receipt_settings::jsonb ->> 'autoPrint')::BOOLEAN AS auto_print_enabled,
    (kd.kiosk_receipt_settings::jsonb ->> 'includePosOrderNumber')::BOOLEAN AS include_pos_order_number,
    (kd.kiosk_receipt_settings::jsonb ->> 'showQrCodeWhenPrintReceiptFails')::BOOLEAN AS show_qr_code_when_print_receipt_fails,
    (kd.kiosk_receipt_settings::jsonb -> 'receiptVisibilityOptions' ->> 'modifierGroupNames')::BOOLEAN AS print_modifier_group_names,
    (kd.kiosk_receipt_settings::jsonb -> 'receiptVisibilityOptions' ->> 'defaultModifiers')::BOOLEAN AS print_default_modifiers,
    (kd.kiosk_receipt_settings::jsonb -> 'receiptVisibilityOptions' ->> 'freeModifiers')::BOOLEAN AS print_free_modifiers,
    (kd.kiosk_receipt_settings::jsonb -> 'receiptVisibilityOptions' ->> 'pricedModifiers')::BOOLEAN AS print_priced_modifiers,
    (kd.kiosk_receipt_settings::jsonb -> 'emailSettings' ->> 'enableEmailReceipt')::BOOLEAN AS enable_email_receipts,
    (kd.kiosk_receipt_settings::jsonb -> 'smsSetting' ->> 'enableSmsReceipt')::BOOLEAN AS enable_sms_receipt,
    (kd.kiosk_receipt_settings::jsonb -> 'showQrCodeForReceiptUrl')::BOOLEAN AS qr_code_for_receipt,
    (kd.business_hours_config::jsonb -> 'message' ->> 'showScreensaver')::BOOLEAN AS show_screensaver,
    (kd.business_hours_config::jsonb ->> 'showMessage')::BOOLEAN AS business_hours_show_message,
    (kd.business_hours_config::jsonb ->> 'enabled')::BOOLEAN AS business_hours_enabled,
    (kd.business_hours_config::jsonb ->> 'posHoursEnabled')::BOOLEAN AS pos_hours_enabled,
    (kd.order_limit_config::jsonb ->> 'quantityLimitPerItem')::INTEGER AS quantity_limit_per_item,
    (kd.order_limit_config::jsonb ->> 'quantityLimitPerOrder')::INTEGER AS quantity_limit_per_order,
    (kd.order_limit_config::jsonb ->> 'maxDiscountPerOrder')::INTEGER AS max_discount_per_order,
    (kd.order_limit_config::jsonb ->> 'showItemAsIsOption')::BOOLEAN AS show_item_asis_option,
    (kd.order_limit_config::jsonb ->> 'enableMinimumOrderTotal')::BOOLEAN AS enable_minimum_order_total,
    (kd.order_limit_config::jsonb ->> 'autoApplyMinQtyToFirstModifier')::BOOLEAN AS auto_apply_min_qty_to_first_modifier,
    (kd.order_limit_config::jsonb ->> 'showMakeItAMealOption')::BOOLEAN AS show_make_it_a_meal_option,
    (kd.order_limit_config::jsonb ->> 'enableComboAutoSkip')::BOOLEAN AS enable_combo_auto_skip,
    (kd.order_limit_config::jsonb ->> 'countToShowPromptsForItemUpsell')::INTEGER AS number_of_item_upsell_prompts_per_order,
    (kd.order_limit_config::jsonb -> 'discountOrderingOptions' ->> 'canEnterCode')::BOOLEAN AS can_enter_code_for_discount,
    (kd.order_limit_config::jsonb -> 'discountOrderingOptions' ->> 'canScanQRCode')::BOOLEAN AS can_scan_qr_code_for_discount,
    (kd.order_limit_config::jsonb -> 'discountOrderingOptions' ->> 'canSelectFromList')::BOOLEAN AS can_select_from_list_for_discount,
    to_jsonb(array(SELECT jsonb_object_keys(kd.kiosk_appearance_text_overrides::jsonb -> 'strings'))) AS enabled_languages,
    (kd.kiosk_appearance_style_options::jsonb ->> 'displayModifierGroupRestrictions')::BOOLEAN AS display_modifier_group_restriction,
    (kd.kiosk_appearance_style_options::jsonb ->> 'allowUserToCollapseOrExpandModifierGroups')::BOOLEAN AS allow_user_to_collapse_or_expand_modifier_groups,
    (kd.kiosk_appearance_style_options::jsonb ->> 'showModifierGroupNamesOrderReview')::BOOLEAN AS show_modifier_group_names_on_order_review,
    (kd.kiosk_appearance_style_options::jsonb ->> 'orderReviewShowDefaultModifiers')::BOOLEAN AS show_default_modifier_on_order_review,
    (kd.kiosk_appearance_style_options::jsonb ->> 'autoExpandModifierGorup')::BOOLEAN AS auto_expand_modifier_group,
    (kd.kiosk_appearance_style_options::jsonb ->> 'showFullPremiumModifierPrice')::BOOLEAN AS show_full_premium_modifier_price,
    (kd.kiosk_appearance_style_options::jsonb ->> 'enableNestedModifierIndentation')::BOOLEAN AS enable_nested_modifier_indentation,
    (kd.kiosk_appearance_style_options::jsonb ->> 'openNestedModifiersInPopup')::BOOLEAN AS open_nested_modifiers_in_popup,
    kd.kiosk_appearance_style_options::jsonb ->> 'categoryHeaderDisplayMode' AS category_header_display_mode,
    kd.kiosk_appearance_style_options::jsonb ->> 'categoryHeaderLogoDisplayMode' AS category_header_logo_display_mode,
    (kd.kiosk_appearance_style_options::jsonb ->> 'showCategoryHighlightedColor')::BOOLEAN AS show_category_highlighted_color,
    (kd.kiosk_appearance_style_options::jsonb ->> 'showItemDescriptions')::BOOLEAN AS show_item_description,
    kd.kiosk_appearance_style_options::jsonb ->> 'categoryNamePostition' AS category_name_position,
    (kd.kiosk_appearance_style_options::jsonb -> 'kioskMenuAppearanceOptions' ->> 'hideSoldOutItemAndModifierOnKiosk')::BOOLEAN AS hide_sold_out_item_and_modifier_on_kiosk,
    (kd.kiosk_appearance_style_options::jsonb ->> 'makeCategorySideTranslucent')::BOOLEAN AS make_category_sidebar_translucent,
    (kd.kiosk_appearance_style_options::jsonb ->> 'enableSingleStepSubcategoryFlow')::BOOLEAN AS enable_single_step_subcategory_flow,
    (kd.kiosk_appearance_style_options::jsonb ->> 'removeCategoryHighLightedBorder')::BOOLEAN AS remove_category_highlighted_border,
    (kd.kiosk_appearance_style_options::jsonb ->> 'enableExtendedComboMode')::BOOLEAN AS enable_extended_combo_mode,
    kd.kiosk_appearance_style_options::jsonb ->> 'buttonStyle' AS button_style,
    (kd.kiosk_appearance_style_options::jsonb ->> 'showDiscountCodeButton')::BOOLEAN AS show_discount_code_button,
    (kd.kiosk_appearance_style_options::jsonb ->> 'makeItemComboImagesRounded')::BOOLEAN AS make_item_combo_images_rounded,
    (kd.kiosk_appearance_style_options::jsonb ->> 'showLoyaltyPointsOnHeader')::BOOLEAN AS show_loyalty_points_on_header,
    (kd.kiosk_appearance_style_options::jsonb -> 'kioskStyleAcceptedPaymentOptions' ->> 'showCard')::BOOLEAN AS show_card_accepted_payment_options,
    (kd.kiosk_appearance_style_options::jsonb -> 'kioskStyleAcceptedPaymentOptions' ->> 'showGooglePay')::BOOLEAN AS show_google_pay_accepted_payment_options,
    (kd.kiosk_appearance_style_options::jsonb -> 'kioskStyleAcceptedPaymentOptions' ->> 'showApplePay')::BOOLEAN AS show_apple_pay_accepted_payment_options,
    (kd.kiosk_appearance_style_options::jsonb -> 'kioskStyleAcceptedPaymentOptions' ->> 'showCash')::BOOLEAN AS show_cash_accepted_payment_options,
    (kd.kiosk_appearance_style_options::jsonb -> 'tapToOrderSetting' ->> 'showTapToOrderCTA')::BOOLEAN AS show_tap_to_order_cta,
    (kd.kiosk_appearance_style_options::jsonb -> 'tapToOrderSetting' ->> 'useTextForCTA')::BOOLEAN AS use_text_for_cta,
    (kd.kiosk_appearance_style_options::jsonb -> 'tapToOrderSetting' ->> 'useImageForCTA')::BOOLEAN AS use_image_for_cta,
    (kd.localization::jsonb -> 'currency')::jsonb AS choose_a_currency,
    kd.localization::jsonb -> 'locale' ->> 'code' AS choose_a_locale,
    (kd.order_types::jsonb -> 'orderTokenSettings' ->> 'orderNumberStart')::INTEGER AS order_number_start,
    (kd.order_types::jsonb -> 'orderTokenSettings' ->> 'allotment')::INTEGER AS allotment,
    (kd.menu_behavior_config::jsonb -> 'negativeModifierBehavior')::jsonb AS negative_modifier_behavior,
    kd.disclaimer_text, kd.preorder_popup_enabled, kd.preorder_popup_text,
    kd.perform_pos_status_check, kd.sysinserttime
  FROM (SELECT * FROM dim.kioskdetails WHERE dim.is_valid_jsonb(kiosks)) AS kd
  CROSS JOIN LATERAL jsonb_each(kd.kiosks::jsonb) AS kiosk_entry(kiosk_key, kiosk_data)
), total AS (
  SELECT DISTINCT
    ol.organizationid AS organization_id, ol.organizationname AS organization_name,
    ol.locationid AS location_id, ol.locationname AS location_name,
    dd.kiosk_id, dd.kiosk_name,
    CASE WHEN dd.kiosk_hardware_id LIKE 'kiosk-hardware-%' THEN substring(dd.kiosk_hardware_id, 16, length(dd.kiosk_hardware_id)) ELSE dd.kiosk_hardware_id END AS kiosk_hardware_id,
    dd.kiosk_software_version, dd.os_type, dd.serial_number,
    dd.is_test_mode, dd.is_demo_kiosk, dd.is_test_mode_on,
    dd.last_login_time, dd.last_sync_time,
    k.devicecreatedon AS device_created_on, k.devicedeletedon AS device_deleted_on,
    k.istestkiosk AS is_test_kiosk, k.devicetype AS device_type, dd.is_activated,
    dd.payment_integration_configs, dd.printer_configs,
    CASE dd.kiosk_activation WHEN 1 THEN 'Auto' WHEN 2 THEN 'Manual' END AS kiosk_activation,
    CASE WHEN k.devicedeletedon IS NOT NULL THEN TRUE ELSE FALSE END AS is_kiosk_deleted,
    CASE dd.kiosk_mode WHEN 1 THEN 'Live' WHEN 2 THEN 'Demo' WHEN 3 THEN 'Test' END AS kiosk_mode,
    dd.kiosk_logging, dd.is_goast_kiosk, dd.loyalty_login_otp,
    dd.pos_provider, dd.payment_provider, '' AS payment_device_type, dd.loyalty_provider, dd.scanners,
    CASE org.status WHEN 0 THEN 'Draft' WHEN 1 THEN 'Onboarding' WHEN 2 THEN 'Live' WHEN 3 THEN 'Cancelled' END AS organization_status,
    CASE loc.status WHEN 0 THEN 'Draft' WHEN 1 THEN 'Onboarding' WHEN 2 THEN 'Live' WHEN 3 THEN 'Cancelled' END AS location_status,
    org.active AS is_org_active, loc.active AS is_loc_active,
    org.isdeleted AS is_org_deleted, loc.isdeleted AS is_loc_deleted,
    CASE WHEN org.status = 2 THEN org.modifiedon END AS org_go_live_date,
    CASE WHEN loc.status = 2 THEN loc.modifiedon END AS loc_go_live_date,
    org.createdon AS org_created_date, loc.createdon AS loc_created_date,
    org.is_ecm_enabled AS is_org_ecm_enabled, org.is_cep_enabled AS is_org_cep_enabled,
    org.is_concessionaire_enabled AS is_org_concessionaire_enabled,
    org.is_smart_upsells_enabled AS is_org_smart_upsells_enabled,
    org.is_feedback_survey_enabled AS is_org_feedback_survey_enabled,
    org.is_digital_menu_board_enabled AS is_org_digital_menu_board_enabled,
    org.is_digital_menu_default_format_enabled AS is_org_digital_menu_default_format_enabled,
    loc.is_ecm_enabled AS is_loc_ecm_enabled, loc.is_cep_enabled AS is_loc_cep_enabled,
    loc.is_concessionaire_enabled AS is_loc_concessionaire_enabled,
    loc.is_smart_upsells_enabled AS is_loc_smart_upsells_enabled,
    loc.is_feedback_survey_enabled AS is_loc_feedback_survey_enabled,
    loc.is_digital_menu_board_enabled AS is_loc_digital_menu_board_enabled,
    loc.is_digital_menu_default_format_enabled AS is_loc_digital_menu_default_format_enabled,
    dd.sysinserttime, now() AS sysupdatetime,
    dd.item_special_request, dd.legal_copy_enabled, dd.ada_configuration,
    dd.calculate_default_modifier_price, dd.track_kiosk_user_behavior,
    dd.loyalty_feature, dd.pickup_flow, dd.pos_auto_applied_discount,
    dd.search_functionality_enabled, dd.recent_orders_enabled, dd.play_card_config,
    dd.round_up_for_charity, dd.calories_enabled, dd.scan_and_go_enabled, dd.age_verification,
    dd.tips_enabled, dd.apply_before_taxes, dd.auto_print_enabled,
    dd.include_pos_order_number, dd.show_qr_code_when_print_receipt_fails,
    dd.print_modifier_group_names, dd.print_default_modifiers, dd.print_free_modifiers, dd.print_priced_modifiers,
    dd.enable_email_receipts, dd.enable_sms_receipt, dd.qr_code_for_receipt,
    dd.show_screensaver, dd.business_hours_show_message, dd.business_hours_enabled, dd.pos_hours_enabled,
    dd.quantity_limit_per_item, dd.quantity_limit_per_order, dd.max_discount_per_order,
    dd.show_item_asis_option, dd.enable_minimum_order_total, dd.auto_apply_min_qty_to_first_modifier,
    dd.show_make_it_a_meal_option, dd.enable_combo_auto_skip, dd.number_of_item_upsell_prompts_per_order,
    dd.can_enter_code_for_discount, dd.can_scan_qr_code_for_discount, dd.can_select_from_list_for_discount,
    dd.enabled_languages, dd.display_modifier_group_restriction,
    dd.allow_user_to_collapse_or_expand_modifier_groups,
    dd.show_modifier_group_names_on_order_review, dd.show_default_modifier_on_order_review,
    dd.auto_expand_modifier_group, dd.enable_nested_modifier_indentation, dd.open_nested_modifiers_in_popup,
    dd.category_header_display_mode, dd.category_header_logo_display_mode,
    dd.show_item_description, dd.category_name_position,
    dd.hide_sold_out_item_and_modifier_on_kiosk, dd.make_category_sidebar_translucent,
    dd.enable_single_step_subcategory_flow, dd.remove_category_highlighted_border,
    dd.enable_extended_combo_mode, dd.button_style, dd.show_discount_code_button,
    dd.make_item_combo_images_rounded, dd.show_loyalty_points_on_header,
    dd.show_card_accepted_payment_options, dd.show_google_pay_accepted_payment_options,
    dd.show_apple_pay_accepted_payment_options, dd.show_cash_accepted_payment_options,
    dd.show_tap_to_order_cta, dd.use_text_for_cta, dd.use_image_for_cta,
    dd.choose_a_currency, dd.choose_a_locale, dd.order_number_start, dd.allotment,
    dd.negative_modifier_behavior, dd.disclaimer_text, dd.preorder_popup_enabled, dd.preorder_popup_text,
    aot.order_types_identity_config, dd.show_category_highlighted_color,
    org.cep_subscriptions::jsonb AS cep_subscriptions, dd.perform_pos_status_check
  FROM device_details AS dd
  LEFT JOIN array_order_types AS aot ON dd.location_id = aot.locationid
  INNER JOIN dim.kiosk AS k ON dd.location_id = k.locationid AND dd.kiosk_id = k.kioskid
  INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol ON dd.location_id = ol.locationid
  INNER JOIN dim.organization AS org ON ol.organizationid = org.id
  INNER JOIN dim.organization AS loc ON ol.locationid = loc.id
)
INSERT INTO dim.vw_grubbrrinstallbase
SELECT * FROM total
WHERE location_status = 'Live' AND is_loc_active = TRUE AND kiosk_mode = 'Live';

$BODY$;
ALTER PROCEDURE dim.usp_grubbrr_install_base() OWNER TO citus;

CREATE OR REPLACE PROCEDURE dim.usp_master_keys_for_duplicate_items()
LANGUAGE plpgsql AS $BODY$
BEGIN
  WITH duplicate_items AS (
    SELECT *, count(*) OVER (PARTITION BY locationid, trim(lower(menuitemname))) AS dupl
    FROM dim.category_hierarchy
  )
  INSERT INTO dim.duplicate_items_master (
    organizationid, locationid, categoryid, categoryname, menuitemid,
    entitytype, item_class_type, menuitemname, sysinserttime
  )
  SELECT organizationid, locationid, categoryid, categoryname, menuitemid,
         entitytype, item_class_type, menuitemname, now()::TIMESTAMP
  FROM duplicate_items di
  WHERE dupl > 1
    AND NOT EXISTS (
      SELECT 1 FROM dim.duplicate_items_master AS dim
      WHERE dim.locationid = di.locationid AND dim.categoryid = di.categoryid AND dim.menuitemid = di.menuitemid
    );

  WITH item_counts AS (
    SELECT locationid, dimmenuitemid, count(*) AS instance_count
    FROM fact.transactionitem WHERE transactionheaderid LIKE 'ordevt-%'
    GROUP BY locationid, dimmenuitemid
  )
  UPDATE dim.duplicate_items_master dim
  SET instance_count = ic.instance_count, sysupdatetime = now()::TIMESTAMP
  FROM item_counts ic
  WHERE dim.locationid = ic.locationid AND dim.menuitemid = ic.dimmenuitemid;

  UPDATE dim.duplicate_items_master dim
  SET masteritemid = concat('mstritm-', uuid_generate_v5(uuid_ns_dns(), concat(dim.locationid, ':', trim(lower(dim.menuitemname))))),
      sysupdatetime = now()::TIMESTAMP
  WHERE dim.masteritemid IS NULL;
END;
$BODY$;
ALTER PROCEDURE dim.usp_master_keys_for_duplicate_items() OWNER TO citus;

CREATE OR REPLACE PROCEDURE fact.usp_location_statistics()
LANGUAGE plpgsql AS $BODY$
BEGIN
  TRUNCATE TABLE fact.location_statistics;

  WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol WHERE ol.organizationtype = 0
  ), order_items AS (
    SELECT ti.* FROM (
      SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.*
      FROM fact.transactionitem AS ti
      INNER JOIN org_loc_lookup AS ol ON ti.locationid = ol.locationid
      WHERE ti.transactionheaderid LIKE 'ordevt-%'
    ) AS ti
  ), frequent_customers AS (
    SELECT fc.organizationid,
      count(*) AS number_of_frequent_customers,
      sum(fc.ordercount) AS orders_placed_by_freq_customers,
      sum(fc.amountspent) AS amount_spent_by_freq_customers,
      sum(fc.amountspent) / CASE WHEN sum(fc.ordercount) > 0 THEN sum(fc.ordercount) ELSE 1 END AS avg_amount_spent_by_freq_customers
    FROM dim.frequentcustomer AS fc GROUP BY fc.organizationid
  ), org_agg_trxn AS (
    SELECT ol.organizationid,
      count(*) AS org_total_order_count,
      sum(th.ordertotal) AS org_total_sales_amount,
      round(avg(th.ordertotal), 3) AS org_avg_order_amount
    FROM fact.transactionheader AS th
    INNER JOIN org_loc_lookup AS ol ON th.locationid = ol.locationid
    WHERE th.orderstatus = 'order-placed' GROUP BY organizationid
  ), loc_agg_trxn AS (
    SELECT th.locationid,
      count(*) AS loc_total_order_count,
      sum(th.ordertotal) AS loc_total_sales_amount,
      round(avg(th.ordertotal), 3) AS loc_avg_order_amount
    FROM fact.transactionheader AS th WHERE th.orderstatus = 'order-placed'
    GROUP BY th.locationid
  ), loc_agg AS (
    SELECT organizationid, locationid, count(*) AS total_items_ordered_within_loc
    FROM order_items GROUP BY organizationid, locationid
  ), loc_itm_agg AS (
    SELECT organizationid, locationid, dimmenuitemid,
      count(*) AS item_selection_frequency_within_loc, max(itemunitprice) AS itemunitprice
    FROM order_items GROUP BY organizationid, locationid, dimmenuitemid
  ), item_statistics AS (
    SELECT lia.organizationid, lia.locationid, lia.dimmenuitemid, lia.itemunitprice,
      lia.item_selection_frequency_within_loc, la.total_items_ordered_within_loc,
      100 * lia.item_selection_frequency_within_loc::NUMERIC(8,3) / la.total_items_ordered_within_loc AS pct_item_selection_freq_within_loc,
      dense_rank() OVER (PARTITION BY lia.locationid ORDER BY item_selection_frequency_within_loc DESC) AS loc_item_popularity
    FROM loc_itm_agg AS lia
    INNER JOIN loc_agg AS la ON lia.organizationid = la.organizationid AND lia.locationid = la.locationid
  ), item_details AS (
    SELECT its.organizationid, its.locationid,
      jsonb_agg(jsonb_build_object(
        'menuitemid', its.dimmenuitemid, 'x_times_selected', its.item_selection_frequency_within_loc,
        'total_items_selected', its.total_items_ordered_within_loc, 'pct_of_all_items', its.pct_item_selection_freq_within_loc,
        'item_class_type', mi.item_class_type, 'itemunitprice', COALESCE(its.itemunitprice, mi.itemunitprice),
        'loc_item_popularity', loc_item_popularity
      ) ORDER BY loc_item_popularity ASC, item_selection_frequency_within_loc DESC) AS loc_item_popularity
    FROM item_statistics AS its
    LEFT JOIN dim.menuitem AS mi ON its.dimmenuitemid = mi.menuitemid
    WHERE loc_item_popularity <= 20 GROUP BY its.organizationid, its.locationid
  ), order_types AS (
    SELECT locationid, jsonb_agg(value ->> 'label') AS order_type_labels
    FROM (SELECT * FROM dim.kioskdetails WHERE dim.is_valid_jsonb(order_types) AND locationid IN (SELECT locationid FROM org_loc_lookup)) AS ld
    CROSS JOIN LATERAL jsonb_each(ld.order_types::jsonb -> 'options') GROUP BY locationid
  )
  INSERT INTO fact.location_statistics
  SELECT DISTINCT
    olk.organizationid, olk.organizationname, olk.locationid, olk.locationname,
    l.city, l.state, l.country, l.active AS isactive, l.timezone,
    ot.order_type_labels, itd.loc_item_popularity,
    COALESCE(la.loc_total_order_count, 0), COALESCE(la.loc_total_sales_amount, 0), COALESCE(la.loc_avg_order_amount, 0),
    COALESCE(oa.org_total_order_count, 0), COALESCE(oa.org_total_sales_amount, 0), COALESCE(oa.org_avg_order_amount, 0),
    COALESCE(fc.number_of_frequent_customers, 0), COALESCE(fc.orders_placed_by_freq_customers, 0),
    COALESCE(fc.amount_spent_by_freq_customers, 0), COALESCE(ROUND(fc.avg_amount_spent_by_freq_customers, 3), 0),
    now()::TIMESTAMP AS sysupdatetime
  FROM org_loc_lookup AS olk
  LEFT JOIN dim.organization AS l ON olk.locationid = l.id
  LEFT JOIN order_types AS ot ON olk.locationid = ot.locationid
  LEFT JOIN item_details AS itd ON olk.locationid = itd.locationid
  LEFT JOIN loc_agg_trxn AS la ON olk.locationid = la.locationid
  LEFT JOIN org_agg_trxn AS oa ON olk.organizationid = oa.organizationid
  LEFT JOIN frequent_customers AS fc ON olk.organizationid = fc.organizationid;
END;
$BODY$;
ALTER PROCEDURE fact.usp_location_statistics() OWNER TO citus;

CREATE OR REPLACE PROCEDURE fact.usp_offer_analysis()
LANGUAGE plpgsql AS $BODY$
BEGIN
  WITH delta AS (
    SELECT * FROM fact.recommendations AS rc
    WHERE rc.syscosmosts > (SELECT ts - 10 FROM fact.watermarktable WHERE watermarktablename = 'fact.recommendations')
      AND NOT EXISTS (SELECT 1 FROM fact.vw_offer_analysis AS oa WHERE oa.locationid = rc.locationid AND oa.transactionheaderid = rc.transactionheaderid)
  ), rec AS (
    SELECT rc.transactionheaderid, rc.locationid, rc.recommendationid, rc.offereditems,
      rc.prompttimestamp, rc.prompttimestamp::TIMESTAMP AS upsellprompttime, rc.syscosmosts,
      element.value ->> 'itemId' AS offered_itemid, element.value ->> 'upsellLevel' AS offered_upselllevel,
      element.value ->> 'promptItemId' AS offered_prmpid, element.value ->> 'upsellGroupId' AS offered_upslgrpid
    FROM delta AS rc, LATERAL jsonb_array_elements(rc.offereditems) element(value)
  ), selected AS (
    SELECT rc.transactionheaderid, rc.locationid, rc.recommendationid, rc.selecteditems, rc.prompttimestamp,
      element.value ->> 'itemId' AS selected_itemid, element.value ->> 'quantity' AS selected_quantity,
      element.value ->> 'upsellLevel' AS selected_upselllevel, element.value ->> 'promptItemId' AS selected_prmpid,
      element.value ->> 'upsellGroupId' AS selected_upslgrpid
    FROM delta AS rc, LATERAL jsonb_array_elements(rc.selecteditems) element(value)
  ), item_analysis AS (
    SELECT r.locationid, r.transactionheaderid, r.recommendationid,
      r.offered_itemid AS offereditem, s.selected_itemid AS selecteditem,
      CASE
        WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'item'  THEN 'Item Level Upsells'
        WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'order' THEN 'Order Level Upsells'
        WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'    THEN 'Smart Upsells'
        ELSE NULL
      END AS upselltype,
      coalesce(s.selected_upslgrpid, r.offered_upslgrpid) AS upsellgroupid, ul.upsellgroupname,
      CASE WHEN lower(s.selected_quantity) = ANY (ARRAY['true','1']) THEN 1 ELSE lower(s.selected_quantity)::integer END AS quantity,
      r.prompttimestamp, r.upsellprompttime, r.syscosmosts, now() AS sysinserttime
    FROM (SELECT * FROM rec WHERE rec.offered_itemid LIKE 'itm-%') r
    LEFT JOIN selected s ON r.transactionheaderid = s.transactionheaderid AND r.recommendationid = s.recommendationid AND r.offered_itemid = s.selected_itemid
    LEFT JOIN dim.upsellgrouplookup ul ON coalesce(s.selected_upslgrpid, r.offered_upslgrpid) = ul.upsellgroupid::text
  ), category_analysis AS (
    SELECT r.locationid, r.transactionheaderid, r.recommendationid,
      r.offered_itemid AS offereditem, s.selected_itemid AS selecteditem,
      CASE
        WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'item'  THEN 'Item Level Upsells'
        WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'order' THEN 'Order Level Upsells'
        WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'    THEN 'Smart Upsells'
        ELSE NULL
      END AS upselltype,
      coalesce(s.selected_upslgrpid, r.offered_upslgrpid) AS upsellgroupid, ul.upsellgroupname,
      CASE WHEN lower(s.selected_quantity) = ANY (ARRAY['true','1']) THEN 1 ELSE lower(s.selected_quantity)::integer END AS quantity,
      r.prompttimestamp, r.upsellprompttime, r.syscosmosts, now() AS sysinserttime
    FROM (SELECT * FROM rec WHERE rec.offered_itemid LIKE 'cat-%') AS r
    INNER JOIN dim.category_hierarchy AS ctg ON r.offered_itemid = ctg.categoryid
    INNER JOIN (SELECT * FROM selected WHERE selected.selected_itemid NOT IN (SELECT offered_itemid FROM rec)) s
      ON r.transactionheaderid = s.transactionheaderid AND r.recommendationid = s.recommendationid AND ctg.menuitemid = s.selected_itemid
    LEFT JOIN dim.upsellgrouplookup ul ON coalesce(s.selected_upslgrpid, r.offered_upslgrpid) = ul.upsellgroupid::text
  ), total AS (
    SELECT * FROM item_analysis UNION SELECT * FROM category_analysis
  )
  INSERT INTO fact.vw_offer_analysis SELECT * FROM total;

  UPDATE fact.watermarktable SET ts = rec.maxts
  FROM (SELECT coalesce(max(syscosmosts), 1500000010) AS maxts, 'fact.recommendations' AS tablename FROM fact.recommendations) AS rec
  WHERE watermarktable.watermarktablename = rec.tablename;
END;
$BODY$;
ALTER PROCEDURE fact.usp_offer_analysis() OWNER TO citus;

CREATE OR REPLACE PROCEDURE fact.usp_customer_menu_preferences()
LANGUAGE sql AS $BODY$
TRUNCATE TABLE fact.customer_menu_preferences;

WITH part AS (
  SELECT * FROM fact.transactionheader AS th WHERE th.orderstatus = 'order-placed' AND th.frequentcustomerid IS NOT NULL
), dayparts AS (
  SELECT th.frequentcustomerid, ti.transactionheaderid, ti.itemid, ti.locationid, th.orderdatelocal,
    CASE WHEN ti.itemtype = 'item' AND ti.dimmenuitemid IS NOT NULL THEN ti.dimmenuitemid
         WHEN ti.itemtype <> 'item' AND ti.comboid IS NOT NULL THEN ti.comboid END AS dimmenuitemid,
    CASE
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 6 AND 10  THEN 'Breakfast'
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 11 AND 13 THEN 'Lunch'
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 14 AND 16 THEN 'Afternoon/Snack'
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 17 AND 20 THEN 'Dinner'
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) >= 21 OR EXTRACT(HOUR FROM th.orderdatelocal) < 6 THEN 'Late Night'
    END AS day_parts,
    'All Day' AS all_day
  FROM part AS th
  INNER JOIN fact.transactionitem AS ti ON th.transactionheaderid = ti.transactionheaderid AND th.locationid = ti.locationid
  WHERE (ti.itemtype = 'item' AND ti.dimmenuitemid IS NOT NULL) OR (ti.itemtype <> 'item' AND ti.comboid IS NOT NULL)
), agg_dayparts AS (
  SELECT locationid, frequentcustomerid, day_parts, dimmenuitemid AS itemid, COUNT(*) AS OrdersCount
  FROM dayparts GROUP BY locationid, frequentcustomerid, day_parts, dimmenuitemid
), agg_all_day AS (
  SELECT locationid, frequentcustomerid, all_day, dimmenuitemid AS itemid, COUNT(*) AS OrdersCount
  FROM dayparts GROUP BY locationid, frequentcustomerid, all_day, dimmenuitemid
), Ranked1 AS (
  SELECT fc.organizationid AS fc_organizationid, agg.locationid, agg.frequentcustomerid,
    agg.day_parts, agg.itemid, it.ItemType, agg.OrdersCount AS item_selection_frequency, NULL AS ItemTags,
    ROW_NUMBER() OVER (PARTITION BY agg.locationid, agg.frequentcustomerid, agg.day_parts ORDER BY agg.OrdersCount DESC) AS rn
  FROM agg_dayparts AS agg
  INNER JOIN dim.frequentcustomer AS fc ON agg.frequentcustomerid = fc.frequentcustomerid
  INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid IS NOT NULL THEN dimmenuitemid
                                   WHEN itemtype <> 'item' AND comboid IS NOT NULL THEN comboid END AS itemid, itemtype
              FROM fact.transactionitem WHERE (itemtype = 'item' AND dimmenuitemid IS NOT NULL) OR (itemtype <> 'item' AND comboid IS NOT NULL)) AS it ON agg.itemid = it.itemid
), Ranked2 AS (
  SELECT fc.organizationid AS fc_organizationid, agg.locationid, agg.frequentcustomerid,
    agg.all_day, agg.itemid, it.ItemType, agg.OrdersCount AS item_selection_frequency, NULL AS ItemTags,
    ROW_NUMBER() OVER (PARTITION BY agg.locationid, agg.frequentcustomerid, agg.all_day ORDER BY agg.OrdersCount DESC) AS rn
  FROM agg_all_day AS agg
  INNER JOIN dim.frequentcustomer AS fc ON agg.frequentcustomerid = fc.frequentcustomerid
  INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid IS NOT NULL THEN dimmenuitemid
                                   WHEN itemtype <> 'item' AND comboid IS NOT NULL THEN comboid END AS itemid, itemtype
              FROM fact.transactionitem WHERE (itemtype = 'item' AND dimmenuitemid IS NOT NULL) OR (itemtype <> 'item' AND comboid IS NOT NULL)) AS it ON agg.itemid = it.itemid
), total AS (
  SELECT fc_organizationid AS organizationid, locationid, frequentcustomerid, day_parts,
    itemid, ItemType, item_selection_frequency, ItemTags::jsonb, now() AS sysinserttime
  FROM Ranked1 WHERE rn <= 10
  UNION
  SELECT fc_organizationid AS organizationid, locationid, frequentcustomerid, all_day,
    itemid, ItemType, item_selection_frequency, ItemTags::jsonb, now() AS sysinserttime
  FROM Ranked2 WHERE rn <= 10
)
INSERT INTO fact.customer_menu_preferences SELECT * FROM total;
$BODY$;
ALTER PROCEDURE fact.usp_customer_menu_preferences() OWNER TO citus;

CREATE OR REPLACE PROCEDURE fact.usp_location_menu_preferences()
LANGUAGE sql AS $BODY$
TRUNCATE TABLE fact.location_menu_preferences;

WITH part AS (
  SELECT * FROM fact.transactionheader AS th WHERE th.orderstatus = 'order-placed'
), dayparts AS (
  SELECT ti.transactionheaderid, ti.itemid, ti.locationid, th.orderdatelocal,
    CASE WHEN ti.itemtype = 'item' AND ti.dimmenuitemid IS NOT NULL THEN ti.dimmenuitemid
         WHEN ti.itemtype <> 'item' AND ti.comboid IS NOT NULL THEN ti.comboid END AS dimmenuitemid,
    CASE
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 6 AND 10  THEN 'Breakfast'
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 11 AND 13 THEN 'Lunch'
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 14 AND 16 THEN 'Afternoon/Snack'
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 17 AND 20 THEN 'Dinner'
      WHEN EXTRACT(HOUR FROM th.orderdatelocal) >= 21 OR EXTRACT(HOUR FROM th.orderdatelocal) < 6 THEN 'Late Night'
    END AS day_parts,
    'All Day' AS all_day
  FROM part AS th
  INNER JOIN fact.transactionitem AS ti ON th.transactionheaderid = ti.transactionheaderid AND th.locationid = ti.locationid
  WHERE (ti.itemtype = 'item' AND ti.dimmenuitemid IS NOT NULL) OR (ti.itemtype <> 'item' AND ti.comboid IS NOT NULL)
), agg_dayparts AS (
  SELECT locationid, day_parts, dimmenuitemid AS itemid, COUNT(*) AS OrdersCount
  FROM dayparts GROUP BY locationid, day_parts, dimmenuitemid
), agg_all_day AS (
  SELECT locationid, all_day, dimmenuitemid AS itemid, COUNT(*) AS OrdersCount
  FROM dayparts GROUP BY locationid, all_day, dimmenuitemid
), Ranked1 AS (
  SELECT ol.organizationid AS ol_organizationid, agg.locationid, agg.day_parts, agg.itemid,
    it.itemtype, agg.OrdersCount AS item_selection_frequency, NULL AS ItemTags,
    ROW_NUMBER() OVER (PARTITION BY agg.locationid, agg.day_parts ORDER BY agg.OrdersCount DESC) AS rn
  FROM agg_dayparts AS agg
  INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol ON agg.locationid = ol.locationid
  INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid IS NOT NULL THEN dimmenuitemid
                                   WHEN itemtype <> 'item' AND comboid IS NOT NULL THEN comboid END AS itemid, itemtype
              FROM fact.transactionitem WHERE (itemtype = 'item' AND dimmenuitemid IS NOT NULL) OR (itemtype <> 'item' AND comboid IS NOT NULL)) AS it ON agg.itemid = it.itemid
), Ranked2 AS (
  SELECT ol.organizationid AS ol_organizationid, agg.locationid, agg.all_day, agg.itemid,
    it.itemtype, agg.OrdersCount AS item_selection_frequency, NULL AS ItemTags,
    ROW_NUMBER() OVER (PARTITION BY agg.locationid, agg.all_day ORDER BY agg.OrdersCount DESC) AS rn
  FROM agg_all_day AS agg
  INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol ON agg.locationid = ol.locationid
  INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid IS NOT NULL THEN dimmenuitemid
                                   WHEN itemtype <> 'item' AND comboid IS NOT NULL THEN comboid END AS itemid, itemtype
              FROM fact.transactionitem WHERE (itemtype = 'item' AND dimmenuitemid IS NOT NULL) OR (itemtype <> 'item' AND comboid IS NOT NULL)) AS it ON agg.itemid = it.itemid
), total AS (
  SELECT ol_organizationid AS organizationid, locationid, day_parts, itemid, ItemType,
    item_selection_frequency, ItemTags::jsonb, now() AS sysinserttime
  FROM Ranked1 WHERE rn <= 10
  UNION
  SELECT ol_organizationid AS organizationid, locationid, all_day, itemid, ItemType,
    item_selection_frequency, ItemTags::jsonb, now() AS sysinserttime
  FROM Ranked2 WHERE rn <= 10
)
INSERT INTO fact.location_menu_preferences SELECT * FROM total;
$BODY$;
ALTER PROCEDURE fact.usp_location_menu_preferences() OWNER TO citus;

-- =============================================================================
-- GRANTS
-- =============================================================================

GRANT USAGE ON SCHEMA dim TO dhanraj;
GRANT USAGE ON SCHEMA dim TO varshil;
GRANT USAGE ON SCHEMA fact TO dhanraj;
GRANT USAGE ON SCHEMA fact TO varshil;

GRANT SELECT ON TABLE dim.abtests TO varshil;
GRANT SELECT ON TABLE dim.datedim TO dhanraj;
GRANT SELECT ON TABLE dim.datedim TO varshil;
GRANT SELECT ON TABLE dim.businessdate TO dhanraj;
GRANT SELECT ON TABLE dim.businessdate TO varshil;
GRANT SELECT ON TABLE dim.company TO dhanraj;
GRANT SELECT ON TABLE dim.company TO varshil;
GRANT SELECT ON TABLE dim.device TO varshil;
GRANT SELECT ON TABLE dim.element TO dhanraj;
GRANT SELECT ON TABLE dim.element TO varshil;
GRANT SELECT ON TABLE dim.experiment TO varshil;
GRANT SELECT ON TABLE dim.feedbackrating TO varshil;
GRANT SELECT ON TABLE dim.feedbackstatus TO varshil;
GRANT SELECT ON TABLE dim.frequentcustomer TO varshil;
GRANT SELECT ON TABLE dim.grubbrr_source_lookup TO varshil;
GRANT SELECT ON TABLE dim.itemcategory TO dhanraj;
GRANT SELECT ON TABLE dim.itemcategory TO varshil;
GRANT SELECT ON TABLE dim.itemcategory_bkp TO varshil;
GRANT SELECT ON TABLE dim.itemcategorymapping TO varshil;
GRANT SELECT ON TABLE dim.kiosk TO varshil;
GRANT SELECT ON TABLE dim.kioskdetails TO varshil;
GRANT SELECT ON TABLE dim.location TO dhanraj;
GRANT SELECT ON TABLE dim.location TO varshil;
GRANT SELECT ON TABLE dim.locationcatalog TO varshil;
GRANT SELECT ON TABLE dim.menuentities TO varshil;
GRANT SELECT ON TABLE dim.menuitem TO varshil;
GRANT SELECT ON TABLE dim.occasionsurvey TO varshil;
GRANT SELECT ON TABLE dim.ordertype TO dhanraj;
GRANT SELECT ON TABLE dim.ordertype TO varshil;
GRANT SELECT ON TABLE dim.ordertype_bkp TO varshil;
GRANT SELECT ON TABLE dim.organization TO varshil;
GRANT SELECT ON TABLE dim.organizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.organizationlocation TO varshil;
GRANT SELECT ON TABLE dim.peripheral TO varshil;
GRANT SELECT ON TABLE dim.upsellgrouplookup TO varshil;
GRANT SELECT ON TABLE dim.userlocation TO varshil;
GRANT SELECT ON TABLE dim.view TO dhanraj;
GRANT SELECT ON TABLE dim.view TO varshil;
GRANT SELECT ON TABLE dim.weather TO varshil;
GRANT SELECT ON TABLE dim.vw_weatherhourlydata TO varshil;
GRANT SELECT ON TABLE dim.vworganizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.vworganizationlocation TO varshil;
GRANT SELECT ON TABLE dim.weather_bkp TO varshil;
GRANT SELECT ON TABLE fact.cep_incidents TO dhanraj;
GRANT SELECT ON TABLE fact.customer_menu_preferences TO varshil;
GRANT SELECT ON TABLE fact.deviceevent TO dhanraj;
GRANT SELECT ON TABLE fact.deviceevent TO varshil;
GRANT SELECT ON TABLE fact.devicehealth TO varshil;
GRANT SELECT ON TABLE fact.devicestate TO dhanraj;
GRANT SELECT ON TABLE fact.devicestate TO varshil;
GRANT SELECT ON TABLE fact.devicetelemetry TO varshil;
GRANT SELECT ON TABLE fact.itemmodifier TO dhanraj;
GRANT SELECT ON TABLE fact.itemmodifier TO varshil;
GRANT SELECT ON TABLE fact.itemssurvey TO varshil;
GRANT SELECT ON TABLE fact.location_menu_preferences TO varshil;
GRANT SELECT ON TABLE fact.occasionsurveydetail TO varshil;
GRANT SELECT ON TABLE fact.ordertiming TO dhanraj;
GRANT SELECT ON TABLE fact.ordertiming TO varshil;
GRANT SELECT ON TABLE fact.peripheralhealth TO varshil;
GRANT SELECT ON TABLE fact.peripheralstate TO dhanraj;
GRANT SELECT ON TABLE fact.peripheralstate TO varshil;
GRANT SELECT ON TABLE fact.pipelinerunstatus TO dhanraj;
GRANT SELECT ON TABLE fact.pipelinerunstatus TO varshil;
GRANT SELECT ON TABLE fact.recommendations TO varshil;
GRANT SELECT ON TABLE fact.recommendations_bkp TO varshil;
GRANT SELECT ON TABLE fact.timingsdatalake TO dhanraj;
GRANT SELECT ON TABLE fact.timingsdatalake TO varshil;
GRANT SELECT ON TABLE fact.transactionheader TO dhanraj;
GRANT SELECT ON TABLE fact.transactionheader TO varshil;
GRANT SELECT ON TABLE fact.transactionitem TO dhanraj;
GRANT SELECT ON TABLE fact.transactionitem TO varshil;
GRANT SELECT ON TABLE fact.transactionitemtest TO varshil;
GRANT SELECT ON TABLE fact.transactionpayment TO dhanraj;
GRANT SELECT ON TABLE fact.transactionpayment TO varshil;
GRANT SELECT ON TABLE fact.transactionrefunds TO varshil;
GRANT SELECT ON TABLE fact.userbehaviour TO dhanraj;
GRANT SELECT ON TABLE fact.userbehaviour TO varshil;
GRANT SELECT ON TABLE fact.userbehaviour_exceptions TO varshil;
GRANT SELECT ON TABLE fact.usercheckedin TO varshil;
GRANT SELECT ON TABLE fact.vw_offer_analysis TO varshil;
GRANT SELECT ON TABLE fact.watermarktable TO dhanraj;
GRANT SELECT ON TABLE fact.watermarktable TO varshil;
