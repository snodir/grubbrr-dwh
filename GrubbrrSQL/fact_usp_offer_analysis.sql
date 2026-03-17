SELECT *-- wt.watermarktablename, wt.watermarkcolumn, wt.watermarkvalue, wt.ticks, wt.ts
from citus.fact.watermarktable as wt;
--1755036781 14:05
UPDATE fact.watermarktable
SET ts = 1500000010-- tr.maxts
--FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.recommendations' as tablename FROM fact.transactionrefunds) as tr 
WHERE watermarktable.watermarktablename = 'fact.recommendations';-- tr.tablename;

SELECT * 
FROM fact.vw_offer_analysis
--WHERE offereditem like 'cat-%' and selecteditem is not NULL
ORDER by upsellprompttime desc
LIMIT 1000

SELECT * 
FROM fact.recommendations
WHERE transactionheaderid like 'ordevt-w6p1m6wnr9'
ORDER by prompttimestamp desc
LIMIT 1000

--truncate table fact.recommendations

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



--call fact.usp_offer_analysis();
SELECT 1 as rn;


SELECT oa.locationid, oa.transactionheaderid, oa.recommendationid, oa.offereditem, oa.selecteditem, mi.menuitemname, oa.upselltype, oa.upsellgroupname, oa.upsellprompttime
FROM fact.vw_offer_analysis as oa
INNER JOIN dim.menuitem as mi 
ON oa.selecteditem = mi.menuitemid
WHERE 1=1
AND oa.transactionheaderid = 'ordevt-28f26doa4q'
AND oa.upsellprompttime :: date = '2025-08-20'
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

CREATE table if not EXISTS /*DROP VIEW fact.vw_offer_analysis*/ fact.vw_offer_analysis (
locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
transactionheaderid character varying(50) COLLATE pg_catalog."default" NOT NULL,
recommendationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
offereditem character varying(50) COLLATE pg_catalog."default" NOT NULL,
selecteditem character varying(50) COLLATE pg_catalog."default",
upselltype character varying(50) COLLATE pg_catalog."default",
upsellgroupid character varying(50) COLLATE pg_catalog."default",
upsellgroupname text COLLATE pg_catalog."default",
quantity INTEGER,
prompttimestamp text,
upsellprompttime TIMESTAMP,
syscosmosts BIGINT,
sysinserttime TIMESTAMP
)
TABLESPACE pg_default;

ALTER TABLE fact.vw_offer_analysis
OWNER to citus;

ALTER TABLE fact.vw_offer_analysis
add CONSTRAINT trxnid_recommendationid_itemid_uidx UNIQUE (transactionheaderid, recommendationid, offereditem);
ADD CONSTRAINT locationid_trxnid_recommendationid_fk FOREIGN KEY (locationid, transactionheaderid, recommendationid) REFERENCES fact.recommendations(locationid, transactionheaderid, recommendationid)

ALTER TABLE fact.recommendations
ADD CONSTRAINT locationid_trxnid_recommendationid_pk PRIMARY KEY (locationid, transactionheaderid, recommendationid)

ALTER TABLE fact.recommendations
--OWNER to citus;
---add syscosmosts BIGINT
add CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid) REFERENCES fact.transactionheader (locationid, transactionheaderid)

SELECT * FROM fact.vw_offer_analysis

CREATE INDEX IF NOT EXISTS locationid_idx
    ON fact.vw_offer_analysis USING btree
    (locationid COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

--INSERT INTO fact.vw_offer_analysis
--drop table fact.offer_analysis
SELECT * FROM fact.offer_analysis

--DROP VIEW fact.vw_offer_analysis

SELECT * FROM fact.vw_offer_analysis as oa
ORDER BY oa.upsellprompttime DESC
LIMIT 1000