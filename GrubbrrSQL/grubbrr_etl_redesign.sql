SELECT DISTINCT isc.table_schema, isc.table_name
FROM information_schema.columns as isc 
WHERE isc.table_schema IN ('dim','fact','stg')
ORDER BY isc.table_schema, isc.table_name--, isc.ordinal_position

SELECT *
FROM dim.businessdate
ORDER BY dateid DESC 
LIMIT 100