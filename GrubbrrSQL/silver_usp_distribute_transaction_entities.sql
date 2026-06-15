--CALL fact.usp_distribute_silver_transaction_entities();

--TRUNCATE TABLE stg.silver_transaction_header

CREATE OR REPLACE PROCEDURE fact.usp_distribute_silver_transaction_entities()
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
        bronze_filepath, silver_transform_time, silver_folderpath, sysinserttime
    )
    SELECT
        src.id                                                                    AS transactionheaderid,
        src.order_id                                                              AS orderid,
        src.kiosk_session_id                                                      AS ordersessionid,
        src.order_date                                                            AS orderdateutc,
        src.business_date                                                         AS businessdate,
        src.syscosmosts                                                           AS syscosmosts,
        src.location_id                                                           AS locationid,
        src.kiosk_source::jsonb->>'kioskId'                                       AS kioskid,
        src.kiosk_source::jsonb->>'name'                                          AS kiosk_name,
        (src.kiosk_source::jsonb->>'kioskMode')::integer                          AS kiosk_mode,
        src.channel                                                               AS channel,
        src.items                                                                 AS items_array,
        src.payment_details                                                       AS payments_array,
        CASE
            WHEN COALESCE(jsonb_array_length(NULLIF(src.items, '')::jsonb), 0) = 0
            THEN COALESCE(jsonb_array_length(NULLIF(src.combos, '')::jsonb), 0)
            ELSE jsonb_array_length(NULLIF(src.items, '')::jsonb)
        END::smallint                                                             AS numberofitems,
        COALESCE(jsonb_array_length(NULLIF(src.payment_details, '')::jsonb), 0)
            ::smallint                                                            AS numberofpayments,
        src.concept_id                                                            AS concept_id,
        src.concept_name                                                          AS concept_name,
        src.order_type                                                            AS ordertype,
        src.order_type_label                                                      AS order_type_label,
        src.type                                                                  AS order_completion_status,
        src.pos_submission_status                                                 AS pos_submission_status,
        src.is_failed_to_send_to_pos                                             AS is_send_to_pos_failed,
        src.is_test_order                                                         AS is_test_order,
        src.loyalty_user::jsonb->>'id'                                            AS frequentcustomerid,
        src.order_identity::jsonb->>'name'                                        AS customername,
        src.client_ip_address                                                     AS client_ip_address,
        src.order_identity::jsonb->>'orderToken'                                  AS order_identity_order_token,
        src.order_identity::jsonb->>'posOrderToken'                               AS order_identity_pos_order_token,
        src.order_identity::jsonb->>'phone'                                       AS order_identity_phone,
        src.order_identity::jsonb->>'phoneCountryCode'                            AS order_identity_phone_country_code,
        src.order_identity::jsonb->>'email'                                       AS order_identity_email,
        src.order_identity::jsonb->>'tableTent'                                   AS order_identity_table_tent,
        src.order_identity::jsonb->>'deviceImei'                                  AS order_identity_device_imei,
        src.guest_count                                                           AS guest_count,
        src.receipt_details::jsonb->>'guestCheckCode'                             AS guest_check_code,
        (src.receipt_details::jsonb->'genesisFiscalFields')::text                 AS genesis_fiscal_fields,
        src.receipt_details::jsonb->>'orderLanguage'                              AS order_language,
        src.receipt_details::jsonb->>'receiptPrintingType'                        AS receipt_printing_type,
        src.loyalty_provider_transaction_id                                       AS loyalty_transaction_id,
        src.loyalty_provider_payment_transaction_id                               AS loyalty_payment_transaction_id,
        src.receipt_details::jsonb->>'loyaltyEarnedPoints'                        AS loyalty_earned_points,
        src.local_currency_details::jsonb->>'currencyCode'                        AS local_currency_code,
        src.local_currency_details::jsonb->>'additionalInfo'                      AS local_currency_additional_info,
        (src.totals::jsonb->>'total')::numeric(12,3)                              AS usd_amount,
        (src.totals::jsonb->>'subTotal')::numeric(12,3)                           AS usd_subtotal,
        (src.totals::jsonb->>'tax')::numeric(12,3)                                AS usd_tax,
        (src.totals::jsonb->>'tip')::numeric(12,3)                                AS usd_tip,
        (src.totals::jsonb->>'discount')::numeric(12,3)                           AS usd_discount,
        (src.totals::jsonb->>'reward')::numeric(12,3)                             AS usd_reward,
        (src.totals::jsonb->>'serviceCharge')::numeric(12,3)                      AS usd_service_charge,
        (src.totals::jsonb->>'charityAmount')::numeric(12,3)                      AS usd_charity_amount,
        (src.totals_cents::jsonb->>'total')::bigint                               AS cents_amount,
        (src.totals_cents::jsonb->>'subTotal')::bigint                            AS cents_subtotal,
        (src.totals_cents::jsonb->>'tax')::bigint                                 AS cents_tax,
        (src.totals_cents::jsonb->>'tip')::bigint                                 AS cents_tip,
        (src.totals_cents::jsonb->>'discount')::bigint                            AS cents_discount,
        (src.totals_cents::jsonb->>'reward')::bigint                              AS cents_reward,
        (src.totals_cents::jsonb->>'serviceCharge')::bigint                       AS cents_service_charge,
        (src.totals_cents::jsonb->>'charityAmount')::bigint                       AS cents_charity_amount,
        src.discounts                                                             AS discounts_array,
        src.combos                                                                AS combos_array,
        src.redeemed_rewards                                                      AS redeemed_rewards_array,
        src.concepts                                                              AS concepts_array,
        (NULLIF(src.upsell_information, '')::jsonb->'upsellPrompt')::text         AS upsell_prompt_array,
        (NULLIF(src.upsell_information, '')::jsonb->'modifierInteractions')::text AS modifier_interactions_array,
        (NULLIF(src.upsell_information, '')::jsonb->'modifierImpressions')::text  AS modifier_impressions_array,
        src.loyalty_user                                                          AS loyalty_user_object,
        src.receipt_details                                                       AS receipt_details_object,
        src.kiosk_source                                                          AS kiosk_source_object,
        src.local_currency_details                                                AS local_currency_details_object,
        src.order_identity                                                        AS order_identity_object,
        src.totals                                                                AS totals_object,
        src.totals_cents                                                          AS totals_cents_object,
        src.bronze_filepath                                                       AS bronze_filepath,
        NULL::text                                                                AS silver_transform_time,
        NULL::text                                                                AS silver_folderpath,
        now()                                                                     AS sysinserttime
    FROM stg.silver_all_transaction_entities src
    WHERE src.type = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_transaction_header h
          WHERE h.transactionheaderid = src.id
            AND h.locationid          = src.location_id
      );


    -- ================================================================
    -- 2. TRANSACTION ITEMS
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
        sysinserttime
    )
    SELECT
        src.id                                                   AS transactionheaderid,
        src.order_id                                             AS orderid,
        src.kiosk_session_id                                     AS ordersessionid,
        src.order_date                                           AS orderdateutc,
        src.business_date                                        AS businessdate,
        src.syscosmosts                                          AS syscosmosts,
        src.location_id                                          AS locationid,
        src.kiosk_source::jsonb->>'kioskId'                      AS kioskid,
        src.kiosk_source::jsonb->>'name'                         AS kiosk_name,
        (src.kiosk_source::jsonb->>'kioskMode')::integer         AS kiosk_mode,
        src.is_test_order                                        AS is_test_order,
        src.loyalty_user::jsonb->>'id'                           AS frequentcustomerid,
        item->>'orderItemId'                                     AS orderitemid,
        item->>'itemSessionId'                                   AS itemsessionid,
        item->>'menuItemId'                                      AS menuitemid,
        item->>'menuItemPosId'                                   AS menu_item_pos_id,
        item->>'name'                                            AS itemname,
        item->>'categoryId'                                      AS categoryid,
        item->>'categoryName'                                    AS categoryname,
        item->>'categoryPosId'                                   AS category_pos_id,
        item->>'conceptId'                                       AS items_concept_id,
        item->>'conceptName'                                     AS items_concept_name,
        (item->>'quantity')::integer                             AS itemquantity,
        (item->>'unitPrice')::numeric(12,3)                      AS usd_itemunitprice,
        (item->>'itemPrice')::numeric(12,3)                      AS usd_total_item_price,
        (item->>'unitPriceCents')::bigint                        AS cents_itemunitprice,
        (item->>'totalPriceCents')::bigint                       AS cents_total_item_price,
        (item->'options')::text                                  AS modifier_options,
        item->'discountSource'->>'discountId'                    AS items_discount_id,
        (item->'discountSource'->>'isHiddenOnReceipt')::boolean  AS is_items_discount_hidden_on_receipt,
        (item->'discounts')::text                                AS items_discounts,
        (item->'upsellSource')::text                             AS items_upsell_source,
        item->>'rewardSource'                                    AS items_reward_source,
        item->>'specialRequest'                                  AS items_special_request,
        src.type                                                 AS order_completion_status,
        src.bronze_filepath                                      AS bronze_filepath,
        NULL::text                                               AS silver_transform_time,
        NULL::text                                               AS silver_folderpath,
        now()                                                    AS sysinserttime
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(NULLIF(src.items, '')::jsonb) AS item
    WHERE src.type = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_transaction_item ti
          WHERE ti.transactionheaderid = src.id
            AND ti.locationid          = src.location_id
      );


    -- ================================================================
    -- 3. ITEM MODIFIERS
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
        sysinserttime
    )
    SELECT
        src.id                                                   AS transactionheaderid,
        src.order_id                                             AS orderid,
        src.kiosk_session_id                                     AS ordersessionid,
        src.order_date                                           AS orderdateutc,
        src.business_date                                        AS businessdate,
        src.syscosmosts                                          AS syscosmosts,
        src.location_id                                          AS locationid,
        src.kiosk_source::jsonb->>'kioskId'                      AS kioskid,
        src.kiosk_source::jsonb->>'name'                         AS kiosk_name,
        (src.kiosk_source::jsonb->>'kioskMode')::integer         AS kiosk_mode,
        src.is_test_order                                        AS is_test_order,
        src.loyalty_user::jsonb->>'id'                           AS frequentcustomerid,
        item->>'orderItemId'                                     AS orderitemid,
        item->>'itemSessionId'                                   AS itemsessionid,
        item->>'menuItemId'                                      AS menuitemid,
        item->>'menuItemPosId'                                   AS menu_item_pos_id,
        item->>'name'                                            AS itemname,
        item->>'categoryId'                                      AS categoryid,
        item->>'categoryName'                                    AS categoryname,
        item->>'categoryPosId'                                   AS category_pos_id,
        (item->>'quantity')::integer                             AS itemquantity,
        (item->>'unitPrice')::numeric(12,3)                      AS usd_itemunitprice,
        (item->>'itemPrice')::numeric(12,3)                      AS usd_total_item_price,
        (item->>'unitPriceCents')::bigint                        AS cents_itemunitprice,
        (item->>'totalPriceCents')::bigint                       AS cents_total_item_price,
        item->'discountSource'->>'discountId'                    AS items_discount_id,
        (item->'discountSource'->>'isHiddenOnReceipt')::boolean  AS is_items_discount_hidden_on_receipt,
        (item->'discounts')::text                                AS items_discounts,
        (item->'upsellSource')::text                             AS items_upsell_source,
        item->>'rewardSource'                                    AS items_reward_source,
        item->>'specialRequest'                                  AS items_special_request,
        item->>'conceptId'                                       AS items_concept_id,
        item->>'conceptName'                                     AS items_concept_name,
        opt->>'modifierId'                                       AS options_modifierid,
        opt->>'modifierPosId'                                    AS options_modifier_pos_id,
        opt->>'name'                                             AS options_modifiername,
        opt->>'modifierCode'                                     AS options_modifier_code,
        opt->>'modifierGroupId'                                  AS options_modifiergroupid,
        opt->>'modifierGroupName'                                AS options_modifiergroupname,
        opt->>'modifierGroupPosId'                               AS options_modifiergroup_pos_id,
        (opt->>'quantity')::integer                              AS options_modifierquantity,
        (opt->>'price')::numeric(12,3)                           AS options_modifierunitprice,
        (opt->>'totalPrice')::numeric(12,3)                      AS options_total_modifierprice,
        (opt->>'freeQuantity')::integer                          AS modifier_freequantity,
        (opt->>'isInvisible')::boolean                           AS is_modifier_invisible,
        (opt->>'isDefault')::boolean                             AS is_modifier_default,
        src.type                                                 AS order_completion_status,
        src.bronze_filepath                                      AS bronze_filepath,
        NULL::text                                               AS silver_transform_time,
        NULL::text                                               AS silver_folderpath,
        now()                                                    AS sysinserttime
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(NULLIF(src.items, '')::jsonb) AS item
    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(item->'options', '[]'::jsonb)) AS opt
    WHERE src.type = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_item_modifiers im
          WHERE im.transactionheaderid = src.id
            AND im.locationid          = src.location_id
      );


    -- ================================================================
    -- 4. TRANSACTION COMBO ITEMS
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
        sysinserttime
    )
    SELECT
        src.id                                                              AS transactionheaderid,
        src.order_id                                                        AS orderid,
        src.kiosk_session_id                                                AS ordersessionid,
        src.order_date                                                      AS orderdateutc,
        src.business_date                                                   AS businessdate,
        src.syscosmosts                                                     AS syscosmosts,
        src.location_id                                                     AS locationid,
        src.kiosk_source::jsonb->>'kioskId'                                 AS kioskid,
        src.kiosk_source::jsonb->>'name'                                    AS kiosk_name,
        (src.kiosk_source::jsonb->>'kioskMode')::integer                    AS kiosk_mode,
        src.is_test_order                                                   AS is_test_order,
        src.loyalty_user::jsonb->>'id'                                      AS frequentcustomerid,
        combo->>'comboId'                                                   AS combo_id,
        combo->>'comboPosId'                                                AS combo_pos_id,
        combo->>'name'                                                      AS combo_name,
        combo->>'orderItemId'                                               AS combo_order_item_id,
        combo->>'itemSessionId'                                             AS combo_item_session_id,
        combo->>'conceptId'                                                 AS combo_concept_id,
        combo->>'conceptName'                                               AS combo_concept_name,
        (combo->>'unitPriceCents')::numeric::bigint                         AS cents_combo_unit_price,
        (combo->>'totalPriceCents')::numeric::bigint                        AS cents_combo_total_price,
        (combo->>'quantity')::integer                                       AS combo_quantity,
        combo->>'specialRequest'                                            AS combo_special_request,
        (combo->'upsellSource')::text                                       AS combo_upsell_source,
        combo->>'rewardSource'                                              AS combo_reward_source,
        cs->>'componentId'                                                  AS component_id,
        cs->>'componentPosId'                                               AS component_pos_id,
        cs->>'name'                                                         AS component_name,
        cs->'item'->>'orderItemId'                                          AS component_item_order_item_id,
        cs->'item'->>'menuItemId'                                           AS component_item_menu_item_id,
        cs->'item'->>'name'                                                 AS component_item_name,
        cs->'item'->>'menuItemPosId'                                        AS component_item_menu_item_pos_id,
        cs->'item'->>'itemSessionId'                                        AS component_item_session_id,
        cs->'item'->>'conceptId'                                            AS component_item_concept_id,
        cs->'item'->>'conceptName'                                          AS component_item_concept_name,
        (cs->'item'->>'quantity')::integer                                  AS component_item_quantity,
        (cs->'item'->>'itemPrice')::numeric(12,3)                           AS component_item_price,
        (cs->'item'->>'unitPrice')::numeric(12,3)                           AS component_item_unit_price,
        ROUND((cs->'item'->>'unitPrice')::numeric * 100)::bigint            AS component_item_cents_unit_price,
        (cs->'item'->>'totalPrice')::numeric(12,3)                          AS component_item_total_price,
        ROUND((cs->'item'->>'totalPrice')::numeric * 100)::bigint           AS component_item_cents_total_price,
        cs->'item'->>'specialRequest'                                       AS component_item_special_request,
        (cs->'item'->'upsellSource')::text                                  AS component_item_upsell_source,
        cs->'item'->>'rewardSource'                                         AS component_item_reward_source,
        cs->'item'->'discountSource'->>'discountId'                         AS component_item_discount_id,
        (cs->'item'->'discountSource'->>'isHiddenOnReceipt')::boolean       AS is_component_item_discount_hidden_on_receipt,
        (cs->'item'->'discounts')::text                                     AS component_item_discounts,
        (cs->'items')::text                                                 AS component_selections_items,
        src.type                                                            AS order_completion_status,
        src.bronze_filepath                                                 AS bronze_filepath,
        NULL::text                                                          AS silver_transform_time,
        NULL::text                                                          AS silver_folderpath,
        now()                                                               AS sysinserttime
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(NULLIF(src.combos, '')::jsonb) AS combo
    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(combo->'componentSelections', '[]'::jsonb)) AS cs
    WHERE src.type = 'order-placed'
    AND NOT EXISTS (
        SELECT 1 FROM stg.silver_transaction_combo_items c
        WHERE c.transactionheaderid = src.id
            AND c.locationid          = src.location_id
    );



    -- ================================================================
    -- 5. UPSELL RECOMMENDATIONS
    -- ================================================================
    INSERT INTO stg.silver_upsell_recommendations (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, recommendationid, prompttimestamp, modal_version,
        offered_items, selected_items,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime
    )
    SELECT
        src.id                                           AS transactionheaderid,
        src.order_id                                     AS orderid,
        src.kiosk_session_id                             AS ordersessionid,
        src.order_date                                   AS orderdateutc,
        src.business_date                                AS businessdate,
        src.syscosmosts                                  AS syscosmosts,
        src.location_id                                  AS locationid,
        src.kiosk_source::jsonb->>'kioskId'              AS kioskid,
        src.kiosk_source::jsonb->>'name'                 AS kiosk_name,
        (src.kiosk_source::jsonb->>'kioskMode')::integer AS kiosk_mode,
        src.is_test_order                                AS is_test_order,
        src.loyalty_user::jsonb->>'id'                   AS frequentcustomerid,
        prompt->>'promptId'                              AS recommendationid,
        prompt->>'promptTime'                            AS prompttimestamp,
        prompt->>'modalVersion'                          AS modal_version,
        (prompt->'offeredItems')::text                   AS offered_items,
        (prompt->'selectedItems')::text                  AS selected_items,
        src.type                                         AS order_completion_status,
        src.bronze_filepath                              AS bronze_filepath,
        NULL::text                                       AS silver_transform_time,
        NULL::text                                       AS silver_folderpath,
        now()                                            AS sysinserttime
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(
        COALESCE(NULLIF(src.upsell_information, '')::jsonb->'upsellPrompt', '[]'::jsonb)
    ) AS prompt
    WHERE src.type = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_upsell_recommendations ur
          WHERE ur.transactionheaderid = src.id
            AND ur.locationid          = src.location_id
      );


    -- ================================================================
    -- 6. MODIFIER RECOMMENDATIONS
    -- ================================================================
    INSERT INTO stg.silver_modifier_recommendations (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, modifier_interactions, modifier_impressions,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime
    )
    SELECT
        src.id                                                                    AS transactionheaderid,
        src.order_id                                                              AS orderid,
        src.kiosk_session_id                                                      AS ordersessionid,
        src.order_date                                                            AS orderdateutc,
        src.business_date                                                         AS businessdate,
        src.syscosmosts                                                           AS syscosmosts,
        src.location_id                                                           AS locationid,
        src.kiosk_source::jsonb->>'kioskId'                                       AS kioskid,
        src.kiosk_source::jsonb->>'name'                                          AS kiosk_name,
        (src.kiosk_source::jsonb->>'kioskMode')::integer                          AS kiosk_mode,
        src.is_test_order                                                         AS is_test_order,
        src.loyalty_user::jsonb->>'id'                                            AS frequentcustomerid,
        (NULLIF(src.upsell_information, '')::jsonb->'modifierInteractions')::text AS modifier_interactions,
        (NULLIF(src.upsell_information, '')::jsonb->'modifierImpressions')::text  AS modifier_impressions,
        src.type                                                                  AS order_completion_status,
        src.bronze_filepath                                                       AS bronze_filepath,
        NULL::text                                                                AS silver_transform_time,
        NULL::text                                                                AS silver_folderpath,
        now()                                                                     AS sysinserttime
    FROM stg.silver_all_transaction_entities src
    WHERE src.type = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_modifier_recommendations mr
          WHERE mr.transactionheaderid = src.id
            AND mr.locationid          = src.location_id
      );


    -- ================================================================
    -- 7. MODIFIER IMPRESSIONS
    -- ================================================================
    INSERT INTO stg.silver_modifier_impressions (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, menuitemid, parentmodifierid, selection_type,
        modifier_impressions_nesting_depth, modifier_impressions_context, strategy,
        modifierid, score, "position", selected, pre_selected, pre_deselected, confirmed_removed,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime
    )
    SELECT
        src.id                                           AS transactionheaderid,
        src.order_id                                     AS orderid,
        src.kiosk_session_id                             AS ordersessionid,
        src.order_date                                   AS orderdateutc,
        src.business_date                                AS businessdate,
        src.syscosmosts                                  AS syscosmosts,
        src.location_id                                  AS locationid,
        src.kiosk_source::jsonb->>'kioskId'              AS kioskid,
        src.kiosk_source::jsonb->>'name'                 AS kiosk_name,
        (src.kiosk_source::jsonb->>'kioskMode')::integer AS kiosk_mode,
        src.is_test_order                                AS is_test_order,
        src.loyalty_user::jsonb->>'id'                   AS frequentcustomerid,
        imp->>'itemId'                                   AS menuitemid,
        imp->>'parentModifierId'                         AS parentmodifierid,
        imp->>'selectionType'                            AS selection_type,
        (imp->>'nestingDepth')::integer                  AS modifier_impressions_nesting_depth,
        (imp->'context')::text                           AS modifier_impressions_context,
        imp->>'strategy'                                 AS strategy,
        rec->>'modifierId'                               AS modifierid,
        (rec->>'score')::integer                         AS score,
        (rec->>'position')::integer                      AS "position",
        (rec->>'selected')::boolean                      AS selected,
        (rec->>'preSelected')::boolean                   AS pre_selected,
        (rec->>'preDeselected')::boolean                 AS pre_deselected,
        (rec->>'confirmedRemoved')::boolean              AS confirmed_removed,
        src.type                                         AS order_completion_status,
        src.bronze_filepath                              AS bronze_filepath,
        NULL::text                                       AS silver_transform_time,
        NULL::text                                       AS silver_folderpath,
        now()                                            AS sysinserttime
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(
        COALESCE(NULLIF(src.upsell_information, '')::jsonb->'modifierImpressions', '[]'::jsonb)
    ) AS imp
    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(imp->'recommendations', '[]'::jsonb)) AS rec
    WHERE src.type = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_modifier_impressions mi
          WHERE mi.locationid          = src.location_id 
            AND mi.transactionheaderid = src.id
      );


    -- ================================================================
    -- 8. MODIFIER INTERACTIONS
    -- ================================================================
    INSERT INTO stg.silver_modifier_interactions (
        transactionheaderid, orderid, ordersessionid, orderdateutc, businessdate,
        syscosmosts, locationid, kioskid, kiosk_name, kiosk_mode, is_test_order,
        frequentcustomerid, menuitemid, modifierid, modifiergroupid, parent_modifier_id,
        selection_type, modifier_interactions_action, modifier_interactions_recorded_at,
        modifier_interactions_nesting_depth,
        order_completion_status, bronze_filepath, silver_transform_time, silver_folderpath,
        sysinserttime
    )
    SELECT
        src.id                                           AS transactionheaderid,
        src.order_id                                     AS orderid,
        src.kiosk_session_id                             AS ordersessionid,
        src.order_date                                   AS orderdateutc,
        src.business_date                                AS businessdate,
        src.syscosmosts                                  AS syscosmosts,
        src.location_id                                  AS locationid,
        src.kiosk_source::jsonb->>'kioskId'              AS kioskid,
        src.kiosk_source::jsonb->>'name'                 AS kiosk_name,
        (src.kiosk_source::jsonb->>'kioskMode')::integer AS kiosk_mode,
        src.is_test_order                                AS is_test_order,
        src.loyalty_user::jsonb->>'id'                   AS frequentcustomerid,
        interaction->>'itemId'                           AS menuitemid,
        interaction->>'modifierId'                       AS modifierid,
        interaction->>'modifierGroupId'                  AS modifiergroupid,
        interaction->>'parentModifierId'                 AS parent_modifier_id,
        interaction->>'selectionType'                    AS selection_type,
        interaction->>'action'                           AS modifier_interactions_action,
        interaction->>'recordedAt'                       AS modifier_interactions_recorded_at,
        (interaction->>'nestingDepth')::integer          AS modifier_interactions_nesting_depth,
        src.type                                         AS order_completion_status,
        src.bronze_filepath                              AS bronze_filepath,
        NULL::text                                       AS silver_transform_time,
        NULL::text                                       AS silver_folderpath,
        now()                                            AS sysinserttime
    FROM stg.silver_all_transaction_entities src
    CROSS JOIN LATERAL jsonb_array_elements(
        COALESCE(NULLIF(src.upsell_information, '')::jsonb->'modifierInteractions', '[]'::jsonb)
    ) AS interaction
    WHERE src.type = 'order-placed'
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_modifier_interactions mi
          WHERE mi.locationid          = src.location_id 
            AND mi.transactionheaderid = src.id
      );


    -- ================================================================
    -- 9. TRANSACTION REFUNDS
    -- ================================================================
    INSERT INTO stg.silver_transaction_refunds (
        locationid, transactionheaderid, orderid,
        original_transaction_id, refund_transaction_id, refund_type,
        refunded_amount, order_completion_status, orderdateutc, syscosmosts,
        bronze_filepath, silver_transform_time, silver_folderpath, sysinserttime
    )
    SELECT
        src.location_id                    AS locationid,
        src.id                             AS transactionheaderid,
        src.order_id                       AS orderid,
        src.original_transaction_id        AS original_transaction_id,
        src.refund_transaction_id          AS refund_transaction_id,
        src.refund_type                    AS refund_type,
        src.refunded_amount::numeric(12,3) AS refunded_amount,
        src.type                           AS order_completion_status,
        src.order_date                     AS orderdateutc,
        src.syscosmosts                    AS syscosmosts,
        src.bronze_filepath                AS bronze_filepath,
        NULL::text                         AS silver_transform_time,
        NULL::text                         AS silver_folderpath,
        now()                              AS sysinserttime
    FROM stg.silver_all_transaction_entities src
    WHERE src.type IN ('order-refund-amount', 'order-refund-transaction')
      AND NOT EXISTS (
          SELECT 1 FROM stg.silver_transaction_refunds r
          WHERE r.locationid          = src.location_id 
            AND r.transactionheaderid = src.id
      );


    -- ================================================================
    -- FLUSH
    -- ================================================================
    TRUNCATE TABLE stg.silver_all_transaction_entities;

END;
$BODY$;

ALTER PROCEDURE fact.usp_distribute_silver_transaction_entities() OWNER TO citus;