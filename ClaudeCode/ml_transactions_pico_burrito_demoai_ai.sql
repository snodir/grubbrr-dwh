--org-642556df-6d2c-42cc-81cc-83c1e490a458	GRUBBRR AI DEMO PICO BURRITO	loc-7e11383c-03a8-40bb-866e-ec596d780773	Pico Burrito Demo

CREATE TABLE IF NOT EXISTS ml.transactions
(
    frequentcustomerid text COLLATE pg_catalog."default",
    organizationid text COLLATE pg_catalog."default",
    organizationname text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    locationname text COLLATE pg_catalog."default",
    kioskid text COLLATE pg_catalog."default",
    transactionheaderid text COLLATE pg_catalog."default",
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    orderitemid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    itemname text COLLATE pg_catalog."default",
    upselllevel text COLLATE pg_catalog."default",
    item_class_type integer,
    itemquantity integer,
    categoryid text COLLATE pg_catalog."default",
    categoryname text COLLATE pg_catalog."default",
    itemunitprice numeric(12,3),
    paymentstatus text COLLATE pg_catalog."default",
    numberofitems integer,
    numberofpayments integer,
    ordertotal numeric(14,4),
    ordersubtotal numeric(14,4),
    ordertip numeric(14,4),
    ordertax numeric(14,4),
    ordertypelabel text COLLATE pg_catalog."default",
    orderdatelocal timestamp without time zone,
    businessdate date,
    weatherhumidity numeric(7,2),
    weathercondition text COLLATE pg_catalog."default",
    temperatureincelcius numeric(7,2),
    yyyy integer,
    mm integer,
    dd integer,
    hh integer,
    ww integer,
    sysinserttime timestamp without time zone
)

CREATE TABLE IF NOT EXISTS ml.transactions_pico_burrito_demo (
    locationid text COLLATE pg_catalog."default",
    frequentcustomerid text COLLATE pg_catalog."default",
    transactionheaderid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    itemname text COLLATE pg_catalog."default",
    item_class_type integer,
    itemquantity integer,
    itemunitprice numeric(12,3),
    numberofitems integer,
    ordersubtotal numeric(14,4),
    ordertypelabel text COLLATE pg_catalog."default",
    orderdatelocal timestamp without time zone,
    businessdate date,
    yyyy integer,
    mm integer,
    dd integer,
    hh integer,
    ww integer,
    yyww INTEGER,
    sysinserttime TIMESTAMP DEFAULT NOW() :: TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ml.transactions_square_trade_show_reg_env (
    locationid text COLLATE pg_catalog."default",
    frequentcustomerid text COLLATE pg_catalog."default",
    transactionheaderid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    itemname text COLLATE pg_catalog."default",
    item_class_type integer,
    itemquantity integer,
    itemunitprice numeric(12,3),
    numberofitems integer,
    ordersubtotal numeric(14,4),
    ordertypelabel text COLLATE pg_catalog."default",
    orderdatelocal timestamp without time zone,
    businessdate date,
    yyyy integer,
    mm integer,
    dd integer,
    hh integer,
    ww integer,
    yyww INTEGER,
    sysinserttime TIMESTAMP DEFAULT NOW() :: TIMESTAMP
);

--org-30b00f49-c9a7-462a-bc5f-c113f4fb8a77	Square Trade Show	loc-c896e94d-f5ee-4466-b4c0-399bbc287fb0	Square Trade
SELECT * FROM dim.frequentcustomer WHERE organizationid = 'org-30b00f49-c9a7-462a-bc5f-c113f4fb8a77'
SELECT DISTINCT locationid FROM ml.transactions_pico_burrito_demo;
SELECT DISTINCT businessdate FROM ml.transactions_pico_burrito_demo ORDER BY businessdate DESC;
SELECT * FROM ml.transactions_square_trade_show_reg_env 
--WHERE frequentcustomerid <> '' 
ORDER BY orderdatelocal DESC LIMIT 1000;
--SELECT DISTINCT organizationid, locationid FROM ml.transactions WHERE organizationid = 'org-642556df-6d2c-42cc-81cc-83c1e490a458'

INSERT INTO ml.transactions(
    frequentcustomerid,
    organizationid,
    organizationname,
    locationid,
    locationname,
    transactionheaderid,
    menuitemid,
    itemname,
    item_class_type,
    itemquantity,
    itemunitprice,
    numberofitems,
    ordertotal,
    ordersubtotal,
    ordertax,
    ordertypelabel,
    orderdatelocal,
    businessdate,
    yyyy,
    mm,
    dd,
    hh,
    ww,
    sysinserttime
)
SELECT pb.frequentcustomerid,
    ol.organizationid,
    ol.organizationname,
    pb.locationid,
    ol.locationname,
    CONCAT('ordevt-', SUBSTRING(transactionheaderid, 5, (LENGTH(transactionheaderid)))) AS transactionheaderid,
    pb.menuitemid,
    pb.itemname,
    pb.item_class_type,
    pb.itemquantity,
    pb.itemunitprice,
    pb.numberofitems,
    pb.ordersubtotal / 0.9         AS ordertotal,
    pb.ordersubtotal,
    pb.ordersubtotal / 9           AS ordertax,
    pb.ordertypelabel,
    pb.orderdatelocal :: TIMESTAMP AS orderdatelocal,
    pb.businessdate   :: DATE      AS businessdate,
    pb.yyyy           :: INTEGER   AS yyyy,
    pb.mm             :: INTEGER   AS mm,
    pb.dd             :: INTEGER   AS dd,
    pb.hh             :: INTEGER   AS hh,
    pb.ww             :: INTEGER   AS ww,
    pb.sysinserttime  :: TIMESTAMP AS sysinserttime
FROM ml.transactions_square_trade_show_reg_env as pb --pico_burrito_demo as pb 
INNER JOIN dim.organizationlocation as ol 
        ON ol.locationid = pb.locationid
       AND ol.organizationtype = 0;
--LIMIT 1000;






WITH order_level_data AS (
SELECT pb.locationid,
    --ol.locationname,
    MIN(frequentcustomerid) AS frequentcustomerid,
    CONCAT('ordevt-',  SUBSTRING(transactionheaderid, 5, LENGTH(transactionheaderid))) AS transactionheaderid,
    MAX(CONCAT('ord-', SUBSTRING(transactionheaderid, 5, LENGTH(transactionheaderid)))) AS orderid,
    MAX(SUBSTRING(transactionheaderid, 5, LENGTH(transactionheaderid))) as ordersessionid,
    MAX(pb.numberofitems) as numberofitems,
    ROUND(AVG(pb.ordersubtotal), 3) as ordersubtotal,
    MAX(pb.orderdatelocal :: TIMESTAMP) AS orderdatelocal,
    MAX(pb.businessdate   :: DATE)      AS businessdate,
    MAX(pb.sysinserttime  :: TIMESTAMP) AS sysinserttime
FROM ml.transactions_square_trade_show_reg_env as pb --pico_burrito_demo as pb 
GROUP BY locationid, CONCAT('ordevt-', SUBSTRING(transactionheaderid, 5, (LENGTH(transactionheaderid))))
)

INSERT INTO fact.transactionheader (
    id,
    locationid,
    transactionheaderid,
    frequentcustomerid,
    orderid,
    ordersessionid,
    orderstatus,
    paymentstatus,
    numberofitems,
    ordertotal,
    ordersubtotal,
    ordertax,
    orderdatelocal,
    dateid,
    businessdate,
    createddate
)
SELECT 
    nextval('fact.transactionheader_id_seq')           AS id,
    locationid,
    transactionheaderid,
    frequentcustomerid,
    orderid,
    ordersessionid,
    'order-placed' AS orderstatus,
    'Paid'         AS paymentstatus,
    numberofitems,
    ordersubtotal / 0.9                             AS ordertotal,
    ordersubtotal,
    ordersubtotal / 9                               AS ordertax,
    orderdatelocal,
    TO_CHAR(orderdatelocal, 'YYYYMMDDHH24') :: INTEGER AS dateid,
    businessdate,
    sysinserttime
FROM order_level_data;




INSERT INTO fact.transactionitem(
    frequentcustomerid,
    locationid,
    transactionheaderid,
    orderid,
    ordersessionid,
    itemid,
    itemname,
    itemsessionid,
    dimmenuitemid,
    menuitemid,
    itemquantity,
    itemunitprice,
    --numberofitems,
    itemtype,
    orderdatelocal,
    businessdate,
    sysinserttime
)
SELECT DISTINCT ON (transactionheaderid, menuitemid, itemname)
    pb.frequentcustomerid,
    pb.locationid,
    CONCAT('ordevt-', SUBSTRING(transactionheaderid, 5, (LENGTH(transactionheaderid)))) AS transactionheaderid,
    CONCAT('ord-', SUBSTRING(transactionheaderid, 5, LENGTH(transactionheaderid)))      AS orderid,
    SUBSTRING(transactionheaderid, 5, LENGTH(transactionheaderid))                      AS ordersessionid,
    CONCAT('orditm-', SUBSTRING(pb.menuitemid, 5, (LENGTH(pb.menuitemid))))             AS itemid,
    pb.itemname,
    CONCAT('itmses-', SUBSTRING(pb.menuitemid, 5, (LENGTH(pb.menuitemid))))              AS itemsessionid,
    pb.menuitemid                                                                       AS dimmenuitemid,
    mi.id                                                                               AS menuitemid,
    pb.itemquantity,
    pb.itemunitprice,
    --pb.numberofitems,
    'item' AS itemtype,
    pb.orderdatelocal :: TIMESTAMP AS orderdatelocal,
    pb.businessdate   :: DATE      AS businessdate,
    pb.sysinserttime  :: TIMESTAMP AS sysinserttime
FROM ml.transactions_square_trade_show_reg_env as pb --pico_burrito_demo as pb 
INNER JOIN dim.menuitem as mi 
        ON mi.menuitemid = pb.menuitemid
ORDER BY transactionheaderid, menuitemid, itemname, orderdatelocal DESC;


SELECT *
FROM ml.transactions_pico_burrito_demo
LIMIT 100;

SELECT locationid, transactionheaderid, ordertotal, ordersubtotal, ordersubtotal/ordertotal AS sub_to_total, ordertax/ordertotal as tax_to_total, ordertip/ordertotal as tip_to_total
FROM fact.transactionheader
WHERE 1=1
--AND locationid = 'loc-7e11383c-03a8-40bb-866e-ec596d780773'
AND orderstatus = 'order-placed'
LIMIT 100;

UPDATE fact.transactionheader
SET ordertotal = ordersubtotal / 0.9,
    ordertax   = ordersubtotal / 9
--SELECT * FROM fact.transactionheader
WHERE locationid = 'loc-7e11383c-03a8-40bb-866e-ec596d780773'
AND ordertotal IS NULL;

SELECT *
FROM fact.transactionitem
WHERE locationid = 'loc-7e11383c-03a8-40bb-866e-ec596d780773'
AND transactionheaderid LIKE 'ordevt-%'
AND frequentcustomerid IS NOT NULL 
AND frequentcustomerid <> ''
LIMIT 10000;

UPDATE fact.transactionheader
SET frequentcustomerid = ti.frequentcustomerid,
    updateddate        = NOW() :: TIMESTAMP
FROM fact.transactionitem as ti 
WHERE transactionheader.locationid          = 'loc-7e11383c-03a8-40bb-866e-ec596d780773'
  AND transactionheader.transactionheaderid = ti.transactionheaderid