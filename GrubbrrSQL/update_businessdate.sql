select *--, substring(th.transactionheaderid, 7, length(th.transactionheaderid)) :: BIGINT as abortedorderid
from fact.transactionheader as th
where 1=1
--and th.transactionheaderid like 'abort-%'
and th.orderdiscount > 1
--and th.channel is null
and th.orderstatus = 'order-placed'
--and th.locationid = 'loc-8ead49a8-798b-4786-988a-90bbbb4775c7'-- 'loc-49971226-2278-440e-8fd1-eff402a73881'-- 'loc-9dbd4815-f50a-4e4f-ac1d-5fd6d9ec728e'-- 'loc-273ffa25-f0d2-48e5-befa-47f0934f3baa'
--and th.businessdate = '2025-06-20'
--and th.orderdatelocal is null
--and th.transactionheaderid = 'ordevt-hskr2m9gck'-- 'ordevt-649sdzodt4'
order by th.orderdateutc desc -- th.id desc
limit 200
--RDBMS

update fact.transactionheader
set orderdateutc = 
case when substring(orderdateutc, 20, 1) = '.' 
     then replace(replace(substring(orderdateutc, 1, 23), 'T', ' '), '+', '0')
     else substring(orderdateutc, 1, 19) end;

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

select 1 as rn;