SELECT *
FROM dim.menuentities

ALTER TABLE dim.menuitem --DROP COLUMN sysinserttime, DROP COLUMN sysupdatetime
ADD COLUMN IF NOT EXISTS itemunitprice NUMERIC(12, 3),
--ALTER COLUMN itemunitprice TYPE NUMERIC(12, 3),
ADD COLUMN IF NOT EXISTS price_changed_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP,
ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP,
ADD COLUMN IF NOT EXISTS catalogid text COLLATE pg_catalog."default";

SELECT count(*) --, max(gms_created_on) gms_created_on, max(gms_modified_on) 
FROM dim.menuitem --10,637/154,505
WHERE 1=1-- calories <> ''
AND sysupdatetime IS NOT NULL
ORDER BY id DESC
LIMIT 1000

SELECT count(*) --, max(gms_created_on) gms_created_on, max(gms_modified_on) 
FROM dim.category_hierarchy --/87,366/195,903

SELECT count(*) --, max(gms_created_on) gms_created_on, max(gms_modified_on) 
FROM dim.duplicate_items_master --44,297/143,538


SELECT *, lower(hch.menuitemname) as lowercase_menuitem,
       count(*) OVER(PARTITION BY hch.locationid, hch.categoryid, lower(hch.menuitemname)) as dupl
FROM dim.category_hierarchy as hch
--INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
--        ON hch.locationid = ol.locationid
--GROUP BY hch.locationid, ol.locationname, hch.categoryid, lower(menuitemname)
WHERE hch.menuitemid = 'itm-04d5e110-f73a-487f-bb75-054fe07d21bf'
ORDER BY dupl DESC, lower(hch.menuitemname)

--TRUNCATE table dim.category_hierarchy;

SELECT lower(mi.menuitemname) as menuitemname, count(*) as dupl
FROM dim.menuitem as mi
GROUP BY lower(mi.menuitemname)
HAVING count(*) > 1
ORDER BY dupl DESC


SELECT hch.locationid, ol.locationname, hch.categoryid,
       lower(menuitemname), count(*) as dupl
FROM dim.category_hierarchy as hch
INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
        ON hch.locationid = ol.locationid
GROUP BY hch.locationid, ol.locationname, hch.categoryid, lower(menuitemname)
HAVING count(*) > 1
ORDER BY dupl DESC;

SELECT dim.organizationid,
	   ol.organizationname,
	   dim.locationid,
	   ol.locationname,
	   dim.categoryid,
	   dim.categoryname,
	   dim.menuitemid,
	   dim.entitytype,
	   dim.item_class_type,
	   dim.menuitemname,
	   dim.instance_count,
	   dim.masteritemid
FROM dim.duplicate_items_master as dim
INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
		ON dim.locationid = ol.locationid
WHERE (CASE WHEN '@{pipeline().parameters.p_orgid}' NOT LIKE 'loc-%' THEN organizationid ELSE locationid END) = '@{pipeline().parameters.p_orgid}'


-- PROCEDURE: dim.usp_master_keys_for_duplicate_items()

-- DROP PROCEDURE IF EXISTS dim.usp_master_keys_for_duplicate_items();

-- CALL dim.usp_master_keys_for_duplicate_items();

CREATE OR REPLACE PROCEDURE dim.usp_master_keys_for_duplicate_items(
	)
LANGUAGE 'plpgsql'
AS $BODY$

BEGIN

WITH duplicate_items AS (
    SELECT *, 
           count(*) over(PARTITION BY locationid, trim(lower(menuitemname))) as dupl
    FROM dim.category_hierarchy
)
INSERT INTO dim.duplicate_items_master (
    organizationid,
    locationid,
    categoryid,
    categoryname,
    menuitemid,
    entitytype,
    item_class_type,
    menuitemname,
    sysinserttime
)
SELECT organizationid,
       locationid,
       categoryid,
       categoryname,
       menuitemid,
       entitytype,
       item_class_type,
       menuitemname,
       now()::TIMESTAMP
FROM duplicate_items di
WHERE dupl > 1
  AND NOT EXISTS (
        SELECT 1 
        FROM dim.duplicate_items_master as dim
        WHERE dim.locationid = di.locationid
          AND dim.categoryid = di.categoryid
          AND dim.menuitemid = di.menuitemid
  );

WITH item_counts AS (
    SELECT locationid, dimmenuitemid, count(*) AS instance_count
    FROM fact.transactionitem
	WHERE transactionheaderid like 'ordevt-%'
    GROUP BY locationid, dimmenuitemid
)
UPDATE dim.duplicate_items_master dim
SET instance_count = ic.instance_count,
    sysupdatetime  = now()::TIMESTAMP
FROM item_counts ic
WHERE dim.locationid = ic.locationid
  AND dim.menuitemid = ic.dimmenuitemid;

UPDATE dim.duplicate_items_master dim
SET masteritemid = concat('mstritm-', uuid_generate_v5(uuid_ns_dns(), concat(dim.locationid, ':', trim(lower(dim.menuitemname))))),
	sysupdatetime  = now()::TIMESTAMP
WHERE dim.masteritemid IS NULL;


END;
$BODY$;
ALTER PROCEDURE dim.usp_master_keys_for_duplicate_items()
    OWNER TO citus;


SELECT *
FROM dim.category_hierarchy as hch
where hch.locationid = 'loc-8hoaq5xop1'

SELECT * 
FROM information_schema.columns as isc 
WHERE isc.table_name = 'menuentities'

--drop TABLE IF EXISTS dim.category_hierarchy;
CREATE TABLE IF NOT EXISTS dim.category_hierarchy
(
id BIGINT,
organizationid TEXT COLLATE pg_catalog."default",
locationid text COLLATE pg_catalog."default" NOT NULL,
mapping_created_on TIMESTAMP, 
mapping_modified_on TIMESTAMP,
is_mapping_active BOOLEAN, 
is_mapping_deleted BOOLEAN, 
catalogid TEXT COLLATE pg_catalog."default",
catalogname TEXT COLLATE pg_catalog."default",
catalog_created_on TIMESTAMP,
catalog_modified_on TIMESTAMP,
is_catalog_active BOOLEAN,
is_catalog_deleted BOOLEAN,
categoryid text COLLATE pg_catalog."default" NOT NULL,
categoryname text COLLATE pg_catalog."default",
category_created_on TIMESTAMP,
category_modified_on TIMESTAMP,
is_category_active BOOLEAN,
is_category_deleted BOOLEAN,
menuitemid TEXT COLLATE pg_catalog."default",
entitytype TEXT COLLATE pg_catalog."default",
item_class_type INTEGER,
menuitemname TEXT COLLATE pg_catalog."default",
item_created_on TIMESTAMP,
item_modified_on TIMESTAMP,
is_item_active BOOLEAN,
is_item_deleted BOOLEAN,
syscosmosts BIGINT,
sysinserttime TIMESTAMP,
sysupdatetime TIMESTAMP
)

TABLESPACE pg_default;

ALTER TABLE dim.category_hierarchy
    OWNER to citus;

CREATE TABLE IF NOT EXISTS dim.duplicate_items_master
(
organizationid TEXT COLLATE pg_catalog."default",
locationid text COLLATE pg_catalog."default" NOT NULL,
categoryid text COLLATE pg_catalog."default" NOT NULL,
categoryname text COLLATE pg_catalog."default",
menuitemid TEXT COLLATE pg_catalog."default",
entitytype TEXT COLLATE pg_catalog."default",
item_class_type INTEGER,
menuitemname TEXT COLLATE pg_catalog."default",
instance_count INTEGER,
masteritemid TEXT COLLATE pg_catalog."default",
sysinserttime TIMESTAMP,
sysupdatetime TIMESTAMP
)

TABLESPACE pg_default;

ALTER TABLE dim.duplicate_items_master
    OWNER to citus;


ALTER TABLE dim.category_hierarchy
--ADD CONSTRAINT category_hierarchy_pkey PRIMARY KEY (id),
--ADD CONSTRAINT location_category_menuitemid_unq UNIQUE (locationid, categoryid, menuitemid);
ADD COLUMN IF NOT EXISTS organizationid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS catalogid TEXT COLLATE pg_catalog."default";
ADD COLUMN IF NOT EXISTS catalogname TEXT COLLATE pg_catalog."default";
ADD COLUMN IF NOT EXISTS catalog_created_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS catalog_modified_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS is_catalog_active BOOLEAN,
ADD COLUMN IF NOT EXISTS is_catalog_deleted BOOLEAN,
ADD COLUMN IF NOT EXISTS category_created_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS category_modified_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS is_category_active BOOLEAN,
ADD COLUMN IF NOT EXISTS is_category_deleted BOOLEAN,
ADD COLUMN IF NOT EXISTS item_created_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS item_modified_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS is_item_active BOOLEAN,
ADD COLUMN IF NOT EXISTS is_item_deleted BOOLEAN,

SELECT *, count(*) over(PARTITION BY menuitemid) as count_by_items --count(*)-- 
FROM dim.category_hierarchy
WHERE 1=1
AND organizationid IS NOT NULL --2,070
AND syscosmosts IS NOT NULL
ORDER BY count_by_items DESC, menuitemid
LIMIT 1000

ALTER TABLE dim.itemcategorymapping
--ADD COLUMN IF NOT EXISTS organizationid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS locationid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS categoryid TEXT COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS item_class_type INTEGER

ALTER TABLE dim.menuitem
ADD COLUMN IF NOT EXISTS entitytype text COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS calories text COLLATE pg_catalog."default",
ADD COLUMN IF NOT EXISTS protein numeric,
ADD COLUMN IF NOT EXISTS sugar numeric,
ADD COLUMN IF NOT EXISTS fat numeric,
ADD COLUMN IF NOT EXISTS is_alcoholic BOOLEAN,
ADD COLUMN IF NOT EXISTS is_vegetarian_item BOOLEAN,
ADD COLUMN IF NOT EXISTS is_vegan_item BOOLEAN,
ADD COLUMN IF NOT EXISTS has_allergen BOOLEAN,
ADD COLUMN IF NOT EXISTS is_active BOOLEAN,
ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN,
ADD COLUMN IF NOT EXISTS gms_created_on TIMESTAMP,
ADD COLUMN IF NOT EXISTS gms_modified_on TIMESTAMP


ALTER TABLE fact.transactionitem
ADD COLUMN IF NOT EXISTS orderdatelocal TIMESTAMP,
ADD COLUMN IF NOT EXISTS businessdate DATE;

SELECT *
FROM fact.transactionitem as ti
WHERE 1=1
  AND ti.locationid IN (SELECT DISTINCT ol.locationid 
                            FROM dim.organizationlocation AS ol
                            WHERE (CASE WHEN 'org-a4b81610-f019-45d2-8522-2ccee0e85bd7' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'org-a4b81610-f019-45d2-8522-2ccee0e85bd7'
                            AND ol.organizationtype = 0
                           )
  AND LOWER(ti.transactionheaderid) like 'ordevt-%'
  AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = 2025
  AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = 43


SELECT * FROM fact.transactionitem as ti
where ti.comboid is not null
LIMIT 1000

WITH order_items AS (
SELECT * FROM fact.transactionitem as ti
    WHERE ti.locationid IN (SELECT DISTINCT ol.locationid 
                            FROM dim.organizationlocation AS ol
                            WHERE (CASE WHEN '{$pdf_orgid}' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = '{$pdf_orgid}'
                            AND ol.organizationtype = 0
                           )
      AND LOWER(ti.transactionheaderid) like 'ordevt-%'
      AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = {$pdf_yyyy}
      AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = {$pdf_ww}
)
SELECT DISTINCT ol.organizationid, ol.organizationname, ti.locationid, ol.locationname,
        ic.categoryid, ic.categoryname, 
       mi.menuitemid, ti.itemunitprice, mi.menuitemname, mi.item_class_type, 
       mi.entitytype, mi.calories, mi.protein, mi.sugar, mi.fat, mi.is_alcoholic,
       mi.is_vegetarian_item, mi.is_vegan_item, mi.has_allergen
FROM order_items as ti 
INNER JOIN dim.menuitem as mi
        ON ti.menuitemid = mi.id
INNER JOIN dim.itemcategory as ic 
        ON ti.categoryid = ic.id
INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
        ON ti.locationid = ol.locationid

SELECT *
FROM dim.itemcategorymapping

UPDATE fact.transactionitem
   SET orderdatelocal = th.orderdatelocal,
       businessdate = th.businessdate
FROM fact.transactionheader as th 
WHERE transactionitem.locationid = th.locationid
  AND transactionitem.transactionheaderid = th.transactionheaderid
  AND (transactionitem.orderdatelocal IS NULL OR transactionitem.businessdate IS NULL)



--File: Menu Entities V1 (Item-level, weekly snapshot, All levels of hierarchy starting from Org to Item(most granular)
--File hierarchy: ml-training-data/org-abcd/menu-entities-yyww-00001.parquet
WITH order_items AS (
    SELECT *
    FROM fact.transactionitem AS ti
    WHERE ti.locationid IN (
        SELECT DISTINCT ol.locationid
        FROM dim.organizationlocation AS ol
        WHERE (
            CASE WHEN 'com-3owh66znkd' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END
        ) = 'com-3owh66znkd'
          AND ol.organizationtype = 0
    )
      AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
      AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = 2025
      AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = 50
)
SELECT DISTINCT
    ol.organizationid,
    ol.organizationname,
    ti.locationid,
    ti.businessdate,
    EXTRACT(YEAR FROM ti.businessdate)::INTEGER AS yyyy,
    EXTRACT(WEEK FROM ti.businessdate)::INTEGER AS ww,
    ol.locationname,
    ic.categoryid,
    ic.categoryname,
    mi.menuitemid,
    ti.itemunitprice AS unitprice,
    mi.menuitemname,
    mi.item_class_type,
    mi.entitytype,
    mi.calories,
    mi.protein,
    mi.sugar,
    mi.fat,
    mi.is_alcoholic,
    mi.is_vegetarian_item,
    mi.is_vegan_item,
    mi.has_allergen
FROM order_items AS ti
INNER JOIN dim.menuitem AS mi
    ON ti.menuitemid = mi.id
INNER JOIN dim.itemcategory AS ic
    ON ti.categoryid = ic.id
INNER JOIN (
    SELECT *
    FROM dim.organizationlocation
    WHERE organizationtype = 0
) AS ol
    ON ti.locationid = ol.locationid;

--File: Menu Entities V2 (Item-level, weekly snapshot, All levels of hierarchy starting from Org to Item(most granular)
--File hierarchy: ml-training-data/org-abcd/menu-entities-yyww-00001.parquet
WITH order_items AS (
    SELECT ti.*, ic.categoryid as dimcategoryid, ic.categoryname
    FROM (  SELECT *
            FROM fact.transactionitem AS ti
            WHERE ti.locationid IN (
                SELECT DISTINCT ol.locationid
                FROM dim.organizationlocation AS ol
                WHERE (
                    CASE WHEN 'com-3owh66znkd' NOT LIKE 'loc-%' THEN ol.organizationid  ELSE ol.locationid END
                ) = 'com-3owh66znkd'
                AND ol.organizationtype = 0
                )
            AND LOWER(ti.transactionheaderid) LIKE 'ordevt-%'
            AND EXTRACT(YEAR FROM ti.businessdate)::INTEGER = 2025
            AND EXTRACT(WEEK FROM ti.businessdate)::INTEGER = 50
    ) as ti
    INNER JOIN dim.itemcategory as ic 
            ON ti.categoryid = ic.id
), category_hierarchy AS (
    SELECT mi.*, ctgh.locationid, ctgh.categoryid, ctgh.categoryname
    FROM dim.menuitem as mi 
    INNER JOIN dim.category_hierarchy as ctgh 
    ON mi.menuitemid = ctgh.menuitemid
    WHERE ctgh.locationid IN (
        SELECT DISTINCT ol.locationid
        FROM dim.organizationlocation AS ol
        WHERE (
            CASE WHEN 'com-3owh66znkd' NOT LIKE 'loc-%' THEN ol.organizationid  ELSE ol.locationid END
        ) = 'com-3owh66znkd')
    AND (    (EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER <= 2025
          AND EXTRACT(YEAR FROM mi.gms_created_on)::INTEGER <= 50
          AND mi.is_active = True AND mi.is_deleted = False) 
        OR   (EXTRACT(YEAR FROM mi.gms_modified_on)::INTEGER >= 2025
          AND EXTRACT(YEAR FROM mi.gms_modified_on)::INTEGER > 50)
        OR mi.gms_modified_on IS NULL
        )
)
SELECT DISTINCT
    ol.organizationid,
    ol.organizationname,
    COALESCE(mi.locationid, ti.locationid) as locationid,
    ti.businessdate,
    2025::INTEGER AS yyyy,
    50::INTEGER AS ww,
    ol.locationname,
    COALESCE(mi.categoryid, ti.dimcategoryid) as categoryid,
    COALESCE(mi.categoryname, ti.categoryname) as categoryname,
    COALESCE(mi.menuitemid, ti.dimmenuitemid) as menuitemid,
    ti.itemunitprice AS unitprice,
    COALESCE(mi.menuitemname, ti.itemname) as menuitemname,
    mi.item_class_type,
    mi.entitytype,
    mi.calories,
    mi.protein,
    mi.sugar,
    mi.fat,
    mi.is_alcoholic,
    mi.is_vegetarian_item,
    mi.is_vegan_item,
    mi.has_allergen
FROM category_hierarchy as mi 
LEFT JOIN order_items AS ti
    ON mi.id = ti.menuitemid AND mi.categoryid = ti.dimcategoryid
LEFT JOIN (
    SELECT *
    FROM dim.organizationlocation
    WHERE organizationtype = 0
) AS ol
    ON mi.locationid = ol.locationid;