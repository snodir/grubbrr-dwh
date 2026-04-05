--
-- PostgreSQL database dump
--

\restrict Srh6knFxTdux5gILLBr4yu6OgvQbV8H56pAanBIG5Ty7bEoQYIFezJt3D4Ud6IL

-- Dumped from database version 16.9 (Ubuntu 16.9-1.pgdg20.04+1)
-- Dumped by pg_dump version 18.2

-- Started on 2026-04-05 21:17:43

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 55 (class 2615 OID 32802)
-- Name: dim; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA dim;


ALTER SCHEMA dim OWNER TO citus;

--
-- TOC entry 56 (class 2615 OID 32810)
-- Name: fact; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA fact;


ALTER SCHEMA fact OWNER TO citus;

--
-- TOC entry 52 (class 2615 OID 420272)
-- Name: stg; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA stg;


ALTER SCHEMA stg OWNER TO citus;

--
-- TOC entry 953 (class 1255 OID 740034)
-- Name: array_to_text(jsonb); Type: FUNCTION; Schema: dim; Owner: citus
--

CREATE FUNCTION dim.array_to_text(a jsonb) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
        RETURN initcap(replace(replace(replace((a :: text), '[', ''), ']', ''), '"', ''));
END;
$$;


ALTER FUNCTION dim.array_to_text(a jsonb) OWNER TO citus;

--
-- TOC entry 571 (class 1255 OID 748068)
-- Name: is_valid_jsonb(text); Type: FUNCTION; Schema: dim; Owner: citus
--

CREATE FUNCTION dim.is_valid_jsonb(input text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  PERFORM input::jsonb;
  RETURN TRUE;
EXCEPTION WHEN others THEN
  RETURN FALSE;
END;
$$;


ALTER FUNCTION dim.is_valid_jsonb(input text) OWNER TO citus;

--
-- TOC entry 725 (class 1255 OID 735591)
-- Name: usp_grubbrr_install_base(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_grubbrr_install_base()
    LANGUAGE sql
    AS $$

TRUNCATE table dim.vw_grubbrrinstallbase;

WITH order_types_identities as (
SELECT 
    locationid,
    order_type.order_key :: TEXT as order_type_id,
    (order_type.order_data ->> 'label') :: TEXT as label,
    (order_type.order_data ->> 'externalDeliveryMode') :: TEXT as external_delivery_mode,
    (order_type.order_data ->> 'enabled') :: BOOLEAN as order_type_enabled,
    (order_type.order_data ->> 'posChannel') :: TEXT as pos_channel,
    (order_type.order_data -> 'orderIdentity' ->> 'orderIdentityMode') :: INTEGER as order_identity_mode,
    (order_type.order_data -> 'orderIdentity' ->> 'customerIdentityMode') :: INTEGER as customer_identity_mode,
    (order_type.order_data -> 'orderIdentity' -> 'customerIdentityModes') :: jsonb as customer_identity_modes,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'askBeforeOrder') :: BOOLEAN as ask_before_order,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeCustomerNameOptional') :: BOOLEAN as make_customer_name_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makePhoneNumberOptional') :: BOOLEAN as make_phone_number_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeEmailOptional') :: BOOLEAN as make_email_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeDateOfBirthOptional') :: BOOLEAN as make_date_of_birth_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeLastFourSsnOptional') :: BOOLEAN as make_last_four_ssn_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeAddressLine1Optional') :: BOOLEAN as make_address_line1_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeAddressLine2Optional') :: BOOLEAN as make_address_line2_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeCityOptional') :: BOOLEAN as make_city_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeStateOptional') :: BOOLEAN as make_state_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeZipCodeOptional') :: BOOLEAN as make_zipcode_optional,
    (order_type.order_data -> 'orderIdentity' -> 'nameIdSettings' ->> 'makeCountryOptional') :: BOOLEAN as make_country_optional
from (select locationid, order_types from dim.kioskdetails WHERE dim.is_valid_jsonb(order_types)) as kd
cross join LATERAL jsonb_each(kd.order_types :: jsonb -> 'options') AS order_type(order_key, order_data)
), json_order_types as (
SELECT locationid,
jsonb_build_object('order_type_id', order_type_id,
                   'label', label,
                   'external_delivery_mode', external_delivery_mode,
                   'order_type_enabled', order_type_enabled,
                   'pos_channel', pos_channel,
                   'order_identity_mode', order_identity_mode,
                   'customer_identity_mode', customer_identity_mode,
                   'customer_identity_modes', customer_identity_modes,
                   'ask_before_order', ask_before_order,
                   'make_customer_name_optional', make_customer_name_optional,
                   'make_phone_number_optional', make_phone_number_optional,
                   'make_email_optional', make_email_optional,
                   'make_date_of_birth_optional', make_date_of_birth_optional, 
                   'make_last_four_ssn_optional', make_last_four_ssn_optional,
                   'make_address_line1_optional', make_address_line1_optional,
                   'make_address_line2_optional', make_address_line2_optional,
                   'make_city_optional', make_city_optional,
                   'make_state_optional', make_state_optional,
                   'make_zipcode_optional', make_zipcode_optional,
                   'make_country_optional', make_country_optional) as order_type_config
FROM order_types_identities
), array_order_types as (
SELECT locationid, to_jsonb(array_agg(order_type_config)) as order_types_identity_config
FROM json_order_types
GROUP BY locationid
), device_details as (
SELECT 
    kiosk_entry.kiosk_key :: TEXT AS kiosk_id,
    (kiosk_entry.kiosk_data ->> 'name') as kiosk_name,
    (kiosk_entry.kiosk_data ->> 'kioskHardwareId') as kiosk_hardware_id,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'appVersion') as kiosk_software_version,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'deviceType') as os_type,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'serialNumber') as serial_number,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'lastLoginTime') :: TIMESTAMP as last_login_time,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'testMode') :: BOOLEAN as is_test_mode,
    (kiosk_entry.kiosk_data ->> 'lastSync') :: TIMESTAMP as last_sync_time,
    (kiosk_entry.kiosk_data ->> 'isDemoDevice') :: BOOLEAN as is_demo_kiosk,
    (kiosk_entry.kiosk_data ->> 'isTestModeOn') :: BOOLEAN as is_test_mode_on,
    kd.locationid as location_id,
    (kiosk_entry.kiosk_data ->> 'companyId') as organization_id,
    (kiosk_entry.kiosk_data ->> 'activated') :: BOOLEAN as is_activated,
    (kiosk_entry.kiosk_data -> 'paymentIntegrationConfigs') :: jsonb as payment_integration_configs,
    (kiosk_entry.kiosk_data -> 'printerConfigurations') :: jsonb as printer_configs,
    (kiosk_entry.kiosk_data ->> 'kioskActivation') :: INTEGER as kiosk_activation,
    (kiosk_entry.kiosk_data ->> 'kioskMode') :: INTEGER as kiosk_mode,
    (kiosk_entry.kiosk_data ->> 'kioskLogging') :: INTEGER as kiosk_logging,
    (kiosk_entry.kiosk_data ->> 'isGoastKisok') :: BOOLEAN as is_goast_kiosk,
    (kiosk_entry.kiosk_data ->> 'loyaltyLoginOtp') as loyalty_login_otp,
    kd.pos_provider :: jsonb as pos_provider,
    kd.loyalty_provider :: jsonb as loyalty_provider,
    kd.payment_provider :: jsonb as payment_provider,
    kd.scanners :: jsonb as scanners,
    kd.item_special_request :: jsonb as item_special_request,
    kd.legal_copy_enabled :: BOOLEAN as legal_copy_enabled,
    kd.ada_configuration :: jsonb as ada_configuration,
    kd.calculate_default_modifier_price :: BOOLEAN as calculate_default_modifier_price,
    kd.track_kiosk_user_behavior :: BOOLEAN as track_kiosk_user_behavior,
    kd.loyalty_feature :: BOOLEAN as loyalty_feature,
    kd.pickup_flow :: BOOLEAN as pickup_flow,
    kd.pos_auto_applied_discount :: BOOLEAN as pos_auto_applied_discount,
    kd.search_functionality_enabled :: BOOLEAN as search_functionality_enabled,
    kd.recent_orders_enabled :: BOOLEAN as recent_orders_enabled,
    kd.play_card_config :: jsonb as play_card_config,
    kd.round_up_for_charity :: BOOLEAN as round_up_for_charity,
    kd.calories_enabled :: BOOLEAN as calories_enabled,
    kd.scan_and_go_enabled :: BOOLEAN as scan_and_go_enabled,
    kd.age_verification :: jsonb as age_verification,
    (kd.tips_settings :: jsonb ->> 'enableTips') :: BOOLEAN as tips_enabled,
    (kd.tips_settings :: jsonb ->> 'applyBeforeTaxes') :: BOOLEAN as apply_before_taxes,
    (kd.kiosk_receipt_settings :: jsonb ->> 'autoPrint') :: BOOLEAN as auto_print_enabled,
    (kd.kiosk_receipt_settings :: jsonb ->> 'includePosOrderNumber') :: BOOLEAN as include_pos_order_number,
    (kd.kiosk_receipt_settings :: jsonb ->> 'showQrCodeWhenPrintReceiptFails') :: BOOLEAN as show_qr_code_when_print_receipt_fails,
    (kd.kiosk_receipt_settings :: jsonb -> 'receiptVisibilityOptions' ->> 'modifierGroupNames') :: BOOLEAN as print_modifier_group_names,
    (kd.kiosk_receipt_settings :: jsonb -> 'receiptVisibilityOptions' ->> 'defaultModifiers') :: BOOLEAN as print_default_modifiers,
    (kd.kiosk_receipt_settings :: jsonb -> 'receiptVisibilityOptions' ->> 'freeModifiers') :: BOOLEAN as print_free_modifiers,
    (kd.kiosk_receipt_settings :: jsonb -> 'receiptVisibilityOptions' ->> 'pricedModifiers') :: BOOLEAN as print_priced_modifiers,
    (kd.kiosk_receipt_settings :: jsonb -> 'emailSettings' ->> 'enableEmailReceipt') :: BOOLEAN as enable_email_receipts,
    (kd.kiosk_receipt_settings :: jsonb -> 'smsSetting' ->> 'enableSmsReceipt') :: BOOLEAN as enable_sms_receipt,
    (kd.kiosk_receipt_settings :: jsonb -> 'showQrCodeForReceiptUrl') :: BOOLEAN as qr_code_for_receipt,
    (kd.business_hours_config :: jsonb -> 'message' ->> 'showScreensaver') :: BOOLEAN as show_screensaver,
    (kd.business_hours_config :: jsonb ->> 'showMessage') :: BOOLEAN as business_hours_show_message,
    (kd.business_hours_config :: jsonb ->> 'enabled') :: BOOLEAN as business_hours_enabled,
    (kd.business_hours_config :: jsonb ->> 'posHoursEnabled') :: BOOLEAN as pos_hours_enabled,
    (kd.order_limit_config :: jsonb ->> 'quantityLimitPerItem') :: INTEGER as quantity_limit_per_item,
    (kd.order_limit_config :: jsonb ->> 'quantityLimitPerOrder') :: INTEGER as quantity_limit_per_order,
    (kd.order_limit_config :: jsonb ->> 'maxDiscountPerOrder') :: INTEGER as max_discount_per_order,
    (kd.order_limit_config :: jsonb ->> 'showItemAsIsOption') :: BOOLEAN as show_item_asis_option,
    (kd.order_limit_config :: jsonb ->> 'enableMinimumOrderTotal') :: BOOLEAN as enable_minimum_order_total,
    (kd.order_limit_config :: jsonb ->> 'autoApplyMinQtyToFirstModifier') :: BOOLEAN as auto_apply_min_qty_to_first_modifier,
    (kd.order_limit_config :: jsonb ->> 'showMakeItAMealOption') :: BOOLEAN as show_make_it_a_meal_option,
    (kd.order_limit_config :: jsonb ->> 'enableComboAutoSkip') :: BOOLEAN as enable_combo_auto_skip,
    (kd.order_limit_config :: jsonb ->> 'countToShowPromptsForItemUpsell') :: INTEGER as number_of_item_upsell_prompts_per_order,
    (kd.order_limit_config :: jsonb -> 'discountOrderingOptions' ->> 'canEnterCode') :: BOOLEAN as can_enter_code_for_discount,
    (kd.order_limit_config :: jsonb -> 'discountOrderingOptions' ->> 'canScanQRCode') :: BOOLEAN as can_scan_qr_code_for_discount,
    (kd.order_limit_config :: jsonb -> 'discountOrderingOptions' ->> 'canSelectFromList') :: BOOLEAN as can_select_from_list_for_discount,
    to_jsonb(array(select jsonb_object_keys(kd.kiosk_appearance_text_overrides :: jsonb -> 'strings'))) as enabled_languages,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'displayModifierGroupRestrictions') :: BOOLEAN as display_modifier_group_restriction,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'allowUserToCollapseOrExpandModifierGroups') :: BOOLEAN as allow_user_to_collapse_or_expand_modifier_groups,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'showModifierGroupNamesOrderReview') :: BOOLEAN as show_modifier_group_names_on_order_review,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'orderReviewShowDefaultModifiers') :: BOOLEAN as show_default_modifier_on_order_review,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'autoExpandModifierGorup') :: BOOLEAN as auto_expand_modifier_group,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'showFullPremiumModifierPrice') :: BOOLEAN as show_full_premium_modifier_price,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'enableNestedModifierIndentation') :: BOOLEAN as enable_nested_modifier_indentation,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'openNestedModifiersInPopup') :: BOOLEAN as open_nested_modifiers_in_popup,
    kd.kiosk_appearance_style_options :: jsonb ->> 'categoryHeaderDisplayMode' as category_header_display_mode,
    kd.kiosk_appearance_style_options :: jsonb ->> 'categoryHeaderLogoDisplayMode' as category_header_logo_display_mode,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'showCategoryHighlightedColor') :: BOOLEAN as show_category_highlighted_color,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'showItemDescriptions') :: BOOLEAN as show_item_description,
    kd.kiosk_appearance_style_options :: jsonb ->> 'categoryNamePostition' as category_name_position,
    (kd.kiosk_appearance_style_options :: jsonb -> 'kioskMenuAppearanceOptions' ->> 'hideSoldOutItemAndModifierOnKiosk') :: BOOLEAN as hide_sold_out_item_and_modifier_on_kiosk,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'makeCategorySideTranslucent') :: BOOLEAN as make_category_sidebar_translucent,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'enableSingleStepSubcategoryFlow') :: BOOLEAN as enable_single_step_subcategory_flow,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'removeCategoryHighLightedBorder') :: BOOLEAN as remove_category_highlighted_border,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'enableExtendedComboMode') :: BOOLEAN as enable_extended_combo_mode,
    kd.kiosk_appearance_style_options :: jsonb ->> 'buttonStyle' as button_style,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'showDiscountCodeButton') :: BOOLEAN as show_discount_code_button,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'makeItemComboImagesRounded') :: BOOLEAN as make_item_combo_images_rounded,
    (kd.kiosk_appearance_style_options :: jsonb ->> 'showLoyaltyPointsOnHeader') :: BOOLEAN as show_loyalty_points_on_header,
    (kd.kiosk_appearance_style_options :: jsonb -> 'kioskStyleAcceptedPaymentOptions' ->> 'showCard') :: BOOLEAN as show_card_accepted_payment_options,
    (kd.kiosk_appearance_style_options :: jsonb -> 'kioskStyleAcceptedPaymentOptions' ->> 'showGooglePay') :: BOOLEAN as show_google_pay_accepted_payment_options,
    (kd.kiosk_appearance_style_options :: jsonb -> 'kioskStyleAcceptedPaymentOptions' ->> 'showApplePay') :: BOOLEAN as show_apple_pay_accepted_payment_options,
    (kd.kiosk_appearance_style_options :: jsonb -> 'kioskStyleAcceptedPaymentOptions' ->> 'showCash') :: BOOLEAN as show_cash_accepted_payment_options,
    (kd.kiosk_appearance_style_options :: jsonb -> 'tapToOrderSetting' ->> 'showTapToOrderCTA') :: BOOLEAN as show_tap_to_order_cta,
    (kd.kiosk_appearance_style_options :: jsonb -> 'tapToOrderSetting' ->> 'useTextForCTA') :: BOOLEAN as use_text_for_cta,
    (kd.kiosk_appearance_style_options :: jsonb -> 'tapToOrderSetting' ->> 'useImageForCTA') :: BOOLEAN as use_image_for_cta,
    (kd.localization :: jsonb -> 'currency') :: jsonb as choose_a_currency,
    kd.localization :: jsonb -> 'locale' ->> 'code' as choose_a_locale,
    (kd.order_types :: jsonb -> 'orderTokenSettings' ->> 'orderNumberStart') :: INTEGER as order_number_start,
    (kd.order_types :: jsonb -> 'orderTokenSettings' ->> 'allotment') :: INTEGER as allotment,
    (kd.menu_behavior_config :: jsonb -> 'negativeModifierBehavior') :: jsonb as negative_modifier_behavior,
    kd.disclaimer_text,
    kd.preorder_popup_enabled,
    kd.preorder_popup_text,
    kd.perform_pos_status_check,
    kd.sysinserttime
from (select * from dim.kioskdetails WHERE dim.is_valid_jsonb(kiosks)) as kd
cross join LATERAL jsonb_each(kd.kiosks :: jsonb) AS kiosk_entry(kiosk_key, kiosk_data)
), total as (
select distinct  
       ol.organizationid as organization_id,
       ol.organizationname as organization_name,
       ol.locationid as location_id,
       ol.locationname as location_name,
       dd.kiosk_id,
       dd.kiosk_name,
       case when dd.kiosk_hardware_id like 'kiosk-hardware-%' then substring(dd.kiosk_hardware_id, 16, length(dd.kiosk_hardware_id)) else dd.kiosk_hardware_id end kiosk_hardware_id,
       dd.kiosk_software_version,
       dd.os_type,
       dd.serial_number,
       dd.is_test_mode,
       dd.is_demo_kiosk,
       dd.is_test_mode_on,
       dd.last_login_time,
       dd.last_sync_time,
       k.devicecreatedon as device_created_on,
       k.devicedeletedon as device_deleted_on,
       k.istestkiosk as is_test_kiosk,
       k.devicetype as device_type,
       dd.is_activated,
       dd.payment_integration_configs,
       dd.printer_configs,
       case dd.kiosk_activation when 1 then 'Auto' when 2 then 'Manual' end as kiosk_activation,
       case when k.devicedeletedon is not null then True else False end as is_kiosk_deleted,
       case dd.kiosk_mode when 1 then 'Live' when 2 then 'Demo' when 3 then 'Test' end as kiosk_mode,
       dd.kiosk_logging,
       dd.is_goast_kiosk,
       dd.loyalty_login_otp,
       dd.pos_provider,
       dd.payment_provider,
       '' as payment_device_type,
       dd.loyalty_provider,
       dd.scanners,
       case org.status when 0 then 'Draft' when 1 then 'Onboarding' when 2 then 'Live' when 3 then 'Cancelled' end as organization_status,
       case loc.status when 0 then 'Draft' when 1 then 'Onboarding' when 2 then 'Live' when 3 then 'Cancelled' end as location_status,
       org.active as is_org_active,
       loc.active as is_loc_active,
       org.isdeleted as is_org_deleted,
       loc.isdeleted as is_loc_deleted,
       case when org.status = 2 then org.modifiedon end as org_go_live_date,
       case when loc.status = 2 then loc.modifiedon end as loc_go_live_date,
       org.createdon as org_created_date, 
       loc.createdon as loc_created_date,
       org.is_ecm_enabled as is_org_ecm_enabled,
       org.is_cep_enabled as is_org_cep_enabled,
       org.is_concessionaire_enabled as is_org_concessionaire_enabled,
       org.is_smart_upsells_enabled as is_org_smart_upsells_enabled,
       org.is_feedback_survey_enabled as is_org_feedback_survey_enabled,
       org.is_digital_menu_board_enabled as is_org_digital_menu_board_enabled,
       org.is_digital_menu_default_format_enabled as is_org_digital_menu_default_format_enabled,
       loc.is_ecm_enabled as is_loc_ecm_enabled,
       loc.is_cep_enabled as is_loc_cep_enabled,
       loc.is_concessionaire_enabled as is_loc_concessionaire_enabled,
       loc.is_smart_upsells_enabled as is_loc_smart_upsells_enabled,
       loc.is_feedback_survey_enabled as is_loc_feedback_survey_enabled,
       loc.is_digital_menu_board_enabled as is_loc_digital_menu_board_enabled,
       loc.is_digital_menu_default_format_enabled as is_loc_digital_menu_default_format_enabled,
       dd.sysinserttime,
       now() as sysupdatetime,
       dd.item_special_request,
       dd.legal_copy_enabled,
       dd.ada_configuration,
       dd.calculate_default_modifier_price,
       dd.track_kiosk_user_behavior,
       dd.loyalty_feature,
       dd.pickup_flow,
       dd.pos_auto_applied_discount,
       dd.search_functionality_enabled,
       dd.recent_orders_enabled,
       dd.play_card_config,
       dd.round_up_for_charity,
       dd.calories_enabled,
       dd.scan_and_go_enabled,
       dd.age_verification,
       dd.tips_enabled,
       dd.apply_before_taxes,
       dd.auto_print_enabled,
       dd.include_pos_order_number,
       dd.show_qr_code_when_print_receipt_fails,
       dd.print_modifier_group_names,
       dd.print_default_modifiers,
       dd.print_free_modifiers,
       dd.print_priced_modifiers,
       dd.enable_email_receipts,
       dd.enable_sms_receipt,
       dd.qr_code_for_receipt,
       dd.show_screensaver,
       dd.business_hours_show_message,
       dd.business_hours_enabled,
       dd.pos_hours_enabled,
       dd.quantity_limit_per_item,
       dd.quantity_limit_per_order,
       dd.max_discount_per_order,
       dd.show_item_asis_option,
       dd.enable_minimum_order_total,
       dd.auto_apply_min_qty_to_first_modifier,
       dd.show_make_it_a_meal_option,
       dd.enable_combo_auto_skip,
       dd.number_of_item_upsell_prompts_per_order,
       dd.can_enter_code_for_discount,
       dd.can_scan_qr_code_for_discount,
       dd.can_select_from_list_for_discount,
       dd.enabled_languages,
       dd.display_modifier_group_restriction,
       dd.allow_user_to_collapse_or_expand_modifier_groups,
       dd.show_modifier_group_names_on_order_review,
       dd.show_default_modifier_on_order_review,
       dd.auto_expand_modifier_group,
       dd.enable_nested_modifier_indentation,
       dd.open_nested_modifiers_in_popup,
       dd.category_header_display_mode,
       dd.category_header_logo_display_mode,
       dd.show_item_description,
       dd.category_name_position,
       dd.hide_sold_out_item_and_modifier_on_kiosk,
       dd.make_category_sidebar_translucent,
       dd.enable_single_step_subcategory_flow,
       dd.remove_category_highlighted_border,
       dd.enable_extended_combo_mode,
       dd.button_style,
       dd.show_discount_code_button,
       dd.make_item_combo_images_rounded,
       dd.show_loyalty_points_on_header,
       dd.show_card_accepted_payment_options,
       dd.show_google_pay_accepted_payment_options,
       dd.show_apple_pay_accepted_payment_options,
       dd.show_cash_accepted_payment_options,
       dd.show_tap_to_order_cta,
       dd.use_text_for_cta,
       dd.use_image_for_cta,
       dd.choose_a_currency,
       dd.choose_a_locale,
       dd.order_number_start,
       dd.allotment,
       dd.negative_modifier_behavior,
       dd.disclaimer_text,
       dd.preorder_popup_enabled,
       dd.preorder_popup_text,
       aot.order_types_identity_config,
       dd.show_category_highlighted_color,
       org.cep_subscriptions :: jsonb as cep_subscriptions,
       dd.perform_pos_status_check
from device_details as dd
left join array_order_types as aot
        on dd.location_id = aot.locationid
inner join dim.kiosk as k 
        on dd.location_id = k.locationid and dd.kiosk_id = k.kioskid 
inner join (select * from dim.organizationlocation where organizationtype = 0) as ol 
        on dd.location_id = ol.locationid
inner join dim.organization as org
        on ol.organizationid = org.id
inner join dim.organization as loc
        on ol.locationid = loc.id
)
INSERT INTO dim.vw_grubbrrinstallbase
SELECT * FROM total
WHERE 1=1
AND location_status = 'Live'
AND is_loc_active = True
AND kiosk_mode = 'Live';
--AND is_kiosk_deleted = False
--AND is_test_kiosk = False
--AND is_test_mode_on = False;

$$;


ALTER PROCEDURE dim.usp_grubbrr_install_base() OWNER TO citus;

--
-- TOC entry 591 (class 1255 OID 2041188)
-- Name: usp_master_keys_for_duplicate_items(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_master_keys_for_duplicate_items()
    LANGUAGE plpgsql
    AS $$

BEGIN

WITH duplicate_items AS (
    SELECT *, 
           count(*) over(PARTITION BY locationid, trim(lower(menuitemname))) as dupl
    FROM dim.category_hierarchy
)
INSERT INTO dim.duplicate_items_master (
    organizationid,
    locationid,
    categoryid,
    categoryname,
    menuitemid,
    entitytype,
    item_class_type,
    menuitemname,
    sysinserttime
)
SELECT organizationid,
       locationid,
       categoryid,
       categoryname,
       menuitemid,
       entitytype,
       item_class_type,
       menuitemname,
       now()::TIMESTAMP
FROM duplicate_items di
WHERE dupl > 1
  AND NOT EXISTS (
        SELECT 1 
        FROM dim.duplicate_items_master as dim
        WHERE dim.locationid = di.locationid
          AND dim.categoryid = di.categoryid
          AND dim.menuitemid = di.menuitemid
  );

WITH item_counts AS (
    SELECT locationid, dimmenuitemid, count(*) AS instance_count
    FROM fact.transactionitem
	WHERE transactionheaderid like 'ordevt-%'
    GROUP BY locationid, dimmenuitemid
)
UPDATE dim.duplicate_items_master dim
SET instance_count = ic.instance_count,
    sysupdatetime  = now()::TIMESTAMP
FROM item_counts ic
WHERE dim.locationid = ic.locationid
  AND dim.menuitemid = ic.dimmenuitemid;

UPDATE dim.duplicate_items_master dim
SET masteritemid = concat('mstritm-', uuid_generate_v5(uuid_ns_dns(), concat(dim.locationid, ':', trim(lower(dim.menuitemname))))),
	sysupdatetime  = now()::TIMESTAMP
WHERE dim.masteritemid IS NULL;


END;
$$;


ALTER PROCEDURE dim.usp_master_keys_for_duplicate_items() OWNER TO citus;

--
-- TOC entry 607 (class 1255 OID 33016)
-- Name: fn_getdata(text, text, text, text); Type: FUNCTION; Schema: fact; Owner: citus
--

CREATE FUNCTION fact.fn_getdata(aty text, dc text, modid text, appli text) RETURNS TABLE(companyid text, locationid text, eventtoken text, dateid integer, deviceid text, eventinstant timestamp without time zone, duration_type text)
    LANGUAGE plpgsql
    AS $$
        begin 
	        RETURN QUERY
            SELECT
                e.companyid,
                e.locationid,
                e.eventtoken,
                e.dateid,
                e.deviceid,
                MIN(e.eventinstant :: timestamp without time zone) AS eventinstant,
                'starttocheckout':: text AS duration_type
            FROM 
                fact.deviceevent e
            WHERE 
                e.actiontype = aty 
                AND e.datacategory = dc
                AND e.moduleid = modid
                AND e.application = appli
            GROUP BY 
                e.companyid, e.locationid, e.eventtoken, e.dateid, e.deviceid;
        END;
        $$;


ALTER FUNCTION fact.fn_getdata(aty text, dc text, modid text, appli text) OWNER TO citus;

--
-- TOC entry 752 (class 1255 OID 33018)
-- Name: getsalesreport(text, text, text); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.getsalesreport(IN _organizationid text, IN _startdate text, IN _enddate text, OUT transactioncount integer, OUT salestotal numeric, OUT avgtransaction numeric, OUT avgguest numeric, OUT avgguesttransaction numeric, OUT loyaltysales numeric, OUT loyaltypct numeric)
    LANGUAGE plpgsql
    AS $$
        BEGIN
            SELECT 
                COUNT(th.transactionheaderid) AS transactioncount,
                COALESCE(SUM(th.ordertotal), 0) AS salestotal,
                COALESCE(SUM(th.ordertotal)::float / NULLIF(COUNT(th.transactionheaderid), 0), 0) AS avgtransaction,
                CASE WHEN SUM(mi.totalguests) = 0 THEN 0 ELSE COALESCE(SUM(th.ordertotal)::float / SUM(mi.totalguests), 0) END AS avgguest,
                CASE WHEN COUNT(th.transactionheaderid) = 0 THEN 0 ELSE COALESCE(SUM(mi.totalguests)::float / COUNT(th.transactionheaderid), 0) END AS avgguesttransaction,
                0.000 AS loyaltysales,
                0.0 AS loyaltypct
            INTO transactioncount, salestotal, avgtransaction, avgguest, avgguesttransaction, loyaltysales, loyaltypct
            FROM fact.transactionheader AS th
            INNER JOIN dim.datedim AS dd ON dd.dateid = th.dateid
            INNER JOIN dim.organizationlocation AS ol ON ol.locationid = th.locationid
            LEFT JOIN (
                SELECT 
                    th.transactionheaderid, 
                    COUNT(*) AS totalguests
                FROM fact.transactionheader AS th
                INNER JOIN dim.datedim AS dd ON dd.dateid = th.dateid
                INNER JOIN fact.transactionitem AS ti ON ti.transactionheaderid = th.transactionheaderid
                INNER JOIN dim.menuitem AS mi ON mi.id = ti.menuitemid AND mi.guest = 1
                INNER JOIN dim.organizationlocation AS ol ON ol.locationid = th.locationid
                WHERE ol.organizationid = _organizationid
                    AND LOWER(th.orderstatus) = 'order-placed' 
                    AND dd.datets BETWEEN _startdate::timestamp with time zone AND _enddate::timestamp with time zone
                GROUP BY th.transactionheaderid
            ) AS mi ON mi.transactionheaderid = th.transactionheaderid
            WHERE ol.organizationid = _organizationid 
                AND LOWER(th.orderstatus) = 'order-placed'
                AND dd.datets BETWEEN _startdate::timestamp with time zone AND _enddate::timestamp with time zone;
        END 
        $$;


ALTER PROCEDURE fact.getsalesreport(IN _organizationid text, IN _startdate text, IN _enddate text, OUT transactioncount integer, OUT salestotal numeric, OUT avgtransaction numeric, OUT avgguest numeric, OUT avgguesttransaction numeric, OUT loyaltysales numeric, OUT loyaltypct numeric) OWNER TO citus;

--
-- TOC entry 846 (class 1255 OID 33017)
-- Name: updatewatermark(text); Type: FUNCTION; Schema: fact; Owner: citus
--

CREATE FUNCTION fact.updatewatermark(tablename text) RETURNS void
    LANGUAGE plpgsql
    AS $$
		DECLARE 
			watermarkvalue timestamp without time zone;
		BEGIN
			SELECT MAX(healthdatatime)
			INTO watermarkvalue
			FROM fact.devicestate;
	
			UPDATE fact.watermarktable
			SET watermarkvalue = watermarkvalue
			WHERE watermarktablename = tablename;

			RETURN;
		END;
		$$;


ALTER FUNCTION fact.updatewatermark(tablename text) OWNER TO citus;

--
-- TOC entry 677 (class 1255 OID 700154)
-- Name: usp_customer_menu_preferences(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_customer_menu_preferences()
    LANGUAGE sql
    AS $$

TRUNCATE TABLE fact.customer_menu_preferences;

WITH part as (
    SELECT * 
    FROM fact.transactionheader as th
    WHERE 1=1--th.locationid = 'loc-637638f7-ef71-4416-85c3-dd63bb25f77d'
      --AND th.businessdate >= '2025-04-01'
      AND th.orderstatus = 'order-placed'
      AND th.frequentcustomerid is not null
), dayparts AS (
    SELECT th.frequentcustomerid, ti.transactionheaderid, ti.itemid, ti.locationid, th.orderdatelocal,
        CASE WHEN ti.itemtype = 'item' AND ti.dimmenuitemid is not null THEN ti.dimmenuitemid
             WHEN ti.itemtype <> 'item' AND ti.comboid is not null THEN ti.comboid end as dimmenuitemid,
        CASE 
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 6 AND 10  THEN 'Breakfast'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 11 AND 13 THEN 'Lunch'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 14 AND 16 THEN 'Afternoon/Snack'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 17 AND 20 THEN 'Dinner'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) >= 21 OR EXTRACT(HOUR FROM th.orderdatelocal) < 6 THEN 'Late Night'
        END AS day_parts,
        'All Day' as all_day        
    FROM part as th
    inner JOIN fact.transactionitem as ti 
            ON th.transactionheaderid = ti.transactionheaderid
           AND th.locationid = ti.locationid
    WHERE (ti.itemtype = 'item' AND ti.dimmenuitemid is not null)
       OR (ti.itemtype <> 'item' AND ti.comboid is not null)
), agg_dayparts as (
    SELECT locationid,
           frequentcustomerid, 
           day_parts, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, frequentcustomerid, day_parts, dimmenuitemid--, itemtype
), agg_all_day as (
    SELECT locationid,
           frequentcustomerid, 
           all_day, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, frequentcustomerid, all_day, dimmenuitemid--, itemtype
), Ranked1 AS (
    SELECT 
        fc.organizationid as fc_organizationid,
        --ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.frequentcustomerid,
        agg.day_parts,
        agg.itemid,
        it.ItemType,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.frequentcustomerid, agg.day_parts ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_dayparts as agg
    INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), Ranked2 AS (
    SELECT 
        fc.organizationid as fc_organizationid,
        --ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.frequentcustomerid,
        agg.all_day,
        agg.itemid,
        it.ItemType,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.frequentcustomerid, agg.all_day ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_all_day as agg
    INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), total as (
SELECT fc_organizationid as organizationid,
       --ol_organizationid,
       locationid,
       frequentcustomerid,
       day_parts,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked1 WHERE rn <= 10
UNION
SELECT fc_organizationid as organizationid,
       --ol_organizationid,
       locationid,
       frequentcustomerid,
       all_day,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked2 WHERE rn <= 10
--ORDER BY item_selection_frequency desc;
)
INSERT INTO fact.customer_menu_preferences
SELECT * from total
--WHERE fc_organizationid <> ol_organizationid
--ORDER BY frequentcustomerid


$$;


ALTER PROCEDURE fact.usp_customer_menu_preferences() OWNER TO citus;

--
-- TOC entry 519 (class 1255 OID 700153)
-- Name: usp_location_menu_preferences(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_location_menu_preferences()
    LANGUAGE sql
    AS $$

TRUNCATE TABLE fact.location_menu_preferences;

WITH part as (
    SELECT * 
    FROM fact.transactionheader as th
    WHERE 1=1 
      --AND th.locationid = 'loc-x4pw1awq97'-- 'loc-637638f7-ef71-4416-85c3-dd63bb25f77d'
      --AND th.businessdate >= '2025-04-01'
      AND th.orderstatus = 'order-placed'
), dayparts AS (
    SELECT ti.transactionheaderid, ti.itemid, ti.locationid, th.orderdatelocal,
        CASE WHEN ti.itemtype = 'item' AND ti.dimmenuitemid is not null THEN ti.dimmenuitemid
             WHEN ti.itemtype <> 'item' AND ti.comboid is not null THEN ti.comboid end as dimmenuitemid,
        CASE 
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 6 AND 10  THEN 'Breakfast'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 11 AND 13 THEN 'Lunch'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 14 AND 16 THEN 'Afternoon/Snack'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 17 AND 20 THEN 'Dinner'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) >= 21 OR EXTRACT(HOUR FROM th.orderdatelocal) < 6 THEN 'Late Night'
        END AS day_parts,
        'All Day' as all_day        
    FROM part as th
    INNER JOIN fact.transactionitem as ti 
            ON th.transactionheaderid = ti.transactionheaderid
           AND th.locationid = ti.locationid
    WHERE (ti.itemtype = 'item' AND ti.dimmenuitemid is not null)
       OR (ti.itemtype <> 'item' AND ti.comboid is not null)
), agg_dayparts as (
    SELECT locationid,
           day_parts, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, day_parts, dimmenuitemid--, itemtype
), agg_all_day as (
    SELECT locationid,
           all_day, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, all_day, dimmenuitemid--, itemtype
), Ranked1 AS (
    SELECT 
        --fc.organizationid as fc_organizationid,
        ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.day_parts,
        agg.itemid,
        it.itemtype,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.day_parts ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_dayparts as agg
    --INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT * FROM dim.organizationlocation where organizationtype = 0) as ol on agg.locationid = ol.locationid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), Ranked2 AS (
    SELECT 
        --fc.organizationid as fc_organizationid,
        ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.all_day,
        agg.itemid,
        it.itemtype,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.all_day ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_all_day as agg
    --INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT * FROM dim.organizationlocation where organizationtype = 0) as ol on agg.locationid = ol.locationid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), total as (
SELECT --fc_organizationid as organizationid,
       ol_organizationid as organizationid,
       locationid,
       day_parts,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked1 WHERE rn <= 10
UNION
SELECT --fc_organizationid as organizationid,
       ol_organizationid as organizationid,
       locationid,
       all_day,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked2 WHERE rn <= 10
--ORDER BY item_selection_frequency desc;
)
INSERT INTO fact.location_menu_preferences
SELECT * from total
--WHERE fc_organizationid <> ol_organizationid
--ORDER BY item_selection_frequency desc

$$;


ALTER PROCEDURE fact.usp_location_menu_preferences() OWNER TO citus;

--
-- TOC entry 832 (class 1255 OID 2247996)
-- Name: usp_location_statistics(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_location_statistics()
    LANGUAGE plpgsql
    AS $$

BEGIN

TRUNCATE TABLE fact.location_statistics;

WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname, 
           ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE 1=1 
      --AND (CASE WHEN 'com-3owh66znkd' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'com-3owh66znkd'
      AND ol.organizationtype = 0
), order_items AS (
    SELECT ti.*
    FROM (
        SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.* 
        FROM fact.transactionitem AS ti
        INNER JOIN org_loc_lookup as ol
			ON ti.locationid = ol.locationid
        WHERE 1=1
          AND ti.transactionheaderid LIKE 'ordevt-%'
    ) as ti
), frequent_customers as (
    SELECT fc.organizationid, 
           count(*) as number_of_frequent_customers,
           sum(fc.ordercount) as orders_placed_by_freq_customers,
           sum(fc.amountspent) as amount_spent_by_freq_customers,
           sum(fc.amountspent) / case when sum(fc.ordercount) > 0 then sum(fc.ordercount) else 1 end as avg_amount_spent_by_freq_customers
    FROM dim.frequentcustomer as fc
    GROUP BY fc.organizationid
), org_agg_trxn as (
	SELECT ol.organizationid, 
           count(*) as org_total_order_count,
           sum(th.ordertotal) as org_total_sales_amount,
           round(avg(th.ordertotal), 3) as org_avg_order_amount
	FROM fact.transactionheader as th 
    INNER JOIN org_loc_lookup as ol
            ON th.locationid = ol.locationid
    WHERE th.orderstatus = 'order-placed'
	GROUP BY organizationid
), loc_agg_trxn as (
	SELECT th.locationid, 
           count(*) as loc_total_order_count,
           sum(th.ordertotal) as loc_total_sales_amount,
           round(avg(th.ordertotal), 3) as loc_avg_order_amount
	FROM fact.transactionheader as th 
    WHERE th.orderstatus = 'order-placed'
	GROUP BY th.locationid
), loc_agg as (
	SELECT organizationid, locationid, 
           count(*) as total_items_ordered_within_loc
	FROM order_items
	GROUP BY organizationid, locationid
), loc_itm_agg as (
	SELECT organizationid, locationid, dimmenuitemid, 
    count(*) as item_selection_frequency_within_loc,
    max(itemunitprice) as itemunitprice
	FROM order_items
	GROUP BY organizationid, locationid, dimmenuitemid
), item_statistics AS (
	SELECT lia.organizationid, lia.locationid, lia.dimmenuitemid, lia.itemunitprice,
           lia.item_selection_frequency_within_loc,
           la.total_items_ordered_within_loc,
           100 * lia.item_selection_frequency_within_loc :: NUMERIC(8,3) / la.total_items_ordered_within_loc as pct_item_selection_freq_within_loc,
           dense_rank() OVER(PARTITION by lia.locationid ORDER BY item_selection_frequency_within_loc DESC) as loc_item_popularity
	FROM loc_itm_agg as lia
    INNER JOIN loc_agg as la 
            ON lia.organizationid = la.organizationid
           AND lia.locationid = la.locationid
), item_details AS (
    SELECT its.organizationid, its.locationid, 
    jsonb_agg(
        jsonb_build_object(
            'menuitemid', its.dimmenuitemid, 
            'x_times_selected', its.item_selection_frequency_within_loc,
            'total_items_selected', its.total_items_ordered_within_loc,
            'pct_of_all_items',  its.pct_item_selection_freq_within_loc,
            'item_class_type', mi.item_class_type,
            'itemunitprice', COALESCE(its.itemunitprice, mi.itemunitprice),
            'loc_item_popularity', loc_item_popularity
        ) ORDER BY loc_item_popularity ASC, item_selection_frequency_within_loc DESC
    ) as loc_item_popularity
    FROM item_statistics as its 
    LEFT JOIN dim.menuitem as mi
           ON its.dimmenuitemid = mi.menuitemid
    WHERE loc_item_popularity <= 20
    GROUP BY its.organizationid, its.locationid
), order_types AS (
SELECT locationid, jsonb_agg(value->>'label') AS order_type_labels
FROM (SELECT * FROM dim.kioskdetails 
      WHERE dim.is_valid_jsonb(order_types) 
        AND locationid IN (SELECT locationid FROM org_loc_lookup)
      ) as ld
CROSS JOIN LATERAL jsonb_each(ld.order_types :: jsonb -> 'options')
GROUP BY locationid
)
INSERT INTO fact.location_statistics
SELECT DISTINCT 
olk.organizationid,
olk.organizationname,
olk.locationid,
olk.locationname,
l.city,
l.state,
l.country,
l.active as isactive,
l.timezone,
ot.order_type_labels,
itd.loc_item_popularity,
COALESCE(la.loc_total_order_count, 0) as loc_total_order_count,
COALESCE(la.loc_total_sales_amount, 0) as loc_total_sales_amount,
COALESCE(la.loc_avg_order_amount, 0) as loc_avg_order_amount,
COALESCE(oa.org_total_order_count, 0) as org_total_order_count,
COALESCE(oa.org_total_sales_amount, 0) as org_total_sales_amount,
COALESCE(oa.org_avg_order_amount, 0) as org_avg_order_amount,
COALESCE(fc.number_of_frequent_customers, 0) as number_of_frequent_customers,
COALESCE(fc.orders_placed_by_freq_customers, 0) as orders_placed_by_freq_customers,
COALESCE(fc.amount_spent_by_freq_customers, 0) as amount_spent_by_freq_customers,
COALESCE(ROUND(fc.avg_amount_spent_by_freq_customers, 3), 0) as avg_amount_spent_by_freq_customers,
now() :: TIMESTAMP as sysupdatetime
FROM org_loc_lookup as olk
LEFT JOIN dim.organization as l
       ON olk.locationid = l.id
LEFT JOIN order_types as ot
       ON olk.locationid = ot.locationid
LEFT JOIN item_details as itd
       ON olk.locationid = itd.locationid
LEFT JOIN loc_agg_trxn as la 
       ON olk.locationid = la.locationid
LEFT JOIN org_agg_trxn as oa
       ON olk.organizationid = oa.organizationid
LEFT JOIN frequent_customers as fc 
       ON olk.organizationid = fc.organizationid;

END;
$$;


ALTER PROCEDURE fact.usp_location_statistics() OWNER TO citus;

--
-- TOC entry 839 (class 1255 OID 676702)
-- Name: usp_offer_analysis(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_offer_analysis()
    LANGUAGE plpgsql
    AS $$

BEGIN

WITH delta as (
         SELECT * FROM fact.recommendations as rc
         WHERE 1=1 
           AND rc.syscosmosts > (select ts - 10 from fact.watermarktable where watermarktablename = 'fact.recommendations')
           AND not EXISTS (select 1 from fact.vw_offer_analysis as oa where oa.locationid = rc.locationid and oa.transactionheaderid = rc.transactionheaderid)
), rec AS (
         SELECT rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.offereditems,
            rc.prompttimestamp,
            rc.prompttimestamp :: TIMESTAMP as upsellprompttime,
            rc.syscosmosts,
            element.value ->> 'itemId'::text AS offered_itemid,
            element.value ->> 'upsellLevel'::text AS offered_upselllevel,
            element.value ->> 'promptItemId'::text AS offered_prmpid,
            element.value ->> 'upsellGroupId'::text AS offered_upslgrpid
           FROM delta as rc,
            LATERAL jsonb_array_elements(rc.offereditems) element(value)
), selected AS (
         SELECT rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.selecteditems,
            rc.prompttimestamp,
            element.value ->> 'itemId'::text AS selected_itemid,
            element.value ->> 'quantity'::text AS selected_quantity,
            element.value ->> 'upsellLevel'::text AS selected_upselllevel,
            element.value ->> 'promptItemId'::text AS selected_prmpid,
            element.value ->> 'upsellGroupId'::text AS selected_upslgrpid
           FROM delta as rc,
            LATERAL jsonb_array_elements(rc.selecteditems) element(value)
), item_analysis as (
        SELECT r.locationid, 
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid AS offereditem,
            s.selected_itemid AS selecteditem,
                CASE
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'item'::text THEN 'Item Level Upsells'::text
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'order'::text THEN 'Order Level Upsells'::text
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'::text THEN 'Smart Upsells'::text
                    ELSE NULL::text
                END AS upselltype,
            coalesce(s.selected_upslgrpid, r.offered_upslgrpid) AS upsellgroupid,
            ul.upsellgroupname,
                CASE
                    WHEN lower(s.selected_quantity) = ANY (ARRAY['true'::text, '1'::text]) THEN 1
                    ELSE lower(s.selected_quantity)::integer
                END AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            now() as sysinserttime
        FROM (SELECT * FROM rec WHERE rec.offered_itemid like 'itm-%') r
            LEFT JOIN selected s ON r.transactionheaderid::text = s.transactionheaderid::text 
                                AND r.recommendationid::text = s.recommendationid::text 
                                AND r.offered_itemid = s.selected_itemid
            LEFT JOIN dim.upsellgrouplookup ul ON coalesce(s.selected_upslgrpid, r.offered_upslgrpid) = ul.upsellgroupid::text
), category_analysis as (
        SELECT r.locationid, 
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid AS offereditem,
            s.selected_itemid AS selecteditem,
                CASE
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'item'::text THEN 'Item Level Upsells'::text
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'order'::text THEN 'Order Level Upsells'::text
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'::text THEN 'Smart Upsells'::text
                    ELSE NULL::text
                END AS upselltype,
            coalesce(s.selected_upslgrpid, r.offered_upslgrpid) AS upsellgroupid,
            ul.upsellgroupname,
                CASE
                    WHEN lower(s.selected_quantity) = ANY (ARRAY['true'::text, '1'::text]) THEN 1
                    ELSE lower(s.selected_quantity)::integer
                END AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            now() as sysinserttime
        FROM (SELECT * FROM rec WHERE rec.offered_itemid like 'cat-%') as r
        INNER join dim.category_hierarchy as ctg 
                on r.offered_itemid = ctg.categoryid
        INNER JOIN (SELECT * FROM selected WHERE selected.selected_itemid not in (SELECT offered_itemid FROM rec)) s 
                ON r.transactionheaderid::text = s.transactionheaderid::text 
                AND r.recommendationid::text = s.recommendationid::text 
                AND ctg.menuitemid = s.selected_itemid --to determine which offered item is selected
        LEFT JOIN dim.upsellgrouplookup ul ON coalesce(s.selected_upslgrpid, r.offered_upslgrpid) = ul.upsellgroupid::text
), total as (
            SELECT * FROM item_analysis
            UNION
            SELECT * FROM category_analysis
    ) INSERT INTO fact.vw_offer_analysis
      SELECT * FROM total;

    UPDATE fact.watermarktable
    SET ts = rec.maxts
    FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.recommendations' as tablename FROM fact.recommendations) as rec 
    WHERE watermarktable.watermarktablename = rec.tablename;

END;
$$;


ALTER PROCEDURE fact.usp_offer_analysis() OWNER TO citus;

--
-- TOC entry 1085 (class 1255 OID 630014)
-- Name: usp_update_datetime_fields(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_update_datetime_fields()
    LANGUAGE plpgsql
    AS $$
BEGIN

UPDATE fact.transactionheader 
   SET orderdatelocal = ((transactionheader.orderdateutc)::timestamp with time zone AT TIME ZONE l.timezone)
FROM ( SELECT DISTINCT location.locationid,
                 CASE
                     WHEN ((location.timezone IS NULL) OR (location.timezone = ''::text)) THEN 'America/New_York'::text
                     ELSE location.timezone
                 END AS timezone
            FROM dim.location) l
WHERE (l.locationid = transactionheader.locationid) AND (transactionheader.orderdatelocal IS NULL);

UPDATE fact.transactionheader 
   SET orderdatelocal = ((transactionheader.orderdateutc)::timestamp with time zone AT TIME ZONE 'America/New_York'::text)
WHERE (transactionheader.orderdatelocal IS NULL);

UPDATE fact.transactionheader 
   SET dateid = (to_char(transactionheader.orderdatelocal, 'YYYYMMDDHH24'::text))::integer
WHERE (transactionheader.dateid IS NULL);

UPDATE fact.transactionheader 
   SET businessdate = (transactionheader.orderdatelocal)::date
WHERE (transactionheader.businessdate IS NULL);

UPDATE fact.transactionheader 
   SET abtestid = abtests.abtestid
FROM dim.abtests
WHERE (abtests.ordersessionid = transactionheader.ordersessionid) AND (transactionheader.abtestid IS NULL);



UPDATE fact.transactionitem 
   SET orderdatelocal = ((transactionitem.orderdateutc)::timestamp with time zone AT TIME ZONE l.timezone)
FROM ( SELECT DISTINCT location.locationid,
                 CASE
                     WHEN ((location.timezone IS NULL) OR (location.timezone = ''::text)) THEN 'America/New_York'::text
                     ELSE location.timezone
                 END AS timezone
            FROM dim.location) l
WHERE (l.locationid = transactionitem.locationid) AND (transactionitem.orderdatelocal IS NULL);

UPDATE fact.transactionitem
   SET orderdatelocal = ((transactionitem.orderdateutc)::timestamp with time zone AT TIME ZONE 'America/New_York'::text)
WHERE (transactionitem.orderdatelocal IS NULL);

UPDATE fact.transactionitem 
   SET businessdate = (transactionitem.orderdatelocal)::date
WHERE (transactionitem.businessdate IS NULL);

END;
$$;


ALTER PROCEDURE fact.usp_update_datetime_fields() OWNER TO citus;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 373 (class 1259 OID 345584)
-- Name: abtests; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.abtests (
    abtestid bigint NOT NULL,
    organizationid text,
    locationid text,
    experimentid text,
    experimentname text,
    variantid text,
    variantname text,
    ordersessionid text,
    deviceid text,
    devicename text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE dim.abtests OWNER TO citus;

--
-- TOC entry 339 (class 1259 OID 32819)
-- Name: datedim; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.datedim (
    dateid integer NOT NULL,
    datets timestamp without time zone NOT NULL,
    hourofday text NOT NULL,
    dayval date NOT NULL,
    daynum smallint NOT NULL,
    dayname text NOT NULL,
    weekval integer NOT NULL,
    monthval integer NOT NULL,
    monthname text NOT NULL,
    quarterval integer NOT NULL,
    yearval integer NOT NULL,
    daypart text NOT NULL,
    dayofyear smallint NOT NULL
);


ALTER TABLE dim.datedim OWNER TO citus;

--
-- TOC entry 346 (class 1259 OID 32912)
-- Name: businessdate; Type: VIEW; Schema: dim; Owner: citus
--

CREATE VIEW dim.businessdate AS
 WITH base AS (
         WITH cur AS (
                 SELECT d.dateid,
                    d.datets,
                    d.hourofday,
                    d.dayval,
                    d.daynum,
                    d.dayname,
                    d.weekval,
                    d.monthval,
                    d.monthname,
                    d.quarterval,
                    d.yearval,
                    d.daypart,
                    d.dayofyear
                   FROM dim.datedim d
                  WHERE ((d.yearval)::numeric = EXTRACT(year FROM now()))
                ), pre AS (
                 SELECT d.dateid,
                    d.datets,
                    d.hourofday,
                    d.dayval,
                    d.daynum,
                    d.dayname,
                    d.weekval,
                    d.monthval,
                    d.monthname,
                    d.quarterval,
                    d.yearval,
                    d.daypart,
                    d.dayofyear
                   FROM dim.datedim d
                  WHERE ((d.yearval)::numeric = EXTRACT(year FROM (now() - '1 year'::interval)))
                )
         SELECT DISTINCT (((p.yearval || to_char((c.dayval)::timestamp with time zone, 'MMDD'::text)) || "substring"(c.hourofday, 1, 2)))::integer AS dateid,
            p.hourofday,
            p.daynum,
            p.dayname,
            p.weekval,
            c.monthval,
            c.monthname,
            c.quarterval,
            p.yearval,
            p.daypart
           FROM (cur c
             LEFT JOIN pre p ON (((p.weekval = c.weekval) AND (p.dayname = c.dayname) AND (p.hourofday = c.hourofday))))
          ORDER BY p.daypart, c.quarterval, p.dayname
        )
 SELECT base.dateid,
    base.hourofday,
    base.daynum,
    base.dayname,
    base.weekval,
    base.monthval,
    base.monthname,
    base.quarterval,
    base.yearval,
    base.daypart
   FROM base
UNION
 SELECT d.dateid,
    d.hourofday,
    d.daynum,
    d.dayname,
    d.weekval,
    d.monthval,
    d.monthname,
    d.quarterval,
    d.yearval,
    d.daypart
   FROM dim.datedim d
  WHERE ((d.yearval)::numeric = EXTRACT(year FROM now()))
  ORDER BY 1, 2, 4;


ALTER VIEW dim.businessdate OWNER TO citus;

--
-- TOC entry 410 (class 1259 OID 2178862)
-- Name: catalog; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.catalog (
    catalogid character varying(50) NOT NULL,
    catalogname character varying(255),
    organizationid character varying(40),
    is_catalog_deleted boolean,
    catalog_created_on timestamp without time zone,
    catalog_modified_on timestamp without time zone,
    gem_company_id character varying(255),
    gem_location_id character varying(255),
    is_sync_in_progress boolean,
    is_standalone boolean,
    is_master boolean,
    is_ecm_enabled boolean
);


ALTER TABLE dim.catalog OWNER TO citus;

--
-- TOC entry 408 (class 1259 OID 2039150)
-- Name: category_hierarchy; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.category_hierarchy (
    id bigint NOT NULL,
    organizationid text,
    locationid text NOT NULL,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    catalogid text,
    catalogname text,
    catalog_created_on timestamp without time zone,
    catalog_modified_on timestamp without time zone,
    is_catalog_active boolean,
    is_catalog_deleted boolean,
    categoryid text NOT NULL,
    categoryname text,
    category_created_on timestamp without time zone,
    category_modified_on timestamp without time zone,
    is_category_active boolean,
    is_category_deleted boolean,
    menuitemid text,
    entitytype text,
    item_class_type integer,
    menuitemname text,
    item_created_on timestamp without time zone,
    item_modified_on timestamp without time zone,
    is_item_active boolean,
    is_item_deleted boolean,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.category_hierarchy OWNER TO citus;

--
-- TOC entry 338 (class 1259 OID 32811)
-- Name: company; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.company (
    companyid text NOT NULL,
    companyname text NOT NULL,
    businessemail text,
    businessphone text,
    businesstype text,
    address1 text,
    address2 text,
    city text,
    state text,
    zipcode text
);


ALTER TABLE dim.company OWNER TO citus;

--
-- TOC entry 379 (class 1259 OID 413623)
-- Name: device; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.device (
    id bigint NOT NULL,
    deviceid character varying(50) NOT NULL,
    devicetype character varying(50) NOT NULL,
    devicename text,
    locationid character varying(50) NOT NULL,
    companyid character varying(50) NOT NULL,
    currentversion character varying(50),
    ipaddress character varying(50),
    state character varying(50) NOT NULL,
    previousstate character varying(50),
    statechangedate timestamp without time zone,
    enrollmentdate timestamp without time zone NOT NULL,
    disenrollmentdate timestamp without time zone,
    disenrollmentreason text,
    testmode boolean DEFAULT false
);


ALTER TABLE dim.device OWNER TO citus;

--
-- TOC entry 409 (class 1259 OID 2039929)
-- Name: duplicate_items_master; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.duplicate_items_master (
    organizationid text,
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text,
    menuitemid text,
    entitytype text,
    item_class_type integer,
    menuitemname text,
    instance_count integer,
    masteritemid text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.duplicate_items_master OWNER TO citus;

--
-- TOC entry 340 (class 1259 OID 32829)
-- Name: element; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.element (
    elementid integer NOT NULL,
    sourceelementid text,
    elementname text
);


ALTER TABLE dim.element OWNER TO citus;

--
-- TOC entry 384 (class 1259 OID 419500)
-- Name: experiment; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.experiment (
    dimkey integer NOT NULL,
    data jsonb
);


ALTER TABLE dim.experiment OWNER TO citus;

--
-- TOC entry 383 (class 1259 OID 419499)
-- Name: experiment_dimkey_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE dim.experiment_dimkey_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.experiment_dimkey_seq OWNER TO citus;

--
-- TOC entry 6140 (class 0 OID 0)
-- Dependencies: 383
-- Name: experiment_dimkey_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.experiment_dimkey_seq OWNED BY dim.experiment.dimkey;


--
-- TOC entry 364 (class 1259 OID 180315)
-- Name: feedbackrating; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.feedbackrating (
    rating text,
    ratingdesc text
);


ALTER TABLE dim.feedbackrating OWNER TO citus;

--
-- TOC entry 363 (class 1259 OID 180310)
-- Name: feedbackstatus; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.feedbackstatus (
    surveytransstatus text,
    statusdesc text
);


ALTER TABLE dim.feedbackstatus OWNER TO citus;

--
-- TOC entry 370 (class 1259 OID 245826)
-- Name: frequentcustomer; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.frequentcustomer (
    customerkey bigint NOT NULL,
    frequentcustomerid text NOT NULL,
    firstname text,
    lastname text,
    email text,
    phone text,
    source text,
    organizationid text,
    createddate text,
    lastorderdate text,
    ordercount integer DEFAULT 0 NOT NULL,
    amountspent numeric DEFAULT 0 NOT NULL,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.frequentcustomer OWNER TO citus;

--
-- TOC entry 401 (class 1259 OID 762124)
-- Name: grubbrr_source_lookup; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.grubbrr_source_lookup (
    id integer NOT NULL,
    source character varying(10),
    description character varying(50)
);


ALTER TABLE dim.grubbrr_source_lookup OWNER TO citus;

--
-- TOC entry 403 (class 1259 OID 862882)
-- Name: holidays; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.holidays (
    holiday_name character varying(50),
    celebrated_date timestamp without time zone,
    month integer,
    day integer,
    holiday_type character varying(20),
    religion character varying(20),
    is_public boolean,
    is_dynamic boolean
);


ALTER TABLE dim.holidays OWNER TO citus;

--
-- TOC entry 414 (class 1259 OID 2669323)
-- Name: item_modifier_group_modifier_mapping; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.item_modifier_group_modifier_mapping (
    catalogid character varying(50) NOT NULL,
    menuitemid character varying(50) NOT NULL,
    modifiergroupid character varying(50) NOT NULL,
    modifierid character varying(50) NOT NULL,
    itm_modgrp_min_selection integer,
    itm_modgrp_max_selection integer,
    itm_modgrp_free_count integer,
    is_itm_modgrp_active boolean,
    is_itm_modgrp_deleted boolean,
    itm_modgrp_created_on timestamp without time zone,
    itm_modgrp_modified_on timestamp without time zone,
    is_itm_modgrp_invisible boolean,
    is_default boolean,
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    default_quantity integer,
    is_modgrp_modfr_active boolean NOT NULL,
    is_modgrp_modfr_deleted boolean NOT NULL,
    modgrp_modfr_created_on timestamp without time zone,
    modgrp_modfr_modified_on timestamp without time zone,
    is_modgrp_modfr_invisible boolean,
    sysinserttime timestamp without time zone
);


ALTER TABLE dim.item_modifier_group_modifier_mapping OWNER TO citus;

--
-- TOC entry 341 (class 1259 OID 32837)
-- Name: itemcategory; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.itemcategory (
    id bigint NOT NULL,
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text NOT NULL,
    isactive boolean DEFAULT true NOT NULL
);


ALTER TABLE dim.itemcategory OWNER TO citus;

--
-- TOC entry 391 (class 1259 OID 514411)
-- Name: itemcategory_bkp; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.itemcategory_bkp (
    id bigint NOT NULL,
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text NOT NULL,
    isactive boolean DEFAULT true NOT NULL
);


ALTER TABLE dim.itemcategory_bkp OWNER TO citus;

--
-- TOC entry 395 (class 1259 OID 665518)
-- Name: itemcategorymapping; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.itemcategorymapping (
    categoryid character varying(50) NOT NULL,
    menuitemid character varying(50),
    subcategoryid character varying(50),
    isactive boolean,
    isdeleted boolean,
    modifiedon timestamp without time zone,
    locationid text,
    categoryname text,
    menuitemname text
);


ALTER TABLE dim.itemcategorymapping OWNER TO citus;

--
-- TOC entry 371 (class 1259 OID 311950)
-- Name: kiosk; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.kiosk (
    id bigint NOT NULL,
    locationid text NOT NULL,
    kioskid text NOT NULL,
    kioskname text,
    serialnumber text,
    appversion text,
    istestkiosk boolean,
    devicetype character varying(50) DEFAULT 'kiosk'::character varying NOT NULL,
    devicecreatedon timestamp without time zone,
    devicedeletedon timestamp without time zone
);


ALTER TABLE dim.kiosk OWNER TO citus;

--
-- TOC entry 394 (class 1259 OID 586491)
-- Name: kioskdetails; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.kioskdetails (
    id text,
    locationid text NOT NULL,
    kiosks text,
    devicetype text,
    syncversion text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    pos_provider text,
    loyalty_provider text,
    payment_provider text,
    scanners text,
    item_special_request text,
    legal_copy_enabled boolean,
    ada_configuration text,
    calculate_default_modifier_price boolean,
    track_kiosk_user_behavior boolean,
    loyalty_feature boolean,
    pickup_flow boolean,
    pos_auto_applied_discount boolean,
    search_functionality_enabled boolean,
    recent_orders_enabled boolean,
    play_card_config text,
    round_up_for_charity boolean,
    calories_enabled boolean,
    scan_and_go_enabled boolean,
    age_verification text,
    tips_settings text,
    business_hours_config text,
    order_types text,
    localization text,
    kiosk_receipt_settings text,
    kiosk_fonts text,
    kiosk_appearance_text_overrides text,
    kiosk_appearance_style_options text,
    loyalty_display_settings text,
    preorder_popup_enabled boolean,
    preorder_popup_text text,
    disclaimer_text text,
    order_limit_config text,
    menu_behavior_config text,
    perform_pos_status_check boolean
);


ALTER TABLE dim.kioskdetails OWNER TO citus;

--
-- TOC entry 342 (class 1259 OID 32863)
-- Name: location; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.location (
    locationid text NOT NULL,
    companyid text NOT NULL,
    locationgroupid text,
    locationname text NOT NULL,
    address1 text,
    address2 text,
    city text,
    state text,
    zipcode text,
    latitude text,
    longitude text,
    timezone text
);


ALTER TABLE dim.location OWNER TO citus;

--
-- TOC entry 372 (class 1259 OID 327009)
-- Name: locationcatalog; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.locationcatalog (
    id bigint NOT NULL,
    organizationid text NOT NULL,
    locationid text NOT NULL,
    locationname text,
    catalogid text,
    timezone text,
    menuid text
);


ALTER TABLE dim.locationcatalog OWNER TO citus;

--
-- TOC entry 400 (class 1259 OID 695503)
-- Name: menuentities; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.menuentities (
    catalogid text NOT NULL,
    entityid text NOT NULL,
    entitytype text NOT NULL,
    brand text NOT NULL,
    displayname text,
    description text,
    calories integer,
    protein numeric,
    sugar numeric,
    fat numeric,
    servingsize text,
    price numeric(6,2),
    mealavailability text[],
    modifiers text[],
    tags text[],
    promptcontext text,
    embedding double precision[],
    currency text,
    updatedon timestamp without time zone NOT NULL,
    categories text[],
    tagsreviewedon timestamp without time zone,
    tagsreviewederror text,
    organizationid text,
    locationid text,
    categoryid text,
    item_class_type integer
);


ALTER TABLE dim.menuentities OWNER TO citus;

--
-- TOC entry 376 (class 1259 OID 359366)
-- Name: menuitem; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.menuitem (
    id bigint NOT NULL,
    menuitemid text NOT NULL,
    menuitemname text NOT NULL,
    guest integer DEFAULT 1 NOT NULL,
    effective_date date,
    item_class_type integer,
    entitytype text,
    calories text,
    protein numeric,
    sugar numeric,
    fat numeric,
    is_alcoholic boolean,
    is_vegetarian_item boolean,
    is_vegan_item boolean,
    has_allergen boolean,
    is_active boolean,
    is_deleted boolean,
    gms_created_on timestamp without time zone,
    gms_modified_on timestamp without time zone,
    itemunitprice numeric(12,3),
    price_changed_on timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.menuitem OWNER TO citus;

--
-- TOC entry 411 (class 1259 OID 2196057)
-- Name: modifier; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.modifier (
    modifierkey bigint,
    modifierid character varying(50) NOT NULL,
    catalogid character varying(50),
    modifiername character varying(255),
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    calories text NOT NULL,
    calories_text text,
    is_modifier_active boolean NOT NULL,
    is_modifier_deleted boolean NOT NULL,
    modifier_created_on timestamp without time zone,
    modifier_modified_on timestamp without time zone,
    is_modifier_default boolean,
    modifier_default_quantity integer,
    is_invisible boolean,
    classification integer,
    price numeric(12,3),
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.modifier OWNER TO citus;

--
-- TOC entry 412 (class 1259 OID 2196809)
-- Name: modifier_group_mapping; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.modifier_group_mapping (
    modifier_mapping_id character varying(50) NOT NULL,
    modifierid character varying(50) NOT NULL,
    modifiergroupid character varying(50) NOT NULL,
    catalogid character varying(50),
    is_mapping_active boolean,
    is_mapping_deleted boolean,
    mapping_created_on timestamp without time zone,
    mapping_modified_on timestamp without time zone,
    is_default boolean,
    default_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    min_quantity integer,
    max_quantity integer,
    calories_text text,
    is_invisible boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.modifier_group_mapping OWNER TO citus;

--
-- TOC entry 366 (class 1259 OID 202916)
-- Name: occasionsurvey; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.occasionsurvey (
    surveykey bigint NOT NULL,
    organizationid text NOT NULL,
    surveyid text NOT NULL,
    surveyname text,
    surveytype text
);


ALTER TABLE dim.occasionsurvey OWNER TO citus;

--
-- TOC entry 365 (class 1259 OID 202915)
-- Name: occasionsurvey_surveykey_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

ALTER TABLE dim.occasionsurvey ALTER COLUMN surveykey ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME dim.occasionsurvey_surveykey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 343 (class 1259 OID 32880)
-- Name: ordertype; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.ordertype (
    id bigint NOT NULL,
    locationid text NOT NULL,
    kioskid text NOT NULL,
    ordertypeid text NOT NULL,
    ordertypelabel text NOT NULL
);


ALTER TABLE dim.ordertype OWNER TO citus;

--
-- TOC entry 396 (class 1259 OID 672293)
-- Name: ordertype_bkp; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.ordertype_bkp (
    id bigint NOT NULL,
    locationid text NOT NULL,
    kioskid text NOT NULL,
    ordertypeid text NOT NULL,
    ordertypelabel text NOT NULL
);


ALTER TABLE dim.ordertype_bkp OWNER TO citus;

--
-- TOC entry 385 (class 1259 OID 431156)
-- Name: organization; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.organization (
    id character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    address1 character varying(255),
    address2 character varying(255),
    city character varying(255),
    state character varying(255),
    zipcode character varying(20),
    country character varying(255),
    organizationtype smallint,
    status smallint,
    phonenumber character varying(20),
    email character varying(255),
    isdeleted boolean DEFAULT false,
    createdon timestamp without time zone,
    createdby character varying(255),
    modifiedon timestamp without time zone,
    modifiedby character varying(255),
    active boolean,
    timezone character varying(50),
    coordinates text,
    dayofweek integer,
    hour integer,
    minutes integer,
    roundupforcharity boolean,
    is_ecm_enabled boolean,
    is_cep_enabled boolean,
    is_concessionaire_enabled boolean,
    is_smart_upsells_enabled boolean,
    is_feedback_survey_enabled boolean,
    is_digital_menu_board_enabled boolean,
    is_digital_menu_default_format_enabled boolean,
    cep_subscriptions text
);


ALTER TABLE dim.organization OWNER TO citus;

--
-- TOC entry 344 (class 1259 OID 32888)
-- Name: organizationlocation; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.organizationlocation (
    organizationid character varying(40) NOT NULL,
    organizationname character varying(255),
    locationid character varying(40) NOT NULL,
    locationname character varying(255) NOT NULL,
    organizationtype smallint,
    roundupforcharity boolean
);


ALTER TABLE dim.organizationlocation OWNER TO citus;

--
-- TOC entry 380 (class 1259 OID 413638)
-- Name: peripheral; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.peripheral (
    id bigint NOT NULL,
    deviceid bigint,
    peripheralid character varying(50) NOT NULL,
    peripheraltype character varying(50) NOT NULL,
    state character varying(50) NOT NULL,
    previousstate character varying(50),
    statechangedate timestamp without time zone,
    description text,
    model text,
    serial text,
    ipaddress character varying(50)
);


ALTER TABLE dim.peripheral OWNER TO citus;

--
-- TOC entry 390 (class 1259 OID 471773)
-- Name: upsellgrouplookup; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.upsellgrouplookup (
    upsellgroupid character varying(50) NOT NULL,
    upsellgroupname text,
    isactive boolean,
    createdon timestamp without time zone,
    modifiedon timestamp without time zone
);


ALTER TABLE dim.upsellgrouplookup OWNER TO citus;

--
-- TOC entry 360 (class 1259 OID 103200)
-- Name: userlocation; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.userlocation (
    userid character varying(40) NOT NULL,
    locationid character varying(40) NOT NULL
);


ALTER TABLE dim.userlocation OWNER TO citus;

--
-- TOC entry 345 (class 1259 OID 32906)
-- Name: view; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.view (
    viewid integer,
    viewname text
);


ALTER TABLE dim.view OWNER TO citus;

--
-- TOC entry 402 (class 1259 OID 806155)
-- Name: vw_grubbrrinstallbase; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.vw_grubbrrinstallbase (
    organization_id character varying(50) NOT NULL,
    organization_name text NOT NULL,
    location_id character varying(50) NOT NULL,
    location_name text NOT NULL,
    kiosk_id character varying(50) NOT NULL,
    kiosk_name text,
    kiosk_hardware_id character varying(50),
    kiosk_software_version character varying(50),
    os_type character varying(50),
    serial_number character varying(50),
    is_test_mode boolean,
    is_demo_kiosk boolean,
    is_test_mode_on boolean,
    last_login_time timestamp without time zone,
    last_sync_time timestamp without time zone,
    device_created_on timestamp without time zone,
    device_deleted_on timestamp without time zone,
    is_test_kiosk boolean,
    device_type character varying(50),
    is_activated boolean,
    payment_integration_configs jsonb,
    printer_configs jsonb,
    kiosk_activation character varying(50),
    is_kiosk_deleted boolean,
    kiosk_mode character varying(10),
    kiosk_logging integer,
    is_goast_kiosk boolean,
    loyalty_login_otp character varying(50),
    pos_provider jsonb,
    payment_provider jsonb,
    payment_device_type character varying(50),
    loyalty_provider jsonb,
    scanners jsonb,
    organization_status character varying(20),
    location_status character varying(20),
    is_org_active boolean,
    is_loc_active boolean,
    is_org_deleted boolean,
    is_loc_deleted boolean,
    org_go_live_date timestamp without time zone,
    loc_go_live_date timestamp without time zone,
    org_created_date timestamp without time zone,
    loc_created_date timestamp without time zone,
    is_org_ecm_enabled boolean,
    is_org_cep_enabled boolean,
    is_org_concessionaire_enabled boolean,
    is_org_smart_upsells_enabled boolean,
    is_org_feedback_survey_enabled boolean,
    is_org_digital_menu_board_enabled boolean,
    is_org_digital_menu_default_format_enabled boolean,
    is_loc_ecm_enabled boolean,
    is_loc_cep_enabled boolean,
    is_loc_concessionaire_enabled boolean,
    is_loc_smart_upsells_enabled boolean,
    is_loc_feedback_survey_enabled boolean,
    is_loc_digital_menu_board_enabled boolean,
    is_loc_digital_menu_default_format_enabled boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    item_special_request jsonb,
    legal_copy_enabled boolean,
    ada_configuration jsonb,
    calculate_default_modifier_price boolean,
    track_kiosk_user_behavior boolean,
    loyalty_feature boolean,
    pickup_flow boolean,
    pos_auto_applied_discount boolean,
    search_functionality_enabled boolean,
    recent_orders_enabled boolean,
    play_card_config jsonb,
    round_up_for_charity boolean,
    calories_enabled boolean,
    scan_and_go_enabled boolean,
    age_verification jsonb,
    tips_enabled boolean,
    apply_before_taxes boolean,
    auto_print_enabled boolean,
    include_pos_order_number boolean,
    show_qr_code_when_print_receipt_fails boolean,
    print_modifier_group_names boolean,
    print_default_modifiers boolean,
    print_free_modifiers boolean,
    print_priced_modifiers boolean,
    enable_email_receipts boolean,
    enable_sms_receipt boolean,
    qr_code_for_receipt boolean,
    show_screensaver boolean,
    business_hours_show_message boolean,
    business_hours_enabled boolean,
    pos_hours_enabled boolean,
    quantity_limit_per_item integer,
    quantity_limit_per_order integer,
    max_discount_per_order integer,
    show_item_asis_option boolean,
    enable_minimum_order_total boolean,
    auto_apply_min_qty_to_first_modifier boolean,
    show_make_it_a_meal_option boolean,
    enable_combo_auto_skip boolean,
    number_of_item_upsell_prompts_per_order integer,
    can_enter_code_for_discount boolean,
    can_scan_qr_code_for_discount boolean,
    can_select_from_list_for_discount boolean,
    enabled_languages jsonb,
    display_modifier_group_restriction boolean,
    allow_user_to_collapse_or_expand_modifier_groups boolean,
    show_modifier_group_names_on_order_review boolean,
    show_default_modifier_on_order_review boolean,
    auto_expand_modifier_group boolean,
    enable_nested_modifier_indentation boolean,
    open_nested_modifiers_in_popup boolean,
    category_header_display_mode text,
    category_header_logo_display_mode text,
    show_item_description boolean,
    category_name_position text,
    hide_sold_out_item_and_modifier_on_kiosk boolean,
    make_category_sidebar_translucent boolean,
    enable_single_step_subcategory_flow boolean,
    remove_category_highlighted_border boolean,
    enable_extended_combo_mode boolean,
    button_style text,
    show_discount_code_button boolean,
    make_item_combo_images_rounded boolean,
    show_loyalty_points_on_header boolean,
    show_card_accepted_payment_options boolean,
    show_google_pay_accepted_payment_options boolean,
    show_apple_pay_accepted_payment_options boolean,
    show_cash_accepted_payment_options boolean,
    show_tap_to_order_cta boolean,
    use_text_for_cta boolean,
    use_image_for_cta boolean,
    choose_a_currency jsonb,
    choose_a_locale text,
    order_number_start integer,
    allotment integer,
    negative_modifier_behavior jsonb,
    disclaimer_text text,
    preorder_popup_enabled boolean,
    preorder_popup_text text,
    order_types_identity_config jsonb,
    show_category_highlighted_color boolean,
    cep_subscriptions jsonb,
    perform_pos_status_check boolean
);


ALTER TABLE dim.vw_grubbrrinstallbase OWNER TO citus;

--
-- TOC entry 378 (class 1259 OID 393489)
-- Name: weather; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.weather (
    organizationid text,
    locationid text NOT NULL,
    city text,
    timezone text,
    apicalldate date NOT NULL,
    locationinfo jsonb,
    weatherinfo jsonb,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.weather OWNER TO citus;

--
-- TOC entry 407 (class 1259 OID 1236960)
-- Name: vw_weatherhourlydata; Type: VIEW; Schema: dim; Owner: citus
--

CREATE VIEW dim.vw_weatherhourlydata AS
 SELECT w.locationid,
    ((w.weatherinfo ->> 'Date'::text))::date AS weatherdate,
    ((hour_entry.hour_data ->> 'Hour'::text))::integer AS hh,
    ((hour_entry.hour_data ->> 'Humidity'::text))::integer AS humidity,
    (hour_entry.hour_data ->> 'Condition'::text) AS condition,
    ((hour_entry.hour_data ->> 'TemperatureInCelcius'::text))::numeric(8,2) AS temperature_c,
    ((hour_entry.hour_data ->> 'IsHot'::text))::boolean AS is_hot,
    ((hour_entry.hour_data ->> 'IsCalm'::text))::boolean AS is_calm,
    ((hour_entry.hour_data ->> 'IsCold'::text))::boolean AS is_cold,
    ((hour_entry.hour_data ->> 'IsCool'::text))::boolean AS is_cool,
    ((hour_entry.hour_data ->> 'IsMild'::text))::boolean AS is_mild,
    ((hour_entry.hour_data ->> 'IsWarm'::text))::boolean AS is_warm,
    ((hour_entry.hour_data ->> 'RainMm'::text))::numeric(8,2) AS rain_mm,
    ((hour_entry.hour_data ->> 'IsSunny'::text))::boolean AS is_sunny,
    ((hour_entry.hour_data ->> 'IsWindy'::text))::boolean AS is_windy,
    ((hour_entry.hour_data ->> 'IsCloudy'::text))::boolean AS is_cloudy,
    ((hour_entry.hour_data ->> 'IsDaytime'::text))::boolean AS is_daytime,
    ((hour_entry.hour_data ->> 'IsRaining'::text))::boolean AS is_raining,
    ((hour_entry.hour_data ->> 'IsSnowing'::text))::boolean AS is_snowing,
    ((hour_entry.hour_data ->> 'IsVeryHot'::text))::boolean AS is_very_hot,
    ((hour_entry.hour_data ->> 'IsFreezing'::text))::boolean AS is_freezing,
    ((hour_entry.hour_data ->> 'IsOvercast'::text))::boolean AS is_overcast,
    ((hour_entry.hour_data ->> 'SnowfallMm'::text))::numeric(8,2) AS snowfall_mm,
    (hour_entry.hour_data ->> 'TempBucket'::text) AS temp_bucket,
    (hour_entry.hour_data ->> 'WindBucket'::text) AS wind_bucket,
    ((hour_entry.hour_data ->> 'FeelsColder'::text))::boolean AS feels_colder,
    ((hour_entry.hour_data ->> 'FeelsHotter'::text))::boolean AS feels_hotter,
    (hour_entry.hour_data ->> 'FoodWeather'::text) AS food_weather,
    ((hour_entry.hour_data ->> 'IsHeavyRain'::text))::boolean AS is_heavy_rain,
    ((hour_entry.hour_data ->> 'IsLightRain'::text))::boolean AS is_light_rain,
    ((hour_entry.hour_data ->> 'IsNighttime'::text))::boolean AS is_nighttime,
    ((hour_entry.hour_data ->> 'IsVeryWindy'::text))::boolean AS is_very_windy,
    ((hour_entry.hour_data ->> 'PressureHpa'::text))::numeric(8,2) AS pressure_hpa,
    ((hour_entry.hour_data ->> 'WeatherCode'::text))::integer AS weather_code,
    ((hour_entry.hour_data ->> 'WindGustKmh'::text))::numeric(8,2) AS wind_gust_kmh,
    ((hour_entry.hour_data ->> 'ComfortScore'::text))::integer AS comfort_score,
    (hour_entry.hour_data ->> 'DrinkWeather'::text) AS drink_weather,
    ((hour_entry.hour_data ->> 'WindSpeedKmh'::text))::numeric(8,2) AS wind_speed_kmh,
    (hour_entry.hour_data ->> 'ComfortBucket'::text) AS comfort_bucket,
    (hour_entry.hour_data ->> 'HumidityBucket'::text) AS humidity_bucket,
    (hour_entry.hour_data ->> 'ConditionBucket'::text) AS condition_bucket,
    ((hour_entry.hour_data ->> 'IsPrecipitating'::text))::boolean AS is_precipitating,
    ((hour_entry.hour_data ->> 'PrecipitationMm'::text))::numeric(8,2) AS precipitation_mm,
    ((hour_entry.hour_data ->> 'VisibilityMeters'::text))::numeric(8,2) AS visibility_meters,
    ((hour_entry.hour_data ->> 'CloudCoverPercent'::text))::numeric(8,2) AS cloud_cover_percent,
    ((hour_entry.hour_data ->> 'IsUnseasonablyHot'::text))::boolean AS is_unseasonably_hot,
    ((hour_entry.hour_data ->> 'IsUnseasonablyCold'::text))::boolean AS is_unseasonably_cold,
    ((hour_entry.hour_data ->> 'OutdoorDiningScore'::text))::integer AS outdoor_dining_score,
    ((hour_entry.hour_data ->> 'WindDirectionDegrees'::text))::integer AS wind_direction_degrees,
    ((hour_entry.hour_data ->> 'PrecipitationProbability'::text))::numeric(8,2) AS precipitation_probability,
    ((hour_entry.hour_data ->> 'ApparentTemperatureCelsius'::text))::numeric(8,2) AS apparent_temperature_celsius
   FROM (dim.weather w
     CROSS JOIN LATERAL jsonb_each((w.weatherinfo -> 'Hours'::text)) hour_entry(hour_key, hour_data))
  WHERE ((w.weatherinfo)::text ~~ '{"Date":%'::text);


ALTER VIEW dim.vw_weatherhourlydata OWNER TO citus;

--
-- TOC entry 347 (class 1259 OID 32917)
-- Name: vworganizationlocation; Type: VIEW; Schema: dim; Owner: citus
--

CREATE VIEW dim.vworganizationlocation AS
 WITH base AS (
         WITH cur AS (
                 SELECT d.dateid,
                    d.datets,
                    d.hourofday,
                    d.dayval,
                    d.daynum,
                    d.dayname,
                    d.weekval,
                    d.monthval,
                    d.monthname,
                    d.quarterval,
                    d.yearval,
                    d.daypart,
                    d.dayofyear
                   FROM dim.datedim d
                  WHERE ((d.yearval)::numeric = EXTRACT(year FROM now()))
                ), pre AS (
                 SELECT d.dateid,
                    d.datets,
                    d.hourofday,
                    d.dayval,
                    d.daynum,
                    d.dayname,
                    d.weekval,
                    d.monthval,
                    d.monthname,
                    d.quarterval,
                    d.yearval,
                    d.daypart,
                    d.dayofyear
                   FROM dim.datedim d
                  WHERE ((d.yearval)::numeric = EXTRACT(year FROM (now() - '1 year'::interval)))
                )
         SELECT DISTINCT (((p.yearval || to_char((c.dayval)::timestamp with time zone, 'MMDD'::text)) || "substring"(c.hourofday, 1, 2)))::integer AS dateid,
            p.hourofday,
            p.daynum,
            p.dayname,
            p.weekval,
            c.monthval,
            c.monthname,
            c.quarterval,
            p.yearval,
            p.daypart
           FROM (cur c
             LEFT JOIN pre p ON (((p.weekval = c.weekval) AND (p.dayname = c.dayname) AND (p.hourofday = c.hourofday))))
          ORDER BY p.daypart, c.quarterval, p.dayname
        )
 SELECT base.dateid,
    base.hourofday,
    base.daynum,
    base.dayname,
    base.weekval,
    base.monthval,
    base.monthname,
    base.quarterval,
    base.yearval,
    base.daypart
   FROM base
UNION
 SELECT d.dateid,
    d.hourofday,
    d.daynum,
    d.dayname,
    d.weekval,
    d.monthval,
    d.monthname,
    d.quarterval,
    d.yearval,
    d.daypart
   FROM dim.datedim d
  WHERE ((d.yearval)::numeric = EXTRACT(year FROM now()))
  ORDER BY 1, 2, 4;


ALTER VIEW dim.vworganizationlocation OWNER TO citus;

--
-- TOC entry 377 (class 1259 OID 387340)
-- Name: weather_bkp; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.weather_bkp (
    organizationid text,
    locationid text NOT NULL,
    city text,
    timezone text,
    businessdate date NOT NULL,
    weatherinfo jsonb,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.weather_bkp OWNER TO citus;

--
-- TOC entry 406 (class 1259 OID 1071621)
-- Name: cep_incidents; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.cep_incidents (
    incidentkey bigint,
    application text,
    organizationid text,
    locationid text,
    deviceid text,
    eventmodule text,
    eventcategory text,
    eventtype text,
    eventtoken text,
    incidenttype text,
    incidentcount integer,
    eventinstant text,
    firstoccurred timestamp without time zone,
    lastoccurred timestamp without time zone,
    notificationtypeid text,
    incidentdata text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    severity text
);


ALTER TABLE fact.cep_incidents OWNER TO citus;

--
-- TOC entry 398 (class 1259 OID 693385)
-- Name: customer_menu_preferences; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.customer_menu_preferences (
    organizationid character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    frequentcustomerid character varying(50) NOT NULL,
    day_parts character varying(20) NOT NULL,
    itemid character varying(50),
    itemtype character varying(50),
    item_selection_frequency integer,
    itemtags jsonb,
    sysinserttime timestamp without time zone
);


ALTER TABLE fact.customer_menu_preferences OWNER TO citus;

--
-- TOC entry 348 (class 1259 OID 32922)
-- Name: deviceevent; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.deviceevent (
    application text NOT NULL,
    companyid text NOT NULL,
    locationid text NOT NULL,
    moduleid text,
    datacategory text,
    actiontype text,
    severity text,
    eventtoken text,
    eventinstant text,
    dateid integer,
    username text,
    userid text,
    deviceid text,
    devicename text,
    summary text,
    eventdata text,
    syscosmosticks bigint,
    sysinserttime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE fact.deviceevent OWNER TO citus;

--
-- TOC entry 381 (class 1259 OID 413945)
-- Name: devicehealth; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.devicehealth (
    id bigint NOT NULL,
    healthdatatype character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    companyid character varying(50) NOT NULL,
    deviceid character varying(50) NOT NULL,
    devicetype character varying(50) NOT NULL,
    status character varying(50) NOT NULL,
    statusmessage text,
    healthdatatime timestamp without time zone NOT NULL,
    statuschangetime timestamp without time zone NOT NULL,
    inserttime timestamp without time zone NOT NULL,
    version character varying(50),
    devicedatatime timestamp without time zone
);


ALTER TABLE fact.devicehealth OWNER TO citus;

--
-- TOC entry 349 (class 1259 OID 32929)
-- Name: devicestate; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.devicestate (
    id bigint NOT NULL,
    companyid text,
    locationid text,
    deviceid text,
    dateid integer,
    state text,
    lasteventtime timestamp without time zone,
    statuschangetime timestamp without time zone,
    duration numeric(10,3),
    sysinserttime timestamp without time zone
);


ALTER TABLE fact.devicestate OWNER TO citus;

--
-- TOC entry 361 (class 1259 OID 159814)
-- Name: devicetelemetry; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.devicetelemetry (
    deviceid text,
    locationid text,
    dateid integer,
    cpuvalue numeric(10,5),
    memoryvalue numeric(10,5),
    cputimestamp timestamp without time zone,
    memorytimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.devicetelemetry OWNER TO citus;

--
-- TOC entry 350 (class 1259 OID 32945)
-- Name: itemmodifier; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.itemmodifier (
    transactionheaderid text NOT NULL,
    orderid text NOT NULL,
    itemid text NOT NULL,
    modifiergroupid text NOT NULL,
    modifierid text NOT NULL,
    modifiername text,
    modifierquantity smallint DEFAULT 1 NOT NULL,
    modifierprice numeric(12,3),
    freequantity integer,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.itemmodifier OWNER TO citus;

--
-- TOC entry 374 (class 1259 OID 352106)
-- Name: itemssurvey; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.itemssurvey (
    organizationid text,
    locationid text,
    dateid integer,
    surveyid text,
    surveytransid text,
    orderid text,
    itemid text,
    itemrating text,
    surveytransstatus text,
    surveyissuedtimestamp text,
    surveycompletedtimestamp text,
    surveylocaltimestamp timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE fact.itemssurvey OWNER TO citus;

--
-- TOC entry 399 (class 1259 OID 693393)
-- Name: location_menu_preferences; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.location_menu_preferences (
    organizationid character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    day_parts character varying(20) NOT NULL,
    itemid character varying(50),
    itemtype character varying(50),
    item_selection_frequency integer,
    itemtags jsonb,
    sysinserttime timestamp without time zone
);


ALTER TABLE fact.location_menu_preferences OWNER TO citus;

--
-- TOC entry 413 (class 1259 OID 2247991)
-- Name: location_statistics; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.location_statistics (
    organizationid character varying(50),
    organizationname character varying(255),
    locationid character varying(50),
    locationname character varying(255),
    city character varying(255),
    state character varying(255),
    country character varying(255),
    isactive boolean,
    timezone character varying(255),
    order_type_labels jsonb,
    loc_item_popularity jsonb,
    loc_total_order_count integer,
    loc_total_sales_amount numeric(12,3),
    loc_avg_order_amount numeric(12,3),
    org_total_order_count integer,
    org_total_sales_amount numeric(12,3),
    org_avg_order_amount numeric(12,3),
    number_of_frequent_customers integer,
    orders_placed_by_freq_customers integer,
    amount_spent_by_freq_customers numeric(12,3),
    avg_amount_spent_by_freq_customers numeric(12,3),
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.location_statistics OWNER TO citus;

--
-- TOC entry 415 (class 1259 OID 2812776)
-- Name: modifier_interactions; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.modifier_interactions (
    locationid text NOT NULL,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    orderitemid text NOT NULL,
    menuitemid text,
    modifiergroupid text NOT NULL,
    modifierid text NOT NULL,
    modifiername text,
    modifierquantity smallint,
    modifierprice numeric(12,3),
    freequantity integer,
    selectiontype text,
    action text,
    businessdate date,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.modifier_interactions OWNER TO citus;

--
-- TOC entry 375 (class 1259 OID 352111)
-- Name: occasionsurveydetail; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.occasionsurveydetail (
    organizationid text,
    locationid text,
    dateid integer,
    surveyid text,
    surveytransid text,
    orderid text,
    surveyrating text,
    surveytransstatus text,
    surveyissuedtimestamp text,
    surveycompletedtimestamp text,
    surveylocaltimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    syscosmosts bigint,
    sourceid integer,
    surveytype integer,
    ordersessionid text
);


ALTER TABLE fact.occasionsurveydetail OWNER TO citus;

--
-- TOC entry 351 (class 1259 OID 32952)
-- Name: ordertiming; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.ordertiming (
    id bigint NOT NULL,
    companyid text,
    locationid text,
    eventtoken text,
    dateid integer,
    deviceid text,
    sessionstart timestamp without time zone,
    menustart timestamp without time zone,
    itemstart timestamp without time zone,
    checkoutstart timestamp without time zone,
    paymentstart timestamp without time zone,
    paymentend timestamp without time zone,
    orderend timestamp without time zone,
    starttomenu numeric(7,3),
    menutoitem numeric(7,3),
    itemtocheckout numeric(7,3),
    checkouttopayment numeric(7,3),
    paytopaid numeric(7,3),
    payendtoend numeric(7,3),
    starttocheckout numeric(7,3),
    checkouttoend numeric(7,3),
    totalordertime numeric(7,3),
    sysinserttime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE fact.ordertiming OWNER TO citus;

--
-- TOC entry 382 (class 1259 OID 413957)
-- Name: peripheralhealth; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.peripheralhealth (
    healthdataid bigint,
    peripheralid character varying(50) NOT NULL,
    peripheraltype character varying(50) NOT NULL,
    status character varying(50) NOT NULL,
    statusmessage text
);


ALTER TABLE fact.peripheralhealth OWNER TO citus;

--
-- TOC entry 352 (class 1259 OID 32959)
-- Name: peripheralstate; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.peripheralstate (
    deviceid text,
    peripheralid text,
    peripheraltype text,
    state text,
    statestart timestamp with time zone,
    stateend timestamp with time zone,
    duration interval
);


ALTER TABLE fact.peripheralstate OWNER TO citus;

--
-- TOC entry 353 (class 1259 OID 32965)
-- Name: pipelinerunstatus; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.pipelinerunstatus (
    pipelinename text NOT NULL,
    pipelinerunid character varying(100) NOT NULL,
    pipelinetriggertime timestamp without time zone NOT NULL,
    issuccess boolean,
    pipelinecompletedtime timestamp without time zone,
    correlationid character varying(100),
    pipelinestatus character varying(50),
    pipelinemessage text,
    triggeredbyuserid character varying(100)
);


ALTER TABLE fact.pipelinerunstatus OWNER TO citus;

--
-- TOC entry 405 (class 1259 OID 888761)
-- Name: pos_sales_details; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.pos_sales_details (
    id bigint NOT NULL,
    businessdate date NOT NULL,
    posorderplaced bigint NOT NULL,
    possales numeric(7,3) DEFAULT 0 NOT NULL,
    postips numeric(7,3) DEFAULT 0,
    locationid text NOT NULL,
    created_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_by character varying(255),
    modified_on timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    modified_by character varying(255),
    is_active boolean DEFAULT false NOT NULL
);


ALTER TABLE fact.pos_sales_details OWNER TO citus;

--
-- TOC entry 404 (class 1259 OID 888760)
-- Name: pos_sales_details_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

ALTER TABLE fact.pos_sales_details ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME fact.pos_sales_details_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 387 (class 1259 OID 454561)
-- Name: recommendations; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.recommendations (
    transactionheaderid character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    recommendationid character varying(50) NOT NULL,
    offereditems jsonb,
    selecteditems jsonb,
    isconverted boolean,
    prompttimestamp text,
    sysinserttime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE fact.recommendations OWNER TO citus;

--
-- TOC entry 386 (class 1259 OID 454469)
-- Name: recommendations_bkp; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.recommendations_bkp (
    transactionheaderid character varying(50) NOT NULL,
    recommendationid character varying(50) NOT NULL,
    offereditems jsonb,
    selecteditems jsonb,
    isconverted boolean,
    prompttimestamp text,
    sysinserttime timestamp without time zone
);


ALTER TABLE fact.recommendations_bkp OWNER TO citus;

--
-- TOC entry 354 (class 1259 OID 32970)
-- Name: timingsdatalake; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.timingsdatalake (
    containername text NOT NULL,
    timing_value timestamp without time zone
);


ALTER TABLE fact.timingsdatalake OWNER TO citus;

--
-- TOC entry 355 (class 1259 OID 32977)
-- Name: transactionheader; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.transactionheader (
    id bigint NOT NULL,
    transactionheaderid text NOT NULL,
    orderid text,
    locationid text NOT NULL,
    kioskid text,
    ordersessionid text,
    dateid integer,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    orderstatus text,
    ordertype integer,
    numberofitems smallint,
    numberofpayments smallint,
    ordersredeemedrewards numeric(12,3),
    ordersubtotal numeric(12,3),
    ordertotal numeric(12,3),
    ordertax numeric(12,3),
    ordertip numeric(12,3),
    orderdiscount numeric(12,3),
    orderbalance numeric(12,3),
    paymentstatus text,
    sourcefile text DEFAULT 'NGE'::text NOT NULL,
    createddate timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updateddate timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    orderstarttime timestamp without time zone,
    reviewordertime timestamp without time zone,
    checkouttime timestamp without time zone,
    paystarttime timestamp without time zone,
    sessionendtime timestamp without time zone,
    precheckouttime numeric(7,3),
    postcheckouttime numeric(7,3),
    menupagetime numeric(7,3),
    reviewpagetime numeric(7,3),
    paymentpagetime numeric(7,3),
    totalordertime numeric(7,3),
    businessdate date,
    frequentcustomerid text,
    abtestid bigint,
    channel text,
    guestcount integer,
    charityamount numeric(12,3),
    syscosmosts bigint,
    sourceid integer,
    orderservicecharge numeric(12,3) DEFAULT 0.000,
    customername character varying(100)
);


ALTER TABLE fact.transactionheader OWNER TO citus;

--
-- TOC entry 356 (class 1259 OID 32988)
-- Name: transactionitem; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.transactionitem (
    transactionheaderid text NOT NULL,
    categoryid bigint,
    menuitemid bigint,
    itemid text NOT NULL,
    comboid text,
    ordersessionid text NOT NULL,
    itemsessionid text,
    itemname text NOT NULL,
    itemquantity smallint DEFAULT 1,
    itemunitprice numeric(12,3),
    upselllevel text,
    upsellpromptitemid text,
    orderid text NOT NULL,
    itemtype text,
    customize boolean,
    upgrade boolean,
    asis boolean,
    itemselectedtime timestamp without time zone,
    addtocarttime timestamp without time zone,
    totaltime numeric(7,3),
    orderdateutc text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    dimmenuitemid character varying(50),
    locationid character varying(50),
    orderdatelocal timestamp without time zone,
    businessdate date
);


ALTER TABLE fact.transactionitem OWNER TO citus;

--
-- TOC entry 367 (class 1259 OID 219255)
-- Name: transactionitemtest; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.transactionitemtest (
    transactionheaderid text NOT NULL,
    categoryid bigint,
    menuitemid bigint,
    itemid text NOT NULL,
    comboid text,
    ordersessionid text NOT NULL,
    itemsessionid text,
    itemname text NOT NULL,
    itemquantity smallint DEFAULT 1,
    itemunitprice numeric(7,3),
    upselllevel text,
    upsellpromptitemid text,
    orderid text NOT NULL,
    itemtype text,
    customize boolean,
    upgrade boolean,
    asis boolean,
    itemselectedtime timestamp without time zone,
    addtocarttime timestamp without time zone,
    totaltime numeric(7,3),
    dateid integer,
    orderdateutc text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.transactionitemtest OWNER TO citus;

--
-- TOC entry 357 (class 1259 OID 32997)
-- Name: transactionpayment; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.transactionpayment (
    transactionheaderid text NOT NULL,
    paymentintegrationid text NOT NULL,
    paymentid text,
    paymentamt numeric(12,3),
    orderid text NOT NULL,
    locationid character varying(50),
    kioskid character varying(50),
    paymentmethod character varying(50),
    paymentintegrationlabel text,
    orderdateutc text,
    sysinserttime timestamp without time zone,
    paymentcardtype character varying(50),
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.transactionpayment OWNER TO citus;

--
-- TOC entry 392 (class 1259 OID 542773)
-- Name: transactionrefunds; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.transactionrefunds (
    transactionheaderid character varying(50) NOT NULL,
    orderid character varying(50),
    locationid character varying(50),
    refundtransactionid character varying(50),
    paymentid character varying(50),
    refundamount numeric(7,3),
    refundtype character varying(50),
    orderdateutc text,
    sysinserttime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE fact.transactionrefunds OWNER TO citus;

--
-- TOC entry 358 (class 1259 OID 33004)
-- Name: userbehaviour; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.userbehaviour (
    id bigint NOT NULL,
    busdate timestamp without time zone,
    locationid text,
    dateid integer,
    daypart text,
    ordertype bigint,
    eventtype text,
    ordersessionidentifier text,
    viewidentifier integer,
    itemsessionidentifier text,
    elementidentifier integer,
    quantity integer,
    createddate timestamp without time zone,
    syscosmosts bigint,
    eventinstant text,
    eventcategory text
);


ALTER TABLE fact.userbehaviour OWNER TO citus;

--
-- TOC entry 388 (class 1259 OID 459790)
-- Name: userbehaviour_exceptions; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.userbehaviour_exceptions (
    id bigint NOT NULL,
    busdate timestamp without time zone,
    locationid text,
    dateid integer,
    daypart text,
    ordertype bigint,
    eventtype text,
    ordersessionidentifier text,
    viewidentifier integer,
    itemsessionidentifier text,
    elementidentifier integer,
    quantity integer,
    createddate timestamp without time zone
);


ALTER TABLE fact.userbehaviour_exceptions OWNER TO citus;

--
-- TOC entry 362 (class 1259 OID 165825)
-- Name: usercheckedin; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.usercheckedin (
    organizationid text NOT NULL,
    locationid text NOT NULL,
    kioskid text,
    ordersessionid text,
    dateid integer,
    ordertimestamp text,
    orderid text,
    customername text,
    customerphone text,
    orderstatus text,
    ordertotal numeric(7,3),
    paymentstatus text,
    amountpaid numeric(7,3),
    paymentmethod text,
    paymentcardtype text,
    sysinserttime timestamp without time zone,
    orderdatelocal timestamp without time zone
);


ALTER TABLE fact.usercheckedin OWNER TO citus;

--
-- TOC entry 397 (class 1259 OID 676689)
-- Name: vw_offer_analysis; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.vw_offer_analysis (
    locationid character varying(50) NOT NULL,
    transactionheaderid character varying(50) NOT NULL,
    recommendationid character varying(50) NOT NULL,
    offereditem character varying(50) NOT NULL,
    selecteditem character varying(50),
    upselltype character varying(50),
    upsellgroupid character varying(50),
    upsellgroupname text,
    quantity integer,
    prompttimestamp text,
    upsellprompttime timestamp without time zone,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE fact.vw_offer_analysis OWNER TO citus;

--
-- TOC entry 359 (class 1259 OID 33011)
-- Name: watermarktable; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.watermarktable (
    watermarktablename text NOT NULL,
    watermarkcolumn text,
    watermarkvalue timestamp without time zone,
    ticks bigint,
    ts bigint,
    source character varying(10) NOT NULL
);


ALTER TABLE fact.watermarktable OWNER TO citus;

--
-- TOC entry 393 (class 1259 OID 583797)
-- Name: kioskdetails; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.kioskdetails (
    id text,
    locationid text,
    kiosks text,
    devicetype text,
    syncversion text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.kioskdetails OWNER TO citus;

--
-- TOC entry 389 (class 1259 OID 461038)
-- Name: recommendations; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.recommendations (
    transactionheaderid character varying(50) NOT NULL,
    locationid character varying(50) NOT NULL,
    recommendationid character varying(50) NOT NULL,
    offereditems text,
    selecteditems text,
    prompttimestamp text,
    sysinserttime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE stg.recommendations OWNER TO citus;

--
-- TOC entry 5761 (class 2604 OID 419503)
-- Name: experiment dimkey; Type: DEFAULT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.experiment ALTER COLUMN dimkey SET DEFAULT nextval('dim.experiment_dimkey_seq'::regclass);


--
-- TOC entry 5927 (class 2606 OID 2178868)
-- Name: catalog catalog_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (catalogid);


--
-- TOC entry 5921 (class 2606 OID 2047555)
-- Name: category_hierarchy category_hierarchy_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.category_hierarchy
    ADD CONSTRAINT category_hierarchy_pkey PRIMARY KEY (id);


--
-- TOC entry 5771 (class 2606 OID 32817)
-- Name: company company_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (companyid);


--
-- TOC entry 5774 (class 2606 OID 32825)
-- Name: datedim datedim_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.datedim
    ADD CONSTRAINT datedim_pk PRIMARY KEY (dateid);


--
-- TOC entry 5858 (class 2606 OID 413632)
-- Name: device device_deviceid_locationid_companyid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_deviceid_locationid_companyid_key UNIQUE (deviceid, locationid, companyid);


--
-- TOC entry 5860 (class 2606 OID 413630)
-- Name: device device_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_pkey PRIMARY KEY (id);


--
-- TOC entry 5778 (class 2606 OID 32835)
-- Name: element dimelement_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.element
    ADD CONSTRAINT dimelement_pkey PRIMARY KEY (elementid);


--
-- TOC entry 5882 (class 2606 OID 419507)
-- Name: experiment experiment_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.experiment
    ADD CONSTRAINT experiment_pkey PRIMARY KEY (dimkey);


--
-- TOC entry 5842 (class 2606 OID 779308)
-- Name: frequentcustomer frequent_customer_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer
    ADD CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 5915 (class 2606 OID 762128)
-- Name: grubbrr_source_lookup grubbrr_source_lookup_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.grubbrr_source_lookup
    ADD CONSTRAINT grubbrr_source_lookup_pkey PRIMARY KEY (id);


--
-- TOC entry 5898 (class 2606 OID 514418)
-- Name: itemcategory_bkp itemcategory_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory_bkp
    ADD CONSTRAINT itemcategory_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 5782 (class 2606 OID 32844)
-- Name: itemcategory itemcategory_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory
    ADD CONSTRAINT itemcategory_pk PRIMARY KEY (id);


--
-- TOC entry 5844 (class 2606 OID 311956)
-- Name: kiosk kiosk_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_pk PRIMARY KEY (id);


--
-- TOC entry 5846 (class 2606 OID 311958)
-- Name: kiosk kiosk_uidx; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_uidx UNIQUE (locationid, kioskid);


--
-- TOC entry 5923 (class 2606 OID 2047632)
-- Name: category_hierarchy location_category_menuitem_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.category_hierarchy
    ADD CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 5848 (class 2606 OID 327015)
-- Name: locationcatalog location_ctlg_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.locationcatalog
    ADD CONSTRAINT location_ctlg_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 5854 (class 2606 OID 387346)
-- Name: weather_bkp location_date_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.weather_bkp
    ADD CONSTRAINT location_date_bkp_pk PRIMARY KEY (locationid, businessdate);


--
-- TOC entry 5856 (class 2606 OID 393495)
-- Name: weather location_date_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.weather
    ADD CONSTRAINT location_date_pk PRIMARY KEY (locationid, apicalldate);


--
-- TOC entry 5785 (class 2606 OID 32869)
-- Name: location location_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.location
    ADD CONSTRAINT location_pk PRIMARY KEY (companyid, locationid);


--
-- TOC entry 5925 (class 2606 OID 2047655)
-- Name: duplicate_items_master locationid_categoryid_menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.duplicate_items_master
    ADD CONSTRAINT locationid_categoryid_menuitemid_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 5917 (class 2606 OID 806161)
-- Name: vw_grubbrrinstallbase locationid_deviceid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase
    ADD CONSTRAINT locationid_deviceid_pk PRIMARY KEY (location_id, kiosk_id);


--
-- TOC entry 5901 (class 2606 OID 594665)
-- Name: kioskdetails locationid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kioskdetails
    ADD CONSTRAINT locationid_pkey PRIMARY KEY (locationid);


--
-- TOC entry 5913 (class 2606 OID 695509)
-- Name: menuentities menuentities_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuentities
    ADD CONSTRAINT menuentities_pkey PRIMARY KEY (entityid);


--
-- TOC entry 5850 (class 2606 OID 359373)
-- Name: menuitem menuitem_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitem_pk PRIMARY KEY (id);


--
-- TOC entry 5852 (class 2606 OID 779647)
-- Name: menuitem menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitemid_unq UNIQUE (menuitemid);


--
-- TOC entry 5931 (class 2606 OID 2196815)
-- Name: modifier_group_mapping modifier_group_modifier_glue_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group_mapping
    ADD CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id);


--
-- TOC entry 5929 (class 2606 OID 2196063)
-- Name: modifier modifier_master_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier
    ADD CONSTRAINT modifier_master_pkey PRIMARY KEY (modifierid);


--
-- TOC entry 5903 (class 2606 OID 672299)
-- Name: ordertype_bkp ordertype_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype_bkp
    ADD CONSTRAINT ordertype_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 5789 (class 2606 OID 32886)
-- Name: ordertype ordertype_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype
    ADD CONSTRAINT ordertype_pk PRIMARY KEY (id);


--
-- TOC entry 5884 (class 2606 OID 431163)
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- TOC entry 5794 (class 2606 OID 775937)
-- Name: organizationlocation organizationid_locationid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organizationlocation
    ADD CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 5835 (class 2606 OID 780632)
-- Name: occasionsurvey orgid_surveyid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.occasionsurvey
    ADD CONSTRAINT orgid_surveyid_pk UNIQUE (organizationid, surveyid);


--
-- TOC entry 5867 (class 2606 OID 413646)
-- Name: peripheral peripheral_deviceid_peripheralid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_peripheralid_key UNIQUE (deviceid, peripheralid);


--
-- TOC entry 5870 (class 2606 OID 413644)
-- Name: peripheral peripheral_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_pkey PRIMARY KEY (id);


--
-- TOC entry 5837 (class 2606 OID 202922)
-- Name: occasionsurvey survey_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.occasionsurvey
    ADD CONSTRAINT survey_pkey PRIMARY KEY (surveykey);


--
-- TOC entry 5894 (class 2606 OID 471809)
-- Name: upsellgrouplookup upsellgroupid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.upsellgrouplookup
    ADD CONSTRAINT upsellgroupid_pkey PRIMARY KEY (upsellgroupid);


--
-- TOC entry 5827 (class 2606 OID 103204)
-- Name: userlocation userlocation_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.userlocation
    ADD CONSTRAINT userlocation_pkey PRIMARY KEY (userid, locationid);


--
-- TOC entry 5873 (class 2606 OID 413951)
-- Name: devicehealth devicehealth_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicehealth
    ADD CONSTRAINT devicehealth_pkey PRIMARY KEY (id);


--
-- TOC entry 5908 (class 2606 OID 694784)
-- Name: location_menu_preferences location_dayparts_itemid_itemtype_unq; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.location_menu_preferences
    ADD CONSTRAINT location_dayparts_itemid_itemtype_unq UNIQUE (locationid, day_parts, itemid, itemtype);


--
-- TOC entry 5886 (class 2606 OID 775712)
-- Name: recommendations locationid_trxnid_recommendationid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT locationid_trxnid_recommendationid_pk PRIMARY KEY (locationid, transactionheaderid, recommendationid);


--
-- TOC entry 5807 (class 2606 OID 32958)
-- Name: ordertiming ordertiming_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.ordertiming
    ADD CONSTRAINT ordertiming_pkey PRIMARY KEY (id);


--
-- TOC entry 5879 (class 2606 OID 413963)
-- Name: peripheralhealth peripheralhealth_healthdataid_peripheralid_key; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.peripheralhealth
    ADD CONSTRAINT peripheralhealth_healthdataid_peripheralid_key UNIQUE (healthdataid, peripheralid);


--
-- TOC entry 5919 (class 2606 OID 888772)
-- Name: pos_sales_details pos_sales_details_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.pos_sales_details
    ADD CONSTRAINT pos_sales_details_pkey PRIMARY KEY (id);


--
-- TOC entry 5811 (class 2606 OID 32976)
-- Name: timingsdatalake timingsdatalake_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.timingsdatalake
    ADD CONSTRAINT timingsdatalake_pkey PRIMARY KEY (containername);


--
-- TOC entry 5814 (class 2606 OID 294801)
-- Name: transactionheader transactionheader_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT transactionheader_pkey PRIMARY KEY (locationid, transactionheaderid);


--
-- TOC entry 5888 (class 2606 OID 454567)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 5818 (class 2606 OID 57357)
-- Name: transactionitem transactionitem_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT transactionitem_pkey PRIMARY KEY (transactionheaderid, itemid, itemname);


--
-- TOC entry 5840 (class 2606 OID 219262)
-- Name: transactionitemtest transactionitemtest_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitemtest
    ADD CONSTRAINT transactionitemtest_pkey PRIMARY KEY (transactionheaderid, itemid, itemname);


--
-- TOC entry 5805 (class 2606 OID 1175206)
-- Name: itemmodifier trxnid_itemid_mdfrgrpid_mdfrid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemmodifier
    ADD CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY KEY (transactionheaderid, itemid, modifiergroupid, modifierid);


--
-- TOC entry 5933 (class 2606 OID 2812782)
-- Name: modifier_interactions trxnid_itemid_modfrgrpid_modfrid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.modifier_interactions
    ADD CONSTRAINT trxnid_itemid_modfrgrpid_modfrid_pk PRIMARY KEY (transactionheaderid, orderitemid, modifiergroupid, modifierid);


--
-- TOC entry 5906 (class 2606 OID 676695)
-- Name: vw_offer_analysis trxnid_recommendationid_itemid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT trxnid_recommendationid_itemid_uidx UNIQUE (transactionheaderid, recommendationid, offereditem);


--
-- TOC entry 5890 (class 2606 OID 459796)
-- Name: userbehaviour_exceptions userbehaviour_exceptions_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour_exceptions
    ADD CONSTRAINT userbehaviour_exceptions_pkey PRIMARY KEY (id);


--
-- TOC entry 5823 (class 2606 OID 33010)
-- Name: userbehaviour userbehaviour_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour
    ADD CONSTRAINT userbehaviour_pkey PRIMARY KEY (id);


--
-- TOC entry 5825 (class 2606 OID 787891)
-- Name: watermarktable watermarktablename_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.watermarktable
    ADD CONSTRAINT watermarktablename_pk PRIMARY KEY (watermarktablename, source);


--
-- TOC entry 5892 (class 2606 OID 461044)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 5772 (class 1259 OID 32826)
-- Name: IX_dateid_datets; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX "IX_dateid_datets" ON dim.datedim USING btree (dateid, datets);


--
-- TOC entry 5790 (class 1259 OID 32893)
-- Name: IX_organizationid_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX "IX_organizationid_locationid" ON dim.organizationlocation USING btree (organizationid, locationid) INCLUDE (organizationname, locationname);


--
-- TOC entry 5769 (class 1259 OID 32818)
-- Name: company_id_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX company_id_idx ON dim.company USING btree (companyid);


--
-- TOC entry 5861 (class 1259 OID 413633)
-- Name: deviceid_locationid_companyid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX deviceid_locationid_companyid_idx ON dim.device USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, state, testmode);


--
-- TOC entry 5783 (class 1259 OID 32870)
-- Name: dim_location_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX dim_location_idx ON dim.location USING btree (locationid);


--
-- TOC entry 5775 (class 1259 OID 32827)
-- Name: idx_datedim_dateid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_datedim_dateid ON dim.datedim USING btree (dateid);


--
-- TOC entry 5776 (class 1259 OID 32828)
-- Name: idx_datedim_datets; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_datedim_datets ON dim.datedim USING btree (datets);


--
-- TOC entry 5862 (class 1259 OID 413634)
-- Name: idx_device_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_id ON dim.device USING btree (deviceid);


--
-- TOC entry 5863 (class 1259 OID 413635)
-- Name: idx_device_location_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_location_id ON dim.device USING btree (locationid);


--
-- TOC entry 5864 (class 1259 OID 413636)
-- Name: idx_device_state; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_state ON dim.device USING btree (state);


--
-- TOC entry 5865 (class 1259 OID 413637)
-- Name: idx_device_testmode; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_testmode ON dim.device USING btree (testmode);


--
-- TOC entry 5909 (class 1259 OID 695510)
-- Name: idx_menuentities_catalog; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_menuentities_catalog ON dim.menuentities USING btree (catalogid);


--
-- TOC entry 5910 (class 1259 OID 695512)
-- Name: idx_menuentities_mealavail; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_menuentities_mealavail ON dim.menuentities USING gin (mealavailability);


--
-- TOC entry 5911 (class 1259 OID 695511)
-- Name: idx_menuentities_tags; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_menuentities_tags ON dim.menuentities USING gin (tags);


--
-- TOC entry 5791 (class 1259 OID 32894)
-- Name: idx_organizationlocation_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_organizationlocation_locationid ON dim.organizationlocation USING btree (locationid);


--
-- TOC entry 5792 (class 1259 OID 32895)
-- Name: idx_organizationlocation_organizationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_organizationlocation_organizationid ON dim.organizationlocation USING btree (organizationid);


--
-- TOC entry 5795 (class 1259 OID 32911)
-- Name: idx_view_viewid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_view_viewid ON dim.view USING btree (viewid);


--
-- TOC entry 5895 (class 1259 OID 514419)
-- Name: itemcategory_bkp_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX itemcategory_bkp_idx ON dim.itemcategory_bkp USING btree (locationid, categoryid);


--
-- TOC entry 5896 (class 1259 OID 514420)
-- Name: itemcategory_bkp_locationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX itemcategory_bkp_locationid_idx ON dim.itemcategory_bkp USING btree (locationid) INCLUDE (categoryid, isactive);


--
-- TOC entry 5779 (class 1259 OID 32845)
-- Name: itemcategory_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX itemcategory_idx ON dim.itemcategory USING btree (locationid, categoryid);


--
-- TOC entry 5780 (class 1259 OID 263819)
-- Name: itemcategory_locationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX itemcategory_locationid_idx ON dim.itemcategory USING btree (locationid) INCLUDE (categoryid, isactive);


--
-- TOC entry 5786 (class 1259 OID 263829)
-- Name: locationgroupid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX locationgroupid_idx ON dim.location USING btree (locationgroupid);


--
-- TOC entry 5787 (class 1259 OID 32887)
-- Name: order_type_uidx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX order_type_uidx ON dim.ordertype USING btree (locationid, kioskid, ordertypeid);


--
-- TOC entry 5833 (class 1259 OID 263842)
-- Name: organizationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX organizationid_idx ON dim.occasionsurvey USING btree (organizationid);


--
-- TOC entry 5868 (class 1259 OID 413652)
-- Name: peripheral_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX peripheral_idx ON dim.peripheral USING btree (deviceid, peripheralid) INCLUDE (peripheraltype, state, statechangedate);


--
-- TOC entry 5832 (class 1259 OID 263813)
-- Name: rating_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX rating_idx ON dim.feedbackrating USING btree (rating) INCLUDE (ratingdesc);


--
-- TOC entry 5838 (class 1259 OID 263843)
-- Name: surveyid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX surveyid_idx ON dim.occasionsurvey USING btree (surveyid) INCLUDE (surveyname, surveytype);


--
-- TOC entry 5831 (class 1259 OID 263814)
-- Name: surveytransstatus_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX surveytransstatus_idx ON dim.feedbackstatus USING btree (surveytransstatus) INCLUDE (statusdesc);


--
-- TOC entry 5796 (class 1259 OID 32927)
-- Name: deviceeventidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX deviceeventidx ON fact.deviceevent USING btree (companyid, locationid);


--
-- TOC entry 5797 (class 1259 OID 32928)
-- Name: deviceeventuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX deviceeventuidx ON fact.deviceevent USING btree (application, companyid, locationid, moduleid, eventtoken, datacategory, actiontype, eventinstant);


--
-- TOC entry 5871 (class 1259 OID 413952)
-- Name: devicehealth_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX devicehealth_idx ON fact.devicehealth USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, status, healthdatatype, healthdatatime, statuschangetime);


--
-- TOC entry 5874 (class 1259 OID 413953)
-- Name: deviceid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX deviceid_idx ON fact.devicehealth USING btree (deviceid);


--
-- TOC entry 5875 (class 1259 OID 413954)
-- Name: idx_devicehealth_deviceid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicehealth_deviceid ON fact.devicehealth USING btree (deviceid);


--
-- TOC entry 5876 (class 1259 OID 413955)
-- Name: idx_devicehealth_deviceid_status_time; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicehealth_deviceid_status_time ON fact.devicehealth USING btree (deviceid, status, healthdatatime DESC);


--
-- TOC entry 5877 (class 1259 OID 413956)
-- Name: idx_devicehealth_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicehealth_locationid ON fact.devicehealth USING btree (locationid);


--
-- TOC entry 5799 (class 1259 OID 32934)
-- Name: idx_devicestate; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicestate ON fact.devicestate USING btree (locationid, companyid, deviceid) WITH (deduplicate_items='true');


--
-- TOC entry 5800 (class 1259 OID 32935)
-- Name: idx_devicestate_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicestate_dateid ON fact.devicestate USING btree (dateid);


--
-- TOC entry 5801 (class 1259 OID 32936)
-- Name: idx_devicestate_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicestate_locationid ON fact.devicestate USING btree (locationid);


--
-- TOC entry 5828 (class 1259 OID 159819)
-- Name: idx_devicetelemetry; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicetelemetry ON fact.devicetelemetry USING btree (locationid, deviceid);


--
-- TOC entry 5829 (class 1259 OID 159820)
-- Name: idx_devicetelemetry_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicetelemetry_dateid ON fact.devicetelemetry USING btree (dateid);


--
-- TOC entry 5830 (class 1259 OID 159821)
-- Name: idx_devicetelemetry_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicetelemetry_locationid ON fact.devicetelemetry USING btree (locationid);


--
-- TOC entry 5809 (class 1259 OID 309287)
-- Name: idx_fact_pipelinerunstatus_correlationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_fact_pipelinerunstatus_correlationid ON fact.pipelinerunstatus USING btree (correlationid) INCLUDE (pipelinestatus);


--
-- TOC entry 5815 (class 1259 OID 32996)
-- Name: idx_transactionitem_headerid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_transactionitem_headerid ON fact.transactionitem USING btree (transactionheaderid);


--
-- TOC entry 5816 (class 1259 OID 215384)
-- Name: idx_transactionitemtest_headerid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_transactionitemtest_headerid ON fact.transactionitem USING btree (transactionheaderid);


--
-- TOC entry 5899 (class 1259 OID 547181)
-- Name: idx_transactionrefunds_headerid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_transactionrefunds_headerid ON fact.transactionrefunds USING btree (transactionheaderid);


--
-- TOC entry 5802 (class 1259 OID 32951)
-- Name: itemmodifieridx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX itemmodifieridx ON fact.itemmodifier USING btree (itemid);


--
-- TOC entry 5798 (class 1259 OID 2198165)
-- Name: ix_deviceevent_journey_lookup; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX ix_deviceevent_journey_lookup ON fact.deviceevent USING btree (locationid, dateid, datacategory, eventtoken) WHERE ((datacategory = 'insight'::text) AND (actiontype = ANY (ARRAY['CategorySelected'::text, 'SubCategorySelected'::text, 'RegularItemSelected'::text, 'ItemRemoved'::text, 'ModifierGroupSelected'::text, 'ModifierSelected'::text, 'ModifierUnselected'::text])));


--
-- TOC entry 5904 (class 1259 OID 676696)
-- Name: locationid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX locationid_idx ON fact.vw_offer_analysis USING btree (locationid);


--
-- TOC entry 5880 (class 1259 OID 413969)
-- Name: peripheralhealth_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX peripheralhealth_idx ON fact.peripheralhealth USING btree (healthdataid, peripheralid) INCLUDE (peripheraltype, status);


--
-- TOC entry 5808 (class 1259 OID 32964)
-- Name: peripheralstate_uidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE UNIQUE INDEX peripheralstate_uidx ON fact.peripheralstate USING btree (deviceid, peripheralid, state, statestart);


--
-- TOC entry 5812 (class 1259 OID 263880)
-- Name: transactionheader_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionheader_locationid_dateid_idx ON fact.transactionheader USING btree (locationid, dateid) INCLUDE (orderstatus, ordertype, businessdate);


--
-- TOC entry 5803 (class 1259 OID 263867)
-- Name: transactionheaderid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionheaderid_idx ON fact.itemmodifier USING btree (transactionheaderid);


--
-- TOC entry 5819 (class 1259 OID 33002)
-- Name: transactionpayment_orderid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionpayment_orderid_idx ON fact.transactionpayment USING btree (orderid);


--
-- TOC entry 5820 (class 1259 OID 33003)
-- Name: transactionpaymentuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionpaymentuidx ON fact.transactionpayment USING btree (transactionheaderid, paymentintegrationid, paymentid);


--
-- TOC entry 5821 (class 1259 OID 263900)
-- Name: userbehaviour_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX userbehaviour_locationid_dateid_idx ON fact.userbehaviour USING btree (locationid, dateid) INCLUDE (ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier);


--
-- TOC entry 5952 (class 2606 OID 413647)
-- Name: peripheral peripheral_deviceid_fkey; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES dim.device(id);


--
-- TOC entry 5938 (class 2606 OID 514947)
-- Name: transactionitem categoryid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT categoryid_fk FOREIGN KEY (categoryid) REFERENCES dim.itemcategory(id);


--
-- TOC entry 5943 (class 2606 OID 788239)
-- Name: devicetelemetry location_deviceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT location_deviceid_fk FOREIGN KEY (locationid, deviceid) REFERENCES dim.kiosk(locationid, kioskid);


--
-- TOC entry 5954 (class 2606 OID 775338)
-- Name: recommendations location_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 5944 (class 2606 OID 788249)
-- Name: devicetelemetry locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 5935 (class 2606 OID 775954)
-- Name: transactionheader locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 5939 (class 2606 OID 779636)
-- Name: transactionitem locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 5945 (class 2606 OID 784801)
-- Name: itemssurvey locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 5948 (class 2606 OID 784796)
-- Name: occasionsurveydetail locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 5940 (class 2606 OID 774863)
-- Name: transactionitem locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 5942 (class 2606 OID 775974)
-- Name: transactionpayment locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionpayment
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 5955 (class 2606 OID 775984)
-- Name: vw_offer_analysis locationid_trxnid_recommendationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT locationid_trxnid_recommendationid_fk FOREIGN KEY (locationid, transactionheaderid, recommendationid) REFERENCES fact.recommendations(locationid, transactionheaderid, recommendationid);


--
-- TOC entry 5941 (class 2606 OID 359444)
-- Name: transactionitem menuitemid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT menuitemid_fk FOREIGN KEY (menuitemid) REFERENCES dim.menuitem(id);


--
-- TOC entry 5936 (class 2606 OID 775964)
-- Name: transactionheader ordertype_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT ordertype_fk FOREIGN KEY (ordertype) REFERENCES dim.ordertype(id);


--
-- TOC entry 5934 (class 2606 OID 788254)
-- Name: deviceevent orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.deviceevent
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (companyid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 5946 (class 2606 OID 788219)
-- Name: itemssurvey orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 5949 (class 2606 OID 788224)
-- Name: occasionsurveydetail orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 5947 (class 2606 OID 780634)
-- Name: itemssurvey orgid_surveyid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT orgid_surveyid_fk FOREIGN KEY (organizationid, surveyid) REFERENCES dim.occasionsurvey(organizationid, surveyid);


--
-- TOC entry 5950 (class 2606 OID 780639)
-- Name: occasionsurveydetail orgid_surveyid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT orgid_surveyid_fk FOREIGN KEY (organizationid, surveyid) REFERENCES dim.occasionsurvey(organizationid, surveyid);


--
-- TOC entry 5953 (class 2606 OID 413964)
-- Name: peripheralhealth peripheralhealth_healthdataid_fkey; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.peripheralhealth
    ADD CONSTRAINT peripheralhealth_healthdataid_fkey FOREIGN KEY (healthdataid) REFERENCES fact.devicehealth(id);


--
-- TOC entry 5956 (class 2606 OID 779648)
-- Name: vw_offer_analysis selecteditem_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT selecteditem_fk FOREIGN KEY (selecteditem) REFERENCES dim.menuitem(menuitemid);


--
-- TOC entry 5951 (class 2606 OID 774836)
-- Name: occasionsurveydetail sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);


--
-- TOC entry 5937 (class 2606 OID 787892)
-- Name: transactionheader sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);


--
-- TOC entry 6131 (class 0 OID 0)
-- Dependencies: 55
-- Name: SCHEMA dim; Type: ACL; Schema: -; Owner: citus
--

GRANT USAGE ON SCHEMA dim TO dhanraj;
GRANT USAGE ON SCHEMA dim TO varshil;


--
-- TOC entry 6132 (class 0 OID 0)
-- Dependencies: 56
-- Name: SCHEMA fact; Type: ACL; Schema: -; Owner: citus
--

GRANT USAGE ON SCHEMA fact TO dhanraj;
GRANT USAGE ON SCHEMA fact TO varshil;


--
-- TOC entry 6133 (class 0 OID 0)
-- Dependencies: 373
-- Name: TABLE abtests; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.abtests TO varshil;


--
-- TOC entry 6134 (class 0 OID 0)
-- Dependencies: 339
-- Name: TABLE datedim; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.datedim TO dhanraj;
GRANT SELECT ON TABLE dim.datedim TO varshil;


--
-- TOC entry 6135 (class 0 OID 0)
-- Dependencies: 346
-- Name: TABLE businessdate; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.businessdate TO dhanraj;
GRANT SELECT ON TABLE dim.businessdate TO varshil;


--
-- TOC entry 6136 (class 0 OID 0)
-- Dependencies: 338
-- Name: TABLE company; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.company TO dhanraj;
GRANT SELECT ON TABLE dim.company TO varshil;


--
-- TOC entry 6137 (class 0 OID 0)
-- Dependencies: 379
-- Name: TABLE device; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.device TO varshil;


--
-- TOC entry 6138 (class 0 OID 0)
-- Dependencies: 340
-- Name: TABLE element; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.element TO dhanraj;
GRANT SELECT ON TABLE dim.element TO varshil;


--
-- TOC entry 6139 (class 0 OID 0)
-- Dependencies: 384
-- Name: TABLE experiment; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.experiment TO varshil;


--
-- TOC entry 6141 (class 0 OID 0)
-- Dependencies: 364
-- Name: TABLE feedbackrating; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackrating TO varshil;


--
-- TOC entry 6142 (class 0 OID 0)
-- Dependencies: 363
-- Name: TABLE feedbackstatus; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackstatus TO varshil;


--
-- TOC entry 6143 (class 0 OID 0)
-- Dependencies: 370
-- Name: TABLE frequentcustomer; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.frequentcustomer TO varshil;


--
-- TOC entry 6144 (class 0 OID 0)
-- Dependencies: 401
-- Name: TABLE grubbrr_source_lookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.grubbrr_source_lookup TO varshil;


--
-- TOC entry 6145 (class 0 OID 0)
-- Dependencies: 341
-- Name: TABLE itemcategory; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory TO dhanraj;
GRANT SELECT ON TABLE dim.itemcategory TO varshil;


--
-- TOC entry 6146 (class 0 OID 0)
-- Dependencies: 391
-- Name: TABLE itemcategory_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory_bkp TO varshil;


--
-- TOC entry 6147 (class 0 OID 0)
-- Dependencies: 395
-- Name: TABLE itemcategorymapping; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategorymapping TO varshil;


--
-- TOC entry 6148 (class 0 OID 0)
-- Dependencies: 371
-- Name: TABLE kiosk; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kiosk TO varshil;


--
-- TOC entry 6149 (class 0 OID 0)
-- Dependencies: 394
-- Name: TABLE kioskdetails; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kioskdetails TO varshil;


--
-- TOC entry 6150 (class 0 OID 0)
-- Dependencies: 342
-- Name: TABLE location; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.location TO dhanraj;
GRANT SELECT ON TABLE dim.location TO varshil;


--
-- TOC entry 6151 (class 0 OID 0)
-- Dependencies: 372
-- Name: TABLE locationcatalog; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.locationcatalog TO varshil;


--
-- TOC entry 6152 (class 0 OID 0)
-- Dependencies: 400
-- Name: TABLE menuentities; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuentities TO varshil;


--
-- TOC entry 6153 (class 0 OID 0)
-- Dependencies: 376
-- Name: TABLE menuitem; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuitem TO varshil;


--
-- TOC entry 6154 (class 0 OID 0)
-- Dependencies: 366
-- Name: TABLE occasionsurvey; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.occasionsurvey TO varshil;


--
-- TOC entry 6155 (class 0 OID 0)
-- Dependencies: 343
-- Name: TABLE ordertype; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype TO dhanraj;
GRANT SELECT ON TABLE dim.ordertype TO varshil;


--
-- TOC entry 6156 (class 0 OID 0)
-- Dependencies: 396
-- Name: TABLE ordertype_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype_bkp TO varshil;


--
-- TOC entry 6157 (class 0 OID 0)
-- Dependencies: 385
-- Name: TABLE organization; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organization TO varshil;


--
-- TOC entry 6158 (class 0 OID 0)
-- Dependencies: 344
-- Name: TABLE organizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.organizationlocation TO varshil;


--
-- TOC entry 6159 (class 0 OID 0)
-- Dependencies: 380
-- Name: TABLE peripheral; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.peripheral TO varshil;


--
-- TOC entry 6160 (class 0 OID 0)
-- Dependencies: 390
-- Name: TABLE upsellgrouplookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.upsellgrouplookup TO varshil;


--
-- TOC entry 6161 (class 0 OID 0)
-- Dependencies: 360
-- Name: TABLE userlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.userlocation TO varshil;


--
-- TOC entry 6162 (class 0 OID 0)
-- Dependencies: 345
-- Name: TABLE view; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.view TO dhanraj;
GRANT SELECT ON TABLE dim.view TO varshil;


--
-- TOC entry 6163 (class 0 OID 0)
-- Dependencies: 378
-- Name: TABLE weather; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather TO varshil;


--
-- TOC entry 6164 (class 0 OID 0)
-- Dependencies: 407
-- Name: TABLE vw_weatherhourlydata; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vw_weatherhourlydata TO varshil;


--
-- TOC entry 6165 (class 0 OID 0)
-- Dependencies: 347
-- Name: TABLE vworganizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vworganizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.vworganizationlocation TO varshil;


--
-- TOC entry 6166 (class 0 OID 0)
-- Dependencies: 377
-- Name: TABLE weather_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather_bkp TO varshil;


--
-- TOC entry 6167 (class 0 OID 0)
-- Dependencies: 406
-- Name: TABLE cep_incidents; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.cep_incidents TO dhanraj;


--
-- TOC entry 6168 (class 0 OID 0)
-- Dependencies: 398
-- Name: TABLE customer_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.customer_menu_preferences TO varshil;


--
-- TOC entry 6169 (class 0 OID 0)
-- Dependencies: 348
-- Name: TABLE deviceevent; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.deviceevent TO dhanraj;
GRANT SELECT ON TABLE fact.deviceevent TO varshil;


--
-- TOC entry 6170 (class 0 OID 0)
-- Dependencies: 381
-- Name: TABLE devicehealth; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicehealth TO varshil;


--
-- TOC entry 6171 (class 0 OID 0)
-- Dependencies: 349
-- Name: TABLE devicestate; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicestate TO dhanraj;
GRANT SELECT ON TABLE fact.devicestate TO varshil;


--
-- TOC entry 6172 (class 0 OID 0)
-- Dependencies: 361
-- Name: TABLE devicetelemetry; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicetelemetry TO varshil;


--
-- TOC entry 6173 (class 0 OID 0)
-- Dependencies: 350
-- Name: TABLE itemmodifier; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemmodifier TO dhanraj;
GRANT SELECT ON TABLE fact.itemmodifier TO varshil;


--
-- TOC entry 6174 (class 0 OID 0)
-- Dependencies: 374
-- Name: TABLE itemssurvey; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemssurvey TO varshil;


--
-- TOC entry 6175 (class 0 OID 0)
-- Dependencies: 399
-- Name: TABLE location_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.location_menu_preferences TO varshil;


--
-- TOC entry 6176 (class 0 OID 0)
-- Dependencies: 375
-- Name: TABLE occasionsurveydetail; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.occasionsurveydetail TO varshil;


--
-- TOC entry 6177 (class 0 OID 0)
-- Dependencies: 351
-- Name: TABLE ordertiming; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.ordertiming TO dhanraj;
GRANT SELECT ON TABLE fact.ordertiming TO varshil;


--
-- TOC entry 6178 (class 0 OID 0)
-- Dependencies: 382
-- Name: TABLE peripheralhealth; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.peripheralhealth TO varshil;


--
-- TOC entry 6179 (class 0 OID 0)
-- Dependencies: 352
-- Name: TABLE peripheralstate; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.peripheralstate TO dhanraj;
GRANT SELECT ON TABLE fact.peripheralstate TO varshil;


--
-- TOC entry 6180 (class 0 OID 0)
-- Dependencies: 353
-- Name: TABLE pipelinerunstatus; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.pipelinerunstatus TO dhanraj;
GRANT SELECT ON TABLE fact.pipelinerunstatus TO varshil;


--
-- TOC entry 6181 (class 0 OID 0)
-- Dependencies: 387
-- Name: TABLE recommendations; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.recommendations TO varshil;


--
-- TOC entry 6182 (class 0 OID 0)
-- Dependencies: 386
-- Name: TABLE recommendations_bkp; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.recommendations_bkp TO varshil;


--
-- TOC entry 6183 (class 0 OID 0)
-- Dependencies: 354
-- Name: TABLE timingsdatalake; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.timingsdatalake TO dhanraj;
GRANT SELECT ON TABLE fact.timingsdatalake TO varshil;


--
-- TOC entry 6184 (class 0 OID 0)
-- Dependencies: 355
-- Name: TABLE transactionheader; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionheader TO dhanraj;
GRANT SELECT ON TABLE fact.transactionheader TO varshil;


--
-- TOC entry 6185 (class 0 OID 0)
-- Dependencies: 356
-- Name: TABLE transactionitem; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionitem TO dhanraj;
GRANT SELECT ON TABLE fact.transactionitem TO varshil;


--
-- TOC entry 6186 (class 0 OID 0)
-- Dependencies: 367
-- Name: TABLE transactionitemtest; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionitemtest TO varshil;


--
-- TOC entry 6187 (class 0 OID 0)
-- Dependencies: 357
-- Name: TABLE transactionpayment; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionpayment TO dhanraj;
GRANT SELECT ON TABLE fact.transactionpayment TO varshil;


--
-- TOC entry 6188 (class 0 OID 0)
-- Dependencies: 392
-- Name: TABLE transactionrefunds; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionrefunds TO varshil;


--
-- TOC entry 6189 (class 0 OID 0)
-- Dependencies: 358
-- Name: TABLE userbehaviour; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour TO dhanraj;
GRANT SELECT ON TABLE fact.userbehaviour TO varshil;


--
-- TOC entry 6190 (class 0 OID 0)
-- Dependencies: 388
-- Name: TABLE userbehaviour_exceptions; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour_exceptions TO varshil;


--
-- TOC entry 6191 (class 0 OID 0)
-- Dependencies: 362
-- Name: TABLE usercheckedin; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.usercheckedin TO varshil;


--
-- TOC entry 6192 (class 0 OID 0)
-- Dependencies: 397
-- Name: TABLE vw_offer_analysis; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.vw_offer_analysis TO varshil;


--
-- TOC entry 6193 (class 0 OID 0)
-- Dependencies: 359
-- Name: TABLE watermarktable; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.watermarktable TO dhanraj;
GRANT SELECT ON TABLE fact.watermarktable TO varshil;


-- Completed on 2026-04-05 21:17:59

--
-- PostgreSQL database dump complete
--

\unrestrict Srh6knFxTdux5gILLBr4yu6OgvQbV8H56pAanBIG5Ty7bEoQYIFezJt3D4Ud6IL

