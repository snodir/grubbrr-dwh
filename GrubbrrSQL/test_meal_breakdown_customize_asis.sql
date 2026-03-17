SELECT * 
FROM fact.transactionitem as ti 
where 1=1
and ti.transactionheaderid in ('ordevt-l5hu1liixp','ordevt-d97r4qskct')
and ti.orderid in ('ord-AAASLMJ79QAA','ord-AAASLMJ79QAB','ord-AAASLMJ79QAC',
'ord-AAASLMJ79QAD','ord-AAASLMJ79QAE','ord-AAASLMJ79QAF',
'ord-AAASLMJ79QAG','ord-AAASLMJ79QAH');

select distinct customize, asis from fact.transactionitem

select ub.busdate,
       ub.eventtype,
       ub.ordersessionidentifier,
       ub.itemsessionidentifier,
       ub.elementidentifier,
       ti.*
from fact.userbehaviour as ub
inner join fact.transactionitem as ti 
on ti.ordersessionid = ub.ordersessionidentifier
where 1=1
and ub.eventtype IN ('CustomizeItemSelected', 'ComboCustomizeClicked','RegularItemSelected','ComboComponentItemSelected',
'AddToCartClicked','ComboSizeSelected','ComboItemSelected','AddAsIsSelected')
and ub.ordersessionidentifier in ('OR8KVVNGO9F3KQKY','5OLJGIRTIR1Q4OQ6')
and ti.transactionheaderid in ('ordevt-l5hu1liixp','ordevt-d97r4qskct')

select ub.busdate,
       ub.eventtype,
       ub.ordersessionidentifier,
       ub.itemsessionidentifier,
       ub.elementidentifier,
       ti.* 
from fact.userbehaviour as ub 
inner join fact.transactionitem as ti 
on ti.ordersessionid = ub.ordersessionidentifier
where ub.eventtype IN ('ComboCustomizeClicked', 'CustomizeItemSelected')
and ub.ordersessionidentifier in ('OR8KVVNGO9F3KQKY','5OLJGIRTIR1Q4OQ6')
order by ub.busdate desc;

CREATE TEMPORARY TABLE transactionitem
(
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    itemid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default" NOT NULL,
    itemsessionid text COLLATE pg_catalog."default",
    itemname text COLLATE pg_catalog."default" NOT NULL,
    itemtype text COLLATE pg_catalog."default",
    asis boolean
)

select * from fact.transactionitem

select transactionheaderid,
       itemid,
       ordersessionid,
       itemsessionid,
       itemname,
       itemtype,
       sum(has_customize) as has_customize,
       case when sum(has_customize) >= 1 then True else False end as iscustomized,
       case when sum(has_customize) >= 1 then False else True end as asis
from (
select ti.transactionheaderid,
       ti.itemid,
       ti.ordersessionid,
       ti.itemsessionid,
       ti.itemname,
       ti.itemtype,
       case when eventtype in ('CustomizeItemSelected','ComboCustomizeClicked') then 1 else 0 end as has_customize
from fact.userbehaviour as ub
left join dim.element as el 
on el.elementid = ub.elementidentifier
inner join (select transactionheaderid,ordersessionid from fact.transactionheader where orderstatus = 'order-placed') as th 
on th.ordersessionid = ub.ordersessionidentifier
inner join (select * from fact.transactionitem where itemtype IN ('item','combo','combocomponent')) as ti 
on ti.ordersessionid = ub.ordersessionidentifier
where 1=1
and ub.eventtype IN ('CustomizeItemSelected', 'ComboCustomizeClicked','RegularItemSelected','ComboComponentItemSelected',
'AddToCartClicked','ComboSizeSelected','ComboItemSelected','AddAsIsSelected')
--and ub.ordersessionidentifier in ('OR8KVVNGO9F3KQKY','5OLJGIRTIR1Q4OQ6')
--and ti.transactionheaderid in ('ordevt-l5hu1liixp','ordevt-d97r4qskct')
) as T
group by transactionheaderid,
       itemid,
       ordersessionid,
       itemsessionid,
       itemname,
       itemtype

--update fact.transactionitem  
set customize = True,
    asis = False
where ordersessionid in 
(select distinct ordersessionidentifier from fact.userbehaviour where eventtype = 'CustomizeItemSelected')

select * 
from fact.transactionitem 
where ordersessionid in 
(select distinct ordersessionidentifier from fact.userbehaviour where eventtype = 'CustomizeItemSelected')

select count(*), count(DISTINCT ordersessionidentifier) from fact.userbehaviour  
where eventtype IN ('CustomizeItemSelected','ComboCustomizeClicked','RegularItemSelected','ComboComponentItemSelected',
'AddToCartClicked','ComboSizeSelected','ComboItemSelected','AddAsIsSelected')

select ub.eventtype,
       ub.ordersessionidentifier,
       ub.itemsessionidentifier,
       ub.elementidentifier,
       count(*) over(partition by ub.ordersessionidentifier) as cnt
from fact.userbehaviour as ub 
where ub.eventtype IN ('CustomizeItemSelected','ComboCustomizeClicked')
order by count(*) over(partition by ub.ordersessionidentifier) desc


select ordersessionidentifier,
       eventtype,
       sum(has_customize) over(partition by ordersessionidentifier) as only_cust,
       count(*) over(partition by ordersessionidentifier) as all_types
from (
select ordersessionidentifier,
       eventtype,
       case when eventtype in ('CustomizeItemSelected','ComboCustomizeClicked') then 1 else 0 end as has_customize
from fact.userbehaviour
where eventtype IN ('CustomizeItemSelected','ComboCustomizeClicked','RegularItemSelected','ComboComponentItemSelected',
'AddToCartClicked','ComboSizeSelected','ComboItemSelected','AddAsIsSelected')
) as T
order by sum(has_customize) over(partition by ordersessionidentifier) desc

select *-- count(*) total_cnt, count(distinct ordersessionid) as ord_cnt
from fact.transactionitem
where customize is not null 
and asis is not null

--Ordered by Dhanraj
select ub.eventtype, ti.customize, ti.upgrade, ti.asis, ti.ordersessionid, ti.* 
from fact.transactionitem as ti
inner join fact.userbehaviour as ub 
on ti.ordersessionid = ub.ordersessionidentifier
where ti.ordersessionid in ('3BISF1K0RP1PTD9E','35C39XKO8209ELFH','TXN0F4BOW7V71BCG')

select distinct eventtype from fact.userbehaviour where eventtype like '%Customize%'

select * from fact.transactionitem as ti 
where ti.ordersessionid in ('3BISF1K0RP1PTD9E','35C39XKO8209ELFH','TXN0F4BOW7V71BCG')
