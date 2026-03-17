--CREATE SCHEMA if not EXISTS stg

--drop TABLE if EXISTS stg.recommendations;
create TABLE if not EXISTS stg.recommendations (
transactionheaderid character varying(50) COLLATE pg_catalog."default" NOT NULL,
locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
recommendationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
offereditems text,
selecteditems text,
prompttimestamp text,
sysinserttime TIMESTAMP
);

alter table stg.recommendations
--add CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid),
add syscosmosts BIGINT

SELECT * FROM stg.recommendations ORDER by sysinserttime DESC
SELECT * FROM fact.recommendations ORDER by sysinserttime DESC

ALTER TABLE stg.recommendations
OWNER to citus;

ALTER TABLE fact.recommendations
--OWNER to citus;
---add syscosmosts BIGINT
add CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader (locationid, transactionheaderid)



/*UPDATE fact.recommendations
SET syscosmosts = th.syscosmosts
FROM fact.transactionheader as th
WHERE recommendations.locationid = th.locationid
  and recommendations.transactionheaderid = th.transactionheaderid
*/
select transactionheaderid, recommendationid, count(*)
from stg.recommendations
GROUP by transactionheaderid, recommendationid
HAVING count(*) > 1



--drop TABLE if EXISTS fact.recommendations;
create TABLE if not EXISTS fact.recommendations (
transactionheaderid character varying(50) COLLATE pg_catalog."default" NOT NULL,
locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
recommendationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
offereditems jsonb,
selecteditems jsonb,
isconverted boolean,
prompttimestamp text,
sysinserttime TIMESTAMP
);

CREATE table if not exists dim.upsellgrouplookup(
upsellgroupid character varying(50) COLLATE pg_catalog."default" NOT NULL,
upsellgroupname text,
isactive BOOLEAN,
createdon TIMESTAMP,
modifiedon TIMESTAMP
)
TABLESPACE pg_default;

ALTER TABLE dim.upsellgrouplookup
OWNER to citus;

CREATE table if not exists /*drop table dim.itemcategorymapping*/ dim.itemcategorymapping(
categoryid character varying(50) COLLATE pg_catalog."default" NOT NULL,
menuitemid character varying(50) COLLATE pg_catalog."default",
subcategoryid character varying(50) COLLATE pg_catalog."default",
isactive BOOLEAN,
isdeleted BOOLEAN,
modifiedon TIMESTAMP
)
TABLESPACE pg_default;

ALTER TABLE dim.itemcategorymapping
OWNER to citus;

ALTER TABLE dim.upsellgrouplookup
add CONSTRAINT upsellgroupid_pkey PRIMARY KEY (upsellgroupid)

alter table fact.recommendations
add CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid);

ALTER TABLE fact.recommendations
OWNER to citus;

select *--, to_timestamp(syscosmosts)
from fact.recommendations--_bkp
ORDER by sysinserttime DESC
limit 1000


SELECT *, to_timestamp(ts)
from fact.watermarktable

select th.locationid, r.*
from fact.recommendations as r
inner join fact.transactionheader as th 
on r.transactionheaderid = th.transactionheaderid

/*insert into fact.recommendation 
(transactionheaderid, recommendationid, offereditems, selecteditems, prompttimestamp, sysinserttime)
select transactionheaderid, 
       recommendationid, 
       offereditems :: jsonb, 
       selecteditems :: jsonb, 
       prompttimestamp, 
       sysinserttime
from stg.recommendation;*/



select *
from fact.transactionheader as th 
where 1=1
--and th.transactionheaderid = 'ordevt-2x0hox9412'
and th.ordersessionid = 'BBNC86PFT9C15S9P'
and th.locationid = 'loc-db73f0b0-d729-4be3-9fb5-aba6bb78a5f0'
order by th.orderdatelocal desc

SELECT * FROM dim.itemcategorymapping
--cat-4fd20b6a-f966-4252-8a35-0b9ef7198923
--cat-51364bc0-7870-42fc-b2ba-7e569c9facd5
--itm-08ff506f-7ad7-42ef-afc2-34ff71974cfb


select * from fact.vw_offer_analysis --recommendations
where 1=1 --and transactionheaderid in ('ordevt-28f26doa4q')-- 'ordevt-6cgyxdgvye','ordevt-w4wxxiben6','ordevt-xprjkrvx7k','ordevt-zh58tlqdo7')
and locationid = 'loc-a77878ae-b569-42dd-ac01-90d9027233cf'-- 'loc-a8845b12-b118-4c08-bb08-66d1e38957e8'
ORDER BY syscosmosts desc

select * from fact.recommendations --recommendations
where 1=1 --and transactionheaderid in ('ordevt-28f26doa4q')-- 'ordevt-6cgyxdgvye','ordevt-w4wxxiben6','ordevt-xprjkrvx7k','ordevt-zh58tlqdo7')
and locationid = 'loc-a77878ae-b569-42dd-ac01-90d9027233cf'-- 'loc-a8845b12-b118-4c08-bb08-66d1e38957e8'
ORDER BY syscosmosts desc
LIMIT 1000

select DISTINCT ti.upselllevel
from fact.transactionitem as ti

select distinct ti.upselllevel
from fact.transactionitem as ti
where 1=1
and ti.transactionheaderid = 'ordevt-2x0hox9412'


select * from stg.recommendations

select rc.transactionheaderid, 
       rc.locationid,
       rc.recommendationid,
       rc.offereditems,
       rc.selecteditems,
       rc.isconverted,
       rc.prompttimestamp,
       rc.sysinserttime
       --case when (rc.selecteditems = '[]' or rc.selecteditems is null) then false else true end isconverted
from fact.recommendations as rc
where 1=1
--and rc.transactionheaderid = 'ordevt-efp0c8jotp'
--and rc.recommendationid = '4cf9b537-5e52-4d70-9082-059387c30e97'
order by rc.sysinserttime desc, transactionheaderid

select distinct oa.upsellgroupid from fact.vw_offer_analysis as oa
select * from dim.upsellgrouplookup;

--insert into dim.upsellgrouplookup(upsellgroupid) 
select distinct oa.upsellgroupid 
from fact.vw_offer_analysis as oa
where not exists (select 1 from dim.upsellgrouplookup as ul where ul.upsellgroupid = oa.upsellgroupid);

SELECT * FROM fact.vw_offer_analysis --2,433

--TRUNCATE TABLE fact.vw_offer_analysis

CREATE OR REPLACE PROCEDURE fact.usp_offer_analysis()
LANGUAGE sql
AS $BODY$

WITH delta as (
         SELECT * FROM fact.recommendations as rc
         WHERE rc.syscosmosts > (select ts - 10 from fact.watermarktable where watermarktablename = 'fact.recommendations')
           AND not EXISTS (select 1 from fact.vw_offer_analysis as oa where oa.locationid = rc.locationid and oa.transactionheaderid = rc.transactionheaderid)
), rec AS (
         SELECT rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.offereditems,
            rc.prompttimestamp,
            rc.prompttimestamp :: TIMESTAMP as upsellprompttime,
            rc.syscosmosts,
            element.value ->> 'itemId'::text AS offered_itemid,
            element.value ->> 'upsellLevel'::text AS offered_upselllevel,
            element.value ->> 'promptItemId'::text AS offered_prmpid,
            element.value ->> 'upsellGroupId'::text AS offered_upslgrpid
           FROM delta as rc,
            LATERAL jsonb_array_elements(rc.offereditems) element(value)
), selected AS (
         SELECT rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.selecteditems,
            rc.prompttimestamp,
            element.value ->> 'itemId'::text AS selected_itemid,
            element.value ->> 'quantity'::text AS selected_quantity,
            element.value ->> 'upsellLevel'::text AS selected_upselllevel,
            element.value ->> 'promptItemId'::text AS selected_prmpid,
            element.value ->> 'upsellGroupId'::text AS selected_upslgrpid
           FROM delta as rc,
            LATERAL jsonb_array_elements(rc.selecteditems) element(value)
), item_analysis as (
        SELECT r.locationid, 
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid AS offereditem,
            s.selected_itemid AS selecteditem,
                CASE
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'item'::text THEN 'Item Level Upsells'::text
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'order'::text THEN 'Order Level Upsells'::text
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'::text THEN 'Smart Upsells'::text
                    ELSE NULL::text
                END AS upselltype,
            coalesce(s.selected_upslgrpid, r.offered_upslgrpid) AS upsellgroupid,
            ul.upsellgroupname,
                CASE
                    WHEN lower(s.selected_quantity) = ANY (ARRAY['true'::text, '1'::text]) THEN 1
                    ELSE lower(s.selected_quantity)::integer
                END AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            now() as sysinserttime
        FROM (SELECT * FROM rec WHERE rec.offered_itemid like 'itm-%') r
            LEFT JOIN selected s ON r.transactionheaderid::text = s.transactionheaderid::text 
                                AND r.recommendationid::text = s.recommendationid::text 
                                AND r.offered_itemid = s.selected_itemid
            LEFT JOIN dim.upsellgrouplookup ul ON coalesce(s.selected_upslgrpid, r.offered_upslgrpid) = ul.upsellgroupid::text
), category_analysis as (
        SELECT r.locationid, 
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid AS offereditem,
            s.selected_itemid AS selecteditem,
                CASE
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'item'::text THEN 'Item Level Upsells'::text
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'order'::text THEN 'Order Level Upsells'::text
                    WHEN lower(coalesce(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'::text THEN 'Smart Upsells'::text
                    ELSE NULL::text
                END AS upselltype,
            coalesce(s.selected_upslgrpid, r.offered_upslgrpid) AS upsellgroupid,
            ul.upsellgroupname,
                CASE
                    WHEN lower(s.selected_quantity) = ANY (ARRAY['true'::text, '1'::text]) THEN 1
                    ELSE lower(s.selected_quantity)::integer
                END AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            now() as sysinserttime
        FROM (SELECT * FROM rec WHERE rec.offered_itemid like 'cat-%') as r
        INNER join dim.itemcategorymapping as icm 
                on r.offered_itemid = icm.categoryid
        INNER JOIN (SELECT * FROM selected WHERE selected.selected_itemid not in (SELECT offered_itemid FROM rec)) s 
                ON r.transactionheaderid::text = s.transactionheaderid::text 
                AND r.recommendationid::text = s.recommendationid::text 
                AND icm.menuitemid = s.selected_itemid --to determine which offered item is selected
        LEFT JOIN dim.upsellgrouplookup ul ON coalesce(s.selected_upslgrpid, r.offered_upslgrpid) = ul.upsellgroupid::text
), total as (
            SELECT * FROM item_analysis
            UNION
            SELECT * FROM category_analysis
    ) INSERT INTO fact.vw_offer_analysis
      SELECT * FROM total;

    UPDATE fact.watermarktable
    SET ts = rec.maxts
    FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.recommendations' as tablename FROM fact.recommendations) as rec 
    WHERE watermarktable.watermarktablename = rec.tablename;

$BODY$;

ALTER PROCEDURE fact.usp_offer_analysis()
    OWNER TO citus;

SELECT * FROM fact.vw_offer_analysis
order by prompttimestamp desc

SELECT * FROM dim.itemcategorymapping

SELECT jsonb_array_length(selecteditems), *
FROM fact.recommendations
order by jsonb_array_length(selecteditems) desc

SELECT DISTINCT element.value ->> 'itemId'::text AS offered_itemid
FROM fact.recommendations rc,
LATERAL jsonb_array_elements(rc.offereditems) element(value)
WHERE element.value ->> 'itemId'::text like 'cat-%'


select * 
from fact.vw_offer_analysis as oa
where 1=1 
--and oa.transactionheaderid in ('ordevt-28d8v3b03b')--,'ordevt-aoclhnqf17','ordevt-b4a9cicfrq','ordevt-ow4pr4i6pw')
and oa.offereditem like 'cat-%'
limit 100;

SELECT DISTINCT oa.offereditem as categoryid
FROM fact.vw_offer_analysis as oa
WHERE 1=1 
AND oa.offereditem like 'cat-%'

SELECT * from dim.itemcategorymapping

select * 
from fact.recommendations as r
where 1=1 
--and r.transactionheaderid in ('ordevt-28d8v3b03b')--,'ordevt-aoclhnqf17','ordevt-b4a9cicfrq','ordevt-ow4pr4i6pw')
--and r.offereditems :: text like '%"cat-20b466fb-8605-4817-8617-02f91a5dde30%'
order by prompttimestamp desc
limit 100;
--cat-20b466fb-8605-4817-8617-02f91a5dde30 --itm-ac3e05b8-4d03-4de0-afc5-b142abed5883
--cat-03284fc5-285b-4f09-a13e-c417af5f125b

select * from dim.upsellgrouplookup
select lower('NATE')

insert into fact.recommendations 
(transactionheaderid, locationid, recommendationid, offereditems, selecteditems, isconverted, prompttimestamp, sysinserttime)
select rc.transactionheaderid,
       rc.locationid,
       rc.recommendationid, 
       rc.offereditems :: jsonb, 
       rc.selecteditems :: jsonb, 
       case when (rc.selecteditems = '[]' or rc.selecteditems is null) then false else true end as isconverted,
       rc.prompttimestamp, 
       rc.sysinserttime
from stg.recommendations as rc
where not exists (select 1 from fact.recommendations as th where th.transactionheaderid = rc.transactionheaderid and th.recommendationid = rc.recommendationid);

insert into dim.upsellgrouplookup(upsellgroupid) 
select distinct oa.upsellgroupid 
from fact.vw_offer_analysis as oa
where not exists (select 1 from dim.upsellgrouplookup as ul where ul.upsellgroupid = oa.upsellgroupid);


select oa.offereditem, 
       mi.menuitemname,
       count(*) as x_times_offered,
       count(oa.selecteditem) as x_times_selected,
       sum(oa.quantity) as qty_selected
from fact.vw_offer_analysis as oa
left join dim.menuitem as mi 
       on oa.offereditem = mi.menuitemid
group by oa.offereditem, mi.menuitemname

select *-- distinct ti.dimmenuitemid -- ti.transactionheaderid-- 
from fact.transactionitem as ti
where ti.dimmenuitemid not in 
(select distinct menuitemid from dim.menuitem)

select * 
from fact.vw_offer_analysis as oa
where oa.transactionheaderid = 'ordevt-11t4ay6jzu'
limit 100;

select *
from fact.transactionitem as ti
where ti.transactionheaderid in ('ordevt-gk98r6u2tb','ordevt-s6st61wucj');

select distinct ol.organizationid,
       ol.organizationname,
       ol.locationid,
       ol.locationname,
       oa.transactionheaderid,
       mi.menuitemname,
       oa.upselltype AS upsellLevel,
       count(oa.selecteditem) AS x_item_selected,
       count(*) AS x_items_offered,
       sum(oa.quantity) AS qty_selected,
       th.ordertotal,
       th.ordersubtotal,
CASE
	WHEN SUM(oa.quantity) IS NULL OR SUM(oa.quantity) = 0 THEN 0
	ELSE COALESCE(ti.itemunitprice, 0)
END AS itemunitprice
FROM fact.vw_offer_analysis AS oa
       inner join (select * from dim.organizationlocation where organizationtype = 0 and organizationid = 'org-21b9c258-ad27-4aab-8663-4d480c235950') as ol
               on oa.locationid = ol.locationid

	INNER JOIN dim.menuitem AS mi
		 ON oa.offereditem  = mi.menuitemid
	INNER JOIN fact.transactionheader AS th
		 ON oa.transactionheaderid = th.transactionheaderid
	INNER JOIN fact.transactionitem AS ti
		 ON ti.transactionheaderid = oa.transactionheaderid
              AND ti.dimmenuitemid = oa.offereditem
		AND ti.upselllevel IS NOT NULL
WHERE 1=1
--and th.transactionheaderid = 'ordevt-11t4ay6jzu'-- 'ordevt-ubmqwb3mdl'
and th.locationid in (select locationid from dim.organizationlocation where organizationtype = 0 and organizationid = 'org-21b9c258-ad27-4aab-8663-4d480c235950')
GROUP BY
oa.offereditem,
mi.menuitemname,
oa.upselltype,
th.ordersubtotal,
th.ordertotal,
th.ordersubtotal,
COALESCE(ti.itemunitprice, 0);



select distinct vw.offereditem
from fact.vw_offer_analysis as vw
where vw.offereditem not like 'cat-%'
and vw.offereditem not in 
(select distinct menuitemid from dim.menuitem)

select distinct vw.offereditem
from fact.vw_offer_analysis as vw
where vw.offereditem like 'cat-%'
and vw.offereditem not in 
(select distinct categoryid from dim.itemcategory)

select distinct ol.organizationid,
       ol.organizationname,
       ol.locationid,
       ol.locationname,
       oa.transactionheaderid,
       mi.menuitemname,
       oa.selecteditem as menuitemid,
       oa.upselltype,
       oa.upsellgroupid,
       oa.upsellgroupname,
       oa.quantity,
       ti.itemunitprice,
       oa.prompttimestamp :: TIMESTAMP as prompttimestamp,
       th.businessdate
from fact.vw_offer_analysis as oa 
inner join (select * from dim.organizationlocation where organizationtype = 0 and organizationid = 'org-21b9c258-ad27-4aab-8663-4d480c235950') as ol
        on oa.locationid = ol.locationid
inner join dim.menuitem as mi 
        on oa.offereditem = mi.menuitemid
INNER JOIN fact.transactionheader AS th
	 ON oa.transactionheaderid = th.transactionheaderid
inner join fact.transactionitem as ti 
	 ON ti.transactionheaderid = oa.transactionheaderid
       AND ti.dimmenuitemid = oa.offereditem
	AND ti.upselllevel IS NOT NULL
where 1=1
and oa.prompttimestamp :: date between '2025-02-15' :: date and CURRENT_DATE :: date
and oa.selecteditem is not null
--and th.transactionheaderid = 'ordevt-11t4ay6jzu'-- 'ordevt-ubmqwb3mdl'
--and locationid in (select locationid from dim.organizationlocation where organizationtype = 0 and organizationid = 'org-21b9c258-ad27-4aab-8663-4d480c235950')
order by prompttimestamp DESC

--ordevt-gk98r6u2tb	Red Pepper Shaker	itm-a8bc1232-3648-4ed1-8796-fb677b093877	Item Level Upsells	upslg-c27e3b17-8b99-48eb-8048-6c1d8adda296	Item Upsell	       1	2025-07-24 00:36:50
--ordevt-s6st61wucj	Cheese Sticks	       itm-a6b8e1d0-92ca-409b-91e4-0a5fafe094e5	Order Level Upsells	upslg-cf03a6cf-553d-47ec-8def-7fe720d6e86f	Order Level Upsell	1	2025-07-24 00:16:16

select distinct ol.organizationid,
       ol.organizationname,
       ol.locationid,
       ol.locationname,
       th.businessdate,
       mi.menuitemname,
       ti.itemquantity,
       ti.itemunitprice,
       ti.upselllevel,
       th.orderdatelocal
from fact.transactionitem as ti
INNER JOIN fact.transactionheader AS th
	 ON ti.transactionheaderid = th.transactionheaderid
inner join dim.menuitem as mi 
        on ti.dimmenuitemid = mi.menuitemid
inner join (select * from dim.organizationlocation where organizationtype = 0 and organizationid = 'org-21b9c258-ad27-4aab-8663-4d480c235950') as ol
        on th.locationid = ol.locationid
where 1=1
and ti.upselllevel is not null and ti.upselllevel <> ''
and th.businessdate :: date between '2025-02-15' :: date and CURRENT_DATE :: date
order by th.businessdate desc;

select *
from fact.transactionitem as ti
where ti.transactionheaderid in ('ordevt-gk98r6u2tb','ordevt-s6st61wucj');


select * from dim.organizationlocation where organizationtype = 0
select * from dim.menuitem

select rc.transactionheaderid, 
       rc.recommendationid,
       rc.offereditems,
       rc.prompttimestamp,
       element ->> 'itemId' as offered_itemid,
       element ->> 'upsellLevel' as offered_upselllevel,
       element ->> 'promptItemId' as offered_prmpid,
       element ->> 'upsellGroupId' as offered_upslgrpid
from fact.recommendations as rc,
jsonb_array_elements(rc.offereditems) AS element
where 1=1
and rc.transactionheaderid = 'ordevt-efp0c8jotp'
and rc.recommendationid = '4cf9b537-5e52-4d70-9082-059387c30e97'
order by transactionheaderid

select rc.transactionheaderid, 
       rc.recommendationid,
       rc.selecteditems,
       element ->> 'itemId' as selected_itemid,
       element ->> 'upsellLevel' as selected_upselllevel,
       element ->> 'promptItemId' as selected_prmpid,
       element ->> 'upsellGroupId' as selected_upslgrpid
from fact.recommendation as rc,
jsonb_array_elements(rc.selecteditems) AS element
where 1=1
and rc.transactionheaderid = 'ordevt-efp0c8jotp'
and rc.recommendationid = '4cf9b537-5e52-4d70-9082-059387c30e97'
order by transactionheaderid


--insert into fact.recommendations 
(transactionheaderid, locationid, recommendationid, offereditems, selecteditems, isconverted, prompttimestamp, sysinserttime)
select rc.transactionheaderid,
       rc.locationid,
       rc.recommendationid, 
       rc.offereditems :: jsonb, 
       rc.selecteditems :: jsonb, 
       case when (rc.selecteditems = '[]' or rc.selecteditems is null) then false else true end as isconverted,
       rc.prompttimestamp, 
       rc.sysinserttime
from stg.recommendations as rc;

--insert into dim.upsellgrouplookup(upsellgroupid) 
select distinct oa.upsellgroupid 
from fact.vw_offer_analysis as oa
where not exists (select 1 from dim.upsellgrouplookup as ul where ul.upsellgroupid = oa.upsellgroupid);

select 1 as rn;