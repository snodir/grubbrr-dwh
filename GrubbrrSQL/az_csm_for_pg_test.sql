select count(*) from fact.transactionitem; --13,770
select count(*) from fact.transactionheader; --12,218
select count(*) from fact.itemmodifier; --3,710
select count(*) from fact.ordertiming; --0
select count(*) from fact.userbehaviour; --36,488
select count(*) from fact.devicetelemetry; --860,694
select count(*) from fact.deviceevent; --300,922
select count(*) from fact.devicestate; --327,592
select count(*) from fact.watermarktable; --3
select count(*) from dim.element; --7,462
select count(*) from dim.company; --523
select count(*) from dim.kiosk; --2,526
select count(*) from dim.location; --1,420
select count(*) from dim.ordertype; --841
select count(*) from dim.itemcategory; --1,002
select count(*) from dim.menuitem; --3,615
select count(*) from dim.organizationlocation; --4,823
select count(*) from dim.datedim; --26,304
select * from fact.pipelinerunstatus;

select * --327,566
from fact.devicestate 
order by dateid desc
LIMIT 100;

select *--
from fact.transactionitem 
where categoryid like 'cat%'
--order by dateid desc
LIMIT 100;

select distinct upselllevel from fact.transactionitem --'Item', '', 'Order', NULL
select distinct categoryid from fact.transactionitem --numeric values
select distinct /*id,*/ categoryid, categoryname from dim.itemcategory order by categoryid --778/798 rows
select distinct id/*, categoryid*/ from dim.itemcategory order by id --1104 rows
select distinct locationid from dim.itemcategory order by locationid --332 rows

select ol.locationname, 
count(ic.categoryid) as cat_count,
sum(th.ordertotal) as sum_total,
sum(th.ordertax) as sum_tax,
sum(th.ordertip) as sum_tip
from fact.transactionheader as th
inner join (select distinct locationid, locationname from dim.organizationlocation) as ol 
on ol.locationid = th.locationid
inner join fact.transactionitem as ti 
on ti.transactionheaderid = th.transactionheaderid
inner join dim.itemcategory as ic 
on ic.id = ti.categoryid
GROUP by ol.locationname

select * from fact.transactionheader
where locationid = 'loc-e058e270-4475-405c-b0af-074817ee1372'

select * 
from fact.transactionitem
where categoryid is null

select * from dim.itemcategory order by locationid limit 10
--select case when 'Me'='me' then 'ci' else 'cs' end
select *--count(distinct locationid), count(*) 
from dim.organizationlocation --1520/5265
--group by locationid
order by locationid limit 1000

select distinct organizationname, locationid, locationname
from dim.organizationlocation --1520/5265
order by locationid limit 1000;

select * from dim.itemcategory order by locationid limit 10
select count(distinct locationid), count(*) from dim.location order by locationid limit 10

select *, count(*) over(partition by locationid) as dupl
from dim.itemcategory 
order by dupl desc, id

select *, 
(select count(*) from dim.itemcategory as c where c.locationid = ic.locationid) as dupl
from dim.itemcategory as ic
order by dupl desc, id

select categoryid, 
count(*) as dupl
from dim.itemcategory
group by categoryid 
having count(*) = 1 --93(>1) 683(=1)

select categoryname, count(distinct locationid) 
from dim.itemcategory group by categoryname

select locationid, 
count(*) as dupl
from dim.itemcategory
group by locationid 
having count(*) > 1 --198(>1) 134(=1)
order by dupl desc

select *
from fact.watermarktable
--insert into fact.watermarktable(watermarktablename,watermarkcolumn)
--values('devicetelemetry', 'telemetrytime'),
--      ('devicestate','lasteventtime'),
--      ('userbehaviour',	'busdate')

select count(*)
from fact.userbehaviour
order by busdate desc --36,488

select * from dim.element
select * from dim.ordertype

select * 
from dim.datedim 
order by dateid desc

SELECT * FROM pg_stat_activity;
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND pid <> pg_backend_pid();

