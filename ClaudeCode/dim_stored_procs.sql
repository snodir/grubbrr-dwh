-- ============================================================
-- Stored Procedures: dim schema
-- Extracted from gas_db_merged_20260530.sql
-- Generated: 2026-05-30
-- ============================================================

--

--
-- TOC entry 846 (class 1255 OID 735591)
-- Name: usp_grubbrr_install_base(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_grubbrr_install_base()
    LANGUAGE plpgsql
    AS $BODY$

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
$BODY$;


ALTER PROCEDURE dim.usp_grubbrr_install_base() OWNER TO citus;

--
-- TOC entry 957 (class 1255 OID 3327439)
-- Name: usp_grubbrr_install_base_all_devices(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_grubbrr_install_base_all_devices()
    LANGUAGE plpgsql
    AS $BODY$

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
$BODY$;


ALTER PROCEDURE dim.usp_grubbrr_install_base_all_devices() OWNER TO citus;

--
-- TOC entry 709 (class 1255 OID 2041188)
-- Name: usp_master_keys_for_duplicate_items(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_master_keys_for_duplicate_items()
    LANGUAGE plpgsql
    AS $BODY$

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
$BODY$;


ALTER PROCEDURE dim.usp_master_keys_for_duplicate_items() OWNER TO citus;

--
-- TOC entry 662 (class 1255 OID 3589004)
-- Name: usp_refresh_catalog(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_catalog()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_catalog() OWNER TO citus;

--
-- TOC entry 659 (class 1255 OID 3586056)
-- Name: usp_refresh_category_hierarchy(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_category_hierarchy()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_category_hierarchy() OWNER TO citus;

--
-- TOC entry 1361 (class 1255 OID 3631114)
-- Name: usp_refresh_dim_location_kiosk_details(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_dim_location_kiosk_details()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_dim_location_kiosk_details() OWNER TO citus;

--
-- TOC entry 1248 (class 1255 OID 3601714)
-- Name: usp_refresh_element(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_element()
    LANGUAGE plpgsql
    AS $BODY$
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
        nextval('dim.element_id_seq'),
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_element() OWNER TO citus;

--
-- TOC entry 934 (class 1255 OID 3586035)
-- Name: usp_refresh_frequentcustomer(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_frequentcustomer()
    LANGUAGE plpgsql
    AS $BODY$
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
    ORDER BY frequentcustomerid, sysinserttime DESC NULLS LAST;

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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_frequentcustomer() OWNER TO citus;

--
-- TOC entry 1231 (class 1255 OID 3587573)
-- Name: usp_refresh_itemcategory(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_itemcategory()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_itemcategory() OWNER TO citus;

--
-- TOC entry 530 (class 1255 OID 3594941)
-- Name: usp_refresh_kiosk(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_kiosk()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_kiosk() OWNER TO citus;

--
-- TOC entry 887 (class 1255 OID 3644492)
-- Name: usp_refresh_location_kiosk_details(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_location_kiosk_details()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_location_kiosk_details() OWNER TO citus;

--
-- TOC entry 672 (class 1255 OID 3586043)
-- Name: usp_refresh_menuitem(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_menuitem()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_menuitem() OWNER TO citus;

--
-- TOC entry 888 (class 1255 OID 3586069)
-- Name: usp_refresh_modifier(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_modifier()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_modifier() OWNER TO citus;

--
-- TOC entry 535 (class 1255 OID 3586077)
-- Name: usp_refresh_modifiergroup(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_modifiergroup()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_modifiergroup() OWNER TO citus;

--
-- TOC entry 1197 (class 1255 OID 3587402)
-- Name: usp_refresh_modifiergroup_modifier_mapping(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_modifiergroup_modifier_mapping()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_modifiergroup_modifier_mapping() OWNER TO citus;

--
-- TOC entry 1262 (class 1255 OID 3608696)
-- Name: usp_refresh_occasionsurvey(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_occasionsurvey()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_occasionsurvey() OWNER TO citus;

--
-- TOC entry 1356 (class 1255 OID 3598986)
-- Name: usp_refresh_ordertype(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_ordertype()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_ordertype() OWNER TO citus;

--
-- TOC entry 780 (class 1255 OID 3644494)
-- Name: usp_refresh_organization(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_organization()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_organization() OWNER TO citus;

--
-- TOC entry 1507 (class 1255 OID 3605488)
-- Name: usp_refresh_organizationlocation(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_organizationlocation()
LANGUAGE plpgsql
AS $BODY$
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
$BODY$;

ALTER PROCEDURE dim.usp_refresh_organizationlocation() OWNER TO citus;

--
-- TOC entry 708 (class 1255 OID 3601734)
-- Name: usp_refresh_view(); Type: PROCEDURE; Schema: dim; Owner: citus
--

CREATE OR REPLACE PROCEDURE dim.usp_refresh_view()
    LANGUAGE plpgsql
    AS $BODY$
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
$BODY$;


ALTER PROCEDURE dim.usp_refresh_view() OWNER TO citus;