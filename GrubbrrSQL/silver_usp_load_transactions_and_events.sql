-- ========
-- 1. Load fact.transactionheader
-- ========

SELECT * FROM stg.silver_transaction_header WHERE ordersessionid = '79EGW2F5UYYT7TBS';

CREATE OR REPLACE PROCEDURE fact.usp_silver_to_fact_transaction_header()
LANGUAGE plpgsql
AS $BODY$
BEGIN

WITH delta_transactions AS (
SELECT
    transactionheaderid,
    orderid,
    locationid,
    kioskid,
    ordersessionid,
    CASE WHEN substring(orderdateutc, 20, 1) = '.' 
         THEN replace(replace(substring(orderdateutc, 1, 23), 'T', ' '), '+', '0') 
         ELSE replace(substring(orderdateutc, 1, 19), 'T', ' ') 
    END as orderdateutc,
    order_completion_status AS orderstatus,
    ordertype as ordertypeid,
    --ordertypelabel,
    usd_reward :: NUMERIC(12,3) AS ordersredeemedrewards,
    usd_subtotal :: NUMERIC(12,3) AS ordersubtotal,
    usd_amount :: NUMERIC(12,3) AS ordertotal,
    usd_tax :: NUMERIC(12,3) AS ordertax,
    usd_tip :: NUMERIC(12,3) AS ordertip,
    usd_discount :: NUMERIC(12,3) AS orderdiscount,
    usd_charity_amount :: NUMERIC(12,3) as charityamount,
    usd_service_charge :: NUMERIC(12,3) as orderservicecharge,
    substring(businessdate, 1, 10) :: TEXT as businessdate,
    CASE channel WHEN 0 THEN 'Kiosk' WHEN 1 THEN 'OnlineOrdering' ELSE 'External' END AS channel,
    guest_count as guestcount,
    frequentcustomerid,
    customername,
    ROW_NUMBER() OVER(PARTITION BY locationid, transactionheaderid ORDER BY orderdateutc DESC) as row_num
FROM stg.silver_transaction_header
WHERE is_test_order = False OR is_test_order IS NULL
), qualified_trxns AS (
SELECT dt.*, 
    ot.id as ordertype,
    dt.orderdateutc :: TIMESTAMPTZ AT TIME ZONE l.timezone AS orderdatelocal
FROM delta_transactions as dt
LEFT JOIN dim.ordertype as ot 
    ON dt.locationid = ot.locationid
    AND dt.kioskid = ot.kioskid
    AND dt.ordertypeid = ot.ordertypeid
LEFT JOIN dim.location as l 
    ON dt.locationid = l.locationid
WHERE row_num = 1
AND NOT EXISTS (SELECT 1 FROM fact.transactionheader as th
                WHERE dt.locationid = th.locationid
                  AND dt.transactionheaderid = th.transactionheaderid)
)
SELECT ROW_NUMBER() OVER(ORDER BY syscosmosts) + (SELECT max(id) FROM fact.transactionheader) AS id,
    transactionheaderid,
    orderid,
    locationid,
    kioskid,
    ordersessionid,
    CAST(TO_CHAR(orderdatelocal, 'YYYYMMDDHH24') as INTEGER) AS dateid,
    orderdateutc,
    orderdatelocal,
    orderstatus,
    ordertype,
    ordersredeemedrewards,
    ordersubtotal,
    ordertotal,
    ordertax,
    orderdiscount,
    charityamount,
    orderservicecharge,
    businessdate,
    channel,
    guestcount,
    frequentcustomerid,
    customername,
    now() :: TIMESTAMP AS createddate
FROM qualified_trxns  

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