select * 
from dim.kiosk as k 
where 1=1
--and k.devicecreatedon is not null
order by k.id desc



select * from fact.transactionheader
where businessdate is null;

select */*tp.transactionheaderid,--count(*)
       tp.pyamount,
       tp.paymentintegrationid,
       tp.paymentintegrationlabel,
       tp.paymentmethod,
       tp.orderdateutc,
       tp.locationid*/
from fact.transactionpayment as tp
where tp.orderdateutc is not null
order by orderdateutc desc
limit 1000

--paymentType             || refundType       || refundAmount
--'payment by customer'   || 'Full'/'Partial' || -10.00 usd


alter table fact.transactionpayment
add sysinserttime TIMESTAMP

select * --count(*)
from fact.transactionheader as th 
where 1=1
--and th.locationid = 'loc-1a433c3e-36c7-42cd-895f-50185a2356da'
and th.orderstatus = 'order-placed'--11,681/61,408
and (th.reviewordertime is not null and th.orderstarttime is not null and th.checkouttime is not null and th.paystarttime is not null and th.sessionendtime is not null)
/*and (th.reviewordertime is null
  or th.orderstarttime is null
  or th.checkouttime is null
  or th.paystarttime is null
  or th.sessionendtime is null)--9,392/11,101*/
order by th.orderdateutc desc
limit 100


select *
from fact.userbehaviour
order by createddate desc
limit 1000

update fact.transactionpayment
set locationid = th.locationid,
    kioskid = th.kioskid,
    orderdateutc = th.orderdateutc
from fact.transactionheader as th
where transactionpayment.transactionheaderid = th.transactionheaderid


select '2025-06-04T09:17:04' :: TIMESTAMP,
       '2025-06-04 09:17:04000:' :: TIMESTAMP

/*update fact.transactionheader
set orderdateutc = substring(orderdateutc, 1, 19)
where orderdateutc = '2025-06-04 09:17:04000:'*/

update fact.transactionheader
set businessdate = cast(orderdatelocal as date)
where businessdate is null;


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