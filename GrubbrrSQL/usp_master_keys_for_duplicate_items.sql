SELECT * FROM fact.transactionitem as ti 
WHERE ti.transactionheaderid like 'ordevt-%' 
ORDER BY ti.orderdatelocal DESC
LIMIT 1000

-- PROCEDURE: dim.usp_master_keys_for_duplicate_items()

--CALL dim.usp_master_keys_for_duplicate_items(); --12s
--CALL fact.usp_location_statistics(); --32s
--CALL ml.usp_refresh_item_modifiergroup_modifier_mapping();

SELECT 1 AS rn;

-- DROP PROCEDURE IF EXISTS dim.usp_master_keys_for_duplicate_items();
-- SELECT count(*) FROM dim.duplicate_items_master
-- CALL dim.usp_master_keys_for_duplicate_items();
CREATE OR REPLACE PROCEDURE dim.usp_master_keys_for_duplicate_items()
LANGUAGE plpgsql
AS $BODY$

BEGIN

TRUNCATE TABLE dim.duplicate_items_master;

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
  /*AND NOT EXISTS (SELECT 1 FROM dim.duplicate_items_master as dim
                  WHERE dim.locationid = di.locationid
                    AND dim.categoryid = di.categoryid
                    AND dim.menuitemid = di.menuitemid)*/
  ;

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