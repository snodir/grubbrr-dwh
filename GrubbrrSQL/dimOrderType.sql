drop TABLE IF EXISTS dim.ordertype_bkp;
CREATE TABLE IF NOT EXISTS dim.ordertype_bkp
(
    id bigint NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    kioskid text COLLATE pg_catalog."default" NOT NULL,
    ordertypeid text COLLATE pg_catalog."default" NOT NULL,
    ordertypelabel text COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT ordertype_bkp_pk PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE dim.ordertype_bkp
    OWNER to citus;

--INSERT INTO dim.ordertype_bkp
SELECT * from dim.ordertype

--TRUNCATE table dim.ordertype;

-- Index: dim.order_type_uidx
CREATE INDEX IF NOT EXISTS order_type_uidx
    ON dim.ordertype USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST, 
     kioskid COLLATE pg_catalog."default" ASC NULLS LAST, 
     ordertypeid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

SELECT *--count(*)
from fact.transactionheader as th
WHERE 1=1 
--and th.ordertype not in (SELECT id from dim.ordertype)
--and not EXISTS (SELECT 1 from dim.ordertype as o where o.locationid = th.locationid and o.kioskid = th.kioskid)
and th.orderstatus = 'order-placed'
and th.ordertype is not null --338,341/14,224
order by th.orderdateutc desc
LIMIT 100 

/*P-7CY56VTZZYJRUSZS, NP-DF9N0QWSLT4M5S27*/

--UPDATE fact.transactionheader
set ordertype = null 
WHERE ordertype not in (SELECT id from dim.ordertype)

SELECT * from dim.ordertype
--WHERE locationid = 'loc-33aa6273-01d1-44f0-b11c-59b291ad03c7'
ORDER BY id;

--loc-33aa6273-01d1-44f0-b11c-59b291ad03c7, ksk-32994550, Carry Out




select * from dim.ordertype
select * from dim.ABTests

select * from dim.element

ALTER TABLE dim.ordertype
ALTER COLUMN id
DROP IDENTITY IF EXISTS;


select locationid, kioskid, ordertypelabel, count(1)
from dim.ordertype
group by locationid, kioskid, ordertypelabel


SELECT distinct 
  c.kioskSource.kioskId ?? null as kioskid,
  c.locationId ?? null as locationid,
  c.orderType ?? null as ordertypeid,
  c.orderTypeLabel ?? null as ordertypelabel,
  c.orderDate ?? null as orderdate
FROM orders as c
where 1=1
and (c.isTestOrder = false or is_defined(c.isTestOrder) = false)
and c.kioskSource.kioskId > ''
AND c.orderType > ''
--AND c.locationId NOT IN ('loc-lr3h36utnl','loc-tezvlbqtrz')