create TEMPORARY table dupl (
    transactionheaderid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    duplCount integer
);

insert into dupl
select transactionheaderid, orderid, locationId, count(*) as duplCount
from fact.transactionheader
group by transactionheaderid, orderid, locationId --92T, --0S, --339P
having count(*) > 1;


;with dup as (
select  
row_number() over(PARTITION by transactionheaderid, locationid order by id) as rn, -- transactionheaderid, orderid, locationId, orderdateutc, ordertotal
*
from fact.transactionheader as th 
where EXISTS 
(select 1 from dupl as d where d.transactionheaderid = th.transactionheaderid
                           and d.orderid = th.orderid
                           and d.locationid = th.locationid)
)
select *
--delete 
from fact.transactionheader where id in (select id from dup where rn > 1);

select transactionheaderid, orderid, ordersessionid, 
       itemid,
       --itemsessionid,
       count(*) as duplCount
from fact.transactionitem
group by transactionheaderid, orderid, ordersessionid,
         itemid
         --itemsessionid
HAVING count(*) > 1;