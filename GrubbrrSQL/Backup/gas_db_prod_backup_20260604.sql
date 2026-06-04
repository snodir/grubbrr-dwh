--
-- PostgreSQL database dump
--

\restrict zEgOtQk6a2doVlVlMsXHmBUOvIsHloN5QUziWNdrdMHoWTONwdIxn0Ja8a2dewd

-- Dumped from database version 16.9 (Ubuntu 16.9-1.pgdg20.04+1)
-- Dumped by pg_dump version 18.3

-- Started on 2026-06-04 21:41:59

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
-- TOC entry 71 (class 2615 OID 19776)
-- Name: dim; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA dim;


ALTER SCHEMA dim OWNER TO citus;

--
-- TOC entry 79 (class 2615 OID 19784)
-- Name: fact; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA fact;


ALTER SCHEMA fact OWNER TO citus;

--
-- TOC entry 68 (class 2615 OID 35926235)
-- Name: ml; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA ml;


ALTER SCHEMA ml OWNER TO citus;

--
-- TOC entry 61 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 6303 (class 0 OID 0)
-- Dependencies: 61
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 54 (class 2615 OID 2847971)
-- Name: stg; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA stg;


ALTER SCHEMA stg OWNER TO citus;

--
-- TOC entry 1234 (class 1255 OID 12564540)
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
-- TOC entry 784 (class 1255 OID 13743406)
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
-- TOC entry 1097 (class 1255 OID 12531087)
-- Name: usp_grubbrr_install_base(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_grubbrr_install_base()
    LANGUAGE plpgsql
    AS $$

BEGIN

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

END;
$$;


ALTER PROCEDURE dim.usp_grubbrr_install_base() OWNER TO citus;

--
-- TOC entry 492 (class 1255 OID 27639264)
-- Name: usp_master_keys_for_duplicate_items(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_master_keys_for_duplicate_items()
    LANGUAGE plpgsql
    AS $$

BEGIN

TRUNCATE TABLE dim.duplicate_items_master;

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
  /*AND NOT EXISTS (SELECT 1 FROM dim.duplicate_items_master as dim
                  WHERE dim.locationid = di.locationid
                    AND dim.categoryid = di.categoryid
                    AND dim.menuitemid = di.menuitemid)*/
  ;

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
-- TOC entry 1303 (class 1255 OID 19972)
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
-- TOC entry 761 (class 1255 OID 19974)
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
-- TOC entry 885 (class 1255 OID 19973)
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
-- TOC entry 826 (class 1255 OID 12531309)
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
UNION --all
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
-- TOC entry 735 (class 1255 OID 39161128)
-- Name: usp_gem_sent_surveys_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_gem_sent_surveys_to_fact()
    LANGUAGE plpgsql
    AS $$

BEGIN

INSERT INTO fact.sent_surveys
SELECT
    organizationid,
    locationid,
    ordersessionid,
    orderid,
    gem_event_category,
    gem_event_type,
    survey_metadata :: jsonb as survey_metadata,
    is_responded,
    gem_event_instant,
    gem_syscosmosts,
    sysinserttime,
    sysupdatetime
FROM stg.sent_surveys AS ss
WHERE NOT EXISTS (SELECT 1 FROM fact.sent_surveys as fs 
                  WHERE fs.locationid = ss.locationid 
                    AND fs.ordersessionid = ss.ordersessionid);

UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(gem_syscosmosts), 1775002010) FROM fact.sent_surveys)
WHERE watermarktablename = 'fact.sent_surveys'
  AND source = 'gem';

END;
$$;


ALTER PROCEDURE fact.usp_gem_sent_surveys_to_fact() OWNER TO citus;

--
-- TOC entry 1182 (class 1255 OID 39161123)
-- Name: usp_item_recommendations_stage_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_item_recommendations_stage_to_fact()
    LANGUAGE plpgsql
    AS $$

BEGIN

insert into fact.recommendations 
(transactionheaderid, locationid, recommendationid, offereditems, selecteditems, isconverted, prompttimestamp, sysinserttime, syscosmosts)
select rc.transactionheaderid,
       rc.locationid,
       rc.recommendationid, 
       rc.offereditems :: jsonb, 
       rc.selecteditems :: jsonb, 
       case when (rc.selecteditems = '[]' or rc.selecteditems is null) then false else true end as isconverted,
       rc.prompttimestamp, 
       rc.sysinserttime,
       rc.syscosmosts
from stg.recommendations as rc
where not exists (select 1 from fact.recommendations as th where th.transactionheaderid = rc.transactionheaderid and th.recommendationid = rc.recommendationid);

END;
$$;


ALTER PROCEDURE fact.usp_item_recommendations_stage_to_fact() OWNER TO citus;

--
-- TOC entry 963 (class 1255 OID 11970234)
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
-- TOC entry 1283 (class 1255 OID 27639265)
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
-- TOC entry 750 (class 1255 OID 39161125)
-- Name: usp_modifier_impression_analysis(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_modifier_impression_analysis()
    LANGUAGE plpgsql
    AS $$

BEGIN

WITH delta_impressions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_impressions' AND source = 'nge')
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_impressions as mim 
                  WHERE mim.locationid = mrc.locationid
                    AND mim.transactionheaderid = mrc.transactionheaderid)
), modifier_impressions AS (
SELECT mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       mrc.orderid,
       outer_elem->>'itemId'                 AS menuitemid,
       rec->>'modifierId'                    AS modifierid,
       outer_elem->>'parentModifierId'       AS parent_modifier_id,
       outer_elem->>'selectionType'          AS selection_type,
      (outer_elem->>'nestingDepth')::INTEGER AS nesting_depth,    
      (rec->>'position')::INTEGER            AS position,
      (rec->>'score')::NUMERIC(5, 3)         AS score,
       outer_elem->>'strategy'               AS strategy,
       outer_elem->>'context'                AS context,
      (rec->>'selected')::boolean            AS selected,
      (rec->>'preDeselected')::boolean       AS pre_deselected,
      (rec->>'confirmedRemoved')::boolean    AS confirmed_removed,
      (rec->>'preSelected')::boolean         AS pre_selected,
       mrc.businessdate, 
       mrc.orderdatelocal,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime    
FROM delta_impressions as mrc,
    -- Step 1: unnest the top-level array
    jsonb_array_elements(modifier_impressions) AS outer_elem,
    -- Step 2: unnest the nested recommendations array
    jsonb_array_elements(outer_elem->'recommendations') AS rec
)
INSERT INTO fact.modifier_impressions
SELECT *, NULL :: TIMESTAMP as sysupdatetime
FROM modifier_impressions;

UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_impressions)
WHERE watermarktablename = 'fact.modifier_impressions'
  AND source = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_modifier_impression_analysis() OWNER TO citus;

--
-- TOC entry 617 (class 1255 OID 39161126)
-- Name: usp_modifier_interaction_analysis(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_modifier_interaction_analysis()
    LANGUAGE plpgsql
    AS $$

BEGIN

WITH delta_interactions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge-Interactions')
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_interactions as mim 
                  WHERE mim.locationid = mrc.locationid
                    AND mim.transactionheaderid = mrc.transactionheaderid)
), modifier_interactions AS (
SELECT mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       mrc.orderid,
       outer_elem->>'itemId' as menuitemid,
       outer_elem->>'action' as action,
       outer_elem->>'modifierId' as modifierid,
       (outer_elem->>'recordedAt')::TIMESTAMP as recorded_at,
       (outer_elem->>'nestingDepth') :: INTEGER as nesting_depth,
       outer_elem->>'selectionType' as selection_type,
       outer_elem->>'modifierGroupId' as modifiergroupid,
       outer_elem->>'parentModifierId' as parent_modifier_id,
       mrc.businessdate, 
       mrc.orderdatelocal,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime    
FROM delta_interactions as mrc,
    -- Step 1: unnest the top-level array
    jsonb_array_elements(modifier_interactions) AS outer_elem
), trxn_enrichment AS (
SELECT mi.locationid,
       mi.transactionheaderid,
       mi.ordersessionid,
       mi.orderid,
       imd.itemid as orderitemid,
       mi.menuitemid,
       mi.modifiergroupid,
       mi.modifierid,
       imd.modifiername,
       mi.parent_modifier_id,
       mi.nesting_depth,
       imd.modifierquantity,
       imd.modifierprice,
       imd.freequantity,
       mi.selection_type,
       mi.action,
       mi.recorded_at as session_recorded_at,
       mi.businessdate,
       mi.orderdatelocal,
       mi.frequentcustomerid,
       mi.syscosmosts,
       mi.sysinserttime
    FROM modifier_interactions as mi 
    LEFT JOIN fact.transactionitem as ti 
        ON mi.locationid = ti.locationid
        AND mi.transactionheaderid = ti.transactionheaderid
        AND mi.menuitemid = ti.dimmenuitemid
    LEFT JOIN fact.itemmodifier as imd 
        ON mi.transactionheaderid = imd.transactionheaderid
        AND ti.itemid = imd.itemid
        AND mi.modifiergroupid = imd.modifiergroupid
        AND mi.modifierid = imd.modifierid
)
INSERT INTO fact.modifier_interactions
SELECT *, 
       NULL :: TIMESTAMP as sysupdatetime, 
       5 as sourceid
FROM trxn_enrichment;

UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_interactions WHERE sourceid = 5)
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge-Interactions';


WITH delta_modifier_trxns AS (
SELECT *
FROM fact.itemmodifier as im
WHERE locationid LIKE 'loc-%'
  AND (syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge-Options') OR
       syscosmosts IS NULL)
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_interactions as mint 
                  WHERE mint.locationid = im.locationid
                    AND mint.transactionheaderid = im.transactionheaderid)
), modfr_enrichment AS (
SELECT mt.locationid,
       mt.transactionheaderid,
       ti.ordersessionid,
       ti.orderid,
       ti.itemid as orderitemid,
       ti.dimmenuitemid as menuitemid,
       mt.modifiergroupid,
       mt.modifierid,
       mt.modifiername,
       NULL :: TEXT as parent_modifier_id,
       NULL :: INTEGER as nesting_depth,
       mt.modifierquantity,
       mt.modifierprice,
       mt.freequantity,
       CASE WHEN mgm.is_default = False AND mg.min_selection = 0 AND mg.max_selection >= 0 THEN 'optional'
            WHEN mgm.is_default = False AND mg.min_selection >= 1 AND mg.max_selection >= 1 THEN 'required'
            WHEN mgm.is_default = True THEN 'default' END selection_type,

       CASE WHEN mgm.is_default = False AND mg.min_selection = 0 AND mg.max_selection >= 0 AND mt.modifierquantity >= 1 THEN 'added'                  --optional modifier added
            WHEN mgm.is_default = False AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'selected'              --required modifier selected
            WHEN mgm.is_default = True AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'kept'                   --default modifier left selected
            WHEN mgm.is_default = True AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity = 0 THEN 'removed' END AS action,  --default modifier de-selected
       NULL :: TEXT as session_recorded_at,
       mt.businessdate,
       ti.orderdatelocal,
       ti.frequentcustomerid,
       mt.syscosmosts,
       mt.sysinserttime
FROM delta_modifier_trxns as mt
LEFT JOIN dim.modifier_group_mapping as mgm
    ON mgm.modifiergroupid = mt.modifiergroupid
    AND mgm.modifierid = mt.modifierid
LEFT JOIN dim.modifier_group as mg 
    ON mg.modifiergroupid = mt.modifiergroupid
LEFT JOIN fact.transactionitem as ti 
    ON mt.transactionheaderid = ti.transactionheaderid
    AND mt.itemid = ti.itemid
)
INSERT INTO fact.modifier_interactions
SELECT *, 
       NULL :: TIMESTAMP as sysupdatetime, 
       6 as sourceid
FROM modfr_enrichment;


/*
UPDATE fact.modifier_interactions
SET modifierquantity = im.modifierquantity,
    modifierprice = im.modifierprice,
    freequantity = im.freequantity
FROM fact.itemmodifier as im 
WHERE modifier_interactions.transactionheaderid = im.transactionheaderid
  AND modifier_interactions.orderid = im.orderid 
  AND modifier_interactions.modifiergroupid = im.modifiergroupid
  AND modifier_interactions.modifierid = im.modifierid
  AND modifier_interactions.modifierquantity IS NULL
  AND modifier_interactions.modifierprice IS NULL
  AND modifier_interactions.freequantity IS NULL;
*/
UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_interactions WHERE sourceid = 6)
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge-Options';

END;
$$;


ALTER PROCEDURE fact.usp_modifier_interaction_analysis() OWNER TO citus;

--
-- TOC entry 996 (class 1255 OID 39161124)
-- Name: usp_modifier_recommendations_stage_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_modifier_recommendations_stage_to_fact()
    LANGUAGE plpgsql
    AS $$

BEGIN

insert into fact.modifier_recommendations 
(locationid, transactionheaderid, ordersessionid, orderid, modifier_impressions, modifier_interactions, 
 businessdate, orderdateutc, frequentcustomerid, syscosmosts, sysinserttime)
select mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       mrc.orderid,
       mrc.modifier_impressions :: jsonb, 
       mrc.modifier_interactions :: jsonb, 
       mrc.businessdate, 
       mrc.orderdateutc,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime
from stg.modifier_recommendation_sessions as mrc
where not exists (select 1 from fact.modifier_recommendations as mr where mr.locationid = mrc.locationid and mr.transactionheaderid = mrc.transactionheaderid);

UPDATE fact.modifier_recommendations
SET orderdatelocal = orderdateutc::TIMESTAMPTZ AT TIME ZONE l.timezone
FROM (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end as timezone from dim.location) as l
WHERE modifier_recommendations.locationid = l.locationid 
  AND modifier_recommendations.orderdatelocal is null;

UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_recommendations)
WHERE watermarktablename = 'fact.modifier_recommendations'
  AND source = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_modifier_recommendations_stage_to_fact() OWNER TO citus;

--
-- TOC entry 1015 (class 1255 OID 11504809)
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
-- TOC entry 1216 (class 1255 OID 39161129)
-- Name: usp_sent_surveys_to_fact_itemssurvey(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey()
    LANGUAGE plpgsql
    AS $$

BEGIN

DROP TABLE IF EXISTS temp_delta_sent_surveys;
CREATE TEMPORARY TABLE temp_delta_sent_surveys (
    organizationid       TEXT COLLATE pg_catalog."default",
    locationid           TEXT COLLATE pg_catalog."default",
    ordersessionid       TEXT COLLATE pg_catalog."default",
    transactionheaderid  TEXT COLLATE pg_catalog."default",
    gem_event_category   TEXT COLLATE pg_catalog."default",
    gem_event_type       TEXT COLLATE pg_catalog."default",
    orderid              TEXT COLLATE pg_catalog."default",
    surveyid             TEXT COLLATE pg_catalog."default",
    itemid               TEXT COLLATE pg_catalog."default",
    is_responded         BOOLEAN,
    gem_event_instant    TEXT COLLATE pg_catalog."default",
    gem_syscosmosts      BIGINT,
    sysinserttime        TIMESTAMP,
    sysupdatetime        TIMESTAMP,
    menuitemid           TEXT COLLATE pg_catalog."default"
);


WITH delta_sent_surveys AS (
    SELECT 
        organizationid,
        locationid,
        ordersessionid,
        orderid AS transactionheaderid,
        gem_event_category,
        gem_event_type,
        survey_metadata,
        CONCAT('ord-', (survey_metadata ->> 'orderId')::TEXT) AS orderid,
        CASE WHEN jsonb_typeof(survey_metadata -> 'surveyIds') = 'array' THEN survey_metadata -> 'surveyIds' END AS surveyid_array,
        CASE WHEN survey_metadata ->> 'surveyIds' NOT LIKE '[%]' THEN survey_metadata ->> 'surveyIds' END AS surveyid_text,
        CASE WHEN jsonb_typeof(survey_metadata -> 'itemId') = 'array' THEN survey_metadata -> 'itemId' END AS itemid_array,
        CASE WHEN survey_metadata ->> 'itemId' NOT LIKE '[%]' THEN survey_metadata ->> 'itemId' END AS itemid_text,
        is_responded,
        gem_event_instant,
        gem_syscosmosts,
        sysinserttime,
        sysupdatetime
    FROM fact.sent_surveys AS ss
    WHERE ss.gem_syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.itemssurvey' AND source = 'gem')
      AND NOT EXISTS (SELECT 1 FROM fact.itemssurvey AS its 
                      WHERE its.locationid = ss.locationid
                        AND its.orderid = ss.orderid)
), flattened_survey_trxns AS (
    SELECT
        dss.organizationid,
        dss.locationid,
        dss.ordersessionid,
        dss.transactionheaderid,
        dss.gem_event_category,
        dss.gem_event_type,
        dss.orderid,
        TRIM(flat_survey.surveyid) AS surveyid,
        --TRIM(flat_item.itemid)     AS itemid,
        dss.is_responded,
        dss.gem_event_instant,
        dss.gem_syscosmosts,
        dss.sysinserttime,
        dss.sysupdatetime
    FROM delta_sent_surveys AS dss
    CROSS JOIN LATERAL (
        SELECT unnest(
            CASE WHEN dss.surveyid_array IS NOT NULL THEN ARRAY(SELECT jsonb_array_elements_text(dss.surveyid_array))
                 WHEN dss.surveyid_text  IS NOT NULL THEN string_to_array(dss.surveyid_text, ',')
            END
        ) AS surveyid
    ) AS flat_survey
    /*CROSS JOIN LATERAL (
        SELECT unnest(
            CASE WHEN dss.itemid_array IS NOT NULL THEN ARRAY(SELECT jsonb_array_elements_text(dss.itemid_array))
                 WHEN dss.itemid_text  IS NOT NULL THEN string_to_array(dss.itemid_text, ',')
            END
        ) AS itemid
    ) AS flat_item*/
), flattened_item_trxns AS (
    SELECT
        dss.organizationid,
        dss.locationid,
        dss.ordersessionid,
        dss.transactionheaderid,
        dss.gem_event_category,
        dss.gem_event_type,
        dss.orderid,
        --TRIM(flat_survey.surveyid) AS surveyid,
        TRIM(flat_item.itemid)     AS itemid,
        dss.is_responded,
        dss.gem_event_instant,
        dss.gem_syscosmosts,
        dss.sysinserttime,
        dss.sysupdatetime
    FROM delta_sent_surveys AS dss
    /*CROSS JOIN LATERAL (
        SELECT unnest(
            CASE WHEN dss.surveyid_array IS NOT NULL THEN ARRAY(SELECT jsonb_array_elements_text(dss.surveyid_array))
                 WHEN dss.surveyid_text  IS NOT NULL THEN string_to_array(dss.surveyid_text, ',')
            END
        ) AS surveyid
    ) AS flat_survey*/
    CROSS JOIN LATERAL (
        SELECT unnest(
            CASE WHEN dss.itemid_array IS NOT NULL THEN ARRAY(SELECT jsonb_array_elements_text(dss.itemid_array))
                 WHEN dss.itemid_text  IS NOT NULL THEN string_to_array(dss.itemid_text, ',')
            END
        ) AS itemid
    ) AS flat_item

), joined_surveys_with_items AS (
    SELECT st.organizationid,
           st.locationid,
           st.ordersessionid,
           st.transactionheaderid,
           st.gem_event_category,
           st.gem_event_type,
           st.orderid,
           st.surveyid,
           it.itemid,
           st.is_responded,
           st.gem_event_instant,
           st.gem_syscosmosts,
           st.sysinserttime,
           st.sysupdatetime 
           --ti.dimmenuitemid as menuitemid
    FROM flattened_survey_trxns as st 
    LEFT JOIN flattened_item_trxns as it
        ON st.locationid = it.locationid
        AND st.transactionheaderid = it.transactionheaderid
)
INSERT INTO temp_delta_sent_surveys
SELECT * FROM joined_surveys_with_items;


INSERT INTO fact.itemssurvey (
    organizationid,
    locationid,
    ordersessionid,
    orderid,
    surveyissuedtimestamp,
    gem_event_category,
    gem_event_type,
    surveyid,
    is_responded,
    gem_event_instant,
    gem_syscosmosts,
    sysinserttime,
    sysupdatetime,
    itemid
)
SELECT
    organizationid,
    locationid,
    ordersessionid,
    transactionheaderid,
    CASE WHEN substring(gem_event_instant, 20, 1) = '.' 
         THEN replace(replace(substring(gem_event_instant, 1, 23), 'T', ' '), '+', '0') 
         ELSE replace(substring(gem_event_instant, 1, 19), 'T', ' ') 
    END AS surveyissuedtimestamp,
    gem_event_category,
    gem_event_type,
    surveyid,
    is_responded,
    gem_event_instant,
    gem_syscosmosts,
    sysinserttime,
    sysupdatetime,
    itemid
FROM temp_delta_sent_surveys as tds
WHERE NOT EXISTS (SELECT * FROM fact.itemssurvey as its 
                  WHERE its.organizationid = tds.organizationid
                    AND its.locationid = tds.locationid
                    AND its.orderid = tds.transactionheaderid
                    AND its.itemid = tds.menuitemid
                    AND its.surveyid = tds.surveyid);


UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(gem_syscosmosts), 1775002010) - 10 FROM fact.itemssurvey)
WHERE watermarktablename = 'fact.itemssurvey'
  AND source = 'gem';


END;
$$;


ALTER PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey() OWNER TO citus;

--
-- TOC entry 599 (class 1255 OID 44776302)
-- Name: usp_silver_transaction_header_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_transaction_header_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE v_max_id INTEGER;

BEGIN

SELECT MAX(id) INTO v_max_id FROM fact.transactionheader;

TRUNCATE TABLE stg.lookup_silver_transaction_header;


WITH delta_transactions AS (
SELECT
    transactionheaderid,
    orderid,
    locationid,
    kioskid,
    ordersessionid,
    fact.parse_iso_timestamp(orderdateutc) as orderdateutc,
    order_completion_status AS orderstatus,
    ordertype as ordertypeid,
    numberofitems,
    numberofpayments,
    usd_reward      :: NUMERIC(12,3) AS ordersredeemedrewards,
    usd_subtotal    :: NUMERIC(12,3) AS ordersubtotal,
    usd_amount      :: NUMERIC(12,3) AS ordertotal,
    usd_tax         :: NUMERIC(12,3) AS ordertax,
    usd_tip         :: NUMERIC(12,3) AS ordertip,          
    usd_discount    :: NUMERIC(12,3) AS orderdiscount,
    usd_charity_amount   :: NUMERIC(12,3) AS charityamount,
    usd_service_charge   :: NUMERIC(12,3) AS orderservicecharge,
    businessdate    :: DATE AS businessdate,
    CASE channel WHEN 0 THEN 'Kiosk' WHEN 1 THEN 'OnlineOrdering' ELSE 'External' END AS channel,
    guest_count AS guestcount,
    frequentcustomerid,
    customername,
    syscosmosts,                                            -- must be carried through for the ORDER BY below
    ROW_NUMBER() OVER(PARTITION BY locationid, transactionheaderid ORDER BY orderdateutc DESC) AS row_num
FROM stg.silver_transaction_header AS sth
WHERE is_test_order = False OR is_test_order IS NULL
), qualified_trxns AS (
SELECT
    dt.*,
    ot.id AS ordertype,
    dt.orderdateutc :: TIMESTAMPTZ AT TIME ZONE l.timezone AS orderdatelocal
FROM delta_transactions AS dt
LEFT JOIN dim.ordertype AS ot
    ON  dt.locationid  = ot.locationid
    AND dt.kioskid     = ot.kioskid
    AND dt.ordertypeid = ot.ordertypeid
LEFT JOIN dim.organization AS l  
    ON dt.locationid = l.id
WHERE dt.row_num = 1
)
INSERT INTO stg.lookup_silver_transaction_header
SELECT
    ROW_NUMBER() OVER (ORDER BY syscosmosts) + v_max_id AS id,
    transactionheaderid,
    orderid,
    locationid,
    kioskid,
    ordersessionid,
    CAST(TO_CHAR(orderdatelocal, 'YYYYMMDDHH24') AS INTEGER) AS dateid,
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
    0.0 :: NUMERIC(12,3)               AS orderbalance,
    CASE WHEN numberofpayments > 0 THEN 'paid' END AS payment_status,
    'NGE'                              AS sourcefile,
    now() :: TIMESTAMP                 AS createddate,
    charityamount,
    orderservicecharge,
    businessdate,
    syscosmosts,
    channel,
    guestcount,
    frequentcustomerid,
    customername                       
FROM qualified_trxns;


-- Order Timing Fields 

DROP TABLE IF EXISTS temp_transaction_header;
CREATE TEMPORARY TABLE IF NOT EXISTS temp_transaction_header (
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
    customername            TEXT COLLATE pg_catalog."default"
);

INSERT INTO temp_transaction_header
SELECT * FROM stg.lookup_silver_transaction_header AS sth
WHERE NOT EXISTS (
                    SELECT 1
                    FROM fact.transactionheader AS th
                    WHERE th.locationid          = sth.locationid
                      AND th.transactionheaderid = sth.transactionheaderid
                );

IF EXISTS (SELECT 1 FROM temp_transaction_header)
THEN

    WITH aggregated_kiosk_events AS (

    SELECT ke.locationid, ke.token,
        min(CASE WHEN lower(ke.eventcategory) = 'session' AND lower (ke.eventtype) = 'started' THEN eventinstant END) AS orderstarttime,
        min(CASE WHEN lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'revieworderclicked' THEN eventinstant END) AS reviewordertime,
        min(CASE WHEN lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'checkoutclicked' THEN eventinstant END) AS checkouttime,
        min(CASE WHEN lower(ke.eventcategory) = 'payment' AND lower (ke.eventtype) = 'create' THEN eventinstant END) AS paystarttime,
        max(CASE WHEN lower(ke.eventcategory) IN ('session','order') AND lower(ke.eventtype) = 'closed' THEN eventinstant END) AS sessionendtime
    FROM stg.silver_kiosk_events as ke 
    WHERE((lower(ke.eventcategory) = 'session' AND lower (ke.eventtype) = 'started') OR 
        (lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'revieworderclicked') OR 
        (lower(ke.eventcategory) IN ('order','insight') AND lower(ke.eventtype) = 'checkoutclicked') OR 
        (lower(ke.eventcategory) = 'payment' AND lower (ke.eventtype) = 'create') OR  
        (lower(ke.eventcategory) IN ('session','order') AND lower(ke.eventtype) = 'closed'))
    AND lower(ke.severity) = 'information'
    GROUP BY ke.locationid, ke.token

    ), orders_enriched_with_ordertiming_fields AS (
    SELECT tth.*,
        fact.parse_iso_timestamp(orderstarttime) :: TIMESTAMP as orderstarttime,
        fact.parse_iso_timestamp(reviewordertime) :: TIMESTAMP as reviewordertime,
        fact.parse_iso_timestamp(checkouttime) :: TIMESTAMP as checkouttime,
        fact.parse_iso_timestamp(paystarttime) :: TIMESTAMP as paystarttime,
        fact.parse_iso_timestamp(sessionendtime) :: TIMESTAMP as sessionendtime
    FROM temp_transaction_header as tth 
    LEFT JOIN aggregated_kiosk_events as ke 
        ON ke.locationid = tth.locationid
        AND ke.token     = tth.ordersessionid
    )
    INSERT INTO fact.transactionheader(
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
        updateddate,
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
        abtestid,
        channel,
        guestcount,
        charityamount,
        syscosmosts,
        sourceid,
        orderservicecharge,
        customername
    )
    SELECT 
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
        payment_status,
        sourcefile,
        createddate,
        NULL :: TIMESTAMP AS updateddate,
        orderstarttime,
        reviewordertime,
        checkouttime,
        paystarttime,
        sessionendtime,
        EXTRACT(EPOCH FROM (checkouttime - orderstarttime)) AS precheckouttime,
        EXTRACT(EPOCH FROM (sessionendtime - checkouttime)) AS postcheckouttime,
        EXTRACT(EPOCH FROM (reviewordertime - orderstarttime)) AS menupagetime,
        EXTRACT(EPOCH FROM (checkouttime - reviewordertime)) AS reviewpagetime,
        EXTRACT(EPOCH FROM (sessionendtime - paystarttime)) AS paymentpagetime,
        EXTRACT(EPOCH FROM (sessionendtime - orderstarttime)) AS totalordertime,
        businessdate,
        frequentcustomerid,
        NULL :: BIGINT AS abtestid,
        channel,
        guestcount,
        charityamount,
        syscosmosts,
        1 :: INTEGER AS sourceid,
        orderservicecharge,
        customername
    FROM orders_enriched_with_ordertiming_fields;

END IF;

DROP TABLE IF EXISTS temp_transaction_header;

END;
$$;


ALTER PROCEDURE fact.usp_silver_transaction_header_to_fact() OWNER TO citus;

--
-- TOC entry 904 (class 1255 OID 11504807)
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


UPDATE fact.watermarktable
   SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.itemmodifier)
WHERE watermarktablename = 'fact.itemmodifier'
  AND source = 'nge';


END;
$$;


ALTER PROCEDURE fact.usp_update_datetime_fields() OWNER TO citus;

--
-- TOC entry 1084 (class 1255 OID 39161131)
-- Name: usp_update_occasion_survey_datetime_fields(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_update_occasion_survey_datetime_fields()
    LANGUAGE plpgsql
    AS $$

BEGIN

UPDATE fact.occasionsurveydetail
SET organizationid = ol.organizationid
FROM (select * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
WHERE occasionsurveydetail.locationid = ol.locationid 
  and occasionsurveydetail.organizationid is null;

UPDATE fact.itemssurvey
SET organizationid = ol.organizationid
FROM (select * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
WHERE itemssurvey.locationid = ol.locationid 
  and itemssurvey.organizationid is null;

UPDATE fact.occasionsurveydetail
SET surveylocaltimestamp = surveycompletedtimestamp::TIMESTAMPTZ AT TIME ZONE l.timezone
FROM (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end as timezone FROM dim.location) as l
WHERE occasionsurveydetail.locationid = l.locationid
  and occasionsurveydetail.surveylocaltimestamp is null;

UPDATE fact.occasionsurveydetail
SET surveylocaltimestamp = surveycompletedtimestamp::TIMESTAMPTZ AT TIME ZONE 'America/New_York'
WHERE surveylocaltimestamp is null;

UPDATE fact.itemssurvey
SET surveylocaltimestamp = surveycompletedtimestamp::TIMESTAMPTZ AT TIME ZONE l.timezone
FROM (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end as timezone FROM dim.location) as l
WHERE itemssurvey.locationid = l.locationid
  and itemssurvey.surveylocaltimestamp is null;

UPDATE fact.itemssurvey
SET surveylocaltimestamp = surveycompletedtimestamp::TIMESTAMPTZ AT TIME ZONE 'America/New_York'
WHERE surveylocaltimestamp is null;

UPDATE fact.occasionsurveydetail
SET dateid = cast(to_char(surveylocaltimestamp, 'YYYYMMDDHH24') as INTEGER)
WHERE dateid is null;

UPDATE fact.itemssurvey
SET dateid = cast(to_char(surveylocaltimestamp, 'YYYYMMDDHH24') as INTEGER)
WHERE dateid is null;

DELETE FROM fact.occasionsurveydetail as osd
WHERE NOT EXISTS (SELECT 1 FROM dim.occasionsurvey as os 
                WHERE os.organizationid = osd.organizationid
                  AND os.surveyid = osd.surveyid);

DELETE FROM fact.itemssurvey as its 
WHERE NOT EXISTS (SELECT 1 FROM dim.occasionsurvey as os 
                WHERE os.organizationid = its.organizationid
                  AND os.surveyid = its.surveyid);

UPDATE fact.watermarktable
SET ts = tr.maxts
FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.occasionsurveydetail' as tablename FROM fact.occasionsurveydetail WHERE sourceid = 1) as tr 
WHERE watermarktable.watermarktablename = tr.tablename
  AND watermarktable.source = 'nge';

UPDATE fact.watermarktable
SET ts = tr.maxts
FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.occasionsurveydetail' as tablename FROM fact.occasionsurveydetail WHERE sourceid = 2) as tr 
WHERE watermarktable.watermarktablename = tr.tablename
  AND watermarktable.source = 'gem';

UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(nge_syscosmosts), 1720000300) - 10 FROM fact.itemssurvey)
WHERE watermarktablename = 'fact.itemssurvey'
  AND source = 'nge';


END;
$$;


ALTER PROCEDURE fact.usp_update_occasion_survey_datetime_fields() OWNER TO citus;

--
-- TOC entry 1203 (class 1255 OID 41463749)
-- Name: usp_refresh_item_modifiergroup_modifier_mapping(text); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(IN p_organizationid text)
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Delete only rows for this organization on every run
    -- --------------------------------------------------------
    WITH org_loc_lookup AS (
        SELECT organizationid, organizationname, locationid, locationname
        FROM dim.organizationlocation
        WHERE CASE WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = p_organizationid
          AND organizationtype = 0
    )
    DELETE FROM ml.item_modifiergroup_modifier_mapping
    WHERE locationid IN (SELECT locationid FROM org_loc_lookup);

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH org_loc_ctlg AS (
        SELECT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname,
               c.catalogid, c.catalogname
        FROM (
            SELECT * FROM dim.organizationlocation
            WHERE CASE WHEN p_organizationid NOT LIKE 'loc-%' THEN organizationid ELSE locationid END = p_organizationid
              AND organizationtype = 0 
        ) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        SELECT
            m.*,
            olc.organizationid,
            olc.organizationname,
            olc.locationid,
            olc.locationname,
            --olc.catalogid,
            olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
    )
    INSERT INTO ml.item_modifiergroup_modifier_mapping
    SELECT
        m.organizationid,
        m.organizationname,
        m.locationid,
        m.locationname,
        m.catalogid,
        m.catalogname,
        imgm.menuitemid,
        mi.menuitemname,
        mi.item_class_type,
        imgm.modifiergroupid,
        mg.modifiergroupname,
        imgm.modifierid,
        m.modifiername,
        m.classification            AS modifier_class_type,
        imgm.is_default             AS is_modifier_default,
        mg.min_selection            AS min_quantity,
        mg.max_selection            AS max_quantity,
        m.allow_quantity_increment,
        m.increment_step,
        m.modifier_default_quantity,
        m.is_invisible              AS is_modifier_invisible,
        m.calories,
        m.price,
        m.is_modifier_active,
        m.is_modifier_deleted,
        m.modifier_created_on,
        m.modifier_modified_on,
        NOW()::TIMESTAMP            AS sysinserttime
    FROM dim.item_modifier_group_modifier_mapping AS imgm
    INNER JOIN org_loc_ctlg_modifiers AS m
        ON  imgm.catalogid  = m.catalogid
        AND imgm.modifierid = m.modifierid
    INNER JOIN dim.menuitem AS mi
        ON imgm.catalogid = mi.catalogid
        AND imgm.menuitemid = mi.menuitemid
    INNER JOIN dim.modifier_group AS mg
        ON  imgm.catalogid       = mg.catalogid
        AND imgm.modifiergroupid = mg.modifiergroupid;

END;
$$;


ALTER PROCEDURE ml.usp_refresh_item_modifiergroup_modifier_mapping(IN p_organizationid text) OWNER TO citus;

--
-- TOC entry 559 (class 1255 OID 39161178)
-- Name: usp_refresh_menu_entities(); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_menu_entities()
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Truncate on every run
    -- --------------------------------------------------------
    TRUNCATE TABLE ml.menu_entities;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH category_hierarchy AS (
        SELECT
            mi.*,
            ol.organizationid,
            ol.organizationname,
            ctgh.locationid,
            ol.locationname,
            ctgh.categoryid,
            ctgh.categoryname
        FROM dim.menuitem AS mi
        LEFT JOIN dim.category_hierarchy AS ctgh
            ON mi.menuitemid = ctgh.menuitemid
        INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
            ON ctgh.locationid = ol.locationid
    )
    INSERT INTO ml.menu_entities
    SELECT DISTINCT
        mi.organizationid,
        mi.organizationname,
        mi.locationid,
        mi.locationname,
        mi.categoryid,
        mi.categoryname,
        mi.menuitemid,
        mi.menuitemname,
        mi.catalogid,
        mi.itemunitprice,
        mi.price_changed_on,
        mi.item_class_type,
        mi.entitytype,
        mi.calories,
        mi.protein,
        mi.sugar,
        mi.fat,
        mi.is_alcoholic,
        mi.is_vegetarian_item,
        mi.is_vegan_item,
        mi.has_allergen,
        mi.is_active,
        mi.is_deleted,
        mi.gms_created_on,
        mi.gms_modified_on,
        NOW()::TIMESTAMP     AS sysinserttime
    FROM category_hierarchy AS mi;

END;
$$;


ALTER PROCEDURE ml.usp_refresh_menu_entities() OWNER TO citus;

--
-- TOC entry 502 (class 1255 OID 43984771)
-- Name: usp_refresh_modifier_impressions(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_modifier_impressions(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_businessdate DATE;  -- Holds the current max date in the target table;
                              -- used to anchor both the delete and the source filter
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.modifier_impressions;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.modifier_impressions;

        DELETE FROM ml.modifier_impressions
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH org_loc_ctlg AS (
        -- Resolve each org+location to its corresponding catalog.
        -- Type=0 filters to standard locations only.
        SELECT ol.organizationid, ol.organizationname, ol.locationid, ol.locationname,
               c.catalogid, c.catalogname
        FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        -- Enrich each modifier with its catalog and location context
        -- so it can be joined to impression events by locationid + modifierid.
        SELECT
            m.*,
            olc.organizationid,
            olc.organizationname,
            olc.locationid,
            olc.locationname,
            --olc.catalogid,
            olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
    )
    INSERT INTO ml.modifier_impressions
    SELECT
        olcm.organizationid,
        olcm.organizationname,
        olcm.locationname,
        olcm.locationid,
        olcm.catalogid,
        olcm.catalogname,
        m.businessdate,
        m.orderdatelocal,
        EXTRACT(YEAR FROM m.businessdate)::INTEGER  AS yyyy,
        EXTRACT(WEEK FROM m.businessdate)::INTEGER  AS ww,
        m.transactionheaderid,
        m.ordersessionid,
        m.orderid,
        m.menuitemid,
        mi.menuitemname,
        mi.item_class_type,
        m.modifierid,
        olcm.modifiername,
        olcm.classification                         AS modifier_class_type,
        m.parent_modifier_id,
        m.nesting_depth,
        olcm.price                                  AS modifierprice,
        m.selection_type,
        m.position,
        m.score,
        m.strategy,
        m.context,
        m.selected,
        m.pre_deselected,
        m.confirmed_removed,
        m.pre_selected,
        m.frequentcustomerid,
        NOW()::TIMESTAMP                            AS sysinserttime  -- audit timestamp for when the row was loaded
    FROM fact.modifier_impressions AS m
    INNER JOIN org_loc_ctlg_modifiers AS olcm
        ON  m.locationid = olcm.locationid
        AND m.modifierid = olcm.modifierid
    INNER JOIN dim.menuitem AS mi
        ON mi.menuitemid = m.menuitemid
    WHERE LOWER(m.transactionheaderid) LIKE 'ordevt-%'  -- exclude non-order events (e.g. kiosk idle sessions)
      AND (
            p_refresh_mode = 0                          -- full load: no date restriction
            OR m.businessdate >= v_max_businessdate     -- incremental: from max date onward
      );

END;
$$;


ALTER PROCEDURE ml.usp_refresh_modifier_impressions(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 896 (class 1255 OID 41463928)
-- Name: usp_refresh_modifier_interactions(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_modifier_interactions(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_businessdate DATE;  -- Holds the current max date in the target table;
                              -- used to anchor both the delete and the source filter
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.modifier_interactions;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.modifier_interactions;

        DELETE FROM ml.modifier_interactions
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH trxn_items AS (
        -- Pull the relevant transaction item fields from ml.transactions.
        -- This is the date-filtered entry point for the entire query.
        SELECT
            tr.organizationid,
            tr.organizationname,
            tr.locationid,
            tr.locationname,
            tr.businessdate,
            tr.orderdatelocal,
            tr.transactionheaderid,
            tr.ordersessionid,
            tr.orderid,
            tr.orderitemid,
            tr.menuitemid,
            tr.itemquantity,
            tr.itemunitprice,
            tr.frequentcustomerid
        FROM ml.transactions AS tr
        WHERE (
                p_refresh_mode = 0                       -- full load: no date restriction
                OR tr.businessdate >= v_max_businessdate -- incremental: from max date onward
        )
    ),
    org_loc_ctlg AS (
        -- Resolve each org+location to its corresponding catalog.
        -- Type=0 filters to standard locations only.
        SELECT ol.organizationid, ol.locationid, c.catalogid, c.catalogname
        FROM (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        INNER JOIN dim.catalog AS c
            ON  ol.organizationid = c.organizationid
            AND ol.locationid     = c.gem_location_id
    ),
    org_loc_ctlg_modifiers AS (
        -- Enrich each modifier with its catalog and location context
        -- so it can be joined to transaction items by locationid + modifierid.
        SELECT
            m.*,
            olc.organizationid,
            olc.locationid,
            olc.catalogname
        FROM dim.modifier AS m
        INNER JOIN org_loc_ctlg AS olc
            ON m.catalogid = olc.catalogid
    )
    INSERT INTO ml.modifier_interactions
    SELECT
        ti.organizationid,
        ti.organizationname,
        ti.locationname,
        ti.locationid,
        olcm.catalogid,
        olcm.catalogname,
        ti.businessdate,
        ti.orderdatelocal,
        EXTRACT(YEAR FROM ti.businessdate)::INTEGER             AS yyyy,
        EXTRACT(WEEK FROM ti.businessdate)::INTEGER             AS ww,
        mt.transactionheaderid,
        ti.ordersessionid,
        ti.orderid,
        mt.itemid                                               AS orderitemid,
        ti.menuitemid,
        mi.menuitemname,
        ti.itemquantity,
        ti.itemunitprice,
        mi.item_class_type,
        mt.modifiergroupid,
        mg.modifiergroupname,
        mt.modifierid,
        mt.modifiername,
        NULL::TEXT                                              AS parent_modifier_id,   -- reserved for future nested modifier support
        NULL::INTEGER                                           AS nesting_depth,        -- reserved for future nested modifier support
        mt.modifierquantity,
        mt.modifierprice,
        mt.freequantity,
        mgm.is_default                                          AS is_modifier_default,
        mg.min_selection                                        AS min_quantity,
        mg.max_selection                                        AS max_quantity,
        -- Classify whether the modifier was optional, required, or a default selection
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 THEN 'optional'
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 THEN 'required'
            WHEN mgm.is_default = TRUE                                                       THEN 'default'
        END                                                     AS selection_type,
        -- Classify the action the customer took on this modifier
        CASE
            WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 AND mt.modifierquantity >= 1 THEN 'added'    -- customer explicitly added an optional modifier
            WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'selected'  -- customer selected a required modifier
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'kept'      -- customer left the default modifier in place
            WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity = 0  THEN 'removed'   -- customer actively removed a default modifier
        END                                                     AS action,
        NULL::TEXT                                              AS session_recorded_at,  -- reserved for future session tracking
        ti.frequentcustomerid,
        olcm.modifier_default_quantity,
        olcm.classification                                     AS modifier_class_type,
        NOW()::TIMESTAMP                                        AS sysinserttime         -- audit timestamp for when the row was loaded
    FROM fact.itemmodifier AS mt
    INNER JOIN trxn_items AS ti
        ON  mt.transactionheaderid = ti.transactionheaderid
        AND mt.itemid              = ti.orderitemid
    INNER JOIN org_loc_ctlg_modifiers AS olcm
        ON  ti.locationid = olcm.locationid
        AND mt.modifierid = olcm.modifierid
    INNER JOIN dim.menuitem AS mi
        ON mi.menuitemid = ti.menuitemid
    LEFT JOIN dim.modifier_group_mapping AS mgm
        ON  mgm.modifiergroupid = mt.modifiergroupid
        AND mgm.modifierid      = mt.modifierid
    LEFT JOIN dim.modifier_group AS mg
        ON mg.modifiergroupid = mt.modifiergroupid;

END;
$$;


ALTER PROCEDURE ml.usp_refresh_modifier_interactions(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 1032 (class 1255 OID 41463761)
-- Name: usp_refresh_transactions(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_transactions(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_businessdate DATE;  -- Holds the current max date in the target table;
                              -- used to anchor both the delete and the source filter
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.transactions;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.transactions;

        DELETE FROM ml.transactions
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM fact.transactionheader AS th
        WHERE LOWER(th.orderstatus) = 'order-placed'   -- exclude cancelled, pending, etc.
          AND (
                p_refresh_mode = 0                     -- full load: no date restriction
                OR th.businessdate >= v_max_businessdate  -- incremental: from max date onward
          )
    )
    INSERT INTO ml.transactions
    SELECT DISTINCT
        th.frequentcustomerid,
        ol.organizationid,
        ol.organizationname,
        th.locationid,
        ol.locationname,
        th.kioskid,
        th.transactionheaderid,
        th.ordersessionid,
        th.orderid,
        ti.itemid                                                    AS orderitemid,
        ti.dimmenuitemid                                             AS menuitemid,
        ti.itemname,
        COALESCE(ti.upselllevel, '')                                 AS upselllevel,  -- default to empty string if no upsell
        mi.item_class_type,
        ti.itemquantity,
        ti.categoryid,
        ctg.categoryname,
        ti.itemunitprice,
        th.paymentstatus,
        th.numberofitems,
        th.numberofpayments,
        th.ordertotal,
        th.ordersubtotal,
        th.ordertip,
        th.ordertax,
        ot.ordertypelabel,
        th.orderdatelocal,
        th.businessdate,
        wh.humidity                                                  AS weatherhumidity,     -- weather at time of order
        wh.condition                                                 AS weathercondition,
        wh.temperature_c                                             AS temperatureincelcius,
        EXTRACT(YEAR  FROM th.businessdate)::INTEGER                 AS yyyy,
        EXTRACT(MONTH FROM th.businessdate)::INTEGER                 AS mm,
        EXTRACT(DAY   FROM th.businessdate)::INTEGER                 AS dd,
        EXTRACT(HOUR  FROM th.orderdatelocal)::INTEGER               AS hh,
        EXTRACT(WEEK  FROM th.businessdate)::INTEGER                 AS ww,
        NOW()::TIMESTAMP                                             AS sysinserttime  -- audit timestamp for when the row was loaded
    FROM cte AS th
    INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON th.locationid = ol.locationid                            -- type=0 filters to standard locations only
    INNER JOIN fact.transactionitem AS ti
        ON th.transactionheaderid = ti.transactionheaderid          -- expand header to one row per item
    LEFT JOIN ml.weather AS wh
        ON  th.locationid          = wh.locationid
        AND th.businessdate        = wh.weatherdate
        AND EXTRACT(HOUR FROM th.orderdatelocal)::INTEGER = wh.hh  -- match weather to the exact hour of the order
    LEFT JOIN dim.itemcategory AS ctg
        ON ti.categoryid = ctg.id
    LEFT JOIN dim.menuitem AS mi
        ON ti.menuitemid = mi.id
    LEFT JOIN dim.ordertype AS ot
        ON th.ordertype = ot.id;

END;
$$;


ALTER PROCEDURE ml.usp_refresh_transactions(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 930 (class 1255 OID 41463856)
-- Name: usp_refresh_upsell_analysis(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_upsell_analysis(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_businessdate DATE;  -- Holds the current max date in the target table;
                              -- used to anchor both the delete and the source filter
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.upsell_analysis;
    ELSE
        -- Incremental: capture the latest date already loaded,
        -- delete it (in case it was a partial load), then reload
        -- from that date forward so no gaps or duplicates occur
        SELECT MAX(businessdate) INTO v_max_businessdate FROM ml.upsell_analysis;

        DELETE FROM ml.upsell_analysis
        WHERE businessdate >= v_max_businessdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- Filter the source to the same date window used in Step 1.
    -- On a full load (mode=0), the date filter is bypassed entirely.
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM fact.transactionheader
        WHERE (
                p_refresh_mode = 0                        -- full load: no date restriction
                OR businessdate >= v_max_businessdate     -- incremental: from max date onward
        )
    )
    INSERT INTO ml.upsell_analysis
    SELECT DISTINCT
        ol.organizationid,
        ol.organizationname,
        oa.locationid,
        ol.locationname,
        th.frequentcustomerid,
        oa.transactionheaderid,
        oa.recommendationid,
        oa.offereditem,
        oa.selecteditem,
        mi.item_class_type,
        oa.upselltype,
        oa.quantity,
        th.businessdate,
        th.orderdatelocal,
        EXTRACT(YEAR  FROM th.businessdate)::INTEGER   AS yyyy,
        EXTRACT(MONTH FROM th.businessdate)::INTEGER   AS mm,
        EXTRACT(DAY   FROM th.businessdate)::INTEGER   AS dd,
        EXTRACT(HOUR  FROM th.orderdatelocal)::INTEGER AS hh,
        EXTRACT(WEEK  FROM th.businessdate)::INTEGER   AS ww,
        NOW()::TIMESTAMP                               AS sysinserttime  -- audit timestamp for when the row was loaded
    FROM fact.vw_offer_analysis AS oa
    INNER JOIN cte AS th
        ON  oa.locationid          = th.locationid
        AND oa.transactionheaderid = th.transactionheaderid
    LEFT JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON oa.locationid = ol.locationid                -- type=0 filters to standard locations only
    LEFT JOIN dim.menuitem AS mi
        ON (
            CASE
                WHEN oa.offereditem NOT LIKE 'cat-%' THEN oa.offereditem  -- item-level offer: use offereditem directly
                ELSE oa.selecteditem                                       -- category-level offer: fall back to what was actually selected
            END
        ) = mi.menuitemid;

END;
$$;


ALTER PROCEDURE ml.usp_refresh_upsell_analysis(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 615 (class 1255 OID 41463706)
-- Name: usp_refresh_weather(integer); Type: PROCEDURE; Schema: ml; Owner: citus
--

CREATE PROCEDURE ml.usp_refresh_weather(IN p_refresh_mode integer DEFAULT 1)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_weatherdate DATE;
BEGIN

    -- --------------------------------------------------------
    -- Step 1: Purge strategy based on refresh mode
    -- --------------------------------------------------------
    IF p_refresh_mode = 0 THEN
        -- Full load: wipe everything and reload all history
        TRUNCATE TABLE ml.weather;
    ELSE
        -- Incremental: capture the current max date, delete it,
        -- then reload from that date forward (picks up any new data too)
        SELECT MAX(weatherdate) INTO v_max_weatherdate FROM ml.weather;

        DELETE FROM ml.weather
        WHERE weatherdate >= v_max_weatherdate;
    END IF;

    -- --------------------------------------------------------
    -- Step 2: Insert
    -- --------------------------------------------------------
    WITH cte AS (
        SELECT *
        FROM dim.vw_weatherhourlydata
        WHERE (
            p_refresh_mode = 0
            OR weatherdate >= v_max_weatherdate
        )
    )
    INSERT INTO ml.weather
    SELECT
        ol.organizationid,
        ol.organizationname,
        cte.locationid,
        ol.locationname,
        cte.weatherdate,
        EXTRACT(YEAR  FROM cte.weatherdate)::INTEGER AS yyyy,
        EXTRACT(MONTH FROM cte.weatherdate)::INTEGER AS mm,
        EXTRACT(DAY   FROM cte.weatherdate)::INTEGER AS dd,
        EXTRACT(WEEK  FROM cte.weatherdate)::INTEGER AS ww,
        cte.hh,
        cte.humidity,
        cte.condition,
        cte.temperature_c,
        cte.is_hot,
        cte.is_calm,
        cte.is_cold,
        cte.is_cool,
        cte.is_mild,
        cte.is_warm,
        cte.rain_mm,
        cte.is_sunny,
        cte.is_windy,
        cte.is_cloudy,
        cte.is_daytime,
        cte.is_raining,
        cte.is_snowing,
        cte.is_very_hot,
        cte.is_freezing,
        cte.is_overcast,
        cte.snowfall_mm,
        cte.temp_bucket,
        cte.wind_bucket,
        cte.feels_colder,
        cte.feels_hotter,
        cte.food_weather,
        cte.is_heavy_rain,
        cte.is_light_rain,
        cte.is_nighttime,
        cte.is_very_windy,
        cte.pressure_hpa,
        cte.weather_code,
        cte.wind_gust_kmh,
        cte.comfort_score,
        cte.drink_weather,
        cte.wind_speed_kmh,
        cte.comfort_bucket,
        cte.humidity_bucket,
        cte.condition_bucket,
        cte.is_precipitating,
        cte.precipitation_mm,
        cte.visibility_meters,
        cte.cloud_cover_percent,
        cte.is_unseasonably_hot,
        cte.is_unseasonably_cold,
        cte.outdoor_dining_score,
        cte.wind_direction_degrees,
        cte.precipitation_probability,
        cte.apparent_temperature_celsius,
        NOW()::TIMESTAMP                             AS sysinserttime
    FROM cte
    LEFT JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
        ON cte.locationid = ol.locationid;

END;
$$;


ALTER PROCEDURE ml.usp_refresh_weather(IN p_refresh_mode integer) OWNER TO citus;

--
-- TOC entry 776 (class 1255 OID 19724)
-- Name: create_extension(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.create_extension(extname text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$ BEGIN
DISCARD TEMP;
IF extname NOT IN (
'address_standardizer',
'amcheck',
'autoinc',
'azure_storage',
'bloom',
'dict_int',
'dict_xsyn',
'insert_username',
'intagg',
'isn',
'lo',
'moddatetime',
'orafce',
'pageinspect',
'pgaudit',
'pgcrypto',
'pgrowlocks',
'pg_trgm',
'pg_visibility',
'postgis',
'postgis_raster',
'postgis_sfcgal',
'postgis_topology',
'postgres_fdw',
'refint',
'seg',
'semver',
'tcn',
'tsm_system_rows',
'tsm_system_time',
'uuid-ossp',
'vector') THEN raise 'not allowed to create this extension';
END IF;
IF extname IN ('azure_storage', 'postgis_topology') THEN
    EXECUTE pg_catalog.format('CREATE EXTENSION %I', extname);
ELSE
    EXECUTE pg_catalog.format('CREATE EXTENSION %I WITH SCHEMA public', extname);
END IF;
IF extname IN ('postgres_fdw') THEN EXECUTE pg_catalog.format('GRANT USAGE ON FOREIGN DATA WRAPPER %I TO citus WITH GRANT OPTION', extname);
END IF;
IF extname IN ('azure_storage') THEN
    GRANT azure_storage_admin TO citus WITH ADMIN OPTION;
    PERFORM azure_storage.citus_cluster_initialize();
END IF;
IF extname IN ('orafce') THEN
    REVOKE ALL ON SCHEMA utl_file FROM PUBLIC;
    REVOKE ALL ON SCHEMA utl_file FROM citus;
END IF;
END; $$;


ALTER FUNCTION public.create_extension(extname text) OWNER TO postgres;

--
-- TOC entry 867 (class 1255 OID 19725)
-- Name: drop_extension(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.drop_extension(extname text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $$ BEGIN
DISCARD TEMP;
IF extname NOT IN (
'address_standardizer',
'amcheck',
'autoinc',
'azure_storage',
'bloom',
'dict_int',
'dict_xsyn',
'insert_username',
'intagg',
'isn',
'lo',
'moddatetime',
'mysql_fdw',
'orafce',
'pageinspect',
'pgaudit',
'pgcrypto',
'pgrowlocks',
'pg_trgm',
'pg_visibility',
'postgis',
'postgis_raster',
'postgis_sfcgal',
'postgis_tiger_geocoder',
'postgis_topology',
'postgres_fdw',
'refint',
'seg',
'semver',
'tcn',
'tsm_system_rows',
'tsm_system_time',
'uuid-ossp',
'vector') THEN raise 'not allowed to drop this extension';
END IF;
EXECUTE pg_catalog.format('DROP EXTENSION %I;', extname);
END; $$;


ALTER FUNCTION public.drop_extension(extname text) OWNER TO postgres;

--
-- TOC entry 1269 (class 1255 OID 19516)
-- Name: pg_replication_origin_create(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_create(text) RETURNS oid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_create($1) $_$;


ALTER FUNCTION public.pg_replication_origin_create(text) OWNER TO postgres;

--
-- TOC entry 1221 (class 1255 OID 19519)
-- Name: pg_replication_origin_drop(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_drop(text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_drop($1) $_$;


ALTER FUNCTION public.pg_replication_origin_drop(text) OWNER TO postgres;

--
-- TOC entry 672 (class 1255 OID 19518)
-- Name: pg_replication_origin_progress(text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_progress(text, boolean) RETURNS pg_lsn
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_progress($1, $2) $_$;


ALTER FUNCTION public.pg_replication_origin_progress(text, boolean) OWNER TO postgres;

--
-- TOC entry 1449 (class 1255 OID 19517)
-- Name: pg_replication_origin_session_progress(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_session_progress(boolean) RETURNS pg_lsn
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_session_progress($1) $_$;


ALTER FUNCTION public.pg_replication_origin_session_progress(boolean) OWNER TO postgres;

--
-- TOC entry 532 (class 1255 OID 19521)
-- Name: pg_replication_origin_session_setup(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_session_setup(text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_session_setup($1) $_$;


ALTER FUNCTION public.pg_replication_origin_session_setup(text) OWNER TO postgres;

--
-- TOC entry 1254 (class 1255 OID 19520)
-- Name: pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_xact_setup($1, $2) $_$;


ALTER FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) OWNER TO postgres;

--
-- TOC entry 2584 (class 1255 OID 19515)
-- Name: sum(public.hll); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.sum(public.hll) (
    SFUNC = public.hll_union_trans,
    STYPE = internal,
    FINALFUNC = public.hll_pack
);


ALTER AGGREGATE public.sum(public.hll) OWNER TO postgres;

--
-- TOC entry 2583 (class 1255 OID 19514)
-- Name: sum(public.hll_hashval); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.sum(public.hll_hashval) (
    SFUNC = public.hll_add_trans0,
    STYPE = internal,
    FINALFUNC = public.hll_pack
);


ALTER AGGREGATE public.sum(public.hll_hashval) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 398 (class 1259 OID 3755598)
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
-- TOC entry 362 (class 1259 OID 19793)
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
-- TOC entry 372 (class 1259 OID 19886)
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
-- TOC entry 429 (class 1259 OID 27639223)
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
-- TOC entry 427 (class 1259 OID 27639207)
-- Name: category_hierarchy; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.category_hierarchy (
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
-- TOC entry 361 (class 1259 OID 19785)
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
-- TOC entry 407 (class 1259 OID 4991312)
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
-- TOC entry 428 (class 1259 OID 27639216)
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
-- TOC entry 363 (class 1259 OID 19803)
-- Name: element; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.element (
    elementid integer NOT NULL,
    sourceelementid text,
    elementname text
);


ALTER TABLE dim.element OWNER TO citus;

--
-- TOC entry 393 (class 1259 OID 2739011)
-- Name: feedbackrating; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.feedbackrating (
    rating text,
    ratingdesc text
);


ALTER TABLE dim.feedbackrating OWNER TO citus;

--
-- TOC entry 394 (class 1259 OID 2739017)
-- Name: feedbackstatus; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.feedbackstatus (
    surveytransstatus text,
    statusdesc text
);


ALTER TABLE dim.feedbackstatus OWNER TO citus;

--
-- TOC entry 397 (class 1259 OID 3755591)
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
-- TOC entry 452 (class 1259 OID 43985152)
-- Name: frequentcustomer_bkp; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.frequentcustomer_bkp (
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


ALTER TABLE dim.frequentcustomer_bkp OWNER TO citus;

--
-- TOC entry 420 (class 1259 OID 13713094)
-- Name: grubbrr_source_lookup; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.grubbrr_source_lookup (
    id integer NOT NULL,
    source text,
    description text
);


ALTER TABLE dim.grubbrr_source_lookup OWNER TO citus;

--
-- TOC entry 437 (class 1259 OID 39161079)
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
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.item_modifier_group_modifier_mapping OWNER TO citus;

--
-- TOC entry 364 (class 1259 OID 19811)
-- Name: itemcategory; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.itemcategory (
    id bigint NOT NULL,
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text NOT NULL,
    isactive boolean DEFAULT true NOT NULL,
    catalogid text
);


ALTER TABLE dim.itemcategory OWNER TO citus;

--
-- TOC entry 413 (class 1259 OID 7230903)
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
-- TOC entry 415 (class 1259 OID 11432713)
-- Name: itemcategorymapping; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.itemcategorymapping (
    categoryid character varying(50) NOT NULL,
    menuitemid character varying(50),
    subcategoryid character varying(50),
    isactive boolean,
    isdeleted boolean,
    modifiedon timestamp without time zone
);


ALTER TABLE dim.itemcategorymapping OWNER TO citus;

--
-- TOC entry 365 (class 1259 OID 19821)
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
    devicedeletedon timestamp without time zone,
    CONSTRAINT devicetype_not_empty CHECK (((devicetype)::text <> ''::text))
);


ALTER TABLE dim.kiosk OWNER TO citus;

--
-- TOC entry 414 (class 1259 OID 10775482)
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
-- TOC entry 367 (class 1259 OID 19837)
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
-- TOC entry 366 (class 1259 OID 19831)
-- Name: locationgroup; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.locationgroup (
    companyid text NOT NULL,
    locationgroupid text NOT NULL,
    locationgroupname text,
    address1 text,
    address2 text,
    city text,
    state text,
    zipcode text
);


ALTER TABLE dim.locationgroup OWNER TO citus;

--
-- TOC entry 406 (class 1259 OID 4966206)
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
    sysupdatetime timestamp without time zone,
    catalogid text
);


ALTER TABLE dim.menuitem OWNER TO citus;

--
-- TOC entry 405 (class 1259 OID 4966194)
-- Name: menuitem_bkp; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.menuitem_bkp (
    id bigint NOT NULL,
    organizationid text,
    locationid text NOT NULL,
    menuitemid text NOT NULL,
    menuitemname text NOT NULL,
    guest integer DEFAULT 1 NOT NULL,
    effective_date date,
    issuedsurveycount integer,
    receivedsurveycount integer,
    totalratingvalue integer
);


ALTER TABLE dim.menuitem_bkp OWNER TO citus;

--
-- TOC entry 399 (class 1259 OID 3771489)
-- Name: menuitem_test; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.menuitem_test (
    id bigint NOT NULL,
    locationid text NOT NULL,
    menuitemid text NOT NULL,
    menuitemname text NOT NULL,
    guest integer DEFAULT 1 NOT NULL,
    effective_date date
);


ALTER TABLE dim.menuitem_test OWNER TO citus;

--
-- TOC entry 430 (class 1259 OID 27639231)
-- Name: modifier; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.modifier (
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
    sysupdatetime timestamp without time zone,
    price_changed_on timestamp without time zone
);


ALTER TABLE dim.modifier OWNER TO citus;

--
-- TOC entry 436 (class 1259 OID 39161070)
-- Name: modifier_group; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.modifier_group (
    modifiergroupid character varying(50) NOT NULL,
    modifiergroupname character varying(510) NOT NULL,
    catalogid character varying(50) NOT NULL,
    max_selection integer,
    min_selection integer,
    free_count integer,
    pos_linked_entity_id character varying(50),
    is_active boolean NOT NULL,
    is_deleted boolean NOT NULL,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    negative_modifier_behavior integer,
    created_by character varying(255),
    modified_by character varying(255),
    max_aggregate_count integer,
    min_aggregate_count integer,
    increment_step integer,
    slider_mode boolean DEFAULT false NOT NULL,
    slider_mode_modifier boolean DEFAULT false NOT NULL,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.modifier_group OWNER TO citus;

--
-- TOC entry 431 (class 1259 OID 27639238)
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
-- TOC entry 388 (class 1259 OID 2081705)
-- Name: occasionsurvey; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.occasionsurvey (
    surveykey bigint NOT NULL,
    organizationid text NOT NULL,
    surveyid text NOT NULL,
    surveyname text,
    surveytype text,
    question_type integer,
    selection_type integer,
    survey_status integer,
    is_deleted boolean,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.occasionsurvey OWNER TO citus;

--
-- TOC entry 387 (class 1259 OID 2081704)
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
-- TOC entry 368 (class 1259 OID 19854)
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
-- TOC entry 416 (class 1259 OID 11432737)
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
-- TOC entry 402 (class 1259 OID 4966167)
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
    organizationtype smallint NOT NULL,
    status smallint NOT NULL,
    phonenumber character varying(20),
    email character varying(255),
    isdeleted boolean DEFAULT false,
    createdon timestamp without time zone NOT NULL,
    createdby character varying(255),
    modifiedon timestamp without time zone,
    modifiedby character varying(255),
    active boolean NOT NULL,
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
-- TOC entry 369 (class 1259 OID 19862)
-- Name: organizationlocation; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.organizationlocation (
    organizationid character varying(40) NOT NULL,
    organizationname character varying(255) NOT NULL,
    locationid character varying(40) NOT NULL,
    locationname character varying(255) NOT NULL,
    organizationtype smallint NOT NULL,
    roundupforcharity boolean
);


ALTER TABLE dim.organizationlocation OWNER TO citus;

--
-- TOC entry 370 (class 1259 OID 19870)
-- Name: organizationparent; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.organizationparent (
    "id " text NOT NULL,
    parentorganizationid text NOT NULL,
    organizationid text NOT NULL,
    organizationparenttype text NOT NULL,
    createdon date NOT NULL,
    createdby text NOT NULL,
    modifiedon date NOT NULL,
    modifiedby text NOT NULL,
    active text NOT NULL
);


ALTER TABLE dim.organizationparent OWNER TO citus;

--
-- TOC entry 408 (class 1259 OID 4991327)
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
-- TOC entry 412 (class 1259 OID 7230885)
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
-- TOC entry 386 (class 1259 OID 1318162)
-- Name: userlocation; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.userlocation (
    userid character varying(40) NOT NULL,
    locationid character varying(40) NOT NULL
);


ALTER TABLE dim.userlocation OWNER TO citus;

--
-- TOC entry 371 (class 1259 OID 19880)
-- Name: view; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.view (
    viewid integer NOT NULL,
    viewname text
);


ALTER TABLE dim.view OWNER TO citus;

--
-- TOC entry 421 (class 1259 OID 13743398)
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
-- TOC entry 435 (class 1259 OID 37323269)
-- Name: vw_grubbrrinstallbase_all_devices; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.vw_grubbrrinstallbase_all_devices (
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


ALTER TABLE dim.vw_grubbrrinstallbase_all_devices OWNER TO citus;

--
-- TOC entry 410 (class 1259 OID 7199758)
-- Name: weather; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.weather (
    organizationid text,
    locationid text,
    city text,
    timezone text,
    locationinfo jsonb,
    historyapicalldate date,
    historyweatherinfo jsonb,
    currentapicalldate date,
    currentweatherinfo jsonb,
    futureapicalldate date,
    futureweatherinfo jsonb,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    weatherinfo jsonb,
    apicalldate date
);


ALTER TABLE dim.weather OWNER TO citus;

--
-- TOC entry 426 (class 1259 OID 18821122)
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
-- TOC entry 373 (class 1259 OID 19891)
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
-- TOC entry 409 (class 1259 OID 7199328)
-- Name: weather_bkp; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.weather_bkp (
    organizationid text,
    locationid text,
    city text,
    timezone text,
    apicalldate date,
    locationinfo jsonb,
    weatherinfo jsonb,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.weather_bkp OWNER TO citus;

--
-- TOC entry 451 (class 1259 OID 40940663)
-- Name: T_4442_1eca082546ae4881a2b72397e354c4fa; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact."T_4442_1eca082546ae4881a2b72397e354c4fa" (
    transactionheaderid text,
    kioskid text,
    locationid text,
    r860976862e0f4565b7f3f63857167ff9 integer,
    ordertype integer
);


ALTER TABLE fact."T_4442_1eca082546ae4881a2b72397e354c4fa" OWNER TO citus;

--
-- TOC entry 433 (class 1259 OID 31068121)
-- Name: T_5656_e6b4c2c790f549b8b4f741798c8912c6; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact."T_5656_e6b4c2c790f549b8b4f741798c8912c6" (
    application text,
    syscosmosts bigint,
    deviceid text,
    dateid integer,
    rcc77f20fb452418388bfefeb6dafe6cf integer,
    username text,
    actiontype text,
    eventdata text,
    locationid text,
    eventinstant text,
    userid text,
    companyid text,
    datacategory text,
    eventtoken text,
    severity text,
    moduleid text,
    sysinserttime timestamp without time zone,
    syscosmosticks bigint,
    summary text
);


ALTER TABLE fact."T_5656_e6b4c2c790f549b8b4f741798c8912c6" OWNER TO citus;

--
-- TOC entry 434 (class 1259 OID 31912721)
-- Name: T_5731_5b365fb5f4a74dfeae4a5924eb4daf5b; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact."T_5731_5b365fb5f4a74dfeae4a5924eb4daf5b" (
    watermarktablename text,
    ts bigint,
    r0b5510154efc4499badfbef5a7c63914 integer,
    ticks bigint,
    watermarkvalue timestamp without time zone
);


ALTER TABLE fact."T_5731_5b365fb5f4a74dfeae4a5924eb4daf5b" OWNER TO citus;

--
-- TOC entry 423 (class 1259 OID 18410580)
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
-- TOC entry 419 (class 1259 OID 11843375)
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
-- TOC entry 374 (class 1259 OID 19896)
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
-- TOC entry 385 (class 1259 OID 19997)
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
-- TOC entry 390 (class 1259 OID 2095696)
-- Name: devicetelemetry; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.devicetelemetry (
    deviceid text NOT NULL,
    locationid text NOT NULL,
    dateid integer NOT NULL,
    cpuvalue numeric(10,5),
    memoryvalue numeric(10,5),
    cputimestamp timestamp without time zone,
    memorytimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.devicetelemetry OWNER TO citus;

--
-- TOC entry 375 (class 1259 OID 19911)
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
    modifierprice numeric(12,3) NOT NULL,
    freequantity integer,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    locationid text,
    businessdate date,
    syscosmosts bigint
);


ALTER TABLE fact.itemmodifier OWNER TO citus;

--
-- TOC entry 400 (class 1259 OID 3813565)
-- Name: itemssurvey; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.itemssurvey (
    organizationid text,
    locationid text NOT NULL,
    dateid integer,
    surveyid text,
    surveytransid text NOT NULL,
    orderid text NOT NULL,
    itemid text NOT NULL,
    itemrating text,
    surveytransstatus text,
    surveyissuedtimestamp text,
    surveycompletedtimestamp text,
    surveylocaltimestamp timestamp without time zone,
    sysinserttime timestamp without time zone,
    nge_syscosmosts bigint,
    ordersessionid text,
    gem_event_category text,
    gem_event_type text,
    is_responded boolean,
    gem_syscosmosts bigint,
    gem_event_instant text,
    sysupdatetime timestamp without time zone,
    sourceid integer
);


ALTER TABLE fact.itemssurvey OWNER TO citus;

--
-- TOC entry 418 (class 1259 OID 11843350)
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
-- TOC entry 432 (class 1259 OID 27639245)
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
-- TOC entry 440 (class 1259 OID 39161098)
-- Name: modifier_impressions; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.modifier_impressions (
    locationid text NOT NULL,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    menuitemid text,
    modifierid text NOT NULL,
    parent_modifier_id text,
    selection_type text,
    nesting_depth integer,
    "position" integer,
    score numeric(5,3),
    strategy text,
    context text,
    selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    pre_selected boolean,
    businessdate date,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.modifier_impressions OWNER TO citus;

--
-- TOC entry 441 (class 1259 OID 39161103)
-- Name: modifier_interactions; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.modifier_interactions (
    locationid text NOT NULL,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    orderitemid text,
    menuitemid text NOT NULL,
    modifiergroupid text NOT NULL,
    modifierid text NOT NULL,
    modifiername text,
    parent_modifier_id text,
    nesting_depth integer,
    modifierquantity integer,
    modifierprice numeric(12,3),
    freequantity integer,
    selection_type text,
    action text,
    session_recorded_at text,
    businessdate date,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    sourceid integer
);


ALTER TABLE fact.modifier_interactions OWNER TO citus;

--
-- TOC entry 443 (class 1259 OID 39161115)
-- Name: modifier_recommendations; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.modifier_recommendations (
    locationid text NOT NULL,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    modifier_impressions jsonb,
    modifier_interactions jsonb,
    businessdate date,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.modifier_recommendations OWNER TO citus;

--
-- TOC entry 401 (class 1259 OID 3813570)
-- Name: occasionsurveydetail; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.occasionsurveydetail (
    organizationid text,
    locationid text NOT NULL,
    dateid integer,
    surveyid text,
    surveytransid text,
    orderid text NOT NULL,
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
-- TOC entry 376 (class 1259 OID 19918)
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
-- TOC entry 377 (class 1259 OID 19925)
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
-- TOC entry 378 (class 1259 OID 19931)
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
-- TOC entry 425 (class 1259 OID 18792979)
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
-- TOC entry 424 (class 1259 OID 18792978)
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
-- TOC entry 404 (class 1259 OID 4966187)
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
-- TOC entry 439 (class 1259 OID 39161091)
-- Name: sent_surveys; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.sent_surveys (
    organizationid text,
    locationid text NOT NULL,
    ordersessionid text NOT NULL,
    orderid text,
    gem_event_category text,
    gem_event_type text,
    survey_metadata jsonb,
    is_responded boolean,
    gem_event_instant text,
    gem_syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.sent_surveys OWNER TO citus;

--
-- TOC entry 379 (class 1259 OID 19936)
-- Name: timingsdatalake; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.timingsdatalake (
    containername text NOT NULL,
    timing_value timestamp without time zone
);


ALTER TABLE fact.timingsdatalake OWNER TO citus;

--
-- TOC entry 380 (class 1259 OID 19943)
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
-- TOC entry 395 (class 1259 OID 2763583)
-- Name: transactionheadertest; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.transactionheadertest (
    id bigint NOT NULL,
    transactionheaderid text NOT NULL,
    orderid text,
    locationid text,
    kioskid text,
    ordersessionid text,
    dateid integer,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    orderstatus text,
    ordertype integer,
    numberofitems smallint,
    numberofpayments smallint,
    ordersredeemedrewards numeric(7,3),
    ordersubtotal numeric(7,3),
    ordertotal numeric(7,3),
    ordertax numeric(7,3),
    ordertip numeric(7,3),
    orderdiscount numeric(7,3),
    orderbalance numeric(7,3),
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
    businessdate date
);


ALTER TABLE fact.transactionheadertest OWNER TO citus;

--
-- TOC entry 384 (class 1259 OID 19980)
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
    syscosmosts bigint,
    orderdatelocal timestamp without time zone,
    businessdate date,
    frequentcustomerid text
);


ALTER TABLE fact.transactionitem OWNER TO citus;

--
-- TOC entry 381 (class 1259 OID 19953)
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
-- TOC entry 411 (class 1259 OID 7230838)
-- Name: transactionrefunds; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.transactionrefunds (
    transactionheaderid character varying(50) NOT NULL,
    orderid character varying(50),
    locationid character varying(50) NOT NULL,
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
-- TOC entry 382 (class 1259 OID 19960)
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
-- TOC entry 422 (class 1259 OID 16817915)
-- Name: userbehaviour_reload; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.userbehaviour_reload (
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
    status integer
);


ALTER TABLE fact.userbehaviour_reload OWNER TO citus;

--
-- TOC entry 389 (class 1259 OID 2095669)
-- Name: usercheckedin; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.usercheckedin (
    organizationid text NOT NULL,
    locationid text NOT NULL,
    kioskid text,
    ordersessionid text,
    dateid integer,
    ordertimestamp text,
    orderid text NOT NULL,
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
-- TOC entry 417 (class 1259 OID 11504790)
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
-- TOC entry 383 (class 1259 OID 19967)
-- Name: watermarktable; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.watermarktable (
    watermarktablename text NOT NULL,
    watermarkcolumn text,
    watermarkvalue timestamp without time zone,
    ticks bigint,
    ts bigint,
    source character varying(50) NOT NULL
);


ALTER TABLE fact.watermarktable OWNER TO citus;

--
-- TOC entry 447 (class 1259 OID 39161154)
-- Name: item_modifiergroup_modifier_mapping; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.item_modifiergroup_modifier_mapping (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    catalogid text,
    catalogname text,
    menuitemid text,
    menuitemname text,
    item_class_type integer,
    modifiergroupid text,
    modifiergroupname text,
    modifierid text,
    modifiername text,
    modifier_class_type integer,
    is_modifier_default boolean,
    min_quantity integer,
    max_quantity integer,
    allow_quantity_increment boolean,
    increment_step integer,
    modifier_default_quantity integer,
    is_modifier_invisible boolean,
    calories text,
    price numeric(12,4),
    is_modifier_active boolean,
    is_modifier_deleted boolean,
    modifier_created_on timestamp without time zone,
    modifier_modified_on timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.item_modifiergroup_modifier_mapping OWNER TO citus;

--
-- TOC entry 450 (class 1259 OID 39161173)
-- Name: menu_entities; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.menu_entities (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    categoryid text,
    categoryname text,
    menuitemid text,
    menuitemname text,
    catalogid text,
    itemunitprice numeric(12,3),
    price_changed_on timestamp without time zone,
    item_class_type integer,
    entitytype text,
    calories text,
    protein numeric(9,2),
    sugar numeric(9,2),
    fat numeric(9,2),
    is_alcoholic boolean,
    is_vegetarian_item boolean,
    is_vegan_item boolean,
    has_allergen boolean,
    is_active boolean,
    is_deleted boolean,
    gms_created_on timestamp without time zone,
    gms_modified_on timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.menu_entities OWNER TO citus;

--
-- TOC entry 449 (class 1259 OID 39161167)
-- Name: modifier_impressions; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.modifier_impressions (
    organizationid text,
    organizationname text,
    locationname text,
    locationid text,
    catalogid text,
    catalogname text,
    businessdate date,
    orderdatelocal timestamp without time zone,
    yyyy integer,
    ww integer,
    transactionheaderid text,
    ordersessionid text,
    orderid text,
    menuitemid text,
    menuitemname text,
    item_class_type integer,
    modifierid text,
    modifiername text,
    modifier_class_type integer,
    parent_modifier_id text,
    nesting_depth integer,
    modifierprice numeric(12,3),
    selection_type text,
    "position" integer,
    score numeric(10,4),
    strategy text,
    context text,
    selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    pre_selected boolean,
    frequentcustomerid text,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.modifier_impressions OWNER TO citus;

--
-- TOC entry 448 (class 1259 OID 39161160)
-- Name: modifier_interactions; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.modifier_interactions (
    organizationid text,
    organizationname text,
    locationname text,
    locationid text,
    catalogid text,
    catalogname text,
    businessdate date,
    orderdatelocal timestamp without time zone,
    yyyy integer,
    ww integer,
    transactionheaderid text,
    ordersessionid text,
    orderid text,
    orderitemid text,
    menuitemid text,
    menuitemname text,
    itemquantity integer,
    itemunitprice numeric(12,3),
    item_class_type integer,
    modifiergroupid text,
    modifiergroupname text,
    modifierid text,
    modifiername text,
    parent_modifier_id text,
    nesting_depth integer,
    modifierquantity integer,
    modifierprice numeric(12,3),
    freequantity integer,
    is_modifier_default boolean,
    min_quantity integer,
    max_quantity integer,
    selection_type text,
    action text,
    session_recorded_at text,
    frequentcustomerid text,
    modifier_default_quantity integer,
    modifier_class_type integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.modifier_interactions OWNER TO citus;

--
-- TOC entry 445 (class 1259 OID 39161142)
-- Name: transactions; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.transactions (
    frequentcustomerid text,
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    kioskid text,
    transactionheaderid text,
    ordersessionid text,
    orderid text,
    orderitemid text,
    menuitemid text,
    itemname text,
    upselllevel text,
    item_class_type integer,
    itemquantity integer,
    categoryid text,
    categoryname text,
    itemunitprice numeric(12,3),
    paymentstatus text,
    numberofitems integer,
    numberofpayments integer,
    ordertotal numeric(14,4),
    ordersubtotal numeric(14,4),
    ordertip numeric(14,4),
    ordertax numeric(14,4),
    ordertypelabel text,
    orderdatelocal timestamp without time zone,
    businessdate date,
    weatherhumidity numeric(7,2),
    weathercondition text,
    temperatureincelcius numeric(7,2),
    yyyy integer,
    mm integer,
    dd integer,
    hh integer,
    ww integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.transactions OWNER TO citus;

--
-- TOC entry 446 (class 1259 OID 39161148)
-- Name: upsell_analysis; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.upsell_analysis (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    frequentcustomerid text,
    transactionheaderid text,
    recommendationid text,
    offereditem text,
    selecteditem text,
    item_class_type integer,
    upselltype text,
    quantity integer,
    businessdate date,
    orderdatelocal timestamp without time zone,
    yyyy integer,
    mm integer,
    dd integer,
    hh integer,
    ww integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.upsell_analysis OWNER TO citus;

--
-- TOC entry 444 (class 1259 OID 39161136)
-- Name: weather; Type: TABLE; Schema: ml; Owner: citus
--

CREATE TABLE ml.weather (
    organizationid text,
    organizationname text,
    locationid text,
    locationname text,
    weatherdate date,
    yyyy integer,
    mm integer,
    dd integer,
    ww integer,
    hh integer,
    humidity integer,
    condition text,
    temperature_c numeric(8,2),
    is_hot boolean,
    is_calm boolean,
    is_cold boolean,
    is_cool boolean,
    is_mild boolean,
    is_warm boolean,
    rain_mm numeric(8,2),
    is_sunny boolean,
    is_windy boolean,
    is_cloudy boolean,
    is_daytime boolean,
    is_raining boolean,
    is_snowing boolean,
    is_very_hot boolean,
    is_freezing boolean,
    is_overcast boolean,
    snowfall_mm numeric(8,2),
    temp_bucket text,
    wind_bucket text,
    feels_colder boolean,
    feels_hotter boolean,
    food_weather text,
    is_heavy_rain boolean,
    is_light_rain boolean,
    is_nighttime boolean,
    is_very_windy boolean,
    pressure_hpa numeric(8,2),
    weather_code integer,
    wind_gust_kmh numeric(8,2),
    comfort_score integer,
    drink_weather text,
    wind_speed_kmh numeric(8,2),
    comfort_bucket text,
    humidity_bucket text,
    condition_bucket text,
    is_precipitating boolean,
    precipitation_mm numeric(8,2),
    visibility_meters numeric(8,2),
    cloud_cover_percent numeric(8,2),
    is_unseasonably_hot boolean,
    is_unseasonably_cold boolean,
    outdoor_dining_score integer,
    wind_direction_degrees integer,
    precipitation_probability numeric(8,2),
    apparent_temperature_celsius numeric(8,2),
    sysinserttime timestamp without time zone
);


ALTER TABLE ml.weather OWNER TO citus;

--
-- TOC entry 391 (class 1259 OID 2258381)
-- Name: report; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.report (
    id character varying(40) NOT NULL,
    organizationid character varying(40) NOT NULL,
    name character varying(255) NOT NULL,
    description text,
    parameters jsonb NOT NULL,
    query text NOT NULL,
    columns jsonb NOT NULL,
    createdon timestamp without time zone NOT NULL,
    createdby character varying(255),
    modifiedon timestamp without time zone,
    modifiedby character varying(255),
    isactive boolean DEFAULT false NOT NULL,
    origin character varying(50) DEFAULT 'Custom'::character varying NOT NULL,
    supportedformats character varying[] DEFAULT ARRAY['Csv'::character varying, 'Excel'::character varying, 'Pdf'::character varying] NOT NULL,
    previewformat character varying(50) DEFAULT 'Tabular'::character varying NOT NULL
);


ALTER TABLE public.report OWNER TO citus;

--
-- TOC entry 392 (class 1259 OID 2379994)
-- Name: reportschedule; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.reportschedule (
    id character varying(40) NOT NULL,
    reportid character varying(40) NOT NULL,
    isactive boolean DEFAULT false NOT NULL,
    organizationid character varying(40) NOT NULL,
    periodfrom timestamp without time zone NOT NULL,
    periodto timestamp without time zone NOT NULL,
    frequencytype character varying(10) NOT NULL,
    frequencydow character varying(10),
    frequencydom smallint,
    frequencytime time without time zone,
    timezone character varying(50) NOT NULL,
    createdon timestamp without time zone NOT NULL,
    createdby character varying(255),
    modifiedon timestamp without time zone,
    modifiedby character varying(255),
    executedon timestamp without time zone,
    format character varying(10) NOT NULL,
    recipients text[],
    parameters jsonb,
    locationid character varying(100)
);


ALTER TABLE public.reportschedule OWNER TO citus;

--
-- TOC entry 360 (class 1259 OID 19778)
-- Name: schemaversions; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.schemaversions (
    schemaversionsid integer NOT NULL,
    scriptname character varying(255) NOT NULL,
    applied timestamp without time zone NOT NULL
);


ALTER TABLE public.schemaversions OWNER TO citus;

--
-- TOC entry 359 (class 1259 OID 19777)
-- Name: schemaversions_schemaversionsid_seq; Type: SEQUENCE; Schema: public; Owner: citus
--

CREATE SEQUENCE public.schemaversions_schemaversionsid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.schemaversions_schemaversionsid_seq OWNER TO citus;

--
-- TOC entry 6400 (class 0 OID 0)
-- Dependencies: 359
-- Name: schemaversions_schemaversionsid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: citus
--

ALTER SEQUENCE public.schemaversions_schemaversionsid_seq OWNED BY public.schemaversions.schemaversionsid;


--
-- TOC entry 453 (class 1259 OID 49106030)
-- Name: gem_failed_order_job_notifications; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.gem_failed_order_job_notifications (
    incidentid text,
    application text,
    organizationid text,
    locationid text,
    eventmodule text,
    eventcategory text,
    eventtype text,
    eventtoken text,
    incidentcount integer,
    firstoccurred text,
    lastoccurred text,
    incidenttype text,
    notificationtypeid text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.gem_failed_order_job_notifications OWNER TO citus;

--
-- TOC entry 442 (class 1259 OID 39161110)
-- Name: modifier_recommendation_sessions; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.modifier_recommendation_sessions (
    locationid text NOT NULL,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    modifier_impressions text,
    modifier_interactions text,
    businessdate date,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE stg.modifier_recommendation_sessions OWNER TO citus;

--
-- TOC entry 403 (class 1259 OID 4966180)
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
-- TOC entry 438 (class 1259 OID 39161084)
-- Name: sent_surveys; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.sent_surveys (
    organizationid text,
    locationid text NOT NULL,
    ordersessionid text NOT NULL,
    orderid text,
    gem_event_category text,
    gem_event_type text,
    survey_metadata text,
    is_responded boolean,
    gem_event_instant text,
    gem_syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE stg.sent_surveys OWNER TO citus;

--
-- TOC entry 396 (class 1259 OID 3303076)
-- Name: transactionheader; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.transactionheader (
    id bigint NOT NULL,
    transactionheaderid text NOT NULL,
    orderid text,
    locationid text,
    kioskid text,
    ordersessionid text,
    dateid integer,
    orderdateutc text,
    orderdatelocal timestamp without time zone,
    orderstatus text,
    ordertype integer,
    numberofitems smallint,
    numberofpayments smallint,
    ordersredeemedrewards numeric(7,3),
    ordersubtotal numeric(7,3),
    ordertotal numeric(7,3),
    ordertax numeric(7,3),
    ordertip numeric(7,3),
    orderdiscount numeric(7,3),
    orderbalance numeric(7,3),
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
    syscosmostsutc text
);


ALTER TABLE stg.transactionheader OWNER TO citus;

--
-- TOC entry 5884 (class 2604 OID 19781)
-- Name: schemaversions schemaversionsid; Type: DEFAULT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.schemaversions ALTER COLUMN schemaversionsid SET DEFAULT nextval('public.schemaversions_schemaversionsid_seq'::regclass);


--
-- TOC entry 6082 (class 2606 OID 27639229)
-- Name: catalog catalog_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (catalogid);


--
-- TOC entry 5926 (class 2606 OID 19791)
-- Name: company company_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (companyid);


--
-- TOC entry 6016 (class 2606 OID 14398703)
-- Name: frequentcustomer customerkey_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer
    ADD CONSTRAINT customerkey_pk PRIMARY KEY (customerkey);


--
-- TOC entry 5929 (class 2606 OID 19799)
-- Name: datedim datedim_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.datedim
    ADD CONSTRAINT datedim_pk PRIMARY KEY (dateid);


--
-- TOC entry 6039 (class 2606 OID 4991321)
-- Name: device device_deviceid_locationid_companyid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_deviceid_locationid_companyid_key UNIQUE (deviceid, locationid, companyid);


--
-- TOC entry 6041 (class 2606 OID 4991319)
-- Name: device device_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_pkey PRIMARY KEY (id);


--
-- TOC entry 5933 (class 2606 OID 19809)
-- Name: element dimelement_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.element
    ADD CONSTRAINT dimelement_pkey PRIMARY KEY (elementid);


--
-- TOC entry 6108 (class 2606 OID 43985160)
-- Name: frequentcustomer_bkp frequentcustomer_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer_bkp
    ADD CONSTRAINT frequentcustomer_bkp_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6018 (class 2606 OID 14398705)
-- Name: frequentcustomer frequentcustomerid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer
    ADD CONSTRAINT frequentcustomerid_unq UNIQUE (frequentcustomerid);


--
-- TOC entry 6071 (class 2606 OID 13713098)
-- Name: grubbrr_source_lookup grubbrr_source_lookup_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.grubbrr_source_lookup
    ADD CONSTRAINT grubbrr_source_lookup_pkey PRIMARY KEY (id);


--
-- TOC entry 6094 (class 2606 OID 39161083)
-- Name: item_modifier_group_modifier_mapping item_modgrp_modfr_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.item_modifier_group_modifier_mapping
    ADD CONSTRAINT item_modgrp_modfr_unq UNIQUE (menuitemid, modifiergroupid, modifierid);


--
-- TOC entry 6060 (class 2606 OID 7230910)
-- Name: itemcategory_bkp itemcategory_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory_bkp
    ADD CONSTRAINT itemcategory_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 5937 (class 2606 OID 19818)
-- Name: itemcategory itemcategory_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory
    ADD CONSTRAINT itemcategory_pk PRIMARY KEY (id);


--
-- TOC entry 5939 (class 2606 OID 19827)
-- Name: kiosk kiosk_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_pk PRIMARY KEY (id);


--
-- TOC entry 5941 (class 2606 OID 19829)
-- Name: kiosk kiosk_uidx; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_uidx UNIQUE (locationid, kioskid);


--
-- TOC entry 6078 (class 2606 OID 27639215)
-- Name: category_hierarchy location_category_menuitem_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.category_hierarchy
    ADD CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 5946 (class 2606 OID 19843)
-- Name: location location_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.location
    ADD CONSTRAINT location_pk PRIMARY KEY (companyid, locationid);


--
-- TOC entry 6053 (class 2606 OID 7231820)
-- Name: weather locationid_apicalldate; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.weather
    ADD CONSTRAINT locationid_apicalldate UNIQUE (locationid, apicalldate);


--
-- TOC entry 6080 (class 2606 OID 27639222)
-- Name: duplicate_items_master locationid_categoryid_menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.duplicate_items_master
    ADD CONSTRAINT locationid_categoryid_menuitemid_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6073 (class 2606 OID 13743404)
-- Name: vw_grubbrrinstallbase locationid_deviceid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase
    ADD CONSTRAINT locationid_deviceid_pk PRIMARY KEY (location_id, kiosk_id);


--
-- TOC entry 6089 (class 2606 OID 37323275)
-- Name: vw_grubbrrinstallbase_all_devices locationid_kioskid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase_all_devices
    ADD CONSTRAINT locationid_kioskid_pk PRIMARY KEY (location_id, kiosk_id);


--
-- TOC entry 6062 (class 2606 OID 10775488)
-- Name: kioskdetails locationid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kioskdetails
    ADD CONSTRAINT locationid_pkey PRIMARY KEY (locationid);


--
-- TOC entry 6032 (class 2606 OID 4966201)
-- Name: menuitem_bkp menuitem_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem_bkp
    ADD CONSTRAINT menuitem_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 6035 (class 2606 OID 4966213)
-- Name: menuitem menuitem_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitem_pk PRIMARY KEY (id);


--
-- TOC entry 6020 (class 2606 OID 3771496)
-- Name: menuitem_test menuitem_test_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem_test
    ADD CONSTRAINT menuitem_test_pk PRIMARY KEY (id);


--
-- TOC entry 6037 (class 2606 OID 18167544)
-- Name: menuitem menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitemid_unq UNIQUE (menuitemid);


--
-- TOC entry 6092 (class 2606 OID 39161078)
-- Name: modifier_group modifier_group_master_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group
    ADD CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid);


--
-- TOC entry 6087 (class 2606 OID 27639244)
-- Name: modifier_group_mapping modifier_group_modifier_glue_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group_mapping
    ADD CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id);


--
-- TOC entry 6085 (class 2606 OID 27639237)
-- Name: modifier modifier_master_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier
    ADD CONSTRAINT modifier_master_pkey PRIMARY KEY (modifierid);


--
-- TOC entry 6064 (class 2606 OID 11432743)
-- Name: ordertype_bkp ordertype_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype_bkp
    ADD CONSTRAINT ordertype_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 5950 (class 2606 OID 19860)
-- Name: ordertype ordertype_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype
    ADD CONSTRAINT ordertype_pk PRIMARY KEY (id);


--
-- TOC entry 6024 (class 2606 OID 4966174)
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- TOC entry 5955 (class 2606 OID 18167517)
-- Name: organizationlocation organizationid_locationid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organizationlocation
    ADD CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 5993 (class 2606 OID 18167546)
-- Name: occasionsurvey orgid_surveyid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.occasionsurvey
    ADD CONSTRAINT orgid_surveyid_pk UNIQUE (organizationid, surveyid);


--
-- TOC entry 6048 (class 2606 OID 4991335)
-- Name: peripheral peripheral_deviceid_peripheralid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_peripheralid_key UNIQUE (deviceid, peripheralid);


--
-- TOC entry 6051 (class 2606 OID 4991333)
-- Name: peripheral peripheral_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_pkey PRIMARY KEY (id);


--
-- TOC entry 5995 (class 2606 OID 2081711)
-- Name: occasionsurvey survey_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.occasionsurvey
    ADD CONSTRAINT survey_pkey PRIMARY KEY (surveykey);


--
-- TOC entry 6058 (class 2606 OID 7230891)
-- Name: upsellgrouplookup upsellgroupid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.upsellgrouplookup
    ADD CONSTRAINT upsellgroupid_pkey PRIMARY KEY (upsellgroupid);


--
-- TOC entry 5990 (class 2606 OID 1318166)
-- Name: userlocation userlocation_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.userlocation
    ADD CONSTRAINT userlocation_pkey PRIMARY KEY (userid, locationid);


--
-- TOC entry 5958 (class 2606 OID 17317777)
-- Name: view view_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.view
    ADD CONSTRAINT view_pkey PRIMARY KEY (viewid);


--
-- TOC entry 6069 (class 2606 OID 11843374)
-- Name: location_menu_preferences location_dayparts_itemid_itemtype_unq; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.location_menu_preferences
    ADD CONSTRAINT location_dayparts_itemid_itemtype_unq UNIQUE (locationid, day_parts, itemid, itemtype);


--
-- TOC entry 6003 (class 2606 OID 14449798)
-- Name: devicetelemetry locationid_deviceid_dateid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT locationid_deviceid_dateid_pk PRIMARY KEY (locationid, deviceid, dateid);


--
-- TOC entry 6022 (class 2606 OID 14449307)
-- Name: itemssurvey locationid_orderid_surveytransid_itemid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT locationid_orderid_surveytransid_itemid_pk PRIMARY KEY (locationid, orderid, surveytransid, itemid);


--
-- TOC entry 5998 (class 2606 OID 14449510)
-- Name: usercheckedin locationid_orderid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.usercheckedin
    ADD CONSTRAINT locationid_orderid_uidx PRIMARY KEY (locationid, orderid);


--
-- TOC entry 6056 (class 2606 OID 14404628)
-- Name: transactionrefunds locationid_transactionheaderid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionrefunds
    ADD CONSTRAINT locationid_transactionheaderid_pk PRIMARY KEY (locationid, transactionheaderid);


--
-- TOC entry 6028 (class 2606 OID 18167505)
-- Name: recommendations locationid_trxnid_recommendationid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT locationid_trxnid_recommendationid_pk PRIMARY KEY (locationid, transactionheaderid, recommendationid);


--
-- TOC entry 5967 (class 2606 OID 19924)
-- Name: ordertiming ordertiming_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.ordertiming
    ADD CONSTRAINT ordertiming_pkey PRIMARY KEY (id);


--
-- TOC entry 6076 (class 2606 OID 18792990)
-- Name: pos_sales_details pos_sales_details_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.pos_sales_details
    ADD CONSTRAINT pos_sales_details_pkey PRIMARY KEY (id);


--
-- TOC entry 6098 (class 2606 OID 39161097)
-- Name: sent_surveys sent_surveys_ordersessionid_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.sent_surveys
    ADD CONSTRAINT sent_surveys_ordersessionid_pkey PRIMARY KEY (locationid, ordersessionid);


--
-- TOC entry 5971 (class 2606 OID 19942)
-- Name: timingsdatalake timingsdatalake_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.timingsdatalake
    ADD CONSTRAINT timingsdatalake_pkey PRIMARY KEY (containername);


--
-- TOC entry 5975 (class 2606 OID 3141243)
-- Name: transactionheader transactionheader_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT transactionheader_pkey PRIMARY KEY (locationid, transactionheaderid);


--
-- TOC entry 6030 (class 2606 OID 4966193)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 6012 (class 2606 OID 2763592)
-- Name: transactionheadertest transactionheadertest_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheadertest
    ADD CONSTRAINT transactionheadertest_pkey PRIMARY KEY (transactionheaderid, id);


--
-- TOC entry 5985 (class 2606 OID 172045)
-- Name: transactionitem transactionitem_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT transactionitem_pkey PRIMARY KEY (transactionheaderid, itemid, itemname);


--
-- TOC entry 5965 (class 2606 OID 14449279)
-- Name: itemmodifier trxnid_itemid_mdfrgrpid_mdfrid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemmodifier
    ADD CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY KEY (transactionheaderid, itemid, modifiergroupid, modifierid);


--
-- TOC entry 6067 (class 2606 OID 11504796)
-- Name: vw_offer_analysis trxnid_recommendationid_itemid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT trxnid_recommendationid_itemid_uidx UNIQUE (transactionheaderid, recommendationid, offereditem);


--
-- TOC entry 5980 (class 2606 OID 19966)
-- Name: userbehaviour userbehaviour_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour
    ADD CONSTRAINT userbehaviour_pkey PRIMARY KEY (id);


--
-- TOC entry 5982 (class 2606 OID 43985146)
-- Name: watermarktable watermarktablename_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.watermarktable
    ADD CONSTRAINT watermarktablename_pk PRIMARY KEY (watermarktablename, source);


--
-- TOC entry 5923 (class 2606 OID 19783)
-- Name: schemaversions PK_schemaversions_Id; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.schemaversions
    ADD CONSTRAINT "PK_schemaversions_Id" PRIMARY KEY (schemaversionsid);


--
-- TOC entry 6005 (class 2606 OID 2258388)
-- Name: report report_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_pkey PRIMARY KEY (id);


--
-- TOC entry 6007 (class 2606 OID 2380001)
-- Name: reportschedule reportschedule_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.reportschedule
    ADD CONSTRAINT reportschedule_pkey PRIMARY KEY (id);


--
-- TOC entry 6096 (class 2606 OID 39161090)
-- Name: sent_surveys sent_surveys_ordersessionid_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.sent_surveys
    ADD CONSTRAINT sent_surveys_ordersessionid_pkey PRIMARY KEY (locationid, ordersessionid);


--
-- TOC entry 6014 (class 2606 OID 3303085)
-- Name: transactionheader transactionheader_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.transactionheader
    ADD CONSTRAINT transactionheader_pkey PRIMARY KEY (transactionheaderid, id);


--
-- TOC entry 6026 (class 2606 OID 4966186)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 5927 (class 1259 OID 19800)
-- Name: IX_dateid_datets; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX "IX_dateid_datets" ON dim.datedim USING btree (dateid, datets);


--
-- TOC entry 5951 (class 1259 OID 19867)
-- Name: IX_organizationid_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX "IX_organizationid_locationid" ON dim.organizationlocation USING btree (organizationid, locationid) INCLUDE (organizationname, locationname);


--
-- TOC entry 5924 (class 1259 OID 19792)
-- Name: company_id_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX company_id_idx ON dim.company USING btree (companyid);


--
-- TOC entry 6042 (class 1259 OID 4991322)
-- Name: deviceid_locationid_companyid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX deviceid_locationid_companyid_idx ON dim.device USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, state, testmode);


--
-- TOC entry 5944 (class 1259 OID 19844)
-- Name: dim_location_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX dim_location_idx ON dim.location USING btree (locationid);


--
-- TOC entry 5930 (class 1259 OID 19801)
-- Name: idx_datedim_dateid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_datedim_dateid ON dim.datedim USING btree (dateid);


--
-- TOC entry 5931 (class 1259 OID 19802)
-- Name: idx_datedim_datets; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_datedim_datets ON dim.datedim USING btree (datets);


--
-- TOC entry 6043 (class 1259 OID 4991323)
-- Name: idx_device_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_id ON dim.device USING btree (deviceid);


--
-- TOC entry 6044 (class 1259 OID 4991324)
-- Name: idx_device_location_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_location_id ON dim.device USING btree (locationid);


--
-- TOC entry 6045 (class 1259 OID 4991325)
-- Name: idx_device_state; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_state ON dim.device USING btree (state);


--
-- TOC entry 6046 (class 1259 OID 4991326)
-- Name: idx_device_testmode; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_testmode ON dim.device USING btree (testmode);


--
-- TOC entry 5952 (class 1259 OID 19868)
-- Name: idx_organizationlocation_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_organizationlocation_locationid ON dim.organizationlocation USING btree (locationid);


--
-- TOC entry 5953 (class 1259 OID 19869)
-- Name: idx_organizationlocation_organizationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_organizationlocation_organizationid ON dim.organizationlocation USING btree (organizationid);


--
-- TOC entry 5956 (class 1259 OID 19885)
-- Name: idx_view_viewid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_view_viewid ON dim.view USING btree (viewid);


--
-- TOC entry 5934 (class 1259 OID 19819)
-- Name: itemcategory_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX itemcategory_idx ON dim.itemcategory USING btree (locationid, categoryid);


--
-- TOC entry 5935 (class 1259 OID 2739023)
-- Name: itemcategory_locationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX itemcategory_locationid_idx ON dim.itemcategory USING btree (locationid) INCLUDE (categoryid, isactive);


--
-- TOC entry 6033 (class 1259 OID 43984756)
-- Name: ix_dim_menuitem_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX ix_dim_menuitem_catalogid ON dim.menuitem USING btree (catalogid);


--
-- TOC entry 6083 (class 1259 OID 43984757)
-- Name: ix_dim_modifier_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX ix_dim_modifier_catalogid ON dim.modifier USING btree (catalogid);


--
-- TOC entry 6090 (class 1259 OID 43984758)
-- Name: ix_dim_modifiergroup_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX ix_dim_modifiergroup_catalogid ON dim.modifier_group USING btree (catalogid);


--
-- TOC entry 5942 (class 1259 OID 2739027)
-- Name: kioskid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX kioskid_idx ON dim.kiosk USING btree (locationid) INCLUDE (istestkiosk);


--
-- TOC entry 5947 (class 1259 OID 2739030)
-- Name: locationgroupid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX locationgroupid_idx ON dim.location USING btree (locationgroupid);


--
-- TOC entry 5943 (class 1259 OID 19836)
-- Name: locationgroupid_uidx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX locationgroupid_uidx ON dim.locationgroup USING btree (locationgroupid);


--
-- TOC entry 5948 (class 1259 OID 19861)
-- Name: order_type_uidx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX order_type_uidx ON dim.ordertype USING btree (locationid, kioskid, ordertypeid);


--
-- TOC entry 5991 (class 1259 OID 2739039)
-- Name: organizationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX organizationid_idx ON dim.occasionsurvey USING btree (organizationid);


--
-- TOC entry 6049 (class 1259 OID 4991341)
-- Name: peripheral_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX peripheral_idx ON dim.peripheral USING btree (deviceid, peripheralid) INCLUDE (peripheraltype, state, statechangedate);


--
-- TOC entry 6008 (class 1259 OID 2739016)
-- Name: rating_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX rating_idx ON dim.feedbackrating USING btree (rating) INCLUDE (ratingdesc);


--
-- TOC entry 5996 (class 1259 OID 2739040)
-- Name: surveyid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX surveyid_idx ON dim.occasionsurvey USING btree (surveyid) INCLUDE (surveyname, surveytype);


--
-- TOC entry 6009 (class 1259 OID 2739022)
-- Name: surveytransstatus_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX surveytransstatus_idx ON dim.feedbackstatus USING btree (surveytransstatus) INCLUDE (statusdesc);


--
-- TOC entry 6074 (class 1259 OID 19379204)
-- Name: cep_incidents_uidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX cep_incidents_uidx ON fact.cep_incidents USING btree (severity, eventmodule, eventcategory, eventtype, organizationid, locationid, eventtoken, eventinstant);


--
-- TOC entry 5959 (class 1259 OID 19901)
-- Name: deviceeventidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX deviceeventidx ON fact.deviceevent USING btree (companyid, locationid);


--
-- TOC entry 5960 (class 1259 OID 19902)
-- Name: deviceeventuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX deviceeventuidx ON fact.deviceevent USING btree (application, companyid, locationid, moduleid, eventtoken, datacategory, actiontype, eventinstant);


--
-- TOC entry 5986 (class 1259 OID 20002)
-- Name: idx_devicestate; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicestate ON fact.devicestate USING btree (locationid, companyid, deviceid) WITH (deduplicate_items='true');


--
-- TOC entry 5987 (class 1259 OID 20003)
-- Name: idx_devicestate_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicestate_dateid ON fact.devicestate USING btree (dateid);


--
-- TOC entry 5988 (class 1259 OID 20004)
-- Name: idx_devicestate_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicestate_locationid ON fact.devicestate USING btree (locationid);


--
-- TOC entry 5999 (class 1259 OID 2095701)
-- Name: idx_devicetelemetry; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicetelemetry ON fact.devicetelemetry USING btree (locationid, deviceid);


--
-- TOC entry 6000 (class 1259 OID 2095702)
-- Name: idx_devicetelemetry_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicetelemetry_dateid ON fact.devicetelemetry USING btree (dateid);


--
-- TOC entry 6001 (class 1259 OID 2095703)
-- Name: idx_devicetelemetry_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicetelemetry_locationid ON fact.devicetelemetry USING btree (locationid);


--
-- TOC entry 5969 (class 1259 OID 3755262)
-- Name: idx_fact_pipelinerunstatus_correlationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_fact_pipelinerunstatus_correlationid ON fact.pipelinerunstatus USING btree (correlationid) INCLUDE (pipelinestatus, pipelinetriggertime, pipelinecompletedtime);


--
-- TOC entry 5972 (class 1259 OID 13104859)
-- Name: idx_th_date_status_loc; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_th_date_status_loc ON fact.transactionheader USING btree (businessdate, orderstatus, locationid);


--
-- TOC entry 5983 (class 1259 OID 19988)
-- Name: idx_transactionitem_headerid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_transactionitem_headerid ON fact.transactionitem USING btree (transactionheaderid);


--
-- TOC entry 6054 (class 1259 OID 7230843)
-- Name: idx_transactionrefunds_headerid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_transactionrefunds_headerid ON fact.transactionrefunds USING btree (transactionheaderid);


--
-- TOC entry 5962 (class 1259 OID 19917)
-- Name: itemmodifieridx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX itemmodifieridx ON fact.itemmodifier USING btree (itemid);


--
-- TOC entry 5961 (class 1259 OID 23803773)
-- Name: ix_deviceevent_journey_lookup; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX ix_deviceevent_journey_lookup ON fact.deviceevent USING btree (locationid, dateid, datacategory, eventtoken) WHERE ((datacategory = 'insight'::text) AND (actiontype = ANY (ARRAY['CategorySelected'::text, 'SubCategorySelected'::text, 'RegularItemSelected'::text, 'ItemRemoved'::text, 'ModifierGroupSelected'::text, 'ModifierSelected'::text, 'ModifierUnselected'::text])));


--
-- TOC entry 6065 (class 1259 OID 11504806)
-- Name: locationid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX locationid_idx ON fact.vw_offer_analysis USING btree (locationid);


--
-- TOC entry 5968 (class 1259 OID 19930)
-- Name: peripheralstate_uidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE UNIQUE INDEX peripheralstate_uidx ON fact.peripheralstate USING btree (deviceid, peripheralid, state, statestart);


--
-- TOC entry 5973 (class 1259 OID 2739063)
-- Name: transactionheader_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionheader_locationid_dateid_idx ON fact.transactionheader USING btree (locationid, dateid) INCLUDE (orderstatus, ordertype, businessdate);


--
-- TOC entry 5963 (class 1259 OID 2739054)
-- Name: transactionheaderid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionheaderid_idx ON fact.itemmodifier USING btree (transactionheaderid);


--
-- TOC entry 6010 (class 1259 OID 2763593)
-- Name: transactionheadertest_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionheadertest_locationid_dateid_idx ON fact.transactionheadertest USING btree (locationid, dateid) INCLUDE (orderstatus, ordertype, businessdate);


--
-- TOC entry 5976 (class 1259 OID 19958)
-- Name: transactionpayment_orderid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionpayment_orderid_idx ON fact.transactionpayment USING btree (orderid);


--
-- TOC entry 5977 (class 1259 OID 19959)
-- Name: transactionpaymentuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionpaymentuidx ON fact.transactionpayment USING btree (transactionheaderid, paymentintegrationid, paymentid);


--
-- TOC entry 5978 (class 1259 OID 2739075)
-- Name: userbehaviour_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX userbehaviour_locationid_dateid_idx ON fact.userbehaviour USING btree (locationid, dateid) INCLUDE (ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier);


--
-- TOC entry 6102 (class 1259 OID 43985112)
-- Name: ix_ml_imm_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_imm_locationid ON ml.item_modifiergroup_modifier_mapping USING btree (locationid);


--
-- TOC entry 6105 (class 1259 OID 43985110)
-- Name: ix_ml_me_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_me_locationid ON ml.menu_entities USING btree (locationid);


--
-- TOC entry 6106 (class 1259 OID 43985111)
-- Name: ix_ml_me_menuitemid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_me_menuitemid ON ml.menu_entities USING btree (menuitemid);


--
-- TOC entry 6103 (class 1259 OID 43985115)
-- Name: ix_ml_mi_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_mi_locid_yyyy_ww ON ml.modifier_interactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6104 (class 1259 OID 43985116)
-- Name: ix_ml_mimp_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_mimp_locid_yyyy_ww ON ml.modifier_impressions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6100 (class 1259 OID 43985113)
-- Name: ix_ml_trx_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_trx_locid_yyyy_ww ON ml.transactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6101 (class 1259 OID 43985114)
-- Name: ix_ml_ua_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_ua_locid_yyyy_ww ON ml.upsell_analysis USING btree (locationid, yyyy, ww);


--
-- TOC entry 6099 (class 1259 OID 43985109)
-- Name: ix_ml_wth_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_wth_locid_yyyy_ww ON ml.weather USING btree (locationid, yyyy, ww);


--
-- TOC entry 6124 (class 2606 OID 18167639)
-- Name: vw_grubbrrinstallbase organizationid_locationid_fk; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase
    ADD CONSTRAINT organizationid_locationid_fk FOREIGN KEY (organization_id, location_id) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6125 (class 2606 OID 37323276)
-- Name: vw_grubbrrinstallbase_all_devices organizationid_locationid_fk; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase_all_devices
    ADD CONSTRAINT organizationid_locationid_fk FOREIGN KEY (organization_id, location_id) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6122 (class 2606 OID 4991336)
-- Name: peripheral peripheral_deviceid_fkey; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES dim.device(id);


--
-- TOC entry 6113 (class 2606 OID 7231002)
-- Name: transactionitem categoryid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT categoryid_fk FOREIGN KEY (categoryid) REFERENCES dim.itemcategory(id);


--
-- TOC entry 6117 (class 2606 OID 18167581)
-- Name: devicetelemetry location_deviceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT location_deviceid_fk FOREIGN KEY (locationid, deviceid) REFERENCES dim.kiosk(locationid, kioskid);


--
-- TOC entry 6121 (class 2606 OID 18167629)
-- Name: recommendations location_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6109 (class 2606 OID 18167644)
-- Name: transactionheader locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6114 (class 2606 OID 18167649)
-- Name: transactionitem locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6115 (class 2606 OID 7231007)
-- Name: transactionitem locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6112 (class 2606 OID 18167664)
-- Name: transactionpayment locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionpayment
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6123 (class 2606 OID 18167634)
-- Name: vw_offer_analysis locationid_trxnid_recommendationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT locationid_trxnid_recommendationid_fk FOREIGN KEY (locationid, transactionheaderid, recommendationid) REFERENCES fact.recommendations(locationid, transactionheaderid, recommendationid);


--
-- TOC entry 6116 (class 2606 OID 7231211)
-- Name: transactionitem menuitemid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT menuitemid_fk FOREIGN KEY (menuitemid) REFERENCES dim.menuitem(id);


--
-- TOC entry 6110 (class 2606 OID 11432865)
-- Name: transactionheader ordertype_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT ordertype_fk FOREIGN KEY (ordertype) REFERENCES dim.ordertype(id);


--
-- TOC entry 6118 (class 2606 OID 18167552)
-- Name: itemssurvey orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6119 (class 2606 OID 18167547)
-- Name: itemssurvey orgid_surveyid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT orgid_surveyid_fk FOREIGN KEY (organizationid, surveyid) REFERENCES dim.occasionsurvey(organizationid, surveyid);


--
-- TOC entry 6120 (class 2606 OID 18167571)
-- Name: occasionsurveydetail sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);


--
-- TOC entry 6111 (class 2606 OID 18167576)
-- Name: transactionheader sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);


--
-- TOC entry 6300 (class 0 OID 0)
-- Dependencies: 71
-- Name: SCHEMA dim; Type: ACL; Schema: -; Owner: citus
--

GRANT USAGE ON SCHEMA dim TO powerbi;
GRANT USAGE ON SCHEMA dim TO dvirani;
GRANT USAGE ON SCHEMA dim TO ppatel;
GRANT USAGE ON SCHEMA dim TO varshil;


--
-- TOC entry 6301 (class 0 OID 0)
-- Dependencies: 79
-- Name: SCHEMA fact; Type: ACL; Schema: -; Owner: citus
--

GRANT USAGE ON SCHEMA fact TO powerbi;
GRANT USAGE ON SCHEMA fact TO dvirani;
GRANT USAGE ON SCHEMA fact TO ppatel;
GRANT USAGE ON SCHEMA fact TO varshil;


--
-- TOC entry 6302 (class 0 OID 0)
-- Dependencies: 68
-- Name: SCHEMA ml; Type: ACL; Schema: -; Owner: citus
--

GRANT USAGE ON SCHEMA ml TO ppatel;
GRANT USAGE ON SCHEMA ml TO varshil;


--
-- TOC entry 6304 (class 0 OID 0)
-- Dependencies: 61
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA public TO citus WITH GRANT OPTION;
SET SESSION AUTHORIZATION citus;
GRANT USAGE ON SCHEMA public TO powerbi;
RESET SESSION AUTHORIZATION;
SET SESSION AUTHORIZATION citus;
GRANT USAGE ON SCHEMA public TO dvirani;
RESET SESSION AUTHORIZATION;
SET SESSION AUTHORIZATION citus;
GRANT USAGE ON SCHEMA public TO ppatel;
RESET SESSION AUTHORIZATION;
SET SESSION AUTHORIZATION citus;
GRANT USAGE ON SCHEMA public TO varshil;
RESET SESSION AUTHORIZATION;


--
-- TOC entry 6305 (class 0 OID 0)
-- Dependencies: 776
-- Name: FUNCTION create_extension(extname text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_extension(extname text) TO citus WITH GRANT OPTION;


--
-- TOC entry 6306 (class 0 OID 0)
-- Dependencies: 867
-- Name: FUNCTION drop_extension(extname text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.drop_extension(extname text) TO citus WITH GRANT OPTION;


--
-- TOC entry 6307 (class 0 OID 0)
-- Dependencies: 1269
-- Name: FUNCTION pg_replication_origin_create(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_create(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_create(text) TO citus;


--
-- TOC entry 6308 (class 0 OID 0)
-- Dependencies: 1221
-- Name: FUNCTION pg_replication_origin_drop(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_drop(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_drop(text) TO citus;


--
-- TOC entry 6309 (class 0 OID 0)
-- Dependencies: 672
-- Name: FUNCTION pg_replication_origin_progress(text, boolean); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_progress(text, boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_progress(text, boolean) TO citus;


--
-- TOC entry 6310 (class 0 OID 0)
-- Dependencies: 1449
-- Name: FUNCTION pg_replication_origin_session_progress(boolean); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_session_progress(boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_session_progress(boolean) TO citus;


--
-- TOC entry 6311 (class 0 OID 0)
-- Dependencies: 532
-- Name: FUNCTION pg_replication_origin_session_setup(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_session_setup(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_session_setup(text) TO citus;


--
-- TOC entry 6312 (class 0 OID 0)
-- Dependencies: 1254
-- Name: FUNCTION pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) TO citus;


--
-- TOC entry 6313 (class 0 OID 0)
-- Dependencies: 398
-- Name: TABLE abtests; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.abtests TO powerbi;
GRANT SELECT ON TABLE dim.abtests TO dvirani;
GRANT SELECT ON TABLE dim.abtests TO ppatel;
GRANT SELECT ON TABLE dim.abtests TO varshil;


--
-- TOC entry 6314 (class 0 OID 0)
-- Dependencies: 362
-- Name: TABLE datedim; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.datedim TO powerbi;
GRANT SELECT ON TABLE dim.datedim TO dvirani;
GRANT SELECT ON TABLE dim.datedim TO ppatel;
GRANT SELECT ON TABLE dim.datedim TO varshil;


--
-- TOC entry 6315 (class 0 OID 0)
-- Dependencies: 372
-- Name: TABLE businessdate; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.businessdate TO powerbi;
GRANT SELECT ON TABLE dim.businessdate TO dvirani;
GRANT SELECT ON TABLE dim.businessdate TO ppatel;
GRANT SELECT ON TABLE dim.businessdate TO varshil;


--
-- TOC entry 6316 (class 0 OID 0)
-- Dependencies: 429
-- Name: TABLE catalog; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.catalog TO ppatel;
GRANT SELECT ON TABLE dim.catalog TO varshil;


--
-- TOC entry 6317 (class 0 OID 0)
-- Dependencies: 427
-- Name: TABLE category_hierarchy; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.category_hierarchy TO ppatel;
GRANT SELECT ON TABLE dim.category_hierarchy TO varshil;


--
-- TOC entry 6318 (class 0 OID 0)
-- Dependencies: 361
-- Name: TABLE company; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.company TO powerbi;
GRANT SELECT ON TABLE dim.company TO dvirani;
GRANT SELECT ON TABLE dim.company TO ppatel;
GRANT SELECT ON TABLE dim.company TO varshil;


--
-- TOC entry 6319 (class 0 OID 0)
-- Dependencies: 407
-- Name: TABLE device; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.device TO dvirani;
GRANT SELECT ON TABLE dim.device TO ppatel;
GRANT SELECT ON TABLE dim.device TO varshil;


--
-- TOC entry 6320 (class 0 OID 0)
-- Dependencies: 428
-- Name: TABLE duplicate_items_master; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.duplicate_items_master TO ppatel;
GRANT SELECT ON TABLE dim.duplicate_items_master TO varshil;


--
-- TOC entry 6321 (class 0 OID 0)
-- Dependencies: 363
-- Name: TABLE element; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.element TO powerbi;
GRANT SELECT ON TABLE dim.element TO dvirani;
GRANT SELECT ON TABLE dim.element TO ppatel;
GRANT SELECT ON TABLE dim.element TO varshil;


--
-- TOC entry 6322 (class 0 OID 0)
-- Dependencies: 393
-- Name: TABLE feedbackrating; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackrating TO powerbi;
GRANT SELECT ON TABLE dim.feedbackrating TO dvirani;
GRANT SELECT ON TABLE dim.feedbackrating TO ppatel;
GRANT SELECT ON TABLE dim.feedbackrating TO varshil;


--
-- TOC entry 6323 (class 0 OID 0)
-- Dependencies: 394
-- Name: TABLE feedbackstatus; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackstatus TO powerbi;
GRANT SELECT ON TABLE dim.feedbackstatus TO dvirani;
GRANT SELECT ON TABLE dim.feedbackstatus TO ppatel;
GRANT SELECT ON TABLE dim.feedbackstatus TO varshil;


--
-- TOC entry 6324 (class 0 OID 0)
-- Dependencies: 397
-- Name: TABLE frequentcustomer; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.frequentcustomer TO powerbi;
GRANT SELECT ON TABLE dim.frequentcustomer TO dvirani;
GRANT SELECT ON TABLE dim.frequentcustomer TO ppatel;
GRANT SELECT ON TABLE dim.frequentcustomer TO varshil;


--
-- TOC entry 6325 (class 0 OID 0)
-- Dependencies: 452
-- Name: TABLE frequentcustomer_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.frequentcustomer_bkp TO ppatel;
GRANT SELECT ON TABLE dim.frequentcustomer_bkp TO varshil;


--
-- TOC entry 6326 (class 0 OID 0)
-- Dependencies: 420
-- Name: TABLE grubbrr_source_lookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.grubbrr_source_lookup TO ppatel;
GRANT SELECT ON TABLE dim.grubbrr_source_lookup TO varshil;


--
-- TOC entry 6327 (class 0 OID 0)
-- Dependencies: 437
-- Name: TABLE item_modifier_group_modifier_mapping; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.item_modifier_group_modifier_mapping TO ppatel;
GRANT SELECT ON TABLE dim.item_modifier_group_modifier_mapping TO varshil;


--
-- TOC entry 6328 (class 0 OID 0)
-- Dependencies: 364
-- Name: TABLE itemcategory; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory TO powerbi;
GRANT SELECT ON TABLE dim.itemcategory TO dvirani;
GRANT SELECT ON TABLE dim.itemcategory TO ppatel;
GRANT SELECT ON TABLE dim.itemcategory TO varshil;


--
-- TOC entry 6329 (class 0 OID 0)
-- Dependencies: 413
-- Name: TABLE itemcategory_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory_bkp TO dvirani;
GRANT SELECT ON TABLE dim.itemcategory_bkp TO ppatel;
GRANT SELECT ON TABLE dim.itemcategory_bkp TO varshil;


--
-- TOC entry 6330 (class 0 OID 0)
-- Dependencies: 415
-- Name: TABLE itemcategorymapping; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategorymapping TO ppatel;
GRANT SELECT ON TABLE dim.itemcategorymapping TO varshil;


--
-- TOC entry 6331 (class 0 OID 0)
-- Dependencies: 365
-- Name: TABLE kiosk; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kiosk TO powerbi;
GRANT SELECT ON TABLE dim.kiosk TO dvirani;
GRANT SELECT ON TABLE dim.kiosk TO ppatel;
GRANT SELECT ON TABLE dim.kiosk TO varshil;


--
-- TOC entry 6332 (class 0 OID 0)
-- Dependencies: 414
-- Name: TABLE kioskdetails; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kioskdetails TO dvirani;
GRANT SELECT ON TABLE dim.kioskdetails TO ppatel;
GRANT SELECT ON TABLE dim.kioskdetails TO varshil;


--
-- TOC entry 6333 (class 0 OID 0)
-- Dependencies: 367
-- Name: TABLE location; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.location TO powerbi;
GRANT SELECT ON TABLE dim.location TO dvirani;
GRANT SELECT ON TABLE dim.location TO ppatel;
GRANT SELECT ON TABLE dim.location TO varshil;


--
-- TOC entry 6334 (class 0 OID 0)
-- Dependencies: 366
-- Name: TABLE locationgroup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.locationgroup TO powerbi;
GRANT SELECT ON TABLE dim.locationgroup TO dvirani;
GRANT SELECT ON TABLE dim.locationgroup TO ppatel;
GRANT SELECT ON TABLE dim.locationgroup TO varshil;


--
-- TOC entry 6335 (class 0 OID 0)
-- Dependencies: 406
-- Name: TABLE menuitem; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuitem TO dvirani;
GRANT SELECT ON TABLE dim.menuitem TO ppatel;
GRANT SELECT ON TABLE dim.menuitem TO varshil;


--
-- TOC entry 6336 (class 0 OID 0)
-- Dependencies: 405
-- Name: TABLE menuitem_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuitem_bkp TO dvirani;
GRANT SELECT ON TABLE dim.menuitem_bkp TO ppatel;
GRANT SELECT ON TABLE dim.menuitem_bkp TO varshil;


--
-- TOC entry 6337 (class 0 OID 0)
-- Dependencies: 399
-- Name: TABLE menuitem_test; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuitem_test TO powerbi;
GRANT SELECT ON TABLE dim.menuitem_test TO dvirani;
GRANT SELECT ON TABLE dim.menuitem_test TO ppatel;
GRANT SELECT ON TABLE dim.menuitem_test TO varshil;


--
-- TOC entry 6338 (class 0 OID 0)
-- Dependencies: 430
-- Name: TABLE modifier; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.modifier TO ppatel;
GRANT SELECT ON TABLE dim.modifier TO varshil;


--
-- TOC entry 6339 (class 0 OID 0)
-- Dependencies: 436
-- Name: TABLE modifier_group; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.modifier_group TO ppatel;
GRANT SELECT ON TABLE dim.modifier_group TO varshil;


--
-- TOC entry 6340 (class 0 OID 0)
-- Dependencies: 431
-- Name: TABLE modifier_group_mapping; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.modifier_group_mapping TO ppatel;
GRANT SELECT ON TABLE dim.modifier_group_mapping TO varshil;


--
-- TOC entry 6341 (class 0 OID 0)
-- Dependencies: 388
-- Name: TABLE occasionsurvey; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.occasionsurvey TO powerbi;
GRANT SELECT ON TABLE dim.occasionsurvey TO dvirani;
GRANT SELECT ON TABLE dim.occasionsurvey TO ppatel;
GRANT SELECT ON TABLE dim.occasionsurvey TO varshil;


--
-- TOC entry 6342 (class 0 OID 0)
-- Dependencies: 368
-- Name: TABLE ordertype; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype TO powerbi;
GRANT SELECT ON TABLE dim.ordertype TO dvirani;
GRANT SELECT ON TABLE dim.ordertype TO ppatel;
GRANT SELECT ON TABLE dim.ordertype TO varshil;


--
-- TOC entry 6343 (class 0 OID 0)
-- Dependencies: 416
-- Name: TABLE ordertype_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype_bkp TO ppatel;
GRANT SELECT ON TABLE dim.ordertype_bkp TO varshil;


--
-- TOC entry 6344 (class 0 OID 0)
-- Dependencies: 402
-- Name: TABLE organization; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organization TO dvirani;
GRANT SELECT ON TABLE dim.organization TO ppatel;
GRANT SELECT ON TABLE dim.organization TO varshil;


--
-- TOC entry 6345 (class 0 OID 0)
-- Dependencies: 369
-- Name: TABLE organizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organizationlocation TO powerbi;
GRANT SELECT ON TABLE dim.organizationlocation TO dvirani;
GRANT SELECT ON TABLE dim.organizationlocation TO ppatel;
GRANT SELECT ON TABLE dim.organizationlocation TO varshil;


--
-- TOC entry 6346 (class 0 OID 0)
-- Dependencies: 370
-- Name: TABLE organizationparent; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organizationparent TO powerbi;
GRANT SELECT ON TABLE dim.organizationparent TO dvirani;
GRANT SELECT ON TABLE dim.organizationparent TO ppatel;
GRANT SELECT ON TABLE dim.organizationparent TO varshil;


--
-- TOC entry 6347 (class 0 OID 0)
-- Dependencies: 408
-- Name: TABLE peripheral; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.peripheral TO dvirani;
GRANT SELECT ON TABLE dim.peripheral TO ppatel;
GRANT SELECT ON TABLE dim.peripheral TO varshil;


--
-- TOC entry 6348 (class 0 OID 0)
-- Dependencies: 412
-- Name: TABLE upsellgrouplookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.upsellgrouplookup TO dvirani;
GRANT SELECT ON TABLE dim.upsellgrouplookup TO ppatel;
GRANT SELECT ON TABLE dim.upsellgrouplookup TO varshil;


--
-- TOC entry 6349 (class 0 OID 0)
-- Dependencies: 386
-- Name: TABLE userlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.userlocation TO powerbi;
GRANT SELECT ON TABLE dim.userlocation TO dvirani;
GRANT SELECT ON TABLE dim.userlocation TO ppatel;
GRANT SELECT ON TABLE dim.userlocation TO varshil;


--
-- TOC entry 6350 (class 0 OID 0)
-- Dependencies: 371
-- Name: TABLE view; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.view TO powerbi;
GRANT SELECT ON TABLE dim.view TO dvirani;
GRANT SELECT ON TABLE dim.view TO ppatel;
GRANT SELECT ON TABLE dim.view TO varshil;


--
-- TOC entry 6351 (class 0 OID 0)
-- Dependencies: 421
-- Name: TABLE vw_grubbrrinstallbase; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vw_grubbrrinstallbase TO ppatel;
GRANT SELECT ON TABLE dim.vw_grubbrrinstallbase TO varshil;


--
-- TOC entry 6352 (class 0 OID 0)
-- Dependencies: 435
-- Name: TABLE vw_grubbrrinstallbase_all_devices; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vw_grubbrrinstallbase_all_devices TO ppatel;
GRANT SELECT ON TABLE dim.vw_grubbrrinstallbase_all_devices TO varshil;


--
-- TOC entry 6353 (class 0 OID 0)
-- Dependencies: 410
-- Name: TABLE weather; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather TO dvirani;
GRANT SELECT ON TABLE dim.weather TO ppatel;
GRANT SELECT ON TABLE dim.weather TO varshil;


--
-- TOC entry 6354 (class 0 OID 0)
-- Dependencies: 426
-- Name: TABLE vw_weatherhourlydata; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vw_weatherhourlydata TO ppatel;
GRANT SELECT ON TABLE dim.vw_weatherhourlydata TO varshil;


--
-- TOC entry 6355 (class 0 OID 0)
-- Dependencies: 373
-- Name: TABLE vworganizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vworganizationlocation TO powerbi;
GRANT SELECT ON TABLE dim.vworganizationlocation TO dvirani;
GRANT SELECT ON TABLE dim.vworganizationlocation TO ppatel;
GRANT SELECT ON TABLE dim.vworganizationlocation TO varshil;


--
-- TOC entry 6356 (class 0 OID 0)
-- Dependencies: 409
-- Name: TABLE weather_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather_bkp TO dvirani;
GRANT SELECT ON TABLE dim.weather_bkp TO ppatel;
GRANT SELECT ON TABLE dim.weather_bkp TO varshil;


--
-- TOC entry 6357 (class 0 OID 0)
-- Dependencies: 451
-- Name: TABLE "T_4442_1eca082546ae4881a2b72397e354c4fa"; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact."T_4442_1eca082546ae4881a2b72397e354c4fa" TO ppatel;
GRANT SELECT ON TABLE fact."T_4442_1eca082546ae4881a2b72397e354c4fa" TO varshil;


--
-- TOC entry 6358 (class 0 OID 0)
-- Dependencies: 433
-- Name: TABLE "T_5656_e6b4c2c790f549b8b4f741798c8912c6"; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact."T_5656_e6b4c2c790f549b8b4f741798c8912c6" TO ppatel;
GRANT SELECT ON TABLE fact."T_5656_e6b4c2c790f549b8b4f741798c8912c6" TO varshil;


--
-- TOC entry 6359 (class 0 OID 0)
-- Dependencies: 434
-- Name: TABLE "T_5731_5b365fb5f4a74dfeae4a5924eb4daf5b"; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact."T_5731_5b365fb5f4a74dfeae4a5924eb4daf5b" TO ppatel;
GRANT SELECT ON TABLE fact."T_5731_5b365fb5f4a74dfeae4a5924eb4daf5b" TO varshil;


--
-- TOC entry 6360 (class 0 OID 0)
-- Dependencies: 423
-- Name: TABLE cep_incidents; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.cep_incidents TO ppatel;
GRANT SELECT ON TABLE fact.cep_incidents TO varshil;


--
-- TOC entry 6361 (class 0 OID 0)
-- Dependencies: 419
-- Name: TABLE customer_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.customer_menu_preferences TO ppatel;
GRANT SELECT ON TABLE fact.customer_menu_preferences TO varshil;


--
-- TOC entry 6362 (class 0 OID 0)
-- Dependencies: 374
-- Name: TABLE deviceevent; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.deviceevent TO powerbi;
GRANT SELECT ON TABLE fact.deviceevent TO dvirani;
GRANT SELECT ON TABLE fact.deviceevent TO ppatel;
GRANT SELECT ON TABLE fact.deviceevent TO varshil;


--
-- TOC entry 6363 (class 0 OID 0)
-- Dependencies: 385
-- Name: TABLE devicestate; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicestate TO powerbi;
GRANT SELECT ON TABLE fact.devicestate TO dvirani;
GRANT SELECT ON TABLE fact.devicestate TO ppatel;
GRANT SELECT ON TABLE fact.devicestate TO varshil;


--
-- TOC entry 6364 (class 0 OID 0)
-- Dependencies: 390
-- Name: TABLE devicetelemetry; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicetelemetry TO powerbi;
GRANT SELECT ON TABLE fact.devicetelemetry TO dvirani;
GRANT SELECT ON TABLE fact.devicetelemetry TO ppatel;
GRANT SELECT ON TABLE fact.devicetelemetry TO varshil;


--
-- TOC entry 6365 (class 0 OID 0)
-- Dependencies: 375
-- Name: TABLE itemmodifier; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemmodifier TO powerbi;
GRANT SELECT ON TABLE fact.itemmodifier TO dvirani;
GRANT SELECT ON TABLE fact.itemmodifier TO ppatel;
GRANT SELECT ON TABLE fact.itemmodifier TO varshil;


--
-- TOC entry 6366 (class 0 OID 0)
-- Dependencies: 400
-- Name: TABLE itemssurvey; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemssurvey TO dvirani;
GRANT SELECT ON TABLE fact.itemssurvey TO ppatel;
GRANT SELECT ON TABLE fact.itemssurvey TO varshil;


--
-- TOC entry 6367 (class 0 OID 0)
-- Dependencies: 418
-- Name: TABLE location_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.location_menu_preferences TO ppatel;
GRANT SELECT ON TABLE fact.location_menu_preferences TO varshil;


--
-- TOC entry 6368 (class 0 OID 0)
-- Dependencies: 432
-- Name: TABLE location_statistics; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.location_statistics TO ppatel;
GRANT SELECT ON TABLE fact.location_statistics TO varshil;


--
-- TOC entry 6369 (class 0 OID 0)
-- Dependencies: 440
-- Name: TABLE modifier_impressions; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.modifier_impressions TO ppatel;
GRANT SELECT ON TABLE fact.modifier_impressions TO varshil;


--
-- TOC entry 6370 (class 0 OID 0)
-- Dependencies: 441
-- Name: TABLE modifier_interactions; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.modifier_interactions TO ppatel;
GRANT SELECT ON TABLE fact.modifier_interactions TO varshil;


--
-- TOC entry 6371 (class 0 OID 0)
-- Dependencies: 443
-- Name: TABLE modifier_recommendations; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.modifier_recommendations TO ppatel;
GRANT SELECT ON TABLE fact.modifier_recommendations TO varshil;


--
-- TOC entry 6372 (class 0 OID 0)
-- Dependencies: 401
-- Name: TABLE occasionsurveydetail; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.occasionsurveydetail TO dvirani;
GRANT SELECT ON TABLE fact.occasionsurveydetail TO ppatel;
GRANT SELECT ON TABLE fact.occasionsurveydetail TO varshil;


--
-- TOC entry 6373 (class 0 OID 0)
-- Dependencies: 376
-- Name: TABLE ordertiming; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.ordertiming TO powerbi;
GRANT SELECT ON TABLE fact.ordertiming TO dvirani;
GRANT SELECT ON TABLE fact.ordertiming TO ppatel;
GRANT SELECT ON TABLE fact.ordertiming TO varshil;


--
-- TOC entry 6374 (class 0 OID 0)
-- Dependencies: 377
-- Name: TABLE peripheralstate; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.peripheralstate TO powerbi;
GRANT SELECT ON TABLE fact.peripheralstate TO dvirani;
GRANT SELECT ON TABLE fact.peripheralstate TO ppatel;
GRANT SELECT ON TABLE fact.peripheralstate TO varshil;


--
-- TOC entry 6375 (class 0 OID 0)
-- Dependencies: 378
-- Name: TABLE pipelinerunstatus; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.pipelinerunstatus TO powerbi;
GRANT SELECT ON TABLE fact.pipelinerunstatus TO dvirani;
GRANT SELECT ON TABLE fact.pipelinerunstatus TO ppatel;
GRANT SELECT ON TABLE fact.pipelinerunstatus TO varshil;


--
-- TOC entry 6376 (class 0 OID 0)
-- Dependencies: 425
-- Name: TABLE pos_sales_details; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.pos_sales_details TO ppatel;
GRANT SELECT ON TABLE fact.pos_sales_details TO varshil;


--
-- TOC entry 6377 (class 0 OID 0)
-- Dependencies: 404
-- Name: TABLE recommendations; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.recommendations TO dvirani;
GRANT SELECT ON TABLE fact.recommendations TO ppatel;
GRANT SELECT ON TABLE fact.recommendations TO varshil;


--
-- TOC entry 6378 (class 0 OID 0)
-- Dependencies: 439
-- Name: TABLE sent_surveys; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.sent_surveys TO ppatel;
GRANT SELECT ON TABLE fact.sent_surveys TO varshil;


--
-- TOC entry 6379 (class 0 OID 0)
-- Dependencies: 379
-- Name: TABLE timingsdatalake; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.timingsdatalake TO powerbi;
GRANT SELECT ON TABLE fact.timingsdatalake TO dvirani;
GRANT SELECT ON TABLE fact.timingsdatalake TO ppatel;
GRANT SELECT ON TABLE fact.timingsdatalake TO varshil;


--
-- TOC entry 6380 (class 0 OID 0)
-- Dependencies: 380
-- Name: TABLE transactionheader; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionheader TO powerbi;
GRANT SELECT ON TABLE fact.transactionheader TO dvirani;
GRANT SELECT ON TABLE fact.transactionheader TO ppatel;
GRANT SELECT ON TABLE fact.transactionheader TO varshil;


--
-- TOC entry 6381 (class 0 OID 0)
-- Dependencies: 395
-- Name: TABLE transactionheadertest; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionheadertest TO dvirani;
GRANT SELECT ON TABLE fact.transactionheadertest TO ppatel;
GRANT SELECT ON TABLE fact.transactionheadertest TO varshil;


--
-- TOC entry 6382 (class 0 OID 0)
-- Dependencies: 384
-- Name: TABLE transactionitem; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionitem TO powerbi;
GRANT SELECT ON TABLE fact.transactionitem TO dvirani;
GRANT SELECT ON TABLE fact.transactionitem TO ppatel;
GRANT SELECT ON TABLE fact.transactionitem TO varshil;


--
-- TOC entry 6383 (class 0 OID 0)
-- Dependencies: 381
-- Name: TABLE transactionpayment; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionpayment TO powerbi;
GRANT SELECT ON TABLE fact.transactionpayment TO dvirani;
GRANT SELECT ON TABLE fact.transactionpayment TO ppatel;
GRANT SELECT ON TABLE fact.transactionpayment TO varshil;


--
-- TOC entry 6384 (class 0 OID 0)
-- Dependencies: 411
-- Name: TABLE transactionrefunds; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionrefunds TO dvirani;
GRANT SELECT ON TABLE fact.transactionrefunds TO ppatel;
GRANT SELECT ON TABLE fact.transactionrefunds TO varshil;


--
-- TOC entry 6385 (class 0 OID 0)
-- Dependencies: 382
-- Name: TABLE userbehaviour; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour TO powerbi;
GRANT SELECT ON TABLE fact.userbehaviour TO dvirani;
GRANT SELECT ON TABLE fact.userbehaviour TO ppatel;
GRANT SELECT ON TABLE fact.userbehaviour TO varshil;


--
-- TOC entry 6386 (class 0 OID 0)
-- Dependencies: 422
-- Name: TABLE userbehaviour_reload; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour_reload TO ppatel;
GRANT SELECT ON TABLE fact.userbehaviour_reload TO varshil;


--
-- TOC entry 6387 (class 0 OID 0)
-- Dependencies: 389
-- Name: TABLE usercheckedin; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.usercheckedin TO powerbi;
GRANT SELECT ON TABLE fact.usercheckedin TO dvirani;
GRANT SELECT ON TABLE fact.usercheckedin TO ppatel;
GRANT SELECT ON TABLE fact.usercheckedin TO varshil;


--
-- TOC entry 6388 (class 0 OID 0)
-- Dependencies: 417
-- Name: TABLE vw_offer_analysis; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.vw_offer_analysis TO ppatel;
GRANT SELECT ON TABLE fact.vw_offer_analysis TO varshil;


--
-- TOC entry 6389 (class 0 OID 0)
-- Dependencies: 383
-- Name: TABLE watermarktable; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.watermarktable TO powerbi;
GRANT SELECT ON TABLE fact.watermarktable TO dvirani;
GRANT SELECT ON TABLE fact.watermarktable TO ppatel;
GRANT SELECT ON TABLE fact.watermarktable TO varshil;


--
-- TOC entry 6390 (class 0 OID 0)
-- Dependencies: 447
-- Name: TABLE item_modifiergroup_modifier_mapping; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.item_modifiergroup_modifier_mapping TO ppatel;
GRANT SELECT ON TABLE ml.item_modifiergroup_modifier_mapping TO varshil;


--
-- TOC entry 6391 (class 0 OID 0)
-- Dependencies: 450
-- Name: TABLE menu_entities; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.menu_entities TO ppatel;
GRANT SELECT ON TABLE ml.menu_entities TO varshil;


--
-- TOC entry 6392 (class 0 OID 0)
-- Dependencies: 449
-- Name: TABLE modifier_impressions; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.modifier_impressions TO ppatel;
GRANT SELECT ON TABLE ml.modifier_impressions TO varshil;


--
-- TOC entry 6393 (class 0 OID 0)
-- Dependencies: 448
-- Name: TABLE modifier_interactions; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.modifier_interactions TO ppatel;
GRANT SELECT ON TABLE ml.modifier_interactions TO varshil;


--
-- TOC entry 6394 (class 0 OID 0)
-- Dependencies: 445
-- Name: TABLE transactions; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.transactions TO ppatel;
GRANT SELECT ON TABLE ml.transactions TO varshil;


--
-- TOC entry 6395 (class 0 OID 0)
-- Dependencies: 446
-- Name: TABLE upsell_analysis; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.upsell_analysis TO ppatel;
GRANT SELECT ON TABLE ml.upsell_analysis TO varshil;


--
-- TOC entry 6396 (class 0 OID 0)
-- Dependencies: 444
-- Name: TABLE weather; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.weather TO ppatel;
GRANT SELECT ON TABLE ml.weather TO varshil;


--
-- TOC entry 6397 (class 0 OID 0)
-- Dependencies: 391
-- Name: TABLE report; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.report TO dvirani;
GRANT SELECT ON TABLE public.report TO ppatel;
GRANT SELECT ON TABLE public.report TO varshil;


--
-- TOC entry 6398 (class 0 OID 0)
-- Dependencies: 392
-- Name: TABLE reportschedule; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.reportschedule TO dvirani;
GRANT SELECT ON TABLE public.reportschedule TO ppatel;
GRANT SELECT ON TABLE public.reportschedule TO varshil;


--
-- TOC entry 6399 (class 0 OID 0)
-- Dependencies: 360
-- Name: TABLE schemaversions; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.schemaversions TO powerbi;
GRANT SELECT ON TABLE public.schemaversions TO dvirani;
GRANT SELECT ON TABLE public.schemaversions TO ppatel;
GRANT SELECT ON TABLE public.schemaversions TO varshil;


-- Completed on 2026-06-04 21:42:21

--
-- PostgreSQL database dump complete
--

\unrestrict zEgOtQk6a2doVlVlMsXHmBUOvIsHloN5QUziWNdrdMHoWTONwdIxn0Ja8a2dewd

