SELECT DISTINCT isc.table_schema, isc.table_name
FROM information_schema.columns isc
WHERE isc.table_schema = 'public'
ORDER BY isc.table_name, isc.ordinal_position;

SELECT count(*)
FROM public.catalog
LIMIT 1000;

WITH C AS (
SELECT nsp.nspname, 
    rel.relname as table_name,
    to_jsonb(array_agg(con.conname)) AS constraint_name,
    to_jsonb(array_agg(con.contype)) AS constraint_type,
    to_jsonb(array_agg(pg_get_constraintdef(con.oid))) AS definition
FROM pg_catalog.pg_constraint as con
JOIN pg_catalog.pg_class as rel ON rel.oid = con.conrelid
JOIN pg_catalog.pg_namespace as nsp ON nsp.oid = rel.relnamespace
WHERE 1=1 AND rel.relname not like 'pg_%' AND nsp.nspname = 'public' -- --and rel.relname = 'catalog_pos_connector_glue'
GROUP BY nsp.nspname, rel.relname
--ORDER BY rel.relname
)
SELECT *
FROM C 
WHERE NOT (C.constraint_type @> '["f"]')

WITH D as (
SELECT DISTINCT
    src_ns.nspname AS child_schema,
    src_tbl.relname AS child_table,
    --src_col.attname AS source_column,
   -- tgt_ns.nspname AS target_schema,
    --to_jsonb(array_agg(con.conname)) AS constraint_name,
    --to_jsonb(array_agg(con.contype)) AS constraint_type,
    --to_jsonb(array_agg(pg_get_constraintdef(con.oid))) AS definition
    --to_jsonb(array_agg(tgt_tbl.relname)) AS target_table
    tgt_tbl.relname AS parent_table
    --tgt_col.attname AS target_column,
    --con.conname AS constraint_name
FROM pg_constraint as con
JOIN pg_class as src_tbl ON con.conrelid = src_tbl.oid
JOIN pg_namespace as src_ns ON src_tbl.relnamespace = src_ns.oid
JOIN pg_class as tgt_tbl ON con.confrelid = tgt_tbl.oid
--JOIN pg_namespace as tgt_ns ON tgt_tbl.relnamespace = tgt_ns.oid
--JOIN pg_attribute as src_col ON src_col.attrelid = src_tbl.oid AND src_col.attnum = ANY (con.conkey)
--JOIN pg_attribute tgt_col ON tgt_col.attrelid = tgt_tbl.oid AND tgt_col.attnum = ANY (con.confkey)
WHERE src_ns.nspname = 'public' and con.contype = 'f' --and 
--GROUP BY src_ns.nspname, src_tbl.relname
--ORDER BY child_schema, child_table--, constraint_name;
)
SELECT D1.parent_table,
FROM D as D1 
LEFT JOIN D as D2 
       ON D1.parent_table = D2.child_table


SELECT '"a"' :: jsonb as arr_jsonb

WITH RECURSIVE fk_edges AS (
    SELECT
        conrelid::regclass AS child,
        confrelid::regclass AS parent
    FROM pg_constraint
    WHERE contype = 'f'
),
tables_in_schema AS (
    SELECT c.oid, c.relname, n.nspname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'r'
      AND n.nspname = 'public'
),
roots AS (
    SELECT oid::regclass AS table_name, t.nspname
    FROM tables_in_schema t
    WHERE NOT EXISTS (
        SELECT 1 FROM fk_edges f WHERE f.child = t.oid::regclass
    )
),
sorted AS (
    SELECT nspname, table_name, 0 AS depth
    FROM roots
    UNION ALL
    SELECT s.nspname, f.child, s.depth + 1
    FROM sorted s
    JOIN fk_edges f ON f.parent = s.table_name
    JOIN tables_in_schema t ON t.oid::regclass = f.child
)
SELECT DISTINCT nspname, table_name, depth
FROM sorted
ORDER BY depth, table_name;



SELECT *--count(*)
FROM public.catalog_pos_connector_glue
LIMIT 1000

WITH A as (
SELECT isc.table_name, to_jsonb(array_agg(isc.column_name)) as key_columns
FROM information_schema.columns as isc 
WHERE isc.table_schema = 'public'
  AND((isc.table_name = 'catalog' AND isc.column_name in ('id')) --2,043
   OR (isc.table_name = 'grubbrr_source_lookup' AND isc.column_name in ('id'))
   OR (isc.table_name = 'itemcategory' AND isc.column_name in ('id'))
   OR (isc.table_name = 'kiosk' AND isc.column_name in ('locationid','kioskid'))
   OR (isc.table_name = 'location' AND isc.column_name in ('locationid','companyid'))
   OR (isc.table_name = 'organization' AND isc.column_name in ('id'))
   OR (isc.table_name = 'organizationlocation' AND isc.column_name in ('organizationid','locationid'))
   OR (isc.table_name = 'menuitem' AND isc.column_name in ('id'))
   OR (isc.table_name = 'occasionsurvey' AND isc.column_name in ('surveykey'))
   OR (isc.table_name = 'ordertype' AND isc.column_name in ('id'))
   OR (isc.table_name = 'kioskdetails' AND isc.column_name in ('locationid'))
   OR (isc.table_name = 'upsellgrouplookup' AND isc.column_name in ('upsellgroupid'))
   OR (isc.table_name = 'userlocation' AND isc.column_name in ('locationid','userid'))
   OR (isc.table_name = 'element' AND isc.column_name in ('elementid')))
GROUP BY isc.table_name
)
ORDER BY isc.table_name, isc.ordinal_position


WITH A as (
SELECT isc.table_name, to_jsonb(array_agg(isc.column_name)) as key_columns
FROM information_schema.columns as isc 
WHERE isc.table_schema = 'fact' --ORDER BY isc.table_name, isc.ordinal_position
  AND((isc.table_name = 'transactionheader' AND isc.column_name in ('locationid','transactionheaderid'))
   OR (isc.table_name = 'transactionitem' AND isc.column_name in ('transactionheaderid','itemid','itemname'))
   --OR (isc.table_name = 'transactionpayment' AND isc.column_name in ('locationid','transactionheaderid'))---++++
   OR (isc.table_name = 'transactionrefunds' AND isc.column_name in ('locationid','transactionheaderid'))
   OR (isc.table_name = 'itemmodifier' AND isc.column_name in ('transactionheaderid','itemid','modifiergroupid','modifierid'))
   OR (isc.table_name = 'itemssurvey' AND isc.column_name in ('locationid','surveytransid','orderid','itemid'))
   OR (isc.table_name = 'occasionsurveydetail' AND isc.column_name in ('locationid','surveytransid','orderid'))
   OR (isc.table_name = 'ordertiming' AND isc.column_name in ('id'))
   OR (isc.table_name = 'recommendations' AND isc.column_name in ('transactionheaderid','recommendationid'))
   OR (isc.table_name = 'vw_offer_analysis' AND isc.column_name in ('transactionheaderid','recommendationid','offereditem'))
   OR (isc.table_name = 'usercheckedin' AND isc.column_name in ('locationid','orderid'))
   OR (isc.table_name = 'userbehaviour' AND isc.column_name in ('id'))
   --OR (isc.table_name = 'deviceevent' AND isc.column_name in ('locationid','eventtoken','datacategory','actiontype','eventinstant'))
   --OR (isc.table_name = 'devicestate' AND isc.column_name in ('locationid','deviceid','state','lasteventtime'))
   OR (isc.table_name = 'devicetelemetry' AND isc.column_name in ('locationid','deviceid','dateid')))
GROUP BY isc.table_name
), B as (
SELECT DISTINCT isc.table_name, isc.column_name as watermark_column, isc.data_type as watermark_data_type,
       CONCAT('SELECT max(', isc.column_name, ') as max_value, ''', isc.table_name, ''' as table_name, ''', isc.column_name,''' as watermark_column FROM fact.', isc.table_name) AS sql_max,
       CONCAT('SELECT * FROM fact.', isc.table_name, 
              ' WHERE ', isc.column_name, ' >= ', 
              CASE WHEN isc.column_name in ('sysinserttime','createddate') 
                   THEN '''2025-10-05 00:00:00.000'' :: TIMESTAMP' 
                   ELSE '2025100500' END) as sql_query
FROM information_schema.columns as isc 
WHERE isc.table_schema = 'fact' --ORDER BY isc.table_name, isc.ordinal_position
  AND((isc.table_name = 'transactionheader' AND isc.column_name in ('createddate'))
   OR (isc.table_name = 'transactionitem' AND isc.column_name in ('sysinserttime'))
   --OR (isc.table_name = 'transactionpayment' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'transactionrefunds' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'itemmodifier' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'itemssurvey' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'occasionsurveydetail' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'ordertiming' AND isc.column_name in ('dateid'))--+++
   OR (isc.table_name = 'recommendations' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'vw_offer_analysis' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'usercheckedin' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'userbehaviour' AND isc.column_name in ('createddate'))
   --OR (isc.table_name = 'deviceevent' AND isc.column_name in ('sysinserttime'))
   --OR (isc.table_name = 'devicestate' AND isc.column_name in ('lasteventtime'))
   OR isc.table_name = 'devicetelemetry' AND isc.column_name in ('dateid'))
)
SELECT A.*, B.watermark_column, B.watermark_data_type, B.sql_max, B.sql_query
FROM A
INNER JOIN B 
       ON A.table_name = B.table_name;


SELECT * FROM dim.ordertype
SELECT * FROM dim.kiosk ORDER BY id 
SELECT * FROM dim.element ORDER BY elementid desc LIMIT 100

SELECT count(*), max(createddate), max(updateddate), max(syscosmosts)
FROM fact.transactionheader

SELECT count(*), max(eve)
FROM fact.deviceevent as d --61,221,386

SELECT * FROM dim.organization
ORDER BY createdon desc

SELECT * 
FROM fact.transactionheader as th
WHERE th.createddate is not null
ORDER BY th.createddate desc
LIMIT 100

SELECT * FROM fact.watermarktable;

SELECT * 
FROM fact.transactionrefunds
--WHERE 
LIMIT 100

CREATE TABLE fact.stage_watermark(
   id INTEGER NOT NULL PRIMARY KEY,
   table_schema CHARACTER VARYING(50) COLLATE pg_catalog."default",
   table_name CHARACTER VARYING(50) COLLATE pg_catalog."default",
   watermark_column CHARACTER VARYING(50) COLLATE pg_catalog."default",
   watermark_timestamp TIMESTAMP
)
TABLESPACE pg_default;

ALTER TABLE fact.stage_watermark
OWNER to citus;

INSERT INTO fact.stage_watermark
VALUES(1, 'fact', 'deviceevent', 'sysinserttime'),
      (2, 'fact', 'devicestate', 'lasteventtime'),
      (3, 'fact', 'transactionpayment', 'sysinserttime')

SELECT DISTINCT isc.table_name, isc.column_name as watermark_column, 
       isc.data_type as watermark_data_type, wm.watermark_timestamp,
       CONCAT('SELECT max(', isc.column_name, ') as max_value, ''', 
               isc.table_name, ''' as table_name, ''', 
               isc.column_name,''' as watermark_column FROM fact.', isc.table_name) AS sql_max
FROM information_schema.columns as isc 
INNER JOIN fact.stage_watermark as wm
        ON isc.table_name = wm.table_name
       AND isc.column_name = wm.watermark_column
WHERE isc.table_schema in ('fact')
  AND((isc.table_name = 'transactionpayment' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'deviceevent' AND isc.column_name in ('sysinserttime'))
   OR (isc.table_name = 'devicestate' AND isc.column_name in ('lasteventtime')));



/*
isc.table_name = 'transactionheader' AND isc.column_name in ('createddate')
   OR isc.table_name = 'transactionitem' AND isc.column_name in ('sysinserttime')
   OR isc.table_name = 'transactionrefunds' AND isc.column_name in ('sysinserttime')
   OR isc.table_name = 'itemmodifier' AND isc.column_name in ('sysinserttime')
   OR isc.table_name = 'itemssurvey' AND isc.column_name in ('sysinserttime')
   OR isc.table_name = 'occasionsurveydetail' AND isc.column_name in ('sysinserttime')
   OR isc.table_name = 'recommendations' AND isc.column_name in ('sysinserttime')
   OR isc.table_name = 'usercheckedin' AND isc.column_name in ('sysinserttime')
   OR isc.table_name = 'devicetelemetry' AND isc.column_name in ('dateid'))
   OR 

   SELECT * FROM @{item().table_name} WHERE @{item().watermark_column} >= @{activity('GetMaxValues').output.firstRow.max_value}

   @concat('SELECT * FROM fact.', item().table_name, 
        ' WHERE ', item().watermark_column, ' > ', 
        if(or(startswith(item().watermark_data_type, 'integer'), startswith(item().watermark_data_type, 'bigint')), 
        string(activity('GetEventMaxValues').output.firstRow.max_value), 
        concat('''', string(activity('GetEventMaxValues').output.firstRow.max_value), ''' :: TIMESTAMP')))

*/