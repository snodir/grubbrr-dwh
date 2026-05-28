--CALL fact.usp_silver_transaction_refunds_to_fact();

SELECT * FROM stg.silver_transaction_refunds
SELECT * FROM fact.transactionrefunds
SELECT * FROM fact.watermarktable
-- Table: fact.transactionrefunds

-- DROP TABLE IF EXISTS fact.transactionrefunds;

CREATE TABLE IF NOT EXISTS fact.transactionrefunds
(
    transactionheaderid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    orderid character varying(50) COLLATE pg_catalog."default",
    locationid character varying(50) COLLATE pg_catalog."default",
    refundtransactionid character varying(50) COLLATE pg_catalog."default",
    paymentid character varying(50) COLLATE pg_catalog."default",
    refundamount numeric(7,3),
    refundtype character varying(50) COLLATE pg_catalog."default",
    orderdateutc text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    syscosmosts bigint
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.transactionrefunds
    OWNER to citus;

-- Index: idx_transactionrefunds_headerid

-- DROP INDEX IF EXISTS fact.idx_transactionrefunds_headerid;

CREATE INDEX IF NOT EXISTS idx_transactionrefunds_headerid
    ON fact.transactionrefunds USING btree
    (transactionheaderid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;


-- Table: stg.silver_transaction_refunds

-- DROP TABLE IF EXISTS stg.silver_transaction_refunds;

CREATE TABLE IF NOT EXISTS stg.silver_transaction_refunds
(
    locationid text COLLATE pg_catalog."default",
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    orderid text COLLATE pg_catalog."default",
    original_transaction_id text COLLATE pg_catalog."default",
    refund_transaction_id text COLLATE pg_catalog."default",
    refund_type text COLLATE pg_catalog."default",
    refunded_amount numeric(12,3),
    order_completion_status text COLLATE pg_catalog."default",
    orderdateutc text COLLATE pg_catalog."default",
    syscosmosts bigint,
    bronze_filepath text COLLATE pg_catalog."default",
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_transaction_refunds
    OWNER to citus;


CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_refunds_to_fact()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_watermark     BIGINT;

BEGIN

    -- No source filter on this watermark row
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_watermark
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionrefunds'
      AND source = 'nge';

    WITH delta AS (
        -- Deduplicate: keep latest refund snapshot per (locationid, transactionheaderid)
        SELECT DISTINCT ON (locationid, transactionheaderid)
            locationid,
            transactionheaderid,
            orderid,
            original_transaction_id         AS paymentid,       -- c.originalTransactionId in CosmosDB
            refund_transaction_id           AS refundtransactionid,
            refund_type                     AS refundtype,
            refunded_amount                 AS refundamount,
            fact.parse_iso_timestamp(orderdateutc) AS orderdateutc,
            syscosmosts
        FROM stg.silver_transaction_refunds
        WHERE syscosmosts > v_watermark
          -- mirror CosmosDB type filter
          AND order_completion_status IN ('order-refund-amount', 'order-refund-transaction')
          -- mirror CosmosDB refundTransactionId <> '' filter
          AND refund_transaction_id IS NOT NULL
          AND refund_transaction_id <> ''
          -- mirror CosmosDB orderDate >= '2024-06-23' hard cutoff
        ORDER BY locationid, transactionheaderid, syscosmosts DESC
    )
    INSERT INTO fact.transactionrefunds (
        transactionheaderid,
        orderid,
        locationid,
        refundtransactionid,
        paymentid,
        refundamount,
        refundtype,
        orderdateutc,
        sysinserttime,
        syscosmosts
    )
    SELECT
        d.transactionheaderid,
        d.orderid,
        d.locationid,
        d.refundtransactionid,
        d.paymentid,
        d.refundamount,
        d.refundtype,
        d.orderdateutc,
        NOW() :: TIMESTAMP      AS sysinserttime,
        d.syscosmosts
    FROM delta d
    -- mirror ADF ExistingPayments step: only load refunds for orders already in fact layer
    INNER JOIN fact.transactionheader th
            ON th.orderid    = d.orderid
           AND th.locationid = d.locationid
    -- mirror ADF NewRefunds step (negate:true): skip if already recorded
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.transactionrefunds tr
        WHERE tr.transactionheaderid = d.transactionheaderid
    );

    -- ----------------------------------------------------------
    -- Update paymentstatus on transactionheader for all refunds
    -- in this batch. ROW_NUMBER() picks the latest refund event
    -- per order in case of multiple partial/full refund records.
    -- Scoped to current batch via v_watermark (same value used
    -- in the INSERT above) to avoid re-processing old refunds.
    -- ----------------------------------------------------------
    WITH latest_refunds AS (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY locationid, orderid
                   ORDER BY orderdateutc DESC
               ) AS rn
        FROM fact.transactionrefunds
        WHERE COALESCE(syscosmosts, 1775002010) > v_watermark
    )
    UPDATE fact.transactionheader
    SET paymentstatus = CASE LOWER(r.refundtype)
                            WHEN 'fullrefund' THEN 'Fully refunded'
                            ELSE                   'Partially refunded'
                        END
    FROM latest_refunds r
    WHERE fact.transactionheader.locationid = r.locationid
      AND fact.transactionheader.orderid    = r.orderid
      AND r.rn = 1;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionrefunds)
    WHERE watermarktablename = 'fact.transactionrefunds';

END;
$BODY$;
ALTER PROCEDURE fact.usp_silver_transaction_refunds_to_fact()
    OWNER TO citus;

/*
WITH refunds as (
select *, row_number() over(partition by locationid, orderid order by orderdateutc desc) as rn
from fact.transactionrefunds
where coalesce(syscosmosts, 1500000010) > @{activity('Lookup MaxFields').output.firstRow.maxts}
)
UPDATE fact.transactionheader 
SET paymentstatus = case lower(r.refundtype) when 'fullrefund' then 'Fully refunded' else 'Partially refunded' end
FROM refunds as r
WHERE transactionheader.locationid = r.locationid
  AND transactionheader.orderid = r.orderid
  AND r.rn = 1;

UPDATE fact.watermarktable
SET ts = tr.maxts
FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.transactionrefunds' as tablename FROM fact.transactionrefunds) as tr 
WHERE watermarktable.watermarktablename = tr.tablename;

SELECT 1 as rn;

*/