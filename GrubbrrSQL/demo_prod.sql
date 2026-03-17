select sum(ordertotal) as ordertotal, 
       sum(orderdiscount) as orderdiscount, 
       sum(ordersredeemedrewards) as ordersredeemedrewards
from fact.transactionheader
where locationid = 'loc-6e6a1e38-f495-417a-95a0-cc9a1dd1a88a'
and businessdate BETWEEN '2025-01-28' and '2025-03-04'
order by orderdatelocal desc
limit 10;

select * from fact.transactionitem --limit 10 --item-level
where orderid in (
    select *-- distinct orderid --, substring(orderid, 5, length(orderid))
    from fact.transactionheader --order-level
    where 1=1
    and locationid like 'loc-d5cc5cc1-dcf4-454e-8b42-88d07fb78e0f'-- 'loc-33aa6273-01d1-44f0-b11c-59b291ad03c7'-- 'loc-7ca1e5db-b1bd-4455-afd1-8dfa628dcfac' --'loc-61493b82-41d7-4b02-b788-de845b480d17' --'loc-f5f8j3z6y6'-- 'loc-87136a64-d70e-4e2d-b534-d1d9a2fefcc0'
    and businessdate = '2025-04-14'
    and orderstatus = 'order-placed'
)


select * 
from fact.usercheckedin
where 1=1 -- locationid = 'loc-33aa6273-01d1-44f0-b11c-59b291ad03c7'
and orderid in (
    select distinct substring(orderid, 5, length(orderid))
    from fact.transactionheader
    where 1=1
    and locationid like 'loc-d5cc5cc1-dcf4-454e-8b42-88d07fb78e0f'-- 'loc-33aa6273-01d1-44f0-b11c-59b291ad03c7'-- 'loc-7ca1e5db-b1bd-4455-afd1-8dfa628dcfac' --'loc-61493b82-41d7-4b02-b788-de845b480d17' --'loc-f5f8j3z6y6'-- 'loc-87136a64-d70e-4e2d-b534-d1d9a2fefcc0'
    and businessdate = '2025-04-14'
    and orderstatus = 'order-placed'
)

select *
from dim.menuitem
where menuitemid = 'itm-46625ae1-64f8-4704-8511-e4cd808f3f6e'

select * 
from dim.location
where locationid = 'loc-33aa6273-01d1-44f0-b11c-59b291ad03c7'

select * from dim.frequentcustomer order by ordercount desc

select * 
from dim.organizationlocation 
where 1=1
--and organizationtype = 0
and (lower(organizationname) like '%einstein%' or lower(locationname) like '%einstein%')
--and organizationid in ('org-d5e6a645-9c9b-42ff-aae9-e04cb35f0f3f')
and locationid in ('loc-48c7aa17-b789-4d26-98df-311ee606f3ad',
                   'loc-d60c9341-3aa1-4d8d-a44f-1840d257111b',
                   'loc-b3dc6588-dc7e-45c4-a854-e5a53d42744a')

select * 
from dim.organization

select *
from dim.location 
order by companyid
where 1=1
and locationid in ('loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3'
                   'loc-48c7aa17-b789-4d26-98df-311ee606f3ad',
                   'loc-d60c9341-3aa1-4d8d-a44f-1840d257111b',
                   'loc-b3dc6588-dc7e-45c4-a854-e5a53d42744a',
                   'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3')

select ol.organizationid, ol.organizationname, ol.locationname, th.*
from fact.transactionheader as th
inner join (select * from dim.organizationlocation where organizationtype = 0) as ol
on th.locationid = ol.locationid
where th.orderstatus = 'order-placed'
and th.businessdate >= '2025-04-01'
order by ol.organizationid


select locationid, count(1)
from dim.organizationlocation 
where organizationtype = 0
group by locationid

select ol.organizationId, ol.organizationname, ti.locationid, ol.locationname, 
       count(1) ordercounts, sum(ordertotal) as amtspent, avg(ordertotal) as avg_amtspent
from fact.transactionheader as ti
inner join (select * from dim.organizationlocation where organizationtype = 0) as ol 
        on ti.locationid = ol.locationid
where orderstatus = 'order-placed'
  and businessdate = '2025-05-21'
group by ol.organizationId, ol.organizationname, ti.locationid, ol.locationname
order by count(1) desc

select ti.transactionheaderid, ti.menuitemid, ti.itemname, mi.menuitemid, mi.menuitemname
from fact.transactionitem as ti 
inner join dim.menuitem as mi 
on ti.menuitemid = mi.id

select * 
from fact.transactionitem
where menuitemid not in (select id from dim.menuitem);
 


select * from dim.menuitem order by id;
select * from fact.devicestate
alter table fact.transactionitem
--add dim_menuitemid text
add dim_locationid text;

/*alter table fact.transactionitem
add CONSTRAINT menuitemid_fk foreign key (menuitemid) REFERENCES dim.menuitem (id);
*/

/*update fact.transactionitem
set dim_menuitemid = mi.menuitemid,
    dim_locationid = mi.locationid
from dim.menuitem as mi 
where transactionitem.menuitemid = mi.id;

update fact.transactionitem
set menuitemid = mi.id
from dim.menuitem as mi 
where transactionitem.dim_menuitemid = mi.menuitemid;

update fact.transactionitem
set menuitemid = null
where menuitemid not in (select id from dim.menuitem);*/


