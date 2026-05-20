--drop table if EXISTS dim.frequentcustomer;
create table dim.frequentcustomer
(
    customerkey bigint NOT NULL,
    frequentcustomerid text COLLATE pg_catalog."default" NOT NULL,
    firstname text COLLATE pg_catalog."default",
    lastname text COLLATE pg_catalog."default",
    email text COLLATE pg_catalog."default",
    phone text COLLATE pg_catalog."default",
    source text COLLATE pg_catalog."default",
    organizationid text COLLATE pg_catalog."default",
    createddate text COLLATE pg_catalog."default",
    lastorderdate text COLLATE pg_catalog."default",
    ordercount integer NOT NULL DEFAULT 0,
    amountspent numeric NOT NULL DEFAULT 0,
    syscosmosts bigint,
    sysinserttime timestamp,
    sysupdatetime timestamp
);

ALTER TABLE IF EXISTS dim.frequentcustomer
--ALTER COLUMN customerkey DROP IDENTITY,
--DROP CONSTRAINT customerkey_pk
--DROP CONSTRAINT frequentcustomerid_unq UNIQUE (frequentcustomerid)
ADD CONSTRAINT customerkey_pk PRIMARY KEY (frequentcustomerid),

-- Table: dim.frequentcustomer

-- DROP TABLE IF EXISTS dim.frequentcustomer;

CREATE TABLE IF NOT EXISTS dim.frequentcustomer_bkp
(
    customerkey bigint NOT NULL,
    frequentcustomerid text COLLATE pg_catalog."default" NOT NULL,
    firstname text COLLATE pg_catalog."default",
    lastname text COLLATE pg_catalog."default",
    email text COLLATE pg_catalog."default",
    phone text COLLATE pg_catalog."default",
    source text COLLATE pg_catalog."default",
    organizationid text COLLATE pg_catalog."default",
    createddate text COLLATE pg_catalog."default",
    lastorderdate text COLLATE pg_catalog."default",
    ordercount integer NOT NULL DEFAULT 0,
    amountspent numeric NOT NULL DEFAULT 0,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    CONSTRAINT frequentcustomer_bkp_pk PRIMARY KEY (frequentcustomerid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.frequentcustomer_bkp
    OWNER to citus;

--INSERT INTO dim.frequentcustomer_bkp --178,238
SELECT *--count(*) 
FROM dim.frequentcustomer --227,642
ORDER BY ordercount DESC LIMIT 100
--TRUNCATE TABLE dim.frequentcustomer

/*
Mapping:

Order.LoyaltyUser.ID => TransHeader.FrequentCustomerID
FreqCustomer.Firstname = Order.LoyaltyUser.FirstName
FreqCustomer.Lastname = Order.LoyaltyUser.LastName
FreqCustomer.Email = Order.LoyaltyUser.Email
FreqCustomer.Phone = Order.LoyaltyUser.Phone
FreqCustomer.Source = FrequentCustomer.affiliate
FreqCustomer.CreateDate = FrequentCustomer.CreateDate
FreqCustomer.LastOrderDate = FrequentCustomer.LastOrderDate*/

--SELECT 1=1, null = null




SELECT max(length(locationid)), max(length(userid))
FROM dim.userlocation
LIMIT 1100

SELECT frequentcustomerid, count(*)
from dim.frequentcustomer 
GROUP BY frequentcustomerid
HAVING count(*) > 1
ORDER BY ordercount DESC;

SELECT max(sysinserttime) as sysinserttime,
       max(sysupdatetime) as sysupdatetime,
       max(syscosmosts) as syscosmosts,
       max(customerkey) as customerkey,
       max(frequentcustomerid) as frequentcustomerid,
       count(*) as total_records --P*21,554  S*19,832
from dim.frequentcustomer


SELECT frequentcustomerid, firstname, lastname, email, phone, source, organizationid, createddate, ordercount,
       count(*) over(PARTITION BY organizationid, phone, email, firstname) as dupl, --aggregate window functions
       ROW_NUMBER() over(PARTITION BY organizationid, phone, email, firstname order by createddate) as row_number
from dim.frequentcustomer
--where email is not null and email <> ''
order by dupl desc, email, phone, source, organizationid;  --ordercount desc, amountspent desc;

with fc_dupl as (
SELECT frequentcustomerid, firstname, lastname, email, phone, source, organizationid, createddate, ordercount,
       count(*) over(PARTITION BY organizationid, phone, source) as dupl, --aggregate window functions
       sum(CASE WHEN ordercount > 0 then 1 else 0 end) over(PARTITION BY organizationid, phone, source) as are_both_accs_active,
       ROW_NUMBER() over(PARTITION BY organizationid, phone, source order by createddate) as row_num
from dim.frequentcustomer
--where email is not null and email <> '' --and ordercount = 0
--order by dupl desc, email, phone, source, organizationid;  --ordercount desc, amountspent desc;
)
SELECT * from fc_dupl WHERE dupl > 1 --and are_both_accs_active >= 2 --and ordercount = 0 --
--and row_num = 2
order by dupl desc, email, phone, source, organizationid;  --ordercount desc, amountspent desc;


SELECT th.transactionheaderid, th.businessdate, fc.*
FROM fact.transactionheader as th 
INNER JOIN (SELECT * from fc_dupl WHERE dupl > 1 and ordercount = 0) as fc
        ON th.frequentcustomerid = fc.frequentcustomerid
order by dupl desc, email, phone, source, organizationid;  --ordercount desc, amountspent desc;


order by dupl desc, email, phone, source, organizationid, th.transactionheaderid;  --ordercount desc, amountspent desc;

SELECT --frequentcustomerid, firstname, lastname, 
        email, phone, source, organizationid, count(*) as row_count
       --count(*) over(PARTITION BY organizationid, phone, email, firstname) as dupl --aggregate window functions
from dim.frequentcustomer
where email is not null and email <> ''
group by email, phone, source, organizationid  --ordercount desc, amountspent desc;
order by row_count desc;


SELECT email, count(*)
FROM dim.frequentcustomer
group by email
having count(*) > 1

select ol.id, 
       ol.name, 
       count(fc.frequentcustomerid) as total_freq_customers,
       sum(case when fc.ordercount > 0 then 1 else 0 end) as active_freq_customers,
       sum(case when fc.ordercount is null or fc.ordercount = 0 then 1 else 0 end) as inactive_freq_customers,
       sum(fc.ordercount) as orders_placed_by_freq_customers,
       sum(fc.amountspent) as amount_spent_by_freq_customers,
       sum(fc.amountspent) / case when sum(fc.ordercount) > 0 then sum(fc.ordercount) else 1 end as avg_amount_spent_by_freq_customers
from dim.frequentcustomer as fc 
inner join dim.organization as ol 
        on fc.organizationid = ol.id
group by ol.id, ol.name
order by total_freq_customers desc, 
         orders_placed_by_freq_customers desc, 
         amount_spent_by_freq_customers desc--createddate desc-- customerkey-- syscosmosts desc-- customerkey desc, 

select coalesce(max(customerkey), 0) as maxid from dim.frequentcustomer


SELECT th.locationid, th.transactionheaderid,
       fc.frequentcustomerid, fc.firstname, fc.lastname, fc.email, fc.phone, fc.source, fc.organizationid, fc.createddate

FROM fact.transactionheader as th 
INNER JOIN dim.frequentcustomer as fc 
        ON th.frequentcustomerid = fc.frequentcustomerid


select * from fact.transactionheader order by orderdateutc desc limit 10

select fc.*, th.*
from dim.frequentcustomer as fc 
left join (select frequentcustomerid, 
                  count(*) as ordercount, 
                  sum(ordertotal) as amountspent,
                  max(dateid) as dateid
           from fact.transactionheader
           where orderstatus = 'order-placed' and frequentcustomerid is not null
           group by frequentcustomerid
) as th 
on th.frequentcustomerid = fc.frequentcustomerid
order by fc.ordercount desc, fc.amountspent desc

/*update dim.frequentcustomer
set ordercount = coalesce(th.ordercount, 0),
    amountspent = coalesce(th.amountspent, 0),
    sysupdatetime = now()
from (
    select frequentcustomerid, count(*) as ordercount, sum(ordertotal) as amountspent
    from fact.transactionheader 
    where orderstatus = 'order-placed' and frequentcustomerid is not null
    group by frequentcustomerid) as th 
where th.frequentcustomerid = frequentcustomer.frequentcustomerid;
*/

select * 
from dim.frequentcustomer 
order by createddate desc

select * 
from fact.transactionheader 
where frequentcustomerid = 'gfc-202504100103659'