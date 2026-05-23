-- The 8 tables below are fact transaction tables 
-- representing different aspects/entities of orders placed by customers at restaurants.
-- After these eight tables, there come 9 tables residing in "stg.silver_" schema and prefix, 
-- That one additional table is transaction_combo_items which represent combos 
-- that are also stored in fact.transactionitem table along with item-level data
-- Table: fact.transactionheader

-- DROP TABLE IF EXISTS fact.transactionheader;

CREATE TABLE IF NOT EXISTS fact.transactionheader
(
    id bigint NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    orderid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default" NOT NULL,
    kioskid text COLLATE pg_catalog."default",
    ordersessionid text COLLATE pg_catalog."default",
    dateid integer,
    orderdateutc text COLLATE pg_catalog."default",
    orderdatelocal timestamp without time zone,
    orderstatus text COLLATE pg_catalog."default",
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
    paymentstatus text COLLATE pg_catalog."default",
    sourcefile text COLLATE pg_catalog."default" NOT NULL DEFAULT 'NGE'::text,
    createddate timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updateddate timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
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
    frequentcustomerid text COLLATE pg_catalog."default",
    abtestid bigint,
    channel text COLLATE pg_catalog."default",
    guestcount integer,
    charityamount numeric(12,3),
    syscosmosts bigint,
    sourceid integer,
    orderservicecharge numeric(12,3) DEFAULT 0.000,
    customername character varying(100) COLLATE pg_catalog."default",
    CONSTRAINT transactionheader_pkey PRIMARY KEY (locationid, transactionheaderid),
    CONSTRAINT locationid_fk FOREIGN KEY (locationid)
        REFERENCES dim.organization (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ordertype_fk FOREIGN KEY (ordertype)
        REFERENCES dim.ordertype (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT sourceid_fk FOREIGN KEY (sourceid)
        REFERENCES dim.grubbrr_source_lookup (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.transactionheader
    OWNER to citus;

REVOKE ALL ON TABLE fact.transactionheader FROM dhanraj;
REVOKE ALL ON TABLE fact.transactionheader FROM varshil;

GRANT ALL ON TABLE fact.transactionheader TO citus;

GRANT SELECT ON TABLE fact.transactionheader TO dhanraj;

GRANT SELECT ON TABLE fact.transactionheader TO varshil;
-- Index: transactionheader_locationid_dateid_idx

-- DROP INDEX IF EXISTS fact.transactionheader_locationid_dateid_idx;

CREATE INDEX IF NOT EXISTS transactionheader_locationid_dateid_idx
    ON fact.transactionheader USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(orderstatus, ordertype, businessdate)
    TABLESPACE pg_default;


-- Table: fact.transactionitem

-- DROP TABLE IF EXISTS fact.transactionitem;

CREATE TABLE IF NOT EXISTS fact.transactionitem
(
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    categoryid bigint,
    menuitemid bigint,
    itemid text COLLATE pg_catalog."default" NOT NULL,
    comboid text COLLATE pg_catalog."default",
    ordersessionid text COLLATE pg_catalog."default" NOT NULL,
    itemsessionid text COLLATE pg_catalog."default",
    itemname text COLLATE pg_catalog."default" NOT NULL,
    itemquantity smallint DEFAULT 1,
    itemunitprice numeric(12,3),
    upselllevel text COLLATE pg_catalog."default",
    upsellpromptitemid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default" NOT NULL,
    itemtype text COLLATE pg_catalog."default",
    customize boolean,
    upgrade boolean,
    asis boolean,
    itemselectedtime timestamp without time zone,
    addtocarttime timestamp without time zone,
    totaltime numeric(7,3),
    orderdateutc text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    dimmenuitemid character varying(50) COLLATE pg_catalog."default",
    locationid character varying(50) COLLATE pg_catalog."default",
    orderdatelocal timestamp without time zone,
    businessdate date,
    syscosmosts bigint,
    frequentcustomerid text COLLATE pg_catalog."default",
    CONSTRAINT transactionitem_pkey PRIMARY KEY (transactionheaderid, itemid, itemname),
    CONSTRAINT categoryid_fk FOREIGN KEY (categoryid)
        REFERENCES dim.itemcategory (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT locationid_fk FOREIGN KEY (locationid)
        REFERENCES dim.organization (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid)
        REFERENCES fact.transactionheader (locationid, transactionheaderid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT menuitemid_fk FOREIGN KEY (menuitemid)
        REFERENCES dim.menuitem (id) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.transactionitem
    OWNER to citus;

REVOKE ALL ON TABLE fact.transactionitem FROM dhanraj;
REVOKE ALL ON TABLE fact.transactionitem FROM varshil;

GRANT ALL ON TABLE fact.transactionitem TO citus;

GRANT SELECT ON TABLE fact.transactionitem TO dhanraj;

GRANT SELECT ON TABLE fact.transactionitem TO varshil;
-- Index: idx_transactionitem_headerid

-- DROP INDEX IF EXISTS fact.idx_transactionitem_headerid;

CREATE INDEX IF NOT EXISTS idx_transactionitem_headerid
    ON fact.transactionitem USING btree
    (transactionheaderid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: idx_transactionitemtest_headerid

-- DROP INDEX IF EXISTS fact.idx_transactionitemtest_headerid;

CREATE INDEX IF NOT EXISTS idx_transactionitemtest_headerid
    ON fact.transactionitem USING btree
    (transactionheaderid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;



-- Table: fact.transactionpayment

-- DROP TABLE IF EXISTS fact.transactionpayment;

CREATE TABLE IF NOT EXISTS fact.transactionpayment
(
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    paymentintegrationid text COLLATE pg_catalog."default" NOT NULL,
    paymentid text COLLATE pg_catalog."default",
    paymentamt numeric(12,3),
    orderid text COLLATE pg_catalog."default" NOT NULL,
    locationid character varying(50) COLLATE pg_catalog."default",
    kioskid character varying(50) COLLATE pg_catalog."default",
    paymentmethod character varying(50) COLLATE pg_catalog."default",
    paymentintegrationlabel text COLLATE pg_catalog."default",
    orderdateutc text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    paymentcardtype character varying(50) COLLATE pg_catalog."default",
    sysupdatetime timestamp without time zone,
    CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid)
        REFERENCES fact.transactionheader (locationid, transactionheaderid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.transactionpayment
    OWNER to citus;

REVOKE ALL ON TABLE fact.transactionpayment FROM dhanraj;
REVOKE ALL ON TABLE fact.transactionpayment FROM varshil;

GRANT ALL ON TABLE fact.transactionpayment TO citus;

GRANT SELECT ON TABLE fact.transactionpayment TO dhanraj;

GRANT SELECT ON TABLE fact.transactionpayment TO varshil;
-- Index: transactionpayment_orderid_idx

-- DROP INDEX IF EXISTS fact.transactionpayment_orderid_idx;

CREATE INDEX IF NOT EXISTS transactionpayment_orderid_idx
    ON fact.transactionpayment USING btree
    (orderid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: transactionpaymentuidx

-- DROP INDEX IF EXISTS fact.transactionpaymentuidx;

CREATE INDEX IF NOT EXISTS transactionpaymentuidx
    ON fact.transactionpayment USING btree
    (transactionheaderid COLLATE pg_catalog."default" ASC NULLS LAST, paymentintegrationid COLLATE pg_catalog."default" ASC NULLS LAST, paymentid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


-- Table: fact.transactionrefunds

-- DROP TABLE IF EXISTS fact.transactionrefunds;

CREATE TABLE IF NOT EXISTS fact.transactionrefunds
(
    transactionheaderid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    orderid character varying(50) COLLATE pg_catalog."default",
    locationid character varying(50) COLLATE pg_catalog."default",
    refundtransactionid character varying(50) COLLATE pg_catalog."default",
    paymentid character varying(50) COLLATE pg_catalog."default",
    refundamount numeric(7,3),
    refundtype character varying(50) COLLATE pg_catalog."default",
    orderdateutc text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    syscosmosts bigint
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.transactionrefunds
    OWNER to citus;

REVOKE ALL ON TABLE fact.transactionrefunds FROM varshil;

GRANT ALL ON TABLE fact.transactionrefunds TO citus;

GRANT SELECT ON TABLE fact.transactionrefunds TO varshil;
-- Index: idx_transactionrefunds_headerid

-- DROP INDEX IF EXISTS fact.idx_transactionrefunds_headerid;

CREATE INDEX IF NOT EXISTS idx_transactionrefunds_headerid
    ON fact.transactionrefunds USING btree
    (transactionheaderid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


-- Table: fact.recommendations

-- DROP TABLE IF EXISTS fact.recommendations;

CREATE TABLE IF NOT EXISTS fact.recommendations
(
    transactionheaderid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    recommendationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    offereditems jsonb,
    selecteditems jsonb,
    isconverted boolean,
    prompttimestamp text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    syscosmosts bigint,
    CONSTRAINT locationid_trxnid_recommendationid_pk PRIMARY KEY (locationid, transactionheaderid, recommendationid),
    CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid),
    CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid)
        REFERENCES fact.transactionheader (locationid, transactionheaderid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.recommendations
    OWNER to citus;

REVOKE ALL ON TABLE fact.recommendations FROM varshil;

GRANT ALL ON TABLE fact.recommendations TO citus;

GRANT SELECT ON TABLE fact.recommendations TO varshil;


-- Table: fact.modifier_recommendations

-- DROP TABLE IF EXISTS fact.modifier_recommendations;



CREATE TABLE IF NOT EXISTS fact.modifier_recommendations
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    modifier_impressions jsonb,
    modifier_interactions jsonb,
    businessdate date,
    orderdateutc text COLLATE pg_catalog."default",
    orderdatelocal timestamp without time zone,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.modifier_recommendations
    OWNER to citus;

-- Table: fact.modifier_impressions

-- DROP TABLE IF EXISTS fact.modifier_impressions;

CREATE TABLE IF NOT EXISTS fact.modifier_impressions
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    parent_modifier_id text COLLATE pg_catalog."default",
    selection_type text COLLATE pg_catalog."default",
    nesting_depth integer,
    "position" integer,
    score numeric(5,3),
    strategy text COLLATE pg_catalog."default",
    context text COLLATE pg_catalog."default",
    selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    pre_selected boolean,
    businessdate date,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.modifier_impressions
    OWNER to citus;



-- Table: fact.modifier_interactions

-- DROP TABLE IF EXISTS fact.modifier_interactions;

CREATE TABLE IF NOT EXISTS fact.modifier_interactions
(
    locationid text COLLATE pg_catalog."default",
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    orderitemid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    modifiergroupid text COLLATE pg_catalog."default" NOT NULL,
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    modifiername text COLLATE pg_catalog."default",
    parent_modifier_id text COLLATE pg_catalog."default",
    nesting_depth integer,
    modifierquantity integer,
    modifierprice numeric(12,3),
    freequantity integer,
    selection_type text COLLATE pg_catalog."default",
    action text COLLATE pg_catalog."default",
    session_recorded_at text COLLATE pg_catalog."default",
    businessdate date,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    sourceid integer
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.modifier_interactions
    OWNER to citus;





-- ============================================================
-- Staging DDLs derived from ADF Dataflow: Orders Bronze → Silver
-- Schema: stg
-- Generated from: BronzeOrdersToSilverParquet dataflow sinks
-- ============================================================

CREATE SCHEMA IF NOT EXISTS stg;


/*
SELECT * FROM stg.silver_transaction_header;
SELECT * FROM stg.silver_transaction_item;
SELECT * FROM stg.silver_transaction_combo_items;
SELECT * FROM stg.silver_transaction_payment;
SELECT * FROM stg.silver_item_modifiers;
SELECT * FROM stg.silver_upsell_recommendations;
SELECT * FROM stg.silver_modifier_recommendations;
SELECT * FROM stg.silver_modifier_interactions;
SELECT * FROM stg.silver_modifier_impressions;
SELECT * FROM stg.silver_transaction_refunds;
SELECT * FROM stg.silver_kiosk_events;
SELECT * FROM stg.silver_cep_incidents;

SELECT * FROM stg.silver_kiosk_events WHERE token = '79EGW2F5UYYT7TBS';
SELECT * FROM stg.silver_transaction_header WHERE ordersessionid = '79EGW2F5UYYT7TBS';
*/


/*
TRUNCATE TABLE stg.silver_transaction_header;
TRUNCATE TABLE stg.silver_transaction_item;
TRUNCATE TABLE stg.silver_transaction_combo_items;
TRUNCATE TABLE stg.silver_transaction_payment;
TRUNCATE TABLE stg.silver_item_modifiers;
TRUNCATE TABLE stg.silver_upsell_recommendations;
TRUNCATE TABLE stg.silver_modifier_recommendations;
TRUNCATE TABLE stg.silver_modifier_interactions;
TRUNCATE TABLE stg.silver_modifier_impressions;
TRUNCATE TABLE stg.silver_kiosk_events;
TRUNCATE TABLE stg.silver_cep_incidents;
*/

-- ============================================================
-- 1. stg.silver_transaction_header
--    Source sink: SilverTrxnHeaderParquet
--    Branch: BronzeOrdersJson → TrxnHeaderColumns → SilverTransformTime
-- ============================================================
--DROP TABLE IF EXISTS stg.silver_transaction_header
CREATE TABLE IF NOT EXISTS stg.silver_transaction_header (
    -- Order identity
    transactionheaderid         TEXT COLLATE pg_catalog."default",
    orderid                     TEXT COLLATE pg_catalog."default",
    ordersessionid              TEXT COLLATE pg_catalog."default",
    orderdateutc                TEXT COLLATE pg_catalog."default",
    businessdate                TEXT COLLATE pg_catalog."default",
    syscosmosts                 BIGINT,

    -- Location / kiosk
    locationid                  TEXT COLLATE pg_catalog."default",
    kioskid                     TEXT COLLATE pg_catalog."default",
    kiosk_name                  TEXT COLLATE pg_catalog."default",
    kiosk_mode                  INTEGER,
    channel                     INTEGER,
    
    -- Items and Payments Array
    items_array                 TEXT COLLATE pg_catalog."default",
    payments_array              TEXT COLLATE pg_catalog."default",

    numberofitems               SMALLINT,
    numberofpayments            SMALLINT,

    -- Concept
    concept_id                  TEXT COLLATE pg_catalog."default",
    concept_name                TEXT COLLATE pg_catalog."default",

    -- Order classification
    ordertype                   TEXT COLLATE pg_catalog."default",
    order_type_label            TEXT COLLATE pg_catalog."default",
    order_completion_status     TEXT COLLATE pg_catalog."default",
    pos_submission_status       INTEGER,
    is_send_to_pos_failed       BOOLEAN,
    is_test_order               BOOLEAN,

    -- Customer / identity
    frequentcustomerid          TEXT COLLATE pg_catalog."default",
    customername                TEXT COLLATE pg_catalog."default",
    client_ip_address           TEXT COLLATE pg_catalog."default",
    order_identity_order_token  TEXT COLLATE pg_catalog."default",
    order_identity_pos_order_token TEXT COLLATE pg_catalog."default",
    order_identity_phone        TEXT COLLATE pg_catalog."default",
    order_identity_phone_country_code TEXT COLLATE pg_catalog."default",
    order_identity_email        TEXT COLLATE pg_catalog."default",
    order_identity_table_tent   TEXT COLLATE pg_catalog."default",
    order_identity_device_imei  TEXT COLLATE pg_catalog."default",

    -- Guest & receipt
    guest_count                 INTEGER,
    guest_check_code            TEXT COLLATE pg_catalog."default",
    genesis_fiscal_fields       TEXT COLLATE pg_catalog."default",
    order_language              TEXT COLLATE pg_catalog."default",
    receipt_printing_type       TEXT COLLATE pg_catalog."default",

    -- Loyalty
    loyalty_transaction_id      TEXT COLLATE pg_catalog."default",
    loyalty_payment_transaction_id TEXT COLLATE pg_catalog."default",
    loyalty_earned_points       TEXT COLLATE pg_catalog."default",

    -- Local currency
    local_currency_code         TEXT COLLATE pg_catalog."default",
    local_currency_additional_info TEXT COLLATE pg_catalog."default",

    -- USD totals
    usd_amount                  NUMERIC(12,3),
    usd_subtotal                NUMERIC(12,3),
    usd_tax                     NUMERIC(12,3),
    usd_tip                     NUMERIC(12,3),
    usd_discount                NUMERIC(12,3),
    usd_reward                  NUMERIC(12,3),
    usd_service_charge          NUMERIC(12,3),
    usd_charity_amount          NUMERIC(12,3),

    -- Cent totals
    cents_amount                BIGINT,
    cents_subtotal              BIGINT,  -- mapped from usd_subtotal cents counterpart (not in totalsCents, kept for symmetry)
    cents_tax                   BIGINT,
    cents_tip                   BIGINT,
    cents_discount              BIGINT,
    cents_reward                BIGINT,
    cents_service_charge        BIGINT,
    cents_charity_amount        BIGINT,

    -- Lineage
    bronze_filepath             TEXT COLLATE pg_catalog."default",
    silver_transform_time       TEXT COLLATE pg_catalog."default",
    silver_folderpath           TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_transaction_header
    OWNER to citus;

-- ============================================================
-- 2. stg.silver_transaction_item
--    Source sink: SilverTrxnItemParquet
--    Branch: BronzeOrdersJson → TrxnItemColumns → flattenItemsArray → SilverTransformTime2
-- ============================================================
--DROP TABLE IF EXISTS stg.silver_transaction_item;
CREATE TABLE IF NOT EXISTS stg.silver_transaction_item (
    -- Order / session identity
    transactionheaderid             TEXT COLLATE pg_catalog."default",
    orderid                         TEXT COLLATE pg_catalog."default",
    ordersessionid                  TEXT COLLATE pg_catalog."default",
    orderdateutc                    TEXT COLLATE pg_catalog."default",
    businessdate                    TEXT COLLATE pg_catalog."default",
    syscosmosts                     BIGINT,

    -- Location / kiosk
    locationid                      TEXT COLLATE pg_catalog."default",
    kioskid                         TEXT COLLATE pg_catalog."default",
    kiosk_name                      TEXT COLLATE pg_catalog."default",
    kiosk_mode                      INTEGER,
    is_test_order                   BOOLEAN,

    -- Customer / identity
    frequentcustomerid              TEXT COLLATE pg_catalog."default",

    -- Item identity
    orderitemid                     TEXT COLLATE pg_catalog."default",
    itemsessionid                   TEXT COLLATE pg_catalog."default",
    menuitemid                      TEXT COLLATE pg_catalog."default",
    menu_item_pos_id                TEXT COLLATE pg_catalog."default",
    itemname                        TEXT COLLATE pg_catalog."default",
    categoryid                      TEXT COLLATE pg_catalog."default",
    categoryname                    TEXT COLLATE pg_catalog."default",
    category_pos_id                 TEXT COLLATE pg_catalog."default",

    -- Concept
    items_concept_id                TEXT COLLATE pg_catalog."default",
    items_concept_name              TEXT COLLATE pg_catalog."default",

    -- Pricing
    itemquantity                    INTEGER,
    usd_itemunitprice               NUMERIC(12,3),
    usd_total_item_price            NUMERIC(12,3),
    cents_itemunitprice             BIGINT,
    cents_total_item_price          BIGINT,

    modifier_options                TEXT COLLATE pg_catalog."default",

    -- Discounts
    items_discount_id               TEXT COLLATE pg_catalog."default",
    is_items_discount_hidden_on_receipt BOOLEAN,
    items_discounts                 TEXT COLLATE pg_catalog."default",

    -- ML / upsell / loyalty signals
    items_upsell_source             TEXT COLLATE pg_catalog."default",
    items_reward_source             TEXT COLLATE pg_catalog."default",
    items_special_request           TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status         TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                 TEXT COLLATE pg_catalog."default",
    silver_transform_time           TEXT COLLATE pg_catalog."default",
    silver_folderpath               TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_transaction_item
    OWNER to citus;

-- ============================================================
-- 3. stg.silver_item_modifiers
--    Source sink: SilverTrxnItemModifiersParquet
--    Branch: flattenItemsArray → FlattenModifiers → SilverTransformTime3
-- ============================================================
--DROP TABLE IF EXISTS stg.silver_item_modifiers;
CREATE TABLE IF NOT EXISTS stg.silver_item_modifiers (
    -- Order / session identity
    transactionheaderid                 TEXT COLLATE pg_catalog."default",
    orderid                             TEXT COLLATE pg_catalog."default",
    ordersessionid                      TEXT COLLATE pg_catalog."default",
    orderdateutc                        TEXT COLLATE pg_catalog."default",
    businessdate                        TEXT COLLATE pg_catalog."default",
    syscosmosts                         BIGINT,

    -- Location / kiosk
    locationid                          TEXT COLLATE pg_catalog."default",
    kioskid                             TEXT COLLATE pg_catalog."default",
    kiosk_name                          TEXT COLLATE pg_catalog."default",
    kiosk_mode                          INTEGER,
    is_test_order                       BOOLEAN,

    -- Customer / identity
    frequentcustomerid                  TEXT COLLATE pg_catalog."default",

    -- Parent item identity
    orderitemid                         TEXT COLLATE pg_catalog."default",
    itemsessionid                       TEXT COLLATE pg_catalog."default",
    menuitemid                          TEXT COLLATE pg_catalog."default",
    menu_item_pos_id                    TEXT COLLATE pg_catalog."default",
    itemname                            TEXT COLLATE pg_catalog."default",
    categoryid                          TEXT COLLATE pg_catalog."default",
    categoryname                        TEXT COLLATE pg_catalog."default",
    category_pos_id                     TEXT COLLATE pg_catalog."default",

    -- Parent item pricing
    itemquantity                        INTEGER,
    usd_itemunitprice                   NUMERIC(12,3),
    usd_total_item_price                NUMERIC(12,3),
    cents_itemunitprice                 BIGINT,
    cents_total_item_price              BIGINT,

    -- Parent item discounts
    items_discount_id                   TEXT COLLATE pg_catalog."default",
    is_items_discount_hidden_on_receipt BOOLEAN,
    items_discounts                     TEXT COLLATE pg_catalog."default",

    -- Parent item signals
    items_upsell_source                 TEXT COLLATE pg_catalog."default",
    items_reward_source                 TEXT COLLATE pg_catalog."default",
    items_special_request               TEXT COLLATE pg_catalog."default",
    items_concept_id                    TEXT COLLATE pg_catalog."default",
    items_concept_name                  TEXT COLLATE pg_catalog."default",

    -- Modifier identity
    options_modifierid                  TEXT COLLATE pg_catalog."default",
    options_modifier_pos_id             TEXT COLLATE pg_catalog."default",
    options_modifiername                TEXT COLLATE pg_catalog."default",
    options_modifier_code               TEXT COLLATE pg_catalog."default",
    options_modifiergroupid             TEXT COLLATE pg_catalog."default",
    options_modifiergroupname           TEXT COLLATE pg_catalog."default",
    options_modifiergroup_pos_id        TEXT COLLATE pg_catalog."default",

    -- Modifier pricing
    options_modifierquantity            INTEGER,
    options_modifierunitprice           NUMERIC(12,3),
    options_total_modifierprice         NUMERIC(12,3),
    modifier_freequantity               INTEGER,

    -- Modifier flags
    is_modifier_invisible               BOOLEAN,
    is_modifier_default                 BOOLEAN,

    -- Order status
    order_completion_status             TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                     TEXT COLLATE pg_catalog."default",
    silver_transform_time               TEXT COLLATE pg_catalog."default",
    silver_folderpath                   TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_item_modifiers
    OWNER to citus;

-- ============================================================
-- 4. stg.silver_transaction_payment
--    Source sink: SilverTrxnPaymentsParquet
--    Branch: BronzeOrdersJson → TrxnPaymentsColumns → flattenPayments → SilverTransformTime4
-- ============================================================
--DROP TABLE IF EXISTS stg.silver_transaction_payment
CREATE TABLE IF NOT EXISTS stg.silver_transaction_payment (
    -- Order / session identity
    transactionheaderid             TEXT COLLATE pg_catalog."default",
    orderid                         TEXT COLLATE pg_catalog."default",
    ordersessionid                  TEXT COLLATE pg_catalog."default",
    orderdateutc                    TEXT COLLATE pg_catalog."default",
    businessdate                    TEXT COLLATE pg_catalog."default",
    syscosmosts                     BIGINT,

    -- Location / kiosk
    locationid                      TEXT COLLATE pg_catalog."default",
    kioskid                         TEXT COLLATE pg_catalog."default",
    kiosk_name                      TEXT COLLATE pg_catalog."default",
    kiosk_mode                      INTEGER,
    is_test_order                   BOOLEAN,

    -- Payment core
    payment_transactionid           TEXT COLLATE pg_catalog."default",
    payment_method                  TEXT COLLATE pg_catalog."default",
    payment_status                  TEXT COLLATE pg_catalog."default",
    payment_amount                  NUMERIC(12,3),
    payment_tender_id               TEXT COLLATE pg_catalog."default",
    payment_integration_id          TEXT COLLATE pg_catalog."default",
    payment_integration_label       TEXT COLLATE pg_catalog."default",
    payment_card_name               TEXT COLLATE pg_catalog."default",
    payment_card_number             TEXT COLLATE pg_catalog."default",
    is_amazon_one_payment           BOOLEAN,

    -- Card detail (from tenderInfo.cardInfo)
    card_info_card_type             TEXT COLLATE pg_catalog."default",
    card_info_last_four             TEXT COLLATE pg_catalog."default",
    card_info_masked_card_number    TEXT COLLATE pg_catalog."default",
    card_info_zip_code              TEXT COLLATE pg_catalog."default",
    card_info_expiration_month      TEXT COLLATE pg_catalog."default",
    card_info_expiration_year       TEXT COLLATE pg_catalog."default",
    card_info_processor_auth_code   TEXT COLLATE pg_catalog."default",
    card_info_available_balance     NUMERIC(12,3),

    -- Settlement / capture (string blobs from source)
    payment_capture_details         TEXT COLLATE pg_catalog."default",
    payment_settlement_details      TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status         TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                 TEXT COLLATE pg_catalog."default",
    silver_transform_time           TEXT COLLATE pg_catalog."default",
    silver_folderpath               TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_transaction_payment
    OWNER to citus;

-- ============================================================
-- 5. stg.silver_transaction_combo_item
--    Source sink: SilverTrxnItemComboItemsParquet
--    Branch: BronzeOrdersJson → TrxnComboColumns → flattenCombosArray
--            → flattenComponentSelectionsArray → SilverTransformTime5
-- ============================================================
--DROP TABLE IF EXISTS stg.silver_transaction_combo_items
CREATE TABLE IF NOT EXISTS stg.silver_transaction_combo_items (
    -- Order / session identity
    transactionheaderid                     TEXT COLLATE pg_catalog."default",
    orderid                                 TEXT COLLATE pg_catalog."default",
    ordersessionid                          TEXT COLLATE pg_catalog."default",
    orderdateutc                            TEXT COLLATE pg_catalog."default",
    businessdate                            TEXT COLLATE pg_catalog."default",
    syscosmosts                             BIGINT,

    -- Location / kiosk
    locationid                              TEXT COLLATE pg_catalog."default",
    kioskid                                 TEXT COLLATE pg_catalog."default",
    kiosk_name                              TEXT COLLATE pg_catalog."default",
    kiosk_mode                              INTEGER,
    is_test_order                           BOOLEAN,

    -- Customer / identity
    frequentcustomerid                      TEXT COLLATE pg_catalog."default",

    -- Combo identity
    combo_id                                TEXT COLLATE pg_catalog."default",
    combo_pos_id                            TEXT COLLATE pg_catalog."default",
    combo_name                              TEXT COLLATE pg_catalog."default",
    combo_order_item_id                     TEXT COLLATE pg_catalog."default",
    combo_item_session_id                   TEXT COLLATE pg_catalog."default",
    combo_concept_id                        TEXT COLLATE pg_catalog."default",
    combo_concept_name                      TEXT COLLATE pg_catalog."default",

    -- Combo pricing (source defines these as double despite "cents" naming)
    cents_combo_unit_price                  BIGINT, --changed from NUMERIC(12,3) to BIGINT since cents can't be double
    cents_combo_total_price                 BIGINT, --changed from NUMERIC(12,3) to BIGINT since cents can't be double
    combo_quantity                          INTEGER,

    -- Combo signals
    combo_special_request                   TEXT COLLATE pg_catalog."default",
    combo_upsell_source                     TEXT COLLATE pg_catalog."default",
    combo_reward_source                     TEXT COLLATE pg_catalog."default",

    -- Component selection identity
    component_id                            TEXT COLLATE pg_catalog."default",
    component_pos_id                        TEXT COLLATE pg_catalog."default",
    component_name                          TEXT COLLATE pg_catalog."default",

    -- Component item identity
    component_item_order_item_id            TEXT COLLATE pg_catalog."default",
    component_item_menu_item_id             TEXT COLLATE pg_catalog."default",
    component_item_name                     TEXT COLLATE pg_catalog."default",
    component_item_menu_item_pos_id         TEXT COLLATE pg_catalog."default",
    component_item_session_id               TEXT COLLATE pg_catalog."default",
    component_item_concept_id              TEXT COLLATE pg_catalog."default",
    component_item_concept_name            TEXT COLLATE pg_catalog."default",

    -- Component item pricing
    component_item_quantity                 INTEGER,
    component_item_price                    NUMERIC(12,3),
    component_item_unit_price               NUMERIC(12,3),
    component_item_cents_unit_price         BIGINT,
    component_item_total_price              NUMERIC(12,3),
    component_item_cents_total_price        BIGINT,

    -- Component item signals
    component_item_special_request          TEXT COLLATE pg_catalog."default",
    component_item_upsell_source            TEXT COLLATE pg_catalog."default",
    component_item_reward_source            TEXT COLLATE pg_catalog."default",
    component_item_discount_id              TEXT COLLATE pg_catalog."default",
    is_component_item_discount_hidden_on_receipt BOOLEAN,
    component_item_discounts                TEXT COLLATE pg_catalog."default",

    component_selections_items              TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status                 TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                         TEXT COLLATE pg_catalog."default",
    silver_transform_time                   TEXT COLLATE pg_catalog."default",
    silver_folderpath                       TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;


ALTER TABLE IF EXISTS stg.silver_transaction_combo_items
    OWNER to citus;

-- ============================================================
-- 6. stg.silver_upsell_recommendations
--    Source sink: SilverUpsellRecommendationsParquet
--    Branch: BronzeOrdersJson → ItemUpsellRecommColumns → flattenUpsellPrompt → SilverTransformTime6
-- ============================================================
--DROP TABLE IF EXISTS stg.silver_upsell_recommendations
CREATE TABLE IF NOT EXISTS stg.silver_upsell_recommendations (
    -- Order / session identity
    transactionheaderid         TEXT COLLATE pg_catalog."default",
    orderid                     TEXT COLLATE pg_catalog."default",
    ordersessionid              TEXT COLLATE pg_catalog."default",
    orderdateutc                TEXT COLLATE pg_catalog."default",
    businessdate                TEXT COLLATE pg_catalog."default",
    syscosmosts                 BIGINT,

    -- Location / kiosk
    locationid                  TEXT COLLATE pg_catalog."default",
    kioskid                     TEXT COLLATE pg_catalog."default",
    kiosk_name                  TEXT COLLATE pg_catalog."default",
    kiosk_mode                  INTEGER,
    is_test_order               BOOLEAN,

    -- Customer / identity
    frequentcustomerid              TEXT COLLATE pg_catalog."default",

    -- Upsell prompt
    recommendationid            TEXT COLLATE pg_catalog."default",
    prompttimestamp             TEXT COLLATE pg_catalog."default",
    modal_version               TEXT COLLATE pg_catalog."default",

    -- Offered and selected items
    offered_items               TEXT COLLATE pg_catalog."default",
    selected_items              TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status     TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath             TEXT COLLATE pg_catalog."default",
    silver_transform_time       TEXT COLLATE pg_catalog."default",
    silver_folderpath           TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_upsell_recommendations
    OWNER to citus;

-- ============================================================
-- 7. stg.silver_modifier_recommendation
--    Source sink: SilverModifierRecommendationsParquet
--    Branch: BronzeOrdersJson → ModifierRecommendations → SilverTransformTime7
--    Note: raw modifier_interactions + modifier_impressions arrays,
--          before the further unrolling that produces sinks 8 and 9.
-- ============================================================
--DROP TABLE IF EXISTS stg.silver_modifier_recommendations
CREATE TABLE IF NOT EXISTS stg.silver_modifier_recommendations (
    -- Order / session identity
    transactionheaderid         TEXT COLLATE pg_catalog."default",
    orderid                     TEXT COLLATE pg_catalog."default",
    ordersessionid              TEXT COLLATE pg_catalog."default",
    orderdateutc                TEXT COLLATE pg_catalog."default",
    businessdate                TEXT COLLATE pg_catalog."default",
    syscosmosts                 BIGINT,

    -- Location / kiosk
    locationid                  TEXT COLLATE pg_catalog."default",
    kioskid                     TEXT COLLATE pg_catalog."default",
    kiosk_name                  TEXT COLLATE pg_catalog."default",
    kiosk_mode                  INTEGER,
    is_test_order               BOOLEAN,

    -- Customer / identity
    frequentcustomerid              TEXT COLLATE pg_catalog."default",

    -- Raw nested arrays (not further unrolled in this sink)
    modifier_interactions       TEXT COLLATE pg_catalog."default",
    modifier_impressions        TEXT COLLATE pg_catalog."default",

    -- Order status
    order_completion_status     TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath             TEXT COLLATE pg_catalog."default",
    silver_transform_time       TEXT COLLATE pg_catalog."default",
    silver_folderpath           TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;


ALTER TABLE IF EXISTS stg.silver_modifier_recommendations
    OWNER to citus;

-- ============================================================
-- 8. stg.silver_modifier_interaction
--    Source sink: SilverModifierInteractionsParquet
--    Branch: ModifierRecommendations → ModifierInteractions → SilverTransformTime8
-- ============================================================
--DROP TABLE IF EXISTS stg.silver_modifier_interactions
CREATE TABLE IF NOT EXISTS stg.silver_modifier_interactions (
    -- Order / session identity
    transactionheaderid                     TEXT COLLATE pg_catalog."default",
    orderid                                 TEXT COLLATE pg_catalog."default",
    ordersessionid                          TEXT COLLATE pg_catalog."default",
    orderdateutc                            TEXT COLLATE pg_catalog."default",
    businessdate                            TEXT COLLATE pg_catalog."default",
    syscosmosts                             BIGINT,

    -- Location / kiosk
    locationid                              TEXT COLLATE pg_catalog."default",
    kioskid                                 TEXT COLLATE pg_catalog."default",
    kiosk_name                              TEXT COLLATE pg_catalog."default",
    kiosk_mode                              INTEGER,
    is_test_order                           BOOLEAN,

    -- Customer / identity
    frequentcustomerid              TEXT COLLATE pg_catalog."default",

    -- Interaction detail
    menuitemid                              TEXT COLLATE pg_catalog."default",
    modifierid                              TEXT COLLATE pg_catalog."default",
    modifiergroupid                         TEXT COLLATE pg_catalog."default",
    parent_modifier_id                      TEXT COLLATE pg_catalog."default",
    selection_type                          TEXT COLLATE pg_catalog."default",
    modifier_interactions_action            TEXT COLLATE pg_catalog."default",
    modifier_interactions_recorded_at       TEXT COLLATE pg_catalog."default",
    modifier_interactions_nesting_depth     INTEGER,

    -- Order status
    order_completion_status                 TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                         TEXT COLLATE pg_catalog."default",
    silver_transform_time                   TEXT COLLATE pg_catalog."default",
    silver_folderpath                       TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_modifier_interactions
    OWNER to citus;

-- ============================================================
-- 9. stg.silver_modifier_impression
--    Source sink: SilverModifierImpressionsParquet
--    Branch: ModifierRecommendations → ModifierImpressions
--            → ImpressionRecommendations → SilverTransformTime9
-- ============================================================
--DROP TABLE IF EXISTS stg.silver_modifier_impressions
CREATE TABLE IF NOT EXISTS stg.silver_modifier_impressions (
    -- Order / session identity
    transactionheaderid                     TEXT COLLATE pg_catalog."default",
    orderid                                 TEXT COLLATE pg_catalog."default",
    ordersessionid                          TEXT COLLATE pg_catalog."default",
    orderdateutc                            TEXT COLLATE pg_catalog."default",
    businessdate                            TEXT COLLATE pg_catalog."default",
    syscosmosts                             BIGINT,

    -- Location / kiosk
    locationid                              TEXT COLLATE pg_catalog."default",
    kioskid                                 TEXT COLLATE pg_catalog."default",
    kiosk_name                              TEXT COLLATE pg_catalog."default",
    kiosk_mode                              INTEGER,
    is_test_order                           BOOLEAN,

    -- Customer / identity
    frequentcustomerid              TEXT COLLATE pg_catalog."default",

    -- Impression context
    menuitemid                              TEXT COLLATE pg_catalog."default",
    parentmodifierid                        TEXT COLLATE pg_catalog."default",
    selection_type                          TEXT COLLATE pg_catalog."default",
    modifier_impressions_nesting_depth      INTEGER,
    modifier_impressions_context            TEXT COLLATE pg_catalog."default",
    strategy                                TEXT COLLATE pg_catalog."default",

    -- Recommendation row (unrolled from recommendations array)
    modifierid                              TEXT COLLATE pg_catalog."default",
    score                                   INTEGER,
    position                                INTEGER,
    selected                                BOOLEAN,
    pre_selected                            BOOLEAN,
    pre_deselected                          BOOLEAN,
    confirmed_removed                       BOOLEAN,

    -- Order status
    order_completion_status                 TEXT COLLATE pg_catalog."default",

    -- Lineage
    bronze_filepath                         TEXT COLLATE pg_catalog."default",
    silver_transform_time                   TEXT COLLATE pg_catalog."default",
    silver_folderpath                       TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_modifier_impressions
    OWNER to citus;


-- Table: fact.transactionrefunds

-- DROP TABLE IF EXISTS fact.transactionrefunds;

CREATE TABLE IF NOT EXISTS stg.silver_transaction_refunds
(
    locationid              TEXT COLLATE pg_catalog."default",
    transactionheaderid     TEXT COLLATE pg_catalog."default" NOT NULL,
    orderid                 TEXT COLLATE pg_catalog."default",
    original_transaction_id TEXT COLLATE pg_catalog."default",
    refund_transaction_id   TEXT COLLATE pg_catalog."default",
    refund_type             TEXT COLLATE pg_catalog."default",
    refunded_amount         NUMERIC(12,3),
    order_completion_status TEXT COLLATE pg_catalog."default",
    orderdateutc            TEXT COLLATE pg_catalog."default",
    syscosmosts             BIGINT,
    bronze_filepath         TEXT COLLATE pg_catalog."default",
    silver_transform_time   TEXT COLLATE pg_catalog."default",
    silver_folderpath       TEXT COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_transaction_refunds
    OWNER to citus;


-- ============================================================
-- stg.silver_kiosk_events
-- Source: KeepNecessaryCols1 → KioskEvents (nge + kiosk)
--         → SilverTransformTime1
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.silver_kiosk_events (
    -- Core event identity
    id                      TEXT COLLATE pg_catalog."default",
    application             TEXT COLLATE pg_catalog."default",
    companyid               TEXT COLLATE pg_catalog."default",           -- renamed from: company
    locationid              TEXT COLLATE pg_catalog."default",           -- renamed from: location
    eventmodule             TEXT COLLATE pg_catalog."default",           -- renamed from: module
    eventcategory           TEXT COLLATE pg_catalog."default",           -- renamed from: category
    eventtype               TEXT COLLATE pg_catalog."default",           -- renamed from: type
    severity                TEXT COLLATE pg_catalog."default",
    token                   TEXT COLLATE pg_catalog."default",

    -- Temporal
    eventinstant            TEXT COLLATE pg_catalog."default",    -- renamed from: instant

    -- User / device context
    username                TEXT COLLATE pg_catalog."default",
    userid                  TEXT COLLATE pg_catalog."default",
    device                  TEXT COLLATE pg_catalog."default",
    devicename              TEXT COLLATE pg_catalog."default",

    -- Payload
    summary                 TEXT COLLATE pg_catalog."default",
    data                    TEXT COLLATE pg_catalog."default",

    -- CosmosDB system fields (kept)
    syscosmosticks          BIGINT,         -- renamed from: ticks | cast via toLong()
    syscosmosts             BIGINT,        -- renamed from: _ts

    -- Silver layer metadata
    silver_transform_time   TEXT COLLATE pg_catalog."default",
    silver_folderpath       TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_kiosk_events
    OWNER to citus;


-- ============================================================
-- stg.silver_cep_incidents
-- Source: KeepNecessaryCols2 → ConnectorEvents
--         (nge + connector + critical + order + ordersubmitresponse)
--         → SilverTransformTime2
-- ============================================================
CREATE TABLE IF NOT EXISTS stg.silver_cep_incidents (
    -- Core event identity
    id                      TEXT COLLATE pg_catalog."default",
    application             TEXT COLLATE pg_catalog."default",
    companyid               TEXT COLLATE pg_catalog."default",
    locationid              TEXT COLLATE pg_catalog."default",
    eventmodule             TEXT COLLATE pg_catalog."default",
    eventcategory           TEXT COLLATE pg_catalog."default",
    eventtype               TEXT COLLATE pg_catalog."default",
    severity                TEXT COLLATE pg_catalog."default",
    token                   TEXT COLLATE pg_catalog."default",

    -- Temporal
    eventinstant            TEXT COLLATE pg_catalog."default",

    -- User / device context
    username                TEXT COLLATE pg_catalog."default",
    userid                  TEXT COLLATE pg_catalog."default",
    device                  TEXT COLLATE pg_catalog."default",
    devicename              TEXT COLLATE pg_catalog."default",

    -- Payload
    summary                 TEXT COLLATE pg_catalog."default",
    data                    TEXT COLLATE pg_catalog."default",

    -- CosmosDB system fields (kept)
    syscosmosticks          BIGINT,
    syscosmosts             BIGINT,

    -- Silver layer metadata
    silver_transform_time   TEXT COLLATE pg_catalog."default",
    silver_folderpath       TEXT COLLATE pg_catalog."default"
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_cep_incidents
    OWNER to citus;

