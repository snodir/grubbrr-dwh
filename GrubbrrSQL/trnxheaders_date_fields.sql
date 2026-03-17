/*update fact.transactionheader
set orderdatelocal = 
case when og.timezone like '%Chicago%' then cast(orderdateutc as timestamp) - INTERVAL '360 minutes'
     when og.timezone like '%New_York%' then cast(orderdateutc as timestamp) - INTERVAL '300 minutes'
     when og.timezone like '%Denver%' then cast(orderdateutc as timestamp) - INTERVAL '420 minutes'
     when og.timezone like '%Los_Angeles%' then cast(orderdateutc as timestamp) - INTERVAL '480 minutes'
     when og.timezone like '%Phoenix%' then cast(orderdateutc as timestamp) - INTERVAL '420 minutes'
     when og.timezone is null then cast(orderdateutc as timestamp) - INTERVAL '300 minutes' end
from (select distinct id, timezone from dim.organizationgeography where organizationtype = 5) as og
where og.id = transactionheader.locationid 
and transactionheader.orderdatelocal is null;*/

update fact.transactionheader
set orderdatelocal = 
orderdateutc::TIMESTAMPTZ AT TIME ZONE COALESCE(og.timezone,'America/New_York')
from (select distinct id, timezone from dim.organizationgeography where organizationtype = 5) as og
where og.id = transactionheader.locationid 
and transactionheader.orderdatelocal is null;

update fact.transactionheader
set businessdate = cast(orderdatelocal as date)
where businessdate is null;