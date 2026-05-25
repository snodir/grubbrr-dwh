--SELECT * FROM stg.silver_transaction_payment;

--CALL fact.usp_silver_transaction_payment_to_fact();

ALTER TABLE IF EXISTS stg.silver_transaction_payment
OWNER TO citus,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP;

CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_payment_to_fact()
LANGUAGE plpgsql
AS $BODY$

BEGIN

INSERT INTO fact.transactionpayment(
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
    paymentcardtype
)
SELECT
    transactionheaderid,
    payment_integration_id AS paymentintegrationid,
    payment_transactionid AS paymentid,
    payment_amount :: NUMERIC(12,3) AS paymentamt,
    orderid,
    locationid,
    kioskid,
    payment_method AS paymentmethod,
    payment_integration_label AS paymentintegrationlabel,
    fact.parse_iso_timestamp(orderdateutc) as orderdateutc,
    now() :: TIMESTAMP AS sysinserttime,
    payment_card_name AS paymentcardtype
FROM stg.silver_transaction_payment AS dp
WHERE (dp.is_test_order = False OR dp.is_test_order IS NULL)
  AND NOT EXISTS (
        SELECT 1
        FROM fact.transactionpayment AS tp
        WHERE tp.locationid          = dp.locationid
          AND tp.transactionheaderid = dp.transactionheaderid
      );

END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_transaction_payment_to_fact()
    OWNER TO citus;
