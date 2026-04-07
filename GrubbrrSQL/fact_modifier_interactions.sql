/*fact.modifier_interactions*/

SELECT * FROM fact.modifier_interactions LIMIT 1000;
SELECT * FROM fact.itemmodifier LIMIT 1000;

CREATE TABLE IF NOT EXISTS fact.modifier_interactions
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    orderitemid text COLLATE pg_catalog."default" NOT NULL,
    menuitemid text COLLATE pg_catalog."default",
    modifiergroupid text COLLATE pg_catalog."default" NOT NULL,
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    modifiername text COLLATE pg_catalog."default",
    modifierquantity smallint,
    modifierprice numeric(12,3),
    freequantity integer,
    selectiontype text COLLATE pg_catalog."default",
    action text COLLATE pg_catalog."default",
    businessdate date,
    orderdatelocal timestamp,
    frequentcustomerid text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT trxnid_itemid_modfrgrpid_modfrid_pk PRIMARY KEY (transactionheaderid, orderitemid, modifiergroupid, modifierid)
);

ALTER TABLE fact.modifier_interactions
OWNER to citus;

WITH modfr_trxn AS (
    SELECT ti.locationid,
           im.transactionheaderid,
           ti.ordersessionid,
           im.orderid,
           im.itemid as orderitemid,
           ti.dimmenuitemid as menuitemid,
           im.modifiergroupid,
           im.modifierid,
           im.modifiername,
           im.modifierquantity,
           im.modifierprice,
           im.freequantity,
           NULL :: TEXT as selectiontype,
           NULL :: TEXT as action,
           ti.businessdate,
           ti.orderdatelocal,
           th.frequentcustomerid,
           im.sysinserttime,
           im.sysupdatetime
    FROM fact.itemmodifier as im 
    INNER JOIN fact.transactionitem as ti
            ON im.transactionheaderid = ti.transactionheaderid
           AND im.itemid = ti.itemid
    INNER JOIN fact.transactionheader as th
            ON ti.locationid = th.locationid
           AND ti.transactionheaderid = th.transactionheaderid
)
INSERT INTO fact.modifier_interactions
SELECT * FROM modfr_trxn;


CREATE TABLE IF NOT EXISTS fact.itemmodifier
(
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    orderid text COLLATE pg_catalog."default" NOT NULL,
    itemid text COLLATE pg_catalog."default" NOT NULL,
    modifiergroupid text COLLATE pg_catalog."default" NOT NULL,
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    modifiername text COLLATE pg_catalog."default",
    modifierquantity smallint NOT NULL DEFAULT 1,
    modifierprice numeric(12,3),
    freequantity integer,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY KEY (transactionheaderid, itemid, modifiergroupid, modifierid)
)

TABLESPACE pg_default;

ALTER TABLE fact.itemmodifier
    OWNER to citus;

-- Index: fact.itemmodifieridx
CREATE INDEX IF NOT EXISTS itemmodifieridx
    ON fact.itemmodifier USING btree
    (itemid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
-- Index: fact.transactionheaderid_idx
CREATE INDEX IF NOT EXISTS transactionheaderid_idx
    ON fact.itemmodifier USING btree
    (transactionheaderid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


