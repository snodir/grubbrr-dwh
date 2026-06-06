ALTER TABLE IF EXISTS dim.menuitem
ADD CONSTRAINT menuitemid_unq UNIQUE (menuitemid)


ALTER TABLE fact.vw_offer_analysis
--add CONSTRAINT trxnid_recommendationid_itemid_uidx UNIQUE (transactionheaderid, recommendationid, offereditem),
DROP CONSTRAINT locationid_trxnid_recommendationid_fk 
FOREIGN KEY (locationid, transactionheaderid, recommendationid) 
REFERENCES fact.recommendations(locationid, transactionheaderid, recommendationid);

ALTER TABLE fact.recommendations
ADD CONSTRAINT locationid_trxnid_recommendationid_pk 
PRIMARY KEY (locationid, transactionheaderid, recommendationid);

ALTER TABLE fact.recommendations
--OWNER to citus;
---add syscosmosts BIGINT
DROP CONSTRAINT location_transactionheaderid_fk 
FOREIGN KEY (locationid, transactionheaderid) 
REFERENCES fact.transactionheader (locationid, transactionheaderid)

SELECT DISTINCT rc.transactionheaderid FROM fact.recommendations as rc --DELETE --FROM fact.vw_offer_analysis as rc-- fact.recommendations as rc 
WHERE 1=1
  --NOT EXISTS (SELECT 1 FROM fact.transactionheader as th WHERE th.locationid = rc.locationid AND th.transactionheaderid = rc.transactionheaderid)
AND rc.transactionheaderid NOT IN (SELECT transactionheaderid FROM fact.transactionheader)

SELECT DISTINCT rc.transactionheaderid FROM fact.transactionpayment as rc --DELETE-- FROM fact.transactionpayment as rc-- fact.recommendations as rc 
WHERE 1=1
  --NOT EXISTS (SELECT 1 FROM fact.transactionheader as th WHERE th.locationid = rc.locationid AND th.transactionheaderid = rc.transactionheaderid)
AND rc.transactionheaderid NOT IN (SELECT transactionheaderid FROM fact.transactionheader)


ALTER TABLE dim.kioskdetails 
ADD CONSTRAINT locationid_pk PRIMARY KEY (locationid);

ALTER TABLE dim.vw_grubbrrinstallbase
--ADD CONSTRAINT locationid_fk FOREIGN key (location_id) REFERENCES dim.kioskdetails (locationid),
ADD CONSTRAINT organizationid_locationid_fk FOREIGN key (organization_id, location_id) REFERENCES dim.organizationlocation(organizationid, locationid)

ALTER TABLE dim.organizationlocation
ADD CONSTRAINT organizationid_locationid_pk PRIMARY key (organizationid, locationid);

ALTER TABLE fact.transactionheader
ADD CONSTRAINT transactionheader_pkey PRIMARY key (locationid, transactionheaderid)

ALTER TABLE fact.transactionheader
ADD CONSTRAINT locationid_fk FOREIGN key (locationid) REFERENCES dim.organization(id)

ALTER TABLE fact.transactionitem
ADD CONSTRAINT locationid_fk FOREIGN key (locationid) REFERENCES dim.organization(id)

ALTER TABLE dim.frequentcustomer
ADD CONSTRAINT frequent_customer_pk PRIMARY key (frequentcustomerid);

ALTER TABLE fact.transactionheader
DROP CONSTRAINT frequent_customer_fk FOREIGN key (frequentcustomerid) REFERENCES dim.frequentcustomer(frequentcustomerid)

SELECT * FROM dim.frequentcustomer WHERE frequentcustomerid = 'gfc-202603190904991';

ALTER TABLE fact.transactionheader
add charityamount  NUMERIC(7,3),
add syscosmosts BIGINT

ALTER TABLE fact.userbehaviour
add syscosmosts BIGINT,
add eventinstant text


ALTER TABLE fact.transactionheader
add syscosmosts BIGINT

ALTER TABLE fact.transactionitem
add syscosmosts BIGINT

ALTER TABLE fact.transactionheader
add CONSTRAINT ordertype_fk FOREIGN KEY (ordertype) REFERENCES dim.ordertype(id);

ALTER TABLE fact.transactionheader
ADD CONSTRAINT location_kiosk_fk FOREIGN key (locationid, kioskid) REFERENCES dim.kiosk(locationid, kioskid)

ALTER TABLE fact.transactionitem 
ADD CONSTRAINT locationid_transactionheaderid_fk 
FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);

ALTER TABLE fact.transactionheader
ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.location(locationid);

ALTER TABLE fact.transactionitem
DROP CONSTRAINT categoryid_fk 
FOREIGN KEY (categoryid) REFERENCES dim.itemcategory(id)

ALTER TABLE fact.transactionitem
ADD CONSTRAINT menuitemid_fk FOREIGN KEY (menuitemid) REFERENCES dim.menuitem(id);

ALTER TABLE fact.transactionpayment
ADD CONSTRAINT payments_locationid_transactionheaderid_pkey PRIMARY KEY (locationid, transactionheaderid)
ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);

ALTER TABLE fact.itemmodifier
ADD CONSTRAINT trxnid_itemid_mdfrgrpid_mdfrid_pk PRIMARY key (transactionheaderid, itemid, modifiergroupid, modifierid)

ALTER TABLE fact.transactionrefunds
ADD CONSTRAINT locationid_transactionheaderid_pk PRIMARY KEY (locationid, transactionheaderid)

ALTER TABLE fact.vw_offer_analysis
ADD CONSTRAINT upsellgroupid_fk FOREIGN KEY (upsellgroupid) REFERENCES dim.upsellgrouplookup(upsellgroupid)

ALTER TABLE dim.menuitem 
ADD CONSTRAINT menuitemid_unq UNIQUE (menuitemid);

ALTER TABLE fact.vw_offer_analysis 
ADD CONSTRAINT selecteditem_fk FOREIGN KEY (selecteditem) REFERENCES dim.menuitem(menuitemid)

ALTER TABLE dim.occasionsurvey 
ADD CONSTRAINT orgid_surveyid_pk UNIQUE (organizationid, surveyid);

ALTER TABLE fact.itemssurvey 
DROP CONSTRAINT orgid_surveyid_fk 
FOREIGN KEY (organizationid, surveyid) REFERENCES dim.occasionsurvey(organizationid, surveyid);

ALTER TABLE fact.itemssurvey 
ADD CONSTRAINT orgid_locationid_fk foreign key (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);

ALTER TABLE fact.occasionsurveydetail 
DROP CONSTRAINT orgid_surveyid_fk 
FOREIGN KEY (organizationid, surveyid) REFERENCES dim.occasionsurvey(organizationid, surveyid);

ALTER TABLE fact.occasionsurveydetail 
ADD CONSTRAINT orgid_locationid_fk foreign key (organizationid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid);


ALTER TABLE fact.occasionsurveydetail
ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);

ALTER TABLE fact.itemssurvey
ADD CONSTRAINT locationid_transactionheaderid_fk FOREIGN KEY (locationid, orderid) REFERENCES fact.transactionheader(locationid, transactionheaderid);

ALTER TABLE fact.itemmodifier
ADD CONSTRAINT transactionheaderid_itemid_fk FOREIGN KEY (transactionheaderid, itemid) REFERENCES fact.transactionitem(transactionheaderid, itemid);

ALTER TABLE fact.occasionsurveydetail
ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id)

ALTER TABLE fact.transactionheader
ADD CONSTRAINT sourceid_fk FOREIGN KEY (sourceid) REFERENCES dim.grubbrr_source_lookup(id)

CREATE INDEX idx_th_date_status_loc
  ON fact.transactionheader (businessdate, orderstatus, locationId);

ALTER TABLE fact.devicetelemetry 
ADD CONSTRAINT location_deviceid_fk FOREIGN KEY (locationid, deviceid) REFERENCES dim.kiosk(locationid, kioskid);

ALTER TABLE fact.devicetelemetry 
ADD CONSTRAINT locationid_fk FOREIGN KEY (locationid) REFERENCES dim.organization(id);

ALTER TABLE fact.deviceevent
ADD CONSTRAINT loc_ctg_eventtype_token_pkey PRIMARY KEY (locationid, datacategory, actiontype, eventtoken)
ADD CONSTRAINT orgid_locationid_fk FOREIGN KEY (companyid, locationid) REFERENCES dim.organizationlocation(organizationid, locationid)

select locationid, datacategory, actiontype, eventtoken, count(*)
from fact.deviceevent
GROUP BY locationid, datacategory, actiontype, eventtoken
having count(*) > 1

ALTER TABLE fact.deviceevent 
ADD CONSTRAINT 

ALTER TABLE fact.devicestate 
ADD CONSTRAINT orgid_locationid_fk FOREIGN key (companyId, locationid) REFERENCES dim.organizationlocation(organizationid, locationid)

ALTER TABLE fact.userbehaviour 
ADD CONSTRAINT 

SELECT * FROM fact.occasionsurveydetail as os
WHERE os.orderid not in (select transactionheaderid from fact.transactionheader)

SELECT * FROM dim.location
SELECT * FROM dim.kioskdetails
SELECT * FROM dim.vw_grubbrrinstallbase
SELECT * FROM dim.organizationlocation
SELECT * FROM fact.occasionsurveydetail
SELECT * FROM dim.upsellgrouplookup
SELECT * FROM fact.itemmodifier LIMIT 1000
SELECT * FROM fact.itemssurvey
SELECT locationid, orderid, count(*) FROM fact.usercheckedin GROUP BY locationid, orderid HAVING count(*)>1
SELECT * FROM fact.transactionitem as ti
where ti.transactionheaderid = 'ordevt-nampvshsu6'
SELECT * FROM fact.ordertiming LIMIT 100
SELECT * FROM fact.userbehaviour LIMIT 100
SELECT * FROM fact.vw_offer_analysis as oa
where 1=1 
--and upsellgroupid not in (SELECT upsellgroupid from dim.upsellgrouplookup)
and oa.transactionheaderid = 'ordevt-nampvshsu6'

SELECT * FROM dim.itemcategorymapping;
SELECT *-- organizationid, locationid, count(*)
FROM dim.organizationlocation
GROUP by organizationid, locationid
HAVING count(*)>1

SELECT * 
FROM fact.transactionheader as th
WHERE 1=1
--and th.transactionheaderid = 'ordevt-3saxf1du1j'
--and locationid not in (SELECT id FROM dim.organization)
and not exists(select 1 from dim.kiosk as k WHERE k.locationid = th.locationid and k.kioskid = th.kioskid)
and th.kioskid is not null

SELECT * 
FROM fact.itemssurvey as its
WHERE 1=1
--and th.transactionheaderid = 'ordevt-3saxf1du1j'
--and locationid not in (SELECT id FROM dim.organization)
and its.itemid not in (SELECT menuitemid FROM dim.menuitem)
and not exists(select 1 from dim.kiosk as k WHERE k.locationid = th.locationid and k.kioskid = th.kioskid)
and th.kioskid is not null


SELECT * 
FROM fact.transactionheader
WHERE orderstatus = 'order-placed'
ORDER BY orderdateutc desc
LIMIT 100

SELECT * FROM fact.transactionpayment as tp
--where tp.transactionheaderid not in (select transactionheaderid from fact.transactionheader)
limit 100

SELECT * FROM fact.transactionrefunds as tr

SELECT * FROM fact.itemmodifier as itm--LIMIT 100
WHERE itm.transactionheaderid not in (select transactionheaderid from fact.transactionitem)


SELECT * FROM fact.userbehaviour 
where busdate is not null 
and locationid = 'loc-3068e32c-1da4-40bc-956f-f305a8529bc6'
order by busdate desc LIMIT 100

SELECT * FROM fact.deviceevent as de
where 1=1
--and locationid = 'loc-3068e32c-1da4-40bc-956f-f305a8529bc6'
and not exists (select 1 from dim.organizationlocation as ol where ol.organizationid = de.companyid and ol.locationid = de.locationid)
ORDER BY eventinstant desc 
LIMIT 100

/*******************problem org-loc mapping*************************/
SELECT distinct *--ds.locationid-- ds.companyid, 
FROM fact.devicestate as ds
where 1=1
--and ds.deviceid = 'ksk-76648040'-- not in (SELECT kioskid FROM dim.kiosk)
--and not exists (select 1 from dim.organizationlocation as ol where ol.organizationid = ds.companyid and ol.locationid = ds.locationid)
--and ds.companyid not in (SELECT id from dim.organization)
and ds.locationid = 'loc-e8dc36c2-d850-4218-995a-1b6029ab4300'-- not in (SELECT id from dim.organization) --11,779
ORDER BY lasteventtime desc
LIMIT 100

SELECT * FROM dim.vw_grubbrrinstallbase
WHERE location_id = 'loc-e8dc36c2-d850-4218-995a-1b6029ab4300'

SELECT * FROM fact.devicetelemetry as dt 
where 1=1 --and cputimestamp is not null 
--and not exists (SELECT 1 FROM dim.kiosk as k WHERE k.locationid = dt.locationid and k.kioskid = dt.deviceid)
and dt.locationid not in (SELECT id FROM dim.organization)
ORDER BY cputimestamp desc LIMIT 100

SELECT *
FROM dim.organizationlocation 
WHERE 1=1--organizationid = 'com-usvo6vs4de'
and locationid = 'loc-9dbd4815-f50a-4e4f-ac1d-5fd6d9ec728e'
--com-usvo6vs4de	loc-9dbd4815-f50a-4e4f-ac1d-5fd6d9ec728e


SELECT * FROM dim.element as os
SELECT * FROM dim.occasionsurvey as os
SELECT * FROM fact.usercheckedin
SELECT * /*delete*/ FROM fact.occasionsurveydetail osd
where 1=1 
--and osd.surveyid not in (SELECT osd.surveyid FROM dim.occasionsurvey)
and osd.orderid not in (select transactionheaderid from fact.transactionheader)
order by osd.surveycompletedtimestamp desc;

SELECT * /*delete*/ FROM fact.itemssurvey osd
where 1=1 
--and osd.surveyid not in (SELECT osd.surveyid FROM dim.occasionsurvey)
--and osd.orderid not in (select transactionheaderid from fact.transactionheader)
order by osd.surveycompletedtimestamp desc;

SELECT * FROM fact.itemssurvey as its
where its.surveyid not in (SELECT its.surveyid FROM dim.occasionsurvey)

SELECT * FROM dim.occasionsurvey




SELECT *
FROM information_schema.columns as c
where 1=1
and c.table_schema = 'fact'
and c.table_name like '%transaction%'
and c.column_name like '%%'
ORDER BY c.table_name, c.ordinal_position