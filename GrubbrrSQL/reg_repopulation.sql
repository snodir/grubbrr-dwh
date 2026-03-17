--drop table if EXISTS fact.transactionheader;
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
    ordersredeemedrewards numeric(7,3),
    ordersubtotal numeric(7,3),
    ordertotal numeric(7,3),
    ordertax numeric(7,3),
    ordertip numeric(7,3),
    orderdiscount numeric(7,3),
    orderbalance numeric(7,3),
    paymentstatus text COLLATE pg_catalog."default",
    sourcefile text COLLATE pg_catalog."default" NOT NULL DEFAULT 'NGE'::text,
    createddate timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updateddate timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
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
    --CONSTRAINT transactionheader_bkp_pkey PRIMARY KEY (transactionheaderid, id),
    CONSTRAINT transactionheader_pkey PRIMARY KEY (locationid, transactionheaderid)
)

TABLESPACE pg_default;

ALTER TABLE fact.transactionheader
    OWNER to citus;

-- Index: fact.transactionheader_locationid_dateid_idx
CREATE INDEX IF NOT EXISTS transactionheader_locationid_dateid_idx
    ON fact.transactionheader USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(orderstatus, ordertype, businessdate)
    TABLESPACE pg_default;

select * from dim.location
select * from fact.transactionheader order by id
select * from fact.transactionitem;
select * from dim.kiosk
select * from fact.transactionpayment;
select * from fact.itemmodifier;
select * from fact.userbehaviour;
select * from fact.watermarktable;
select * from dim.element;
select * from dim.view;
select * from fact.usercheckedin;
select * from fact.deviceevent;
select * from fact.devicestate order by id limit 1000;
select * from fact.devicetelemetry;
select * from dim.occasionsurvey;
select * from fact.itemssurvey;
select * from fact.occasionsurveydetail;
select * from dim.organizationlocation;
select * from dim.userlocation;


/*TRUNCATE table fact.transactionpayment;
TRUNCATE table fact.itemmodifier;
TRUNCATE table fact.userbehaviour;
TRUNCATE table fact.devicestate;
TRUNCATE table fact.devicetelemetry;
TRUNCATE table fact.userbehaviour;
TRUNCATE table fact.usercheckedin;
TRUNCATE table fact.deviceevent;

/*TRUNCATE table "dim"."company";
--TRUNCATE table "dim"."datedim"
TRUNCATE table "dim"."element";
TRUNCATE table "dim"."itemcategory";
TRUNCATE table "dim"."kiosk";
TRUNCATE table "dim"."location";
TRUNCATE table "dim"."locationgroup";
TRUNCATE table "dim"."menuitem";
TRUNCATE table "dim"."occasionsurvey";
TRUNCATE table "dim"."ordertype";
TRUNCATE table "dim"."organization";
TRUNCATE table "dim"."organizationgeography";
TRUNCATE table "dim"."organizationlocation";
TRUNCATE table "dim"."organizationparent";
TRUNCATE table "dim"."userlocation"; 
TRUNCATE table "dim"."view"*/

SELECT * from dim.datedim