SELECT * FROM stg.silver_kiosk_events as ke
WHERE ke.eventcategory IN ('Order', 'insight')
  AND ke.eventtype     IN ('Cancelled', 'OrderCancelled', 'Abandoned', 'Exception')


-- PROCEDURE: fact.usp_gem_aborted_orders_to_fact()
--
-- Writes aborted/cancelled/abandoned/exception order events from
-- stg.silver_kiosk_events into:
--   fact.transactionheader  (sourceid = 2, transactionheaderid = 'abort-' + id)
--   fact.transactionitem    (one placeholder stub row per aborted order)
--
-- Source filter:
--   eventcategory IN ('Order', 'insight')
--   eventtype     IN ('Cancelled', 'OrderCancelled', 'Abandoned', 'Exception')

-- DROP PROCEDURE IF EXISTS fact.usp_gem_aborted_orders_to_fact();

CREATE OR REPLACE PROCEDURE fact.usp_silver_aborted_orders_and_items_to_fact()
LANGUAGE 'plpgsql'
AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'gem';


    -- ----------------------------------------------------------------
    -- Stage the aborted order delta into a temp table so both the
    -- header INSERT and the item INSERT share the same result without
    -- repeating the dedup + filter logic.
    --
    -- DISTINCT ON (locationid, token) ordered by syscosmosts DESC keeps
    -- the latest event per session — mirrors ADF ROW_NUMBER() OVER
    -- (PARTITION BY location, token ORDER BY id DESC) filtered to rn = 1.
    -- ----------------------------------------------------------------
    DROP TABLE IF EXISTS temp_aborted_delta;
    CREATE TEMPORARY TABLE temp_aborted_delta AS
    SELECT DISTINCT ON (ke.locationid, ke.token)
        ke.id,
        CONCAT('abort-', ke.id)                                          AS transactionheaderid,
        ke.locationid,
        ke.device                                                        AS kioskid,
        ke.token                                                         AS ordersessionid,
        -- orderid: 'ord-' + order.sessionId from data JSON
        -- fallback to token if sessionId is absent
        CONCAT('ord-',
            COALESCE(
                NULLIF(ke.data :: jsonb -> 'order' ->> 'sessionId', ''),
                ke.token
            )
        )                                                                AS orderid,
        -- itemsessionid: raw sessionId without 'ord-' prefix
        -- mirrors ADF select2: itemsessionid = itemsessionid.order.sessionId
        COALESCE(
            NULLIF(ke.data :: jsonb -> 'order' ->> 'sessionId', ''),
            ke.token
        )                                                                AS itemsessionid,
        -- orderstatus: mirrors ADF case(exception → Abandoned, ordercancelled → Cancelled)
        CASE LOWER(ke.eventtype)
            WHEN 'exception'      THEN 'Abandoned'
            WHEN 'ordercancelled' THEN 'Cancelled'
            ELSE ke.eventtype
        END                                                              AS orderstatus,
        -- channel: extracted from data JSON via LIKE pattern
        -- mirrors ADF: case(like(data,'%"channel":0%'), 'Kiosk', ...)
        CASE
            WHEN ke.data LIKE '%"channel":0%' THEN 'Kiosk'
            WHEN ke.data LIKE '%"channel":1%' THEN 'OnlineOrdering'
            WHEN ke.data LIKE '%"channel":2%' THEN 'External'
            ELSE 'Kiosk'
        END                                                              AS channel,
        fact.parse_iso_timestamp(ke.eventinstant)                        AS orderdateutc,
        ke.syscosmosts
    FROM stg.silver_kiosk_events AS ke
    -- Real kiosk filter — mirrors ADF EXISTS against dim.kiosk WHERE istestkiosk = False
    INNER JOIN dim.kiosk AS dk
        ON  dk.kioskid     = ke.device
        AND dk.istestkiosk = false
    WHERE ke.eventcategory IN ('Order', 'insight')
      AND ke.eventtype     IN ('Cancelled', 'OrderCancelled', 'Abandoned', 'Exception')
      AND ke.syscosmosts   > v_max_syscosmosts
      -- Skip sessions already written as aborted orders
      AND NOT EXISTS (
          SELECT 1 FROM fact.transactionheader AS th
          WHERE th.locationid          = ke.locationid
            AND th.transactionheaderid = CONCAT('abort-', ke.id)
      )
    ORDER BY ke.locationid, ke.token, ke.syscosmosts DESC;


    -- ----------------------------------------------------------------
    -- INSERT fact.transactionheader
    --
    -- Session timing scoped to sessions in the current delta batch —
    -- avoids a full scan of silver_kiosk_events on every run.
    -- Same event filter pattern as usp_silver_transaction_header_to_fact.
    -- ----------------------------------------------------------------
    WITH session_timing AS (

        SELECT
            ke.locationid,
            ke.token,
            MIN(CASE WHEN LOWER(ke.eventcategory) = 'session'
                          AND LOWER(ke.eventtype)  = 'started'
                     THEN ke.eventinstant END)                           AS orderstarttime,
            MIN(CASE WHEN LOWER(ke.eventcategory) IN ('order', 'insight')
                          AND LOWER(ke.eventtype)  = 'revieworderclicked'
                     THEN ke.eventinstant END)                           AS reviewordertime,
            MIN(CASE WHEN LOWER(ke.eventcategory) IN ('order', 'insight')
                          AND LOWER(ke.eventtype)  = 'checkoutclicked'
                     THEN ke.eventinstant END)                           AS checkouttime,
            MIN(CASE WHEN LOWER(ke.eventcategory) = 'payment'
                          AND LOWER(ke.eventtype)  = 'create'
                     THEN ke.eventinstant END)                           AS paystarttime,
            MAX(CASE WHEN LOWER(ke.eventcategory) IN ('session', 'order')
                          AND LOWER(ke.eventtype)  = 'closed'
                     THEN ke.eventinstant END)                           AS sessionendtime
        FROM stg.silver_kiosk_events AS ke
        INNER JOIN temp_aborted_delta AS ad
            ON  ad.locationid     = ke.locationid
            AND ad.ordersessionid = ke.token
        WHERE LOWER(ke.severity) = 'information'
          AND (
                (LOWER(ke.eventcategory) = 'session'             AND LOWER(ke.eventtype) = 'started')            OR
                (LOWER(ke.eventcategory) IN ('order', 'insight') AND LOWER(ke.eventtype) = 'revieworderclicked') OR
                (LOWER(ke.eventcategory) IN ('order', 'insight') AND LOWER(ke.eventtype) = 'checkoutclicked')    OR
                (LOWER(ke.eventcategory) = 'payment'             AND LOWER(ke.eventtype) = 'create')             OR
                (LOWER(ke.eventcategory) IN ('session', 'order') AND LOWER(ke.eventtype) = 'closed')
              )
        GROUP BY ke.locationid, ke.token

    )
    INSERT INTO fact.transactionheader (
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
        channel,
        syscosmosts,
        sourceid
    )
    SELECT
        nextval('fact.transactionheader_id_seq')                                        AS id,
        ad.transactionheaderid,
        ad.orderid,
        ad.locationid,
        ad.kioskid,
        ad.ordersessionid,
        CAST(TO_CHAR(
            (ad.orderdateutc :: TIMESTAMPTZ AT TIME ZONE org.timezone) :: TIMESTAMP,
            'YYYYMMDDHH24'
        ) AS INTEGER)                                                                   AS dateid,
        ad.orderdateutc,
        (ad.orderdateutc :: TIMESTAMPTZ AT TIME ZONE org.timezone) :: TIMESTAMP        AS orderdatelocal,
        ad.orderstatus,
        0 :: SMALLINT                                                                   AS numberofitems,
        0 :: SMALLINT                                                                   AS numberofpayments,
        0.000 :: NUMERIC(12,3)                                                         AS ordersredeemedrewards,
        0.000 :: NUMERIC(12,3)                                                         AS ordersubtotal,
        0.000 :: NUMERIC(12,3)                                                         AS ordertotal,
        0.000 :: NUMERIC(12,3)                                                         AS ordertax,
        0.000 :: NUMERIC(12,3)                                                         AS ordertip,
        0.000 :: NUMERIC(12,3)                                                         AS orderdiscount,
        0.000 :: NUMERIC(12,3)                                                         AS orderbalance,
        'None'                                                                          AS paymentstatus,
        'NGE'                                                                           AS sourcefile,
        now() :: TIMESTAMP                                                              AS createddate,
        fact.parse_iso_timestamp(st.orderstarttime)  :: TIMESTAMP                      AS orderstarttime,
        fact.parse_iso_timestamp(st.reviewordertime) :: TIMESTAMP                      AS reviewordertime,
        fact.parse_iso_timestamp(st.checkouttime)    :: TIMESTAMP                      AS checkouttime,
        fact.parse_iso_timestamp(st.paystarttime)    :: TIMESTAMP                      AS paystarttime,
        fact.parse_iso_timestamp(st.sessionendtime)  :: TIMESTAMP                      AS sessionendtime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.checkouttime) :: TIMESTAMP    - fact.parse_iso_timestamp(st.orderstarttime) :: TIMESTAMP
        ))                                                                              AS precheckouttime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.sessionendtime) :: TIMESTAMP  - fact.parse_iso_timestamp(st.checkouttime) :: TIMESTAMP
        ))                                                                              AS postcheckouttime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.reviewordertime) :: TIMESTAMP - fact.parse_iso_timestamp(st.orderstarttime) :: TIMESTAMP
        ))                                                                              AS menupagetime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.checkouttime) :: TIMESTAMP    - fact.parse_iso_timestamp(st.reviewordertime) :: TIMESTAMP
        ))                                                                              AS reviewpagetime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.sessionendtime) :: TIMESTAMP - fact.parse_iso_timestamp(st.paystarttime) :: TIMESTAMP
        ))                                                                              AS paymentpagetime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.sessionendtime) :: TIMESTAMP  - fact.parse_iso_timestamp(st.orderstarttime) :: TIMESTAMP
        ))                                                                              AS totalordertime,
        ad.channel,
        ad.syscosmosts,
        2                                                                               AS sourceid
    FROM temp_aborted_delta AS ad
    LEFT JOIN session_timing AS st
        ON  st.locationid = ad.locationid
        AND st.token      = ad.ordersessionid
    LEFT JOIN dim.organization AS org
        ON  org.id = ad.locationid
    ON CONFLICT (locationid, transactionheaderid)
    DO NOTHING;


    -- ----------------------------------------------------------------
    -- INSERT fact.transactionitem — placeholder stub per aborted order
    --
    -- Mirrors ADF WriteToItems: one fixed row per aborted order with
    -- itemid = 'itemid' and itemname = 'itemname' as placeholders.
    -- PK (transactionheaderid, itemid, itemname) guarantees exactly
    -- one stub row regardless of reruns.
    -- ----------------------------------------------------------------
    INSERT INTO fact.transactionitem (
        transactionheaderid,
        itemid,
        itemsessionid,
        itemname,
        itemquantity,
        itemunitprice,
        upselllevel,
        upsellpromptitemid,
        orderid,
        ordersessionid,
        orderdateutc,
        sysinserttime,
        locationid
    )
    SELECT
        ad.transactionheaderid,
        'itemid'                AS itemid,
        ad.itemsessionid,
        'itemname'              AS itemname,
        0 :: SMALLINT           AS itemquantity,
        0.000 :: NUMERIC(12,3)  AS itemunitprice,
        ''                      AS upselllevel,
        ''                      AS upsellpromptitemid,
        ad.orderid,
        ad.ordersessionid,
        ad.orderdateutc,
        now() :: TIMESTAMP      AS sysinserttime,
        ad.locationid
    FROM temp_aborted_delta AS ad
    ON CONFLICT (transactionheaderid, itemid, itemname)
    DO NOTHING;


    -- Advance watermark to max GEM syscosmosts across all sourceid = 2 headers
    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionheader WHERE sourceid = 2)
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'gem';

END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_aborted_orders_and_items_to_fact()
    OWNER TO citus;