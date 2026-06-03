SELECT *--count(*)
FROM fact.transactionheader as th 
WHERE 1=1 
--AND th.locationid = 'loc-bf92520f-bd20-4316-8f12-d1d4406b201d'-- 'loc-ca0632a9-5362-426a-8534-09681bb0f042'-- 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992' --'loc-dad8a3d8-74bd-4d72-a06a-56a51df8d208'
--AND th.transactionheaderid IN ('ordevt-78CRBGTRPVGELYOO','ordevt-LB8Q7XLXENKGJVZI','ordevt-KPMXKSRVLP86J2YR','ordevt-NMN4RZR6NQ31W8HW','ordevt-2MUIURL3MQPSDTWN')
AND th.orderstatus = 'order-placed'
--AND th.businessdate = '2026-05-21'
ORDER BY th.orderdatelocal DESC
LIMIT 100;

SELECT * FROM stg.silver_transaction_header 
WHERE locationid = 'loc-6f86a91c-8257-4f2c-9af5-0116546fccfd'
AND transactionheaderid = 'ordevt-XKL8CL81PD512JUQ'

SELECT *
FROM dim.ordertype
WHERE locationid = 'loc-6f86a91c-8257-4f2c-9af5-0116546fccfd'

SELECT ol.organizationname, ol.locationname, os.*--count(*)
FROM fact.occasionsurveydetail as os 
INNER JOIN dim.organizationlocation as ol
        ON ol.locationid       = os.locationid
       AND ol.organizationtype = 0
WHERE 1=1 AND os.locationid = 'loc-bf92520f-bd20-4316-8f12-d1d4406b201d'-- 'loc-ca0632a9-5362-426a-8534-09681bb0f042'-- 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992' --'loc-dad8a3d8-74bd-4d72-a06a-56a51df8d208'
AND os.orderid IN ('ordevt-78CRBGTRPVGELYOO','ordevt-LB8Q7XLXENKGJVZI','ordevt-KPMXKSRVLP86J2YR','ordevt-NMN4RZR6NQ31W8HW','ordevt-2MUIURL3MQPSDTWN')

SELECT * FROM fact.recommendations
WHERE 1=1 AND locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992' --'loc-dad8a3d8-74bd-4d72-a06a-56a51df8d208'
ORDER BY syscosmosts DESC
LIMIT 100;


SELECT max(th.syscosmosts) as maxts, 
    max(th.orderdateutc) as max_orderdateutc,
    'fact.transactionheader' as watermarktablename, 
    'nge' as source
FROM fact.transactionheader as th
WHERE sourceid = 1 --1780133426	fact.transactionheader	nge

SELECT DISTINCT orderstatus FROM fact.transactionheader

SELECT *
FROM fact.itemmodifier as im 
WHERE 1=1 
--AND im.locationid = 'loc-dad8a3d8-74bd-4d72-a06a-56a51df8d208'
AND im.transactionheaderid = 'ordevt-N1S9WD4EOAS7DY6V'
--AND im.businessdate = '2026-05-01'
--ORDER BY im.orderdatelocal DESC
LIMIT 100;

SELECT *
FROM fact.transactionitem
WHERE syscosmosts IS NOT NULL
ORDER BY syscosmosts DESC
LIMIT 100;

SELECT *
FROM fact.modifier_interactions as mi 
WHERE 1=1 
--AND mi.locationid = 'loc-dad8a3d8-74bd-4d72-a06a-56a51df8d208'
--AND mi.transactionheaderid = 'ordevt-N1S9WD4EOAS7DY6V'
--AND im.businessdate = '2026-05-01'
--ORDER BY im.orderdatelocal DESC
LIMIT 100;


DROP TABLE IF EXISTS stg.transactionheader;
CREATE TABLE IF NOT EXISTS stg.transactionheader
(
    id bigint NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    orderid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    kioskid text COLLATE pg_catalog."default",
    ordersessionid text COLLATE pg_catalog."default",
    dateid integer,
    orderdateutc text COLLATE pg_catalog."default",
    orderdatelocal timestamp without time zone,
    orderstatus text COLLATE pg_catalog."default",
    ordertype integer,
    numberofitems smallint,
    numberofpayments smallint,
    ordersredeemedrewards numeric(7,3),
    ordersubtotal numeric(7,3),
    ordertotal numeric(7,3),
    ordertax numeric(7,3),
    ordertip numeric(7,3),
    orderdiscount numeric(7,3),
    orderbalance numeric(7,3),
    paymentstatus text COLLATE pg_catalog."default",
    sourcefile text COLLATE pg_catalog."default" NOT NULL DEFAULT 'NGE'::text,
    createddate timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updateddate timestamp without time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    orderstarttime timestamp without time zone,
    reviewordertime timestamp without time zone,
    checkouttime timestamp without time zone,
    paystarttime timestamp without time zone,
    sessionendtime timestamp without time zone,
    precheckouttime numeric(7,3),
    postcheckouttime numeric(7,3),
    menupagetime numeric(7,3),
    reviewpagetime numeric(7,3),
    paymentpagetime numeric(7,3),
    totalordertime numeric(7,3),
    businessdate date,
    syscosmostsutc text COLLATE pg_catalog."default",
    CONSTRAINT transactionheader_pkey PRIMARY KEY (transactionheaderid, id)
)

TABLESPACE pg_default;

ALTER TABLE stg.transactionheader
    OWNER to citus;

-- Index: fact.transactionheader_locationid_dateid_idx
CREATE INDEX IF NOT EXISTS transactionheader_locationid_dateid_idx
    ON stg.transactionheader USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, dateid ASC NULLS LAST)
    INCLUDE(orderstatus, ordertype, businessdate)
    TABLESPACE pg_default;

select * from stg.transactionheader

--insert into fact.transactionheader
select (select max(id) from fact.transactionheader) as maxid, 
*
from stg.transactionheader as stg
where not exists (
    select 1 from fact.transactionheader th 
    where th.transactionheaderid = stg.transactionheaderid
      and th.orderid = stg.orderid
      and th.locationid = stg.locationid
) 

select count(*) from stg.transactionheader --140,377
select count(*) from fact.transactionheader where orderstatus = 'order-placed' --140,358

select * 
from stg.transactionheader as stg
where 1=1  
and stg.locationid = 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3'-- 'loc-72cd6945-5b7c-4fa5-942b-ee3ec8f21881'-- 
--and stg.orderdateutc >= '2025-02-20 05:00:00.0000000Z' and orderdateutc < '2025-02-21 05:00:00.0000000Z'
and stg.businessdate = '2025-02-20'
--and stg.orderstatus = 'order-placed'
--and not exists (select 1 from fact.transactionheader th where th.transactionheaderid = stg.transactionheaderid)
and stg.transactionheaderid not in 
(
    select * from fact.transactionheader 
    where locationid = 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3' 
    and businessdate = '2025-02-20' -- orderdateutc >= '2025-02-20 05:00:00.0000000Z' and orderdateutc < '2025-02-21 05:00:00.0000000Z'
    and orderstatus = 'order-placed'
)

select * from fact.transactionheader
where transactionheaderid in (
'ordevt-hs8a7m72ze',
'ordevt-ptjegwu11x',
'ordevt-o388yxzaja',
'ordevt-4z25l3pxei',
'ordevt-1nm7n0astv',
'ordevt-xoj8dzrhfg',
'ordevt-1gcasgq0t3',
'ordevt-eedynu6e1i',
'ordevt-9csjcnr60t',
'ordevt-85ds5ka3t9',
'ordevt-0n51olb52n',
'ordevt-jwd1h6qpg7',
'ordevt-efayscnfa8',
'ordevt-36b9xrmzyt',
'ordevt-9ijx8omrw4',
'ordevt-cnhm9187wm',
'ordevt-xmiqda5d38',
'ordevt-1s934whnqk',
'ordevt-ib7dytysek',
'ordevt-alb9euf5zh',
'ordevt-lk56ztm90o',
'ordevt-h6cez41pdb',
'ordevt-xca2n1omap',
'ordevt-4ykyhz30qc')

select * 
from stg.transactionheader stg
where 1=1 
--and stg.locationid = 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3'
--and stg.orderdateutc >= '2025-02-20 05:00:00.0000000Z' and orderdateutc < '2025-02-21 05:00:00.0000000Z'
--and not exists (select 1 from fact.transactionheader th where th.transactionheaderid = stg.transactionheaderid)
and stg.transactionheaderid not in (select transactionheaderid from fact.transactionheader)

select distinct transactionheaderid from stg.transactionheader where transactionheaderid is not null
except 
select distinct transactionheaderid from fact.transactionheader where transactionheaderid is not null


select *-- sum(ordertotal), sum(ordersubtotal) count(*) --
from stg.transactionheader 
where 1=1
and (dateid is null)
and locationid = 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3'-- 'loc-72cd6945-5b7c-4fa5-942b-ee3ec8f21881'-- 'loc-9070a34c-e976-4d96-b06e-ec2ec5214ee4'
--and orderid like '%6202F57FAE274A4F82D96495B0B1A2C2%'-- in ('ord-17366','ord-17383','ord-17384')-- = 'ord-AAASLMR79QAA'-- is not null-- in ('ord-32492334929395718','ord-32491966367449089','ord-32491173946081280')
and orderdateutc >= '2025-02-20 05:00:00.0000000Z' and orderdateutc < '2025-02-21 05:00:00.0000000Z'
--and dateid between 2025022000 and 2025022023 
--and channel is not null
and orderstatus = 'order-placed'
--order by orderdateutc desc limit 100

--insert into fact.transactionheader
select distinct transactionheaderid-- count(*)
from stg.transactionheader
where 1=1
and orderdateutc >= '2025-02-15 05:00:00.000+00:00' --7,296
and orderstatus = 'order-placed'

select count(*) --distinct transactionheaderid--
from fact.transactionheader
where 1=1
--and orderdateutc >= '2025-02-15 05:00:00.000+00:00' --6,198
and orderstatus = 'order-placed'
--order by orderdateutc desc 
limit 10

--128,673 cosmosDB
--128,891 PG

select *
from fact.transactionheader
where ordersessionid in (
'4M119WKR9PFTSMAR',
'2FMC87Y8P9RG1ZMZ',
'QVMLR42MJXQ1YDN5',
'WB4W5CLP8XCRXXR3',
'ZW3FC2F4L0BUX21H'
)

update fact.transactionheader
set kioskid = stg.kioskid,
    ordersessionid = stg.ordersessionid,
    dateid = stg.dateid,
    orderdateutc = stg.orderdateutc,
    orderdatelocal = stg.orderdatelocal,
    orderstatus = stg.orderstatus,
    ordertype = stg.ordertype,
    numberofitems = stg.numberofitems,
    numberofpayments = stg.numberofpayments,
    ordersredeemedrewards = stg.ordersredeemedrewards,
    ordersubtotal = stg.ordersubtotal,
    ordertotal = stg.ordertotal,
    ordertax = stg.ordertax,
    ordertip = stg.ordertip,
    orderdiscount = stg.orderdiscount,
    orderbalance = stg.orderbalance,
    paymentstatus = stg.paymentstatus,
    sourcefile = stg.sourcefile,
    createddate = stg.createddate,
    updateddate = stg.updateddate,
    orderstarttime = stg.orderstarttime,
    reviewordertime = stg.reviewordertime,
    checkouttime = stg.checkouttime,
    paystarttime = stg.paystarttime,
    sessionendtime = stg.sessionendtime,
    precheckouttime = stg.precheckouttime,
    postcheckouttime = stg.postcheckouttime,
    menupagetime = stg.menupagetime,
    reviewpagetime = stg.reviewpagetime,
    paymentpagetime = stg.paymentpagetime,
    totalordertime = stg.totalordertime,
    businessdate = stg.businessdate,
    syscosmostsutc = stg.syscosmostsutc
from stg.transactionheader as stg
where stg.locationid = transactionheader.locationid 
  and stg.transactionheaderid = transactionheader.transactionheaderid
  and stg.orderid = transactionheader.orderid
  --and transactionheader.orderdatelocal is null;
  --and transactionheader.locationid = 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3' 
  --and transactionheader.businessdate = '2025-02-20' -- orderdateutc >= '2025-02-20 05:00:00.0000000Z' and orderdateutc < '2025-02-21 05:00:00.0000000Z'
  --and transactionheader.orderstatus = 'order-placed'

--select * from stg.transactionheader order by syscosmostsutc desc limit 1000

select * from fact.transactionheader 
where 1=1
and channel is not null
and ordersessionid  = 'IAMLKSPSA5SLBD9A'


select * 
from fact.transactionheader
where 1=1
--and locationid = 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3'
and orderid = 'ord-8C91C76CD4FE40EAA5120CF3B995FE41'-- 'ord-285D11CAC0554380AE68863699B2D61C'
--and businessdate = '2025-02-27'
--and orderstatus = 'order-placed'

select * 
from fact.transactionheader
where 1=1
--and locationid = 'loc-0157f49f-e7c0-4cc4-9ab7-4f7a8d2c26d3'
--and businessdate = '2025-02-27'
--and orderstatus = 'order-placed'
and transactionheaderid in (
'ordevt-4dy2bjbavx',
'ordevt-qf1pldlr5w',
'ordevt-911ykpt2n8',
'ordevt-pj3k04molt',
'ordevt-ojyaytw0hr',
'ordevt-l3v45ss22s',
'ordevt-dt66e4mtfb',
'ordevt-jz0km5qmns',
'ordevt-fhx2klvltr',
'ordevt-bkl92kyful',
'ordevt-tp7oggmfqu',
'ordevt-7fsgfnk3c2',
'ordevt-yr7022wo8u',
'ordevt-8k7j5sn1f6',
'ordevt-8xquu1ch61',
'ordevt-l72kghg644',
'ordevt-jel0socacq',
'ordevt-caw2b2r0k5',
'ordevt-9k14x8rimi',
'ordevt-9oh4452gqf',
'ordevt-6oa0qwl0jw',
'ordevt-emyzzgj7au',
'ordevt-mp9lrmpgvr',
'ordevt-hzbfr8vzdk',
'ordevt-ccmyouv8uc',
'ordevt-0x70g4n05m',
'ordevt-ci565qnc1x',
'ordevt-uh9djm1bvx',
'ordevt-cyasv1s7h1',
'ordevt-de47y966q3',
'ordevt-11buj1qdb5',
'ordevt-b6tbgc9gi4',
'ordevt-4jifwd04r6',
'ordevt-6xcddq04w5',
'ordevt-ectyvp44d3',
'ordevt-ahdfkkv33b',
'ordevt-cx3rxb1c9w',
'ordevt-nomy1cjqed',
'ordevt-omp0jym8wu',
'ordevt-8ptq9d7wz2',
'ordevt-v7qzyk2jse',
'ordevt-zrprf88wyq',
'ordevt-8okkof5ozq',
'ordevt-rn1gwrmpbo',
'ordevt-cgu5ny9366',
'ordevt-qfprwunkai',
'ordevt-4nvgznjiua',
'ordevt-g7h5p8mmat',
'ordevt-oz0owd9zok',
'ordevt-pmnbj5y5g0',
'ordevt-cll9n7ti3f',
'ordevt-j0guytpy6f',
'ordevt-127tpjn5f0',
'ordevt-koltp1a2cn',
'ordevt-pip6e6p5cg',
'ordevt-0y4v4zjccs',
'ordevt-pdpdysz363',
'ordevt-0l4n9rtb27',
'ordevt-ruo0d7qf7o',
'ordevt-bbwj7gdgnf',
'ordevt-mm135m1asx',
'ordevt-4wdernuxnd',
'ordevt-z9jbt3gzjh',
'ordevt-o86wuevx5r',
'ordevt-k396lwa9bk',
'ordevt-09fk0cpq66',
'ordevt-0cmh2ma8cd',
'ordevt-gv1ols8zpi',
'ordevt-mkd3fmipdh',
'ordevt-oebr84bvq6',
'ordevt-z7cwetqe93',
'ordevt-4bfzh0e43i',
'ordevt-kzx06dkate',
'ordevt-32nx66246o',
'ordevt-97b5d78i0n',
'ordevt-om9b14bfor',
'ordevt-aepft9a7kr'
)
