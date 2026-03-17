drop table if EXISTS fact.usercheckedin;
CREATE TABLE IF NOT EXISTS fact.usercheckedin
(
    organizationid text COLLATE pg_catalog."default" NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    kioskid text COLLATE pg_catalog."default",
    ordersessionid text COLLATE pg_catalog."default",
    dateid integer,
    ordertimestamp text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    customername text COLLATE pg_catalog."default",
    customerphone text COLLATE pg_catalog."default",
    orderstatus text COLLATE pg_catalog."default",
    ordertotal numeric(7,3),
    paymentstatus text COLLATE pg_catalog."default",
    amountpaid numeric(7,3),
    paymentmethod text COLLATE pg_catalog."default",
    paymentcardtype text COLLATE pg_catalog."default",
    sysinserttime TIMESTAMP
)

TABLESPACE pg_default;

ALTER TABLE fact.usercheckedin
    OWNER to citus;


select * from fact.usercheckedin
where 1=1
--and orderid in ('8A8E7B5E8C72402A9864384EA23CCB40','3A10B7FB28624006BB2762910CD24A36')
order by ordertimestamp desc

select max(length(organizationid)) from dim.organizationlocation

select * from fact.transactionpayment;
select * from fact.transactionitem;
select * from dim.datedim

--alter table fact.usercheckedin
--add sysinserttime TIMESTAMP


select * from fact.usercheckedin
where ordertimestamp like '2025%';

/*update fact.usercheckedin
set --amountpaid = amountpaid / 100,
    --ordertotal = ordertotal / 100,
    paymentcardtype = '1'
where paymentmethod = 'Pay with Card'
and orderid = '818D80467FED4DA4AEF2ACC853CF3BF6'*/


