--CALL fact.usp_gem_usercheckedin_to_fact_usercheckedin();


SELECT *
FROM fact.usercheckedin
ORDER BY sysinserttime DESC
LIMIT 100;

SELECT locationid, orderid,
    count(*)
FROM fact.usercheckedin
GROUP BY locationid, orderid
HAVING count(*) > 1
ORDER BY sysinserttime DESC
LIMIT 100;

ALTER TABLE IF EXISTS fact.usercheckedin
ADD COLUMN IF NOT EXISTS syscosmosts BIGINT,
ADD CONSTRAINT usercheckedin_pkey PRIMARY KEY (locationid, orderid)

-- Table: fact.usercheckedin

-- DROP TABLE IF EXISTS fact.usercheckedin;

CREATE TABLE IF NOT EXISTS fact.usercheckedin
(
    organizationid text COLLATE pg_catalog."default" NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    kioskid text COLLATE pg_catalog."default",
    ordersessionid text COLLATE pg_catalog."default",
    dateid integer,
    ordertimestamp text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    customername text COLLATE pg_catalog."default",
    customerphone text COLLATE pg_catalog."default",
    orderstatus text COLLATE pg_catalog."default",
    ordertotal numeric(7,3),
    paymentstatus text COLLATE pg_catalog."default",
    amountpaid numeric(7,3),
    paymentmethod text COLLATE pg_catalog."default",
    paymentcardtype text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    orderdatelocal timestamp without time zone,
    syscosmosts BIGINT
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.usercheckedin
    OWNER to citus;

-- Table: stg.silver_kiosk_events

-- DROP TABLE IF EXISTS stg.silver_kiosk_events;

CREATE TABLE IF NOT EXISTS stg.silver_kiosk_events
(
    id text COLLATE pg_catalog."default",
    application text COLLATE pg_catalog."default",
    companyid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    eventmodule text COLLATE pg_catalog."default",
    eventcategory text COLLATE pg_catalog."default",
    eventtype text COLLATE pg_catalog."default",
    severity text COLLATE pg_catalog."default",
    token text COLLATE pg_catalog."default",
    eventinstant text COLLATE pg_catalog."default",
    username text COLLATE pg_catalog."default",
    userid text COLLATE pg_catalog."default",
    device text COLLATE pg_catalog."default",
    devicename text COLLATE pg_catalog."default",
    summary text COLLATE pg_catalog."default",
    data text COLLATE pg_catalog."default",
    syscosmosticks bigint,
    syscosmosts bigint,
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_kiosk_events
    OWNER to citus;
-- Index: ix_silver_kiosk_events_syscosmosts_brin

-- DROP INDEX IF EXISTS stg.ix_silver_kiosk_events_syscosmosts_brin;

CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_syscosmosts_brin
    ON stg.silver_kiosk_events USING brin
    (syscosmosts)
    WITH (pages_per_range=128)
    TABLESPACE pg_default;



CREATE OR REPLACE PROCEDURE fact.usp_gem_usercheckedin_to_fact_usercheckedin()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_watermark     BIGINT;

BEGIN

    -- ----------------------------------------------------------
    -- Step 1 — Read the current watermark (syscosmosts bigint)
    -- ----------------------------------------------------------
    SELECT COALESCE(ts, 1775002010) - 10
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.usercheckedin'
      AND  source             = 'gem';


    -- ----------------------------------------------------------
    -- Step 2 — Upsert into fact.usercheckedin
    --
    -- data JSON path (from sample):
    --   "with request"    : data.request.OrderId
    --                       data.request.Order.OrderIdentity.{Name,Phone}
    --                       data.request.Payments[0].{TotalPaid, PreTipTotal,
    --                         TipAmount, PaymentIntegrationLabel,
    --                         TenderInfo.CardInfo.CardType}
    --   "without request" : data.OrderId
    --                       data.Order.OrderIdentity.{Name,Phone}
    --                       data.Payments[0].{...}
    --
    -- amountpaid : TotalPaid / 100         (cents → USD)
    -- ordertotal : (PreTipTotal + TipAmount) / 100
    -- CardType   : integer code (e.g. 4) — stored as text via jsonb ->>
    -- ----------------------------------------------------------
    WITH parsed AS (
        SELECT
            stg.locationid,
            stg.companyid                                               AS organizationid,
            stg.device                                                  AS kioskid,
            NULLIF(stg.token, '')                                       AS ordersessionid,
            stg.eventinstant                                            AS ordertimestamp,
            stg.syscosmosts,

            -- Payment status — regex guards both "Payments":[] and "Payments": []
            CASE
                WHEN stg.data ~ '"Payments"\s*:\s*\[\s*\]' THEN 'unpaid'
                ELSE 'paid'
            END                                                         AS paymentstatus,

            -- OrderId
            CASE
                WHEN stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' ->> 'OrderId'
                ELSE     stg.data::jsonb ->> 'OrderId'
            END                                                         AS orderid,

            -- CustomerName
            CASE
                WHEN stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' -> 'Order' -> 'OrderIdentity' ->> 'Name'
                ELSE     stg.data::jsonb -> 'Order' -> 'OrderIdentity' ->> 'Name'
            END                                                         AS customername,

            -- CustomerPhone
            CASE
                WHEN stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' -> 'Order' -> 'OrderIdentity' ->> 'Phone'
                ELSE     stg.data::jsonb -> 'Order' -> 'OrderIdentity' ->> 'Phone'
            END                                                         AS customerphone,

            -- AmountPaid: TotalPaid cents → USD
            CASE
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                     AND stg.data LIKE '{"request"%'
                    THEN (stg.data::jsonb -> 'request' -> 'Payments' -> 0 ->> 'TotalPaid')::numeric / 100
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                    THEN (stg.data::jsonb -> 'Payments' -> 0 ->> 'TotalPaid')::numeric / 100
            END                                                         AS amountpaid,

            -- OrderTotal: (PreTipTotal + TipAmount) cents → USD
            CASE
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                     AND stg.data LIKE '{"request"%'
                    THEN (
                            (stg.data::jsonb -> 'request' -> 'Payments' -> 0 ->> 'PreTipTotal')::numeric +
                            (stg.data::jsonb -> 'request' -> 'Payments' -> 0 ->> 'TipAmount')::numeric
                         ) / 100
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                    THEN (
                            (stg.data::jsonb -> 'Payments' -> 0 ->> 'PreTipTotal')::numeric +
                            (stg.data::jsonb -> 'Payments' -> 0 ->> 'TipAmount')::numeric
                         ) / 100
            END                                                         AS ordertotal,

            -- PaymentMethod
            CASE
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                     AND stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' -> 'Payments' -> 0 ->> 'PaymentIntegrationLabel'
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                    THEN stg.data::jsonb -> 'Payments' -> 0 ->> 'PaymentIntegrationLabel'
            END                                                         AS paymentmethod,

            -- PaymentCardType: integer code stored as text (e.g. '4')
            CASE
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                     AND stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' -> 'Payments' -> 0 -> 'TenderInfo' -> 'CardInfo' ->> 'CardType'
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                    THEN stg.data::jsonb -> 'Payments' -> 0 -> 'TenderInfo' -> 'CardInfo' ->> 'CardType'
            END                                                         AS paymentcardtype

        FROM  stg.silver_kiosk_events AS stg
        WHERE LOWER(stg.eventtype)  = 'usercheckedin'
          AND LOWER(stg.severity)   = 'information'
          AND stg.syscosmosts        > v_watermark
          AND stg.data               IS NOT NULL
          AND EXISTS (
                  SELECT 1
                  FROM   dim.location AS dl
                  WHERE  dl.locationid = stg.locationid
              )
    ),

    deduped AS (
        SELECT DISTINCT ON (locationid, orderid)
            locationid,
            organizationid,
            kioskid,
            ordersessionid,
            ordertimestamp,
            orderid,
            customername,
            customerphone,
            paymentstatus,
            amountpaid,
            ordertotal,
            paymentmethod,
            paymentcardtype,
            syscosmosts
        FROM  parsed
        WHERE orderid IS NOT NULL
        ORDER BY locationid, orderid,
                 ordertimestamp DESC
    )

    INSERT INTO fact.usercheckedin (
        organizationid,
        locationid,
        kioskid,
        ordersessionid,
        ordertimestamp,
        orderid,
        customername,
        customerphone,
        paymentstatus,
        amountpaid,
        ordertotal,
        paymentmethod,
        paymentcardtype,
        syscosmosts,
        sysinserttime
    )
    SELECT
        organizationid,
        locationid,
        kioskid,
        ordersessionid,
        ordertimestamp,
        orderid,
        customername,
        customerphone,
        paymentstatus,
        amountpaid,
        ordertotal,
        paymentmethod,
        paymentcardtype,
        syscosmosts,
        NOW()::timestamp
    FROM deduped
    ON CONFLICT (locationid, orderid)
    DO UPDATE SET
        organizationid  = COALESCE(EXCLUDED.organizationid,  fact.usercheckedin.organizationid),
        kioskid         = COALESCE(EXCLUDED.kioskid,         fact.usercheckedin.kioskid),
        ordersessionid  = COALESCE(EXCLUDED.ordersessionid,  fact.usercheckedin.ordersessionid),
        ordertimestamp  = COALESCE(EXCLUDED.ordertimestamp,  fact.usercheckedin.ordertimestamp),
        customername    = COALESCE(EXCLUDED.customername,    fact.usercheckedin.customername),
        customerphone   = COALESCE(EXCLUDED.customerphone,   fact.usercheckedin.customerphone),
        paymentstatus   = COALESCE(EXCLUDED.paymentstatus,   fact.usercheckedin.paymentstatus),
        amountpaid      = COALESCE(EXCLUDED.amountpaid,      fact.usercheckedin.amountpaid),
        ordertotal      = COALESCE(EXCLUDED.ordertotal,      fact.usercheckedin.ordertotal),
        paymentmethod   = COALESCE(EXCLUDED.paymentmethod,   fact.usercheckedin.paymentmethod),
        paymentcardtype = COALESCE(EXCLUDED.paymentcardtype, fact.usercheckedin.paymentcardtype);

    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- ----------------------------------------------------------
    UPDATE fact.watermarktable
    SET    ts = (SELECT coalesce(max(syscosmosts), 1775002010) FROM fact.usercheckedin)
    WHERE  watermarktablename = 'fact.usercheckedin'
      AND  source             = 'gem';

END;
$BODY$;

ALTER PROCEDURE fact.usp_gem_usercheckedin_to_fact_usercheckedin() OWNER TO citus;