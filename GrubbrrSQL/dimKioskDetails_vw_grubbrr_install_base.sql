--DROP TABLE if EXISTS dim.kioskdetails;
CREATE TABLE if not EXISTS dim.kioskdetails (
    id text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    kiosks text COLLATE pg_catalog."default",
    devicetype text COLLATE pg_catalog."default",
    syncversion text COLLATE pg_catalog."default",
    syscosmosts BIGINT,
    sysinserttime TIMESTAMP,
    pos_provider text COLLATE pg_catalog."default",
    loyalty_provider text COLLATE pg_catalog."default",
    payment_provider text COLLATE pg_catalog."default"
)
TABLESPACE pg_default;

ALTER TABLE dim.kioskdetails
OWNER to citus;

ALTER TABLE dim.kioskdetails
--add CONSTRAINT locationid_pkey PRIMARY KEY (locationid);
--add pos_provider text,
--add loyalty_provider text,
--add payment_provider text
add scanners text


SELECT * 
from dim.organization
where 1=1
and isdeleted = False
and active = True
and organizationtype = 0
ORDER by createdon desc;

SELECT kd.locationid, count(*)
from dim.kioskdetails as kd 
group by kd.locationid
having count(*) > 1

select *, count(*) over(partition by organizationid) as count_by_org
from dim.organizationlocation 
where 1=1
--and organizationid = 'org-42a2fc0d-1696-4fd9-8c9e-dc5504f903c2'
--and locationid = 'loc-2d672932-a1b7-4ff0-a848-d65c0c18c417'
--and organizationtype = 1
order by count_by_org desc, locationid;

SELECT * 
from dim.kioskdetails
WHERE 1=1 
--and locationid = 'loc-8ead49a8-798b-4786-988a-90bbbb4775c7'
and lower(kiosks) like '%scanner%'

SELECT * 
from dim.organization--details
WHERE 1=1 
and id in ('loc-aarouctkh1','loc-zuv585x39o','loc-405e624e-dd80-4f2b-80ee-35d7672e7c49')

--and locationid = 

SELECT * FROM dim.ABTests

SELECT * 
from dim.vw_grubbrrinstallbase
WHERE 1=1 
--and kiosk_mode = 'Live'
--and kiosk_mode = 'Live'
and location_Id = 'loc-8ead49a8-798b-4786-988a-90bbbb4775c7'
and location_name like 'NCR'
--AND kiosk_id = 'ksk-08781362'

/***Columns to be added to the vw_grubbrrinstallbase
1. Status (0-draft, 1-onboarding, 2-live, 3-cancelled)
2. Go-Live date
3. CEP - Complex Event Processing
3. ECM and non-ECM
***/

/***Columns to be added to the dim.organization
1. roundupforcharity
2. is_ecm_enabled
3. is_cep_enabled
4. is_concessionaire_enabled
5. is_smart_upsells_enabled
6. is_feedback_survey_enabled
7. is_digital_menu_board_enabled
8. is_digital_menu_default_format_enabled
***/

SELECT count(*)
from dim.organization as o --3816


ALTER TABLE dim.organization
add roundupforcharity BOOLEAN,
add is_ecm_enabled BOOLEAN,
add is_cep_enabled BOOLEAN,
add is_concessionaire_enabled BOOLEAN,
add is_smart_upsells_enabled BOOLEAN,
add is_feedback_survey_enabled BOOLEAN,
add is_digital_menu_board_enabled BOOLEAN,
add is_digital_menu_default_format_enabled BOOLEAN

SELECT * from dim.LOCATION

SELECT *
from dim.kiosk
where kioskid not like 'ksk-%' --in ('ksk-00026381') --('ksk-21215512','ksk-25224994')-- 

select kiosks :: jsonb, * 
from dim.kioskdetails
where locationid = 'loc-8ead49a8-798b-4786-988a-90bbbb4775c7'-- 'loc-01064db7-fb4e-488c-b0dc-441486c632db'-- in ('loc-b1c8b0ad-18f1-4475-9e69-3c5d12e0a90f','loc-9dbd4815-f50a-4e4f-ac1d-5fd6d9ec728e')
ORDER BY syscosmosts DESC
LIMIT 100;

--Prod sample data
--ksk-21215512 --> 0GE8HNBR600244V (serial-number)
--ksk-25224994 --> 0GE8HNBR600494Z (serial-number)


SELECT * 
from dim.kioskdetails 
where 1=1 
--and kiosks :: text like '%kioskActivation%'
and locationId = 'loc-86e58b1d-f535-47b2-9f7f-14d8c8d0591a'

SELECT *-- location_id, kiosk_hardware_id, pos_provider, payment_provider, loyalty_provider, *
from dim.vw_grubbrrinstallbase
where 1=1
--and kiosk_id in ('ksk-21215512','ksk-25224994') --  ('ksk-00026381')
--and device_created_on > last_login_time and device_created_on > last_sync_time
--and location_Id = 'loc-05b08272-d5b6-45ae-bd9b-8293ac2ff677'
and is_org_active = True and is_loc_active = True
and organization_status in ('Live')--, 'Onboarding')
order by device_created_on desc

select * from dim.organizationlocation where organizationtype = 0 and locationid = 'loc-01064db7-fb4e-488c-b0dc-441486c632db'
select * from dim.organization where /*organizationtype = 0 and*/ id = 'loc-01064db7-fb4e-488c-b0dc-441486c632db'
select * from dim.organization where organizationtype <> 0 and id = 'loc-01064db7-fb4e-488c-b0dc-441486c632db'*/


CREATE OR REPLACE VIEW dim.vw_grubbrrinstallbase
AS
WITH device_details as (
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
    kd.payment_provider :: jsonb as payment_provider
from dim.kioskdetails as kd
cross join LATERAL jsonb_each(kd.kiosks :: jsonb) AS kiosk_entry(kiosk_key, kiosk_data)
)
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
       '' as scanner_type,
       case org.status when 0 then 'Draft' when 1 then 'Onboarding' when 2 then 'Live' when 3 then 'Cancelled' end as organization_status,
       case loc.status when 0 then 'Draft' when 1 then 'Onboarding' when 2 then 'Live' when 3 then 'Cancelled' end as location_status,
       org.active as is_org_active,
       loc.active as is_loc_active,
       org.isdeleted as is_org_deleted,
       loc.isdeleted as is_loc_deleted,
       case when org.status = 2 then org.modifiedon end as org_go_live_date,
       case when loc.status = 2 then loc.modifiedon end as loc_go_live_date,
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
       loc.is_digital_menu_default_format_enabled as is_loc_digital_menu_default_format_enabled
from device_details as dd
inner join dim.kiosk as k 
        on dd.location_id = k.locationid and dd.kiosk_id = k.kioskid 
inner join (select * from dim.organizationlocation where organizationtype = 0) ol 
        on dd.location_id = ol.locationid --and dd.location_id = 'loc-01064db7-fb4e-488c-b0dc-441486c632db'
inner join dim.organization as org
        on ol.organizationid = org.id
inner join dim.organization as loc
        on ol.locationid = loc.id;

INSERT INTO dim.grubbrrinstallbase
SELECT * FROM dim.vw_grubbrrinstallbase


CREATE TABLE dim.grubbrrinstallbase
(
organization_id character varying(50) COLLATE pg_catalog."default" NOT NULL,
organization_name text COLLATE pg_catalog."default" NOT NULL,
location_id character varying(50) COLLATE pg_catalog."default" NOT NULL,
location_name text COLLATE pg_catalog."default" NOT NULL,
kiosk_id character varying(50) COLLATE pg_catalog."default",
kiosk_name text COLLATE pg_catalog."default",
kiosk_hardware_id character varying(50) COLLATE pg_catalog."default",
kiosk_software_version character varying(50) COLLATE pg_catalog."default",
os_type character varying(50) COLLATE pg_catalog."default",
serial_number character varying(50) COLLATE pg_catalog."default",
is_test_mode BOOLEAN,
is_demo_kiosk BOOLEAN,
is_test_mode_on BOOLEAN,
last_login_time TIMESTAMP,
last_sync_time TIMESTAMP,
device_created_on TIMESTAMP,
device_deleted_on TIMESTAMP,
is_test_kiosk boolean,
device_type character varying(50) COLLATE pg_catalog."default",
is_activated BOOLEAN,
payment_integration_configs jsonb,
printer_configs jsonb,
kiosk_activation character varying(50) COLLATE pg_catalog."default",
is_kiosk_deleted BOOLEAN,
kiosk_mode character varying(10) COLLATE pg_catalog."default",
kiosk_logging INTEGER,
is_goast_kiosk BOOLEAN,
loyalty_login_otp character varying(50) COLLATE pg_catalog."default",
pos_provider jsonb,
payment_provider jsonb,
payment_device_type character varying(50) COLLATE pg_catalog."default",
loyalty_provider jsonb,
scanner_type character varying(50) COLLATE pg_catalog."default",
organization_status character varying(20) COLLATE pg_catalog."default",
location_status character varying(20) COLLATE pg_catalog."default",
is_org_active boolean,
is_loc_active boolean,
is_org_deleted boolean,
is_loc_deleted boolean,
org_go_live_date TIMESTAMP,
loc_go_live_date TIMESTAMP,
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
is_loc_digital_menu_default_format_enabled boolean
)
TABLESPACE pg_default;

ALTER TABLE dim.grubbrrinstallbase
OWNER to citus;

/***Columns to be added to the vw_grubbrrinstallbase
1. Status (0-draft, 1-onboarding, 2-live, 3-cancelled)
2. Go-Live date
3. CEP - Complex Event Processing
3. ECM and non-ECM
***/

/***Columns to be added to the dim.organization
1. roundupforcharity
2. is_ecm_enabled
3. is_cep_enabled
4. is_concessionaire_enabled
5. is_smart_upsells_enabled
6. is_feedback_survey_enabled
7. is_digital_menu_board_enabled
8. is_digital_menu_default_format_enabled
***/

SELECT * from dim.kiosk;

SELECT *--count(*)
from dim.organization as o --3816


ALTER TABLE dim.organization
add roundupforcharity BOOLEAN,
add is_ecm_enabled BOOLEAN,
add is_cep_enabled BOOLEAN,
add is_concessionaire_enabled BOOLEAN,
add is_smart_upsells_enabled BOOLEAN,
add is_feedback_survey_enabled BOOLEAN,
add is_digital_menu_board_enabled BOOLEAN,
add is_digital_menu_default_format_enabled BOOLEAN

SELECT distinct 
       ol.organizationid as organization_id,
       ol.organizationname as organization_name,
       ol.locationid as location_id,
       ol.locationname as location_name,
       k.kioskid as kiosk_id,
       k.kioskname as kiosk_name,
       '' as os_type,
       '' as hardware_type,
       '' as pos_provider,
       '' as payment_provider,
       '' as payment_device_type,
       '' as loyalty_provider,
       '' as printer_type,
       '' as scanner_type,
       k.appversion as kiosk_software_version,
       k.serialnumber as serial_number,
       k.istestkiosk as is_test_kiosk,
       k.devicetype as device_type,
       k.devicecreatedon as device_created_on,
       k.devicedeletedon as device_deleted_on
from dim.kiosk as k
inner join (select * from dim.organizationlocation where organizationtype = 0) ol 
        on k.locationid = ol.locationid 
limit 100

select * from dim.vw_grubbrrinstallbase

SELECT * from stg.kioskdetails 
WHERE locationid = 'loc-b1c8b0ad-18f1-4475-9e69-3c5d12e0a90f'
LIMIT 1000
SELECT * from dim.device LIMIT 1000
SELECT * from dim.kiosk ORDER BY devicecreatedon desc LIMIT 1000
SELECT * from dim.peripheral LIMIT 1000

WITH device_details as (
SELECT 
    kiosk_entry.kiosk_key AS kiosk_id,
    (kiosk_entry.kiosk_data ->> 'name') as kiosk_name,
    (kiosk_entry.kiosk_data ->> 'kioskHardwareId') as kiosk_hardware_id,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'appVersion') as kiosk_software_version,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'deviceType') as os_type,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'serialNumber') as serial_number,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'lastLoginTime') :: TIMESTAMP as last_login_time,
    (kiosk_entry.kiosk_data -> 'deviceDetails' ->> 'testMode') :: BOOLEAN as is_test_mode,
    (kiosk_entry.kiosk_data -> 'printerConfigurations') :: jsonb as printer,
    (kiosk_entry.kiosk_data ->> 'lastSync') :: TIMESTAMP as last_sync_time,
    (kiosk_entry.kiosk_data ->> 'isDemoDevice') :: BOOLEAN as is_demo_kiosk,
    (kiosk_entry.kiosk_data ->> 'isTestModeOn') :: BOOLEAN as is_test_mode_on,
    (kiosk_entry.kiosk_data ->> 'locationId') as location_id,
    (kiosk_entry.kiosk_data ->> 'companyId') as organization_id,
    (kiosk_entry.kiosk_data ->> 'activated') :: BOOLEAN as is_activated,
    (kiosk_entry.kiosk_data -> 'paymentIntegrationConfigs') :: jsonb as payment_integration_configs,
    (kiosk_entry.kiosk_data -> 'printerConfigurations') :: jsonb as printer_configs,
    (kiosk_entry.kiosk_data ->> 'kioskActivation') :: INTEGER as kiosk_activation,
    (kiosk_entry.kiosk_data ->> 'kioskMode') :: INTEGER as kiosk_mode,
    (kiosk_entry.kiosk_data ->> 'kioskLogging') :: INTEGER as kiosk_logging,
    (kiosk_entry.kiosk_data ->> 'isGoastKisok') :: BOOLEAN as is_goast_kiosk,
    (kiosk_entry.kiosk_data ->> 'kioskLogging') as loyalty_login_otp
    /*dev.playCardHardwareSettings ->> 'lightsComPort' AS lightsComPort,
    dev.playCardHardwareSettings ->> 'cardDispenserComPort' AS cardDispenserComPort,
    dev.playCardHardwareSettings ->> 'cardDispenserBaudRate' AS cardDispenserBaudRate*/

FROM stg.kioskdetails as kd
cross join LATERAL jsonb_each(kd.kiosks :: jsonb) AS kiosk_entry(kiosk_key, kiosk_data)
)
select dd.*, k.*
from device_details as dd
left join dim.kiosk as k 
       ON dd.location_id = k.locationid
      and dd.kiosk_id = k.kioskid
WHERE k.kioskid is not null
LIMIT 100;

select * from dim.kiosk 

SELECT k.locationid, k.kioskid, count(1)
from dim.kiosk as k
GROUP BY k.locationid, k.kioskid
HAVING count(1) > 1