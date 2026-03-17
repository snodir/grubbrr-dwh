select *
from public.vw_transactiondetails

select * from dim.datedim

select locationid,
       sum(ordertotal) as sum_total,
       sum(ordertip) as sum_tip,
       sum(ordertax) as sum_tax
from fact.transactionheader
where locationid like 'loc-043fd5ab-643a-43df-bde4-ea558d6e036f'
and dateid between 2024100100 and 2024103124
group by locationid
--order by dateid

select th.locationid, 
       --count(ic.categoryid) as cat_count,
       ol.locationname,
       th.ordertotal,
       th.ordertax,
       th.ordertip,
       sum(th.ordertotal) over(partition by th.locationid) as sum_total,
       sum(th.ordertip) over(partition by th.locationid) as sum_tip,
       sum(th.ordertax) over(partition by th.locationid) as sum_tax
from fact.transactionheader as th
left join (select distinct locationid, locationname from dim.organizationlocation) as ol 
on ol.locationid = th.locationid
--left join fact.transactionitem as ti 
--on ti.transactionheaderid = th.transactionheaderid
--left join dim.itemcategory as ic 
--on ic.id = ti.categoryid
where th.locationid like 'loc-043fd5ab-643a-43df-bde4-ea558d6e036f'
and th.dateid between 2024100100 and 2024103124
--GROUP by th.locationid

select *-- distinct locationid, locationname 
from dim.organizationlocation
where organizationname like '%BK%Full%'
order by organizationid, locationid

select * from dim.location;

select distinct * --organizationtype--*/*1,555
       --distinct locationid, locationname --1,555
       --distinct organizationid, organizationname, locationid, locationname --1,555
from dim.organizationlocation
where organizationtype = 5
order by organizationid, locationid

select ol.organizationid,
       ol.organizationname,
       ol.locationid,
       ol.locationname,
       ic.id as ctg_key_null,
       ic.categoryid as categoryid,
       ic.categoryname as categoryname,
       count(ic.id) over(partition by ol.locationid) as ctg_count_null
       --coalesce(ic.id, 0) as ctg_key,
       --coalesce(ic.categoryid, '') as categoryid,
       --coalesce(ic.categoryname, '') as categoryname,
       --count(coalesce(ic.id, 0)) over(partition by ol.locationid) as ctg_count,
       /*th.ordertotal,
       th.ordertax,
       th.ordertip,
       sum(th.ordertotal) over(partition by th.locationid) as sum_total,
       sum(th.ordertip) over(partition by th.locationid) as sum_tip,
       sum(th.ordertax) over(partition by th.locationid) as sum_tax*/
from (select * from dim.organizationlocation where organizationtype = 0) as ol
left join dim.itemcategory as ic 
on ic.locationid = ol.locationid and ic.isactive = True
--left join fact.transactionitem as ti 
--on ti.categoryid = ic.id
--left join fact.transactionheader as th 
--on th.locationid = ol.locationid
order by organizationid, ctg_key_null

select ol.organizationid,
       ol.organizationname,
       ol.locationid,
       ol.locationname,
       ic.id as ctg_key_null,
       ic.categoryid as categoryid,
       ic.categoryname as categoryname,
       count(ic.id) over(partition by ol.locationid) as ctg_count_null
from (select * from dim.organizationlocation where organizationtype = 5) as ol
left join dim.itemcategory as ic 
on ic.locationid = ol.locationid and ic.isactive = True
order by organizationid, ctg_key_null


select count(*), count(DISTINCT locationid) from dim.organizationlocation where organizationtype = 5
select count(*) as cnt, --25,383
       count(distinct orderid) as ordcnt, --21,342
       count(distinct transactionheaderid) as trnx_count --23,343
from fact.transactionitem

select count(*) as cnt, --23,344
       count(distinct orderid) as ord_count, --17,275
       count(distinct transactionheaderid) as trnx_count --23,344
from fact.transactionheader

select * 
from fact.transactionheader as th 
where 1=1
and th.transactionheaderid in ('ordevt-rkyrtrpx6y','ordevt-yik5pt59tt')

select ic.categoryid, ic.categoryname, ic.locationid, 
       ti.* 
from fact.transactionitem as ti
left join dim.itemcategory as ic
on ic.id = ti.categoryid
where 1=1
and ic.isactive = True
--and ti.transactionheaderid in ('ordevt-8tsopwlj8h','ordevt-3o054p8312','ordevt-o2fndxiycx','ordevt-rtlkkij49r')
--and ti.categoryid in (235,315,381)
--and ic.categoryid in ('cat-0473d918-810c-4224-a28e-69718b2751fc')
order by ic.locationid, ic.categoryid --ti.dateid

select * 
from dim.itemcategory 
where isactive = True
order by categoryid, locationid

select transactionheaderid, count(*) as rowcount
from fact.transactionitem
group by transactionheaderid
having count(*)>1

select ti.upselllevel, th.*
from fact.transactionheader as th 
inner join fact.transactionitem as ti 
on ti.transactionheaderid = th.transactionheaderid
and ti.orderid = th.orderid 
and th.locationid = 'any_loc_id'
and th.dateid between 2024120400 and 2024120423
