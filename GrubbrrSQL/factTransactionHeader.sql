--Schema (Column structure) changed
--drop table if EXISTS fact.transactionheader;
CREATE TABLE IF NOT EXISTS fact.transactionheader
(
    id bigint NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    orderid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
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
    CONSTRAINT transactionheader_pkey PRIMARY KEY (transactionheaderid, id)
)

TABLESPACE pg_default;

ALTER TABLE fact.transactionheader
    OWNER to citus;
