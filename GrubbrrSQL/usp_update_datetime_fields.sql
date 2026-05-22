CALL fact.usp_update_datetime_fields();
SELECT 1 as rn;

CREATE OR REPLACE PROCEDURE fact.usp_update_datetime_fields()
LANGUAGE plpgsql
AS $BODY$
BEGIN

UPDATE fact.transactionheader 
   SET orderdatelocal = ((transactionheader.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE l.timezone)
FROM ( SELECT DISTINCT location.locationid,
                 CASE
                     WHEN ((location.timezone IS NULL) OR (location.timezone = ''::text)) THEN 'America/New_York'::text
                     ELSE location.timezone
                 END AS timezone
            FROM dim.location) l
WHERE (l.locationid = transactionheader.locationid) AND (transactionheader.orderdatelocal IS NULL);

UPDATE fact.transactionheader 
   SET orderdatelocal = ((transactionheader.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE 'America/New_York'::text)
WHERE (transactionheader.orderdatelocal IS NULL);

UPDATE fact.transactionheader 
   SET dateid = (to_char(transactionheader.orderdatelocal, 'YYYYMMDDHH24'::text))::integer
WHERE (transactionheader.dateid IS NULL);

UPDATE fact.transactionheader 
   SET businessdate = (transactionheader.orderdatelocal)::date
WHERE (transactionheader.businessdate IS NULL);

UPDATE fact.transactionheader 
   SET abtestid = abtests.abtestid
FROM dim.abtests
WHERE (abtests.ordersessionid = transactionheader.ordersessionid) AND (transactionheader.abtestid IS NULL);



UPDATE fact.transactionitem 
   SET orderdatelocal = ((transactionitem.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE l.timezone)
FROM ( SELECT DISTINCT location.locationid,
                 CASE
                     WHEN ((location.timezone IS NULL) OR (location.timezone = ''::text)) THEN 'America/New_York'::text
                     ELSE location.timezone
                 END AS timezone
            FROM dim.location) l
WHERE (l.locationid = transactionitem.locationid) AND (transactionitem.orderdatelocal IS NULL);

UPDATE fact.transactionitem
   SET orderdatelocal = ((transactionitem.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE 'America/New_York'::text)
WHERE (transactionitem.orderdatelocal IS NULL);

UPDATE fact.transactionitem 
   SET businessdate = (transactionitem.orderdatelocal)::date
WHERE (transactionitem.businessdate IS NULL);


UPDATE fact.watermarktable
   SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.itemmodifier)
WHERE watermarktablename = 'fact.itemmodifier'
  AND source = 'nge';


END;
$BODY$;


ALTER PROCEDURE fact.usp_update_datetime_fields()
    OWNER TO citus;