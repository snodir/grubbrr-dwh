--SELECT * FROM stg.silver_transaction_payment;

--CALL fact.usp_silver_transaction_payment_to_fact();

ALTER TABLE IF EXISTS stg.silver_transaction_payment
OWNER TO citus,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;

-- PROCEDURE: fact.usp_silver_transaction_payment_to_fact()

-- DROP PROCEDURE IF EXISTS fact.usp_silver_transaction_payment_to_fact();

CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_payment_to_fact(
	)
LANGUAGE plpgsql
AS $BODY$


DECLARE
    v_max_syscosmosts BIGINT;

BEGIN

    SELECT COALESCE(MAX(syscosmosts)-10, 0)
    INTO v_max_syscosmosts
    FROM fact.transactionpayment;

    WITH delta AS (
        -- Deduplicate: keep latest row per (location, header, payment)
        SELECT DISTINCT ON (locationid, transactionheaderid, payment_transactionid)
            transactionheaderid,
            orderid,
            locationid,
            kioskid,
            payment_integration_id          AS paymentintegrationid,
            payment_transactionid           AS paymentid,
            payment_amount  :: NUMERIC(12,3) AS paymentamt,
            payment_method                  AS paymentmethod,
            payment_integration_label       AS paymentintegrationlabel,
            payment_card_name               AS paymentcardtype,
            orderdateutc,
            syscosmosts
        FROM stg.silver_transaction_payment
        WHERE (is_test_order = False OR is_test_order IS NULL)
          AND syscosmosts > v_max_syscosmosts
        ORDER BY locationid, transactionheaderid, payment_transactionid, syscosmosts DESC
    )
    INSERT INTO fact.transactionpayment (
        transactionheaderid,
        paymentintegrationid,
        paymentid,
        paymentamt,
        orderid,
        locationid,
        kioskid,
        paymentmethod,
        paymentintegrationlabel,
        orderdateutc,
        sysinserttime,
        paymentcardtype,
        syscosmosts
    )
    SELECT
        transactionheaderid,
        paymentintegrationid,
        paymentid,
        paymentamt,
        orderid,
        locationid,
        kioskid,
        paymentmethod,
        paymentintegrationlabel,
        fact.parse_iso_timestamp(orderdateutc)  AS orderdateutc,
        now() :: TIMESTAMP                      AS sysinserttime,
        paymentcardtype,
        syscosmosts
    FROM delta

    ON CONFLICT (locationid, transactionheaderid, paymentintegrationid, paymentid)
    DO NOTHING;  -- payments are immutable once recorded

END;
$BODY$;
ALTER PROCEDURE fact.usp_silver_transaction_payment_to_fact()
    OWNER TO citus;

