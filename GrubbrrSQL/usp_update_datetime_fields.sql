CREATE or REPLACE PROCEDURE fact.usp_update_datetime_fields()
LANGUAGE SQL 
begin atomic

update fact.transactionheader
set orderdatelocal = orderdateutc::TIMESTAMPTZ AT TIME ZONE l.timezone
from (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end as timezone from dim.location) as l
where l.locationid = transactionheader.locationid 
and transactionheader.orderdatelocal is null;

update fact.transactionheader
set orderdatelocal = orderdateutc::TIMESTAMPTZ AT TIME ZONE 'America/New_York'
where orderdatelocal is null;

update fact.transactionheader
set dateid = cast(to_char(orderdatelocal, 'YYYYMMDDHH24') as integer)
where dateid is null;

update fact.transactionheader
set businessdate = cast(orderdatelocal as date)
where businessdate is null;

update fact.transactionheader
set ABTestID = ABTests.ABTestID
from dim.ABTests
where ABTests.OrderSessionID = transactionheader.ordersessionid
and transactionheader.ABTestID is null;

end;

call fact.usp_update_datetime_fields();
select 1 as rn;