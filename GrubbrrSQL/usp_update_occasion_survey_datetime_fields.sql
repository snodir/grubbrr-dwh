--CALL fact.usp_update_occasion_survey_datetime_fields();
--SELECT *, to_timestamp(ts) FROM fact.watermarktable as wt;


CREATE OR REPLACE PROCEDURE fact.usp_update_occasion_survey_datetime_fields()
LANGUAGE plpgsql
AS $BODY$

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
$BODY$;

ALTER PROCEDURE fact.usp_update_occasion_survey_datetime_fields()
OWNER TO citus;