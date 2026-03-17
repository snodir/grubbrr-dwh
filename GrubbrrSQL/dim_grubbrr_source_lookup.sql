CREATE TABLE dim.grubbrr_source_lookup(
id INTEGER PRIMARY KEY,
source CHARACTER VARYING(10) COLLATE pg_catalog."default",
description CHARACTER VARYING(50) COLLATE pg_catalog."default"
)
TABLESPACE pg_default;

ALTER TABLE dim.grubbrr_source_lookup
OWNER to citus;

ALTER TABLE fact.transactionheader
ADD sourceid INTEGER;

ALTER TABLE fact.occasionsurveydetail
--DROP COLUMN ngesyscosmosts, DROP COLUMN gemsyscosmosts
--ADD syscosmosts BIGINT,
--ADD sourceid int;
ALTER COLUMN surveytransid DROP NOT NULL
DROP CONSTRAINT locationid_orderid_surveytransid_pk

ALTER TABLE fact.occasionsurveydetail
ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id)

SELECT * FROM fact.occasionsurveydetail

SELECT * FROM dim.grubbrr_source_lookup
SELECT * FROM fact.occasionsurveydetail WHERE sourceid = 2

--UPDATE fact.occasionsurveydetail
--set sourceid = 1

SELECT * FROM fact.transactionheader
WHERE orderstatus is null-- <> 'order-placed'
AND sourceid is null-- = 2
ORDER BY orderdateutc desc
LIMIT 1000;

UPDATE fact.transactionheader
SET sourceid = CASE WHEN orderstatus = 'order-placed' THEN 1 ELSE 2 END
WHERE orderstatus = 'order-placed'


SELECT * from fact.transactionitem as ti
WHERE 1=1-- ti.transactionheaderid not like 'ordevt-%'
AND ti.orderdateutc :: timestamp > now()
ORDER BY orderdateutc desc LIMIT 1000

INSERT INTO dim.grubbrr_source_lookup(id, source, description)
VALUES
      (1, 'nge', 'Next Generation Enterprise'),
      (2, 'gem', 'Grubbrr Event Management'),
      (3, 'gsh', 'Grubbrr System Health'),
      (4, 'gou', 'Grubbrr Organizations and Users'),
      (5, 'gxs', 'Grubbrr Transaction Service')


update fact.transactionheader
set orderdatelocal = orderdateutc::TIMESTAMPTZ AT TIME ZONE l.timezone
from (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end as timezone from dim.location) as l
where l.locationid = transactionheader.locationid 
and transactionheader.orderdatelocal is null;

update fact.transactionheader
set orderdatelocal = orderdateutc::TIMESTAMPTZ AT TIME ZONE 'America/New_York'
where orderdatelocal is null;

update fact.transactionheader
set dateid = cast(to_char(orderdatelocal, 'YYYYMMDDHH24') as integer)
where dateid is null;

update fact.transactionheader
set businessdate = cast(orderdatelocal as date)
where businessdate is null;

update fact.transactionheader
set ABTestID = ABTests.ABTestID
from dim.ABTests
where ABTests.OrderSessionID = transactionheader.ordersessionid
and transactionheader.ABTestID is null;

select 1 as rn;
