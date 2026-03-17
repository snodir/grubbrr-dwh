select coalesce(businessdate, cast(orderdateutc as date)) as businessdate, *
from fact.transactionheader 
where 1=1
--and businessdate is not null
--and transactionheaderid in ('ordevt-lf95msnyg1','ordevt-ovj6jaob3d','ordevt-p181j1rufb','ordevt-lmjks7ug69')
--and orderid = 'ord-AAACEMPZ9QAC'--AAACEMPZ9QAC
order by orderdateutc desc
limit 10

--alter table fact.transactionheader 
--add businessdate date
select count(*), count(businessdate) FROM fact.transactionheader --38,132	3,311
select count(*), count(businessdate) 
FROM fact.transactionheader --38132	3311
where transactionheaderid like 'abort%'

update fact.transactionheader
set businessdate = coalesce(cast(orderdatelocal as date), cast(orderdateutc as date))
where businessdate is null --'ord-AAACEMPZ9QAC'