--CALL etl.truncate_silver_staging();
--SELECT * FROM fact.watermarktable;
CREATE OR REPLACE PROCEDURE etl.truncate_silver_staging(
)
LANGUAGE plpgsql 
AS $BODY$
BEGIN

    -- ── Transaction staging tables: full truncate ──────────────────
    -- No cross-hour dependency, safe to clear completely each run
    --TRUNCATE TABLE stg.silver_transaction_header;
    --TRUNCATE TABLE stg.silver_transaction_item;
    --TRUNCATE TABLE stg.silver_transaction_combo_items;
    TRUNCATE TABLE stg.silver_transaction_payment;
    TRUNCATE TABLE stg.silver_item_modifiers;
    TRUNCATE TABLE stg.silver_upsell_recommendations;
    TRUNCATE TABLE stg.silver_modifier_recommendations;
    TRUNCATE TABLE stg.silver_modifier_interactions;
    TRUNCATE TABLE stg.silver_modifier_impressions;
    --TRUNCATE TABLE stg.silver_transaction_refunds; --not a big table to truncate

    -- ── Device / infrastructure staging tables: full truncate ──────
    TRUNCATE TABLE stg.fact_devicestate;
    TRUNCATE TABLE stg.fact_devicetelemetry;
    TRUNCATE TABLE stg.fact_occasionsurveydetail;
    TRUNCATE TABLE stg.fact_itemssurvey;
    TRUNCATE TABLE stg.silver_cep_incidents;
    TRUNCATE TABLE stg.gem_failed_order_job_notifications;


    -- ── Events staging table: 15-minute sliding window ────────────
    -- 8 SPs join this table via ordersessionid = token.
    -- Sessions can start up to 15 minutes before the order completes.
    -- Kiosk auto-cancels after 15 min → this window covers all cases.
    DELETE FROM stg.silver_kiosk_events
    WHERE syscosmosts < (SELECT ts - 600         -- 600 seconds = 10 minutes of backup for late-minutes (hh:40 - hh:59)
                         FROM fact.watermarktable 
                         WHERE watermarktablename = 'fact.deviceevent'
                           AND source             = 'gem');

    DELETE FROM stg.silver_transaction_header
    WHERE syscosmosts < (SELECT ts - 600         -- 600 seconds = 10 minutes of backup for late-minutes (hh:40 - hh:59)
                         FROM fact.watermarktable 
                         WHERE watermarktablename = 'fact.transactionheader'
                           AND source             = 'nge');

    DELETE FROM stg.silver_transaction_item
    WHERE syscosmosts < (SELECT ts - 600         -- 600 seconds = 10 minutes of backup for late-minutes (hh:40 - hh:59)
                         FROM fact.watermarktable 
                         WHERE watermarktablename = 'fact.transactionitem'
                           AND source             = 'nge');

    DELETE FROM stg.silver_transaction_combo_items
    WHERE syscosmosts < (SELECT ts - 600         -- 600 seconds = 10 minutes of backup for late-minutes (hh:40 - hh:59)
                         FROM fact.watermarktable 
                         WHERE watermarktablename = 'fact.transactionitem'
                           AND source             = 'nge');
                           
END;
$BODY$;

