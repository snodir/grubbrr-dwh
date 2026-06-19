--CALL fact.usp_distribute_silver_transaction_entities();
--SELECT * FROM stg.silver_all_transaction_entities;
--TRUNCATE --TABLE stg.silver_all_transaction_entities
--DROP TABLE --IF EXISTS stg.silver_all_transaction_entities;
CREATE TABLE IF NOT EXISTS stg.silver_all_transaction_entities (
    -- ── Cosmos / system metadata ──────────────────────────────────────────
    "_attachments"                        TEXT,
    "_etag"                               TEXT,
    "_rid"                                TEXT,
    "_self"                               TEXT,
    "_lsn"                                BIGINT,
    "_ts"                                 BIGINT,

    -- ── Order header scalars ──────────────────────────────────────────────
    "id"                                  TEXT,
    "orderId"                             TEXT,
    "locationId"                          TEXT,
    "businessDate"                        TEXT,
    "orderDate"                           TEXT,
    "orderType"                           TEXT,
    "orderTypeLabel"                      TEXT,
    "channel"                             INTEGER,
    "conceptId"                           TEXT,
    "conceptName"                         TEXT,
    "kioskSessionId"                      TEXT,
    "clientIpAddress"                     TEXT,
    "guestCount"                          INTEGER,
    "gusetCheckImageLink"                 TEXT,   -- preserved source typo
    "isFailedToSendToPos"                 BOOLEAN,
    "isTestOrder"                         BOOLEAN,
    "posSubmissionStatus"                 INTEGER,
    "originalTransactionId"               TEXT,
    "refundTransactionId"                 TEXT,
    "refundType"                          TEXT,
    "refundedAmount"                      NUMERIC(12,3),
    "rawResponse"                         TEXT,
    "receiptImage"                        TEXT,
    "orderReceiptUrl"                     TEXT,
    "orderReceiptPdfUrl"                  TEXT,
    "type"                                TEXT,

    -- ── Loyalty scalars ───────────────────────────────────────────────────
    "loyaltyProviderTransactionId"        TEXT,
    "loyaltyProviderPaymentTransactionId" TEXT,

    -- ── Complex / nested  →  TEXT ─────────────────────────────────────────
    "kioskSource"                         TEXT,
    "orderIdentity"                       TEXT,
    "loyaltyUser"                         TEXT,
    "localCurrencyDetails"                TEXT,
    "totals"                              TEXT,
    "totalsCents"                         TEXT,
    "receiptDetails"                      TEXT,
    "concepts"                            TEXT,
    "items"                               TEXT,
    "combos"                              TEXT,
    "discounts"                           TEXT,
    "paymentDetails"                      TEXT,
    "redeemedRewards"                     TEXT,
    "upsellInformation"                   TEXT,

    --New Fields--
    "resolvedAt"                          TEXT,
    "thirdPartyOrderId"                   TEXT,
    -- ── Pipeline metadata ─────────────────────────────────────────────────
    "bronze_folderpath"                   TEXT,
    "sysinserttime"                       TEXT
);


-- ================================================================
-- usp_distribute_silver_transaction_entities targets
-- ================================================================
ALTER TABLE IF EXISTS stg.silver_transaction_header
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

-- Missing ALTER TABLE
ALTER TABLE IF EXISTS stg.silver_transaction_payment
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

ALTER TABLE IF EXISTS stg.silver_transaction_item
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

ALTER TABLE IF EXISTS stg.silver_item_modifiers
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

ALTER TABLE IF EXISTS stg.silver_transaction_combo_items
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

ALTER TABLE IF EXISTS stg.silver_upsell_recommendations
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

ALTER TABLE IF EXISTS stg.silver_modifier_recommendations
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

ALTER TABLE IF EXISTS stg.silver_modifier_impressions
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

ALTER TABLE IF EXISTS stg.silver_modifier_interactions
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;

ALTER TABLE IF EXISTS stg.silver_transaction_refunds
    ADD COLUMN IF NOT EXISTS bronze_folderpath TEXT;







CREATE OR REPLACE PROCEDURE fact.usp_distribute_silver_transaction_entities(
    p_partition_path TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- ================================================================
    -- 1. TRANSACTION HEADER
    -- ================================================================
    INSERT INTO stg.silver_transaction_header (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, channel,
        items_array, payments_array, numberofitems, numberofpayments,
        concept_id, concept_name, ordertype, order_type_label, order_completion_status,
        pos_submission_status, is_send_to_pos_failed, is_test_order,
        frequentcustomerid, customername, client_ip_address,
        order_identity_order_token, order_identity_pos_order_token,
        order_identity_phone, order_identity_phone_country_code,
        order_identity_email, order_identity_table_tent, order_identity_device_imei,
        guest_count, guest_check_code, genesis_fiscal_fields, order_language,
        receipt_printing_type, loyalty_transaction_id, loyalty_payment_transaction_id,
        loyalty_earned_points, local_currency_code, local_currency_additional_info,
        usd_amount, usd_subtotal, usd_tax, usd_tip, usd_discount,
        usd_reward, usd_service_charge, usd_charity_amount,
        cents_amount, cents_subtotal, cents_tax, cents_tip, cents_discount,
        cents_reward, cents_service_charge, cents_charity_amount,
        discounts_array, combos_array, redeemed_rewards_array, concepts_array,
        upsell_prompt_array, modifier_interactions_array, modifier_impressions_array,
        loyalty_user_object, receipt_details_object, kiosk_source_object,
        local_currency_details_object, order_identity_object,
        totals_object, totals_cents_object,
        bronze_filepath, silver_transform_time, silver_folderpath, sysinserttime, bronze_folderpath
    )
    SELECT
        src."id"                                                                   AS transactionheaderid,
        src."orderId"                                                              AS orderid,
        src."kioskSessionId"                                                       AS ordersessionid,
        src."orderDate"                                                            AS orderdateutc,
        src."businessDate"                                                         AS businessdate,
        src."_ts"                                                                  AS syscosmosts,
        src."locationId"                                                           AS locationid,
        src."kioskSource"::jsonb->>'kioskId'                                       AS kioskid,
        src."kioskSource"::jsonb->>'name'                                          AS kiosk_name,
        (src."kioskSource"::jsonb->>'kioskMode')::integer                          AS kiosk_mode,
        src."channel"                                                              AS channel,
        src."items"                                                                AS items_array,
        src."paymentDetails"                                                       AS payments_array,
        CASE
            WHEN COALESCE(jsonb_array_length(NULLIF(src."items", '')::jsonb), 0) = 0
            THEN COALESCE(jsonb_array_length(NULLIF(src."combos", '')::jsonb), 0)
            ELSE jsonb_array_length(NULLIF(src."items", '')::jsonb)
        END::smallint                                                              AS numberofitems,
        COALESCE(jsonb_array_length(NULLIF(src."paymentDetails", '')::jsonb), 0)
            ::smallint                                                             AS numberofpayments,
        src."conceptId"                                                            AS concept_id,
        src."conceptName"                                                          AS concept_name,
        src."orderType"                                                            AS ordertype,
        src."orderTypeLabel"                                                       AS order_type_label,
        src."type"                                                                 AS order_completion_status,
        src."posSubmissionStatus"                                                  AS pos_submission_status,
        src."isFailedToSendToPos"                                                  AS is_send_to_pos_failed,
        src."isTestOrder"                                                          AS is_test_order,
        src."loyaltyUser"::jsonb->>'id'                                            AS frequentcustomerid,
        src."orderIdentity"::jsonb->>'name'                                        AS customername,
        src."clientIpAddress"                                                      AS client_ip_address,
        src."orderIdentity"::jsonb->>'orderToken'                                  AS order_identity_order_token,
        src."orderIdentity"::jsonb->>'posOrderToken'                               AS order_identity_pos_order_token,
        src."orderIdentity"::jsonb->>'phone'                                       AS order_identity_phone,
        src."orderIdentity"::jsonb->>'phoneCountryCode'                            AS order_identity_phone_country_code,
        src."orderIdentity"::jsonb->>'email'                                       AS order_identity_email,
        src."orderIdentity"::jsonb->>'tableTent'                                   AS order_identity_table_tent,
        src."orderIdentity"::jsonb->>'deviceImei'                                  AS order_identity_device_imei,
        src."guestCount"                                                           AS guest_count,
        src."receiptDetails"::jsonb->>'guestCheckCode'                             AS guest_check_code,
        (src."receiptDetails"::jsonb->'genesisFiscalFields')::text                 AS genesis_fiscal_fields,
        src."receiptDetails"::jsonb->>'orderLanguage'                              AS order_language,
        src."receiptDetails"::jsonb->>'receiptPrintingType'                        AS receipt_printing_type,
        src."loyaltyProviderTransactionId"                                         AS loyalty_transaction_id,
        src."loyaltyProviderPaymentTransactionId"                                  AS loyalty_payment_transaction_id,
        src."receiptDetails"::jsonb->>'loyaltyEarnedPoints'                        AS loyalty_earned_points,
        src."localCurrencyDetails"::jsonb->>'currencyCode'                         AS local_currency_code,
        src."localCurrencyDetails"::jsonb->>'additionalInfo'                       AS local_currency_additional_info,
        (src."totals"::jsonb->>'total')::numeric(12,3)                             AS usd_amount,
        (src."totals"::jsonb->>'subTotal')::numeric(12,3)                          AS usd_subtotal,
        (src."totals"::jsonb->>'tax')::numeric(12,3)                               AS usd_tax,
        (src."totals"::jsonb->>'tip')::numeric(12,3)                               AS usd_tip,
        (src."totals"::jsonb->>'discount')::numeric(12,3)                          AS usd_discount,
        (src."totals"::jsonb->>'reward')::numeric(12,3)                            AS usd_reward,
        (src."totals"::jsonb->>'serviceCharge')::numeric(12,3)                     AS usd_service_charge,
        (src."totals"::jsonb->>'charityAmount')::numeric(12,3)                     AS usd_charity_amount,
        (src."totalsCents"::jsonb->>'total')::bigint                               AS cents_amount,
        (src."totalsCents"::jsonb->>'subTotal')::bigint                            AS cents_subtotal,
        (src."totalsCents"::jsonb->>'tax')::bigint                                 AS cents_tax,
        (src."totalsCents"::jsonb->>'tip')::bigint                                 AS cents_tip,
        (src."totalsCents"::jsonb->>'discount')::bigint                            AS cents_discount,
        (src."totalsCents"::jsonb->>'reward')::bigint                              AS cents_reward,
        (src."totalsCents"::jsonb->>'serviceCharge')::bigint                       AS cents_service_charge,
        (src."totalsCents"::jsonb->>'charityAmount')::bigint                       AS cents_charity_amount,
        src."discounts"                                                            AS discounts_array,
        src."combos"                                                               AS combos_array,
        src."redeemedRewards"                                                      AS redeemed_rewards_array,
        src."concepts"                                                             AS concepts_array,
        (NULLIF(src."upsellInformation", '')::jsonb->'upsellPrompt')::text         AS upsell_prompt_array,
        (NULLIF(src."upsellInformation", '')::jsonb->'modifierInteractions')::text AS modifier_interactions_array,
        (NULLIF(src."upsellInformation", '')::jsonb->'modifierImpressions')::text  AS modifier_impressions_array,
        src."loyaltyUser"                                                          AS loyalty_user_object,
        src."receiptDetails"                                                       AS receipt_details_object,
        src."kioskSource"                                                          AS kiosk_source_object,
        src."localCurrencyDetails"                                                 AS local_currency_details_object,
        src."orderIdentity"                                                        AS order_identity_object,
        src."totals"                                                               AS totals_object,
        src."totalsCents"                                                          AS totals_cents_object,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')               AS bronze_filepath,
        NULL::text                                                                 AS silver_transform_time,
        NULL::text                                                                 AS silver_folderpath,
        now()                                                                      AS sysinserttime,
        src."bronze_folderpath"                                                    AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_transaction_header h
          WHERE h.locationid          = src."locationId"
            AND h.transactionheaderid = src."id"
      );


    -- ================================================================
    -- 2. TRANSACTION PAYMENTS
    -- ================================================================
    INSERT INTO stg.silver_transaction_payment (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        payment_transactionid, payment_method, payment_status, payment_amount,
        payment_tender_id, payment_integration_id, payment_integration_label,
        payment_card_name, payment_card_number, is_amazon_one_payment,
        card_info_card_type, card_info_last_four, card_info_masked_card_number,
        card_info_zip_code, card_info_expiration_month, card_info_expiration_year,
        card_info_processor_auth_code, card_info_available_balance,
        payment_capture_details, payment_settlement_details,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime, bronze_folderpath
    )
    SELECT
        src."id"                                                        AS transactionheaderid,
        src."orderId"                                                   AS orderid,
        src."kioskSessionId"                                            AS ordersessionid,
        src."orderDate"                                                 AS orderdateutc,
        src."businessDate"                                              AS businessdate,
        src."_ts"                                                       AS syscosmosts,
        src."locationId"                                                AS locationid,
        src."kioskSource"::jsonb->>'kioskId'                            AS kioskid,
        src."kioskSource"::jsonb->>'name'                               AS kiosk_name,
        (src."kioskSource"::jsonb->>'kioskMode')::integer               AS kiosk_mode,
        src."isTestOrder"                                               AS is_test_order,
        pmt->>'transactionId'                                           AS payment_transactionid,
        pmt->>'paymentMethod'                                           AS payment_method,
        pmt->>'status'                                                  AS payment_status,
        (pmt->>'amount')::numeric(12,3)                                 AS payment_amount,
        pmt->>'tenderId'                                                AS payment_tender_id,
        pmt->>'paymentIntegrationId'                                    AS payment_integration_id,
        pmt->>'paymentIntegrationLabel'                                 AS payment_integration_label,
        pmt->>'paymentCardName'                                         AS payment_card_name,
        pmt->>'paymentCardNumber'                                       AS payment_card_number,
        (pmt->>'isAmazonOnePayment')::boolean                           AS is_amazon_one_payment,
        pmt->'tenderInfo'->'cardInfo'->>'cardType'                      AS card_info_card_type,
        pmt->'tenderInfo'->'cardInfo'->>'lastFour'                      AS card_info_last_four,
        pmt->'tenderInfo'->'cardInfo'->>'maskedCardNumber'              AS card_info_masked_card_number,
        pmt->'tenderInfo'->'cardInfo'->>'zipCode'                       AS card_info_zip_code,
        pmt->'tenderInfo'->'cardInfo'->>'expirationMonth'               AS card_info_expiration_month,
        pmt->'tenderInfo'->'cardInfo'->>'expirationYear'                AS card_info_expiration_year,
        pmt->'tenderInfo'->'cardInfo'->>'processorAuthCode'             AS card_info_processor_auth_code,
        (pmt->'tenderInfo'->'cardInfo'->>'availableBalance')::numeric(12,3) AS card_info_available_balance,
        pmt->>'captureDetails'                                          AS payment_capture_details,
        pmt->>'settlementDetails'                                       AS payment_settlement_details,
        src."type"                                                      AS order_completion_status,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')    AS bronze_filepath,
        NULL::text                                                      AS silver_transform_time,
        NULL::text                                                      AS silver_folderpath,
        now()                                                           AS sysinserttime,
        src."bronze_folderpath"                                         AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(NULLIF(src."paymentDetails", '')::jsonb) AS pmt
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_transaction_payment tp
          WHERE tp.locationid          = src."locationId"
            AND tp.transactionheaderid = src."id"
      );


    -- ================================================================
    -- 3. TRANSACTION ITEMS
    -- ================================================================
    INSERT INTO stg.silver_transaction_item (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, orderitemid, itemsessionid, menuitemid, menu_item_pos_id,
        itemname, categoryid, categoryname, category_pos_id,
        items_concept_id, items_concept_name,
        itemquantity, usd_itemunitprice, usd_total_item_price,
        cents_itemunitprice, cents_total_item_price,
        modifier_options, items_discount_id, is_items_discount_hidden_on_receipt,
        items_discounts, items_upsell_source, items_reward_source, items_special_request,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime, bronze_folderpath
    )
    SELECT
        src."id"                                                    AS transactionheaderid,
        src."orderId"                                               AS orderid,
        src."kioskSessionId"                                        AS ordersessionid,
        src."orderDate"                                             AS orderdateutc,
        src."businessDate"                                          AS businessdate,
        src."_ts"                                                   AS syscosmosts,
        src."locationId"                                            AS locationid,
        src."kioskSource"::jsonb->>'kioskId'                        AS kioskid,
        src."kioskSource"::jsonb->>'name'                           AS kiosk_name,
        (src."kioskSource"::jsonb->>'kioskMode')::integer           AS kiosk_mode,
        src."isTestOrder"                                           AS is_test_order,
        src."loyaltyUser"::jsonb->>'id'                             AS frequentcustomerid,
        item->>'orderItemId'                                        AS orderitemid,
        item->>'itemSessionId'                                      AS itemsessionid,
        item->>'menuItemId'                                         AS menuitemid,
        item->>'menuItemPosId'                                      AS menu_item_pos_id,
        item->>'name'                                               AS itemname,
        item->>'categoryId'                                         AS categoryid,
        item->>'categoryName'                                       AS categoryname,
        item->>'categoryPosId'                                      AS category_pos_id,
        item->>'conceptId'                                          AS items_concept_id,
        item->>'conceptName'                                        AS items_concept_name,
        (item->>'quantity')::integer                                AS itemquantity,
        (item->>'unitPrice')::numeric(12,3)                         AS usd_itemunitprice,
        (item->>'itemPrice')::numeric(12,3)                         AS usd_total_item_price,
        (item->>'unitPriceCents')::bigint                           AS cents_itemunitprice,
        (item->>'totalPriceCents')::bigint                          AS cents_total_item_price,
        (item->'options')::text                                     AS modifier_options,
        item->'discountSource'->>'discountId'                       AS items_discount_id,
        (item->'discountSource'->>'isHiddenOnReceipt')::boolean     AS is_items_discount_hidden_on_receipt,
        (item->'discounts')::text                                   AS items_discounts,
        (item->'upsellSource')::text                                AS items_upsell_source,
        item->>'rewardSource'                                       AS items_reward_source,
        item->>'specialRequest'                                     AS items_special_request,
        src."type"                                                  AS order_completion_status,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')                   AS bronze_filepath,
        NULL::text                                                                     AS silver_transform_time,
        NULL::text                                                                     AS silver_folderpath,
        now()                                                                          AS sysinserttime,
        src."bronze_folderpath"                                                        AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(NULLIF(src."items", '')::jsonb) AS item
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_transaction_item ti
          WHERE ti.locationid          = src."locationId"
            AND ti.transactionheaderid = src."id"
      );


    -- ================================================================
    -- 4. ITEM MODIFIERS
    -- ================================================================
    INSERT INTO stg.silver_item_modifiers (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, orderitemid, itemsessionid, menuitemid, menu_item_pos_id,
        itemname, categoryid, categoryname, category_pos_id,
        itemquantity, usd_itemunitprice, usd_total_item_price,
        cents_itemunitprice, cents_total_item_price,
        items_discount_id, is_items_discount_hidden_on_receipt,
        items_discounts, items_upsell_source, items_reward_source, items_special_request,
        items_concept_id, items_concept_name,
        options_modifierid, options_modifier_pos_id, options_modifiername, options_modifier_code,
        options_modifiergroupid, options_modifiergroupname, options_modifiergroup_pos_id,
        options_modifierquantity, options_modifierunitprice, options_total_modifierprice,
        modifier_freequantity, is_modifier_invisible, is_modifier_default,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime, bronze_folderpath
    )
    SELECT
        src."id"                                                    AS transactionheaderid,
        src."orderId"                                               AS orderid,
        src."kioskSessionId"                                        AS ordersessionid,
        src."orderDate"                                             AS orderdateutc,
        src."businessDate"                                          AS businessdate,
        src."_ts"                                                   AS syscosmosts,
        src."locationId"                                            AS locationid,
        src."kioskSource"::jsonb->>'kioskId'                        AS kioskid,
        src."kioskSource"::jsonb->>'name'                           AS kiosk_name,
        (src."kioskSource"::jsonb->>'kioskMode')::integer           AS kiosk_mode,
        src."isTestOrder"                                           AS is_test_order,
        src."loyaltyUser"::jsonb->>'id'                             AS frequentcustomerid,
        item->>'orderItemId'                                        AS orderitemid,
        item->>'itemSessionId'                                      AS itemsessionid,
        item->>'menuItemId'                                         AS menuitemid,
        item->>'menuItemPosId'                                      AS menu_item_pos_id,
        item->>'name'                                               AS itemname,
        item->>'categoryId'                                         AS categoryid,
        item->>'categoryName'                                       AS categoryname,
        item->>'categoryPosId'                                      AS category_pos_id,
        (item->>'quantity')::integer                                AS itemquantity,
        (item->>'unitPrice')::numeric(12,3)                         AS usd_itemunitprice,
        (item->>'itemPrice')::numeric(12,3)                         AS usd_total_item_price,
        (item->>'unitPriceCents')::bigint                           AS cents_itemunitprice,
        (item->>'totalPriceCents')::bigint                          AS cents_total_item_price,
        item->'discountSource'->>'discountId'                       AS items_discount_id,
        (item->'discountSource'->>'isHiddenOnReceipt')::boolean     AS is_items_discount_hidden_on_receipt,
        (item->'discounts')::text                                   AS items_discounts,
        (item->'upsellSource')::text                                AS items_upsell_source,
        item->>'rewardSource'                                       AS items_reward_source,
        item->>'specialRequest'                                     AS items_special_request,
        item->>'conceptId'                                          AS items_concept_id,
        item->>'conceptName'                                        AS items_concept_name,
        opt->>'modifierId'                                          AS options_modifierid,
        opt->>'modifierPosId'                                       AS options_modifier_pos_id,
        opt->>'name'                                                AS options_modifiername,
        opt->>'modifierCode'                                        AS options_modifier_code,
        opt->>'modifierGroupId'                                     AS options_modifiergroupid,
        opt->>'modifierGroupName'                                   AS options_modifiergroupname,
        opt->>'modifierGroupPosId'                                  AS options_modifiergroup_pos_id,
        (opt->>'quantity')::integer                                 AS options_modifierquantity,
        (opt->>'price')::numeric(12,3)                              AS options_modifierunitprice,
        (opt->>'totalPrice')::numeric(12,3)                         AS options_total_modifierprice,
        (opt->>'freeQuantity')::integer                             AS modifier_freequantity,
        (opt->>'isInvisible')::boolean                              AS is_modifier_invisible,
        (opt->>'isDefault')::boolean                                AS is_modifier_default,
        src."type"                                                  AS order_completion_status,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')                   AS bronze_filepath,
        NULL::text                                                                     AS silver_transform_time,
        NULL::text                                                                     AS silver_folderpath,
        now()                                                                          AS sysinserttime,
        src."bronze_folderpath"                                                        AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(NULLIF(src."items", '')::jsonb) AS item
    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(item->'options', '[]'::jsonb)) AS opt
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_item_modifiers im
          WHERE im.locationid          = src."locationId"
            AND im.transactionheaderid = src."id"
      );


    -- ================================================================
    -- 5. TRANSACTION COMBO ITEMS
    -- ================================================================
    INSERT INTO stg.silver_transaction_combo_items (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid,
        combo_id, combo_pos_id, combo_name, combo_order_item_id, combo_item_session_id,
        combo_concept_id, combo_concept_name,
        cents_combo_unit_price, cents_combo_total_price, combo_quantity, combo_special_request,
        combo_upsell_source, combo_reward_source,
        component_id, component_pos_id, component_name,
        component_item_order_item_id, component_item_menu_item_id, component_item_name,
        component_item_menu_item_pos_id, component_item_session_id,
        component_item_concept_id, component_item_concept_name, component_item_quantity,
        component_item_price, component_item_unit_price, component_item_cents_unit_price,
        component_item_total_price, component_item_cents_total_price,
        component_item_special_request, component_item_upsell_source, component_item_reward_source,
        component_item_discount_id, is_component_item_discount_hidden_on_receipt,
        component_item_discounts, component_selections_items,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime, bronze_folderpath
    )
    SELECT
        src."id"                                                              AS transactionheaderid,
        src."orderId"                                                         AS orderid,
        src."kioskSessionId"                                                  AS ordersessionid,
        src."orderDate"                                                       AS orderdateutc,
        src."businessDate"                                                    AS businessdate,
        src."_ts"                                                             AS syscosmosts,
        src."locationId"                                                      AS locationid,
        src."kioskSource"::jsonb->>'kioskId'                                  AS kioskid,
        src."kioskSource"::jsonb->>'name'                                     AS kiosk_name,
        (src."kioskSource"::jsonb->>'kioskMode')::integer                     AS kiosk_mode,
        src."isTestOrder"                                                     AS is_test_order,
        src."loyaltyUser"::jsonb->>'id'                                       AS frequentcustomerid,
        combo->>'comboId'                                                     AS combo_id,
        combo->>'comboPosId'                                                  AS combo_pos_id,
        combo->>'name'                                                        AS combo_name,
        combo->>'orderItemId'                                                 AS combo_order_item_id,
        combo->>'itemSessionId'                                               AS combo_item_session_id,
        combo->>'conceptId'                                                   AS combo_concept_id,
        combo->>'conceptName'                                                 AS combo_concept_name,
        (combo->>'unitPriceCents')::numeric::bigint                           AS cents_combo_unit_price,
        (combo->>'totalPriceCents')::numeric::bigint                          AS cents_combo_total_price,
        (combo->>'quantity')::integer                                         AS combo_quantity,
        combo->>'specialRequest'                                              AS combo_special_request,
        (combo->'upsellSource')::text                                         AS combo_upsell_source,
        combo->>'rewardSource'                                                AS combo_reward_source,
        cs->>'componentId'                                                    AS component_id,
        cs->>'componentPosId'                                                 AS component_pos_id,
        cs->>'name'                                                           AS component_name,
        cs->'item'->>'orderItemId'                                            AS component_item_order_item_id,
        cs->'item'->>'menuItemId'                                             AS component_item_menu_item_id,
        cs->'item'->>'name'                                                   AS component_item_name,
        cs->'item'->>'menuItemPosId'                                          AS component_item_menu_item_pos_id,
        cs->'item'->>'itemSessionId'                                          AS component_item_session_id,
        cs->'item'->>'conceptId'                                              AS component_item_concept_id,
        cs->'item'->>'conceptName'                                            AS component_item_concept_name,
        (cs->'item'->>'quantity')::integer                                    AS component_item_quantity,
        (cs->'item'->>'itemPrice')::numeric(12,3)                             AS component_item_price,
        (cs->'item'->>'unitPrice')::numeric(12,3)                             AS component_item_unit_price,
        ROUND((cs->'item'->>'unitPrice')::numeric * 100)::bigint              AS component_item_cents_unit_price,
        (cs->'item'->>'totalPrice')::numeric(12,3)                            AS component_item_total_price,
        ROUND((cs->'item'->>'totalPrice')::numeric * 100)::bigint             AS component_item_cents_total_price,
        cs->'item'->>'specialRequest'                                         AS component_item_special_request,
        (cs->'item'->'upsellSource')::text                                    AS component_item_upsell_source,
        cs->'item'->>'rewardSource'                                           AS component_item_reward_source,
        cs->'item'->'discountSource'->>'discountId'                           AS component_item_discount_id,
        (cs->'item'->'discountSource'->>'isHiddenOnReceipt')::boolean         AS is_component_item_discount_hidden_on_receipt,
        (cs->'item'->'discounts')::text                                       AS component_item_discounts,
        (cs->'items')::text                                                   AS component_selections_items,
        src."type"                                                            AS order_completion_status,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')                   AS bronze_filepath,
        NULL::text                                                                     AS silver_transform_time,
        NULL::text                                                                     AS silver_folderpath,
        now()                                                                          AS sysinserttime,
        src."bronze_folderpath"                                                        AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(NULLIF(src."combos", '')::jsonb) AS combo
    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(combo->'componentSelections', '[]'::jsonb)) AS cs
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_transaction_combo_items c
          WHERE c.locationid          = src."locationId"
            AND c.transactionheaderid = src."id"
      );


    -- ================================================================
    -- 6. UPSELL RECOMMENDATIONS
    -- ================================================================
    INSERT INTO stg.silver_upsell_recommendations (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, recommendationid, prompttimestamp, modal_version,
        offered_items, selected_items,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime, bronze_folderpath
    )
    SELECT
        src."id"                                            AS transactionheaderid,
        src."orderId"                                       AS orderid,
        src."kioskSessionId"                                AS ordersessionid,
        src."orderDate"                                     AS orderdateutc,
        src."businessDate"                                  AS businessdate,
        src."_ts"                                           AS syscosmosts,
        src."locationId"                                    AS locationid,
        src."kioskSource"::jsonb->>'kioskId'                AS kioskid,
        src."kioskSource"::jsonb->>'name'                   AS kiosk_name,
        (src."kioskSource"::jsonb->>'kioskMode')::integer   AS kiosk_mode,
        src."isTestOrder"                                   AS is_test_order,
        src."loyaltyUser"::jsonb->>'id'                     AS frequentcustomerid,
        prompt->>'promptId'                                 AS recommendationid,
        prompt->>'promptTime'                               AS prompttimestamp,
        prompt->>'modalVersion'                             AS modal_version,
        (prompt->'offeredItems')::text                      AS offered_items,
        (prompt->'selectedItems')::text                     AS selected_items,
        src."type"                                          AS order_completion_status,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')                   AS bronze_filepath,
        NULL::text                                                                     AS silver_transform_time,
        NULL::text                                                                     AS silver_folderpath,
        now()                                                                          AS sysinserttime,
        src."bronze_folderpath"                                                        AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(
        COALESCE(NULLIF(src."upsellInformation", '')::jsonb->'upsellPrompt', '[]'::jsonb)
    ) AS prompt
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_upsell_recommendations ur
          WHERE ur.locationid          = src."locationId"
            AND ur.transactionheaderid = src."id"
      );


    -- ================================================================
    -- 7. MODIFIER RECOMMENDATIONS
    -- ================================================================
    INSERT INTO stg.silver_modifier_recommendations (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, modifier_interactions, modifier_impressions,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime, bronze_folderpath
    )
    SELECT
        src."id"                                                                     AS transactionheaderid,
        src."orderId"                                                                AS orderid,
        src."kioskSessionId"                                                         AS ordersessionid,
        src."orderDate"                                                              AS orderdateutc,
        src."businessDate"                                                           AS businessdate,
        src."_ts"                                                                    AS syscosmosts,
        src."locationId"                                                             AS locationid,
        src."kioskSource"::jsonb->>'kioskId'                                         AS kioskid,
        src."kioskSource"::jsonb->>'name'                                            AS kiosk_name,
        (src."kioskSource"::jsonb->>'kioskMode')::integer                            AS kiosk_mode,
        src."isTestOrder"                                                            AS is_test_order,
        src."loyaltyUser"::jsonb->>'id'                                              AS frequentcustomerid,
        (NULLIF(src."upsellInformation", '')::jsonb->'modifierInteractions')::text   AS modifier_interactions,
        (NULLIF(src."upsellInformation", '')::jsonb->'modifierImpressions')::text    AS modifier_impressions,
        src."type"                                                                   AS order_completion_status,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')                  AS bronze_filepath,
        NULL::text                                                                   AS silver_transform_time,
        NULL::text                                                                   AS silver_folderpath,
        now()                                                                        AS sysinserttime,
        src."bronze_folderpath"                                                      AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_modifier_recommendations mr
          WHERE mr.locationid          = src."locationId"
            AND mr.transactionheaderid = src."id"
      );


    -- ================================================================
    -- 8. MODIFIER IMPRESSIONS
    -- ================================================================
    INSERT INTO stg.silver_modifier_impressions (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, menuitemid, parentmodifierid, selection_type,
        modifier_impressions_nesting_depth, modifier_impressions_context, strategy,
        modifierid, score, "position", selected, pre_selected, pre_deselected, confirmed_removed,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime, bronze_folderpath
    )
    SELECT
        src."id"                                            AS transactionheaderid,
        src."orderId"                                       AS orderid,
        src."kioskSessionId"                                AS ordersessionid,
        src."orderDate"                                     AS orderdateutc,
        src."businessDate"                                  AS businessdate,
        src."_ts"                                           AS syscosmosts,
        src."locationId"                                    AS locationid,
        src."kioskSource"::jsonb->>'kioskId'                AS kioskid,
        src."kioskSource"::jsonb->>'name'                   AS kiosk_name,
        (src."kioskSource"::jsonb->>'kioskMode')::integer   AS kiosk_mode,
        src."isTestOrder"                                   AS is_test_order,
        src."loyaltyUser"::jsonb->>'id'                     AS frequentcustomerid,
        imp->>'itemId'                                      AS menuitemid,
        imp->>'parentModifierId'                            AS parentmodifierid,
        imp->>'selectionType'                               AS selection_type,
        (imp->>'nestingDepth')::integer                     AS modifier_impressions_nesting_depth,
        (imp->'context')::text                              AS modifier_impressions_context,
        imp->>'strategy'                                    AS strategy,
        rec->>'modifierId'                                  AS modifierid,
        (rec->>'score')::integer                            AS score,
        (rec->>'position')::integer                         AS "position",
        (rec->>'selected')::boolean                         AS selected,
        (rec->>'preSelected')::boolean                      AS pre_selected,
        (rec->>'preDeselected')::boolean                    AS pre_deselected,
        (rec->>'confirmedRemoved')::boolean                 AS confirmed_removed,
        src."type"                                          AS order_completion_status,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')                   AS bronze_filepath,
        NULL::text                                                                     AS silver_transform_time,
        NULL::text                                                                     AS silver_folderpath,
        now()                                                                          AS sysinserttime,
        src."bronze_folderpath"                                                        AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(
        COALESCE(NULLIF(src."upsellInformation", '')::jsonb->'modifierImpressions', '[]'::jsonb)
    ) AS imp
    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(imp->'recommendations', '[]'::jsonb)) AS rec
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_modifier_impressions mi
          WHERE mi.locationid          = src."locationId"
            AND mi.transactionheaderid = src."id"
      );


    -- ================================================================
    -- 9. MODIFIER INTERACTIONS
    -- ================================================================
    INSERT INTO stg.silver_modifier_interactions (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, menuitemid, modifierid, modifiergroupid, parent_modifier_id,
        selection_type, modifier_interactions_action, modifier_interactions_recorded_at,
        modifier_interactions_nesting_depth,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime, bronze_folderpath
    )
    SELECT
        src."id"                                            AS transactionheaderid,
        src."orderId"                                       AS orderid,
        src."kioskSessionId"                                AS ordersessionid,
        src."orderDate"                                     AS orderdateutc,
        src."businessDate"                                  AS businessdate,
        src."_ts"                                           AS syscosmosts,
        src."locationId"                                    AS locationid,
        src."kioskSource"::jsonb->>'kioskId'                AS kioskid,
        src."kioskSource"::jsonb->>'name'                   AS kiosk_name,
        (src."kioskSource"::jsonb->>'kioskMode')::integer   AS kiosk_mode,
        src."isTestOrder"                                   AS is_test_order,
        src."loyaltyUser"::jsonb->>'id'                     AS frequentcustomerid,
        interaction->>'itemId'                              AS menuitemid,
        interaction->>'modifierId'                          AS modifierid,
        interaction->>'modifierGroupId'                     AS modifiergroupid,
        interaction->>'parentModifierId'                    AS parent_modifier_id,
        interaction->>'selectionType'                       AS selection_type,
        interaction->>'action'                              AS modifier_interactions_action,
        interaction->>'recordedAt'                          AS modifier_interactions_recorded_at,
        (interaction->>'nestingDepth')::integer             AS modifier_interactions_nesting_depth,
        src."type"                                          AS order_completion_status,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')                   AS bronze_filepath,
        NULL::text                                                                     AS silver_transform_time,
        NULL::text                                                                     AS silver_folderpath,
        now()                                                                          AS sysinserttime,
        src."bronze_folderpath"                                                        AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(
        COALESCE(NULLIF(src."upsellInformation", '')::jsonb->'modifierInteractions', '[]'::jsonb)
    ) AS interaction
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_modifier_interactions mi
          WHERE mi.locationid          = src."locationId"
            AND mi.transactionheaderid = src."id"
      );


    -- ================================================================
    -- 10. TRANSACTION REFUNDS
    -- ================================================================
    INSERT INTO stg.silver_transaction_refunds (
        locationid, transactionheaderid, orderid,
        original_transaction_id, refund_transaction_id, refund_type,
        refunded_amount, order_completion_status, orderdateutc, syscosmosts,
        bronze_filepath, silver_transform_time, silver_folderpath, sysinserttime, bronze_folderpath
    )
    SELECT
        src."locationId"                         AS locationid,
        src."id"                                 AS transactionheaderid,
        src."orderId"                            AS orderid,
        src."originalTransactionId"              AS original_transaction_id,
        src."refundTransactionId"                AS refund_transaction_id,
        src."refundType"                         AS refund_type,
        src."refundedAmount"::numeric(12,3)      AS refunded_amount,
        src."type"                               AS order_completion_status,
        src."orderDate"                          AS orderdateutc,
        src."_ts"                                AS syscosmosts,
        CONCAT('/', src."bronze_folderpath", '/', src."id", '.json')                   AS bronze_filepath,
        NULL::text                                                                     AS silver_transform_time,
        NULL::text                                                                     AS silver_folderpath,
        now()                                                                          AS sysinserttime,
        src."bronze_folderpath"                                                        AS bronze_folderpath
    FROM stg.silver_all_transaction_entities src
    WHERE (p_partition_path IS NULL OR src."bronze_folderpath" = p_partition_path)
      AND src."type" IN ('order-refund-amount', 'order-refund-transaction')
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_transaction_refunds r
          WHERE r.locationid          = src."locationId"
            AND r.transactionheaderid = src."id"
      );


    -- ================================================================
    -- FLUSH
    -- ================================================================
    IF p_partition_path IS NULL THEN
        TRUNCATE TABLE stg.silver_all_transaction_entities;
    ELSE
        DELETE FROM stg.silver_all_transaction_entities
        WHERE "bronze_folderpath" = p_partition_path;
    END IF;

END;
$BODY$;

ALTER PROCEDURE fact.usp_distribute_silver_transaction_entities(TEXT) OWNER TO citus;