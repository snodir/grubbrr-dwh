select ti.*
from fact.transactionitem as ti 
inner join fact.transactionheader as th 
on th.ordersessionid = ti.ordersessionid
order by th.dateid desc
LIMIT 10;

select count(*) --20,428 --26,295
from fact.transactionitem --*******dev

select * from fact.ordertiming order by id desc


select count(*) --11,527 --11,533
from fact.transactionitem --*******stage

select ot.locationid, ot.kioskid, ot.ordertypeid,
count(1) 
from dim.ordertype as ot
group by ot.locationid, ot.kioskid, ot.ordertypeid
having count(1)>1

select * 
from dim.ordertype
where 1=1
--and locationid= 'loc-40cd7f8f-5a54-4862-92ee-3e57d4ccdc52'
and kioskid= 'ksk-39874317'
--and ordertypeid= 'pickup'
order by id desc
--(loc-40cd7f8f-5a54-4862-92ee-3e57d4ccdc52, ksk-39874317, pickup)
--(loc-40cd7f8f-5a54-4862-92ee-3e57d4ccdc52, ksk-39874317, pickup)
select distinct ordertypeid from dim.ordertype

select * 
from dim.ordertype
order by id desc

select transactionheaderid, itemid, itemname, count(1)
from fact.transactionitem
group by transactionheaderid, itemid, itemname
having count(1)>1;

select transactionheaderid, itemid, count(1)
from fact.transactionitem
group by transactionheaderid, itemid
having count(1)>1;

select transactionheaderid, count(1)
from fact.transactionitem
group by transactionheaderid
having count(1)>1;

select *
from dim.ordertype

select * from information_schema.columns 
where 1=1
and column_name like '%order%type%'
and table_name like '%%'
and table_schema like '%%' 

select * from fact.pipelinerunstatus
/*insert into fact.pipelinerunstatus(pipelinename)
values('CopyGOUStageViewTOGASStageDim')*/

/*
SELECT distinct 
  c.kioskSource.kioskId as kioskid,
  c.locationId as locationid,
  c.orderType as ordertypeid,
  max(substring(c.orderId, 4, length(c.orderId))) as maxorderid
FROM orders as c
WHERE 1=1
and c.kioskSource.kioskId > ''
AND c.orderType > ''
AND c.locationId NOT IN ('loc-lr3h36utnl','loc-tezvlbqtrz')
group by 
  c.kioskSource.kioskId,
  c.locationId,
  c.orderType*/