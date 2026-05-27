-- ========
-- 1. Load fact.transactionheader
-- ========

--CALL fact.usp_silver_transaction_header_to_fact();

CREATE INDEX IF NOT EXISTS ix_transactionheader_syscosmosts_brin
    ON fact.transactionheader USING brin (syscosmosts)
    WITH (pages_per_range = 128);

SELECT * FROM stg.silver_transaction_header WHERE transactionheaderid = 'ordevt-N9LAXQ8VPIDH49PW';
SELECT * FROM fact.transactionheader ORDER BY createddate DESC LIMIT 100
SELECT * FROM dim.ordertype WHERE locationid = 'loc-1fb25c39-043f-4fe1-99d8-6e4086e24586'

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


CREATE SEQUENCE IF NOT EXISTS fact.transactionheader_id_seq;

SELECT setval(
    'fact.transactionheader_id_seq',
    COALESCE((SELECT MAX(id) FROM fact.transactionheader), 0)
);

ALTER TABLE fact.transactionheader
    ALTER COLUMN id SET DEFAULT nextval('fact.transactionheader_id_seq');


-- ============================================================
-- SECTION 2 – REFRESH STORED PROCEDURE
-- ============================================================

CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_header_to_fact()
LANGUAGE plpgsql
AS
$BODY$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'nge';


    WITH delta_transactions AS (
        -- DISTINCT ON replaces ROW_NUMBER() + WHERE row_num = 1
        -- Keeps the latest version of each transaction per location
        SELECT DISTINCT ON (locationid, transactionheaderid)
            transactionheaderid,
            orderid,
            locationid,
            kioskid,
            ordersessionid,
            fact.parse_iso_timestamp(orderdateutc)  AS orderdateutc,
            order_completion_status                 AS orderstatus,
            CASE WHEN ordertype = ''
                   OR ordertype IS NULL THEN order_type_label
                 ELSE ordertype
            END                                     AS ordertypeid,
            numberofitems,
            numberofpayments,
            usd_reward          :: NUMERIC(12,3)    AS ordersredeemedrewards,
            usd_subtotal        :: NUMERIC(12,3)    AS ordersubtotal,
            usd_amount          :: NUMERIC(12,3)    AS ordertotal,
            usd_tax             :: NUMERIC(12,3)    AS ordertax,
            usd_tip             :: NUMERIC(12,3)    AS ordertip,
            usd_discount        :: NUMERIC(12,3)    AS orderdiscount,
            usd_charity_amount  :: NUMERIC(12,3)    AS charityamount,
            usd_service_charge  :: NUMERIC(12,3)    AS orderservicecharge,
            businessdate        :: DATE             AS businessdate,
            CASE channel
                WHEN 0 THEN 'Kiosk'
                WHEN 1 THEN 'OnlineOrdering'
                ELSE 'External'
            END                                     AS channel,
            guest_count                             AS guestcount,
            frequentcustomerid,
            customername,
            syscosmosts
        FROM stg.silver_transaction_header
        WHERE (is_test_order = False OR is_test_order IS NULL)
          AND syscosmosts > v_max_syscosmosts
        ORDER BY locationid, transactionheaderid, orderdateutc DESC

    ), qualified_trxns AS (

        SELECT
            dt.*,
            ot.id                                                        AS ordertype,
            dt.orderdateutc :: TIMESTAMPTZ AT TIME ZONE l.timezone       AS orderdatelocal
        FROM delta_transactions AS dt
        LEFT JOIN dim.ordertype AS ot
            ON  dt.locationid  = ot.locationid
            AND dt.kioskid     = ot.kioskid
            AND dt.ordertypeid = ot.ordertypeid
        LEFT JOIN dim.organization AS l
            ON dt.locationid = l.id

    ), aggregated_kiosk_events AS (

        -- Pre-filtered to only the sessions present in this batch.
        -- Avoids a full scan of silver_kiosk_events on every run.
        SELECT
            ke.locationid,
            ke.token,
            min(CASE WHEN lower(ke.eventcategory) = 'session'
                          AND lower(ke.eventtype)  = 'started'
                     THEN ke.eventinstant END)                           AS orderstarttime,
            min(CASE WHEN lower(ke.eventcategory) IN ('order','insight')
                          AND lower(ke.eventtype)  = 'revieworderclicked'
                     THEN ke.eventinstant END)                           AS reviewordertime,
            min(CASE WHEN lower(ke.eventcategory) IN ('order','insight')
                          AND lower(ke.eventtype)  = 'checkoutclicked'
                     THEN ke.eventinstant END)                           AS checkouttime,
            min(CASE WHEN lower(ke.eventcategory) = 'payment'
                          AND lower(ke.eventtype)  = 'create'
                     THEN ke.eventinstant END)                           AS paystarttime,
            max(CASE WHEN lower(ke.eventcategory) IN ('session','order')
                          AND lower(ke.eventtype)  = 'closed'
                     THEN ke.eventinstant END)                           AS sessionendtime
        FROM stg.silver_kiosk_events AS ke
        INNER JOIN qualified_trxns AS qt
            ON  qt.locationid     = ke.locationid
            AND qt.ordersessionid = ke.token
        WHERE lower(ke.severity) = 'information'
          AND (
                (lower(ke.eventcategory) = 'session'               AND lower(ke.eventtype) = 'started')            OR
                (lower(ke.eventcategory) IN ('order', 'insight')   AND lower(ke.eventtype) = 'revieworderclicked') OR
                (lower(ke.eventcategory) IN ('order', 'insight')   AND lower(ke.eventtype) = 'checkoutclicked')    OR
                (lower(ke.eventcategory) = 'payment'               AND lower(ke.eventtype) = 'create')             OR
                (lower(ke.eventcategory) IN ('session', 'order')   AND lower(ke.eventtype) = 'closed')
              )
        GROUP BY ke.locationid, ke.token

    ), orders_enriched AS (

        SELECT
            qt.*,
            fact.parse_iso_timestamp(ke.orderstarttime)  :: TIMESTAMP AS orderstarttime,
            fact.parse_iso_timestamp(ke.reviewordertime) :: TIMESTAMP AS reviewordertime,
            fact.parse_iso_timestamp(ke.checkouttime)    :: TIMESTAMP AS checkouttime,
            fact.parse_iso_timestamp(ke.paystarttime)    :: TIMESTAMP AS paystarttime,
            fact.parse_iso_timestamp(ke.sessionendtime)  :: TIMESTAMP AS sessionendtime
        FROM qualified_trxns AS qt
        LEFT JOIN aggregated_kiosk_events AS ke
            ON  ke.locationid = qt.locationid
            AND ke.token      = qt.ordersessionid

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
        channel,
        guestcount,
        charityamount,
        syscosmosts,
        sourceid,
        orderservicecharge,
        customername
    )
    SELECT
        nextval('fact.transactionheader_id_seq')                    AS id,
        transactionheaderid,
        orderid,
        locationid,
        kioskid,
        ordersessionid,
        CAST(TO_CHAR(orderdatelocal, 'YYYYMMDDHH24') AS INTEGER)    AS dateid,
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
        0.0 :: NUMERIC(12,3)                                        AS orderbalance,
        CASE WHEN numberofpayments > 0 THEN 'paid' END              AS paymentstatus,
        'NGE'                                                        AS sourcefile,
        now() :: TIMESTAMP                                           AS createddate,
        orderstarttime,
        reviewordertime,
        checkouttime,
        paystarttime,
        sessionendtime,
        EXTRACT(EPOCH FROM (checkouttime    - orderstarttime))      AS precheckouttime,
        EXTRACT(EPOCH FROM (sessionendtime  - checkouttime))        AS postcheckouttime,
        EXTRACT(EPOCH FROM (reviewordertime - orderstarttime))      AS menupagetime,
        EXTRACT(EPOCH FROM (checkouttime    - reviewordertime))     AS reviewpagetime,
        EXTRACT(EPOCH FROM (sessionendtime  - paystarttime))        AS paymentpagetime,
        EXTRACT(EPOCH FROM (sessionendtime  - orderstarttime))      AS totalordertime,
        businessdate,
        frequentcustomerid,
        channel,
        guestcount,
        charityamount,
        syscosmosts,
        1 :: INTEGER                                                 AS sourceid,
        orderservicecharge,
        customername
    FROM orders_enriched

    ON CONFLICT (locationid, transactionheaderid)
    DO UPDATE SET
        ordertype        = EXCLUDED.ordertype,
        orderstarttime   = COALESCE(fact.transactionheader.orderstarttime,   EXCLUDED.orderstarttime),
        reviewordertime  = COALESCE(fact.transactionheader.reviewordertime,  EXCLUDED.reviewordertime),
        checkouttime     = COALESCE(fact.transactionheader.checkouttime,     EXCLUDED.checkouttime),
        paystarttime     = COALESCE(fact.transactionheader.paystarttime,     EXCLUDED.paystarttime),
        sessionendtime   = COALESCE(fact.transactionheader.sessionendtime,   EXCLUDED.sessionendtime),
        precheckouttime  = COALESCE(
                               fact.transactionheader.precheckouttime,
                               EXTRACT(EPOCH FROM (EXCLUDED.checkouttime    - EXCLUDED.orderstarttime))
                           ),
        postcheckouttime = COALESCE(
                               fact.transactionheader.postcheckouttime,
                               EXTRACT(EPOCH FROM (EXCLUDED.sessionendtime  - EXCLUDED.checkouttime))
                           ),
        menupagetime     = COALESCE(
                               fact.transactionheader.menupagetime,
                               EXTRACT(EPOCH FROM (EXCLUDED.reviewordertime - EXCLUDED.orderstarttime))
                           ),
        reviewpagetime   = COALESCE(
                               fact.transactionheader.reviewpagetime,
                               EXTRACT(EPOCH FROM (EXCLUDED.checkouttime    - EXCLUDED.reviewordertime))
                           ),
        paymentpagetime  = COALESCE(
                               fact.transactionheader.paymentpagetime,
                               EXTRACT(EPOCH FROM (EXCLUDED.sessionendtime  - EXCLUDED.paystarttime))
                           ),
        totalordertime   = COALESCE(
                               fact.transactionheader.totalordertime,
                               EXTRACT(EPOCH FROM (EXCLUDED.sessionendtime  - EXCLUDED.orderstarttime))
                           ),
        updateddate      = now() :: TIMESTAMP
    WHERE (
        (fact.transactionheader.ordertype       IS NULL AND EXCLUDED.ordertype       IS NOT NULL) OR
        (fact.transactionheader.orderstarttime  IS NULL AND EXCLUDED.orderstarttime  IS NOT NULL) OR
        (fact.transactionheader.reviewordertime IS NULL AND EXCLUDED.reviewordertime IS NOT NULL) OR
        (fact.transactionheader.checkouttime    IS NULL AND EXCLUDED.checkouttime    IS NOT NULL) OR
        (fact.transactionheader.paystarttime    IS NULL AND EXCLUDED.paystarttime    IS NOT NULL) OR
        (fact.transactionheader.sessionendtime  IS NULL AND EXCLUDED.sessionendtime  IS NOT NULL)
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionheader WHERE sourceid = 1)
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'nge';

END;
$BODY$;



ALTER PROCEDURE fact.usp_silver_transaction_header_to_fact()
    OWNER TO citus;


-- =============================================================================
-- RECOMMENDED SUPPORTING INDEXES
-- Run once after deploying the procedure.
-- =============================================================================

-- Required for ON CONFLICT target (must be UNIQUE)
-- CREATE UNIQUE INDEX IF NOT EXISTS uix_th_location_txnid
--     ON fact.transactionheader (locationid, transactionheaderid);

-- Supports the syscosmosts watermark lookup
-- CREATE INDEX IF NOT EXISTS idx_th_syscosmosts
--     ON fact.transactionheader (syscosmosts DESC);

-- Supports the incremental filter on silver table
-- CREATE INDEX IF NOT EXISTS idx_silver_th_syscosmosts
--     ON stg.silver_transaction_header (syscosmosts)
--     WHERE (is_test_order = False OR is_test_order IS NULL);

-- Supports the kiosk events pre-filter join
-- CREATE INDEX IF NOT EXISTS idx_ke_location_token
--     ON stg.silver_kiosk_events (locationid, token)
--     WHERE lower(severity) = 'information';

-- Optional: functional indexes to avoid lower() scan penalty on event filters
-- CREATE INDEX IF NOT EXISTS idx_ke_eventcategory_lower
--     ON stg.silver_kiosk_events (lower(eventcategory), lower(eventtype));






-- =============================================================================
-- PROCEDURE: fact.usp_silver_transaction_header_to_fact
-- 
-- CHANGES FROM ORIGINAL:
--   1. Incremental load via syscosmosts watermark (no longer full-scans silver)
--   2. Removed stg.lookup_silver_transaction_header intermediate materialization
--   3. Removed temp_transaction_header table entirely
--   4. Replaced ROW_NUMBER() deduplication with DISTINCT ON
--   5. Pre-filtered stg.silver_kiosk_events to relevant sessions only
--   6. Replaced NOT EXISTS anti-pattern with INSERT ... ON CONFLICT
--   7. ON CONFLICT DO UPDATE fills NULL timing fields with late-arriving data
--   8. COALESCE guards ensure existing timing values are never overwritten
--   9. WHERE clause on DO UPDATE prevents unnecessary writes when nothing changes
--  10. Derived timing fields recomputed from base timestamps for consistency
--
-- NOTE ON LATE-ARRIVING KIOSK EVENTS:
--   Timing fields (orderstarttime, sessionendtime, etc.) come from
--   stg.silver_kiosk_events, which may arrive after the transaction header.
--   The ON CONFLICT DO UPDATE handles this: if a transaction was inserted
--   with NULL timing fields, any subsequent run that finds matching kiosk
--   events will fill them in — as long as the transaction reappears in the
--   silver layer (syscosmosts > watermark). If kiosk events are the ONLY
--   thing that changes (transaction header itself is not re-emitted), consider
--   a separate backfill procedure that targets fact.transactionheader WHERE
--   orderstarttime IS NULL and joins directly to silver_kiosk_events.
-- =============================================================================