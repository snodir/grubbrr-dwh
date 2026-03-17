SELECT ol.organizationname, ol.locationname, cmp.frequentcustomerid, cmp.day_parts, 
       cmp.itemid, mi.menuitemname, cmp.itemtype, cmp.item_selection_frequency
FROM fact.customer_menu_preferences as cmp
LEFT JOIN dim.menuitem as mi 
       ON cmp.itemid = mi.menuitemid
LEFT JOIN (SELECT * FROM dim.organizationlocation as ol WHERE ol.organizationtype = 0) as ol 
       ON cmp.organizationid = ol.organizationid
      AND cmp.locationid = ol.locationid
ORDER BY frequentcustomerid, cmp.day_parts, item_selection_frequency desc;

CALL fact.usp_customer_menu_preferences();

CREATE OR REPLACE PROCEDURE fact.usp_customer_menu_preferences()
LANGUAGE sql
AS $BODY$

TRUNCATE TABLE fact.customer_menu_preferences;

WITH part as (
    SELECT * 
    FROM fact.transactionheader as th
    WHERE 1=1--th.locationid = 'loc-637638f7-ef71-4416-85c3-dd63bb25f77d'
      --AND th.businessdate >= '2025-04-01'
      AND th.orderstatus = 'order-placed'
      AND th.frequentcustomerid is not null
), dayparts AS (
    SELECT th.frequentcustomerid, ti.transactionheaderid, ti.itemid, ti.locationid, th.orderdatelocal,
        CASE WHEN ti.itemtype = 'item' AND ti.dimmenuitemid is not null THEN ti.dimmenuitemid
             WHEN ti.itemtype <> 'item' AND ti.comboid is not null THEN ti.comboid end as dimmenuitemid,
        CASE 
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 6 AND 10  THEN 'Breakfast'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 11 AND 13 THEN 'Lunch'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 14 AND 16 THEN 'Afternoon/Snack'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 17 AND 20 THEN 'Dinner'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) >= 21 OR EXTRACT(HOUR FROM th.orderdatelocal) < 6 THEN 'Late Night'
        END AS day_parts,
        'All Day' as all_day        
    FROM part as th
    inner JOIN fact.transactionitem as ti 
            ON th.transactionheaderid = ti.transactionheaderid
           AND th.locationid = ti.locationid
    WHERE (ti.itemtype = 'item' AND ti.dimmenuitemid is not null)
       OR (ti.itemtype <> 'item' AND ti.comboid is not null)
), agg_dayparts as (
    SELECT locationid,
           frequentcustomerid, 
           day_parts, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, frequentcustomerid, day_parts, dimmenuitemid--, itemtype
), agg_all_day as (
    SELECT locationid,
           frequentcustomerid, 
           all_day, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, frequentcustomerid, all_day, dimmenuitemid--, itemtype
), Ranked1 AS (
    SELECT 
        fc.organizationid as fc_organizationid,
        --ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.frequentcustomerid,
        agg.day_parts,
        agg.itemid,
        it.ItemType,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.frequentcustomerid, agg.day_parts ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_dayparts as agg
    INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), Ranked2 AS (
    SELECT 
        fc.organizationid as fc_organizationid,
        --ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.frequentcustomerid,
        agg.all_day,
        agg.itemid,
        it.ItemType,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.frequentcustomerid, agg.all_day ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_all_day as agg
    INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), total as (
SELECT fc_organizationid as organizationid,
       --ol_organizationid,
       locationid,
       frequentcustomerid,
       day_parts,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked1 WHERE rn <= 10
UNION --all
SELECT fc_organizationid as organizationid,
       --ol_organizationid,
       locationid,
       frequentcustomerid,
       all_day,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked2 WHERE rn <= 10
--ORDER BY item_selection_frequency desc;
)
INSERT INTO fact.customer_menu_preferences
SELECT * from total
--WHERE fc_organizationid <> ol_organizationid
--ORDER BY frequentcustomerid


$BODY$;

/*
CREATE TABLE if not EXISTS /*truncate table*/ fact.customer_menu_preferences(
organizationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
frequentcustomerid character varying(50) COLLATE pg_catalog."default" NOT NULL,
day_parts character varying(20) COLLATE pg_catalog."default" NOT NULL,
itemid character varying(50) COLLATE pg_catalog."default",
itemtype character varying(50) COLLATE pg_catalog."default",
item_selection_frequency INTEGER,
itemtags jsonb,
sysinserttime TIMESTAMP
)
TABLESPACE pg_default;

ALTER TABLE fact.customer_menu_preferences
OWNER to citus
*/