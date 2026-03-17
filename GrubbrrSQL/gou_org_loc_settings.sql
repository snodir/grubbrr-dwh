SELECT o.*,
       case when exists (select 1 from public.organizationsetting as os 
                         where os.organizationid = o.id 
                           and os.settingid = 'ost-E64430FF-9D39-4BB6-9D7E-FC9BAF46B23B' 
                           and os.booleanvalue = True) then True else False end as is_ecm_enabled,
       case when exists (select 1 from public.organizationsetting as os 
                         where os.organizationid = o.id 
                           and os.settingid = 'ost-1625cffe-edf0-4cdf-b6e5-c48e56e2448d' 
                           and os.booleanvalue = True) then True else False end as is_cep_enabled,
       case when exists (select 1 from public.organizationsetting as os 
                         where os.organizationid = o.id 
                           and os.settingid = 'ost-52B64A51-872A-4E2D-BF7A-2AD757B7E874' 
                           and os.booleanvalue = True) then True else False end as is_concessionaire_enabled,
       case when exists (select 1 from public.organizationsetting as os 
                         where os.organizationid = o.id 
                           and os.settingid = 'ost-C9C2213A-2E85-440C-8662-7B5C7C1571EA' 
                           and os.booleanvalue = True) then True else False end as is_smart_upsells_enabled,
       case when exists (select 1 from public.organizationsetting as os 
                         where os.organizationid = o.id 
                           and os.settingid = 'ost-8A3DE810-3321-479D-9347-AFFBFCEC9B06' 
                           and os.booleanvalue = True) then True else False end as is_feedback_survey_enabled,
       case when exists (select 1 from public.organizationsetting as os 
                         where os.organizationid = o.id 
                           and os.settingid = 'ost-0657BAE7-EECF-4825-9FE6-5CCE6D18910D' 
                           and os.booleanvalue = True) then True else False end as is_digital_menu_board_enabled,
       case when exists (select 1 from public.organizationsetting as os 
                         where os.organizationid = o.id 
                           and os.settingid = 'ost-109E8023-CEF5-4FBD-B28D-466758DAA1D4' 
                           and os.booleanvalue = True) then True else False end as is_digital_menu_default_format_enabled
FROM public.organization as o
WHERE 1=1
  AND o.id = 'loc-81128084-8d53-461c-b01b-5bbc51aa088d'
  AND o.active = True 
  AND o.isdeleted = False
  AND o.organizationtype = 0;
LIMIT 1000

SELECT id, count(*)
from public.organization as o --3816
GROUP BY id
HAVING count(*) > 1

SELECT organizationid, locationid, count(*)
FROM public.vw_organizationlocation as o
WHERE 1=1 
--AND o.locationid = 'loc-66d85cfc-62f3-40eb-96c3-39afb144b4e3'
GROUP BY organizationid, locationid
HAVING count(*) > 1



SELECT os.organizationid, os.settingid, 
       CASE settingid WHEN 'ost-1625cffe-edf0-4cdf-b6e5-c48e56e2448d' THEN 'EnableComplexEventProcessingId'
                      WHEN 'ost-E64430FF-9D39-4BB6-9D7E-FC9BAF46B23B' THEN 'EnableEnterpriseConfigurationManagementId'
                      WHEN 'ost-52B64A51-872A-4E2D-BF7A-2AD757B7E874' THEN 'Concessionaire'
                      WHEN 'ost-C9C2213A-2E85-440C-8662-7B5C7C1571EA' THEN 'EnableSmartUpsells'
                      WHEN 'ost-8A3DE810-3321-479D-9347-AFFBFCEC9B06' THEN 'EnableFeedbackSurvey'
                      WHEN 'ost-0657BAE7-EECF-4825-9FE6-5CCE6D18910D' THEN 'EnableDigitalMenuBoard'
                      WHEN 'ost-109E8023-CEF5-4FBD-B28D-466758DAA1D4' THEN 'DigitalMenuBoardDefaultFormat' END as settingName,
       os.booleanvalue
from public.organizationsetting as os 
WHERE 1=1
and os.organizationid = 'loc-81128084-8d53-461c-b01b-5bbc51aa088d'
and os.settingid = 'ost-1625cffe-edf0-4cdf-b6e5-c48e56e2448d' --EnableEnterpriseConfigurationManagementId 
--and os.organizationid = 'loc-c466c37f-8437-4416-9cc7-b3c8bc5b9d00'


/***
EnableComplexEventProcessingId = 'ost-1625cffe-edf0-4cdf-b6e5-c48e56e2448d';
EnableEnterpriseConfigurationManagementId = 'ost-E64430FF-9D39-4BB6-9D7E-FC9BAF46B23B';
Concessionaire - 'ost-52B64A51-872A-4E2D-BF7A-2AD757B7E874';
EnableSmartUpsells = 'ost-C9C2213A-2E85-440C-8662-7B5C7C1571EA';
EnableFeedbackSurvey = 'ost-8A3DE810-3321-479D-9347-AFFBFCEC9B06';
EnableDigitalMenuBoard = 'ost-0657BAE7-EECF-4825-9FE6-5CCE6D18910D';
DigitalMenuBoardDefaultFormat = 'ost-109E8023-CEF5-4FBD-B28D-466758DAA1D4';
***/


SELECT *
FROM public.vw_organizationlocation --organization
WHERE organizationid in ('org-0e65e422-ba41-438b-988e-0a61e250b871',
             'com-s54vepfp4h',
             'loc-4515643c-981b-40e4-bad0-ede54ad71f6a',
             'loc-8s9bh2ikch',
             'loc-9c326d9f-bf74-4e57-a061-77678105e6d7',
             'loc-069a73be-501b-4a56-bdca-402b2c1b5f07',
             'loc-0bdb46ab-b164-493f-a3d7-43d6163532f5',
             'loc-32524e7d-6e5b-458e-8851-ce7f3b1851b8',
             'loc-41a95ce1-763d-42e4-8864-a5ee09aa2b93',
             'loc-7f2dcde9-e7f4-45ec-bddf-082456a8eb9e');

/***Missing Orgs/Locs in Regression GAS
org-0e65e422-ba41-438b-988e-0a61e250b871	loc-4515643c-981b-40e4-bad0-ede54ad71f6a	Five Guys	26, Lý Tự Trọng, Quận 1
org-0e65e422-ba41-438b-988e-0a61e250b871	loc-9c326d9f-bf74-4e57-a061-77678105e6d7	HMS	14 NO, Sikar Road, Sector 8, Vishwakarma Industrial Area, Vidyadhar Nagar, Jaipur, Jaipur Division
com-s54vepfp4h	                          loc-8s9bh2ikch	BFi test location	1081    Holland Drive
org-0e65e422-ba41-438b-988e-0a61e250b871	loc-069a73be-501b-4a56-bdca-402b2c1b5f07	Popeyes	14 NO, Sikar Road, Sector 8, Vishwakarma Industrial Area, Vidyadhar Nagar, Jaipur, Jaipur Division
org-0e65e422-ba41-438b-988e-0a61e250b871	loc-0bdb46ab-b164-493f-a3d7-43d6163532f5	Newks	1425, Old Sunset Trail, Santa Fe County, 6330
org-0e65e422-ba41-438b-988e-0a61e250b871	loc-32524e7d-6e5b-458e-8851-ce7f3b1851b8	Bojangles	12500, Tukwila International Boulevard, King County, 2506
org-0e65e422-ba41-438b-988e-0a61e250b871	loc-41a95ce1-763d-42e4-8864-a5ee09aa2b93	Carls Jr	La racebox, 75, Rue Claire Lacombe, Oise
org-0e65e422-ba41-438b-988e-0a61e250b871	loc-7f2dcde9-e7f4-45ec-bddf-082456a8eb9e	Toast	Rua Vinte e Cinco de Março, Centro Histórico de São Paulo, São Paulo
***/


SELECT o.id, count(*)
from public.organization as o
group by o.id
having count(*) > 1

SELECT os.organizationid, count(*)
from public.organizationsetting as os 
group by os.organizationid
having count(*) > 1

