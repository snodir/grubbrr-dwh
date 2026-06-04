--
-- PostgreSQL database dump
--

\restrict AXlqme4dxmiMlkAeDcnh0WNCW66eUfOYgMdflMydquEh77M8eDTpXyhjkORon8N

-- Dumped from database version 16.9 (Ubuntu 16.9-1.pgdg20.04+1)
-- Dumped by pg_dump version 18.3

-- Started on 2026-06-04 21:53:58

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
-- TOC entry 64 (class 2615 OID 32802)
-- Name: dim; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA dim;


ALTER SCHEMA dim OWNER TO citus;

--
-- TOC entry 47 (class 2615 OID 3338276)
-- Name: etl; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA etl;


ALTER SCHEMA etl OWNER TO citus;

--
-- TOC entry 65 (class 2615 OID 32810)
-- Name: fact; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA fact;


ALTER SCHEMA fact OWNER TO citus;

--
-- TOC entry 76 (class 2615 OID 3042094)
-- Name: ml; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA ml;


ALTER SCHEMA ml OWNER TO citus;

--
-- TOC entry 62 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 6578 (class 0 OID 0)
-- Dependencies: 62
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 61 (class 2615 OID 420272)
-- Name: stg; Type: SCHEMA; Schema: -; Owner: citus
--

CREATE SCHEMA stg;


ALTER SCHEMA stg OWNER TO citus;

--
-- TOC entry 2310 (class 1247 OID 456209)
-- Name: reportorigin; Type: TYPE; Schema: public; Owner: citus
--

CREATE TYPE public.reportorigin AS ENUM (
    'Custom',
    'System'
);


ALTER TYPE public.reportorigin OWNER TO citus;

--
-- TOC entry 614 (class 1255 OID 3700924)
-- Name: array_to_text(jsonb); Type: FUNCTION; Schema: dim; Owner: citus
--

CREATE FUNCTION dim.array_to_text(a jsonb) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
    SELECT initcap(replace(replace(replace(a::text, '[', ''), ']', ''), '"', ''));
$$;


ALTER FUNCTION dim.array_to_text(a jsonb) OWNER TO citus;

--
-- TOC entry 1059 (class 1255 OID 3700925)
-- Name: is_valid_jsonb(text); Type: FUNCTION; Schema: dim; Owner: citus
--

CREATE FUNCTION dim.is_valid_jsonb(input text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE STRICT
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
-- TOC entry 860 (class 1255 OID 735591)
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
-- TOC entry 972 (class 1255 OID 3327439)
-- Name: usp_grubbrr_install_base_all_devices(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_grubbrr_install_base_all_devices()
    LANGUAGE plpgsql
    AS $$

BEGIN

TRUNCATE TABLE dim.vw_grubbrrinstallbase_all_devices;

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
INSERT INTO dim.vw_grubbrrinstallbase_all_devices
SELECT * FROM total
WHERE 1=1;
--AND location_status = 'Live'
--AND is_loc_active = True
--AND kiosk_mode = 'Live';
--AND is_kiosk_deleted = False
--AND is_test_kiosk = False
--AND is_test_mode_on = False;


END;
$$;


ALTER PROCEDURE dim.usp_grubbrr_install_base_all_devices() OWNER TO citus;

--
-- TOC entry 722 (class 1255 OID 2041188)
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
-- TOC entry 675 (class 1255 OID 3589004)
-- Name: usp_refresh_catalog(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_catalog()
    LANGUAGE plpgsql
    AS $$
BEGIN

    CREATE TEMP TABLE tmp_catalog ON COMMIT DROP AS
    SELECT DISTINCT ON (catalogid)
        catalogid,
        catalogname,
        organizationid,
        is_catalog_deleted,
        catalog_created_on,
        catalog_modified_on,
        gem_company_id,
        gem_location_id,
        is_sync_in_progress,
        is_standalone,
        is_master,
        is_ecm_enabled
    FROM stg.dim_catalog
    ORDER BY catalogid, catalog_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_catalog ON tmp_catalog (catalogid);
    ANALYZE tmp_catalog;

    -- INSERT net new
    INSERT INTO dim.catalog (
        catalogid,
        catalogname,
        organizationid,
        is_catalog_deleted,
        catalog_created_on,
        catalog_modified_on,
        gem_company_id,
        gem_location_id,
        is_sync_in_progress,
        is_standalone,
        is_master,
        is_ecm_enabled,
        sysinserttime
    )
    SELECT
        t.catalogid,
        t.catalogname,
        t.organizationid,
        t.is_catalog_deleted,
        t.catalog_created_on,
        t.catalog_modified_on,
        t.gem_company_id,
        t.gem_location_id,
        t.is_sync_in_progress,
        t.is_standalone,
        t.is_master,
        t.is_ecm_enabled,
        NOW()
    FROM tmp_catalog t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.catalog d
        WHERE d.catalogid = t.catalogid
    );

    -- UPDATE changed
    UPDATE dim.catalog d
    SET
        catalogname         = t.catalogname,
        organizationid      = t.organizationid,
        is_catalog_deleted  = t.is_catalog_deleted,
        catalog_created_on  = t.catalog_created_on,
        catalog_modified_on = t.catalog_modified_on,
        gem_company_id      = t.gem_company_id,
        gem_location_id     = t.gem_location_id,
        is_sync_in_progress = t.is_sync_in_progress,
        is_standalone       = t.is_standalone,
        is_master           = t.is_master,
        is_ecm_enabled      = t.is_ecm_enabled,
        sysupdatetime       = NOW()
    FROM tmp_catalog t
    WHERE d.catalogid = t.catalogid
    AND (
        d.catalogname         IS DISTINCT FROM t.catalogname         OR
        d.organizationid      IS DISTINCT FROM t.organizationid      OR
        d.is_catalog_deleted  IS DISTINCT FROM t.is_catalog_deleted  OR
        d.catalog_created_on  IS DISTINCT FROM t.catalog_created_on  OR
        d.catalog_modified_on IS DISTINCT FROM t.catalog_modified_on OR
        d.gem_company_id      IS DISTINCT FROM t.gem_company_id      OR
        d.gem_location_id     IS DISTINCT FROM t.gem_location_id     OR
        d.is_sync_in_progress IS DISTINCT FROM t.is_sync_in_progress OR
        d.is_standalone       IS DISTINCT FROM t.is_standalone       OR
        d.is_master           IS DISTINCT FROM t.is_master           OR
        d.is_ecm_enabled      IS DISTINCT FROM t.is_ecm_enabled
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_catalog() OWNER TO citus;

--
-- TOC entry 672 (class 1255 OID 3586056)
-- Name: usp_refresh_category_hierarchy(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_category_hierarchy()
    LANGUAGE plpgsql
    AS $$
BEGIN

    CREATE TEMP TABLE tmp_category_hierarchy ON COMMIT DROP AS
    SELECT DISTINCT ON (locationid, categoryid, menuitemid)
        organizationid,
        locationid,
        mapping_created_on,
        mapping_modified_on,
        is_mapping_active,
        is_mapping_deleted,
        catalogid,
        catalogname,
        catalog_created_on,
        catalog_modified_on,
        is_catalog_active,
        is_catalog_deleted,
        categoryid,
        categoryname,
        category_created_on,
        category_modified_on,
        is_category_active,
        is_category_deleted,
        menuitemid,
        entitytype,
        item_class_type,
        menuitemname,
        item_created_on,
        item_modified_on,
        is_item_active,
        is_item_deleted,
        syscosmosts
    FROM stg.dim_category_hierarchy
    ORDER BY locationid, categoryid, menuitemid, mapping_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_category_hierarchy ON tmp_category_hierarchy (locationid, categoryid, menuitemid);

    -- INSERT net new
    INSERT INTO dim.category_hierarchy (
        organizationid,
        locationid,
        mapping_created_on,
        mapping_modified_on,
        is_mapping_active,
        is_mapping_deleted,
        catalogid,
        catalogname,
        catalog_created_on,
        catalog_modified_on,
        is_catalog_active,
        is_catalog_deleted,
        categoryid,
        categoryname,
        category_created_on,
        category_modified_on,
        is_category_active,
        is_category_deleted,
        menuitemid,
        entitytype,
        item_class_type,
        menuitemname,
        item_created_on,
        item_modified_on,
        is_item_active,
        is_item_deleted,
        syscosmosts,
        sysinserttime
    )
    SELECT
        t.organizationid,
        t.locationid,
        t.mapping_created_on,
        t.mapping_modified_on,
        t.is_mapping_active,
        t.is_mapping_deleted,
        t.catalogid,
        t.catalogname,
        t.catalog_created_on,
        t.catalog_modified_on,
        t.is_catalog_active,
        t.is_catalog_deleted,
        t.categoryid,
        t.categoryname,
        t.category_created_on,
        t.category_modified_on,
        t.is_category_active,
        t.is_category_deleted,
        t.menuitemid,
        t.entitytype,
        t.item_class_type,
        t.menuitemname,
        t.item_created_on,
        t.item_modified_on,
        t.is_item_active,
        t.is_item_deleted,
        t.syscosmosts,
        NOW()
    FROM tmp_category_hierarchy t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.category_hierarchy d
        WHERE d.locationid  = t.locationid
        AND   d.categoryid  = t.categoryid
        AND   d.menuitemid  = t.menuitemid
    );

    -- UPDATE changed
    UPDATE dim.category_hierarchy d
    SET
        organizationid       = t.organizationid,
        mapping_created_on   = t.mapping_created_on,
        mapping_modified_on  = t.mapping_modified_on,
        is_mapping_active    = t.is_mapping_active,
        is_mapping_deleted   = t.is_mapping_deleted,
        catalogid            = t.catalogid,
        catalogname          = t.catalogname,
        catalog_created_on   = t.catalog_created_on,
        catalog_modified_on  = t.catalog_modified_on,
        is_catalog_active    = t.is_catalog_active,
        is_catalog_deleted   = t.is_catalog_deleted,
        categoryname         = t.categoryname,
        category_created_on  = t.category_created_on,
        category_modified_on = t.category_modified_on,
        is_category_active   = t.is_category_active,
        is_category_deleted  = t.is_category_deleted,
        entitytype           = t.entitytype,
        item_class_type      = t.item_class_type,
        menuitemname         = t.menuitemname,
        item_created_on      = t.item_created_on,
        item_modified_on     = t.item_modified_on,
        is_item_active       = t.is_item_active,
        is_item_deleted      = t.is_item_deleted,
        syscosmosts          = t.syscosmosts,
        sysupdatetime        = NOW()
    FROM tmp_category_hierarchy t
    WHERE d.locationid  = t.locationid
    AND   d.categoryid  = t.categoryid
    AND   d.menuitemid  = t.menuitemid
    AND (
        d.organizationid       IS DISTINCT FROM t.organizationid       OR
        d.mapping_created_on   IS DISTINCT FROM t.mapping_created_on   OR
        d.mapping_modified_on  IS DISTINCT FROM t.mapping_modified_on  OR
        d.is_mapping_active    IS DISTINCT FROM t.is_mapping_active    OR
        d.is_mapping_deleted   IS DISTINCT FROM t.is_mapping_deleted   OR
        d.catalogid            IS DISTINCT FROM t.catalogid            OR
        d.catalogname          IS DISTINCT FROM t.catalogname          OR
        d.catalog_created_on   IS DISTINCT FROM t.catalog_created_on   OR
        d.catalog_modified_on  IS DISTINCT FROM t.catalog_modified_on  OR
        d.is_catalog_active    IS DISTINCT FROM t.is_catalog_active    OR
        d.is_catalog_deleted   IS DISTINCT FROM t.is_catalog_deleted   OR
        d.categoryname         IS DISTINCT FROM t.categoryname         OR
        d.category_created_on  IS DISTINCT FROM t.category_created_on  OR
        d.category_modified_on IS DISTINCT FROM t.category_modified_on OR
        d.is_category_active   IS DISTINCT FROM t.is_category_active   OR
        d.is_category_deleted  IS DISTINCT FROM t.is_category_deleted  OR
        d.entitytype           IS DISTINCT FROM t.entitytype           OR
        d.item_class_type      IS DISTINCT FROM t.item_class_type      OR
        d.menuitemname         IS DISTINCT FROM t.menuitemname         OR
        d.item_created_on      IS DISTINCT FROM t.item_created_on      OR
        d.item_modified_on     IS DISTINCT FROM t.item_modified_on     OR
        d.is_item_active       IS DISTINCT FROM t.is_item_active       OR
        d.is_item_deleted      IS DISTINCT FROM t.is_item_deleted      OR
        d.syscosmosts          IS DISTINCT FROM t.syscosmosts
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_category_hierarchy() OWNER TO citus;

--
-- TOC entry 1378 (class 1255 OID 3631114)
-- Name: usp_refresh_dim_location_kiosk_details(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_dim_location_kiosk_details()
    LANGUAGE plpgsql
    AS $$
BEGIN

    ---------------------------------------------------------------------------
    -- STEP 1: UPSERT core kiosk rows from stg.dim_location_kiosks
    ---------------------------------------------------------------------------
    INSERT INTO dim.kioskdetails (
        id,
        locationid,
        devicetype,
        syncversion,
        kiosks,
        syscosmosts,
        sysinserttime
    )
    SELECT
        id,
        locationid,
        devicetype,
        syncversion,
        kiosks,
        syscosmosts,
        NOW()
    FROM stg.dim_location_kiosks
    ON CONFLICT (locationid) DO UPDATE SET
        id             = EXCLUDED.id,
        devicetype     = EXCLUDED.devicetype,
        syncversion    = EXCLUDED.syncversion,
        kiosks         = EXCLUDED.kiosks,
        syscosmosts    = EXCLUDED.syscosmosts,
        sysupdatetime  = NOW();

    ---------------------------------------------------------------------------
    -- STEP 2: UPDATE pos_provider from stg.dim_pos_provider
    ---------------------------------------------------------------------------
    WITH deduped AS (
        SELECT DISTINCT ON (locationid, pos_provider)
            locationid,
            CASE
                WHEN LOWER(pos_provider) LIKE 'pid-%'
                    THEN SUBSTRING(pos_provider FROM 5)
                ELSE pos_provider
            END AS pos_provider
        FROM stg.dim_pos_provider
        ORDER BY locationid, pos_provider, syscosmosts DESC
    ),
    aggregated AS (
        SELECT
            locationid,
            JSONB_AGG(pos_provider)::TEXT AS pos_provider
        FROM deduped
        GROUP BY locationid
    )
    UPDATE dim.kioskdetails d
    SET
        pos_provider  = a.pos_provider,
        sysupdatetime = NOW()
    FROM aggregated a
    WHERE d.locationid = a.locationid;

    ---------------------------------------------------------------------------
    -- STEP 3: UPDATE loyalty_provider from stg.dim_loyalty_configuration
    ---------------------------------------------------------------------------
    WITH deduped AS (
        SELECT DISTINCT ON (locationid, loyalty_provider)
            locationid,
            loyalty_provider
        FROM stg.dim_loyalty_configuration
        ORDER BY locationid, loyalty_provider, syscosmosts DESC
    ),
    aggregated AS (
        SELECT
            locationid,
            JSONB_AGG(loyalty_provider)::TEXT AS loyalty_provider
        FROM deduped
        GROUP BY locationid
    )
    UPDATE dim.kioskdetails d
    SET
        loyalty_provider = a.loyalty_provider,
        sysupdatetime    = NOW()
    FROM aggregated a
    WHERE d.locationid = a.locationid;

    ---------------------------------------------------------------------------
    -- STEP 4: UPDATE payment_provider from stg.dim_payment_provider
    ---------------------------------------------------------------------------
    WITH deduped AS (
        SELECT DISTINCT ON (locationid, payment_provider)
            locationid,
            CASE
                WHEN LOWER(payment_provider) LIKE 'payment-integration-%'
                    THEN SUBSTRING(payment_provider FROM 21)
                ELSE payment_provider
            END AS payment_provider
        FROM stg.dim_payment_provider
        ORDER BY locationid, payment_provider, syscosmosts DESC
    ),
    aggregated AS (
        SELECT
            locationid,
            JSONB_AGG(payment_provider)::TEXT AS payment_provider
        FROM deduped
        GROUP BY locationid
    )
    UPDATE dim.kioskdetails d
    SET
        payment_provider = a.payment_provider,
        sysupdatetime    = NOW()
    FROM aggregated a
    WHERE d.locationid = a.locationid;

    ---------------------------------------------------------------------------
    -- STEP 5: UPDATE kiosk config + feature flags from stg.dim_kiosk_config
    ---------------------------------------------------------------------------
    WITH latest AS (
        SELECT DISTINCT ON (locationid)
            locationid,
            scanners,
            item_special_request,
            legal_copy_enabled,
            ada_configuration,
            calculate_default_modifier_price,
            track_kiosk_user_behavior,
            loyalty_feature,
            pickup_flow,
            pos_auto_applied_discount,
            search_functionality_enabled,
            recent_orders_enabled,
            play_card_config,
            round_up_for_charity,
            calories_enabled,
            scan_and_go_enabled,
            age_verification,
            tips_settings,
            business_hours_config,
            order_types,
            localization,
            loyalty_display_settings,
            preorder_popup_enabled,
            preorder_popup_text,
            disclaimer_text,
            order_limit_config,
            menu_behavior_config,
            perform_pos_status_check
        FROM stg.dim_kiosk_config
        ORDER BY locationid, syscosmosts DESC
    )
    UPDATE dim.kioskdetails d
    SET
        scanners                         = l.scanners,
        item_special_request             = l.item_special_request,
        legal_copy_enabled               = l.legal_copy_enabled,
        ada_configuration                = l.ada_configuration,
        calculate_default_modifier_price = l.calculate_default_modifier_price,
        track_kiosk_user_behavior        = l.track_kiosk_user_behavior,
        loyalty_feature                  = l.loyalty_feature,
        pickup_flow                      = l.pickup_flow,
        pos_auto_applied_discount        = l.pos_auto_applied_discount,
        search_functionality_enabled     = l.search_functionality_enabled,
        recent_orders_enabled            = l.recent_orders_enabled,
        play_card_config                 = l.play_card_config,
        round_up_for_charity             = l.round_up_for_charity,
        calories_enabled                 = l.calories_enabled,
        scan_and_go_enabled              = l.scan_and_go_enabled,
        age_verification                 = l.age_verification,
        tips_settings                    = l.tips_settings,
        business_hours_config            = l.business_hours_config,
        order_types                      = l.order_types,
        localization                     = l.localization,
        loyalty_display_settings         = l.loyalty_display_settings,
        preorder_popup_enabled           = l.preorder_popup_enabled,
        preorder_popup_text              = l.preorder_popup_text,
        disclaimer_text                  = l.disclaimer_text,
        order_limit_config               = l.order_limit_config,
        menu_behavior_config             = l.menu_behavior_config,
        perform_pos_status_check         = l.perform_pos_status_check,
        sysupdatetime                    = NOW()
    FROM latest l
    WHERE d.locationid = l.locationid;

    ---------------------------------------------------------------------------
    -- STEP 6: UPDATE appearance fields from stg.dim_kiosk_appearance
    ---------------------------------------------------------------------------
    WITH latest AS (
        SELECT DISTINCT ON (locationid)
            locationid,
            kiosk_receipt_settings,
            kiosk_fonts,
            kiosk_appearance_text_overrides,
            kiosk_appearance_style_options
        FROM stg.dim_kiosk_appearance
        ORDER BY locationid, syscosmosts DESC
    )
    UPDATE dim.kioskdetails d
    SET
        kiosk_receipt_settings          = l.kiosk_receipt_settings,
        kiosk_fonts                     = l.kiosk_fonts,
        kiosk_appearance_text_overrides = l.kiosk_appearance_text_overrides,
        kiosk_appearance_style_options  = l.kiosk_appearance_style_options,
        sysupdatetime                   = NOW()
    FROM latest l
    WHERE d.locationid = l.locationid;

END;
$$;


ALTER PROCEDURE dim.usp_refresh_dim_location_kiosk_details() OWNER TO citus;

--
-- TOC entry 1263 (class 1255 OID 3601714)
-- Name: usp_refresh_element(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_element()
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- ── Step 1: extract distinct elements from insight events ──
    -- Mirrors ADF: sourceElement → parse2 → select3 → derivedColumn10 → filter1 → aggregate4
    --
    -- Empty string defaults mirror ADF derivedColumn10:
    --   elementidentifier1 = case(elementidentifier=='','None',elementidentifier)
    --   elementname1       = case(elementname=='','None',elementname)
    --
    -- filter1 mirror: WHERE sourceelementid IS NOT NULL
    --   (ADF: isNull(elementidentifier1)==false — excludes rows where
    --    JSON had no elementId field at all, distinct from empty string → 'None')

    CREATE TEMP TABLE tmp_element ON COMMIT DROP AS
    SELECT DISTINCT
        COALESCE(NULLIF(TRIM(data::jsonb->>'element'),   ''), 'None') AS elementname,
        COALESCE(NULLIF(TRIM(data::jsonb->>'elementId'), ''), 'None') AS sourceelementid
    FROM stg.silver_kiosk_events as ke
    WHERE ke.eventmodule      = 'kiosk'
      AND ke.eventcategory    = 'insight'
      AND ke.data             IS NOT NULL
      AND ke.data             <> ''
      -- Mirrors ADF filter1: exclude rows where elementId parsed to NULL
      AND (ke.data::jsonb)->>'elementId' IS NOT NULL;

    CREATE INDEX ix_tmp_element ON tmp_element (elementname, sourceelementid);
    ANALYZE tmp_element;


    -- ── Step 2: INSERT net-new elements ──────────────────────
    -- Mirrors ADF exists6 negate exists ON
    --   (elementidentifier1==sourceelementid && elementname1==elementname)

    INSERT INTO dim.element (elementid, sourceelementid, elementname, sysinserttime)
    SELECT
        nextval('dim.element_elementid_seq'),
        t.sourceelementid,
        t.elementname,
        NOW()::TIMESTAMP
    FROM tmp_element t
    WHERE NOT EXISTS (
        SELECT 1
        FROM dim.element e
        WHERE e.sourceelementid = t.sourceelementid
          AND e.elementname     = t.elementname
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_element() OWNER TO citus;

--
-- TOC entry 949 (class 1255 OID 3586035)
-- Name: usp_refresh_frequentcustomer(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_frequentcustomer()
    LANGUAGE plpgsql
    AS $$
BEGIN

    CREATE TEMP TABLE tmp_frequentcustomer ON COMMIT DROP AS
    SELECT DISTINCT ON (frequentcustomerid)
        frequentcustomerid,
        firstname,
        lastname,
        email,
        phone,
        source,
        organizationid,
        createddate,
        lastorderdate,
        ordercount,
        syscosmosts
    FROM stg.dim_frequentcustomer
    ORDER BY frequentcustomerid, syscosmosts DESC NULLS LAST;

    CREATE INDEX ix_tmp_frequentcustomer_id ON tmp_frequentcustomer (frequentcustomerid);

    -- INSERT net new
    INSERT INTO dim.frequentcustomer (
        customerkey,
        frequentcustomerid,
        firstname,
        lastname,
        email,
        phone,
        source,
        organizationid,
        createddate,
        lastorderdate,
        ordercount,
        amountspent,
        syscosmosts,
        sysinserttime
    )
    SELECT
        nextval('dim.frequentcustomer_customerkey_seq'),
        t.frequentcustomerid,
        t.firstname,
        t.lastname,
        t.email,
        t.phone,
        t.source,
        t.organizationid,
        t.createddate,
        t.lastorderdate,
        t.ordercount,
        0,
        t.syscosmosts,
        NOW()
    FROM tmp_frequentcustomer t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.frequentcustomer d
        WHERE d.frequentcustomerid = t.frequentcustomerid
    );

    -- UPDATE changed
    UPDATE dim.frequentcustomer d
    SET
        firstname      = t.firstname,
        lastname       = t.lastname,
        email          = t.email,
        phone          = t.phone,
        source         = t.source,
        organizationid = t.organizationid,
        createddate    = t.createddate,
        lastorderdate  = t.lastorderdate,
        ordercount     = t.ordercount,
        syscosmosts    = t.syscosmosts,
        sysupdatetime  = NOW()
    FROM tmp_frequentcustomer t
    WHERE d.frequentcustomerid = t.frequentcustomerid
    AND (
        d.firstname      IS DISTINCT FROM t.firstname      OR
        d.lastname       IS DISTINCT FROM t.lastname       OR
        d.email          IS DISTINCT FROM t.email          OR
        d.phone          IS DISTINCT FROM t.phone          OR
        d.source         IS DISTINCT FROM t.source         OR
        d.organizationid IS DISTINCT FROM t.organizationid OR
        d.createddate    IS DISTINCT FROM t.createddate    OR
        d.lastorderdate  IS DISTINCT FROM t.lastorderdate  OR
        d.ordercount     IS DISTINCT FROM t.ordercount     OR
        d.syscosmosts    IS DISTINCT FROM t.syscosmosts
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_frequentcustomer() OWNER TO citus;

--
-- TOC entry 1246 (class 1255 OID 3587573)
-- Name: usp_refresh_itemcategory(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_itemcategory()
    LANGUAGE plpgsql
    AS $$
BEGIN

    CREATE TEMP TABLE tmp_itemcategory ON COMMIT DROP AS
    SELECT DISTINCT ON (locationid, categoryid)
        locationid,
        categoryid,
        categoryname,
        is_category_active,
        catalogid,
        is_category_deleted,
        category_created_on,
        category_modified_on,
        is_alcoholic,
        number_of_items,
        number_of_sub_categories,
        number_of_item_variations,
        number_of_combos,
        number_of_combo_families
    FROM stg.dim_itemcategory
    ORDER BY locationid, categoryid, category_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_itemcategory ON tmp_itemcategory (locationid, categoryid);
    ANALYZE tmp_itemcategory;

    -- INSERT net new
    INSERT INTO dim.itemcategory (
        id,
        locationid,
        categoryid,
        categoryname,
        isactive,
        catalogid,
        is_category_deleted,
        category_created_on,
        category_modified_on,
        is_alcoholic,
        number_of_items,
        number_of_sub_categories,
        number_of_item_variations,
        number_of_combos,
        number_of_combo_families,
        sysinserttime
    )
    SELECT
        nextval('dim.itemcategory_id_seq'),
        t.locationid,
        t.categoryid,
        t.categoryname,
        t.is_category_active,
        t.catalogid,
        t.is_category_deleted,
        t.category_created_on,
        t.category_modified_on,
        t.is_alcoholic,
        t.number_of_items,
        t.number_of_sub_categories,
        t.number_of_item_variations,
        t.number_of_combos,
        t.number_of_combo_families,
        NOW()
    FROM tmp_itemcategory t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.itemcategory d
        WHERE d.locationid = t.locationid
        AND   d.categoryid = t.categoryid
    );

    -- UPDATE changed
    UPDATE dim.itemcategory d
    SET
        categoryname             = t.categoryname,
        isactive                 = t.is_category_active,
        catalogid                = t.catalogid,
        is_category_deleted      = t.is_category_deleted,
        category_created_on      = t.category_created_on,
        category_modified_on     = t.category_modified_on,
        is_alcoholic             = t.is_alcoholic,
        number_of_items          = t.number_of_items,
        number_of_sub_categories = t.number_of_sub_categories,
        number_of_item_variations = t.number_of_item_variations,
        number_of_combos         = t.number_of_combos,
        number_of_combo_families = t.number_of_combo_families,
        sysupdatetime            = NOW()
    FROM tmp_itemcategory t
    WHERE d.locationid = t.locationid
    AND   d.categoryid = t.categoryid
    AND (
        d.categoryname             IS DISTINCT FROM t.categoryname             OR
        d.isactive                 IS DISTINCT FROM t.is_category_active       OR
        d.catalogid                IS DISTINCT FROM t.catalogid                OR
        d.is_category_deleted      IS DISTINCT FROM t.is_category_deleted      OR
        d.category_created_on      IS DISTINCT FROM t.category_created_on      OR
        d.category_modified_on     IS DISTINCT FROM t.category_modified_on     OR
        d.is_alcoholic             IS DISTINCT FROM t.is_alcoholic             OR
        d.number_of_items          IS DISTINCT FROM t.number_of_items          OR
        d.number_of_sub_categories IS DISTINCT FROM t.number_of_sub_categories OR
        d.number_of_item_variations IS DISTINCT FROM t.number_of_item_variations OR
        d.number_of_combos         IS DISTINCT FROM t.number_of_combos         OR
        d.number_of_combo_families IS DISTINCT FROM t.number_of_combo_families
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_itemcategory() OWNER TO citus;

--
-- TOC entry 542 (class 1255 OID 3594941)
-- Name: usp_refresh_kiosk(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_kiosk()
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- ── Step 1: deduplicate staging ───────────────────────────
    CREATE TEMP TABLE tmp_kiosk ON COMMIT DROP AS
    SELECT DISTINCT ON (locationid, kioskid)
        locationid,
        kioskid,
        kioskname,
        appversion,
        istestkiosk,
        COALESCE(devicetype, 'kiosk') AS devicetype,
        devicecreatedon,
        devicedeletedon
    FROM stg.dim_kiosk
    ORDER BY locationid, kioskid, devicecreatedon DESC NULLS LAST;

    CREATE INDEX ix_tmp_kiosk ON tmp_kiosk (locationid, kioskid);
    ANALYZE tmp_kiosk;

    -- ── Step 2: INSERT net-new devices ────────────────────────
    -- serialnumber: no source mapping in this pipeline, left NULL
    INSERT INTO dim.kiosk (
        id,
        locationid,
        kioskid,
        kioskname,
        appversion,
        istestkiosk,
        devicetype,
        devicecreatedon,
        devicedeletedon,
        sysinserttime
    )
    SELECT
        nextval('dim.kiosk_id_seq'),
        t.locationid,
        t.kioskid,
        t.kioskname,
        t.appversion,
        t.istestkiosk,
        t.devicetype,
        t.devicecreatedon,
        t.devicedeletedon,
        NOW()
    FROM tmp_kiosk t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.kiosk d
        WHERE d.locationid = t.locationid
          AND d.kioskid    = t.kioskid
    );

    -- ── Step 3: UPDATE changed attributes ────────────────────
    -- serialnumber intentionally excluded – no source value.
    -- Only fires when at least one mutable column has changed.
    UPDATE dim.kiosk d
    SET
        kioskname       = t.kioskname,
        appversion      = t.appversion,
        istestkiosk     = t.istestkiosk,
        devicetype      = t.devicetype,
        devicecreatedon = t.devicecreatedon,
        devicedeletedon = t.devicedeletedon,
        sysupdatetime   = NOW()
    FROM tmp_kiosk t
    WHERE d.locationid = t.locationid
      AND d.kioskid    = t.kioskid
      AND (
          d.kioskname       IS DISTINCT FROM t.kioskname       OR
          d.appversion      IS DISTINCT FROM t.appversion      OR
          d.istestkiosk     IS DISTINCT FROM t.istestkiosk     OR
          d.devicetype      IS DISTINCT FROM t.devicetype      OR
          d.devicecreatedon IS DISTINCT FROM t.devicecreatedon OR
          d.devicedeletedon IS DISTINCT FROM t.devicedeletedon
      );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_kiosk() OWNER TO citus;

--
-- TOC entry 901 (class 1255 OID 3644492)
-- Name: usp_refresh_location_kiosk_details(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_location_kiosk_details()
    LANGUAGE plpgsql
    AS $$
BEGIN

    ---------------------------------------------------------------------------
    -- STEP 1: UPSERT core kiosk rows from stg.dim_location_kiosks
    ---------------------------------------------------------------------------
    INSERT INTO dim.kioskdetails (
        id,
        locationid,
        devicetype,
        syncversion,
        kiosks,
        syscosmosts,
        sysinserttime
    )
    SELECT
        id,
        locationid,
        devicetype,
        syncversion,
        kiosks,
        syscosmosts,
        NOW()
    FROM stg.dim_location_kiosks
    ON CONFLICT (locationid) DO UPDATE SET
        id             = EXCLUDED.id,
        devicetype     = EXCLUDED.devicetype,
        syncversion    = EXCLUDED.syncversion,
        kiosks         = EXCLUDED.kiosks,
        syscosmosts    = EXCLUDED.syscosmosts,
        sysupdatetime  = NOW();

    ---------------------------------------------------------------------------
    -- STEP 2: UPDATE pos_provider from stg.dim_pos_provider
    ---------------------------------------------------------------------------
    WITH deduped AS (
        SELECT DISTINCT ON (locationid, pos_provider)
            locationid,
            CASE
                WHEN LOWER(pos_provider) LIKE 'pid-%'
                    THEN SUBSTRING(pos_provider FROM 5)
                ELSE pos_provider
            END AS pos_provider
        FROM stg.dim_pos_provider
        ORDER BY locationid, pos_provider, syscosmosts DESC
    ),
    aggregated AS (
        SELECT
            locationid,
            JSONB_AGG(pos_provider)::TEXT AS pos_provider
        FROM deduped
        GROUP BY locationid
    )
    UPDATE dim.kioskdetails d
    SET
        pos_provider  = a.pos_provider,
        sysupdatetime = NOW()
    FROM aggregated a
    WHERE d.locationid = a.locationid;

    ---------------------------------------------------------------------------
    -- STEP 3: UPDATE loyalty_provider from stg.dim_loyalty_configuration
    ---------------------------------------------------------------------------
    WITH deduped AS (
        SELECT DISTINCT ON (locationid, loyalty_provider)
            locationid,
            loyalty_provider
        FROM stg.dim_loyalty_configuration
        ORDER BY locationid, loyalty_provider, syscosmosts DESC
    ),
    aggregated AS (
        SELECT
            locationid,
            JSONB_AGG(loyalty_provider)::TEXT AS loyalty_provider
        FROM deduped
        GROUP BY locationid
    )
    UPDATE dim.kioskdetails d
    SET
        loyalty_provider = a.loyalty_provider,
        sysupdatetime    = NOW()
    FROM aggregated a
    WHERE d.locationid = a.locationid;

    ---------------------------------------------------------------------------
    -- STEP 4: UPDATE payment_provider from stg.dim_payment_provider
    ---------------------------------------------------------------------------
    WITH deduped AS (
        SELECT DISTINCT ON (locationid, payment_provider)
            locationid,
            CASE
                WHEN LOWER(payment_provider) LIKE 'payment-integration-%'
                    THEN SUBSTRING(payment_provider FROM 21)
                ELSE payment_provider
            END AS payment_provider
        FROM stg.dim_payment_provider
        ORDER BY locationid, payment_provider, syscosmosts DESC
    ),
    aggregated AS (
        SELECT
            locationid,
            JSONB_AGG(payment_provider)::TEXT AS payment_provider
        FROM deduped
        GROUP BY locationid
    )
    UPDATE dim.kioskdetails d
    SET
        payment_provider = a.payment_provider,
        sysupdatetime    = NOW()
    FROM aggregated a
    WHERE d.locationid = a.locationid;

    ---------------------------------------------------------------------------
    -- STEP 5: UPDATE kiosk config + feature flags from stg.dim_kiosk_config
    ---------------------------------------------------------------------------
    WITH latest AS (
        SELECT DISTINCT ON (locationid)
            locationid,
            scanners,
            item_special_request,
            legal_copy_enabled,
            ada_configuration,
            calculate_default_modifier_price,
            track_kiosk_user_behavior,
            loyalty_feature,
            pickup_flow,
            pos_auto_applied_discount,
            search_functionality_enabled,
            recent_orders_enabled,
            play_card_config,
            round_up_for_charity,
            calories_enabled,
            scan_and_go_enabled,
            age_verification,
            tips_settings,
            business_hours_config,
            order_types,
            localization,
            loyalty_display_settings,
            preorder_popup_enabled,
            preorder_popup_text,
            disclaimer_text,
            order_limit_config,
            menu_behavior_config,
            perform_pos_status_check
        FROM stg.dim_kiosk_config
        ORDER BY locationid, syscosmosts DESC
    )
    UPDATE dim.kioskdetails d
    SET
        scanners                         = l.scanners,
        item_special_request             = l.item_special_request,
        legal_copy_enabled               = l.legal_copy_enabled,
        ada_configuration                = l.ada_configuration,
        calculate_default_modifier_price = l.calculate_default_modifier_price,
        track_kiosk_user_behavior        = l.track_kiosk_user_behavior,
        loyalty_feature                  = l.loyalty_feature,
        pickup_flow                      = l.pickup_flow,
        pos_auto_applied_discount        = l.pos_auto_applied_discount,
        search_functionality_enabled     = l.search_functionality_enabled,
        recent_orders_enabled            = l.recent_orders_enabled,
        play_card_config                 = l.play_card_config,
        round_up_for_charity             = l.round_up_for_charity,
        calories_enabled                 = l.calories_enabled,
        scan_and_go_enabled              = l.scan_and_go_enabled,
        age_verification                 = l.age_verification,
        tips_settings                    = l.tips_settings,
        business_hours_config            = l.business_hours_config,
        order_types                      = l.order_types,
        localization                     = l.localization,
        loyalty_display_settings         = l.loyalty_display_settings,
        preorder_popup_enabled           = l.preorder_popup_enabled,
        preorder_popup_text              = l.preorder_popup_text,
        disclaimer_text                  = l.disclaimer_text,
        order_limit_config               = l.order_limit_config,
        menu_behavior_config             = l.menu_behavior_config,
        perform_pos_status_check         = l.perform_pos_status_check,
        sysupdatetime                    = NOW()
    FROM latest l
    WHERE d.locationid = l.locationid;

    ---------------------------------------------------------------------------
    -- STEP 6: UPDATE appearance fields from stg.dim_kiosk_appearance
    ---------------------------------------------------------------------------
    WITH latest AS (
        SELECT DISTINCT ON (locationid)
            locationid,
            kiosk_receipt_settings,
            kiosk_fonts,
            kiosk_appearance_text_overrides,
            kiosk_appearance_style_options
        FROM stg.dim_kiosk_appearance
        ORDER BY locationid, syscosmosts DESC
    )
    UPDATE dim.kioskdetails d
    SET
        kiosk_receipt_settings          = l.kiosk_receipt_settings,
        kiosk_fonts                     = l.kiosk_fonts,
        kiosk_appearance_text_overrides = l.kiosk_appearance_text_overrides,
        kiosk_appearance_style_options  = l.kiosk_appearance_style_options,
        sysupdatetime                   = NOW()
    FROM latest l
    WHERE d.locationid = l.locationid;

END;
$$;


ALTER PROCEDURE dim.usp_refresh_location_kiosk_details() OWNER TO citus;

--
-- TOC entry 685 (class 1255 OID 3586043)
-- Name: usp_refresh_menuitem(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_menuitem()
    LANGUAGE plpgsql
    AS $$
BEGIN

    CREATE TEMP TABLE tmp_menuitem ON COMMIT DROP AS
    SELECT DISTINCT ON (menuitemid)
        menuitemid,
        menuitemname,
        entitytype,
        calories,
        protein,
        sugar,
        fat,
        is_alcoholic,
        is_vegetarian_item,
        is_vegan_item,
        has_allergen,
        item_class_type,
        is_active,
        is_deleted,
        gms_created_on,
        gms_modified_on,
        itemunitprice,
        price_changed_on,
        catalogid
    FROM stg.dim_menuitem
    ORDER BY menuitemid, gms_modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_menuitem_id ON tmp_menuitem (menuitemid);

    -- INSERT net new
    INSERT INTO dim.menuitem (
        id,
        menuitemid,
        menuitemname,
        guest,
        effective_date,
        entitytype,
        calories,
        protein,
        sugar,
        fat,
        is_alcoholic,
        is_vegetarian_item,
        is_vegan_item,
        has_allergen,
        item_class_type,
        is_active,
        is_deleted,
        gms_created_on,
        gms_modified_on,
        itemunitprice,
        price_changed_on,
        catalogid,
        sysinserttime
    )
    SELECT
        nextval('dim.menuitem_id_seq'),
        t.menuitemid,
        t.menuitemname,
        1,
        NULL,
        t.entitytype,
        t.calories,
        t.protein,
        t.sugar,
        t.fat,
        t.is_alcoholic,
        t.is_vegetarian_item,
        t.is_vegan_item,
        t.has_allergen,
        t.item_class_type,
        t.is_active,
        t.is_deleted,
        t.gms_created_on,
        t.gms_modified_on,
        t.itemunitprice,
        t.price_changed_on,
        t.catalogid,
        NOW()
    FROM tmp_menuitem t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.menuitem d
        WHERE d.menuitemid = t.menuitemid
    );

    -- UPDATE changed
    UPDATE dim.menuitem d
    SET
        menuitemname       = t.menuitemname,
        entitytype         = t.entitytype,
        calories           = t.calories,
        protein            = t.protein,
        sugar              = t.sugar,
        fat                = t.fat,
        is_alcoholic       = t.is_alcoholic,
        is_vegetarian_item = t.is_vegetarian_item,
        is_vegan_item      = t.is_vegan_item,
        has_allergen       = t.has_allergen,
        item_class_type    = t.item_class_type,
        is_active          = t.is_active,
        is_deleted         = t.is_deleted,
        gms_created_on     = t.gms_created_on,
        gms_modified_on    = t.gms_modified_on,
        itemunitprice      = t.itemunitprice,
        price_changed_on   = t.price_changed_on,
        catalogid          = t.catalogid,
        sysupdatetime      = NOW()
    FROM tmp_menuitem t
    WHERE d.menuitemid = t.menuitemid
    AND (
        d.menuitemname       IS DISTINCT FROM t.menuitemname       OR
        d.entitytype         IS DISTINCT FROM t.entitytype         OR
        d.calories           IS DISTINCT FROM t.calories           OR
        d.protein            IS DISTINCT FROM t.protein            OR
        d.sugar              IS DISTINCT FROM t.sugar              OR
        d.fat                IS DISTINCT FROM t.fat                OR
        d.is_alcoholic       IS DISTINCT FROM t.is_alcoholic       OR
        d.is_vegetarian_item IS DISTINCT FROM t.is_vegetarian_item OR
        d.is_vegan_item      IS DISTINCT FROM t.is_vegan_item      OR
        d.has_allergen       IS DISTINCT FROM t.has_allergen       OR
        d.item_class_type    IS DISTINCT FROM t.item_class_type    OR
        d.is_active          IS DISTINCT FROM t.is_active          OR
        d.is_deleted         IS DISTINCT FROM t.is_deleted         OR
        d.gms_created_on     IS DISTINCT FROM t.gms_created_on     OR
        d.gms_modified_on    IS DISTINCT FROM t.gms_modified_on    OR
        d.itemunitprice      IS DISTINCT FROM t.itemunitprice      OR
        d.price_changed_on   IS DISTINCT FROM t.price_changed_on   OR
        d.catalogid          IS DISTINCT FROM t.catalogid
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_menuitem() OWNER TO citus;

--
-- TOC entry 902 (class 1255 OID 3586069)
-- Name: usp_refresh_modifier(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_modifier()
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- -------------------------------------------------------
    -- Step 1: Deduplicate stg into a temp table
    -- -------------------------------------------------------
    CREATE TEMP TABLE tmp_modifier ON COMMIT DROP AS
    SELECT DISTINCT ON (modifierid)
        modifierid,
        catalogid,
        modifiername,
        min_quantity,
        max_quantity,
        allow_quantity_increment,
        increment_step,
        calories,
        calories_text,
        is_modifier_active,
        is_modifier_deleted,
        modifier_created_on,
        modifier_modified_on,
        is_modifier_default,
        modifier_default_quantity,
        is_invisible,
        classification,
        price,
        price_changed_on
    FROM stg.dim_modifier
    ORDER BY modifierid, modifier_modified_on DESC NULLS LAST;

    -- Index on temp table to speed up JOIN in steps below
    CREATE INDEX ix_tmp_modifier_modifierid ON tmp_modifier (modifierid);

    -- -------------------------------------------------------
    -- Step 2: INSERT net new records only
    -- -------------------------------------------------------
    INSERT INTO dim.modifier (
        modifierid,
        catalogid,
        modifiername,
        min_quantity,
        max_quantity,
        allow_quantity_increment,
        increment_step,
        calories,
        calories_text,
        is_modifier_active,
        is_modifier_deleted,
        modifier_created_on,
        modifier_modified_on,
        is_modifier_default,
        modifier_default_quantity,
        is_invisible,
        classification,
        price,
        price_changed_on,
        sysinserttime
    )
    SELECT
        t.modifierid,
        t.catalogid,
        t.modifiername,
        t.min_quantity,
        t.max_quantity,
        t.allow_quantity_increment,
        t.increment_step,
        t.calories,
        t.calories_text,
        t.is_modifier_active,
        t.is_modifier_deleted,
        t.modifier_created_on,
        t.modifier_modified_on,
        t.is_modifier_default,
        t.modifier_default_quantity,
        t.is_invisible,
        t.classification,
        t.price,
        t.price_changed_on,
        NOW()
    FROM tmp_modifier t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.modifier d
        WHERE d.modifierid = t.modifierid
    );

    -- -------------------------------------------------------
    -- Step 3: UPDATE only changed records
    -- -------------------------------------------------------
    UPDATE dim.modifier d
    SET
        catalogid                = t.catalogid,
        modifiername             = t.modifiername,
        min_quantity             = t.min_quantity,
        max_quantity             = t.max_quantity,
        allow_quantity_increment = t.allow_quantity_increment,
        increment_step           = t.increment_step,
        calories                 = t.calories,
        calories_text            = t.calories_text,
        is_modifier_active       = t.is_modifier_active,
        is_modifier_deleted      = t.is_modifier_deleted,
        modifier_created_on      = t.modifier_created_on,
        modifier_modified_on     = t.modifier_modified_on,
        is_modifier_default      = t.is_modifier_default,
        modifier_default_quantity = t.modifier_default_quantity,
        is_invisible             = t.is_invisible,
        classification           = t.classification,
        price                    = t.price,
        price_changed_on         = t.price_changed_on,
        sysupdatetime            = NOW()
    FROM tmp_modifier t
    WHERE d.modifierid = t.modifierid
    AND (
        d.catalogid                IS DISTINCT FROM t.catalogid                OR
        d.modifiername             IS DISTINCT FROM t.modifiername             OR
        d.min_quantity             IS DISTINCT FROM t.min_quantity             OR
        d.max_quantity             IS DISTINCT FROM t.max_quantity             OR
        d.allow_quantity_increment IS DISTINCT FROM t.allow_quantity_increment OR
        d.increment_step           IS DISTINCT FROM t.increment_step           OR
        d.calories                 IS DISTINCT FROM t.calories                 OR
        d.calories_text            IS DISTINCT FROM t.calories_text            OR
        d.is_modifier_active       IS DISTINCT FROM t.is_modifier_active       OR
        d.is_modifier_deleted      IS DISTINCT FROM t.is_modifier_deleted      OR
        d.modifier_created_on      IS DISTINCT FROM t.modifier_created_on      OR
        d.modifier_modified_on     IS DISTINCT FROM t.modifier_modified_on     OR
        d.is_modifier_default      IS DISTINCT FROM t.is_modifier_default      OR
        d.modifier_default_quantity IS DISTINCT FROM t.modifier_default_quantity OR
        d.is_invisible             IS DISTINCT FROM t.is_invisible             OR
        d.classification           IS DISTINCT FROM t.classification           OR
        d.price                    IS DISTINCT FROM t.price                    OR
        d.price_changed_on         IS DISTINCT FROM t.price_changed_on
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_modifier() OWNER TO citus;

--
-- TOC entry 547 (class 1255 OID 3586077)
-- Name: usp_refresh_modifiergroup(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_modifiergroup()
    LANGUAGE plpgsql
    AS $$
BEGIN

    CREATE TEMP TABLE tmp_modifier_group ON COMMIT DROP AS
    SELECT DISTINCT ON (modifiergroupid)
        modifiergroupid,
        modifiergroupname,
        catalogid,
        max_selection,
        min_selection,
        free_count,
        pos_linked_entity_id,
        is_active,
        is_deleted,
        created_on,
        modified_on,
        negative_modifier_behavior,
        created_by,
        modified_by,
        max_aggregate_count,
        min_aggregate_count,
        increment_step,
        slider_mode,
        slider_mode_modifier
    FROM stg.dim_modifiergroup
    ORDER BY modifiergroupid, modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_modifier_group_id ON tmp_modifier_group (modifiergroupid);

    -- INSERT net new
    INSERT INTO dim.modifier_group (
        modifiergroupid,
        modifiergroupname,
        catalogid,
        max_selection,
        min_selection,
        free_count,
        pos_linked_entity_id,
        is_active,
        is_deleted,
        created_on,
        modified_on,
        negative_modifier_behavior,
        created_by,
        modified_by,
        max_aggregate_count,
        min_aggregate_count,
        increment_step,
        slider_mode,
        slider_mode_modifier,
        sysinserttime
    )
    SELECT
        t.modifiergroupid,
        t.modifiergroupname,
        t.catalogid,
        t.max_selection,
        t.min_selection,
        t.free_count,
        t.pos_linked_entity_id,
        t.is_active,
        t.is_deleted,
        t.created_on,
        t.modified_on,
        t.negative_modifier_behavior,
        t.created_by,
        t.modified_by,
        t.max_aggregate_count,
        t.min_aggregate_count,
        t.increment_step,
        t.slider_mode,
        t.slider_mode_modifier,
        NOW()
    FROM tmp_modifier_group t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.modifier_group d
        WHERE d.modifiergroupid = t.modifiergroupid
    );

    -- UPDATE changed
    UPDATE dim.modifier_group d
    SET
        modifiergroupname          = t.modifiergroupname,
        catalogid                  = t.catalogid,
        max_selection              = t.max_selection,
        min_selection              = t.min_selection,
        free_count                 = t.free_count,
        pos_linked_entity_id       = t.pos_linked_entity_id,
        is_active                  = t.is_active,
        is_deleted                 = t.is_deleted,
        created_on                 = t.created_on,
        modified_on                = t.modified_on,
        negative_modifier_behavior = t.negative_modifier_behavior,
        created_by                 = t.created_by,
        modified_by                = t.modified_by,
        max_aggregate_count        = t.max_aggregate_count,
        min_aggregate_count        = t.min_aggregate_count,
        increment_step             = t.increment_step,
        slider_mode                = t.slider_mode,
        slider_mode_modifier       = t.slider_mode_modifier,
        sysupdatetime              = NOW()
    FROM tmp_modifier_group t
    WHERE d.modifiergroupid = t.modifiergroupid
    AND (
        d.modifiergroupname          IS DISTINCT FROM t.modifiergroupname          OR
        d.catalogid                  IS DISTINCT FROM t.catalogid                  OR
        d.max_selection              IS DISTINCT FROM t.max_selection              OR
        d.min_selection              IS DISTINCT FROM t.min_selection              OR
        d.free_count                 IS DISTINCT FROM t.free_count                 OR
        d.pos_linked_entity_id       IS DISTINCT FROM t.pos_linked_entity_id       OR
        d.is_active                  IS DISTINCT FROM t.is_active                  OR
        d.is_deleted                 IS DISTINCT FROM t.is_deleted                 OR
        d.created_on                 IS DISTINCT FROM t.created_on                 OR
        d.modified_on                IS DISTINCT FROM t.modified_on                OR
        d.negative_modifier_behavior IS DISTINCT FROM t.negative_modifier_behavior OR
        d.created_by                 IS DISTINCT FROM t.created_by                 OR
        d.modified_by                IS DISTINCT FROM t.modified_by                OR
        d.max_aggregate_count        IS DISTINCT FROM t.max_aggregate_count        OR
        d.min_aggregate_count        IS DISTINCT FROM t.min_aggregate_count        OR
        d.increment_step             IS DISTINCT FROM t.increment_step             OR
        d.slider_mode                IS DISTINCT FROM t.slider_mode                OR
        d.slider_mode_modifier       IS DISTINCT FROM t.slider_mode_modifier
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_modifiergroup() OWNER TO citus;

--
-- TOC entry 1212 (class 1255 OID 3587402)
-- Name: usp_refresh_modifiergroup_modifier_mapping(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_modifiergroup_modifier_mapping()
    LANGUAGE plpgsql
    AS $$
BEGIN

    CREATE TEMP TABLE tmp_modifier_group ON COMMIT DROP AS
    SELECT DISTINCT ON (modifiergroupid)
        modifiergroupid,
        modifiergroupname,
        catalogid,
        max_selection,
        min_selection,
        free_count,
        pos_linked_entity_id,
        is_active,
        is_deleted,
        created_on,
        modified_on,
        negative_modifier_behavior,
        created_by,
        modified_by,
        max_aggregate_count,
        min_aggregate_count,
        increment_step,
        slider_mode,
        slider_mode_modifier
    FROM stg.dim_modifiergroup
    ORDER BY modifiergroupid, modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_modifier_group_id ON tmp_modifier_group (modifiergroupid);

    -- INSERT net new
    INSERT INTO dim.modifier_group (
        modifiergroupid,
        modifiergroupname,
        catalogid,
        max_selection,
        min_selection,
        free_count,
        pos_linked_entity_id,
        is_active,
        is_deleted,
        created_on,
        modified_on,
        negative_modifier_behavior,
        created_by,
        modified_by,
        max_aggregate_count,
        min_aggregate_count,
        increment_step,
        slider_mode,
        slider_mode_modifier,
        sysinserttime
    )
    SELECT
        t.modifiergroupid,
        t.modifiergroupname,
        t.catalogid,
        t.max_selection,
        t.min_selection,
        t.free_count,
        t.pos_linked_entity_id,
        t.is_active,
        t.is_deleted,
        t.created_on,
        t.modified_on,
        t.negative_modifier_behavior,
        t.created_by,
        t.modified_by,
        t.max_aggregate_count,
        t.min_aggregate_count,
        t.increment_step,
        t.slider_mode,
        t.slider_mode_modifier,
        NOW()
    FROM tmp_modifier_group t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.modifier_group d
        WHERE d.modifiergroupid = t.modifiergroupid
    );

    -- UPDATE changed
    UPDATE dim.modifier_group d
    SET
        modifiergroupname          = t.modifiergroupname,
        catalogid                  = t.catalogid,
        max_selection              = t.max_selection,
        min_selection              = t.min_selection,
        free_count                 = t.free_count,
        pos_linked_entity_id       = t.pos_linked_entity_id,
        is_active                  = t.is_active,
        is_deleted                 = t.is_deleted,
        created_on                 = t.created_on,
        modified_on                = t.modified_on,
        negative_modifier_behavior = t.negative_modifier_behavior,
        created_by                 = t.created_by,
        modified_by                = t.modified_by,
        max_aggregate_count        = t.max_aggregate_count,
        min_aggregate_count        = t.min_aggregate_count,
        increment_step             = t.increment_step,
        slider_mode                = t.slider_mode,
        slider_mode_modifier       = t.slider_mode_modifier,
        sysupdatetime              = NOW()
    FROM tmp_modifier_group t
    WHERE d.modifiergroupid = t.modifiergroupid
    AND (
        d.modifiergroupname          IS DISTINCT FROM t.modifiergroupname          OR
        d.catalogid                  IS DISTINCT FROM t.catalogid                  OR
        d.max_selection              IS DISTINCT FROM t.max_selection              OR
        d.min_selection              IS DISTINCT FROM t.min_selection              OR
        d.free_count                 IS DISTINCT FROM t.free_count                 OR
        d.pos_linked_entity_id       IS DISTINCT FROM t.pos_linked_entity_id       OR
        d.is_active                  IS DISTINCT FROM t.is_active                  OR
        d.is_deleted                 IS DISTINCT FROM t.is_deleted                 OR
        d.created_on                 IS DISTINCT FROM t.created_on                 OR
        d.modified_on                IS DISTINCT FROM t.modified_on                OR
        d.negative_modifier_behavior IS DISTINCT FROM t.negative_modifier_behavior OR
        d.created_by                 IS DISTINCT FROM t.created_by                 OR
        d.modified_by                IS DISTINCT FROM t.modified_by                OR
        d.max_aggregate_count        IS DISTINCT FROM t.max_aggregate_count        OR
        d.min_aggregate_count        IS DISTINCT FROM t.min_aggregate_count        OR
        d.increment_step             IS DISTINCT FROM t.increment_step             OR
        d.slider_mode                IS DISTINCT FROM t.slider_mode                OR
        d.slider_mode_modifier       IS DISTINCT FROM t.slider_mode_modifier
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_modifiergroup_modifier_mapping() OWNER TO citus;

--
-- TOC entry 1277 (class 1255 OID 3608696)
-- Name: usp_refresh_occasionsurvey(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_occasionsurvey()
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- ── Step 1: deduplicate staging ───────────────────────────
    CREATE TEMP TABLE tmp_occasionsurvey ON COMMIT DROP AS
    SELECT DISTINCT ON (organizationid, surveyid)
        organizationid,
        surveyid,
        surveyname,
        surveytype,
        question_type,
        selection_type,
        survey_status,
        is_deleted,
        created_on,
        modified_on
    FROM stg.dim_occasionsurvey
    ORDER BY organizationid, surveyid, modified_on DESC NULLS LAST;

    CREATE INDEX ix_tmp_occasionsurvey
        ON tmp_occasionsurvey (organizationid, surveyid);
    ANALYZE tmp_occasionsurvey;

    -- ── Step 2: INSERT net-new surveys ────────────────────────
    INSERT INTO dim.occasionsurvey (
        surveykey,
        organizationid,
        surveyid,
        surveyname,
        surveytype,
        question_type,
        selection_type,
        survey_status,
        is_deleted,
        created_on,
        modified_on,
        sysinserttime
    )
    SELECT
        nextval('dim.occasionsurvey_surveykey_seq'),
        t.organizationid,
        t.surveyid,
        t.surveyname,
        t.surveytype,
        t.question_type,
        t.selection_type,
        t.survey_status,
        t.is_deleted,
        t.created_on,
        t.modified_on,
        NOW()
    FROM tmp_occasionsurvey t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.occasionsurvey d
        WHERE d.organizationid = t.organizationid
          AND d.surveyid       = t.surveyid
    );

    -- ── Step 3: UPDATE changed attributes ────────────────────
    -- Only fires when at least one mutable column has changed.
    UPDATE dim.occasionsurvey d
    SET
        surveyname     = t.surveyname,
        surveytype     = t.surveytype,
        question_type  = t.question_type,
        selection_type = t.selection_type,
        survey_status  = t.survey_status,
        is_deleted     = t.is_deleted,
        created_on     = t.created_on,
        modified_on    = t.modified_on,
        sysupdatetime  = NOW()
    FROM tmp_occasionsurvey t
    WHERE d.organizationid = t.organizationid
      AND d.surveyid       = t.surveyid
      AND (
          d.surveyname     IS DISTINCT FROM t.surveyname     OR
          d.surveytype     IS DISTINCT FROM t.surveytype     OR
          d.question_type  IS DISTINCT FROM t.question_type  OR
          d.selection_type IS DISTINCT FROM t.selection_type OR
          d.survey_status  IS DISTINCT FROM t.survey_status  OR
          d.is_deleted     IS DISTINCT FROM t.is_deleted     OR
          d.created_on     IS DISTINCT FROM t.created_on     OR
          d.modified_on    IS DISTINCT FROM t.modified_on
      );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_occasionsurvey() OWNER TO citus;

--
-- TOC entry 1372 (class 1255 OID 3598986)
-- Name: usp_refresh_ordertype(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_ordertype()
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- ── Step 1: deduplicate source ────────────────────────────
    -- Derives dimension data from transaction history.
    -- ordertypeid fallback: if blank/NULL → fall back to order_type_label
    --   mirrors ADF: case(ordertypeid=='' || isNull(ordertypeid), ordertypelabel, ordertypeid)
    -- Filters replicated from ADF CosmosDB source query:
    --   • kioskid > ''                    (non-empty kiosk)
    --   • is_test_order = false OR NULL   (exclude test orders)
    -- Rows where both ordertype and order_type_label are blank carry
    -- no useful dimension value and are excluded.
    -- DISTINCT ON picks the row with the highest CosmosDB source timestamp
    -- per natural key (syscosmosts bigint – more reliable than ETL load time).

    CREATE TEMP TABLE tmp_ordertype ON COMMIT DROP AS
    SELECT DISTINCT ON (locationid, kioskid, ordertypeid)
        locationid,
        kioskid,
        COALESCE(NULLIF(TRIM(ordertype), ''), order_type_label)      AS ordertypeid,
        COALESCE(NULLIF(TRIM(order_type_label), ''), ordertype)      AS ordertypelabel
    FROM stg.silver_transaction_header
    WHERE (is_test_order = FALSE OR is_test_order IS NULL)
      AND COALESCE(NULLIF(TRIM(ordertype), ''), NULLIF(TRIM(order_type_label), '')) IS NOT NULL
    ORDER BY
        locationid,
        kioskid,
        COALESCE(NULLIF(TRIM(ordertype), ''), order_type_label),
        syscosmosts DESC NULLS LAST;

    CREATE INDEX ix_tmp_ordertype
        ON tmp_ordertype (locationid, kioskid, ordertypeid);
    ANALYZE tmp_ordertype;


    -- ── Step 2: INSERT net-new order types ───────────────────

    INSERT INTO dim.ordertype (
        id,
        locationid,
        kioskid,
        ordertypeid,
        ordertypelabel,
        sysinserttime
    )
    SELECT
        nextval('dim.ordertype_id_seq'),
        t.locationid,
        t.kioskid,
        t.ordertypeid,
        t.ordertypelabel,
        NOW()::TIMESTAMP
    FROM tmp_ordertype t
    WHERE NOT EXISTS (
        SELECT 1
        FROM dim.ordertype d
        WHERE d.locationid  = t.locationid
          AND d.kioskid     = t.kioskid
          AND d.ordertypeid = t.ordertypeid
    );


    -- ── Step 3: UPDATE changed label ─────────────────────────
    -- ordertypelabel is the only mutable attribute.
    -- IS DISTINCT FROM guard avoids touching unchanged rows.

    UPDATE dim.ordertype d
    SET
        ordertypelabel = t.ordertypelabel,
        sysupdatetime  = NOW()::TIMESTAMP
    FROM tmp_ordertype t
    WHERE d.locationid   = t.locationid
      AND d.kioskid      = t.kioskid
      AND d.ordertypeid  = t.ordertypeid
      AND d.ordertypelabel IS DISTINCT FROM t.ordertypelabel;

END;
$$;


ALTER PROCEDURE dim.usp_refresh_ordertype() OWNER TO citus;

--
-- TOC entry 794 (class 1255 OID 3644494)
-- Name: usp_refresh_organization(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_organization()
    LANGUAGE plpgsql
    AS $$
BEGIN

    INSERT INTO dim.organization (
        id,
        name,
        address1,
        address2,
        city,
        state,
        zipcode,
        country,
        organizationtype,
        status,
        phonenumber,
        email,
        isdeleted,
        createdon,
        createdby,
        modifiedon,
        modifiedby,
        active,
        timezone,
        coordinates,
        dayofweek,
        hour,
        minutes,
        roundupforcharity,
        is_ecm_enabled,
        is_cep_enabled,
        is_concessionaire_enabled,
        is_smart_upsells_enabled,
        is_feedback_survey_enabled,
        is_digital_menu_board_enabled,
        is_digital_menu_default_format_enabled,
        cep_subscriptions,
        sysinserttime
    )
    SELECT
        o.id,
        o.name,
        o.address1,
        o.address2,
        o.city,
        o.state,
        o.zipcode,
        o.country,
        o.organizationtype,
        o.status,
        o.phonenumber,
        o.email,
        o.isdeleted,
        o.createdon,
        o.createdby,
        o.modifiedon,
        o.modifiedby,
        o.active,
        o.timezone,
        o.coordinates,
        o.dayofweek,
        o.hour,
        o.minutes,
        k.round_up_for_charity      AS roundupforcharity,
        o.is_ecm_enabled,
        o.is_cep_enabled,
        o.is_concessionaire_enabled,
        o.is_smart_upsells_enabled,
        o.is_feedback_survey_enabled,
        o.is_digital_menu_board_enabled,
        o.is_digital_menu_default_format_enabled,
        c.cep_subscriptions,
        NOW()
    FROM stg.dim_organization o
    LEFT JOIN dim.kioskdetails k        ON o.id = k.locationid
    LEFT JOIN stg.dim_cep_subscriptions c ON o.id = c.id
    ON CONFLICT (id) DO UPDATE SET
        name                                   = EXCLUDED.name,
        address1                               = EXCLUDED.address1,
        address2                               = EXCLUDED.address2,
        city                                   = EXCLUDED.city,
        state                                  = EXCLUDED.state,
        zipcode                                = EXCLUDED.zipcode,
        country                                = EXCLUDED.country,
        organizationtype                       = EXCLUDED.organizationtype,
        status                                 = EXCLUDED.status,
        phonenumber                            = EXCLUDED.phonenumber,
        email                                  = EXCLUDED.email,
        isdeleted                              = EXCLUDED.isdeleted,
        createdon                              = EXCLUDED.createdon,
        createdby                              = EXCLUDED.createdby,
        modifiedon                             = EXCLUDED.modifiedon,
        modifiedby                             = EXCLUDED.modifiedby,
        active                                 = EXCLUDED.active,
        timezone                               = EXCLUDED.timezone,
        coordinates                            = EXCLUDED.coordinates,
        dayofweek                              = EXCLUDED.dayofweek,
        hour                                   = EXCLUDED.hour,
        minutes                                = EXCLUDED.minutes,
        roundupforcharity                      = EXCLUDED.roundupforcharity,
        is_ecm_enabled                         = EXCLUDED.is_ecm_enabled,
        is_cep_enabled                         = EXCLUDED.is_cep_enabled,
        is_concessionaire_enabled              = EXCLUDED.is_concessionaire_enabled,
        is_smart_upsells_enabled               = EXCLUDED.is_smart_upsells_enabled,
        is_feedback_survey_enabled             = EXCLUDED.is_feedback_survey_enabled,
        is_digital_menu_board_enabled          = EXCLUDED.is_digital_menu_board_enabled,
        is_digital_menu_default_format_enabled = EXCLUDED.is_digital_menu_default_format_enabled,
        cep_subscriptions                      = EXCLUDED.cep_subscriptions,
        sysupdatetime                          = NOW();

END;
$$;


ALTER PROCEDURE dim.usp_refresh_organization() OWNER TO citus;

--
-- TOC entry 1524 (class 1255 OID 3605488)
-- Name: usp_refresh_organizationlocation(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_organizationlocation()
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- ── Step 1: deduplicate staging ───────────────────────────
    CREATE TEMP TABLE tmp_organizationlocation ON COMMIT DROP AS
    SELECT DISTINCT ON (organizationid, locationid)
        organizationid,
        organizationname,
        locationid,
        locationname,
        organizationtype
        -- roundupforcharity excluded: fully derived in Step 4
        --                             from dim.organization, not from staging
    FROM stg.dim_organizationlocation
    ORDER BY organizationid, locationid, sysinserttime DESC NULLS LAST;

    CREATE INDEX ix_tmp_organizationlocation
        ON tmp_organizationlocation (organizationid, locationid);
    ANALYZE tmp_organizationlocation;

    -- ── Step 2: INSERT net-new org-location mappings ──────────
    INSERT INTO dim.organizationlocation (
        organizationid,
        organizationname,
        locationid,
        locationname,
        organizationtype,
        sysinserttime
        -- roundupforcharity: will be populated by Step 4
    )
    SELECT
        t.organizationid,
        t.organizationname,
        t.locationid,
        t.locationname,
        t.organizationtype,
        NOW()
    FROM tmp_organizationlocation t
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.organizationlocation d
        WHERE d.organizationid = t.organizationid
          AND d.locationid     = t.locationid
    );

    -- ── Step 3: UPDATE changed attributes ────────────────────
    -- roundupforcharity intentionally excluded – owned by Step 4.
    -- Only fires when at least one mutable column has changed.
    UPDATE dim.organizationlocation d
    SET
        organizationname = t.organizationname,
        locationname     = t.locationname,
        organizationtype = t.organizationtype,
        sysupdatetime    = NOW()
    FROM tmp_organizationlocation t
    WHERE d.organizationid = t.organizationid
      AND d.locationid     = t.locationid
      AND (
          d.organizationname IS DISTINCT FROM t.organizationname OR
          d.locationname     IS DISTINCT FROM t.locationname     OR
          d.organizationtype IS DISTINCT FROM t.organizationtype
      );

    -- ── Step 4: derive roundupforcharity from dim.organization ─
    -- Org-level flag: if ANY location in the org has roundupforcharity = TRUE
    -- in dim.organization, all rows for that org are flagged TRUE.
    WITH cte AS (
        SELECT DISTINCT
            ol.organizationid,
            ol.locationid,
            SUM(CASE WHEN o.roundupforcharity = TRUE THEN 1 ELSE 0 END)
                OVER (PARTITION BY ol.organizationid) AS org_level_roundup_for_charity
        FROM dim.organizationlocation AS ol
        INNER JOIN dim.organization AS o
               ON ol.locationid = o.id
    )
    UPDATE dim.organizationlocation
    SET roundupforcharity = CASE
                                WHEN cte.org_level_roundup_for_charity > 0 THEN TRUE
                                ELSE FALSE
                            END
    FROM cte
    WHERE organizationlocation.organizationid = cte.organizationid
      AND organizationlocation.locationid     = cte.locationid;

-- ── Step 5: sync dim.location from organizationlocation + organization ──
    -- Scope: organizationtype = 0 (location-level rows only).
    -- Coordinates format in dim.organization: "(26.0940882,-80.2690641)"
    -- No columns added to dim.location — mapping to existing schema only.

    -- 5a: INSERT net-new locations
    INSERT INTO dim.location (
        locationid,
        companyid,          -- ← ol.organizationid
        locationgroupid,    -- no source mapping; NULL
        locationname,       -- ← ol.locationname
        address1,           -- ← o.address1
        address2,           -- ← o.address2
        city,               -- ← o.city
        state,              -- ← o.state
        zipcode,            -- ← o.zipcode
        latitude,           -- ← o.coordinates part 1
        longitude,          -- ← o.coordinates part 2
        timezone,           -- ← o.timezone
        sysinserttime
    )
    SELECT
        ol.locationid,
        ol.organizationid                                                                     AS companyid,
        NULL                                                                                  AS locationgroupid,
        ol.locationname,
        o.address1,
        o.address2,
        o.city,
        o.state,
        o.zipcode,
        TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 1))          AS latitude,
        TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 2))          AS longitude,
        o.timezone,
        NOW()
    FROM dim.organizationlocation ol
    INNER JOIN dim.organization o
            ON ol.locationid = o.id
           AND ol.organizationtype = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM dim.location loc
        WHERE loc.locationid = ol.locationid
    );

    -- 5b: UPDATE changed location-level attributes
    UPDATE dim.location loc
    SET
        locationname  = ol.locationname,
        address1      = o.address1,
        address2      = o.address2,
        city          = o.city,
        state         = o.state,
        zipcode       = o.zipcode,
        latitude      = TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 1)),
        longitude     = TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 2)),
        timezone      = o.timezone,
        sysupdatetime = NOW()
    FROM dim.organizationlocation ol
    INNER JOIN dim.organization o
            ON ol.locationid = o.id
           AND ol.organizationtype = 0
    WHERE loc.locationid = ol.locationid
      AND (
          loc.locationname IS DISTINCT FROM ol.locationname                                                           OR
          loc.address1     IS DISTINCT FROM o.address1                                                                OR
          loc.address2     IS DISTINCT FROM o.address2                                                                OR
          loc.city         IS DISTINCT FROM o.city                                                                    OR
          loc.state        IS DISTINCT FROM o.state                                                                   OR
          loc.zipcode      IS DISTINCT FROM o.zipcode                                                                 OR
          loc.latitude     IS DISTINCT FROM TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 1)) OR
          loc.longitude    IS DISTINCT FROM TRIM(SPLIT_PART(REPLACE(REPLACE(o.coordinates, '(', ''), ')', ''), ',', 2)) OR
          loc.timezone     IS DISTINCT FROM o.timezone
      );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_organizationlocation() OWNER TO citus;

--
-- TOC entry 721 (class 1255 OID 3601734)
-- Name: usp_refresh_view(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE PROCEDURE dim.usp_refresh_view()
    LANGUAGE plpgsql
    AS $$
BEGIN

    -- ── Step 1: extract distinct view names from insight events ──
    -- Mirrors ADF: sourceDim → parse1 (data.view) → select2 → aggregate3
    -- NULL/blank view names excluded — no useful dimension value to store

    CREATE TEMP TABLE tmp_view ON COMMIT DROP AS
    SELECT DISTINCT
        NULLIF(TRIM(data::jsonb->>'view'), '') AS viewname
    FROM stg.silver_kiosk_events as ke
    WHERE ke.eventmodule      = 'kiosk'
      AND ke.eventcategory    = 'insight'
      AND ke.data             IS NOT NULL
      AND ke.data             <> ''
      AND NULLIF(TRIM(data::jsonb->>'view'), '') IS NOT NULL;

    CREATE INDEX ix_tmp_view ON tmp_view (viewname);
    ANALYZE tmp_view;


    -- ── Step 2: INSERT net-new view names ────────────────────
    -- Mirrors ADF exists5 (negate exists against DimView on viewname)

    INSERT INTO dim.view (viewid, viewname, sysinserttime)
    SELECT
        nextval('dim.view_id_seq'),
        t.viewname,
        NOW()::TIMESTAMP
    FROM tmp_view t
    WHERE NOT EXISTS (
        SELECT 1
        FROM dim.view v
        WHERE v.viewname = t.viewname
    );

END;
$$;


ALTER PROCEDURE dim.usp_refresh_view() OWNER TO citus;

--
-- TOC entry 572 (class 1255 OID 3698531)
-- Name: truncate_silver_staging(); Type: PROCEDURE; Schema: etl; Owner: citus
--

CREATE PROCEDURE etl.truncate_silver_staging()
    LANGUAGE plpgsql
    AS $$
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
    TRUNCATE TABLE stg.silver_transaction_refunds;

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
$$;


ALTER PROCEDURE etl.truncate_silver_staging() OWNER TO citus;

--
-- TOC entry 1282 (class 1255 OID 3676268)
-- Name: usp_sort_db_objects_by_dependency(); Type: PROCEDURE; Schema: etl; Owner: citus
--

CREATE PROCEDURE etl.usp_sort_db_objects_by_dependency()
    LANGUAGE plpgsql
    AS $$


BEGIN

DROP TABLE IF EXISTS temp_gas_db_dependency_topology;

CREATE TEMP TABLE IF NOT EXISTS temp_gas_db_dependency_topology(
    table_schema text COLLATE pg_catalog."default",
    table_name text COLLATE pg_catalog."default",
    key_columns jsonb,
    key_type text COLLATE pg_catalog."default",
    key_column_data_types jsonb,
    dependency_level INTEGER,
    dependency_count INTEGER,
    depends_on jsonb,
    referenced_by jsonb,  -- NEW COLUMN
    insert_watermark text COLLATE pg_catalog."default",
    insert_watermark_data_type text COLLATE pg_catalog."default",
    update_watermark text COLLATE pg_catalog."default",
    update_watermark_data_type text COLLATE pg_catalog."default",
    sql_aggregate text COLLATE pg_catalog."default"
);

WITH RECURSIVE watermark_columns AS (
    SELECT DISTINCT
        COALESCE(it.table_schema, ut.table_schema) as table_schema, 
        COALESCE(it.table_name, ut.table_name) as table_name, 
        it.column_name as insert_watermark, 
        it.data_type as insert_watermark_type,
        ut.column_name as update_watermark, 
        ut.data_type as update_watermark_type
    FROM
        (SELECT 
            n.nspname::text as table_schema,
            c.relname::text as table_name,
            a.attname::text as column_name,
            format_type(a.atttypid, a.atttypmod) as data_type
         FROM pg_catalog.pg_attribute a
         JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
         JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
         WHERE n.nspname IN ('dim','fact','etl','ml')
           AND c.relkind = 'r'
           AND a.attnum > 0 
           AND NOT a.attisdropped
           AND (a.attname LIKE 'create%date%' OR a.attname LIKE 'sys%inserttime' OR a.attname LIKE 'created%on%')
           AND format_type(a.atttypid, a.atttypmod) LIKE '%timestamp%') as it
    FULL OUTER JOIN  
        (SELECT 
            n.nspname::text as table_schema,
            c.relname::text as table_name,
            a.attname::text as column_name,
            format_type(a.atttypid, a.atttypmod) as data_type
         FROM pg_catalog.pg_attribute a
         JOIN pg_catalog.pg_class c ON a.attrelid = c.oid
         JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
         WHERE n.nspname IN ('dim','fact','etl','ml')
           AND c.relkind = 'r'
           AND a.attnum > 0 
           AND NOT a.attisdropped
           AND (a.attname LIKE 'update%date%' OR a.attname LIKE 'sys%updatetime' OR a.attname LIKE 'modified%on%')
           AND format_type(a.atttypid, a.atttypmod) LIKE '%timestamp%') as ut
        ON it.table_schema = ut.table_schema
       AND it.table_name = ut.table_name
),
table_dependencies AS (
    -- Get all base tables in the schema
    SELECT DISTINCT
        n.nspname::text AS table_schema,
        c.relname::text AS table_name
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r' -- regular tables only
        AND n.nspname IN ('dim','fact','etl','ml')
        AND n.nspname NOT LIKE 'pg_temp_%'
        AND n.nspname NOT LIKE 'pg_toast_temp_%'
),
foreign_keys AS (
    -- Extract all foreign key relationships using pg_constraint (including cross-schema)
    SELECT DISTINCT
        n1.nspname::text AS referencing_schema,
        c1.relname::text AS referencing_table,
        n2.nspname::text AS referenced_schema,
        c2.relname::text AS referenced_table,
        -- Create a combined identifier for matching
        n1.nspname::text || '.' || c1.relname::text AS referencing_full,
        n2.nspname::text || '.' || c2.relname::text AS referenced_full
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c1 ON con.conrelid = c1.oid
    JOIN pg_catalog.pg_namespace n1 ON c1.relnamespace = n1.oid
    JOIN pg_catalog.pg_class c2 ON con.confrelid = c2.oid
    JOIN pg_catalog.pg_namespace n2 ON c2.relnamespace = n2.oid
    WHERE con.contype = 'f' -- foreign key constraints
        AND n1.nspname IN ('dim','fact','etl','ml')
),
dependency_graph AS (
    -- Build the complete dependency graph (including cross-schema dependencies)
    SELECT DISTINCT
        td.table_schema,
        td.table_name,
        td.table_schema || '.' || td.table_name AS full_table_name,
        COALESCE(array_agg(DISTINCT fk.referenced_full) 
            FILTER (WHERE fk.referenced_full IS NOT NULL), ARRAY[]::text[]) AS depends_on
    FROM table_dependencies td
    LEFT JOIN foreign_keys fk 
        ON td.table_schema || '.' || td.table_name = fk.referencing_full
    GROUP BY td.table_schema, td.table_name
),
reverse_dependency_graph AS (
    -- NEW CTE: Build reverse dependencies (which tables reference this table)
    SELECT DISTINCT
        td.table_schema,
        td.table_name,
        td.table_schema || '.' || td.table_name AS full_table_name,
        COALESCE(array_agg(DISTINCT fk.referencing_full) 
            FILTER (WHERE fk.referencing_full IS NOT NULL), ARRAY[]::text[]) AS referenced_by
    FROM table_dependencies td
    LEFT JOIN foreign_keys fk 
        ON td.table_schema || '.' || td.table_name = fk.referenced_full
    GROUP BY td.table_schema, td.table_name
),
table_keys AS (
    -- Get Primary Key or Unique Key columns using pg_constraint
    SELECT DISTINCT
        n.nspname::text AS table_schema,
        c.relname::text AS table_name,
        CASE 
            WHEN con.contype = 'p' THEN 'PRIMARY KEY'
            WHEN con.contype = 'u' THEN 'UNIQUE'
        END AS constraint_type,
        to_jsonb(array_agg(a.attname::text ORDER BY array_position(con.conkey, a.attnum))) AS key_columns,
        -- Build JSON object of column:type pairs
        jsonb_object_agg(
            a.attname::text,
            format_type(a.atttypid, a.atttypmod)
        ) AS key_data_types,
        CASE 
            WHEN con.contype = 'p' THEN 1
            WHEN con.contype = 'u' THEN 2
        END AS key_priority
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_class c ON con.conrelid = c.oid
    JOIN pg_catalog.pg_namespace n ON c.relnamespace = n.oid
    JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(con.conkey)
    WHERE con.contype IN ('p', 'u') -- primary key or unique
        AND n.nspname IN ('dim','fact','etl','ml')
    GROUP BY n.nspname, c.relname, con.contype, con.conname
),
best_keys AS (
    -- Select the best key for each table (PK preferred over UNIQUE)
    SELECT DISTINCT ON (table_schema, table_name)
        table_schema,
        table_name,
        constraint_type,
        key_columns,
        key_data_types
    FROM table_keys
    ORDER BY table_schema, table_name, key_priority
),
dependency_levels AS (
    -- Level 0: Tables with no dependencies
    SELECT DISTINCT
        dg.table_schema,
        dg.table_name,
        dg.full_table_name,
        0 AS dependency_level,
        dg.depends_on,
        ARRAY[dg.full_table_name] AS dependency_chain,
        bk.key_columns,
        bk.key_data_types,
        bk.constraint_type AS key_type
    FROM dependency_graph dg
    LEFT JOIN best_keys bk
        ON dg.table_schema = bk.table_schema
        AND dg.table_name = bk.table_name
    WHERE cardinality(dg.depends_on) = 0
    
    UNION ALL
    
    -- Recursive: Calculate levels for dependent tables
    SELECT DISTINCT
        dg.table_schema,
        dg.table_name,
        dg.full_table_name,
        dl.dependency_level + 1 AS dependency_level,
        dg.depends_on,
        dl.dependency_chain || dg.full_table_name AS dependency_chain,
        bk.key_columns,
        bk.key_data_types,
        bk.constraint_type AS key_type
    FROM dependency_graph dg
    JOIN dependency_levels dl 
        ON dl.full_table_name = ANY(dg.depends_on)
    LEFT JOIN best_keys bk
        ON dg.table_schema = bk.table_schema
        AND dg.table_name = bk.table_name
    WHERE NOT dg.full_table_name = ANY(dl.dependency_chain) -- Prevent circular dependencies
)

INSERT INTO temp_gas_db_dependency_topology
SELECT DISTINCT
    dl.table_schema,
    dl.table_name,
    dl.key_columns,
    dl.key_type,
    dl.key_data_types,
    dl.dependency_level,
    COALESCE(array_length(dl.depends_on, 1), 0) AS dependency_count,
    to_jsonb(dl.depends_on) as depends_on,
    to_jsonb(rdg.referenced_by) as referenced_by,  -- NEW COLUMN
    wc.insert_watermark,
    wc.insert_watermark_type,
    wc.update_watermark,
    wc.update_watermark_type,
    CASE WHEN (dl.key_data_types :: text LIKE '%bigint"}' OR dl.key_data_types :: text LIKE '%integer"}') AND jsonb_array_length(dl.key_columns) = 1
         THEN concat('max(', dl.key_columns ->> 0, ') as max_id, ', 
                      CASE WHEN wc.insert_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.insert_watermark, ')') END, ' as max_insert, ', 
                      CASE WHEN wc.update_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.update_watermark, ')') END, ' as max_update, ', 
                      'count(*) as record_count')
         ELSE concat('NULL as max_id, ', 
                      CASE WHEN wc.insert_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.insert_watermark, ')') END, ' as max_insert, ', 
                      CASE WHEN wc.update_watermark IS NULL THEN 'NULL' ELSE concat('max(', wc.update_watermark, ')') END, ' as max_update, ', 
                      'count(*) as record_count')
    END as sql_aggregate
FROM dependency_levels dl
LEFT JOIN watermark_columns wc
    ON dl.table_schema = wc.table_schema
    AND dl.table_name = wc.table_name
LEFT JOIN reverse_dependency_graph rdg  -- NEW JOIN
    ON dl.table_schema = rdg.table_schema
    AND dl.table_name = rdg.table_name
WHERE dl.dependency_level = (
    -- Get the maximum level for each table (in case of multiple paths)
    SELECT MAX(dl2.dependency_level)
    FROM dependency_levels dl2
    WHERE dl2.table_name = dl.table_name
        AND dl2.table_schema = dl.table_schema
);

INSERT INTO etl.gas_db_object_dependency_sort (
    table_schema,
    table_name,
    key_columns,
    key_type,
    key_column_data_types,
    dependency_level,
    dependency_count,
    depends_on,
    referenced_by,  -- NEW COLUMN
    insert_watermark,
    insert_watermark_data_type,
    update_watermark,
    update_watermark_data_type,
    sql_aggregate
)
SELECT * FROM temp_gas_db_dependency_topology as tau
WHERE NOT EXISTS (SELECT 1 FROM etl.gas_db_object_dependency_sort as pau 
                  WHERE pau.table_schema = tau.table_schema
                    AND pau.table_name = tau.table_name);

UPDATE etl.gas_db_object_dependency_sort
SET table_schema = tau.table_schema,
    table_name = tau.table_name,
    key_columns = tau.key_columns,
    key_type = tau.key_type,
    key_column_data_types = tau.key_column_data_types,
    dependency_level = tau.dependency_level,
    dependency_count = tau.dependency_count,
    depends_on = tau.depends_on,
    referenced_by = tau.referenced_by,  -- NEW COLUMN
    insert_watermark = tau.insert_watermark,
    insert_watermark_data_type = tau.insert_watermark_data_type,
    update_watermark = tau.update_watermark,
    update_watermark_data_type = tau.update_watermark_data_type,
    sql_aggregate = tau.sql_aggregate
FROM temp_gas_db_dependency_topology as tau
WHERE gas_db_object_dependency_sort.table_schema = tau.table_schema
  AND gas_db_object_dependency_sort.table_name = tau.table_name;

UPDATE etl.gas_db_object_dependency_sort
SET sql_source_query = CASE WHEN (referenced_by :: text LIKE '[]' OR referenced_by IS NULL) AND record_count < 10000000
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NULL AND update_watermark_value IS NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' > ''', insert_watermark_value :: text,
                                        ''' :: TIMESTAMP OR ', update_watermark, ' > ''', update_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' > ''', insert_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN (key_columns :: text LIKE '[]' OR key_columns IS NULL) AND insert_watermark_value IS NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', update_watermark, ' > ''', update_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN jsonb_array_length(key_columns) >= 1 AND record_count <= 100000
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            WHEN jsonb_array_length(key_columns) = 1 AND (key_column_data_types :: text LIKE '%bigint"}' OR key_column_data_types :: text LIKE '%integer"}')
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', key_columns ->> 0, ' >= ', COALESCE(watermark_integer_value, 0) :: text)
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' >= ''', insert_watermark_value :: text,
                                        ''' :: TIMESTAMP OR ', update_watermark, ' >= ''', update_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NOT NULL AND update_watermark_value IS NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', insert_watermark, ' > ''', insert_watermark_value :: text, ''' :: TIMESTAMP')
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NULL AND update_watermark_value IS NOT NULL
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name,
                                        ' WHERE ', update_watermark, ' > ''', update_watermark_value :: text, ''' :: TIMESTAMP')                            
                            WHEN jsonb_array_length(key_columns) >= 1 AND insert_watermark_value IS NULL AND update_watermark_value IS NULL AND record_count < 10000000 AND (referenced_by :: text LIKE '[]' OR referenced_by IS NULL)
                            THEN concat('SELECT * FROM ', table_schema, '.', table_name)
                            ELSE concat('SELECT * FROM ', table_schema, '.', table_name)
                        END;

DROP TABLE IF EXISTS temp_gas_db_dependency_topology;

END;
$$;


ALTER PROCEDURE etl.usp_sort_db_objects_by_dependency() OWNER TO citus;

--
-- TOC entry 738 (class 1255 OID 33016)
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
-- TOC entry 1474 (class 1255 OID 3568570)
-- Name: parse_iso_timestamp(text); Type: FUNCTION; Schema: fact; Owner: citus
--

CREATE FUNCTION fact.parse_iso_timestamp(ts_string text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
    SELECT CASE WHEN substring(ts_string, 20, 1) = '.'
                THEN replace(replace(substring(ts_string, 1, 23), 'T', ' '), '+', '0')
                ELSE replace(substring(ts_string, 1, 19), 'T', ' ')
           END;
$$;


ALTER FUNCTION fact.parse_iso_timestamp(ts_string text) OWNER TO citus;

--
-- TOC entry 989 (class 1255 OID 33017)
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
			SET watermarkvalue = watermarkvalue,
                sysupdatetime = NOW() :: TIMESTAMP
			WHERE watermarktablename = tablename;

			RETURN;
		END;
		$$;


ALTER FUNCTION fact.updatewatermark(tablename text) OWNER TO citus;

--
-- TOC entry 812 (class 1255 OID 700154)
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
-- TOC entry 884 (class 1255 OID 3654115)
-- Name: usp_gem_ordertiming_to_fact_ordertiming(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_gem_ordertiming_to_fact_ordertiming()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_watermark BIGINT;

BEGIN

    SELECT COALESCE(ts, 1775002010) - 600
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.ordertiming'
      AND  source             = 'gem';

    WITH new_events AS (
        SELECT
            stg.locationid,
            stg.companyid,
            stg.token,
            stg.device,
            stg.eventcategory,
            stg.eventtype,
            fact.parse_iso_timestamp(stg.eventinstant) :: TIMESTAMP AS eventinstant,
            stg.syscosmosts
        FROM  stg.silver_kiosk_events AS stg
        WHERE stg.eventmodule   = 'kiosk'
          AND stg.application   = 'nge'
          AND stg.token         > ''
          AND stg.token         IS NOT NULL
          AND stg.syscosmosts   > v_watermark
          AND (
                  (LOWER(stg.eventcategory) = 'session'  AND LOWER(stg.eventtype) = 'started')
               OR (LOWER(stg.eventcategory) = 'service'  AND LOWER(stg.eventtype) = 'select')
               OR (LOWER(stg.eventcategory) = 'item'     AND LOWER(stg.eventtype) = 'selected')
               OR (LOWER(stg.eventcategory) = 'checkout' AND LOWER(stg.eventtype) = 'viewed')
               OR (LOWER(stg.eventcategory) = 'payment'  AND LOWER(stg.eventtype) = 'create')
               OR (LOWER(stg.eventcategory) = 'order'    AND LOWER(stg.eventtype) = 'paidinfull')
               OR (LOWER(stg.eventcategory) = 'session'  AND LOWER(stg.eventtype) = 'closed')
          )
    ),

    aggregated AS (
        SELECT
            locationid,
            companyid,
            token                                                                                AS eventtoken,
            device                                                                               AS deviceid,
            MIN(CASE WHEN LOWER(eventcategory) = 'session' AND LOWER(eventtype) = 'started'
                     THEN TO_CHAR(eventinstant, 'YYYYMMDDHH24') :: INTEGER END)                  AS dateid,
            MIN(CASE WHEN LOWER(eventcategory) = 'session'  AND LOWER(eventtype) = 'started'    THEN eventinstant END) AS sessionstart,
            MIN(CASE WHEN LOWER(eventcategory) = 'service'  AND LOWER(eventtype) = 'select'     THEN eventinstant END) AS menustart,
            MIN(CASE WHEN LOWER(eventcategory) = 'item'     AND LOWER(eventtype) = 'selected'   THEN eventinstant END) AS itemstart,
            MAX(CASE WHEN LOWER(eventcategory) = 'checkout' AND LOWER(eventtype) = 'viewed'     THEN eventinstant END) AS checkoutstart,
            MIN(CASE WHEN LOWER(eventcategory) = 'payment'  AND LOWER(eventtype) = 'create'     THEN eventinstant END) AS paymentstart,
            MAX(CASE WHEN LOWER(eventcategory) = 'order'    AND LOWER(eventtype) = 'paidinfull' THEN eventinstant END) AS paymentend,
            MAX(CASE WHEN LOWER(eventcategory) = 'session'  AND LOWER(eventtype) = 'closed'     THEN eventinstant END) AS orderend,
            MAX(syscosmosts)                                                                     AS syscosmosts
        FROM  new_events
        GROUP BY locationid, companyid, token, device
    )

    INSERT INTO fact.ordertiming (
        id,
        companyid,
        locationid,
        eventtoken,
        dateid,
        deviceid,
        sessionstart,
        menustart,
        itemstart,
        checkoutstart,
        paymentstart,
        paymentend,
        orderend,
        starttomenu,
        menutoitem,
        itemtocheckout,
        checkouttopayment,
        paytopaid,
        payendtoend,
        starttocheckout,
        checkouttoend,
        totalordertime,
        sysinserttime,
        syscosmosts
    )
    SELECT
        nextval('fact.ordertiming_id_seq')                                                       AS id,
        companyid,
        locationid,
        eventtoken,
        dateid,
        deviceid,
        sessionstart,
        menustart,
        itemstart,
        checkoutstart,
        paymentstart,
        paymentend,
        orderend,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (menustart     - sessionstart )) :: NUMERIC, 3), 0)   AS starttomenu,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (itemstart     - menustart    )) :: NUMERIC, 3), 0)   AS menutoitem,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (checkoutstart - itemstart    )) :: NUMERIC, 3), 0)   AS itemtocheckout,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (paymentstart  - checkoutstart)) :: NUMERIC, 3), 0)   AS checkouttopayment,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (paymentend    - paymentstart )) :: NUMERIC, 3), 0)   AS paytopaid,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (orderend      - paymentend   )) :: NUMERIC, 3), 0)   AS payendtoend,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (checkoutstart - sessionstart )) :: NUMERIC, 3), 0)   AS starttocheckout,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (orderend      - checkoutstart)) :: NUMERIC, 3), 0)   AS checkouttoend,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (orderend      - sessionstart )) :: NUMERIC, 3), 0)   AS totalordertime,
        NOW() :: TIMESTAMP                                                                       AS sysinserttime,
        syscosmosts
    FROM aggregated                          -- ← no semicolon here, INSERT continues below

    ON CONFLICT (locationid, eventtoken)
    DO UPDATE SET
        -- Fill NULL timing fields with newly arrived event timestamps
        sessionstart      = COALESCE(fact.ordertiming.sessionstart,  EXCLUDED.sessionstart),
        menustart         = COALESCE(fact.ordertiming.menustart,     EXCLUDED.menustart),
        itemstart         = COALESCE(fact.ordertiming.itemstart,     EXCLUDED.itemstart),
        checkoutstart     = COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart),
        paymentstart      = COALESCE(fact.ordertiming.paymentstart,  EXCLUDED.paymentstart),
        paymentend        = COALESCE(fact.ordertiming.paymentend,    EXCLUDED.paymentend),
        orderend          = COALESCE(fact.ordertiming.orderend,      EXCLUDED.orderend),

        -- Recalculate durations using merged (best available) timestamps
        -- If existing row had sessionstart=NULL but new batch has it,
        -- we now have both ends and can compute the real duration
        starttomenu       = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.menustart,     EXCLUDED.menustart) -
                                COALESCE(fact.ordertiming.sessionstart,  EXCLUDED.sessionstart)
                            )) :: NUMERIC, 3), 0),
        menutoitem        = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.itemstart,     EXCLUDED.itemstart) -
                                COALESCE(fact.ordertiming.menustart,     EXCLUDED.menustart)
                            )) :: NUMERIC, 3), 0),
        itemtocheckout    = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart) -
                                COALESCE(fact.ordertiming.itemstart,     EXCLUDED.itemstart)
                            )) :: NUMERIC, 3), 0),
        checkouttopayment = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.paymentstart,  EXCLUDED.paymentstart) -
                                COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart)
                            )) :: NUMERIC, 3), 0),
        paytopaid         = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.paymentend,    EXCLUDED.paymentend) -
                                COALESCE(fact.ordertiming.paymentstart,  EXCLUDED.paymentstart)
                            )) :: NUMERIC, 3), 0),
        payendtoend       = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.orderend,      EXCLUDED.orderend) -
                                COALESCE(fact.ordertiming.paymentend,    EXCLUDED.paymentend)
                            )) :: NUMERIC, 3), 0),
        starttocheckout   = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart) -
                                COALESCE(fact.ordertiming.sessionstart,  EXCLUDED.sessionstart)
                            )) :: NUMERIC, 3), 0),
        checkouttoend     = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.orderend,      EXCLUDED.orderend) -
                                COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart)
                            )) :: NUMERIC, 3), 0),
        totalordertime    = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.orderend,      EXCLUDED.orderend) -
                                COALESCE(fact.ordertiming.sessionstart,  EXCLUDED.sessionstart)
                            )) :: NUMERIC, 3), 0),

        -- Always advance to latest known syscosmosts
        syscosmosts       = GREATEST(fact.ordertiming.syscosmosts, EXCLUDED.syscosmosts),
        sysupdatetime     = NOW() :: TIMESTAMP

    -- Only update if at least one timing field can be filled in
    WHERE (
        (fact.ordertiming.sessionstart  IS NULL AND EXCLUDED.sessionstart  IS NOT NULL) OR
        (fact.ordertiming.menustart     IS NULL AND EXCLUDED.menustart     IS NOT NULL) OR
        (fact.ordertiming.itemstart     IS NULL AND EXCLUDED.itemstart     IS NOT NULL) OR
        (fact.ordertiming.checkoutstart IS NULL AND EXCLUDED.checkoutstart IS NOT NULL) OR
        (fact.ordertiming.paymentstart  IS NULL AND EXCLUDED.paymentstart  IS NOT NULL) OR
        (fact.ordertiming.paymentend    IS NULL AND EXCLUDED.paymentend    IS NOT NULL) OR
        (fact.ordertiming.orderend      IS NULL AND EXCLUDED.orderend      IS NOT NULL)
    );

    UPDATE fact.watermarktable
    SET    ts = (SELECT COALESCE(MAX(syscosmosts), 1720000300) FROM fact.ordertiming),
           sysupdatetime = NOW() :: TIMESTAMP
    WHERE  watermarktablename = 'fact.ordertiming'
      AND  source             = 'gem';

END;
$$;


ALTER PROCEDURE fact.usp_gem_ordertiming_to_fact_ordertiming() OWNER TO citus;

--
-- TOC entry 1099 (class 1255 OID 2984304)
-- Name: usp_gem_sent_surveys_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_gem_sent_surveys_to_fact()
    LANGUAGE plpgsql
    AS $$


DECLARE
    v_max_gem_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_gem_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.sent_surveys'
      AND source             = 'gem';

    WITH delta_sent AS (

        SELECT DISTINCT ON (locationid, token)
            locationid,
            token                                           AS ordersessionid,
            NULLIF(ke.data, '') :: jsonb ->> 'orderId'      AS orderid,
            NULLIF(ke.data, '') :: jsonb                    AS survey_metadata,
            eventcategory                                   AS gem_event_category,
            eventtype                                       AS gem_event_type,
            eventinstant                                    AS gem_event_instant,
            syscosmosts                                     AS gem_syscosmosts
        FROM stg.silver_kiosk_events AS ke
        WHERE ke.eventcategory = 'Survey'
          AND ke.eventtype     = 'Sent'
          AND ke.token         > ''
          AND ke.syscosmosts   > v_max_gem_syscosmosts
        ORDER BY locationid, token, syscosmosts DESC

    )
    INSERT INTO fact.sent_surveys (
        organizationid,
        locationid,
        ordersessionid,
        orderid,
        survey_metadata,
        gem_event_category,
        gem_event_type,
        gem_event_instant,
        gem_syscosmosts,
        is_responded,
        sysinserttime
    )
    SELECT
        ol.organizationid,
        ds.locationid,
        ds.ordersessionid,
        ds.orderid,
        ds.survey_metadata,
        ds.gem_event_category,
        ds.gem_event_type,
        ds.gem_event_instant,
        ds.gem_syscosmosts,
        false                   AS is_responded,
        now() :: TIMESTAMP      AS sysinserttime
    FROM delta_sent AS ds
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = ds.locationid
        AND ol.organizationtype = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM fact.sent_surveys AS fs
        WHERE fs.locationid     = ds.locationid
          AND fs.ordersessionid = ds.ordersessionid
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(gem_syscosmosts), 1775002010) FROM fact.sent_surveys),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.sent_surveys'
      AND source             = 'gem';

END;
$$;


ALTER PROCEDURE fact.usp_gem_sent_surveys_to_fact() OWNER TO citus;

--
-- TOC entry 757 (class 1255 OID 3652819)
-- Name: usp_gem_usercheckedin_to_fact_usercheckedin(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_gem_usercheckedin_to_fact_usercheckedin()
    LANGUAGE plpgsql
    AS $$

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
    -- data JSON path (FROM sample):
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

    UPDATE fact.usercheckedin
    SET orderdatelocal = ordertimestamp::TIMESTAMPTZ AT TIME ZONE l.timezone
    FROM dim.organization as l
    WHERE l.id = usercheckedin.locationid 
    and usercheckedin.orderdatelocal IS NULL;

    UPDATE fact.usercheckedin
    SET dateid = cast(to_char(orderdatelocal, 'YYYYMMDDHH24') as integer)
    WHERE dateid IS NULL;
    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- ----------------------------------------------------------
    UPDATE fact.watermarktable
    SET    ts = (SELECT coalesce(max(syscosmosts), 1775002010) FROM fact.usercheckedin),
           sysupdatetime = NOW() :: TIMESTAMP
    WHERE  watermarktablename = 'fact.usercheckedin'
      AND  source             = 'gem';

END;
$$;


ALTER PROCEDURE fact.usp_gem_usercheckedin_to_fact_usercheckedin() OWNER TO citus;

--
-- TOC entry 941 (class 1255 OID 3679444)
-- Name: usp_gsh_devicehealth_to_fact_devicestate(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_gsh_devicehealth_to_fact_devicestate()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_watermark     TIMESTAMP;

BEGIN

    -- ----------------------------------------------------------
    -- Step 1 — Read the current watermark
    -- ----------------------------------------------------------
    SELECT COALESCE(watermarkvalue, '1970-01-01 00:00:00'::timestamp)
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.devicestate'
      AND  source             = 'gsh';

    -- ----------------------------------------------------------
    -- Step 2 — Insert qualifying rows into fact.devicestate
    -- ----------------------------------------------------------
    WITH live_locations AS (
        SELECT DISTINCT
            o.id      AS locationid,
            k.kioskid AS deviceid
        FROM  dim.organization AS o
        INNER JOIN dim.kiosk   AS k ON o.id = k.locationid
        WHERE o.active      = true
          AND o.status      = 2
          AND k.istestkiosk = false
    ),

    delta AS (
        SELECT
            stg.companyid,
            stg.locationid,
            stg.deviceid,
            stg.healthdatatime                                          AS lasteventtime,
            stg.statuschangetime,
            ROUND(
                GREATEST(
                    0,
                    EXTRACT(EPOCH FROM (stg.healthdatatime - stg.statuschangetime)) / 60.0
                )::numeric, 3
            )                                                           AS duration,
            REPLACE(
                REPLACE(
                    REPLACE(SUBSTRING(stg.healthdatatime::text, 1, 13), 
                            '-', ''),
                    ' ', ''),
                'T', ''
            ) :: INTEGER                                                AS dateid,
            CASE stg.status
                WHEN 'Ok'      THEN 'Up'
                WHEN 'Dormant' THEN 'Caution'
                WHEN 'Unknown' THEN 'Down'
                ELSE                'PartialUp'
            END                                                         AS state
        FROM  stg.fact_devicestate AS stg
        INNER JOIN live_locations  AS ll
               ON  ll.locationid = stg.locationid
              AND  ll.deviceid   = stg.deviceid
        WHERE stg.healthdatatime > v_watermark
          AND NOT EXISTS (
                  SELECT 1
                  FROM   fact.devicestate AS f
                  WHERE  f.deviceid      = stg.deviceid
                    AND  f.locationid    = stg.locationid
                    AND  f.lasteventtime = stg.healthdatatime
              )
    )

    INSERT INTO fact.devicestate (
        id,
        companyid,
        locationid,
        deviceid,
        dateid,
        state,
        lasteventtime,
        statuschangetime,
        duration,
        sysinserttime
    )
    SELECT
        NEXTVAL('fact.devicestate_id_seq'),
        companyid,
        locationid,
        deviceid,
        dateid,
        state,
        lasteventtime,
        statuschangetime,
        duration,
        NOW()::timestamp
    FROM delta;


    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- ----------------------------------------------------------

        UPDATE fact.watermarktable
        SET    watermarkvalue = (SELECT COALESCE(MAX(lasteventtime) - INTERVAL '10 seconds', '1970-01-01 00:00:00'::TIMESTAMP) FROM fact.devicestate),
               sysupdatetime  = NOW() :: TIMESTAMP
        WHERE  watermarktablename = 'fact.devicestate'
          AND  source             = 'gsh';



END;
$$;


ALTER PROCEDURE fact.usp_gsh_devicehealth_to_fact_devicestate() OWNER TO citus;

--
-- TOC entry 1054 (class 1255 OID 3650138)
-- Name: usp_gsh_devicetelemetry_to_fact_devicetelemetry(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_gsh_devicetelemetry_to_fact_devicetelemetry()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_watermark TIMESTAMP;

BEGIN

    -- ----------------------------------------------------------
    -- Step 1 — Read the current watermark
    -- Conservative: lesser of MAX(cputimestamp) and MAX(memorytimestamp)
    -- mirrors ADF sourcedevicetelemetry query
    -- ----------------------------------------------------------
    SELECT COALESCE(watermarkvalue, '1970-01-01 00:00:00'::timestamp)
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.devicetelemetry'
      AND  source             = 'gsh';

    -- ----------------------------------------------------------
    -- Step 2 — Upsert into fact.devicetelemetry
    --
    -- Qualifications:
    --   a) cputimestamp OR memorytimestamp beats the watermark
    --   b) Location is live (dim.organization status=2, active=true,
    --      dim.kiosk istestkiosk=false)
    --   c) locationid exists in dim.organization
    --      (mirrors ADF ExistingLocations exists check)
    --
    -- cpu/memory normalization (mirrors ADF CastFields derivedColumn):
    --   ksk-% devices with value <= 1  → keep as-is (already a ratio)
    --   all others with value > 1      → divide by 100
    --
    -- Upsert key: (deviceid, locationid, dateid)
    --   On conflict: update metric values and timestamps,
    --                preserve original sysinserttime
    -- ----------------------------------------------------------
    WITH live_locations_kiosks AS (
        SELECT DISTINCT
            o.id      AS locationid,
            k.kioskid AS deviceid
        FROM  dim.organization AS o
        INNER JOIN dim.kiosk   AS k ON o.id = k.locationid
        WHERE o.active      = true
          AND o.status      = 2
          AND k.istestkiosk = false
    ),

    delta AS (
        SELECT DISTINCT ON (stg.locationid, stg.deviceid, stg.dateid)
            stg.deviceid,
            stg.locationid,
            stg.dateid,
            stg.cputimestamp,
            stg.memorytimestamp,
            CASE
                WHEN stg.deviceid LIKE 'ksk-%' AND stg.cpuvalue    <= 1 THEN stg.cpuvalue
                WHEN stg.cpuvalue    > 1                                 THEN stg.cpuvalue    / 100
            END AS cpuvalue,
            CASE
                WHEN stg.deviceid LIKE 'ksk-%' AND stg.memoryvalue <= 1 THEN stg.memoryvalue
                WHEN stg.memoryvalue > 1                                 THEN stg.memoryvalue / 100
            END AS memoryvalue
        FROM  stg.fact_devicetelemetry AS stg
        INNER JOIN live_locations_kiosks AS ll
               ON  ll.locationid = stg.locationid
              AND  ll.deviceid   = stg.deviceid
        WHERE EXISTS (
                  SELECT 1
                  FROM   dim.organization AS o
                  WHERE  o.id = stg.locationid
              )
          AND (stg.cputimestamp >= v_watermark OR stg.memorytimestamp >= v_watermark)
        ORDER BY
            stg.deviceid,
            stg.locationid,
            stg.dateid,
            GREATEST(stg.cputimestamp, stg.memorytimestamp) DESC  -- latest reading wins
    )

    INSERT INTO fact.devicetelemetry (
        deviceid,
        locationid,
        dateid,
        cpuvalue,
        memoryvalue,
        cputimestamp,
        memorytimestamp,
        sysinserttime,
        sysupdatetime
    )
    SELECT
        deviceid,
        locationid,
        dateid,
        cpuvalue,
        memoryvalue,
        cputimestamp,
        memorytimestamp,
        NOW()::timestamp,
        NULL
    FROM delta
    ON CONFLICT (deviceid, locationid, dateid)
    DO UPDATE SET
        cpuvalue        = COALESCE(EXCLUDED.cpuvalue,        fact.devicetelemetry.cpuvalue),
        memoryvalue     = COALESCE(EXCLUDED.memoryvalue,     fact.devicetelemetry.memoryvalue),
        cputimestamp    = COALESCE(EXCLUDED.cputimestamp,    fact.devicetelemetry.cputimestamp),
        memorytimestamp = COALESCE(EXCLUDED.memorytimestamp, fact.devicetelemetry.memorytimestamp),
        sysupdatetime   = NOW()::timestamp;
        -- sysinserttime deliberately excluded — preserves original insert time

    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- Conservative: lesser of MAX(cputimestamp) and MAX(memorytimestamp)
    -- ----------------------------------------------------------
    UPDATE fact.watermarktable
    SET    watermarkvalue = (
               SELECT LEAST(MAX(cputimestamp), MAX(memorytimestamp)) - INTERVAL '10 seconds'
               FROM   fact.devicetelemetry
           ),
           sysupdatetime = NOW() :: TIMESTAMP
    WHERE  watermarktablename = 'fact.devicetelemetry'
      AND  source             = 'gsh';

END;
$$;


ALTER PROCEDURE fact.usp_gsh_devicetelemetry_to_fact_devicetelemetry() OWNER TO citus;

--
-- TOC entry 915 (class 1255 OID 2874333)
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
-- TOC entry 643 (class 1255 OID 700153)
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
-- TOC entry 975 (class 1255 OID 2247996)
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
-- TOC entry 537 (class 1255 OID 2951716)
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
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_impressions),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_impressions'
  AND source = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_modifier_impression_analysis() OWNER TO citus;

--
-- TOC entry 1370 (class 1255 OID 2951719)
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
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_interactions WHERE sourceid = 5),
    sysupdatetime = NOW() :: TIMESTAMP
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
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_interactions WHERE sourceid = 6),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge-Options';

END;
$$;


ALTER PROCEDURE fact.usp_modifier_interaction_analysis() OWNER TO citus;

--
-- TOC entry 552 (class 1255 OID 2874430)
-- Name: usp_modifier_recommendation_analysis(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_modifier_recommendation_analysis()
    LANGUAGE plpgsql
    AS $$

BEGIN

WITH delta_impressions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_impressions')
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
SET ts = (SELECT max(syscosmosts) - 10 FROM fact.modifier_impressions),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_impressions'
  AND source = 'nge';

WITH delta_interactions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge')
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
SELECT *, NULL :: TIMESTAMP as sysupdatetime
FROM trxn_enrichment;

UPDATE fact.watermarktable
SET ts = (SELECT max(syscosmosts) - 10 FROM fact.modifier_interactions WHERE modifiername IS NOT NULL),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge';


WITH delta_modifier_trxns AS (
SELECT *
FROM fact.itemmodifier as im
WHERE (syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge-Options') OR
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
       CASE WHEN m.min_quantity = 0 AND m.max_quantity > 0 THEN 'optional'
            WHEN m.min_quantity >= 1 AND m.max_quantity >= 1 THEN 'default' END selection_type,
       CASE WHEN m.min_quantity = 0 AND m.max_quantity > 0 AND mt.modifierquantity > 0 THEN 'added'
            WHEN m.min_quantity >= 1 AND m.max_quantity >= 1 AND mt.modifierquantity >= 1 THEN 'kept'
            WHEN m.min_quantity >= 1 AND m.max_quantity >= 1 AND mt.modifierquantity = 0 THEN 'removed' END AS action,
       NULL :: TEXT as session_recorded_at,
       mt.businessdate,
       ti.orderdatelocal,
       ti.frequentcustomerid,
       mt.syscosmosts,
       mt.sysinserttime
FROM delta_modifier_trxns as mt
LEFT JOIN dim.modifier as m 
    ON mt.modifierid = m.modifierid
LEFT JOIN fact.transactionitem as ti 
    ON mt.transactionheaderid = ti.transactionheaderid
    AND mt.itemid = ti.itemid
)
INSERT INTO fact.modifier_interactions
SELECT *, NULL :: TIMESTAMP as sysupdatetime 
FROM modfr_enrichment;

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

UPDATE fact.watermarktable
SET ts = (SELECT max(syscosmosts) - 10 FROM fact.modifier_interactions WHERE modifiername IS NOT NULL),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge-Options';

END;
$$;


ALTER PROCEDURE fact.usp_modifier_recommendation_analysis() OWNER TO citus;

--
-- TOC entry 1132 (class 1255 OID 3615966)
-- Name: usp_nge_update_itemssurvey(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_nge_update_itemssurvey()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_max_nge_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_nge_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'nge';


    WITH delta_responses AS (

        SELECT DISTINCT ON (locationid, orderid, surveyid, itemid)
            locationid,
            orderid,
            surveyid,
            surveytransid,
            itemid,
            itemrating,
            surveytransstatus,
            surveycompletedtimestamp,
            nge_syscosmosts
        FROM stg.fact_itemssurvey
        WHERE nge_syscosmosts > v_max_nge_syscosmosts
        ORDER BY locationid, orderid, surveyid, itemid, nge_syscosmosts DESC

    )
    UPDATE fact.itemssurvey AS f
    SET
        organizationid              = COALESCE(os.organizationid, ol.organizationid),
        surveytransid               = dr.surveytransid,
        itemrating                  = dr.itemrating,
        surveytransstatus           = dr.surveytransstatus,
        surveycompletedtimestamp    = dr.surveycompletedtimestamp,
        nge_syscosmosts             = dr.nge_syscosmosts,
        is_responded                = CASE WHEN dr.surveytransstatus = '2'
                                          THEN true ELSE false END,
        sysupdatetime               = now() :: TIMESTAMP
    FROM delta_responses AS dr
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = dr.locationid
        AND th.transactionheaderid = dr.orderid
        AND th.orderstatus         = 'order-placed'
    INNER JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = dr.locationid
        AND ol.organizationtype = 0
    INNER JOIN dim.occasionsurvey AS os
        ON  os.organizationid = ol.organizationid
        AND os.surveyid       = dr.surveyid
    WHERE f.locationid    = dr.locationid
      AND f.orderid       = dr.orderid
      AND f.surveyid      = dr.surveyid
      AND f.itemid        = dr.itemid
      AND f.sysupdatetime IS NULL;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(nge_syscosmosts), 1775002010) FROM fact.itemssurvey),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_nge_update_itemssurvey() OWNER TO citus;

--
-- TOC entry 982 (class 1255 OID 676702)
-- Name: usp_offer_analysis(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_offer_analysis()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.recommendations'
      AND source             = 'nge';

WITH delta AS (
        SELECT * FROM fact.recommendations AS rc
        WHERE rc.syscosmosts > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1 FROM fact.vw_offer_analysis AS oa
                WHERE oa.locationid          = rc.locationid
                  AND oa.transactionheaderid = rc.transactionheaderid
              )
), rec AS (
        SELECT
            rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.offereditems,
            rc.prompttimestamp,
            rc.prompttimestamp :: TIMESTAMP                                 AS upsellprompttime,
            rc.syscosmosts,
            element.value ->> 'itemId'       :: TEXT                       AS offered_itemid,
            element.value ->> 'upsellLevel'  :: TEXT                       AS offered_upselllevel,
            element.value ->> 'promptItemId' :: TEXT                       AS offered_prmpid,
            element.value ->> 'upsellGroupId':: TEXT                       AS offered_upslgrpid
        FROM delta AS rc,
            LATERAL jsonb_array_elements(rc.offereditems) element(value)
), selected AS (
        SELECT
            rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.selecteditems,
            rc.prompttimestamp,
            element.value ->> 'itemId'       :: TEXT                       AS selected_itemid,
            element.value ->> 'quantity'     :: TEXT                       AS selected_quantity,
            element.value ->> 'upsellLevel'  :: TEXT                       AS selected_upselllevel,
            element.value ->> 'promptItemId' :: TEXT                       AS selected_prmpid,
            element.value ->> 'upsellGroupId':: TEXT                       AS selected_upslgrpid
        FROM delta AS rc,
            LATERAL jsonb_array_elements(rc.selecteditems) element(value)
), item_analysis AS (
        SELECT
            r.locationid,
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid                                                AS offereditem,
            r.offered_upselllevel                                           AS offereditem_upselllevel,
            r.offered_prmpid                                                AS offered_promptitemid,
            r.offered_upslgrpid                                             AS offered_upsellgroupid,
            s.selected_itemid                                               AS selecteditem,
            s.selected_upselllevel                                          AS selecteditem_upselllevel,
            s.selected_prmpid                                               AS selected_promptitemid,
            s.selected_upslgrpid                                            AS selected_upsellgroupid,
            CASE
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'item'     THEN 'Item Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'order'    THEN 'Order Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'       THEN 'Smart Order Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai-order' THEN 'Smart Order Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai-item'  THEN 'Smart Item Upsells'
                ELSE NULL
            END                                                             AS upselltype,
            COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)            AS upsellgroupid,
            ul.upsellgroupname,
            CASE
                WHEN lower(s.selected_quantity) = ANY (ARRAY['true', '1']) THEN 1
                ELSE lower(s.selected_quantity) :: INTEGER
            END                                                             AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            NOW()                                                           AS sysinserttime
        FROM (SELECT * FROM rec WHERE rec.offered_itemid LIKE 'itm-%') AS r
        LEFT JOIN selected                  AS s
            ON  s.transactionheaderid :: TEXT = r.transactionheaderid :: TEXT
            AND s.recommendationid    :: TEXT = r.recommendationid    :: TEXT
            AND s.selected_itemid     :: TEXT = r.offered_itemid      :: TEXT
        LEFT JOIN dim.upsellgrouplookup     AS ul
            ON  ul.upsellgroupid :: TEXT = COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)
), category_analysis AS (
        SELECT
            r.locationid,
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid                                                AS offereditem,
            r.offered_upselllevel                                           AS offereditem_upselllevel,
            r.offered_prmpid                                                AS offered_promptitemid,
            r.offered_upslgrpid                                             AS offered_upsellgroupid,
            s.selected_itemid                                               AS selecteditem,
            s.selected_upselllevel                                          AS selecteditem_upselllevel,
            s.selected_prmpid                                               AS selected_promptitemid,
            s.selected_upslgrpid                                            AS selected_upsellgroupid,
            CASE
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'item'     THEN 'Item Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'order'    THEN 'Order Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'       THEN 'Smart Order Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai-order' THEN 'Smart Order Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai-item'  THEN 'Smart Item Upsells'
                ELSE NULL
            END                                                             AS upselltype,
            COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)            AS upsellgroupid,
            ul.upsellgroupname,
            CASE
                WHEN lower(s.selected_quantity) = ANY (ARRAY['true', '1']) THEN 1
                ELSE lower(s.selected_quantity) :: INTEGER
            END                                                             AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            NOW()                                                           AS sysinserttime
        FROM (SELECT * FROM rec WHERE rec.offered_itemid LIKE 'cat-%') AS r
        INNER JOIN dim.category_hierarchy   AS ctg
            ON  ctg.categoryid = r.offered_itemid
        INNER JOIN (
                SELECT * FROM selected
                WHERE selected.selected_itemid NOT IN (SELECT offered_itemid FROM rec)
              )                             AS s
            ON  s.transactionheaderid :: TEXT = r.transactionheaderid :: TEXT
            AND s.recommendationid    :: TEXT = r.recommendationid    :: TEXT
            AND s.selected_itemid             = ctg.menuitemid
        LEFT JOIN dim.upsellgrouplookup     AS ul
            ON  ul.upsellgroupid :: TEXT = COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)
), total AS (
        SELECT * FROM item_analysis
        UNION
        SELECT * FROM category_analysis
)
INSERT INTO fact.vw_offer_analysis (
    locationid,
    transactionheaderid,
    recommendationid,
    offereditem,
    offereditem_upselllevel,
    offered_promptitemid,
    offered_upsellgroupid,
    selecteditem,
    selecteditem_upselllevel,
    selected_promptitemid,
    selected_upsellgroupid,
    upselltype,
    upsellgroupid,
    upsellgroupname,
    quantity,
    prompttimestamp,
    upsellprompttime,
    syscosmosts,
    sysinserttime
)
SELECT
    locationid,
    transactionheaderid,
    recommendationid,
    offereditem,
    offereditem_upselllevel,
    offered_promptitemid,
    offered_upsellgroupid,
    selecteditem,
    selecteditem_upselllevel,
    selected_promptitemid,
    selected_upsellgroupid,
    upselltype,
    upsellgroupid,
    upsellgroupname,
    quantity,
    prompttimestamp,
    upsellprompttime,
    syscosmosts,
    sysinserttime
FROM total;

    UPDATE fact.watermarktable
    SET ts            = rec.maxts,
        sysupdatetime = NOW() :: TIMESTAMP
    FROM (
        SELECT
            COALESCE(MAX(syscosmosts), 1500000010)  AS maxts,
            'fact.recommendations'                  AS tablename,
            'nge'                                   AS source
        FROM fact.recommendations
    ) AS rec
    WHERE watermarktable.watermarktablename = rec.tablename
      AND watermarktable.source             = rec.source;

END;
$$;


ALTER PROCEDURE fact.usp_offer_analysis() OWNER TO citus;

--
-- TOC entry 664 (class 1255 OID 2993069)
-- Name: usp_sent_surveys_to_fact_itemssurvey(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_max_gem_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_gem_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'gem';

    DROP TABLE IF EXISTS temp_delta_sent_surveys;
    CREATE TEMPORARY TABLE temp_delta_sent_surveys (
        organizationid       TEXT COLLATE pg_catalog."default",
        locationid           TEXT COLLATE pg_catalog."default",
        ordersessionid       TEXT COLLATE pg_catalog."default",
        transactionheaderid  TEXT COLLATE pg_catalog."default",
        gem_event_category   TEXT COLLATE pg_catalog."default",
        gem_event_type       TEXT COLLATE pg_catalog."default",
        surveyid             TEXT COLLATE pg_catalog."default",
        itemid               TEXT COLLATE pg_catalog."default",
        is_responded         BOOLEAN,
        gem_event_instant    TEXT COLLATE pg_catalog."default",
        gem_syscosmosts      BIGINT,
        sysinserttime        TIMESTAMP,
        sysupdatetime        TIMESTAMP
    );

    WITH delta_sent_surveys AS (

        SELECT
            organizationid,
            locationid,
            ordersessionid,
            orderid                                                             AS transactionheaderid,
            gem_event_category,
            gem_event_type,
            survey_metadata,
            CASE WHEN jsonb_typeof(survey_metadata -> 'surveyIds') = 'array'
                 THEN survey_metadata -> 'surveyIds'
            END                                                                 AS surveyid_array,
            CASE WHEN survey_metadata ->> 'surveyIds' NOT LIKE '[%]'
                 THEN survey_metadata ->> 'surveyIds'
            END                                                                 AS surveyid_text,
            CASE WHEN jsonb_typeof(survey_metadata -> 'itemId') = 'array'
                 THEN survey_metadata -> 'itemId'
            END                                                                 AS itemid_array,
            CASE WHEN survey_metadata ->> 'itemId' NOT LIKE '[%]'
                 THEN survey_metadata ->> 'itemId'
            END                                                                 AS itemid_text,
            is_responded,
            gem_event_instant,
            gem_syscosmosts,
            sysinserttime,
            sysupdatetime
        FROM fact.sent_surveys AS ss
        WHERE ss.gem_syscosmosts > v_max_gem_syscosmosts
          AND NOT EXISTS (
              SELECT 1 FROM fact.itemssurvey AS its
              WHERE its.locationid = ss.locationid
                AND its.orderid    = ss.orderid
          )

    ), flattened_survey_trxns AS (

        SELECT
            dss.organizationid,
            dss.locationid,
            dss.ordersessionid,
            dss.transactionheaderid,
            dss.gem_event_category,
            dss.gem_event_type,
            TRIM(flat_survey.surveyid)                                          AS surveyid,
            dss.is_responded,
            dss.gem_event_instant,
            dss.gem_syscosmosts,
            dss.sysinserttime,
            dss.sysupdatetime
        FROM delta_sent_surveys AS dss
        CROSS JOIN LATERAL (
            SELECT unnest(
                CASE WHEN dss.surveyid_array IS NOT NULL
                     THEN ARRAY(SELECT jsonb_array_elements_text(dss.surveyid_array))
                     WHEN dss.surveyid_text  IS NOT NULL
                     THEN string_to_array(dss.surveyid_text, ',')
                END
            ) AS surveyid
        ) AS flat_survey

    ), flattened_item_trxns AS (

        SELECT
            dss.locationid,
            dss.transactionheaderid,
            TRIM(flat_item.itemid)                                              AS itemid
        FROM delta_sent_surveys AS dss
        CROSS JOIN LATERAL (
            SELECT unnest(
                CASE WHEN dss.itemid_array IS NOT NULL
                     THEN ARRAY(SELECT jsonb_array_elements_text(dss.itemid_array))
                     WHEN dss.itemid_text  IS NOT NULL
                     THEN string_to_array(dss.itemid_text, ',')
                END
            ) AS itemid
        ) AS flat_item

    ), joined_surveys_with_items AS (

        SELECT
            st.organizationid,
            st.locationid,
            st.ordersessionid,
            st.transactionheaderid,
            st.gem_event_category,
            st.gem_event_type,
            st.surveyid,
            it.itemid,
            st.is_responded,
            st.gem_event_instant,
            st.gem_syscosmosts,
            st.sysinserttime,
            st.sysupdatetime
        FROM flattened_survey_trxns AS st
        LEFT JOIN flattened_item_trxns AS it
            ON  it.locationid          = st.locationid
            AND it.transactionheaderid = st.transactionheaderid

    )
    INSERT INTO temp_delta_sent_surveys
    SELECT DISTINCT ON (locationid, transactionheaderid, surveyid, itemid) * 
    FROM joined_surveys_with_items
    ORDER BY locationid, transactionheaderid, surveyid, itemid, gem_syscosmosts DESC;

    INSERT INTO fact.itemssurvey (
        organizationid,
        locationid,
        ordersessionid,
        orderid,
        surveyissuedtimestamp,
        gem_event_category,
        gem_event_type,
        surveyid,
        itemid,
        is_responded,
        gem_event_instant,
        gem_syscosmosts,
        sysinserttime,
        sysupdatetime,
        sourceid
    )
    SELECT
        tds.organizationid,
        tds.locationid,
        tds.ordersessionid,
        tds.transactionheaderid,
        fact.parse_iso_timestamp(tds.gem_event_instant)     AS surveyissuedtimestamp,
        tds.gem_event_category,
        tds.gem_event_type,
        tds.surveyid,
        tds.itemid,
        tds.is_responded,
        tds.gem_event_instant,
        tds.gem_syscosmosts,
        tds.sysinserttime,
        tds.sysupdatetime,
        2                                                   AS sourceid
    FROM temp_delta_sent_surveys AS tds
    WHERE NOT EXISTS (
        SELECT 1 FROM fact.itemssurvey AS its
        WHERE its.organizationid = tds.organizationid
          AND its.locationid     = tds.locationid
          AND its.orderid        = tds.transactionheaderid
          AND its.surveyid       = tds.surveyid
          AND its.itemid         = tds.itemid
    )
      AND EXISTS (
        SELECT 1 FROM fact.transactionheader AS th
        WHERE th.locationid          = tds.locationid
          AND th.transactionheaderid = tds.transactionheaderid
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(gem_syscosmosts), 1775002010) FROM fact.itemssurvey),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'gem';

END;
$$;


ALTER PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey() OWNER TO citus;

--
-- TOC entry 1121 (class 1255 OID 3618756)
-- Name: usp_silver_aborted_orders_and_items_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_aborted_orders_and_items_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'gem';


    -- ----------------------------------------------------------------
    -- Stage the aborted order delta into a temp table so both the
    -- header INSERT and the item INSERT share the same result without
    -- repeating the dedup + filter logic.
    --
    -- DISTINCT ON (locationid, token) ordered by syscosmosts DESC keeps
    -- the latest event per session — mirrors ADF ROW_NUMBER() OVER
    -- (PARTITION BY location, token ORDER BY id DESC) filtered to rn = 1.
    -- ----------------------------------------------------------------
    DROP TABLE IF EXISTS temp_aborted_delta;
    CREATE TEMPORARY TABLE temp_aborted_delta AS
    SELECT DISTINCT ON (ke.locationid, ke.token)
        ke.id,
        CONCAT('abort-', ke.id)                                          AS transactionheaderid,
        ke.locationid,
        ke.device                                                        AS kioskid,
        ke.token                                                         AS ordersessionid,
        -- orderid: 'ord-' + order.sessionId from data JSON
        -- fallback to token if sessionId is absent
        CONCAT('ord-',
            COALESCE(
                NULLIF(ke.data :: jsonb -> 'order' ->> 'sessionId', ''),
                ke.token
            )
        )                                                                AS orderid,
        -- itemsessionid: raw sessionId without 'ord-' prefix
        -- mirrors ADF select2: itemsessionid = itemsessionid.order.sessionId
        COALESCE(
            NULLIF(ke.data :: jsonb -> 'order' ->> 'sessionId', ''),
            ke.token
        )                                                                AS itemsessionid,
        -- orderstatus: mirrors ADF case(exception → Abandoned, ordercancelled → Cancelled)
        CASE LOWER(ke.eventtype)
            WHEN 'exception'      THEN 'Abandoned'
            WHEN 'ordercancelled' THEN 'Cancelled'
            ELSE ke.eventtype
        END                                                              AS orderstatus,
        -- channel: extracted from data JSON via LIKE pattern
        -- mirrors ADF: case(like(data,'%"channel":0%'), 'Kiosk', ...)
        CASE
            WHEN ke.data LIKE '%"channel":0%' THEN 'Kiosk'
            WHEN ke.data LIKE '%"channel":1%' THEN 'OnlineOrdering'
            WHEN ke.data LIKE '%"channel":2%' THEN 'External'
            ELSE 'Kiosk'
        END                                                              AS channel,
        fact.parse_iso_timestamp(ke.eventinstant)                        AS orderdateutc,
        ke.syscosmosts
    FROM stg.silver_kiosk_events AS ke
    -- Real kiosk filter — mirrors ADF EXISTS against dim.kiosk WHERE istestkiosk = False
    INNER JOIN dim.kiosk AS dk
        ON  dk.kioskid     = ke.device
        AND dk.istestkiosk = false
    WHERE ke.eventcategory IN ('Order', 'insight')
      AND ke.eventtype     IN ('Cancelled', 'OrderCancelled', 'Abandoned', 'Exception')
      AND ke.syscosmosts   > v_max_syscosmosts
      -- Skip sessions already written as aborted orders
      AND NOT EXISTS (
          SELECT 1 FROM fact.transactionheader AS th
          WHERE th.locationid          = ke.locationid
            AND th.transactionheaderid = CONCAT('abort-', ke.id)
      )
    ORDER BY ke.locationid, ke.token, ke.syscosmosts DESC;


    -- ----------------------------------------------------------------
    -- INSERT fact.transactionheader
    --
    -- Session timing scoped to sessions in the current delta batch —
    -- avoids a full scan of silver_kiosk_events on every run.
    -- Same event filter pattern as usp_silver_transaction_header_to_fact.
    -- ----------------------------------------------------------------
    WITH session_timing AS (

        SELECT
            ke.locationid,
            ke.token,
            MIN(CASE WHEN LOWER(ke.eventcategory) = 'session'
                          AND LOWER(ke.eventtype)  = 'started'
                     THEN ke.eventinstant END)                           AS orderstarttime,
            MIN(CASE WHEN LOWER(ke.eventcategory) IN ('order', 'insight')
                          AND LOWER(ke.eventtype)  = 'revieworderclicked'
                     THEN ke.eventinstant END)                           AS reviewordertime,
            MIN(CASE WHEN LOWER(ke.eventcategory) IN ('order', 'insight')
                          AND LOWER(ke.eventtype)  = 'checkoutclicked'
                     THEN ke.eventinstant END)                           AS checkouttime,
            MIN(CASE WHEN LOWER(ke.eventcategory) = 'payment'
                          AND LOWER(ke.eventtype)  = 'create'
                     THEN ke.eventinstant END)                           AS paystarttime,
            MAX(CASE WHEN LOWER(ke.eventcategory) IN ('session', 'order')
                          AND LOWER(ke.eventtype)  = 'closed'
                     THEN ke.eventinstant END)                           AS sessionendtime
        FROM stg.silver_kiosk_events AS ke
        INNER JOIN temp_aborted_delta AS ad
            ON  ad.locationid     = ke.locationid
            AND ad.ordersessionid = ke.token
        WHERE LOWER(ke.severity) = 'information'
          AND (
                (LOWER(ke.eventcategory) = 'session'             AND LOWER(ke.eventtype) = 'started')            OR
                (LOWER(ke.eventcategory) IN ('order', 'insight') AND LOWER(ke.eventtype) = 'revieworderclicked') OR
                (LOWER(ke.eventcategory) IN ('order', 'insight') AND LOWER(ke.eventtype) = 'checkoutclicked')    OR
                (LOWER(ke.eventcategory) = 'payment'             AND LOWER(ke.eventtype) = 'create')             OR
                (LOWER(ke.eventcategory) IN ('session', 'order') AND LOWER(ke.eventtype) = 'closed')
              )
        GROUP BY ke.locationid, ke.token
        
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
        channel,
        syscosmosts,
        sourceid
    )
    SELECT
        nextval('fact.transactionheader_id_seq')                                        AS id,
        ad.transactionheaderid,
        ad.orderid,
        ad.locationid,
        ad.kioskid,
        ad.ordersessionid,
        CAST(TO_CHAR(
            (ad.orderdateutc :: TIMESTAMPTZ AT TIME ZONE loc.timezone) :: TIMESTAMP,
            'YYYYMMDDHH24'
        ) AS INTEGER)                                                                   AS dateid,
        ad.orderdateutc,
        (ad.orderdateutc :: TIMESTAMPTZ AT TIME ZONE loc.timezone) :: TIMESTAMP        AS orderdatelocal,
        ad.orderstatus,
        0 :: SMALLINT                                                                   AS numberofitems,
        0 :: SMALLINT                                                                   AS numberofpayments,
        0.000 :: NUMERIC(12,3)                                                         AS ordersredeemedrewards,
        0.000 :: NUMERIC(12,3)                                                         AS ordersubtotal,
        0.000 :: NUMERIC(12,3)                                                         AS ordertotal,
        0.000 :: NUMERIC(12,3)                                                         AS ordertax,
        0.000 :: NUMERIC(12,3)                                                         AS ordertip,
        0.000 :: NUMERIC(12,3)                                                         AS orderdiscount,
        0.000 :: NUMERIC(12,3)                                                         AS orderbalance,
        'None'                                                                          AS paymentstatus,
        'NGE'                                                                           AS sourcefile,
        now() :: TIMESTAMP                                                              AS createddate,
        fact.parse_iso_timestamp(st.orderstarttime)  :: TIMESTAMP                      AS orderstarttime,
        fact.parse_iso_timestamp(st.reviewordertime) :: TIMESTAMP                      AS reviewordertime,
        fact.parse_iso_timestamp(st.checkouttime)    :: TIMESTAMP                      AS checkouttime,
        fact.parse_iso_timestamp(st.paystarttime)    :: TIMESTAMP                      AS paystarttime,
        fact.parse_iso_timestamp(st.sessionendtime)  :: TIMESTAMP                      AS sessionendtime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.checkouttime) :: TIMESTAMP    - fact.parse_iso_timestamp(st.orderstarttime) :: TIMESTAMP
        ))                                                                              AS precheckouttime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.sessionendtime) :: TIMESTAMP  - fact.parse_iso_timestamp(st.checkouttime) :: TIMESTAMP
        ))                                                                              AS postcheckouttime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.reviewordertime) :: TIMESTAMP - fact.parse_iso_timestamp(st.orderstarttime) :: TIMESTAMP
        ))                                                                              AS menupagetime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.checkouttime) :: TIMESTAMP    - fact.parse_iso_timestamp(st.reviewordertime) :: TIMESTAMP
        ))                                                                              AS reviewpagetime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.sessionendtime) :: TIMESTAMP - fact.parse_iso_timestamp(st.paystarttime) :: TIMESTAMP
        ))                                                                              AS paymentpagetime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.sessionendtime) :: TIMESTAMP  - fact.parse_iso_timestamp(st.orderstarttime) :: TIMESTAMP
        ))                                                                              AS totalordertime,
        ad.channel,
        ad.syscosmosts,
        2                                                                               AS sourceid
    FROM temp_aborted_delta AS ad
    LEFT JOIN session_timing AS st
        ON  st.locationid = ad.locationid
        AND st.token      = ad.ordersessionid
    LEFT JOIN dim.organization AS loc
        ON  loc.id = ad.locationid
    ON CONFLICT (locationid, transactionheaderid)
    DO NOTHING;


    -- ----------------------------------------------------------------
    -- INSERT fact.transactionitem — placeholder stub per aborted order
    --
    -- Mirrors ADF WriteToItems: one fixed row per aborted order with
    -- itemid = 'itemid' and itemname = 'itemname' as placeholders.
    -- PK (transactionheaderid, itemid, itemname) guarantees exactly
    -- one stub row regardless of reruns.
    -- ----------------------------------------------------------------
    INSERT INTO fact.transactionitem (
        transactionheaderid,
        itemid,
        itemsessionid,
        itemname,
        itemquantity,
        itemunitprice,
        upselllevel,
        upsellpromptitemid,
        orderid,
        ordersessionid,
        orderdateutc,
        sysinserttime,
        locationid
    )
    SELECT
        ad.transactionheaderid,
        'itemid'                AS itemid,
        ad.itemsessionid,
        'itemname'              AS itemname,
        0 :: SMALLINT           AS itemquantity,
        0.000 :: NUMERIC(12,3)  AS itemunitprice,
        ''                      AS upselllevel,
        ''                      AS upsellpromptitemid,
        ad.orderid,
        ad.ordersessionid,
        ad.orderdateutc,
        now() :: TIMESTAMP      AS sysinserttime,
        ad.locationid
    FROM temp_aborted_delta AS ad
    ON CONFLICT (transactionheaderid, itemid, itemname)
    DO NOTHING;


    -- Advance watermark to max GEM syscosmosts across all sourceid = 2 headers
    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionheader WHERE sourceid = 2),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'gem';

END;
$$;


ALTER PROCEDURE fact.usp_silver_aborted_orders_and_items_to_fact() OWNER TO citus;

--
-- TOC entry 709 (class 1255 OID 3688733)
-- Name: usp_silver_cep_incidents_to_fact_cep_incidents(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_cep_incidents_to_fact_cep_incidents()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1767225610) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.cep_incidents'
      AND source             = 'gem';


    WITH new_error_events AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- stg.silver_cep_incidents is pre-filtered at the bronze→silver
        -- layer (application=nge, module=connector, severity=critical,
        -- category=order, type=ordersubmitresponse), so no re-filtering needed.
        -- DISTINCT ON natural key, latest syscosmosts wins.
        -- NOT EXISTS mirrors ADF negate exists against GASfactCEPIncidents:
        --   id        == incidentkey
        --   token     == eventtoken
        -- EXISTS dim.organizationlocation mirrors ADF ExistingLocations check

        SELECT DISTINCT ON (
            sci.id,
            sci.token
        )
            sci.id,
            sci.application,
            sci.companyid,
            sci.locationid,
            sci.eventmodule,
            sci.eventcategory,
            sci.eventtype,
            sci.severity,
            sci.token,
            sci.eventinstant,
            sci.device,
            sci.data,
            sci.syscosmosts
        FROM stg.silver_cep_incidents               AS sci
        WHERE sci.syscosmosts   > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.cep_incidents              AS ci
                WHERE ci.incidentkey = sci.id :: BIGINT
                  AND ci.eventtoken  = sci.token
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organizationlocation        AS ol
                WHERE ol.locationid     = sci.locationid
                  AND ol.organizationid = sci.companyid
              )
        ORDER BY
            sci.id,
            sci.token,
            sci.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.cep_incidents (
        incidentkey,
        application,
        organizationid,
        locationid,
        deviceid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidenttype,
        incidentcount,
        eventinstant,
        firstoccurred,
        lastoccurred,
        notificationtypeid,
        incidentdata,
        syscosmosts,
        sysinserttime,
        severity
    )
    -- ── gemJobCEP left join mirrored here ──────────────────────
    -- ADF joins error events LEFT JOIN gemCEPIncidents
    -- (Cosmos job='asa-failed-order') on:
    --   incidentkey  == incidentid
    --   errortoken   == eventtoken
    --   eventcategory == eventcategory
    --   eventtype    == eventtype
    -- Incident metadata (counts, timestamps) enriched from
    -- fact.gem_failed_order_job_notifications
    SELECT
        nee.id :: BIGINT                                                    AS incidentkey,
        nee.application,
        nee.companyid                                                       AS organizationid,
        nee.locationid,
        nee.device                                                          AS deviceid,
        nee.eventmodule,
        nee.eventcategory,
        nee.eventtype,
        nee.token                                                           AS eventtoken,
        gfojn.incidenttype,
        gfojn.incidentcount,
        nee.eventinstant,
        fact.parse_iso_timestamp(gfojn.firstoccurred) :: TIMESTAMP          AS firstoccurred,
        fact.parse_iso_timestamp(gfojn.lastoccurred) :: TIMESTAMP           AS firstoccurred,
        gfojn.notificationtypeid,
        nee.data                                                            AS incidentdata,
        nee.syscosmosts,
        NOW() :: TIMESTAMP                                                  AS sysinserttime,
        nee.severity
    FROM new_error_events                               AS nee
    LEFT JOIN fact.gem_failed_order_job_notifications   AS gfojn
        ON  gfojn.incidentid    = nee.id :: BIGINT
        AND gfojn.eventtoken    = nee.token
        AND gfojn.eventcategory = nee.eventcategory
        AND gfojn.eventtype     = nee.eventtype;


    UPDATE fact.watermarktable
    SET ts            = (SELECT COALESCE(MAX(syscosmosts), 0) FROM fact.cep_incidents),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.cep_incidents'
      AND source             = 'gem';

END;
$$;


ALTER PROCEDURE fact.usp_silver_cep_incidents_to_fact_cep_incidents() OWNER TO citus;

--
-- TOC entry 1436 (class 1255 OID 3623319)
-- Name: usp_silver_item_modifiers_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_item_modifiers_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_max_syscosmosts BIGINT;

BEGIN

    -- Capture watermark once upfront; subtract 10s as a safety overlap buffer
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.itemmodifier'
      AND source             = 'nge';

    WITH delta AS (
        -- Deduplicate: keep latest Cosmos snapshot per (header, item, group, modifier)
        SELECT DISTINCT ON (
            transactionheaderid,
            orderitemid,
            options_modifiergroupid,
            options_modifierid
        )
            transactionheaderid,
            orderid,
            orderitemid                             AS itemid,
            options_modifiergroupid                 AS modifiergroupid,
            options_modifierid                      AS modifierid,
            options_modifiername                    AS modifiername,
            COALESCE(options_modifierquantity, 1)   AS modifierquantity,
            options_modifierunitprice               AS modifierprice,
            modifier_freequantity                   AS freequantity,
            locationid,
            businessdate :: DATE                    AS businessdate,
            syscosmosts
        FROM stg.silver_item_modifiers
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND options_modifierid      IS NOT NULL
          AND options_modifiergroupid IS NOT NULL
          AND orderitemid             IS NOT NULL
          AND syscosmosts > v_max_syscosmosts
        ORDER BY
            transactionheaderid,
            orderitemid,
            options_modifiergroupid,
            options_modifierid,
            syscosmosts DESC
    )
    INSERT INTO fact.itemmodifier (
        transactionheaderid,
        orderid,
        itemid,
        modifiergroupid,
        modifierid,
        modifiername,
        modifierquantity,
        modifierprice,
        freequantity,
        sysinserttime,
        locationid,
        businessdate,
        syscosmosts
    )
    SELECT
        transactionheaderid,
        orderid,
        itemid,
        modifiergroupid,
        modifierid,
        modifiername,
        modifierquantity,
        modifierprice,
        freequantity,
        NOW() :: TIMESTAMP  AS sysinserttime,
        locationid,
        businessdate,
        syscosmosts
    FROM delta
    ON CONFLICT (transactionheaderid, itemid, modifiergroupid, modifierid)
    DO UPDATE SET
        modifiername     = EXCLUDED.modifiername,
        modifierquantity = EXCLUDED.modifierquantity,
        modifierprice    = EXCLUDED.modifierprice,
        freequantity     = EXCLUDED.freequantity,
        sysupdatetime    = NOW() :: TIMESTAMP,
        -- only advance if incoming snapshot is genuinely newer
        syscosmosts      = GREATEST(EXCLUDED.syscosmosts, fact.itemmodifier.syscosmosts);

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.itemmodifier),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.itemmodifier'
      AND source             = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_silver_item_modifiers_to_fact() OWNER TO citus;

--
-- TOC entry 759 (class 1255 OID 3687333)
-- Name: usp_silver_kiosk_events_to_fact_cep_incidents(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_kiosk_events_to_fact_cep_incidents()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(MAX(syscosmosts) - 10, 0)
    INTO v_max_syscosmosts
    FROM fact.cep_incidents;


    WITH new_error_events AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- Mirrors ADF split@ErrorEvents filter:
        --   connector module  →  any severity
        --   kiosk module      →  severity=error, category=order, type=validate
        -- DISTINCT ON natural key, latest syscosmosts wins
        -- NOT EXISTS mirrors ADF negate exists against GASfactCEPIncidents:
        --   id        == incidentkey
        --   token     == eventtoken
        -- EXISTS dim.organizationlocation mirrors ADF ExistingLocations check

        SELECT DISTINCT ON (
            ske.id,
            ske.token
        )
            ske.id,
            ske.application,
            ske.companyid,
            ske.locationid,
            ske.eventmodule,
            ske.eventcategory,
            ske.eventtype,
            ske.severity,
            ske.token,
            ske.eventinstant,
            ske.device,
            ske.data,
            ske.syscosmosts
        FROM stg.silver_kiosk_events            AS ske
        WHERE ske.syscosmosts   > v_max_syscosmosts
          AND (
              lower(ske.eventmodule) = 'connector'
              OR (
                  lower(ske.eventmodule)       = 'kiosk'
                  AND lower(ske.severity)      = 'error'
                  AND lower(ske.eventcategory) = 'order'
                  AND lower(ske.eventtype)     = 'validate'
              )
          )
          AND NOT EXISTS (
                SELECT 1
                FROM fact.cep_incidents          AS ci
                WHERE ci.incidentkey = ske.id :: BIGINT
                  AND ci.eventtoken  = ske.token
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organizationlocation    AS ol
                WHERE ol.locationid     = ske.locationid
                  AND ol.organizationid = ske.companyid
              )
        ORDER BY
            ske.id,
            ske.token,
            ske.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.cep_incidents (
        incidentkey,
        application,
        organizationid,
        locationid,
        deviceid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidenttype,
        incidentcount,
        eventinstant,
        firstoccurred,
        lastoccurred,
        notificationtypeid,
        incidentdata,
        syscosmosts,
        sysinserttime,
        severity
    )
    -- ── gemJobCEP left join mirrored here ──────────────────────
    -- ADF joins select2 (error events) LEFT JOIN gemCEPIncidents
    -- (Cosmos job='asa-failed-order') on:
    --   incidentkey == incidentid
    --   errortoken  == eventtoken
    --   eventcategory == eventcategory
    --   eventtype   == eventtype
    -- Incident metadata (counts, timestamps) comes from stg.silver_cep_incidents,
    -- which is expected to be pre-loaded from the gemCEPIncidents Cosmos container
    SELECT
        nee.id :: BIGINT                                                    AS incidentkey,
        nee.application,
        nee.companyid                                                       AS organizationid,
        nee.locationid,
        nee.device                                                          AS deviceid,
        nee.eventmodule,
        nee.eventcategory,
        nee.eventtype,
        nee.token                                                           AS eventtoken,
        sci.incidenttype,
        sci.incidentcount,
        nee.eventinstant,
        sci.firstoccurred,
        sci.lastoccurred,
        sci.notificationtypeid,
        nee.data                                                            AS incidentdata,
        nee.syscosmosts,
        NOW() :: TIMESTAMP                                                  AS sysinserttime,
        nee.severity
    FROM new_error_events                           AS nee
    LEFT JOIN stg.silver_cep_incidents              AS sci
        ON  sci.incidentid    = nee.id
        AND sci.eventtoken    = nee.token
        AND sci.eventcategory = nee.eventcategory
        AND sci.eventtype     = nee.eventtype;


    UPDATE fact.watermarktable
    SET ts            = (SELECT COALESCE(MAX(syscosmosts), 0) FROM fact.cep_incidents),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.cep_incidents'
      AND source             = 'gem';

END;
$$;


ALTER PROCEDURE fact.usp_silver_kiosk_events_to_fact_cep_incidents() OWNER TO citus;

--
-- TOC entry 1256 (class 1255 OID 3605479)
-- Name: usp_silver_kiosk_events_to_fact_deviceevent(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_kiosk_events_to_fact_deviceevent()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 600
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.deviceevent'
      AND source             = 'gem';

    WITH new_events AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- DISTINCT ON natural key, latest syscosmosts wins
        -- NOT EXISTS mirrors ADF negate exists against AnalyticsDbEvents:
        --   location == locationid
        --   token    == eventtoken
        --   category == datacategory
        --   type     == actiontype
        --   instant  == eventinstant
        -- EXISTS dim.organizationlocation mirrors ADF dimOrgLoc exists check
        --   and aligns with the FK constraint on fact.deviceevent

        SELECT DISTINCT ON (
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant
        )
            ske.application,
            ske.companyid,
            ske.locationid,
            ske.eventmodule,
            ske.eventcategory,
            ske.eventtype,
            ske.severity,
            ske.token,
            ske.eventinstant,
            ske.username,
            ske.userid,
            ske.device,
            ske.summary,
            ske.data,
            ske.syscosmosticks,
            ske.syscosmosts
        FROM stg.silver_kiosk_events            AS ske
        WHERE ske.syscosmosts   > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.deviceevent           AS de
                WHERE de.locationid   = ske.locationid
                  AND de.eventtoken   = ske.token
                  AND de.datacategory = ske.eventcategory
                  AND de.actiontype   = ske.eventtype
                  AND de.eventinstant = ske.eventinstant
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organizationlocation   AS ol
                WHERE ol.locationid     = ske.locationid
                  AND ol.organizationid = ske.companyid
              )
        ORDER BY
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant,
            ske.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.deviceevent (
        application,
        companyid,
        locationid,
        moduleid,
        datacategory,
        actiontype,
        severity,
        eventtoken,
        eventinstant,
        dateid,
        username,
        userid,
        deviceid,
        devicename,
        summary,
        eventdata,
        syscosmosticks,
        sysinserttime,
        syscosmosts
    )
    SELECT
        application,
        companyid,
        locationid,
        eventmodule                                                         AS moduleid,
        eventcategory                                                       AS datacategory,
        eventtype                                                           AS actiontype,
        severity,
        token                                                               AS eventtoken,
        eventinstant,
        REPLACE(REPLACE(SUBSTRING(eventinstant, 1, 13), '-', ''), 'T', '')
            :: INTEGER                                                      AS dateid,
        username,
        userid,
        device                                                              AS deviceid,
        device                                                              AS devicename,
        summary,
        data                                                                AS eventdata,
        syscosmosticks,
        NOW() :: TIMESTAMP                                                  AS sysinserttime,
        syscosmosts
    FROM new_events;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.deviceevent),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.deviceevent'
      AND source             = 'gem';
END;
$$;


ALTER PROCEDURE fact.usp_silver_kiosk_events_to_fact_deviceevent() OWNER TO citus;

--
-- TOC entry 997 (class 1255 OID 3605480)
-- Name: usp_silver_kiosk_events_to_fact_userbehaviour(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_kiosk_events_to_fact_userbehaviour()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    -- -10 buffer mirrors transactionheader pattern to catch late-arriving events
    SELECT COALESCE(ts, 1775002010) - 600
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.userbehaviour'
      AND source             = 'gem';


    WITH new_events AS (

        SELECT DISTINCT ON (
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant
        )
            ske.locationid,
            ske.token                               AS ordersessionidentifier,
            ske.eventcategory,
            ske.eventinstant,
            ske.eventtype,
            ske.data,
            ske.device,
            ske.syscosmosts
        FROM stg.silver_kiosk_events                AS ske
        WHERE ske.eventmodule      = 'kiosk'
          AND ske.eventcategory    = 'insight'
          AND ske.syscosmosts      > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.userbehaviour             AS ub
                WHERE ub.locationid             = ske.locationid
                  AND ub.ordersessionidentifier = ske.token
                  AND ub.eventcategory          = ske.eventcategory
                  AND ub.eventtype              = ske.eventtype
                  AND ub.eventinstant           = ske.eventinstant
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organization               AS o
                WHERE o.id = ske.locationid
              )
        ORDER BY
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant,
            ske.syscosmosts DESC NULLS LAST

    ), parsed_events AS (

        SELECT
            ne.locationid,
            ne.ordersessionidentifier,
            ne.eventcategory,
            ne.eventinstant,
            ne.eventtype,
            ne.syscosmosts,
            ne.device,
            fact.parse_iso_timestamp(ne.eventinstant)                             AS busdate,
            REPLACE(REPLACE(SUBSTRING(ne.eventinstant, 1, 13), '-', ''), 'T', '')
                :: INTEGER                                                         AS dateid,
            NULLIF(TRIM(ne.data::jsonb->>'view'),         '')                     AS view_name,
            COALESCE(NULLIF(TRIM(ne.data::jsonb->>'element'),   ''), 'None')      AS element_name,
            COALESCE(NULLIF(TRIM(ne.data::jsonb->>'elementId'), ''), 'None')      AS source_element_id,
            NULLIF(TRIM(ne.data::jsonb->>'quantity'), '')::INTEGER                AS quantity,
            NULLIF(TRIM(ne.data::jsonb->>'itemSessionId'), '')                    AS itemsessionidentifier
        FROM new_events ne
        WHERE ne.data IS NOT NULL
          AND ne.data <> ''

    ), enriched AS (

        SELECT
            pe.locationid,
            pe.ordersessionidentifier,
            pe.eventcategory,
            pe.eventinstant,
            pe.eventtype,
            pe.syscosmosts,
            pe.busdate,
            pe.dateid,
            pe.itemsessionidentifier,
            pe.quantity,
            ot.id                                   AS ordertype,
            dv.viewid                               AS viewidentifier,
            de.elementid                            AS elementidentifier,
            'None'  :: TEXT                         AS daypart,
            NOW()   :: TIMESTAMP                    AS createddate
        FROM parsed_events                          AS pe
        LEFT JOIN dim.ordertype                     AS ot
            ON  ot.locationid = pe.locationid
            AND ot.kioskid    = pe.device
        LEFT JOIN dim.view                          AS dv
            ON  dv.viewname   = pe.view_name
        LEFT JOIN dim.element                       AS de
            ON  de.elementname     = pe.element_name
            AND de.sourceelementid = pe.source_element_id

    )
    INSERT INTO fact.userbehaviour (
        id,
        busdate,
        locationid,
        dateid,
        daypart,
        ordertype,
        eventtype,
        ordersessionidentifier,
        viewidentifier,
        itemsessionidentifier,
        elementidentifier,
        quantity,
        createddate,
        syscosmosts,
        eventinstant,
        eventcategory
    )
    SELECT
        nextval('fact.userbehaviour_id_seq'),
        busdate :: TIMESTAMP AS busdate,
        locationid,
        dateid,
        daypart,
        ordertype,
        eventtype,
        ordersessionidentifier,
        viewidentifier,
        itemsessionidentifier,
        elementidentifier,
        quantity,
        createddate,
        syscosmosts,
        eventinstant,
        eventcategory
    FROM enriched;

END;
$$;


ALTER PROCEDURE fact.usp_silver_kiosk_events_to_fact_userbehaviour() OWNER TO citus;

--
-- TOC entry 1496 (class 1255 OID 3629703)
-- Name: usp_silver_modifier_impressions_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_modifier_impressions_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_watermark_impressions     BIGINT;

BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_watermark_impressions
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.modifier_impressions'
      AND source             = 'nge';

    WITH delta_impressions AS (
        SELECT DISTINCT ON (
            locationid,
            transactionheaderid,
            menuitemid,
            modifierid,
            position
        )
            locationid,
            transactionheaderid,
            ordersessionid,
            orderid,
            menuitemid,
            modifierid,
            parentmodifierid                        AS parent_modifier_id,
            selection_type,
            modifier_impressions_nesting_depth      AS nesting_depth,
            position,
            score :: NUMERIC(5,3)                   AS score,
            strategy,
            modifier_impressions_context            AS context,
            selected,
            pre_deselected,
            confirmed_removed,
            pre_selected,
            businessdate :: DATE                    AS businessdate,
            orderdateutc,
            frequentcustomerid,
            syscosmosts,
            sysinserttime
        FROM stg.silver_modifier_impressions
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND modifierid IS NOT NULL
          AND syscosmosts > v_watermark_impressions
        ORDER BY
            locationid,
            transactionheaderid,
            menuitemid,
            modifierid,
            position,
            syscosmosts DESC
    )
    INSERT INTO fact.modifier_impressions (
        locationid,
        transactionheaderid,
        ordersessionid,
        orderid,
        menuitemid,
        modifierid,
        parent_modifier_id,
        selection_type,
        nesting_depth,
        position,
        score,
        strategy,
        context,
        selected,
        pre_deselected,
        confirmed_removed,
        pre_selected,
        businessdate,
        orderdatelocal,
        frequentcustomerid,
        syscosmosts,
        sysinserttime
    )
    SELECT
        d.locationid,
        d.transactionheaderid,
        d.ordersessionid,
        d.orderid,
        d.menuitemid,
        d.modifierid,
        d.parent_modifier_id,
        d.selection_type,
        d.nesting_depth,
        d.position,
        d.score,
        d.strategy,
        d.context,
        d.selected,
        d.pre_deselected,
        d.confirmed_removed,
        d.pre_selected,
        d.businessdate,
        fact.parse_iso_timestamp(d.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE ol.timezone AS orderdatelocal,
        d.frequentcustomerid,
        d.syscosmosts,
        NOW() :: TIMESTAMP                                                               AS sysinserttime
    FROM delta_impressions d
    LEFT JOIN dim.organization AS ol
           ON ol.id       = d.locationid
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.modifier_impressions mi
        WHERE mi.locationid          = d.locationid
          AND mi.transactionheaderid = d.transactionheaderid
          AND mi.menuitemid          = d.menuitemid
          AND mi.modifierid          = d.modifierid
          AND mi.position            = d.position
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_impressions),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.modifier_impressions'
      AND source             = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_silver_modifier_impressions_to_fact() OWNER TO citus;

--
-- TOC entry 745 (class 1255 OID 3623322)
-- Name: usp_silver_modifier_interactions_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_modifier_interactions_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_watermark_interactions    BIGINT;
    v_watermark_options         BIGINT;

BEGIN

    -- ----------------------------------------------------------
    -- Capture both watermarks upfront before any DML
    -- ----------------------------------------------------------
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_watermark_interactions
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.modifier_interactions'
      AND source             = 'nge-Interactions';

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_watermark_options
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.modifier_interactions'
      AND source             = 'nge-Options';

    -- ==============================================================
    -- Part 1: Behavioral interaction events
    --         Source  : stg.silver_modifier_interactions
    --                   (pre-flattened from upsellInformation.modifierInteractions)
    --         sourceid: 5
    -- ==============================================================
    WITH delta_interactions AS (
        SELECT DISTINCT ON (
            transactionheaderid,
            modifiergroupid,
            modifierid,
            modifier_interactions_action,
            modifier_interactions_recorded_at
        )
            locationid,
            transactionheaderid,
            ordersessionid,
            orderid,
            menuitemid,
            modifierid,
            modifiergroupid,
            parent_modifier_id,
            selection_type,
            modifier_interactions_action            AS action,
            modifier_interactions_recorded_at       AS session_recorded_at,
            modifier_interactions_nesting_depth     AS nesting_depth,
            businessdate :: DATE                    AS businessdate,
            orderdateutc,
            frequentcustomerid,
            syscosmosts,
            sysinserttime
        FROM stg.silver_modifier_interactions
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND syscosmosts > v_watermark_interactions
        ORDER BY
            transactionheaderid,
            modifiergroupid,
            modifierid,
            modifier_interactions_action,
            modifier_interactions_recorded_at,
            syscosmosts DESC
    ),
    trxn_enrichment AS (
        SELECT
            di.locationid,
            di.transactionheaderid,
            di.ordersessionid,
            di.orderid,
            imd.itemid                              AS orderitemid,
            di.menuitemid,
            di.modifiergroupid,
            di.modifierid,
            imd.modifiername,
            di.parent_modifier_id,
            di.nesting_depth,
            imd.modifierquantity,
            imd.modifierprice,
            imd.freequantity,
            di.selection_type,
            di.action,
            di.session_recorded_at,
            di.businessdate,
            ti.orderdatelocal,                       
            di.frequentcustomerid,
            di.syscosmosts,
            di.sysinserttime
        FROM delta_interactions di
        LEFT JOIN fact.transactionitem ti
               ON ti.locationid          = di.locationid
              AND ti.transactionheaderid = di.transactionheaderid
              AND ti.dimmenuitemid       = di.menuitemid
        LEFT JOIN fact.itemmodifier imd
               ON imd.transactionheaderid = di.transactionheaderid
              AND imd.itemid             = ti.itemid
              AND imd.modifiergroupid    = di.modifiergroupid
              AND imd.modifierid         = di.modifierid
        WHERE NOT EXISTS (
            SELECT 1
            FROM fact.modifier_interactions mint
            WHERE mint.transactionheaderid  = di.transactionheaderid
              AND mint.modifiergroupid      = di.modifiergroupid
              AND mint.modifierid           = di.modifierid
              AND mint.action               = di.action
              AND mint.session_recorded_at  = di.session_recorded_at
        )
    )
    INSERT INTO fact.modifier_interactions
    SELECT *,
           NULL :: TIMESTAMP  AS sysupdatetime,
           5                  AS sourceid
    FROM trxn_enrichment;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_interactions WHERE sourceid = 5),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.modifier_interactions'
      AND source             = 'nge-Interactions';


    -- ==============================================================
    -- Part 2: Options-derived interactions (inferred action/selection_type
    --         from ordered modifiers in fact.itemmodifier + dim lookups)
    --         Source  : fact.itemmodifier (unchanged)
    --         sourceid: 6
    -- ==============================================================
    WITH delta_modifier_trxns AS (
        SELECT *
        FROM fact.itemmodifier im
        WHERE locationid LIKE 'loc-%'
          AND (syscosmosts > v_watermark_options OR syscosmosts IS NULL)
          AND NOT EXISTS (
                SELECT 1
                FROM fact.modifier_interactions mint
                WHERE mint.locationid          = im.locationid
                  AND mint.transactionheaderid = im.transactionheaderid
          )
    ),
    modfr_enrichment AS (
        SELECT
            mt.locationid,
            mt.transactionheaderid,
            ti.ordersessionid,
            ti.orderid,
            ti.itemid                               AS orderitemid,
            ti.dimmenuitemid                        AS menuitemid,
            mt.modifiergroupid,
            mt.modifierid,
            mt.modifiername,
            NULL :: TEXT                            AS parent_modifier_id,
            NULL :: INTEGER                         AS nesting_depth,
            mt.modifierquantity,
            mt.modifierprice,
            mt.freequantity,
            CASE WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 THEN 'optional'
                 WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 THEN 'required'
                 WHEN mgm.is_default = TRUE                                                      THEN 'default'
            END                                     AS selection_type,
            CASE WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 AND mt.modifierquantity >= 1 THEN 'added'
                 WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'selected'
                 WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'kept'
                 WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity = 0  THEN 'removed'
            END                                     AS action,
            NULL :: TEXT                            AS session_recorded_at,
            mt.businessdate,
            ti.orderdatelocal,
            ti.frequentcustomerid,
            mt.syscosmosts,
            mt.sysinserttime
        FROM delta_modifier_trxns mt
        LEFT JOIN dim.modifier_group_mapping mgm
               ON mgm.modifiergroupid = mt.modifiergroupid
              AND mgm.modifierid      = mt.modifierid
        LEFT JOIN dim.modifier_group mg
               ON mg.modifiergroupid  = mt.modifiergroupid
        LEFT JOIN fact.transactionitem ti
               ON ti.transactionheaderid = mt.transactionheaderid
              AND ti.itemid              = mt.itemid
    )
    INSERT INTO fact.modifier_interactions
    SELECT *,
           NULL :: TIMESTAMP  AS sysupdatetime,
           6                  AS sourceid
    FROM modfr_enrichment;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_interactions WHERE sourceid = 6),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.modifier_interactions'
      AND source             = 'nge-Options';

END;
$$;


ALTER PROCEDURE fact.usp_silver_modifier_interactions_to_fact() OWNER TO citus;

--
-- TOC entry 933 (class 1255 OID 3623321)
-- Name: usp_silver_modifier_recommendations_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_modifier_recommendations_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_max_syscosmosts BIGINT;

BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.modifier_recommendations'
      AND source             = 'nge';

    WITH delta AS (
        -- Deduplicate: keep latest snapshot per (locationid, transactionheaderid)
        SELECT DISTINCT ON (locationid, transactionheaderid)
            locationid,
            transactionheaderid,
            ordersessionid,
            orderid,
            modifier_impressions,
            modifier_interactions,      -- intentionally nullable; CosmosDB filter only guards impressions
            businessdate :: DATE        AS businessdate,
            orderdateutc,
            frequentcustomerid,
            syscosmosts
        FROM stg.silver_modifier_recommendations
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND syscosmosts        >  v_max_syscosmosts
          -- mirror CosmosDB source filter: skip orders with no impressions data
          AND modifier_impressions IS NOT NULL
          AND modifier_impressions != '[]'
        ORDER BY locationid, transactionheaderid, syscosmosts DESC
    )
    INSERT INTO fact.modifier_recommendations (
        locationid,
        transactionheaderid,
        ordersessionid,
        orderid,
        modifier_impressions,
        modifier_interactions,
        businessdate,
        orderdateutc,
        orderdatelocal,
        frequentcustomerid,
        syscosmosts,
        sysinserttime
    )
    SELECT
        d.locationid,
        d.transactionheaderid,
        d.ordersessionid,
        d.orderid,
        d.modifier_impressions :: JSONB,
        d.modifier_interactions :: JSONB,
        d.businessdate,
        fact.parse_iso_timestamp(d.orderdateutc)    AS orderdateutc,
        th.orderdatelocal                           AS orderdatelocal,
        d.frequentcustomerid,
        d.syscosmosts,
        NOW() :: TIMESTAMP                          AS sysinserttime
    FROM delta d
    -- Mirror ADF ExistingOrders step: only load if the parent order is already in the fact layer
    INNER JOIN fact.transactionheader th
            ON th.locationid          = d.locationid
           AND th.transactionheaderid = d.transactionheaderid
    -- Mirror ADF NewModfrRecs step (negate:true): skip if already recorded
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.modifier_recommendations mr
        WHERE mr.locationid          = d.locationid
          AND mr.transactionheaderid = d.transactionheaderid
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_recommendations),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.modifier_recommendations'
      AND source             = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_silver_modifier_recommendations_to_fact() OWNER TO citus;

--
-- TOC entry 677 (class 1255 OID 3553218)
-- Name: usp_silver_transaction_header_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_transaction_header_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 600
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

        SELECT DISTINCT ON (locationid, transactionheaderid)
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
        ORDER BY locationid, transactionheaderid, orderdateutc DESC

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
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionheader WHERE sourceid = 1),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_silver_transaction_header_to_fact() OWNER TO citus;

--
-- TOC entry 1447 (class 1255 OID 3600414)
-- Name: usp_silver_transaction_item_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_transaction_item_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 600
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionitem'
      AND source             = 'nge';

    WITH delta_items AS (

        SELECT * FROM (
            SELECT DISTINCT ON (
                transactionheaderid,
                COALESCE(orderitemid, itemsessionid, menuitemid),
                itemname
            )
                transactionheaderid,
                orderid,
                locationid,
                ordersessionid,
                itemsessionid,
                COALESCE(orderitemid, itemsessionid, menuitemid)                    AS itemid,
                menuitemid                                                           AS raw_menuitemid,
                itemname,
                itemquantity                :: SMALLINT                             AS itemquantity,
                usd_itemunitprice           :: NUMERIC(12,3)                        AS itemunitprice,
                categoryid                                                           AS raw_categoryid,
                (NULLIF(items_upsell_source, '') :: json ->> 'upsellLevelType')     AS upselllevel,
                (NULLIF(items_upsell_source, '') :: json ->> 'upsellPromptItemId')  AS upsellpromptitemid,
                NULL :: TEXT                                                         AS comboid,
                'item' :: TEXT                                                       AS itemtype,
                businessdate                :: DATE                                 AS businessdate,
                fact.parse_iso_timestamp(orderdateutc)                              AS orderdateutc,
                frequentcustomerid,
                syscosmosts
            FROM stg.silver_transaction_item
            WHERE syscosmosts > v_max_syscosmosts
              AND (is_test_order = false OR is_test_order IS NULL)
            ORDER BY
                transactionheaderid,
                COALESCE(orderitemid, itemsessionid, menuitemid),
                itemname,
                syscosmosts DESC
        ) regular_items

        UNION ALL

        SELECT * FROM (
            SELECT DISTINCT ON (
                transactionheaderid,
                combo_order_item_id,
                combo_name
            )
                transactionheaderid,
                orderid,
                locationid,
                ordersessionid,
                combo_item_session_id                                                AS itemsessionid,
                combo_order_item_id                                                  AS itemid,
                NULL :: TEXT                                                         AS raw_menuitemid,
                combo_name                                                           AS itemname,
                combo_quantity              :: SMALLINT                              AS itemquantity,
                (cents_combo_unit_price / 100.0) :: NUMERIC(12,3)                    AS itemunitprice,
                NULL :: TEXT                                                         AS raw_categoryid,
                (NULLIF(combo_upsell_source, '') :: json ->> 'upsellLevelType')      AS upselllevel,
                (NULLIF(combo_upsell_source, '') :: json ->> 'upsellPromptItemId')   AS upsellpromptitemid,
                combo_id                                                             AS comboid,
                'combo' :: TEXT                                                      AS itemtype,
                businessdate                :: DATE                                  AS businessdate,
                fact.parse_iso_timestamp(orderdateutc)                               AS orderdateutc,
                frequentcustomerid,
                syscosmosts
            FROM stg.silver_transaction_combo_items
            WHERE syscosmosts > v_max_syscosmosts
              AND (is_test_order = false OR is_test_order IS NULL)
            ORDER BY
                transactionheaderid,
                combo_order_item_id,
                combo_name,
                syscosmosts DESC
        ) combo_headers

        UNION ALL

        SELECT * FROM (
            SELECT DISTINCT ON (
                transactionheaderid,
                component_item_order_item_id,
                component_item_name
            )
                transactionheaderid,
                orderid,
                locationid,
                ordersessionid,
                component_item_session_id                                            AS itemsessionid,
                component_item_order_item_id                                         AS itemid,
                component_item_menu_item_id                                          AS raw_menuitemid,
                component_item_name                                                  AS itemname,
                component_item_quantity     :: SMALLINT                             AS itemquantity,
                component_item_unit_price   :: NUMERIC(12,3)                        AS itemunitprice,
                NULL :: TEXT                                                         AS raw_categoryid,
                (NULLIF(component_item_upsell_source, '') :: json ->> 'upsellLevelType')    AS upselllevel,
                (NULLIF(component_item_upsell_source, '') :: json ->> 'upsellPromptItemId') AS upsellpromptitemid,
                combo_id                                                             AS comboid,
                'combocomponent' :: TEXT                                             AS itemtype,
                businessdate                :: DATE                                 AS businessdate,
                fact.parse_iso_timestamp(orderdateutc)                              AS orderdateutc,
                frequentcustomerid,
                syscosmosts
            FROM stg.silver_transaction_combo_items
            WHERE syscosmosts > v_max_syscosmosts
              AND (is_test_order = false OR is_test_order IS NULL)
              AND component_item_order_item_id IS NOT NULL
              AND component_item_name          IS NOT NULL
            ORDER BY
                transactionheaderid,
                component_item_order_item_id,
                component_item_name,
                syscosmosts DESC
        ) combo_components

    ), resolved AS MATERIALIZED (

        SELECT
            di.transactionheaderid,
            di.orderid,
            di.locationid,
            di.ordersessionid,
            di.itemsessionid,
            di.itemid,
            di.itemname,
            di.itemquantity,
            di.itemunitprice,
            di.raw_menuitemid                                                       AS dimmenuitemid,
            mi.id                                                                   AS menuitemid,
            ic.id                                                                   AS categoryid,
            di.upselllevel,
            di.upsellpromptitemid,
            di.comboid,
            di.itemtype,
            di.businessdate,
            di.orderdateutc,
            di.frequentcustomerid,
            di.syscosmosts
        FROM delta_items AS di
        LEFT JOIN dim.menuitem AS mi
            ON  mi.menuitemid  = di.raw_menuitemid
        LEFT JOIN dim.itemcategory AS ic
            ON  ic.locationid  = di.locationid
            AND ic.categoryid  = di.raw_categoryid

    ), gem_events AS (

        -- Scoped to only sessions present in the current delta batch
        -- to avoid a full scan of fact.userbehaviour
        SELECT
            ub.locationid,
            ub.token,
            ub.eventtype,
            fact.parse_iso_timestamp(eventinstant) :: TIMESTAMP AS eventtime
        FROM stg.silver_kiosk_events ub
        WHERE ub.eventtype IN (
            'ItemCustomizeClicked', 'CustomizeItemSelected', 'ComboCustomizeClicked',
            'RegularItemSelected',  'ComboComponentItemSelected', 'AddToCartClicked',
            'ComboSizeSelected',    'ComboItemSelected',          'AddAsIsSelected'
        )
          AND EXISTS (
              SELECT 1
              FROM resolved r
              WHERE r.ordersessionid = ub.token
                AND r.locationid     = ub.locationid
          )

    ), item_timing AS (

        SELECT
            r.transactionheaderid,
            r.itemid,
            r.itemname,
            r.itemtype,
            r.ordersessionid,
            r.itemsessionid,
            MAX(CASE WHEN ge.eventtype IN ('AddToCartClicked', 'AddAsIsSelected')
                THEN ge.eventtime END)                                              AS addtocarttime,
            MAX(CASE WHEN ge.eventtype IN (
                'RegularItemSelected', 'ComboComponentItemSelected',
                'ComboComponentSelected', 'ComboItemSelected')
                THEN ge.eventtime END)                                              AS itemselectedtime,
            SUM(CASE WHEN ge.eventtype IN (
                'CustomizeItemSelected', 'ComboCustomizeClicked', 'ItemCustomizeClicked')
                THEN 1 ELSE 0 END)                                                 AS customize_count,
            SUM(CASE WHEN ge.eventtype = 'ComboSizeSelected'
                THEN 1 ELSE 0 END)                                                 AS upgrade_count
        FROM resolved r
        LEFT JOIN gem_events ge
            ON  ge.token = r.ordersessionid
            AND ge.locationid             = r.locationid
        GROUP BY
            r.transactionheaderid, r.itemid, r.itemname,
            r.itemtype, r.ordersessionid, r.itemsessionid

    )
    INSERT INTO fact.transactionitem (
        transactionheaderid,
        categoryid,
        menuitemid,
        itemid,
        comboid,
        ordersessionid,
        itemsessionid,
        itemname,
        itemquantity,
        itemunitprice,
        upselllevel,
        upsellpromptitemid,
        orderid,
        itemtype,
        customize,
        upgrade,
        asis,
        itemselectedtime,
        addtocarttime,
        totaltime,
        orderdateutc,
        orderdatelocal,
        businessdate,
        sysinserttime,
        sysupdatetime,
        locationid,
        dimmenuitemid,
        syscosmosts,
        frequentcustomerid
    )
    SELECT DISTINCT ON (r.transactionheaderid, r.itemid, r.itemname)
        r.transactionheaderid,
        r.categoryid,
        r.menuitemid,
        r.itemid,
        r.comboid,
        r.ordersessionid,
        r.itemsessionid,
        r.itemname,
        r.itemquantity,
        r.itemunitprice,
        r.upselllevel,
        r.upsellpromptitemid,
        r.orderid,
        r.itemtype,
        COALESCE(t.customize_count, 0) >= 1                                         AS customize,
        COALESCE(t.upgrade_count,   0) >= 1                                         AS upgrade,
        COALESCE(t.customize_count, 0) <  1                                         AS asis,
        t.itemselectedtime,
        t.addtocarttime,
        ABS(COALESCE(
            EXTRACT(EPOCH FROM (t.addtocarttime - t.itemselectedtime)) :: NUMERIC(7,3),
            0
        ))                                                                           AS totaltime,
        r.orderdateutc,
        (r.orderdateutc :: TIMESTAMPTZ AT TIME ZONE org.timezone) :: TIMESTAMP      AS orderdatelocal,
        r.businessdate,
        NOW() :: TIMESTAMP                                                           AS sysinserttime,
        NOW() :: TIMESTAMP                                                           AS sysupdatetime,
        r.locationid,
        r.dimmenuitemid,
        r.syscosmosts,
        r.frequentcustomerid
    FROM resolved AS r
    LEFT JOIN item_timing AS t
        ON  t.transactionheaderid = r.transactionheaderid
        AND t.itemid              = r.itemid
        AND t.itemname            = r.itemname
        AND t.itemtype            = r.itemtype
        AND t.ordersessionid      = r.ordersessionid
        AND t.itemsessionid       = r.itemsessionid
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = r.locationid
        AND th.transactionheaderid = r.transactionheaderid
    LEFT JOIN dim.organization AS org
        ON  org.id = r.locationid
    --WHERE NOT EXISTS (
    --    SELECT 1
    --    FROM fact.transactionitem AS ti
    --    WHERE ti.transactionheaderid = r.transactionheaderid
    --      AND ti.itemid              = r.itemid
    --      AND ti.itemname            = r.itemname
    --)
    ORDER BY r.transactionheaderid, r.itemid, r.itemname, r.orderdateutc DESC
    ON CONFLICT (transactionheaderid, itemid, itemname)
    DO UPDATE SET
        customize        = EXCLUDED.customize,
        upgrade          = EXCLUDED.upgrade,
        asis             = EXCLUDED.asis,
        itemselectedtime = EXCLUDED.itemselectedtime,
        addtocarttime    = EXCLUDED.addtocarttime,
        totaltime        = EXCLUDED.totaltime,
        sysupdatetime    = NOW() :: TIMESTAMP
    WHERE
        fact.transactionitem.itemselectedtime IS NULL
        OR fact.transactionitem.addtocarttime IS NULL;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionitem WHERE transactionheaderid LIKE 'ordevt-%'),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionitem'
      AND source             = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_silver_transaction_item_to_fact() OWNER TO citus;

--
-- TOC entry 973 (class 1255 OID 3553220)
-- Name: usp_silver_transaction_payment_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_transaction_payment_to_fact()
    LANGUAGE plpgsql
    AS $$


DECLARE
    v_max_syscosmosts BIGINT;

BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionpayment'
      AND source             = 'nge';


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
    WHERE EXISTS (
            SELECT 1
            FROM fact.transactionheader AS th
            WHERE th.locationid          = delta.locationid
              AND th.transactionheaderid = delta.transactionheaderid
    )
    AND NOT EXISTS (
            SELECT 1
            FROM fact.transactionpayment AS tp
            WHERE tp.locationid          = delta.locationid
              AND tp.transactionheaderid = delta.transactionheaderid
    );
    --ON CONFLICT (locationid, transactionheaderid, paymentintegrationid, paymentid)
    --DO NOTHING;  -- payments are immutable once recorded

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionpayment),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionpayment'
      AND source             = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_silver_transaction_payment_to_fact() OWNER TO citus;

--
-- TOC entry 1110 (class 1255 OID 3629704)
-- Name: usp_silver_transaction_refunds_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_transaction_refunds_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_watermark     BIGINT;

BEGIN

    -- Capture watermark
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_watermark
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionrefunds'
      AND source             = 'nge';

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
            ON th.locationid = d.locationid 
           AND th.orderid    = d.orderid
    -- mirror ADF NewRefunds step (negate:true): skip if already recorded
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.transactionrefunds tr
        WHERE tr.locationid = d.locationid
          AND tr.transactionheaderid = d.transactionheaderid
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
                        END,
        updateddate   = NOW() :: TIMESTAMP
    FROM latest_refunds r
    WHERE fact.transactionheader.locationid = r.locationid
      AND fact.transactionheader.orderid    = r.orderid
      AND r.rn = 1;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionrefunds),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionrefunds'
      AND source             = 'nge';

END;
$$;


ALTER PROCEDURE fact.usp_silver_transaction_refunds_to_fact() OWNER TO citus;

--
-- TOC entry 1113 (class 1255 OID 3607278)
-- Name: usp_silver_upsell_recommendations_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_silver_upsell_recommendations_to_fact()
    LANGUAGE plpgsql
    AS $$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.recommendations'
      AND source             = 'nge';


    WITH delta AS (

        SELECT DISTINCT ON (locationid, transactionheaderid, recommendationid)
            transactionheaderid,
            locationid,
            recommendationid,
            NULLIF(offered_items, '')  :: JSONB                 AS offereditems,
            NULLIF(selected_items, '') :: JSONB                 AS selecteditems,
            CASE
                WHEN selected_items IS NULL
                  OR selected_items  IN ('', '[]', 'null')      THEN false
                ELSE true
            END                                                  AS isconverted,
            prompttimestamp,
            syscosmosts
        FROM stg.silver_upsell_recommendations
        WHERE syscosmosts > v_max_syscosmosts
          AND (is_test_order = false OR is_test_order IS NULL)
          AND recommendationid IS NOT NULL
          AND offered_items    IS NOT NULL
        ORDER BY
            locationid,
            transactionheaderid,
            recommendationid,
            syscosmosts DESC

    )
    INSERT INTO fact.recommendations (
        transactionheaderid,
        locationid,
        recommendationid,
        offereditems,
        selecteditems,
        isconverted,
        prompttimestamp,
        sysinserttime,
        syscosmosts
    )
    SELECT
        d.transactionheaderid,
        d.locationid,
        d.recommendationid,
        d.offereditems,
        d.selecteditems,
        d.isconverted,
        d.prompttimestamp,
        NOW() :: TIMESTAMP      AS sysinserttime,
        d.syscosmosts
    FROM delta d
    INNER JOIN fact.transactionheader th
        ON  th.locationid          = d.locationid
        AND th.transactionheaderid = d.transactionheaderid
    ON CONFLICT (locationid, transactionheaderid, recommendationid)
    DO UPDATE SET
        selecteditems = EXCLUDED.selecteditems,
        isconverted   = EXCLUDED.isconverted,
        syscosmosts   = EXCLUDED.syscosmosts
    WHERE
        fact.recommendations.isconverted IS DISTINCT FROM true;

END;
$$;


ALTER PROCEDURE fact.usp_silver_upsell_recommendations_to_fact() OWNER TO citus;

--
-- TOC entry 1375 (class 1255 OID 3688570)
-- Name: usp_stg_gem_failed_order_job_notifications_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_stg_gem_failed_order_job_notifications_to_fact()
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1767225610) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.gem_failed_order_job_notifications'
      AND source             = 'gem-Job';


    WITH new_notifications AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- DISTINCT ON natural key, latest syscosmosts wins
        -- NOT EXISTS deduplicates against fact on:
        --   incidentid == incidentid
        --   eventtoken == eventtoken

        SELECT DISTINCT ON (
            stg.incidentid,
            stg.eventtoken
        )
            stg.incidentid,
            stg.application,
            stg.organizationid,
            stg.locationid,
            stg.eventmodule,
            stg.eventcategory,
            stg.eventtype,
            stg.eventtoken,
            stg.incidentcount,
            stg.firstoccurred,
            stg.lastoccurred,
            stg.incidenttype,
            stg.notificationtypeid,
            stg.syscosmosts
        FROM stg.gem_failed_order_job_notifications     AS stg
        WHERE stg.syscosmosts   > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.gem_failed_order_job_notifications    AS f
                WHERE f.incidentid = stg.incidentid :: BIGINT
                  AND f.eventtoken = stg.eventtoken
              )
        ORDER BY
            stg.incidentid,
            stg.eventtoken,
            stg.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.gem_failed_order_job_notifications (
        incidentid,
        application,
        organizationid,
        locationid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidentcount,
        firstoccurred,
        lastoccurred,
        incidenttype,
        notificationtypeid,
        syscosmosts,
        sysinserttime
    )
    SELECT
        incidentid :: BIGINT,
        application,
        organizationid,
        locationid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidentcount,
        firstoccurred,
        lastoccurred,
        incidenttype,
        notificationtypeid,
        syscosmosts,
        NOW() :: TIMESTAMP      AS sysinserttime
    FROM new_notifications;


    UPDATE fact.watermarktable
    SET ts            = (SELECT COALESCE(MAX(syscosmosts), 0) FROM fact.gem_failed_order_job_notifications),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.gem_failed_order_job_notifications'
      AND source             = 'gem-Job';

END;
$$;


ALTER PROCEDURE fact.usp_stg_gem_failed_order_job_notifications_to_fact() OWNER TO citus;

--
-- TOC entry 1403 (class 1255 OID 3613228)
-- Name: usp_stg_occasionsurveydetail_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_stg_occasionsurveydetail_to_fact()
    LANGUAGE plpgsql
    AS $_$

DECLARE
    v_max_syscosmosts_nge   BIGINT;
    v_max_syscosmosts_gem   BIGINT;
BEGIN

    -- Separate watermarks to avoid one source suppressing the other
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts_nge
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.occasionsurveydetail'
      AND source             = 'nge';

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts_gem
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.occasionsurveydetail'
      AND source             = 'gem';


    -- ================================================================
    -- Stream 1: NGE Survey Feedbacks (sourceid = 1)     [UNCHANGED]
    --
    -- Dedup key  : (locationid, surveytransid, orderid)
    -- Lookups    : dim.organizationlocation → organizationid
    --              dim.occasionsurvey       → validates survey exists
    -- Gate       : fact.transactionheader INNER JOIN (orderstatus = 'order-placed')
    -- ordersessionid resolved from transactionheader (not in Cosmos NGE source)
    -- ================================================================
    INSERT INTO fact.occasionsurveydetail (
        organizationid,
        locationid,
        dateid,
        surveyid,
        surveytransid,
        orderid,
        ordersessionid,
        surveyrating,
        surveytransstatus,
        surveycompletedtimestamp,
        surveylocaltimestamp,
        surveytype,
        sysinserttime,
        syscosmosts,
        sourceid
    )
    SELECT DISTINCT ON (stg.locationid, stg.surveytransid, stg.orderid)
        ol.organizationid,
        stg.locationid,
        stg.dateid,
        stg.surveyid,
        stg.surveytransid,
        stg.orderid,
        COALESCE(stg.ordersessionid, th.ordersessionid)                     AS ordersessionid,
        stg.surveyrating,
        stg.surveytransstatus,
        stg.surveycompletedtimestamp,
        stg.surveylocaltimestamp,
        COALESCE(
            stg.surveytype,
            CASE WHEN stg.surveyrating ~ '^\d+$' THEN 1 ELSE 2 END
        )                                                                   AS surveytype,
        now() :: TIMESTAMP                                                  AS sysinserttime,
        stg.syscosmosts,
        1                                                                   AS sourceid
    FROM stg.fact_occasionsurveydetail AS stg
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = stg.locationid
        AND th.transactionheaderid = stg.orderid
        AND th.orderstatus         = 'order-placed'
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = stg.locationid
        AND ol.organizationtype = 0
    INNER JOIN dim.occasionsurvey AS os
        ON  os.organizationid = ol.organizationid
        AND os.surveyid       = stg.surveyid
    WHERE stg.syscosmosts   > v_max_syscosmosts_nge
    AND NOT EXISTS (
        SELECT 1
        FROM fact.occasionsurveydetail AS f
        WHERE f.locationid      = stg.locationid
            AND f.surveytransid = stg.surveytransid
            AND f.orderid       = stg.orderid
            AND f.sourceid      = 2
    );

    -- ================================================================
    -- Stream 2: GEM Skipped Surveys (sourceid = 2)      [MODIFIED]
    --
    -- Source     : stg.silver_kiosk_events (replaces stg.fact_occasionsurveydetail)
    -- Dedup key  : (locationid, ordersessionid) WHERE sourceid = 2
    -- Lookups    : dim.organizationlocation → organizationid
    -- Gate       : fact.transactionheader INNER JOIN on ordersessionid
    --              → resolves orderid = transactionheaderid
    --              → validates orderstatus = 'order-placed'
    -- Sparse insert: no surveyid, surveyrating, surveytransstatus, surveytype
    -- ================================================================
    WITH delta_skipped AS (

        -- Deduplicate within the incoming batch.
        -- A session could theoretically produce multiple 'skipped' events;
        -- keep the latest one by syscosmosts.
        SELECT DISTINCT ON (locationid, token)
            locationid,
            token           AS ordersessionid,
            eventinstant    AS surveycompletedtimestamp,
            syscosmosts
        FROM stg.silver_kiosk_events
        WHERE eventmodule               = 'kiosk'
          AND eventcategory             = 'Survey'
          AND eventtype                 = 'SurveySkipped'
          AND token                     > ''
          AND syscosmosts               > v_max_syscosmosts_gem
        ORDER BY locationid, token, syscosmosts DESC

    )
    INSERT INTO fact.occasionsurveydetail (
        organizationid,
        locationid,
        orderid,
        ordersessionid,
        surveycompletedtimestamp,
        sysinserttime,
        syscosmosts,
        sourceid
    )
    SELECT
        ol.organizationid,
        ds.locationid,
        th.transactionheaderid          AS orderid,
        ds.ordersessionid,
        ds.surveycompletedtimestamp,
        now() :: TIMESTAMP              AS sysinserttime,
        ds.syscosmosts,
        2                               AS sourceid
    FROM delta_skipped AS ds
    -- Resolves orderid and validates the order exists and was placed
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid     = ds.locationid
        AND th.ordersessionid = ds.ordersessionid
        AND th.orderstatus    = 'order-placed'
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = ds.locationid
        AND ol.organizationtype = 0
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.occasionsurveydetail AS f
        WHERE f.locationid    = ds.locationid
          AND f.ordersessionid = ds.ordersessionid
          AND f.sourceid      = 2
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.occasionsurveydetail WHERE sourceid = 1),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.occasionsurveydetail'
      AND source             = 'nge';


    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.occasionsurveydetail WHERE sourceid = 2),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.occasionsurveydetail'
      AND source             = 'gem';



END;
$_$;


ALTER PROCEDURE fact.usp_stg_occasionsurveydetail_to_fact() OWNER TO citus;

--
-- TOC entry 1237 (class 1255 OID 630014)
-- Name: usp_update_datetime_fields(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE PROCEDURE fact.usp_update_datetime_fields()
    LANGUAGE plpgsql
    AS $$
BEGIN

UPDATE fact.transactionheader 
   SET orderdatelocal = ((transactionheader.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE l.timezone),
       updateddate    = NOW()
FROM dim.organization AS l
WHERE (l.id = transactionheader.locationid) AND (transactionheader.orderdatelocal IS NULL);

UPDATE fact.transactionheader 
   SET orderdatelocal = ((transactionheader.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE 'America/New_York'::text),
       updateddate    = NOW()
WHERE (transactionheader.orderdatelocal IS NULL);

UPDATE fact.transactionheader 
   SET dateid      = (to_char(transactionheader.orderdatelocal, 'YYYYMMDDHH24'::text))::integer,
       updateddate = NOW()
WHERE (transactionheader.dateid IS NULL);

UPDATE fact.transactionheader 
   SET businessdate = (transactionheader.orderdatelocal)::date,
       updateddate = NOW()
WHERE (transactionheader.businessdate IS NULL);

UPDATE fact.transactionheader 
   SET abtestid = abtests.abtestid
FROM dim.abtests
WHERE (abtests.ordersessionid = transactionheader.ordersessionid) AND (transactionheader.abtestid IS NULL);



UPDATE fact.transactionitem 
   SET orderdatelocal = ((transactionitem.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE l.timezone),
       sysupdatetime  = NOW()
FROM dim.organization AS l
WHERE (l.id = transactionitem.locationid) AND (transactionitem.orderdatelocal IS NULL);

UPDATE fact.transactionitem
   SET orderdatelocal = ((transactionitem.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE 'America/New_York'::text),
       sysupdatetime  = NOW()
WHERE (transactionitem.orderdatelocal IS NULL);

UPDATE fact.transactionitem 
   SET businessdate  = (transactionitem.orderdatelocal)::date,
       sysupdatetime = NOW()
WHERE (transactionitem.businessdate IS NULL);



END;
$$;


ALTER PROCEDURE fact.usp_update_datetime_fields() OWNER TO citus;

--
-- TOC entry 1465 (class 1255 OID 3024871)
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
SET ts = tr.maxts,
    sysupdatetime = NOW() :: TIMESTAMP
FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.occasionsurveydetail' as tablename FROM fact.occasionsurveydetail WHERE sourceid = 1) as tr 
WHERE watermarktable.watermarktablename = tr.tablename
  AND watermarktable.source = 'nge';

UPDATE fact.watermarktable
SET ts = tr.maxts,
    sysupdatetime = NOW() :: TIMESTAMP
FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.occasionsurveydetail' as tablename FROM fact.occasionsurveydetail WHERE sourceid = 2) as tr 
WHERE watermarktable.watermarktablename = tr.tablename
  AND watermarktable.source = 'gem';

UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(nge_syscosmosts), 1720000300) - 10 FROM fact.itemssurvey),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.itemssurvey'
  AND source = 'nge';


END;
$$;


ALTER PROCEDURE fact.usp_update_occasion_survey_datetime_fields() OWNER TO citus;

--
-- TOC entry 1547 (class 1255 OID 3363399)
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
-- TOC entry 996 (class 1255 OID 3044530)
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
-- TOC entry 1554 (class 1255 OID 3364123)
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
-- TOC entry 585 (class 1255 OID 3364121)
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
-- TOC entry 1452 (class 1255 OID 3363400)
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
-- TOC entry 570 (class 1255 OID 3363402)
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
-- TOC entry 666 (class 1255 OID 3363392)
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
-- TOC entry 869 (class 1255 OID 19724)
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
-- TOC entry 965 (class 1255 OID 19725)
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
-- TOC entry 1379 (class 1255 OID 19516)
-- Name: pg_replication_origin_create(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_create(text) RETURNS oid
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_create($1) $_$;


ALTER FUNCTION public.pg_replication_origin_create(text) OWNER TO postgres;

--
-- TOC entry 1328 (class 1255 OID 19519)
-- Name: pg_replication_origin_drop(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_drop(text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_drop($1) $_$;


ALTER FUNCTION public.pg_replication_origin_drop(text) OWNER TO postgres;

--
-- TOC entry 764 (class 1255 OID 19518)
-- Name: pg_replication_origin_progress(text, boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_progress(text, boolean) RETURNS pg_lsn
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_progress($1, $2) $_$;


ALTER FUNCTION public.pg_replication_origin_progress(text, boolean) OWNER TO postgres;

--
-- TOC entry 1567 (class 1255 OID 19517)
-- Name: pg_replication_origin_session_progress(boolean); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_session_progress(boolean) RETURNS pg_lsn
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_session_progress($1) $_$;


ALTER FUNCTION public.pg_replication_origin_session_progress(boolean) OWNER TO postgres;

--
-- TOC entry 615 (class 1255 OID 19521)
-- Name: pg_replication_origin_session_setup(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_session_setup(text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_session_setup($1) $_$;


ALTER FUNCTION public.pg_replication_origin_session_setup(text) OWNER TO postgres;

--
-- TOC entry 1360 (class 1255 OID 19520)
-- Name: pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'pg_temp'
    AS $_$ SELECT pg_catalog.pg_replication_origin_xact_setup($1, $2) $_$;


ALTER FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) OWNER TO postgres;

--
-- TOC entry 2822 (class 1255 OID 19515)
-- Name: sum(public.hll); Type: AGGREGATE; Schema: public; Owner: postgres
--

CREATE AGGREGATE public.sum(public.hll) (
    SFUNC = public.hll_union_trans,
    STYPE = internal,
    FINALFUNC = public.hll_pack
);


ALTER AGGREGATE public.sum(public.hll) OWNER TO postgres;

--
-- TOC entry 2821 (class 1255 OID 19514)
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
-- TOC entry 419 (class 1259 OID 345584)
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
-- TOC entry 389 (class 1259 OID 32819)
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
-- TOC entry 396 (class 1259 OID 32912)
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
-- TOC entry 454 (class 1259 OID 2178862)
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
    is_ecm_enabled boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.catalog OWNER TO citus;

--
-- TOC entry 452 (class 1259 OID 2039150)
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
-- TOC entry 388 (class 1259 OID 32811)
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
-- TOC entry 425 (class 1259 OID 413623)
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
-- TOC entry 453 (class 1259 OID 2039929)
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
-- TOC entry 390 (class 1259 OID 32829)
-- Name: element; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.element (
    elementid integer NOT NULL,
    sourceelementid text,
    elementname text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.element OWNER TO citus;

--
-- TOC entry 529 (class 1259 OID 3700984)
-- Name: element_elementid_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE dim.element_elementid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.element_elementid_seq OWNER TO citus;

--
-- TOC entry 6594 (class 0 OID 0)
-- Dependencies: 529
-- Name: element_elementid_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.element_elementid_seq OWNED BY dim.element.elementid;


--
-- TOC entry 428 (class 1259 OID 419500)
-- Name: experiment; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.experiment (
    dimkey integer NOT NULL,
    data jsonb
);


ALTER TABLE dim.experiment OWNER TO citus;

--
-- TOC entry 427 (class 1259 OID 419499)
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
-- TOC entry 6596 (class 0 OID 0)
-- Dependencies: 427
-- Name: experiment_dimkey_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.experiment_dimkey_seq OWNED BY dim.experiment.dimkey;


--
-- TOC entry 413 (class 1259 OID 180315)
-- Name: feedbackrating; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.feedbackrating (
    rating text,
    ratingdesc text
);


ALTER TABLE dim.feedbackrating OWNER TO citus;

--
-- TOC entry 412 (class 1259 OID 180310)
-- Name: feedbackstatus; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.feedbackstatus (
    surveytransstatus text,
    statusdesc text
);


ALTER TABLE dim.feedbackstatus OWNER TO citus;

--
-- TOC entry 416 (class 1259 OID 245826)
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
-- TOC entry 476 (class 1259 OID 3418396)
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
-- TOC entry 493 (class 1259 OID 3586033)
-- Name: frequentcustomer_customerkey_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE dim.frequentcustomer_customerkey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.frequentcustomer_customerkey_seq OWNER TO citus;

--
-- TOC entry 6600 (class 0 OID 0)
-- Dependencies: 493
-- Name: frequentcustomer_customerkey_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.frequentcustomer_customerkey_seq OWNED BY dim.frequentcustomer.customerkey;


--
-- TOC entry 445 (class 1259 OID 762124)
-- Name: grubbrr_source_lookup; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.grubbrr_source_lookup (
    id integer NOT NULL,
    source text,
    description text
);


ALTER TABLE dim.grubbrr_source_lookup OWNER TO citus;

--
-- TOC entry 447 (class 1259 OID 862882)
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
-- TOC entry 458 (class 1259 OID 2669323)
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
-- TOC entry 391 (class 1259 OID 32837)
-- Name: itemcategory; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.itemcategory (
    id bigint NOT NULL,
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text NOT NULL,
    isactive boolean,
    catalogid text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    is_category_deleted boolean,
    category_created_on timestamp without time zone,
    category_modified_on timestamp without time zone,
    is_alcoholic boolean,
    number_of_items smallint,
    number_of_sub_categories smallint,
    number_of_item_variations smallint,
    number_of_combos smallint,
    number_of_combo_families smallint
);


ALTER TABLE dim.itemcategory OWNER TO citus;

--
-- TOC entry 435 (class 1259 OID 514411)
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
-- TOC entry 500 (class 1259 OID 3587571)
-- Name: itemcategory_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE dim.itemcategory_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.itemcategory_id_seq OWNER TO citus;

--
-- TOC entry 6604 (class 0 OID 0)
-- Dependencies: 500
-- Name: itemcategory_id_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.itemcategory_id_seq OWNED BY dim.itemcategory.id;


--
-- TOC entry 439 (class 1259 OID 665518)
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
-- TOC entry 417 (class 1259 OID 311950)
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
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.kiosk OWNER TO citus;

--
-- TOC entry 504 (class 1259 OID 3594939)
-- Name: kiosk_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE dim.kiosk_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.kiosk_id_seq OWNER TO citus;

--
-- TOC entry 6607 (class 0 OID 0)
-- Dependencies: 504
-- Name: kiosk_id_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.kiosk_id_seq OWNED BY dim.kiosk.id;


--
-- TOC entry 438 (class 1259 OID 586491)
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
    perform_pos_status_check boolean,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.kioskdetails OWNER TO citus;

--
-- TOC entry 392 (class 1259 OID 32863)
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
    timezone text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.location OWNER TO citus;

--
-- TOC entry 418 (class 1259 OID 327009)
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
-- TOC entry 444 (class 1259 OID 695503)
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
-- TOC entry 422 (class 1259 OID 359366)
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
-- TOC entry 494 (class 1259 OID 3586041)
-- Name: menuitem_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE dim.menuitem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.menuitem_id_seq OWNER TO citus;

--
-- TOC entry 6613 (class 0 OID 0)
-- Dependencies: 494
-- Name: menuitem_id_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.menuitem_id_seq OWNED BY dim.menuitem.id;


--
-- TOC entry 455 (class 1259 OID 2196057)
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
-- TOC entry 464 (class 1259 OID 2951551)
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
-- TOC entry 456 (class 1259 OID 2196809)
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
-- TOC entry 473 (class 1259 OID 3087656)
-- Name: occasionsurvey; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.occasionsurvey (
    surveykey bigint NOT NULL,
    organizationid text NOT NULL,
    surveyid text NOT NULL,
    surveyname text,
    surveytype integer,
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
-- TOC entry 510 (class 1259 OID 3608697)
-- Name: occasionsurvey_surveykey_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE dim.occasionsurvey_surveykey_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.occasionsurvey_surveykey_seq OWNER TO citus;

--
-- TOC entry 6614 (class 0 OID 0)
-- Dependencies: 510
-- Name: occasionsurvey_surveykey_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.occasionsurvey_surveykey_seq OWNED BY dim.occasionsurvey.surveykey;


--
-- TOC entry 393 (class 1259 OID 32880)
-- Name: ordertype; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.ordertype (
    id bigint NOT NULL,
    locationid text NOT NULL,
    kioskid text NOT NULL,
    ordertypeid text NOT NULL,
    ordertypelabel text NOT NULL,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.ordertype OWNER TO citus;

--
-- TOC entry 440 (class 1259 OID 672293)
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
-- TOC entry 505 (class 1259 OID 3598983)
-- Name: ordertype_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE dim.ordertype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.ordertype_id_seq OWNER TO citus;

--
-- TOC entry 6617 (class 0 OID 0)
-- Dependencies: 505
-- Name: ordertype_id_seq; Type: SEQUENCE OWNED BY; Schema: dim; Owner: citus
--

ALTER SEQUENCE dim.ordertype_id_seq OWNED BY dim.ordertype.id;


--
-- TOC entry 429 (class 1259 OID 431156)
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
    cep_subscriptions text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.organization OWNER TO citus;

--
-- TOC entry 394 (class 1259 OID 32888)
-- Name: organizationlocation; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.organizationlocation (
    organizationid character varying(40) NOT NULL,
    organizationname character varying(255),
    locationid character varying(40) NOT NULL,
    locationname character varying(255) NOT NULL,
    organizationtype smallint,
    roundupforcharity boolean,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.organizationlocation OWNER TO citus;

--
-- TOC entry 426 (class 1259 OID 413638)
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
-- TOC entry 434 (class 1259 OID 471773)
-- Name: upsellgrouplookup; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.upsellgrouplookup (
    upsellgroupid character varying(50) NOT NULL,
    upsellgroupname text,
    isactive boolean,
    createdon timestamp without time zone,
    modifiedon timestamp without time zone,
    catalogid text,
    sysinserttime timestamp without time zone
);


ALTER TABLE dim.upsellgrouplookup OWNER TO citus;

--
-- TOC entry 409 (class 1259 OID 103200)
-- Name: userlocation; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.userlocation (
    userid character varying(40) NOT NULL,
    locationid character varying(40) NOT NULL,
    sysinserttime timestamp without time zone
);


ALTER TABLE dim.userlocation OWNER TO citus;

--
-- TOC entry 507 (class 1259 OID 3601732)
-- Name: view_id_seq; Type: SEQUENCE; Schema: dim; Owner: citus
--

CREATE SEQUENCE dim.view_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE dim.view_id_seq OWNER TO citus;

--
-- TOC entry 395 (class 1259 OID 32906)
-- Name: view; Type: TABLE; Schema: dim; Owner: citus
--

CREATE TABLE dim.view (
    viewid integer DEFAULT nextval('dim.view_id_seq'::regclass),
    viewname text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE dim.view OWNER TO citus;

--
-- TOC entry 446 (class 1259 OID 806155)
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
-- TOC entry 475 (class 1259 OID 3327442)
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
-- TOC entry 424 (class 1259 OID 393489)
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
-- TOC entry 451 (class 1259 OID 1236960)
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
-- TOC entry 397 (class 1259 OID 32917)
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
-- TOC entry 423 (class 1259 OID 387340)
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
-- TOC entry 481 (class 1259 OID 3518722)
-- Name: bronze_partition_registry; Type: TABLE; Schema: etl; Owner: citus
--

CREATE TABLE etl.bronze_partition_registry (
    dateid integer NOT NULL,
    layer text,
    entity text NOT NULL,
    partition_path text,
    partition_date date,
    partition_year smallint,
    partition_month smallint,
    partition_day smallint,
    partition_hour smallint,
    status text DEFAULT 'pending'::text,
    file_count integer,
    started_at timestamp without time zone,
    completed_at timestamp without time zone,
    adf_pipeline_run_id text,
    error_message text,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE etl.bronze_partition_registry OWNER TO citus;

--
-- TOC entry 526 (class 1259 OID 3676263)
-- Name: gas_db_object_dependency_sort; Type: TABLE; Schema: etl; Owner: citus
--

CREATE TABLE etl.gas_db_object_dependency_sort (
    table_schema text,
    table_name text,
    key_columns jsonb,
    key_type text,
    key_column_data_types jsonb,
    dependency_level integer,
    dependency_count integer,
    depends_on jsonb,
    referenced_by jsonb,
    insert_watermark text,
    insert_watermark_data_type text,
    update_watermark text,
    update_watermark_data_type text,
    insert_watermark_value timestamp without time zone,
    update_watermark_value timestamp without time zone,
    watermark_integer_value bigint,
    record_count bigint,
    sql_aggregate text,
    sysupdatetime timestamp without time zone,
    post_sync_insert_watermark_value timestamp without time zone,
    post_sync_update_watermark_value timestamp without time zone,
    post_sync_watermark_integer_value bigint,
    post_sync_record_count bigint,
    sysupdatetime_after_migration timestamp without time zone,
    sql_source_query text
);


ALTER TABLE etl.gas_db_object_dependency_sort OWNER TO citus;

--
-- TOC entry 450 (class 1259 OID 1071621)
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
-- TOC entry 442 (class 1259 OID 693385)
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
-- TOC entry 398 (class 1259 OID 32922)
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
-- TOC entry 530 (class 1259 OID 3735719)
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
-- TOC entry 399 (class 1259 OID 32929)
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
-- TOC entry 523 (class 1259 OID 3650129)
-- Name: devicestate_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

CREATE SEQUENCE fact.devicestate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.devicestate_id_seq OWNER TO citus;

--
-- TOC entry 6632 (class 0 OID 0)
-- Dependencies: 523
-- Name: devicestate_id_seq; Type: SEQUENCE OWNED BY; Schema: fact; Owner: citus
--

ALTER SEQUENCE fact.devicestate_id_seq OWNED BY fact.devicestate.id;


--
-- TOC entry 410 (class 1259 OID 159814)
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
-- TOC entry 528 (class 1259 OID 3688736)
-- Name: gem_failed_order_job_notifications; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.gem_failed_order_job_notifications (
    incidentid bigint,
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


ALTER TABLE fact.gem_failed_order_job_notifications OWNER TO citus;

--
-- TOC entry 400 (class 1259 OID 32945)
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
    sysupdatetime timestamp without time zone,
    locationid text,
    businessdate date,
    syscosmosts bigint
);


ALTER TABLE fact.itemmodifier OWNER TO citus;

--
-- TOC entry 420 (class 1259 OID 352106)
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
-- TOC entry 443 (class 1259 OID 693393)
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
-- TOC entry 457 (class 1259 OID 2247991)
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
-- TOC entry 461 (class 1259 OID 2874472)
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
-- TOC entry 462 (class 1259 OID 2874493)
-- Name: modifier_interactions; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.modifier_interactions (
    locationid text,
    transactionheaderid text NOT NULL,
    ordersessionid text,
    orderid text,
    orderitemid text,
    menuitemid text,
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
-- TOC entry 460 (class 1259 OID 2860510)
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
-- TOC entry 421 (class 1259 OID 352111)
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
-- TOC entry 401 (class 1259 OID 32952)
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
    syscosmosts bigint,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.ordertiming OWNER TO citus;

--
-- TOC entry 525 (class 1259 OID 3654113)
-- Name: ordertiming_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

CREATE SEQUENCE fact.ordertiming_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.ordertiming_id_seq OWNER TO citus;

--
-- TOC entry 6639 (class 0 OID 0)
-- Dependencies: 525
-- Name: ordertiming_id_seq; Type: SEQUENCE OWNED BY; Schema: fact; Owner: citus
--

ALTER SEQUENCE fact.ordertiming_id_seq OWNED BY fact.ordertiming.id;


--
-- TOC entry 531 (class 1259 OID 3735726)
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
-- TOC entry 402 (class 1259 OID 32965)
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
-- TOC entry 449 (class 1259 OID 888761)
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
-- TOC entry 448 (class 1259 OID 888760)
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
-- TOC entry 431 (class 1259 OID 454561)
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
-- TOC entry 430 (class 1259 OID 454469)
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
-- TOC entry 465 (class 1259 OID 2987102)
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
-- TOC entry 403 (class 1259 OID 32970)
-- Name: timingsdatalake; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.timingsdatalake (
    containername text NOT NULL,
    timing_value timestamp without time zone
);


ALTER TABLE fact.timingsdatalake OWNER TO citus;

--
-- TOC entry 404 (class 1259 OID 32977)
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
    updateddate timestamp without time zone,
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
-- TOC entry 506 (class 1259 OID 3600411)
-- Name: transactionheader_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

CREATE SEQUENCE fact.transactionheader_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.transactionheader_id_seq OWNER TO citus;

--
-- TOC entry 6645 (class 0 OID 0)
-- Dependencies: 506
-- Name: transactionheader_id_seq; Type: SEQUENCE OWNED BY; Schema: fact; Owner: citus
--

ALTER SEQUENCE fact.transactionheader_id_seq OWNED BY fact.transactionheader.id;


--
-- TOC entry 405 (class 1259 OID 32988)
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
    businessdate date,
    syscosmosts bigint,
    frequentcustomerid text
);


ALTER TABLE fact.transactionitem OWNER TO citus;

--
-- TOC entry 406 (class 1259 OID 32997)
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
    sysupdatetime timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE fact.transactionpayment OWNER TO citus;

--
-- TOC entry 436 (class 1259 OID 542773)
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
-- TOC entry 407 (class 1259 OID 33004)
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
    eventcategory text,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.userbehaviour OWNER TO citus;

--
-- TOC entry 432 (class 1259 OID 459790)
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
-- TOC entry 508 (class 1259 OID 3601741)
-- Name: userbehaviour_id_seq; Type: SEQUENCE; Schema: fact; Owner: citus
--

CREATE SEQUENCE fact.userbehaviour_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE fact.userbehaviour_id_seq OWNER TO citus;

--
-- TOC entry 6651 (class 0 OID 0)
-- Dependencies: 508
-- Name: userbehaviour_id_seq; Type: SEQUENCE OWNED BY; Schema: fact; Owner: citus
--

ALTER SEQUENCE fact.userbehaviour_id_seq OWNED BY fact.userbehaviour.id;


--
-- TOC entry 411 (class 1259 OID 165825)
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
    orderdatelocal timestamp without time zone,
    syscosmosts bigint
);


ALTER TABLE fact.usercheckedin OWNER TO citus;

--
-- TOC entry 441 (class 1259 OID 676689)
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
    sysinserttime timestamp without time zone,
    offereditem_upselllevel text,
    offered_promptitemid text,
    offered_upsellgroupid text,
    selecteditem_upselllevel text,
    selected_promptitemid text,
    selected_upsellgroupid text
);


ALTER TABLE fact.vw_offer_analysis OWNER TO citus;

--
-- TOC entry 408 (class 1259 OID 33011)
-- Name: watermarktable; Type: TABLE; Schema: fact; Owner: citus
--

CREATE TABLE fact.watermarktable (
    watermarktablename text NOT NULL,
    watermarkcolumn text,
    watermarkvalue timestamp without time zone,
    ticks bigint,
    ts bigint,
    source character varying(50) NOT NULL,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
);


ALTER TABLE fact.watermarktable OWNER TO citus;

--
-- TOC entry 472 (class 1259 OID 3048276)
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
-- TOC entry 468 (class 1259 OID 3044534)
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
-- TOC entry 471 (class 1259 OID 3048261)
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
-- TOC entry 470 (class 1259 OID 3048228)
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
-- TOC entry 469 (class 1259 OID 3044562)
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
-- TOC entry 466 (class 1259 OID 3042193)
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
-- TOC entry 467 (class 1259 OID 3042222)
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
-- TOC entry 414 (class 1259 OID 227930)
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
    supportedformats character varying[] DEFAULT ARRAY['Csv'::character varying, 'Excel'::character varying, 'Pdf'::character varying] NOT NULL,
    previewformat character varying(50) DEFAULT 'Tabular'::character varying NOT NULL,
    origin character varying(50) DEFAULT 'Custom'::character varying NOT NULL
);


ALTER TABLE public.report OWNER TO citus;

--
-- TOC entry 415 (class 1259 OID 238011)
-- Name: reportschedule; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.reportschedule (
    id character varying(40) NOT NULL,
    reportid character varying(40) NOT NULL,
    isactive boolean DEFAULT false NOT NULL,
    organizationid character varying(40) NOT NULL,
    periodfrom timestamp without time zone,
    periodto timestamp without time zone,
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
-- TOC entry 387 (class 1259 OID 32804)
-- Name: schemaversions; Type: TABLE; Schema: public; Owner: citus
--

CREATE TABLE public.schemaversions (
    schemaversionsid integer NOT NULL,
    scriptname character varying(255) NOT NULL,
    applied timestamp without time zone NOT NULL
);


ALTER TABLE public.schemaversions OWNER TO citus;

--
-- TOC entry 386 (class 1259 OID 32803)
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
-- TOC entry 6659 (class 0 OID 0)
-- Dependencies: 386
-- Name: schemaversions_schemaversionsid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: citus
--

ALTER SEQUENCE public.schemaversions_schemaversionsid_seq OWNED BY public.schemaversions.schemaversionsid;


--
-- TOC entry 502 (class 1259 OID 3588996)
-- Name: dim_catalog; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_catalog (
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
    is_ecm_enabled boolean,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_catalog OWNER TO citus;

--
-- TOC entry 496 (class 1259 OID 3586057)
-- Name: dim_category_hierarchy; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_category_hierarchy (
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
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_category_hierarchy OWNER TO citus;

--
-- TOC entry 521 (class 1259 OID 3644487)
-- Name: dim_cep_subscriptions; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_cep_subscriptions (
    id text,
    cep_subscriptions text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_cep_subscriptions OWNER TO citus;

--
-- TOC entry 492 (class 1259 OID 3584732)
-- Name: dim_frequentcustomer; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_frequentcustomer (
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
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_frequentcustomer OWNER TO citus;

--
-- TOC entry 501 (class 1259 OID 3587579)
-- Name: dim_itemcategory; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_itemcategory (
    locationid text NOT NULL,
    categoryid text NOT NULL,
    categoryname text NOT NULL,
    catalogid text,
    is_category_active boolean,
    is_category_deleted boolean,
    category_created_on timestamp without time zone,
    category_modified_on timestamp without time zone,
    is_alcoholic boolean,
    number_of_items smallint,
    number_of_sub_categories smallint,
    number_of_item_variations smallint,
    number_of_combos smallint,
    number_of_combo_families smallint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_itemcategory OWNER TO citus;

--
-- TOC entry 503 (class 1259 OID 3594934)
-- Name: dim_kiosk; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_kiosk (
    locationid text NOT NULL,
    kioskid text NOT NULL,
    kioskname text,
    appversion text,
    istestkiosk boolean,
    devicetype character varying(50),
    devicecreatedon timestamp without time zone,
    devicedeletedon timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_kiosk OWNER TO citus;

--
-- TOC entry 519 (class 1259 OID 3631109)
-- Name: dim_kiosk_appearance; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_kiosk_appearance (
    locationid text,
    kiosk_receipt_settings text,
    kiosk_fonts text,
    kiosk_appearance_text_overrides text,
    kiosk_appearance_style_options text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_kiosk_appearance OWNER TO citus;

--
-- TOC entry 518 (class 1259 OID 3631104)
-- Name: dim_kiosk_config; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_kiosk_config (
    locationid text,
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
    loyalty_display_settings text,
    preorder_popup_enabled boolean,
    preorder_popup_text text,
    disclaimer_text text,
    order_limit_config text,
    menu_behavior_config text,
    perform_pos_status_check boolean,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_kiosk_config OWNER TO citus;

--
-- TOC entry 514 (class 1259 OID 3631084)
-- Name: dim_location_kiosks; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_location_kiosks (
    id text,
    locationid text,
    companyid text,
    devicetype text,
    syncversion text,
    kiosks text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_location_kiosks OWNER TO citus;

--
-- TOC entry 516 (class 1259 OID 3631094)
-- Name: dim_loyalty_configuration; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_loyalty_configuration (
    locationid text,
    loyalty_provider text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_loyalty_configuration OWNER TO citus;

--
-- TOC entry 495 (class 1259 OID 3586044)
-- Name: dim_menuitem; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_menuitem (
    menuitemid text NOT NULL,
    menuitemname text NOT NULL,
    entitytype text,
    calories text,
    protein numeric,
    sugar numeric,
    fat numeric,
    is_alcoholic boolean,
    is_vegetarian_item boolean,
    is_vegan_item boolean,
    has_allergen boolean,
    item_class_type integer,
    is_active boolean,
    is_deleted boolean,
    gms_created_on timestamp without time zone,
    gms_modified_on timestamp without time zone,
    itemunitprice numeric(12,3),
    price_changed_on timestamp without time zone,
    catalogid text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_menuitem OWNER TO citus;

--
-- TOC entry 497 (class 1259 OID 3586064)
-- Name: dim_modifier; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_modifier (
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
    price_changed_on timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_modifier OWNER TO citus;

--
-- TOC entry 498 (class 1259 OID 3586070)
-- Name: dim_modifiergroup; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_modifiergroup (
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
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_modifiergroup OWNER TO citus;

--
-- TOC entry 499 (class 1259 OID 3586080)
-- Name: dim_modifiergroup_modifier_mapping; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_modifiergroup_modifier_mapping (
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
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_modifiergroup_modifier_mapping OWNER TO citus;

--
-- TOC entry 511 (class 1259 OID 3608712)
-- Name: dim_occasionsurvey; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_occasionsurvey (
    organizationid text NOT NULL,
    surveyid text NOT NULL,
    surveyname text,
    surveytype integer,
    question_type integer,
    selection_type integer,
    survey_status integer,
    is_deleted boolean,
    created_on timestamp without time zone,
    modified_on timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_occasionsurvey OWNER TO citus;

--
-- TOC entry 520 (class 1259 OID 3644479)
-- Name: dim_organization; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_organization (
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
    cep_subscriptions text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_organization OWNER TO citus;

--
-- TOC entry 509 (class 1259 OID 3605517)
-- Name: dim_organizationlocation; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_organizationlocation (
    organizationid character varying(40) NOT NULL,
    organizationname character varying(255),
    locationid character varying(40) NOT NULL,
    locationname character varying(255) NOT NULL,
    organizationtype smallint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_organizationlocation OWNER TO citus;

--
-- TOC entry 517 (class 1259 OID 3631099)
-- Name: dim_payment_provider; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_payment_provider (
    locationid text,
    payment_provider text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_payment_provider OWNER TO citus;

--
-- TOC entry 515 (class 1259 OID 3631089)
-- Name: dim_pos_provider; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.dim_pos_provider (
    locationid text,
    pos_provider text,
    syscosmosts bigint,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.dim_pos_provider OWNER TO citus;

--
-- TOC entry 522 (class 1259 OID 3648879)
-- Name: fact_devicestate; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.fact_devicestate (
    id bigint,
    healthdatatype text,
    locationid text,
    companyid text,
    deviceid text,
    devicetype text,
    status text,
    statusmessage text,
    healthdatatime timestamp without time zone,
    statuschangetime timestamp without time zone,
    inserttime timestamp without time zone,
    version text,
    devicedatatime timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.fact_devicestate OWNER TO citus;

--
-- TOC entry 524 (class 1259 OID 3650133)
-- Name: fact_devicetelemetry; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.fact_devicetelemetry (
    deviceid text,
    locationid text,
    dateid integer,
    cpuvalue numeric(10,5),
    memoryvalue numeric(10,5),
    cputimestamp timestamp without time zone,
    memorytimestamp timestamp without time zone,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.fact_devicetelemetry OWNER TO citus;

--
-- TOC entry 513 (class 1259 OID 3614573)
-- Name: fact_itemssurvey; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.fact_itemssurvey (
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
    nge_syscosmosts bigint,
    sourceid integer,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.fact_itemssurvey OWNER TO citus;

--
-- TOC entry 512 (class 1259 OID 3608723)
-- Name: fact_occasionsurveydetail; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.fact_occasionsurveydetail (
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
    syscosmosts bigint,
    sourceid integer,
    surveytype integer,
    ordersessionid text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.fact_occasionsurveydetail OWNER TO citus;

--
-- TOC entry 527 (class 1259 OID 3687335)
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
-- TOC entry 437 (class 1259 OID 583797)
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
-- TOC entry 484 (class 1259 OID 3568572)
-- Name: lookup_silver_transaction_header; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.lookup_silver_transaction_header (
    id integer,
    transactionheaderid text,
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
    ordersredeemedrewards numeric(12,3),
    ordersubtotal numeric(12,3),
    ordertotal numeric(12,3),
    ordertax numeric(12,3),
    ordertip numeric(12,3),
    orderdiscount numeric(12,3),
    orderbalance numeric(12,3),
    paymentstatus text,
    sourcefile text,
    createddate timestamp without time zone,
    charityamount numeric(12,3),
    orderservicecharge numeric(12,3),
    businessdate date,
    syscosmosts bigint,
    channel text,
    guestcount integer,
    frequentcustomerid text,
    customername text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.lookup_silver_transaction_header OWNER TO citus;

--
-- TOC entry 459 (class 1259 OID 2849148)
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
-- TOC entry 433 (class 1259 OID 461038)
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
-- TOC entry 463 (class 1259 OID 2944480)
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
-- TOC entry 479 (class 1259 OID 3499461)
-- Name: silver_cep_incidents; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_cep_incidents (
    id text,
    application text,
    companyid text,
    locationid text,
    eventmodule text,
    eventcategory text,
    eventtype text,
    severity text,
    token text,
    eventinstant text,
    username text,
    userid text,
    device text,
    devicename text,
    summary text,
    data text,
    syscosmosticks bigint,
    syscosmosts bigint,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_cep_incidents OWNER TO citus;

--
-- TOC entry 485 (class 1259 OID 3570048)
-- Name: silver_item_modifiers; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_item_modifiers (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    orderitemid text,
    itemsessionid text,
    menuitemid text,
    menu_item_pos_id text,
    itemname text,
    categoryid text,
    categoryname text,
    category_pos_id text,
    itemquantity integer,
    usd_itemunitprice numeric(12,3),
    usd_total_item_price numeric(12,3),
    cents_itemunitprice bigint,
    cents_total_item_price bigint,
    items_discount_id text,
    is_items_discount_hidden_on_receipt boolean,
    items_discounts text,
    items_upsell_source text,
    items_reward_source text,
    items_special_request text,
    items_concept_id text,
    items_concept_name text,
    options_modifierid text,
    options_modifier_pos_id text,
    options_modifiername text,
    options_modifier_code text,
    options_modifiergroupid text,
    options_modifiergroupname text,
    options_modifiergroup_pos_id text,
    options_modifierquantity integer,
    options_modifierunitprice numeric(12,3),
    options_total_modifierprice numeric(12,3),
    modifier_freequantity integer,
    is_modifier_invisible boolean,
    is_modifier_default boolean,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_item_modifiers OWNER TO citus;

--
-- TOC entry 478 (class 1259 OID 3499456)
-- Name: silver_kiosk_events; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_kiosk_events (
    id text,
    application text,
    companyid text,
    locationid text,
    eventmodule text,
    eventcategory text,
    eventtype text,
    severity text,
    token text,
    eventinstant text,
    username text,
    userid text,
    device text,
    devicename text,
    summary text,
    data text,
    syscosmosticks bigint,
    syscosmosts bigint,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_kiosk_events OWNER TO citus;

--
-- TOC entry 490 (class 1259 OID 3571370)
-- Name: silver_modifier_impressions; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_modifier_impressions (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    menuitemid text,
    parentmodifierid text,
    selection_type text,
    modifier_impressions_nesting_depth integer,
    modifier_impressions_context text,
    strategy text,
    modifierid text,
    score integer,
    "position" integer,
    selected boolean,
    pre_selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_modifier_impressions OWNER TO citus;

--
-- TOC entry 489 (class 1259 OID 3571365)
-- Name: silver_modifier_interactions; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_modifier_interactions (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    menuitemid text,
    modifierid text,
    modifiergroupid text,
    parent_modifier_id text,
    selection_type text,
    modifier_interactions_action text,
    modifier_interactions_recorded_at text,
    modifier_interactions_nesting_depth integer,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_modifier_interactions OWNER TO citus;

--
-- TOC entry 488 (class 1259 OID 3571360)
-- Name: silver_modifier_recommendations; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_modifier_recommendations (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    modifier_interactions text,
    modifier_impressions text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_modifier_recommendations OWNER TO citus;

--
-- TOC entry 491 (class 1259 OID 3580160)
-- Name: silver_transaction_combo_items; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_transaction_combo_items (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    combo_id text,
    combo_pos_id text,
    combo_name text,
    combo_order_item_id text,
    combo_item_session_id text,
    combo_concept_id text,
    combo_concept_name text,
    cents_combo_unit_price bigint,
    cents_combo_total_price bigint,
    combo_quantity integer,
    combo_special_request text,
    combo_upsell_source text,
    combo_reward_source text,
    component_id text,
    component_pos_id text,
    component_name text,
    component_item_order_item_id text,
    component_item_menu_item_id text,
    component_item_name text,
    component_item_menu_item_pos_id text,
    component_item_session_id text,
    component_item_concept_id text,
    component_item_concept_name text,
    component_item_quantity integer,
    component_item_price numeric(12,3),
    component_item_unit_price numeric(12,3),
    component_item_cents_unit_price bigint,
    component_item_total_price numeric(12,3),
    component_item_cents_total_price bigint,
    component_item_special_request text,
    component_item_upsell_source text,
    component_item_reward_source text,
    component_item_discount_id text,
    is_component_item_discount_hidden_on_receipt boolean,
    component_item_discounts text,
    component_selections_items text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_transaction_combo_items OWNER TO citus;

--
-- TOC entry 480 (class 1259 OID 3518689)
-- Name: silver_transaction_header; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_transaction_header (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    channel integer,
    items_array text,
    payments_array text,
    numberofitems smallint,
    numberofpayments smallint,
    concept_id text,
    concept_name text,
    ordertype text,
    order_type_label text,
    order_completion_status text,
    pos_submission_status integer,
    is_send_to_pos_failed boolean,
    is_test_order boolean,
    frequentcustomerid text,
    customername text,
    client_ip_address text,
    order_identity_order_token text,
    order_identity_pos_order_token text,
    order_identity_phone text,
    order_identity_phone_country_code text,
    order_identity_email text,
    order_identity_table_tent text,
    order_identity_device_imei text,
    guest_count integer,
    guest_check_code text,
    genesis_fiscal_fields text,
    order_language text,
    receipt_printing_type text,
    loyalty_transaction_id text,
    loyalty_payment_transaction_id text,
    loyalty_earned_points text,
    local_currency_code text,
    local_currency_additional_info text,
    usd_amount numeric(12,3),
    usd_subtotal numeric(12,3),
    usd_tax numeric(12,3),
    usd_tip numeric(12,3),
    usd_discount numeric(12,3),
    usd_reward numeric(12,3),
    usd_service_charge numeric(12,3),
    usd_charity_amount numeric(12,3),
    cents_amount bigint,
    cents_subtotal bigint,
    cents_tax bigint,
    cents_tip bigint,
    cents_discount bigint,
    cents_reward bigint,
    cents_service_charge bigint,
    cents_charity_amount bigint,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_transaction_header OWNER TO citus;

--
-- TOC entry 486 (class 1259 OID 3570053)
-- Name: silver_transaction_item; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_transaction_item (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    orderitemid text,
    itemsessionid text,
    menuitemid text,
    menu_item_pos_id text,
    itemname text,
    categoryid text,
    categoryname text,
    category_pos_id text,
    items_concept_id text,
    items_concept_name text,
    itemquantity integer,
    usd_itemunitprice numeric(12,3),
    usd_total_item_price numeric(12,3),
    cents_itemunitprice bigint,
    cents_total_item_price bigint,
    modifier_options text,
    items_discount_id text,
    is_items_discount_hidden_on_receipt boolean,
    items_discounts text,
    items_upsell_source text,
    items_reward_source text,
    items_special_request text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_transaction_item OWNER TO citus;

--
-- TOC entry 477 (class 1259 OID 3428544)
-- Name: silver_transaction_payment; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_transaction_payment (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    payment_transactionid text,
    payment_method text,
    payment_status text,
    payment_amount numeric(12,3),
    payment_tender_id text,
    payment_integration_id text,
    payment_integration_label text,
    payment_card_name text,
    payment_card_number text,
    is_amazon_one_payment boolean,
    card_info_card_type text,
    card_info_last_four text,
    card_info_masked_card_number text,
    card_info_zip_code text,
    card_info_expiration_month text,
    card_info_expiration_year text,
    card_info_processor_auth_code text,
    card_info_available_balance numeric(12,3),
    payment_capture_details text,
    payment_settlement_details text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_transaction_payment OWNER TO citus;

--
-- TOC entry 482 (class 1259 OID 3531845)
-- Name: silver_transaction_refunds; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_transaction_refunds (
    locationid text,
    transactionheaderid text NOT NULL,
    orderid text,
    original_transaction_id text,
    refund_transaction_id text,
    refund_type text,
    refunded_amount numeric(12,3),
    order_completion_status text,
    orderdateutc text,
    syscosmosts bigint,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_transaction_refunds OWNER TO citus;

--
-- TOC entry 487 (class 1259 OID 3571355)
-- Name: silver_upsell_recommendations; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.silver_upsell_recommendations (
    transactionheaderid text,
    orderid text,
    ordersessionid text,
    orderdateutc text,
    businessdate text,
    syscosmosts bigint,
    locationid text,
    kioskid text,
    kiosk_name text,
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text,
    recommendationid text,
    prompttimestamp text,
    modal_version text,
    offered_items text,
    selected_items text,
    order_completion_status text,
    bronze_filepath text,
    silver_transform_time text,
    silver_folderpath text,
    sysinserttime timestamp without time zone
);


ALTER TABLE stg.silver_upsell_recommendations OWNER TO citus;

--
-- TOC entry 483 (class 1259 OID 3567138)
-- Name: temp_silver_transaction_header; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.temp_silver_transaction_header (
    id integer,
    transactionheaderid text,
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
    ordersredeemedrewards numeric(12,3),
    ordersubtotal numeric(12,3),
    ordertotal numeric(12,3),
    ordertax numeric(12,3),
    ordertip numeric(12,3),
    orderdiscount numeric(12,3),
    orderbalance numeric(12,3),
    paymentstatus text,
    sourcefile text,
    createddate timestamp without time zone,
    charityamount numeric(12,3),
    orderservicecharge numeric(12,3),
    businessdate date,
    syscosmosts bigint,
    channel text,
    guestcount integer,
    frequentcustomerid text,
    customername text
);


ALTER TABLE stg.temp_silver_transaction_header OWNER TO citus;

--
-- TOC entry 474 (class 1259 OID 3244112)
-- Name: transactionheader; Type: TABLE; Schema: stg; Owner: citus
--

CREATE TABLE stg.transactionheader (
    id text NOT NULL,
    kiosksessionid text,
    orderid text,
    locationid text,
    type text,
    ordertype text,
    ordertypelabel text,
    channel integer,
    orderdate text,
    businessdate text,
    guestcount integer,
    possubmissionstatus integer,
    isfailedtosendtopos boolean,
    istestorder boolean,
    clientipaddress text,
    conceptid text,
    conceptname text,
    loyaltyuser text,
    loyaltyprovidertransactionid text,
    loyaltyproviderpaymenttransactionid text,
    receiptimage text,
    orderreceipturl text,
    orderreceiptpdfurl text,
    guestcheckimagelink text,
    totals text,
    totalscents text,
    localcurrencydetails text,
    orderidentity text,
    kiosksource text,
    upsellinformation text,
    receiptdetails text,
    items text,
    combos text,
    paymentdetails text,
    redeemedrewards text,
    discounts text,
    concepts text,
    sys_rid text,
    sys_self text,
    sys_etag text,
    sys_attachments text,
    sys_lsn bigint,
    syscosmosts bigint,
    bronze_filepath text
);


ALTER TABLE stg.transactionheader OWNER TO citus;

--
-- TOC entry 6123 (class 2604 OID 3735710)
-- Name: element elementid; Type: DEFAULT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.element ALTER COLUMN elementid SET DEFAULT nextval('dim.element_elementid_seq'::regclass);


--
-- TOC entry 6149 (class 2604 OID 3700981)
-- Name: experiment dimkey; Type: DEFAULT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.experiment ALTER COLUMN dimkey SET DEFAULT nextval('dim.experiment_dimkey_seq'::regclass);


--
-- TOC entry 6141 (class 2604 OID 3735711)
-- Name: frequentcustomer customerkey; Type: DEFAULT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer ALTER COLUMN customerkey SET DEFAULT nextval('dim.frequentcustomer_customerkey_seq'::regclass);


--
-- TOC entry 6124 (class 2604 OID 3735712)
-- Name: itemcategory id; Type: DEFAULT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory ALTER COLUMN id SET DEFAULT nextval('dim.itemcategory_id_seq'::regclass);


--
-- TOC entry 6144 (class 2604 OID 3735713)
-- Name: kiosk id; Type: DEFAULT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk ALTER COLUMN id SET DEFAULT nextval('dim.kiosk_id_seq'::regclass);


--
-- TOC entry 6146 (class 2604 OID 3735714)
-- Name: menuitem id; Type: DEFAULT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem ALTER COLUMN id SET DEFAULT nextval('dim.menuitem_id_seq'::regclass);


--
-- TOC entry 6159 (class 2604 OID 3735715)
-- Name: occasionsurvey surveykey; Type: DEFAULT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.occasionsurvey ALTER COLUMN surveykey SET DEFAULT nextval('dim.occasionsurvey_surveykey_seq'::regclass);


--
-- TOC entry 6125 (class 2604 OID 3735716)
-- Name: ordertype id; Type: DEFAULT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype ALTER COLUMN id SET DEFAULT nextval('dim.ordertype_id_seq'::regclass);


--
-- TOC entry 6127 (class 2604 OID 3735724)
-- Name: devicestate id; Type: DEFAULT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicestate ALTER COLUMN id SET DEFAULT nextval('fact.devicestate_id_seq'::regclass);


--
-- TOC entry 6129 (class 2604 OID 3735725)
-- Name: ordertiming id; Type: DEFAULT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.ordertiming ALTER COLUMN id SET DEFAULT nextval('fact.ordertiming_id_seq'::regclass);


--
-- TOC entry 6130 (class 2604 OID 3735731)
-- Name: transactionheader id; Type: DEFAULT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader ALTER COLUMN id SET DEFAULT nextval('fact.transactionheader_id_seq'::regclass);


--
-- TOC entry 6135 (class 2604 OID 3735732)
-- Name: userbehaviour id; Type: DEFAULT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour ALTER COLUMN id SET DEFAULT nextval('fact.userbehaviour_id_seq'::regclass);


--
-- TOC entry 6122 (class 2604 OID 32807)
-- Name: schemaversions schemaversionsid; Type: DEFAULT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.schemaversions ALTER COLUMN schemaversionsid SET DEFAULT nextval('public.schemaversions_schemaversionsid_seq'::regclass);


--
-- TOC entry 6318 (class 2606 OID 2178868)
-- Name: catalog catalog_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (catalogid);


--
-- TOC entry 6171 (class 2606 OID 32817)
-- Name: company company_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (companyid);


--
-- TOC entry 6174 (class 2606 OID 32825)
-- Name: datedim datedim_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.datedim
    ADD CONSTRAINT datedim_pk PRIMARY KEY (dateid);


--
-- TOC entry 6261 (class 2606 OID 413632)
-- Name: device device_deviceid_locationid_companyid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_deviceid_locationid_companyid_key UNIQUE (deviceid, locationid, companyid);


--
-- TOC entry 6263 (class 2606 OID 413630)
-- Name: device device_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.device
    ADD CONSTRAINT device_pkey PRIMARY KEY (id);


--
-- TOC entry 6178 (class 2606 OID 32835)
-- Name: element dimelement_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.element
    ADD CONSTRAINT dimelement_pkey PRIMARY KEY (elementid);


--
-- TOC entry 6275 (class 2606 OID 419507)
-- Name: experiment experiment_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.experiment
    ADD CONSTRAINT experiment_pkey PRIMARY KEY (dimkey);


--
-- TOC entry 6244 (class 2606 OID 779308)
-- Name: frequentcustomer frequent_customer_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer
    ADD CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6355 (class 2606 OID 3418404)
-- Name: frequentcustomer_bkp frequentcustomer_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.frequentcustomer_bkp
    ADD CONSTRAINT frequentcustomer_bkp_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6308 (class 2606 OID 762128)
-- Name: grubbrr_source_lookup grubbrr_source_lookup_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.grubbrr_source_lookup
    ADD CONSTRAINT grubbrr_source_lookup_pkey PRIMARY KEY (id);


--
-- TOC entry 6327 (class 2606 OID 2888241)
-- Name: item_modifier_group_modifier_mapping item_modgrp_modfr_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.item_modifier_group_modifier_mapping
    ADD CONSTRAINT item_modgrp_modfr_unq UNIQUE (menuitemid, modifiergroupid, modifierid);


--
-- TOC entry 6291 (class 2606 OID 514418)
-- Name: itemcategory_bkp itemcategory_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory_bkp
    ADD CONSTRAINT itemcategory_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 6182 (class 2606 OID 32844)
-- Name: itemcategory itemcategory_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.itemcategory
    ADD CONSTRAINT itemcategory_pk PRIMARY KEY (id);


--
-- TOC entry 6246 (class 2606 OID 311956)
-- Name: kiosk kiosk_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_pk PRIMARY KEY (id);


--
-- TOC entry 6248 (class 2606 OID 311958)
-- Name: kiosk kiosk_uidx; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kiosk
    ADD CONSTRAINT kiosk_uidx UNIQUE (locationid, kioskid);


--
-- TOC entry 6314 (class 2606 OID 2047632)
-- Name: category_hierarchy location_category_menuitem_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.category_hierarchy
    ADD CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6250 (class 2606 OID 327015)
-- Name: locationcatalog location_ctlg_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.locationcatalog
    ADD CONSTRAINT location_ctlg_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 6257 (class 2606 OID 387346)
-- Name: weather_bkp location_date_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.weather_bkp
    ADD CONSTRAINT location_date_bkp_pk PRIMARY KEY (locationid, businessdate);


--
-- TOC entry 6259 (class 2606 OID 393495)
-- Name: weather location_date_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.weather
    ADD CONSTRAINT location_date_pk PRIMARY KEY (locationid, apicalldate);


--
-- TOC entry 6185 (class 2606 OID 32869)
-- Name: location location_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.location
    ADD CONSTRAINT location_pk PRIMARY KEY (companyid, locationid);


--
-- TOC entry 6316 (class 2606 OID 2047655)
-- Name: duplicate_items_master locationid_categoryid_menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.duplicate_items_master
    ADD CONSTRAINT locationid_categoryid_menuitemid_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6310 (class 2606 OID 806161)
-- Name: vw_grubbrrinstallbase locationid_deviceid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase
    ADD CONSTRAINT locationid_deviceid_pk PRIMARY KEY (location_id, kiosk_id);


--
-- TOC entry 6353 (class 2606 OID 3327448)
-- Name: vw_grubbrrinstallbase_all_devices locationid_kioskid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase_all_devices
    ADD CONSTRAINT locationid_kioskid_pk PRIMARY KEY (location_id, kiosk_id);


--
-- TOC entry 6294 (class 2606 OID 594665)
-- Name: kioskdetails locationid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.kioskdetails
    ADD CONSTRAINT locationid_pkey PRIMARY KEY (locationid);


--
-- TOC entry 6306 (class 2606 OID 695509)
-- Name: menuentities menuentities_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuentities
    ADD CONSTRAINT menuentities_pkey PRIMARY KEY (entityid);


--
-- TOC entry 6253 (class 2606 OID 359373)
-- Name: menuitem menuitem_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitem_pk PRIMARY KEY (id);


--
-- TOC entry 6255 (class 2606 OID 779647)
-- Name: menuitem menuitemid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.menuitem
    ADD CONSTRAINT menuitemid_unq UNIQUE (menuitemid);


--
-- TOC entry 6323 (class 2606 OID 2951718)
-- Name: modifier_group_mapping modfrgrp_modfr_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group_mapping
    ADD CONSTRAINT modfrgrp_modfr_unq UNIQUE (modifiergroupid, modifierid);


--
-- TOC entry 6332 (class 2606 OID 2951561)
-- Name: modifier_group modifier_group_master_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group
    ADD CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid);


--
-- TOC entry 6325 (class 2606 OID 2196815)
-- Name: modifier_group_mapping modifier_group_modifier_glue_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier_group_mapping
    ADD CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id);


--
-- TOC entry 6321 (class 2606 OID 2888243)
-- Name: modifier modifierid_unq; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.modifier
    ADD CONSTRAINT modifierid_unq UNIQUE (modifierid);


--
-- TOC entry 6296 (class 2606 OID 672299)
-- Name: ordertype_bkp ordertype_bkp_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype_bkp
    ADD CONSTRAINT ordertype_bkp_pk PRIMARY KEY (id);


--
-- TOC entry 6189 (class 2606 OID 32886)
-- Name: ordertype ordertype_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.ordertype
    ADD CONSTRAINT ordertype_pk PRIMARY KEY (id);


--
-- TOC entry 6277 (class 2606 OID 431163)
-- Name: organization organization_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- TOC entry 6194 (class 2606 OID 775937)
-- Name: organizationlocation organizationid_locationid_pk; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.organizationlocation
    ADD CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 6270 (class 2606 OID 413646)
-- Name: peripheral peripheral_deviceid_peripheralid_key; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_peripheralid_key UNIQUE (deviceid, peripheralid);


--
-- TOC entry 6273 (class 2606 OID 413644)
-- Name: peripheral peripheral_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_pkey PRIMARY KEY (id);


--
-- TOC entry 6349 (class 2606 OID 3087662)
-- Name: occasionsurvey survey_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.occasionsurvey
    ADD CONSTRAINT survey_pkey PRIMARY KEY (surveykey);


--
-- TOC entry 6287 (class 2606 OID 471809)
-- Name: upsellgrouplookup upsellgroupid_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.upsellgrouplookup
    ADD CONSTRAINT upsellgroupid_pkey PRIMARY KEY (upsellgroupid);


--
-- TOC entry 6231 (class 2606 OID 103204)
-- Name: userlocation userlocation_pkey; Type: CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.userlocation
    ADD CONSTRAINT userlocation_pkey PRIMARY KEY (userid, locationid);


--
-- TOC entry 6359 (class 2606 OID 3518729)
-- Name: bronze_partition_registry bronze_partition_registry_pkey; Type: CONSTRAINT; Schema: etl; Owner: citus
--

ALTER TABLE ONLY etl.bronze_partition_registry
    ADD CONSTRAINT bronze_partition_registry_pkey PRIMARY KEY (entity, dateid);


--
-- TOC entry 6233 (class 2606 OID 3650141)
-- Name: devicetelemetry devicetelemetry_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT devicetelemetry_pkey PRIMARY KEY (locationid, deviceid, dateid);


--
-- TOC entry 6301 (class 2606 OID 694784)
-- Name: location_menu_preferences location_dayparts_itemid_itemtype_unq; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.location_menu_preferences
    ADD CONSTRAINT location_dayparts_itemid_itemtype_unq UNIQUE (locationid, day_parts, itemid, itemtype);


--
-- TOC entry 6209 (class 2606 OID 3702330)
-- Name: ordertiming locationid_eventtoken_unq; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.ordertiming
    ADD CONSTRAINT locationid_eventtoken_unq UNIQUE (locationid, eventtoken);


--
-- TOC entry 6279 (class 2606 OID 775712)
-- Name: recommendations locationid_trxnid_recommendationid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT locationid_trxnid_recommendationid_pk PRIMARY KEY (locationid, transactionheaderid, recommendationid);


--
-- TOC entry 6211 (class 2606 OID 32958)
-- Name: ordertiming ordertiming_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.ordertiming
    ADD CONSTRAINT ordertiming_pkey PRIMARY KEY (id);


--
-- TOC entry 6312 (class 2606 OID 888772)
-- Name: pos_sales_details pos_sales_details_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.pos_sales_details
    ADD CONSTRAINT pos_sales_details_pkey PRIMARY KEY (id);


--
-- TOC entry 6334 (class 2606 OID 2987108)
-- Name: sent_surveys sent_surveys_ordersessionid_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.sent_surveys
    ADD CONSTRAINT sent_surveys_ordersessionid_pkey PRIMARY KEY (locationid, ordersessionid);


--
-- TOC entry 6214 (class 2606 OID 32976)
-- Name: timingsdatalake timingsdatalake_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.timingsdatalake
    ADD CONSTRAINT timingsdatalake_pkey PRIMARY KEY (containername);


--
-- TOC entry 6218 (class 2606 OID 294801)
-- Name: transactionheader transactionheader_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT transactionheader_pkey PRIMARY KEY (locationid, transactionheaderid);


--
-- TOC entry 6281 (class 2606 OID 454567)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 6221 (class 2606 OID 57357)
-- Name: transactionitem transactionitem_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT transactionitem_pkey PRIMARY KEY (transactionheaderid, itemid, itemname);


--
-- TOC entry 6207 (class 2606 OID 1175206)
-- Name: itemmodifier trxnid_itemid_mdfrgrpid_mdfrid_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemmodifier
    ADD CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY KEY (transactionheaderid, itemid, modifiergroupid, modifierid);


--
-- TOC entry 6299 (class 2606 OID 676695)
-- Name: vw_offer_analysis trxnid_recommendationid_itemid_uidx; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT trxnid_recommendationid_itemid_uidx UNIQUE (transactionheaderid, recommendationid, offereditem);


--
-- TOC entry 6283 (class 2606 OID 459796)
-- Name: userbehaviour_exceptions userbehaviour_exceptions_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour_exceptions
    ADD CONSTRAINT userbehaviour_exceptions_pkey PRIMARY KEY (id);


--
-- TOC entry 6227 (class 2606 OID 33010)
-- Name: userbehaviour userbehaviour_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.userbehaviour
    ADD CONSTRAINT userbehaviour_pkey PRIMARY KEY (id);


--
-- TOC entry 6238 (class 2606 OID 3652822)
-- Name: usercheckedin usercheckedin_pkey; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.usercheckedin
    ADD CONSTRAINT usercheckedin_pkey PRIMARY KEY (locationid, orderid);


--
-- TOC entry 6229 (class 2606 OID 3735734)
-- Name: watermarktable watermarktablename_pk; Type: CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.watermarktable
    ADD CONSTRAINT watermarktablename_pk PRIMARY KEY (watermarktablename, source);


--
-- TOC entry 6168 (class 2606 OID 32809)
-- Name: schemaversions PK_schemaversions_Id; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.schemaversions
    ADD CONSTRAINT "PK_schemaversions_Id" PRIMARY KEY (schemaversionsid);


--
-- TOC entry 6242 (class 2606 OID 227937)
-- Name: report report_pkey; Type: CONSTRAINT; Schema: public; Owner: citus
--

ALTER TABLE ONLY public.report
    ADD CONSTRAINT report_pkey PRIMARY KEY (id);


--
-- TOC entry 6371 (class 2606 OID 3589002)
-- Name: dim_catalog catalog_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_catalog
    ADD CONSTRAINT catalog_pkey PRIMARY KEY (catalogid);


--
-- TOC entry 6361 (class 2606 OID 3584739)
-- Name: dim_frequentcustomer frequent_customer_pk; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_frequentcustomer
    ADD CONSTRAINT frequent_customer_pk PRIMARY KEY (frequentcustomerid);


--
-- TOC entry 6363 (class 2606 OID 3586063)
-- Name: dim_category_hierarchy location_category_menuitem_unq; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_category_hierarchy
    ADD CONSTRAINT location_category_menuitem_unq UNIQUE (locationid, categoryid, menuitemid);


--
-- TOC entry 6367 (class 2606 OID 3586088)
-- Name: dim_modifiergroup_modifier_mapping modfrgrp_modfr_unq; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_modifiergroup_modifier_mapping
    ADD CONSTRAINT modfrgrp_modfr_unq UNIQUE (modifiergroupid, modifierid);


--
-- TOC entry 6365 (class 2606 OID 3586079)
-- Name: dim_modifiergroup modifier_group_master_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_modifiergroup
    ADD CONSTRAINT modifier_group_master_pkey PRIMARY KEY (modifiergroupid);


--
-- TOC entry 6369 (class 2606 OID 3586086)
-- Name: dim_modifiergroup_modifier_mapping modifier_group_modifier_glue_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_modifiergroup_modifier_mapping
    ADD CONSTRAINT modifier_group_modifier_glue_pkey PRIMARY KEY (modifier_mapping_id);


--
-- TOC entry 6375 (class 2606 OID 3644486)
-- Name: dim_organization organization_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_organization
    ADD CONSTRAINT organization_pkey PRIMARY KEY (id);


--
-- TOC entry 6373 (class 2606 OID 3605523)
-- Name: dim_organizationlocation organizationid_locationid_pk; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.dim_organizationlocation
    ADD CONSTRAINT organizationid_locationid_pk PRIMARY KEY (organizationid, locationid);


--
-- TOC entry 6351 (class 2606 OID 3244118)
-- Name: transactionheader pk_transactionheader; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.transactionheader
    ADD CONSTRAINT pk_transactionheader PRIMARY KEY (id);


--
-- TOC entry 6329 (class 2606 OID 2959149)
-- Name: sent_surveys sent_surveys_ordersessionid_pkey; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.sent_surveys
    ADD CONSTRAINT sent_surveys_ordersessionid_pkey PRIMARY KEY (locationid, ordersessionid);


--
-- TOC entry 6285 (class 2606 OID 461044)
-- Name: recommendations transactionheaderid_recommendationid_uidx; Type: CONSTRAINT; Schema: stg; Owner: citus
--

ALTER TABLE ONLY stg.recommendations
    ADD CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);


--
-- TOC entry 6172 (class 1259 OID 32826)
-- Name: IX_dateid_datets; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX "IX_dateid_datets" ON dim.datedim USING btree (dateid, datets);


--
-- TOC entry 6190 (class 1259 OID 32893)
-- Name: IX_organizationid_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX "IX_organizationid_locationid" ON dim.organizationlocation USING btree (organizationid, locationid) INCLUDE (organizationname, locationname);


--
-- TOC entry 6169 (class 1259 OID 32818)
-- Name: company_id_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX company_id_idx ON dim.company USING btree (companyid);


--
-- TOC entry 6264 (class 1259 OID 413633)
-- Name: deviceid_locationid_companyid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX deviceid_locationid_companyid_idx ON dim.device USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, state, testmode);


--
-- TOC entry 6183 (class 1259 OID 32870)
-- Name: dim_location_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX dim_location_idx ON dim.location USING btree (locationid);


--
-- TOC entry 6175 (class 1259 OID 32827)
-- Name: idx_datedim_dateid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_datedim_dateid ON dim.datedim USING btree (dateid);


--
-- TOC entry 6176 (class 1259 OID 32828)
-- Name: idx_datedim_datets; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_datedim_datets ON dim.datedim USING btree (datets);


--
-- TOC entry 6265 (class 1259 OID 413634)
-- Name: idx_device_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_id ON dim.device USING btree (deviceid);


--
-- TOC entry 6266 (class 1259 OID 413635)
-- Name: idx_device_location_id; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_location_id ON dim.device USING btree (locationid);


--
-- TOC entry 6267 (class 1259 OID 413636)
-- Name: idx_device_state; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_state ON dim.device USING btree (state);


--
-- TOC entry 6268 (class 1259 OID 413637)
-- Name: idx_device_testmode; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_device_testmode ON dim.device USING btree (testmode);


--
-- TOC entry 6302 (class 1259 OID 695510)
-- Name: idx_menuentities_catalog; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_menuentities_catalog ON dim.menuentities USING btree (catalogid);


--
-- TOC entry 6303 (class 1259 OID 695512)
-- Name: idx_menuentities_mealavail; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_menuentities_mealavail ON dim.menuentities USING gin (mealavailability);


--
-- TOC entry 6304 (class 1259 OID 695511)
-- Name: idx_menuentities_tags; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_menuentities_tags ON dim.menuentities USING gin (tags);


--
-- TOC entry 6191 (class 1259 OID 32894)
-- Name: idx_organizationlocation_locationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_organizationlocation_locationid ON dim.organizationlocation USING btree (locationid);


--
-- TOC entry 6192 (class 1259 OID 32895)
-- Name: idx_organizationlocation_organizationid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_organizationlocation_organizationid ON dim.organizationlocation USING btree (organizationid);


--
-- TOC entry 6195 (class 1259 OID 32911)
-- Name: idx_view_viewid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX idx_view_viewid ON dim.view USING btree (viewid);


--
-- TOC entry 6288 (class 1259 OID 514419)
-- Name: itemcategory_bkp_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX itemcategory_bkp_idx ON dim.itemcategory_bkp USING btree (locationid, categoryid);


--
-- TOC entry 6289 (class 1259 OID 514420)
-- Name: itemcategory_bkp_locationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX itemcategory_bkp_locationid_idx ON dim.itemcategory_bkp USING btree (locationid) INCLUDE (categoryid, isactive);


--
-- TOC entry 6179 (class 1259 OID 32845)
-- Name: itemcategory_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX itemcategory_idx ON dim.itemcategory USING btree (locationid, categoryid);


--
-- TOC entry 6180 (class 1259 OID 263819)
-- Name: itemcategory_locationid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX itemcategory_locationid_idx ON dim.itemcategory USING btree (locationid) INCLUDE (categoryid, isactive);


--
-- TOC entry 6251 (class 1259 OID 3399343)
-- Name: ix_dim_menuitem_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX ix_dim_menuitem_catalogid ON dim.menuitem USING btree (catalogid);


--
-- TOC entry 6319 (class 1259 OID 3399344)
-- Name: ix_dim_modifier_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX ix_dim_modifier_catalogid ON dim.modifier USING btree (catalogid);


--
-- TOC entry 6330 (class 1259 OID 3399345)
-- Name: ix_dim_modifiergroup_catalogid; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX ix_dim_modifiergroup_catalogid ON dim.modifier_group USING btree (catalogid);


--
-- TOC entry 6186 (class 1259 OID 263829)
-- Name: locationgroupid_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX locationgroupid_idx ON dim.location USING btree (locationgroupid);


--
-- TOC entry 6187 (class 1259 OID 32887)
-- Name: order_type_uidx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE UNIQUE INDEX order_type_uidx ON dim.ordertype USING btree (locationid, kioskid, ordertypeid);


--
-- TOC entry 6271 (class 1259 OID 413652)
-- Name: peripheral_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX peripheral_idx ON dim.peripheral USING btree (deviceid, peripheralid) INCLUDE (peripheraltype, state, statechangedate);


--
-- TOC entry 6240 (class 1259 OID 263813)
-- Name: rating_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX rating_idx ON dim.feedbackrating USING btree (rating) INCLUDE (ratingdesc);


--
-- TOC entry 6239 (class 1259 OID 263814)
-- Name: surveytransstatus_idx; Type: INDEX; Schema: dim; Owner: citus
--

CREATE INDEX surveytransstatus_idx ON dim.feedbackstatus USING btree (surveytransstatus) INCLUDE (statusdesc);


--
-- TOC entry 6196 (class 1259 OID 32927)
-- Name: deviceeventidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX deviceeventidx ON fact.deviceevent USING btree (companyid, locationid);


--
-- TOC entry 6197 (class 1259 OID 32928)
-- Name: deviceeventuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX deviceeventuidx ON fact.deviceevent USING btree (application, companyid, locationid, moduleid, eventtoken, datacategory, actiontype, eventinstant);


--
-- TOC entry 6376 (class 1259 OID 3735738)
-- Name: devicehealth_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX devicehealth_idx ON fact.devicehealth USING btree (deviceid, locationid, companyid) INCLUDE (devicetype, status, healthdatatype, healthdatatime, statuschangetime);


--
-- TOC entry 6377 (class 1259 OID 3735739)
-- Name: deviceid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX deviceid_idx ON fact.devicehealth USING btree (deviceid);


--
-- TOC entry 6378 (class 1259 OID 3735740)
-- Name: idx_devicehealth_deviceid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicehealth_deviceid ON fact.devicehealth USING btree (deviceid);


--
-- TOC entry 6379 (class 1259 OID 3735741)
-- Name: idx_devicehealth_deviceid_status_time; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicehealth_deviceid_status_time ON fact.devicehealth USING btree (deviceid, status, healthdatatime DESC);


--
-- TOC entry 6380 (class 1259 OID 3735742)
-- Name: idx_devicehealth_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicehealth_locationid ON fact.devicehealth USING btree (locationid);


--
-- TOC entry 6200 (class 1259 OID 32934)
-- Name: idx_devicestate; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicestate ON fact.devicestate USING btree (locationid, companyid, deviceid) WITH (deduplicate_items='true');


--
-- TOC entry 6201 (class 1259 OID 32935)
-- Name: idx_devicestate_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicestate_dateid ON fact.devicestate USING btree (dateid);


--
-- TOC entry 6202 (class 1259 OID 32936)
-- Name: idx_devicestate_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicestate_locationid ON fact.devicestate USING btree (locationid);


--
-- TOC entry 6234 (class 1259 OID 159819)
-- Name: idx_devicetelemetry; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicetelemetry ON fact.devicetelemetry USING btree (locationid, deviceid);


--
-- TOC entry 6235 (class 1259 OID 159820)
-- Name: idx_devicetelemetry_dateid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicetelemetry_dateid ON fact.devicetelemetry USING btree (dateid);


--
-- TOC entry 6236 (class 1259 OID 159821)
-- Name: idx_devicetelemetry_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_devicetelemetry_locationid ON fact.devicetelemetry USING btree (locationid);


--
-- TOC entry 6203 (class 1259 OID 3584720)
-- Name: idx_fact_itemmodifier_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_fact_itemmodifier_locationid ON fact.itemmodifier USING btree (locationid);


--
-- TOC entry 6212 (class 1259 OID 309287)
-- Name: idx_fact_pipelinerunstatus_correlationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_fact_pipelinerunstatus_correlationid ON fact.pipelinerunstatus USING btree (correlationid) INCLUDE (pipelinestatus);


--
-- TOC entry 6219 (class 1259 OID 3583313)
-- Name: idx_fact_transactionitem_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_fact_transactionitem_locationid ON fact.transactionitem USING btree (locationid);


--
-- TOC entry 6222 (class 1259 OID 3583314)
-- Name: idx_fact_transactionpayment_locationid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_fact_transactionpayment_locationid ON fact.transactionpayment USING btree (locationid);


--
-- TOC entry 6292 (class 1259 OID 547181)
-- Name: idx_transactionrefunds_headerid; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX idx_transactionrefunds_headerid ON fact.transactionrefunds USING btree (transactionheaderid);


--
-- TOC entry 6204 (class 1259 OID 32951)
-- Name: itemmodifieridx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX itemmodifieridx ON fact.itemmodifier USING btree (itemid);


--
-- TOC entry 6198 (class 1259 OID 2198165)
-- Name: ix_deviceevent_journey_lookup; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX ix_deviceevent_journey_lookup ON fact.deviceevent USING btree (locationid, dateid, datacategory, eventtoken) WHERE ((datacategory = 'insight'::text) AND (actiontype = ANY (ARRAY['CategorySelected'::text, 'SubCategorySelected'::text, 'RegularItemSelected'::text, 'ItemRemoved'::text, 'ModifierGroupSelected'::text, 'ModifierSelected'::text, 'ModifierUnselected'::text])));


--
-- TOC entry 6199 (class 1259 OID 3605477)
-- Name: ix_deviceevent_syscosmosts_brin; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX ix_deviceevent_syscosmosts_brin ON fact.deviceevent USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6215 (class 1259 OID 3617347)
-- Name: ix_transactionheader_syscosmosts_brin; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX ix_transactionheader_syscosmosts_brin ON fact.transactionheader USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6224 (class 1259 OID 3617344)
-- Name: ix_userbehaviour_syscosmosts_brin; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX ix_userbehaviour_syscosmosts_brin ON fact.userbehaviour USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6297 (class 1259 OID 676696)
-- Name: locationid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX locationid_idx ON fact.vw_offer_analysis USING btree (locationid);


--
-- TOC entry 6216 (class 1259 OID 263880)
-- Name: transactionheader_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionheader_locationid_dateid_idx ON fact.transactionheader USING btree (locationid, dateid) INCLUDE (orderstatus, ordertype, businessdate);


--
-- TOC entry 6205 (class 1259 OID 263867)
-- Name: transactionheaderid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionheaderid_idx ON fact.itemmodifier USING btree (transactionheaderid);


--
-- TOC entry 6223 (class 1259 OID 33003)
-- Name: transactionpaymentuidx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX transactionpaymentuidx ON fact.transactionpayment USING btree (transactionheaderid, paymentintegrationid, paymentid);


--
-- TOC entry 6225 (class 1259 OID 263900)
-- Name: userbehaviour_locationid_dateid_idx; Type: INDEX; Schema: fact; Owner: citus
--

CREATE INDEX userbehaviour_locationid_dateid_idx ON fact.userbehaviour USING btree (locationid, dateid) INCLUDE (ordersessionidentifier, viewidentifier, itemsessionidentifier, elementidentifier);


--
-- TOC entry 6347 (class 1259 OID 3050933)
-- Name: ix_ml_imm_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_imm_locationid ON ml.item_modifiergroup_modifier_mapping USING btree (locationid);


--
-- TOC entry 6342 (class 1259 OID 3044539)
-- Name: ix_ml_me_locationid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_me_locationid ON ml.menu_entities USING btree (locationid);


--
-- TOC entry 6343 (class 1259 OID 3044540)
-- Name: ix_ml_me_menuitemid; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_me_menuitemid ON ml.menu_entities USING btree (menuitemid);


--
-- TOC entry 6345 (class 1259 OID 3050934)
-- Name: ix_ml_mi_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_mi_locid_yyyy_ww ON ml.modifier_interactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6346 (class 1259 OID 3050935)
-- Name: ix_ml_mimp_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_mimp_locid_yyyy_ww ON ml.modifier_impressions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6344 (class 1259 OID 3050806)
-- Name: ix_ml_trx_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_trx_locid_yyyy_ww ON ml.transactions USING btree (locationid, yyyy, ww);


--
-- TOC entry 6335 (class 1259 OID 3042200)
-- Name: ix_ml_ua_businessdate; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_ua_businessdate ON ml.upsell_analysis USING btree (businessdate);


--
-- TOC entry 6336 (class 1259 OID 3042199)
-- Name: ix_ml_ua_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_ua_locid_yyyy_ww ON ml.upsell_analysis USING btree (locationid, yyyy, ww);


--
-- TOC entry 6337 (class 1259 OID 3042198)
-- Name: ix_ml_ua_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_ua_yyyy_ww ON ml.upsell_analysis USING btree (yyyy, ww);


--
-- TOC entry 6338 (class 1259 OID 3044148)
-- Name: ix_ml_wth_locationid_weatherdate_hh; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_wth_locationid_weatherdate_hh ON ml.weather USING btree (locationid, weatherdate, hh);


--
-- TOC entry 6339 (class 1259 OID 3042228)
-- Name: ix_ml_wth_locid_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_wth_locid_yyyy_ww ON ml.weather USING btree (locationid, yyyy, ww);


--
-- TOC entry 6340 (class 1259 OID 3042229)
-- Name: ix_ml_wth_weatherdate; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_wth_weatherdate ON ml.weather USING btree (weatherdate);


--
-- TOC entry 6341 (class 1259 OID 3042227)
-- Name: ix_ml_wth_yyyy_ww; Type: INDEX; Schema: ml; Owner: citus
--

CREATE INDEX ix_ml_wth_yyyy_ww ON ml.weather USING btree (yyyy, ww);


--
-- TOC entry 6356 (class 1259 OID 3703824)
-- Name: ix_silver_kiosk_events_syscosmosts; Type: INDEX; Schema: stg; Owner: citus
--

CREATE INDEX ix_silver_kiosk_events_syscosmosts ON stg.silver_kiosk_events USING btree (syscosmosts);


--
-- TOC entry 6357 (class 1259 OID 3605478)
-- Name: ix_silver_kiosk_events_syscosmosts_brin; Type: INDEX; Schema: stg; Owner: citus
--

CREATE INDEX ix_silver_kiosk_events_syscosmosts_brin ON stg.silver_kiosk_events USING brin (syscosmosts) WITH (pages_per_range='128');


--
-- TOC entry 6401 (class 2606 OID 3327449)
-- Name: vw_grubbrrinstallbase_all_devices organizationid_locationid_fk; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.vw_grubbrrinstallbase_all_devices
    ADD CONSTRAINT organizationid_locationid_fk FOREIGN KEY (organization_id, location_id) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6397 (class 2606 OID 413647)
-- Name: peripheral peripheral_deviceid_fkey; Type: FK CONSTRAINT; Schema: dim; Owner: citus
--

ALTER TABLE ONLY dim.peripheral
    ADD CONSTRAINT peripheral_deviceid_fkey FOREIGN KEY (deviceid) REFERENCES dim.device(id);


--
-- TOC entry 6385 (class 2606 OID 514947)
-- Name: transactionitem categoryid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT categoryid_fk FOREIGN KEY (categoryid) REFERENCES dim.itemcategory(id);


--
-- TOC entry 6390 (class 2606 OID 788239)
-- Name: devicetelemetry location_deviceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT location_deviceid_fk FOREIGN KEY (locationid, deviceid) REFERENCES dim.kiosk(locationid, kioskid);


--
-- TOC entry 6398 (class 2606 OID 775338)
-- Name: recommendations location_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.recommendations
    ADD CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6391 (class 2606 OID 788249)
-- Name: devicetelemetry locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.devicetelemetry
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6382 (class 2606 OID 775954)
-- Name: transactionheader locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6386 (class 2606 OID 779636)
-- Name: transactionitem locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);


--
-- TOC entry 6392 (class 2606 OID 784801)
-- Name: itemssurvey locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6394 (class 2606 OID 784796)
-- Name: occasionsurveydetail locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6387 (class 2606 OID 2970909)
-- Name: transactionitem locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6389 (class 2606 OID 775974)
-- Name: transactionpayment locationid_transactionheaderid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionpayment
    ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);


--
-- TOC entry 6399 (class 2606 OID 775984)
-- Name: vw_offer_analysis locationid_trxnid_recommendationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT locationid_trxnid_recommendationid_fk FOREIGN KEY (locationid, transactionheaderid, recommendationid) REFERENCES fact.recommendations(locationid, transactionheaderid, recommendationid);


--
-- TOC entry 6388 (class 2606 OID 359444)
-- Name: transactionitem menuitemid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionitem
    ADD CONSTRAINT menuitemid_fk FOREIGN KEY (menuitemid) REFERENCES dim.menuitem(id);


--
-- TOC entry 6383 (class 2606 OID 775964)
-- Name: transactionheader ordertype_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT ordertype_fk FOREIGN KEY (ordertype) REFERENCES dim.ordertype(id);


--
-- TOC entry 6381 (class 2606 OID 788254)
-- Name: deviceevent orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.deviceevent
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (companyid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6393 (class 2606 OID 788219)
-- Name: itemssurvey orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.itemssurvey
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6395 (class 2606 OID 788224)
-- Name: occasionsurveydetail orgid_locationid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


--
-- TOC entry 6400 (class 2606 OID 779648)
-- Name: vw_offer_analysis selecteditem_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.vw_offer_analysis
    ADD CONSTRAINT selecteditem_fk FOREIGN KEY (selecteditem) REFERENCES dim.menuitem(menuitemid);


--
-- TOC entry 6396 (class 2606 OID 774836)
-- Name: occasionsurveydetail sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.occasionsurveydetail
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);


--
-- TOC entry 6384 (class 2606 OID 787892)
-- Name: transactionheader sourceid_fk; Type: FK CONSTRAINT; Schema: fact; Owner: citus
--

ALTER TABLE ONLY fact.transactionheader
    ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id);


--
-- TOC entry 6576 (class 0 OID 0)
-- Dependencies: 64
-- Name: SCHEMA dim; Type: ACL; Schema: -; Owner: citus
--

GRANT USAGE ON SCHEMA dim TO dhanraj;
GRANT USAGE ON SCHEMA dim TO varshil;


--
-- TOC entry 6577 (class 0 OID 0)
-- Dependencies: 65
-- Name: SCHEMA fact; Type: ACL; Schema: -; Owner: citus
--

GRANT USAGE ON SCHEMA fact TO dhanraj;
GRANT USAGE ON SCHEMA fact TO varshil;


--
-- TOC entry 6579 (class 0 OID 0)
-- Dependencies: 62
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON SCHEMA public TO citus WITH GRANT OPTION;
SET SESSION AUTHORIZATION citus;
GRANT USAGE ON SCHEMA public TO varshil;
RESET SESSION AUTHORIZATION;


--
-- TOC entry 6580 (class 0 OID 0)
-- Dependencies: 869
-- Name: FUNCTION create_extension(extname text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.create_extension(extname text) TO citus WITH GRANT OPTION;


--
-- TOC entry 6581 (class 0 OID 0)
-- Dependencies: 965
-- Name: FUNCTION drop_extension(extname text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.drop_extension(extname text) TO citus WITH GRANT OPTION;


--
-- TOC entry 6582 (class 0 OID 0)
-- Dependencies: 1379
-- Name: FUNCTION pg_replication_origin_create(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_create(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_create(text) TO citus;


--
-- TOC entry 6583 (class 0 OID 0)
-- Dependencies: 1328
-- Name: FUNCTION pg_replication_origin_drop(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_drop(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_drop(text) TO citus;


--
-- TOC entry 6584 (class 0 OID 0)
-- Dependencies: 764
-- Name: FUNCTION pg_replication_origin_progress(text, boolean); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_progress(text, boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_progress(text, boolean) TO citus;


--
-- TOC entry 6585 (class 0 OID 0)
-- Dependencies: 1567
-- Name: FUNCTION pg_replication_origin_session_progress(boolean); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_session_progress(boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_session_progress(boolean) TO citus;


--
-- TOC entry 6586 (class 0 OID 0)
-- Dependencies: 615
-- Name: FUNCTION pg_replication_origin_session_setup(text); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_session_setup(text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_session_setup(text) TO citus;


--
-- TOC entry 6587 (class 0 OID 0)
-- Dependencies: 1360
-- Name: FUNCTION pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone); Type: ACL; Schema: public; Owner: postgres
--

REVOKE ALL ON FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION public.pg_replication_origin_xact_setup(pg_lsn, timestamp with time zone) TO citus;


--
-- TOC entry 6588 (class 0 OID 0)
-- Dependencies: 419
-- Name: TABLE abtests; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.abtests TO varshil;


--
-- TOC entry 6589 (class 0 OID 0)
-- Dependencies: 389
-- Name: TABLE datedim; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.datedim TO dhanraj;
GRANT SELECT ON TABLE dim.datedim TO varshil;


--
-- TOC entry 6590 (class 0 OID 0)
-- Dependencies: 396
-- Name: TABLE businessdate; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.businessdate TO dhanraj;
GRANT SELECT ON TABLE dim.businessdate TO varshil;


--
-- TOC entry 6591 (class 0 OID 0)
-- Dependencies: 388
-- Name: TABLE company; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.company TO dhanraj;
GRANT SELECT ON TABLE dim.company TO varshil;


--
-- TOC entry 6592 (class 0 OID 0)
-- Dependencies: 425
-- Name: TABLE device; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.device TO varshil;


--
-- TOC entry 6593 (class 0 OID 0)
-- Dependencies: 390
-- Name: TABLE element; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.element TO dhanraj;
GRANT SELECT ON TABLE dim.element TO varshil;


--
-- TOC entry 6595 (class 0 OID 0)
-- Dependencies: 428
-- Name: TABLE experiment; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.experiment TO varshil;


--
-- TOC entry 6597 (class 0 OID 0)
-- Dependencies: 413
-- Name: TABLE feedbackrating; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackrating TO varshil;


--
-- TOC entry 6598 (class 0 OID 0)
-- Dependencies: 412
-- Name: TABLE feedbackstatus; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.feedbackstatus TO varshil;


--
-- TOC entry 6599 (class 0 OID 0)
-- Dependencies: 416
-- Name: TABLE frequentcustomer; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.frequentcustomer TO varshil;


--
-- TOC entry 6601 (class 0 OID 0)
-- Dependencies: 445
-- Name: TABLE grubbrr_source_lookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.grubbrr_source_lookup TO varshil;


--
-- TOC entry 6602 (class 0 OID 0)
-- Dependencies: 391
-- Name: TABLE itemcategory; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory TO dhanraj;
GRANT SELECT ON TABLE dim.itemcategory TO varshil;


--
-- TOC entry 6603 (class 0 OID 0)
-- Dependencies: 435
-- Name: TABLE itemcategory_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategory_bkp TO varshil;


--
-- TOC entry 6605 (class 0 OID 0)
-- Dependencies: 439
-- Name: TABLE itemcategorymapping; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.itemcategorymapping TO varshil;


--
-- TOC entry 6606 (class 0 OID 0)
-- Dependencies: 417
-- Name: TABLE kiosk; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kiosk TO varshil;


--
-- TOC entry 6608 (class 0 OID 0)
-- Dependencies: 438
-- Name: TABLE kioskdetails; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.kioskdetails TO varshil;


--
-- TOC entry 6609 (class 0 OID 0)
-- Dependencies: 392
-- Name: TABLE location; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.location TO dhanraj;
GRANT SELECT ON TABLE dim.location TO varshil;


--
-- TOC entry 6610 (class 0 OID 0)
-- Dependencies: 418
-- Name: TABLE locationcatalog; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.locationcatalog TO varshil;


--
-- TOC entry 6611 (class 0 OID 0)
-- Dependencies: 444
-- Name: TABLE menuentities; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuentities TO varshil;


--
-- TOC entry 6612 (class 0 OID 0)
-- Dependencies: 422
-- Name: TABLE menuitem; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.menuitem TO varshil;


--
-- TOC entry 6615 (class 0 OID 0)
-- Dependencies: 393
-- Name: TABLE ordertype; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype TO dhanraj;
GRANT SELECT ON TABLE dim.ordertype TO varshil;


--
-- TOC entry 6616 (class 0 OID 0)
-- Dependencies: 440
-- Name: TABLE ordertype_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.ordertype_bkp TO varshil;


--
-- TOC entry 6618 (class 0 OID 0)
-- Dependencies: 429
-- Name: TABLE organization; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organization TO varshil;


--
-- TOC entry 6619 (class 0 OID 0)
-- Dependencies: 394
-- Name: TABLE organizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.organizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.organizationlocation TO varshil;


--
-- TOC entry 6620 (class 0 OID 0)
-- Dependencies: 426
-- Name: TABLE peripheral; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.peripheral TO varshil;


--
-- TOC entry 6621 (class 0 OID 0)
-- Dependencies: 434
-- Name: TABLE upsellgrouplookup; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.upsellgrouplookup TO varshil;


--
-- TOC entry 6622 (class 0 OID 0)
-- Dependencies: 409
-- Name: TABLE userlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.userlocation TO varshil;


--
-- TOC entry 6623 (class 0 OID 0)
-- Dependencies: 395
-- Name: TABLE view; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.view TO dhanraj;
GRANT SELECT ON TABLE dim.view TO varshil;


--
-- TOC entry 6624 (class 0 OID 0)
-- Dependencies: 424
-- Name: TABLE weather; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather TO varshil;


--
-- TOC entry 6625 (class 0 OID 0)
-- Dependencies: 451
-- Name: TABLE vw_weatherhourlydata; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vw_weatherhourlydata TO varshil;


--
-- TOC entry 6626 (class 0 OID 0)
-- Dependencies: 397
-- Name: TABLE vworganizationlocation; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.vworganizationlocation TO dhanraj;
GRANT SELECT ON TABLE dim.vworganizationlocation TO varshil;


--
-- TOC entry 6627 (class 0 OID 0)
-- Dependencies: 423
-- Name: TABLE weather_bkp; Type: ACL; Schema: dim; Owner: citus
--

GRANT SELECT ON TABLE dim.weather_bkp TO varshil;


--
-- TOC entry 6628 (class 0 OID 0)
-- Dependencies: 450
-- Name: TABLE cep_incidents; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.cep_incidents TO dhanraj;


--
-- TOC entry 6629 (class 0 OID 0)
-- Dependencies: 442
-- Name: TABLE customer_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.customer_menu_preferences TO varshil;


--
-- TOC entry 6630 (class 0 OID 0)
-- Dependencies: 398
-- Name: TABLE deviceevent; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.deviceevent TO dhanraj;
GRANT SELECT ON TABLE fact.deviceevent TO varshil;


--
-- TOC entry 6631 (class 0 OID 0)
-- Dependencies: 399
-- Name: TABLE devicestate; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicestate TO dhanraj;
GRANT SELECT ON TABLE fact.devicestate TO varshil;


--
-- TOC entry 6633 (class 0 OID 0)
-- Dependencies: 410
-- Name: TABLE devicetelemetry; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.devicetelemetry TO varshil;


--
-- TOC entry 6634 (class 0 OID 0)
-- Dependencies: 400
-- Name: TABLE itemmodifier; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemmodifier TO dhanraj;
GRANT SELECT ON TABLE fact.itemmodifier TO varshil;


--
-- TOC entry 6635 (class 0 OID 0)
-- Dependencies: 420
-- Name: TABLE itemssurvey; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.itemssurvey TO varshil;


--
-- TOC entry 6636 (class 0 OID 0)
-- Dependencies: 443
-- Name: TABLE location_menu_preferences; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.location_menu_preferences TO varshil;


--
-- TOC entry 6637 (class 0 OID 0)
-- Dependencies: 421
-- Name: TABLE occasionsurveydetail; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.occasionsurveydetail TO varshil;


--
-- TOC entry 6638 (class 0 OID 0)
-- Dependencies: 401
-- Name: TABLE ordertiming; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.ordertiming TO dhanraj;
GRANT SELECT ON TABLE fact.ordertiming TO varshil;


--
-- TOC entry 6640 (class 0 OID 0)
-- Dependencies: 402
-- Name: TABLE pipelinerunstatus; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.pipelinerunstatus TO dhanraj;
GRANT SELECT ON TABLE fact.pipelinerunstatus TO varshil;


--
-- TOC entry 6641 (class 0 OID 0)
-- Dependencies: 431
-- Name: TABLE recommendations; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.recommendations TO varshil;


--
-- TOC entry 6642 (class 0 OID 0)
-- Dependencies: 430
-- Name: TABLE recommendations_bkp; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.recommendations_bkp TO varshil;


--
-- TOC entry 6643 (class 0 OID 0)
-- Dependencies: 403
-- Name: TABLE timingsdatalake; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.timingsdatalake TO dhanraj;
GRANT SELECT ON TABLE fact.timingsdatalake TO varshil;


--
-- TOC entry 6644 (class 0 OID 0)
-- Dependencies: 404
-- Name: TABLE transactionheader; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionheader TO dhanraj;
GRANT SELECT ON TABLE fact.transactionheader TO varshil;


--
-- TOC entry 6646 (class 0 OID 0)
-- Dependencies: 405
-- Name: TABLE transactionitem; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionitem TO dhanraj;
GRANT SELECT ON TABLE fact.transactionitem TO varshil;


--
-- TOC entry 6647 (class 0 OID 0)
-- Dependencies: 406
-- Name: TABLE transactionpayment; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionpayment TO dhanraj;
GRANT SELECT ON TABLE fact.transactionpayment TO varshil;


--
-- TOC entry 6648 (class 0 OID 0)
-- Dependencies: 436
-- Name: TABLE transactionrefunds; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.transactionrefunds TO varshil;


--
-- TOC entry 6649 (class 0 OID 0)
-- Dependencies: 407
-- Name: TABLE userbehaviour; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour TO dhanraj;
GRANT SELECT ON TABLE fact.userbehaviour TO varshil;


--
-- TOC entry 6650 (class 0 OID 0)
-- Dependencies: 432
-- Name: TABLE userbehaviour_exceptions; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.userbehaviour_exceptions TO varshil;


--
-- TOC entry 6652 (class 0 OID 0)
-- Dependencies: 411
-- Name: TABLE usercheckedin; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.usercheckedin TO varshil;


--
-- TOC entry 6653 (class 0 OID 0)
-- Dependencies: 441
-- Name: TABLE vw_offer_analysis; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.vw_offer_analysis TO varshil;


--
-- TOC entry 6654 (class 0 OID 0)
-- Dependencies: 408
-- Name: TABLE watermarktable; Type: ACL; Schema: fact; Owner: citus
--

GRANT SELECT ON TABLE fact.watermarktable TO dhanraj;
GRANT SELECT ON TABLE fact.watermarktable TO varshil;


--
-- TOC entry 6655 (class 0 OID 0)
-- Dependencies: 470
-- Name: TABLE modifier_interactions; Type: ACL; Schema: ml; Owner: citus
--

GRANT SELECT ON TABLE ml.modifier_interactions TO varshil;


--
-- TOC entry 6656 (class 0 OID 0)
-- Dependencies: 414
-- Name: TABLE report; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.report TO varshil;


--
-- TOC entry 6657 (class 0 OID 0)
-- Dependencies: 415
-- Name: TABLE reportschedule; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.reportschedule TO varshil;


--
-- TOC entry 6658 (class 0 OID 0)
-- Dependencies: 387
-- Name: TABLE schemaversions; Type: ACL; Schema: public; Owner: citus
--

GRANT SELECT ON TABLE public.schemaversions TO varshil;


-- Completed on 2026-06-04 21:54:30

--
-- PostgreSQL database dump complete
--

\unrestrict AXlqme4dxmiMlkAeDcnh0WNCW66eUfOYgMdflMydquEh77M8eDTpXyhjkORon8N

