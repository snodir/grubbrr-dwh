--Schema(Column structure) changed
--drop table if EXISTS fact.transactionitem;
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
    itemunitprice numeric(7,3),
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
    dateid integer,
    orderdateutc text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT transactionitem_pkey PRIMARY KEY (transactionheaderid, itemid, itemname)
)

TABLESPACE pg_default;

ALTER TABLE fact.transactionitem
    OWNER to citus;


-- Index: fact.idx_transactionitem_headerid
CREATE INDEX IF NOT EXISTS idx_transactionitem_headerid
    ON fact.transactionitem USING btree
    (transactionheaderid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

