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
    paymentcardtype text COLLATE pg_catalog."default"
)

TABLESPACE pg_default;

select * from fact.usercheckedin
select DISTINCT ordertimestamp from fact.usercheckedin

select organizationid,
       locationid,
       orderid,
       dateid,
       ordertimestamp,
       customername
from fact.usercheckedin
