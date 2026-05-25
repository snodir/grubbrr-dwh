-- ========
-- 1. Load fact.transactionheader
-- ========

SELECT max(orderdatelocal), max(createddate) FROM fact.transactionheader; --2026-05-21 15:00:03.193	2026-05-21 10:58:59.134653

SELECT *
FROM fact.transactionheader as th
WHERE th.createddate > '2026-05-21 10:58:59.134653' :: TIMESTAMP;

SELECT fact.parse_iso_timestamp(orderdateutc) :: TIMESTAMP as ts, 
    fact.parse_iso_timestamp(orderdateutc) AS string_ts,
    * 
FROM stg.silver_transaction_header as sth--
WHERE NOT EXISTS (SELECT 1 FROM fact.transactionheader as th 
                  WHERE th.locationid = sth.locationid 
                    AND th.transactionheaderid = sth.transactionheaderid)
  AND sth.is_test_order = False;

ALTER TABLE IF EXISTS stg.silver_transaction_header
OWNER TO citus,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;


SELECT * FROM stg.silver_kiosk_events WHERE token = '79EGW2F5UYYT7TBS';

--SELECT '2026-05-15T06:59:57.746922+00:00' :: TIMESTAMP

--CALL fact.usp_silver_transaction_header_to_fact();

SELECT * FROM stg.lookup_silver_transaction_header;

ALTER TABLE fact.transactionheader
ALTER COLUMN updateddate DROP NOT NULL,
ALTER COLUMN updateddate DROP DEFAULT;

CREATE TABLE IF NOT EXISTS stg.lookup_silver_transaction_header (
    id                      INTEGER,
    transactionheaderid     TEXT COLLATE pg_catalog."default",
    orderid                 TEXT COLLATE pg_catalog."default",
    locationid              TEXT COLLATE pg_catalog."default",
    kioskid                 TEXT COLLATE pg_catalog."default",
    ordersessionid          TEXT COLLATE pg_catalog."default",
    dateid                  INTEGER,
    orderdateutc            TEXT COLLATE pg_catalog."default",
    orderdatelocal          TIMESTAMP,
    orderstatus             TEXT COLLATE pg_catalog."default",
    ordertype               INTEGER,
    numberofitems           SMALLINT,
    numberofpayments        SMALLINT,
    ordersredeemedrewards   NUMERIC(12,3),
    ordersubtotal           NUMERIC(12,3),
    ordertotal              NUMERIC(12,3),
    ordertax                NUMERIC(12,3),
    ordertip                NUMERIC(12,3),
    orderdiscount           NUMERIC(12,3),
    orderbalance            NUMERIC(12,3),
    paymentstatus           TEXT COLLATE pg_catalog."default",
    sourcefile              TEXT COLLATE pg_catalog."default",
    createddate             TIMESTAMP,
    charityamount           NUMERIC(12,3),
    orderservicecharge      NUMERIC(12,3),
    businessdate            DATE,
    syscosmosts             BIGINT,
    channel                 TEXT COLLATE pg_catalog."default",
    guestcount              INTEGER,
    frequentcustomerid      TEXT COLLATE pg_catalog."default",
    customername            TEXT COLLATE pg_catalog."default",
    sysinserttime           TIMESTAMP,
) TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.lookup_silver_transaction_header
OWNER TO citus,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;


CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_header_to_fact()
LANGUAGE plpgsql
AS $BODY$

DECLARE v_max_id INTEGER;

BEGIN

SELECT MAX(id) INTO v_max_id FROM fact.transactionheader;

TRUNCATE TABLE stg.lookup_silver_transaction_header;


WITH delta_transactions AS (
SELECT
    transactionheaderid,
    orderid,
    locationid,
    kioskid,
    ordersessionid,
    fact.parse_iso_timestamp(orderdateutc) as orderdateutc,
    order_completion_status AS orderstatus,
    ordertype as ordertypeid,
    numberofitems,
    numberofpayments,
    usd_reward      :: NUMERIC(12,3) AS ordersredeemedrewards,
    usd_subtotal    :: NUMERIC(12,3) AS ordersubtotal,
    usd_amount      :: NUMERIC(12,3) AS ordertotal,
    usd_tax         :: NUMERIC(12,3) AS ordertax,
    usd_tip         :: NUMERIC(12,3) AS ordertip,          
    usd_discount    :: NUMERIC(12,3) AS orderdiscount,
    usd_charity_amount   :: NUMERIC(12,3) AS charityamount,
    usd_service_charge   :: NUMERIC(12,3) AS orderservicecharge,
    businessdate    :: DATE AS businessdate,
    CASE channel WHEN 0 THEN 'Kiosk' WHEN 1 THEN 'OnlineOrdering' ELSE 'External' END AS channel,
    guest_count AS guestcount,
    frequentcustomerid,
    customername,
    syscosmosts,                                            -- must be carried through for the ORDER BY below
    ROW_NUMBER() OVER(PARTITION BY locationid, transactionheaderid ORDER BY orderdateutc DESC) AS row_num
FROM stg.silver_transaction_header AS sth
WHERE is_test_order = False OR is_test_order IS NULL
), qualified_trxns AS (
SELECT
    dt.*,
    ot.id AS ordertype,
    dt.orderdateutc :: TIMESTAMPTZ AT TIME ZONE l.timezone AS orderdatelocal
FROM delta_transactions AS dt
LEFT JOIN dim.ordertype AS ot
    ON  dt.locationid  = ot.locationid
    AND dt.kioskid     = ot.kioskid
    AND dt.ordertypeid = ot.ordertypeid
LEFT JOIN dim.organization AS l  
    ON dt.locationid = l.id
WHERE dt.row_num = 1
)
INSERT INTO stg.lookup_silver_transaction_header
SELECT
    ROW_NUMBER() OVER (ORDER BY syscosmosts) + v_max_id AS id,
    transactionheaderid,
    orderid,
    locationid,
    kioskid,
    ordersessionid,
    CAST(TO_CHAR(orderdatelocal, 'YYYYMMDDHH24') AS INTEGER) AS dateid,
    orderdateutc,
    orderdatelocal,
    orderstatus,
    ordertype,
    numberofitems,
    numberofpayments,
    ordersredeemedrewards,
    ordersubtotal,
    ordertotal,
    ordertax,
    ordertip,                         
    orderdiscount,
    0.0 :: NUMERIC(12,3)               AS orderbalance,
    CASE WHEN numberofpayments > 0 THEN 'paid' END AS paymentstatus,
    'NGE'                              AS sourcefile,
    now() :: TIMESTAMP                 AS createddate,
    charityamount,
    orderservicecharge,
    businessdate,
    syscosmosts,
    channel,
    guestcount,
    frequentcustomerid,
    customername                       
FROM qualified_trxns;


-- Order Timing Fields 

DROP TABLE IF EXISTS temp_transaction_header;
CREATE TEMPORARY TABLE IF NOT EXISTS temp_transaction_header (
    id                      INTEGER,
    transactionheaderid     TEXT COLLATE pg_catalog."default",
    orderid                 TEXT COLLATE pg_catalog."default",
    locationid              TEXT COLLATE pg_catalog."default",
    kioskid                 TEXT COLLATE pg_catalog."default",
    ordersessionid          TEXT COLLATE pg_catalog."default",
    dateid                  INTEGER,
    orderdateutc            TEXT COLLATE pg_catalog."default",
    orderdatelocal          TIMESTAMP,
    orderstatus             TEXT COLLATE pg_catalog."default",
    ordertype               INTEGER,
    numberofitems           SMALLINT,
    numberofpayments        SMALLINT,
    ordersredeemedrewards   NUMERIC(12,3),
    ordersubtotal           NUMERIC(12,3),
    ordertotal              NUMERIC(12,3),
    ordertax                NUMERIC(12,3),
    ordertip                NUMERIC(12,3),
    orderdiscount           NUMERIC(12,3),
    orderbalance            NUMERIC(12,3),
    paymentstatus           TEXT COLLATE pg_catalog."default",
    sourcefile              TEXT COLLATE pg_catalog."default",
    createddate             TIMESTAMP,
    charityamount           NUMERIC(12,3),
    orderservicecharge      NUMERIC(12,3),
    businessdate            DATE,
    syscosmosts             BIGINT,
    channel                 TEXT COLLATE pg_catalog."default",
    guestcount              INTEGER,
    frequentcustomerid      TEXT COLLATE pg_catalog."default",
    customername            TEXT COLLATE pg_catalog."default"
);

INSERT INTO temp_transaction_header
SELECT * FROM stg.lookup_silver_transaction_header AS sth
WHERE NOT EXISTS (
                    SELECT 1
                    FROM fact.transactionheader AS th
                    WHERE th.locationid          = sth.locationid
                      AND th.transactionheaderid = sth.transactionheaderid
                );

IF EXISTS (SELECT 1 FROM temp_transaction_header)
THEN

    WITH aggregated_kiosk_events AS (

    SELECT ke.locationid, ke.token,
        min(CASE WHEN lower(ke.eventcategory) = 'session' AND lower (ke.eventtype) = 'started' THEN eventinstant END) AS orderstarttime,
        min(CASE WHEN lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'revieworderclicked' THEN eventinstant END) AS reviewordertime,
        min(CASE WHEN lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'checkoutclicked' THEN eventinstant END) AS checkouttime,
        min(CASE WHEN lower(ke.eventcategory) = 'payment' AND lower (ke.eventtype) = 'create' THEN eventinstant END) AS paystarttime,
        max(CASE WHEN lower(ke.eventcategory) IN ('session','order') AND lower(ke.eventtype) = 'closed' THEN eventinstant END) AS sessionendtime
    FROM stg.silver_kiosk_events as ke 
    WHERE((lower(ke.eventcategory) = 'session' AND lower (ke.eventtype) = 'started') OR 
        (lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'revieworderclicked') OR 
        (lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'checkoutclicked') OR 
        (lower(ke.eventcategory) = 'payment' AND lower (ke.eventtype) = 'create') OR  
        (lower(ke.eventcategory) IN ('session','order') AND lower(ke.eventtype) = 'closed'))
    AND lower(ke.severity) = 'information'
    GROUP BY ke.locationid, ke.token

    ), orders_enriched_with_ordertiming_fields AS (
    SELECT tth.*,
        fact.parse_iso_timestamp(orderstarttime) :: TIMESTAMP as orderstarttime,
        fact.parse_iso_timestamp(reviewordertime) :: TIMESTAMP as reviewordertime,
        fact.parse_iso_timestamp(checkouttime) :: TIMESTAMP as checkouttime,
        fact.parse_iso_timestamp(paystarttime) :: TIMESTAMP as paystarttime,
        fact.parse_iso_timestamp(sessionendtime) :: TIMESTAMP as sessionendtime
    FROM temp_transaction_header as tth 
    LEFT JOIN aggregated_kiosk_events as ke 
        ON ke.locationid = tth.locationid
        AND ke.token     = tth.ordersessionid
    )
    INSERT INTO fact.transactionheader(
        id,
        transactionheaderid,
        orderid,
        locationid,
        kioskid,
        ordersessionid,
        dateid,
        orderdateutc,
        orderdatelocal,
        orderstatus,
        ordertype,
        numberofitems,
        numberofpayments,
        ordersredeemedrewards,
        ordersubtotal,
        ordertotal,
        ordertax,
        ordertip,
        orderdiscount,
        orderbalance,
        paymentstatus,
        sourcefile,
        createddate,
        updateddate,
        orderstarttime,
        reviewordertime,
        checkouttime,
        paystarttime,
        sessionendtime,
        precheckouttime,
        postcheckouttime,
        menupagetime,
        reviewpagetime,
        paymentpagetime,
        totalordertime,
        businessdate,
        frequentcustomerid,
        abtestid,
        channel,
        guestcount,
        charityamount,
        syscosmosts,
        sourceid,
        orderservicecharge,
        customername
    )
    SELECT 
        id,
        transactionheaderid,
        orderid,
        locationid,
        kioskid,
        ordersessionid,
        dateid,
        orderdateutc,
        orderdatelocal,
        orderstatus,
        ordertype,
        numberofitems,
        numberofpayments,
        ordersredeemedrewards,
        ordersubtotal,
        ordertotal,
        ordertax,
        ordertip,
        orderdiscount,
        orderbalance,
        paymentstatus,
        sourcefile,
        createddate,
        NULL :: TIMESTAMP AS updateddate,
        orderstarttime,
        reviewordertime,
        checkouttime,
        paystarttime,
        sessionendtime,
        EXTRACT(EPOCH FROM (checkouttime - orderstarttime)) AS precheckouttime,
        EXTRACT(EPOCH FROM (sessionendtime - checkouttime)) AS postcheckouttime,
        EXTRACT(EPOCH FROM (reviewordertime - orderstarttime)) AS menupagetime,
        EXTRACT(EPOCH FROM (checkouttime - reviewordertime)) AS reviewpagetime,
        EXTRACT(EPOCH FROM (sessionendtime - paystarttime)) AS paymentpagetime,
        EXTRACT(EPOCH FROM (sessionendtime - orderstarttime)) AS totalordertime,
        businessdate,
        frequentcustomerid,
        NULL :: BIGINT AS abtestid,
        channel,
        guestcount,
        charityamount,
        syscosmosts,
        1 :: INTEGER AS sourceid,
        orderservicecharge,
        customername
    FROM orders_enriched_with_ordertiming_fields;

END IF;

DROP TABLE IF EXISTS temp_transaction_header;

END;
$BODY$;  

ALTER PROCEDURE fact.usp_silver_transaction_header_to_fact()
    OWNER TO citus;



SELECT * FROM dim.grubbrr_source_lookup

SELECT ke.companyid,
    th.locationid,
    th.transactionheaderid,
    th.orderid,
    th.ordersessionid,
    th.businessdate,
    th.kioskid,
    th.kiosk_mode,
    th.is_test_order,
    ke.application,
    ke.eventmodule,
    ke.eventcategory,
    ke.eventtype,
    ke.eventinstant,
    th.orderdateutc
FROM stg.silver_kiosk_events as ke 
INNER JOIN stg.silver_transaction_header as th 
    ON ke.locationid = th.locationid
    AND ke.token = th.ordersessionid
WHERE th.ordersessionid = '79EGW2F5UYYT7TBS'
ORDER BY ke.syscosmosticks;

SELECT ke.locationid, ke.token, --ke.eventcategory, ke.eventtype,
    min(CASE WHEN lower(ke.eventcategory) = 'session' AND lower (ke.eventtype) = 'started' THEN eventinstant END) AS session_started,
    min(CASE WHEN lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'revieworderclicked' THEN eventinstant END) AS review_order_clicked,
    min(CASE WHEN lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'checkoutclicked' THEN eventinstant END) AS checkout_clicked,
    min(CASE WHEN lower(ke.eventcategory) = 'payment' AND lower (ke.eventtype) = 'create' THEN eventinstant END) AS payment_create,
    max(CASE WHEN lower(ke.eventcategory) IN ('session','order') AND lower(ke.eventtype) = 'closed' THEN eventinstant END) AS order_session_closed
FROM stg.silver_kiosk_events as ke 
WHERE 1=1
AND ke.token = '79EGW2F5UYYT7TBS'
AND ((lower(ke.eventcategory) = 'session' AND lower (ke.eventtype) = 'started') OR 
     (lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'revieworderclicked') OR 
     (lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'checkoutclicked') OR 
     (lower(ke.eventcategory) = 'payment' AND lower (ke.eventtype) = 'create') OR  
     (lower(ke.eventcategory) IN ('session','order') AND lower(ke.eventtype) = 'closed'))
AND lower(ke.severity) = 'information'
GROUP BY ke.locationid, ke.token--, ke.eventcategory, ke.eventtype
ORDER BY session_started;