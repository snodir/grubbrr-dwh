--DROP TABLE if EXISTS dim.kioskdetails;
CREATE TABLE if not EXISTS dim.kioskdetails (
    id text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    kiosks text COLLATE pg_catalog."default",
    devicetype text COLLATE pg_catalog."default",
    syncversion text COLLATE pg_catalog."default",
    syscosmosts BIGINT,
    sysinserttime TIMESTAMP
)
TABLESPACE pg_default;

ALTER TABLE dim.kioskdetails
OWNER to citus;

select kiosks :: jsonb, * 
from dim.kioskdetails
where locationid = 'loc-b1c8b0ad-18f1-4475-9e69-3c5d12e0a90f'
ORDER BY syscosmosts DESC
LIMIT 100;

SELECT * from dim.kioskdetails

SELECT * from dim.vw_grubbrrinstallbase

CREATE OR REPLACE VIEW dim.vw_grubbrrinstallbase
AS
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
       dd.kiosk_hardware_id,
       dd.kiosk_software_version,
       dd.os_type,
       dd.serial_number,
       dd.last_login_time,
       dd.is_test_mode,
       dd.is_demo_kiosk,
       dd.is_test_mode_on,
       dd.last_sync_time,
       k.istestkiosk as is_test_kiosk,
       k.devicetype as device_type,
       dd.is_activated,
       dd.payment_integration_configs,
       dd.printer_configs,
       dd.kiosk_activation,
       dd.kiosk_mode,
       dd.kiosk_logging,
       dd.is_goast_kiosk,
       dd.loyalty_login_otp,
       '' as pos_provider,
       '' as payment_provider,
       '' as payment_device_type,
       '' as loyalty_provider,
       '' as scanner_type,
       k.devicecreatedon as device_created_on,
       k.devicedeletedon as device_deleted_on
from device_details as dd
inner join dim.kiosk as k 
        on dd.location_id = k.locationid and dd.kiosk_id = k.kioskid
inner join (select * from dim.organizationlocation where organizationtype = 0) ol 
        on dd.location_id = ol.locationid

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