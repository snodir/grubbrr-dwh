CREATE TABLE if not EXISTS fact.transactionrefunds (
transactionheaderid character varying(50) COLLATE pg_catalog."default" NOT NULL,
orderid character varying(50) COLLATE pg_catalog."default",
locationid character varying(50) COLLATE pg_catalog."default",
refundtransactionid character varying(50) COLLATE pg_catalog."default",
paymentid character varying(50) COLLATE pg_catalog."default",
refundamount numeric(7,3),
refundtype character varying(50) COLLATE pg_catalog."default",
orderdateutc text COLLATE pg_catalog."default",
sysinserttime TIMESTAMP
);

ALTER TABLE fact.transactionrefunds
OWNER to citus;

alter TABLE fact.transactionrefunds
--add CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);
add syscosmosts BIGINT

WITH refunds as (
select *, row_number() over(partition by locationid, orderid order by orderdateutc desc) as rn
from fact.transactionrefunds
--where coalesce(syscosmosts, 1500000010) > @{activity('Lookup MaxFields').output.firstRow.maxts}
)
UPDATE fact.transactionheader 
SET paymentstatus = case lower(r.refundtype) when 'fullrefund' then 'Fully refunded' else 'Partially refunded' end
FROM refunds as r
WHERE transactionheader.locationid = r.locationid
  AND transactionheader.orderid = r.orderid
  AND r.rn = 1;

UPDATE fact.watermarktable
SET ts = tr.maxts
FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.transactionrefunds' as tablename FROM fact.transactionrefunds) as tr 
WHERE watermarktable.watermarktablename = tr.tablename;

SELECT 1 as rn;


select * 
from fact.transactionrefunds 
where (refundtransactionid is null OR refundtransactionid = '')

SELECT *
FROM fact.transactionheader
WHERE paymentstatus like '%refund%'
order by orderdatelocal desc;

SELECT tr.*
from fact.transactionrefunds as tr 
where 1=1 
--and tr.orderid = 'ord-6323ee06-12aa-4d84-aa4e-fd2ce5b48105'
order by tr.orderdateutc desc;


update fact.transactionpayment
set locationid = th.locationid,
    kioskid = th.kioskid,
    orderdateutc = th.orderdateutc
from fact.transactionheader as th
where transactionpayment.transactionheaderid = th.transactionheaderid


SELECT th.paymentstatus, tr.*
from fact.transactionrefunds as tr 
inner join fact.transactionheader as th 
        on tr.orderid = th.orderid 
       and tr.locationid = th.locationid 
where 1=1 
--and tr.orderid = 'ord-6323ee06-12aa-4d84-aa4e-fd2ce5b48105'
order by tr.orderdateutc desc;

SELECT tr.*
from fact.transactionrefunds as tr 
where 1=1 
--and tr.orderid = 'ord-6323ee06-12aa-4d84-aa4e-fd2ce5b48105'
order by tr.orderdateutc desc;




SELECT * from fact.transactionheader as th 
where 1=1 
and th.orderid = 'ord-6323ee06-12aa-4d84-aa4e-fd2ce5b48105'

select * 
from fact.transactionpayment as tp
where 1=1
--and tp.transactionheaderid = 'ordevt-8kxax3gl7a'
--and not EXISTS (SELECT 1 from fact.transactionheader as th where th.transactionheaderid = tp.transactionheaderid) 
order by orderdateutc desc
limit 10


select * 
from fact.transactionrefunds as tr
where tr.transactionheaderid = 'ordevt-8kxax3gl7a'
order by tr.orderdateutc desc
limit 10

select * 
from fact.transactionrefunds as tr
where 1=1
and exists (select 1 from fact.transactionheader as th where th.orderid = tr.orderid)
--and not exists (select 1 from fact.transactionpayment as tp where tp.transactionheaderid = tr.transactionheaderid)
order by tr.orderdateutc desc