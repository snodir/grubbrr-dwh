/*fact.modifier_interactions*/

SELECT * FROM fact.modifier_interactions LIMIT 1000;
SELECT * FROM fact.itemmodifier LIMIT 1000;

CREATE TABLE IF NOT EXISTS fact.modifier_interactions
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    orderitemid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    modifiergroupid text COLLATE pg_catalog."default" NOT NULL,
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    modifiername text COLLATE pg_catalog."default",
    parent_modifier_id text COLLATE pg_catalog."default",
    nesting_depth INTEGER,
    modifierquantity INTEGER,
    modifierprice numeric(12,3),
    freequantity integer,
    selection_type text COLLATE pg_catalog."default",
    action text COLLATE pg_catalog."default",
    session_recorded_at text COLLATE pg_catalog."default",
    businessdate date,
    orderdatelocal timestamp,
    frequentcustomerid text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT trxnid_menuitemid_modfrgrpid_modfrid_pk PRIMARY KEY (transactionheaderid, menuitemid, modifiergroupid, modifierid)
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

ALTER TABLE fact.itemmodifier
ADD COLUMN IF NOT EXISTS locationid text COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS businessdate DATE,
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT;

ALTER TABLE fact.transactionitem
ADD COLUMN IF NOT EXISTS orderdatelocal TIMESTAMP,
ADD COLUMN IF NOT EXISTS businessdate DATE,
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT,
ADD COLUMN IF NOT EXISTS frequentcustomerid text COLLATE pg_catalog."default";

--CALL fact.usp_update_transaction_item_and_modifier_fields();
SET work_mem = '256MB'
SHOW work_mem;


CREATE OR REPLACE PROCEDURE fact.usp_update_transaction_item_and_modifier_fields()
LANGUAGE plpgsql
AS $BODY$

BEGIN

UPDATE fact.transactionitem
SET orderdatelocal = th.orderdatelocal,
    businessdate = th.businessdate,
    syscosmosts = th.syscosmosts,
    frequentcustomerid = th.frequentcustomerid
FROM fact.transactionheader as th
WHERE transactionitem.locationid = th.locationid
  AND transactionitem.transactionheaderid = th.transactionheaderid
  AND transactionitem.orderdatelocal IS NULL;

--SELECT count(1) FROM fact.transactionitem WHERE businessdate IS NULL

END;
$BODY$;

UPDATE fact.itemmodifier
SET locationid = ti.locationid,
    businessdate = ti.businessdate,
    syscosmosts = ti.syscosmosts
FROM fact.transactionitem as ti 
WHERE itemmodifier.transactionheaderid = ti.transactionheaderid
  AND itemmodifier.itemid = ti.itemid
  AND itemmodifier.locationid IS NULL;


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


