;with cte as (
select *
from fact.transactionheader as th
where th.locationid = 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3'
  and th.orderstatus = 'order-placed'
  and th.businessdate >= '2024-06-01'-- '2025-04-01'-- '2024-06-01' --and '2025-04-01'
)
select distinct th.*, ti.*, im.*, uc.*
from cte as th
left join fact.transactionitem as ti 
on th.transactionheaderid = ti.transactionheaderid
left join fact.itemmodifier as im
on th.transactionheaderid = im.transactionheaderid and ti.itemid = im.itemid
left join fact.usercheckedin as uc
on th.locationid = uc.locationid and th.orderid = concat('ord-', uc.orderid)
where 1=1
--and uc.orderid is not null
order by th.orderdateutc desc, th.orderid;

select * from fact.itemmodifier limit 10;

select ol.organizationId, ol.organizationname, 
       th.locationid, ol.locationname,
       th.transactionheaderid, th.orderid, 
       th.orderdatelocal, th.businessdate,  ot.ordertypelabel,
       th.ordertotal, tp.paymentmethod, tp.paymentintegrationlabel
       --count(1) as ordercounts, sum(ordertotal) as amtspent, avg(ordertotal) as avg_amtspent
from fact.transactionheader as th
inner join (select * from dim.organizationlocation where organizationtype = 0 and organizationid = 'org-21b9c258-ad27-4aab-8663-4d480c235950') as ol 
        on th.locationid = ol.locationid
left join dim.ordertype as ot 
        on th.ordertype = ot.id 
left join fact.transactionpayment as tp 
        on th.transactionheaderid = tp.transactionheaderid
        and th.locationid = tp.locationid
ORDER by th.orderdatelocal desc


where 1=1
and th.orderstatus = 'order-placed'
and th.businessdate BETWEEN '2025-01-01' and CURRENT_DATE :: date--'2025-07-13' --
group by ol.organizationId, ol.organizationname, th.locationid, ol.locationname
order by count(1) desc

SELECT * from fact.transactionpayment as tp
--WHERE tp.locationid is null
ORDER by orderdateutc DESC
LIMIT 100
