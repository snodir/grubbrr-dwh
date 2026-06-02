
WITH dupl AS (
    SELECT ot.locationid, ot.eventtoken, count(*) AS dupl --> 1
    FROM fact.ordertiming as ot
    GROUP BY ot.locationid, ot.eventtoken
    HAVING count(*) > 1   
), dupl_detector AS (
    SELECT *, ROW_NUMBER() OVER(PARTITION BY ot.locationid, ot.eventtoken ORDER BY ot.id DESC) AS rn
    FROM fact.ordertiming as ot 
    WHERE EXISTS (SELECT 1 FROM dupl WHERE dupl.locationid = ot.locationid AND dupl.eventtoken = ot.eventtoken)
)
DELETE FROM fact.ordertiming as ot WHERE EXISTS (SELECT 1 FROM dupl_detector as dd 
              WHERE dd.id         = ot.id 
                AND dd.locationid = ot.locationid 
                AND dd.eventtoken = ot.eventtoken
                AND dd.rn         > 1);

ALTER TABLE IF EXISTS fact.ordertiming
ADD CONSTRAINT locationid_eventtoken_unq UNIQUE (locationid, eventtoken);

ALTER TABLE IF EXISTS fact.ordertiming
ADD CONSTRAINT locationid_eventtoken_unq UNIQUE (locationid, eventtoken);

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