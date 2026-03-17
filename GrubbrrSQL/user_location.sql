SELECT *
FROM dim.organization;

WITH order_types AS (
SELECT locationid, json_agg(value->>'label') AS order_type_labels
FROM (SELECT * FROM dim.kioskdetails WHERE dim.is_valid_jsonb(order_types)),
     LATERAL jsonb_each(order_types :: jsonb -> 'options')
GROUP BY locationid
)
SELECT DISTINCT 
o.id as locationid,
o.name as locationnname,
o.city,
o.state,
o.country,
o.active as isactive,
o.timezone
FROM dim.organization as o
INNER JOIN order_types as ot 
        ON o.id = ot.locationid


SELECT *,  
FROM dim.kioskdetails
WHERE 1=1
  AND lower(order_types :: text) like '%"label":%"delivery"%'-- AND
 
LIMIT 1000;

SELECT * FROM dim.kioskdetails
WHERE lower(order_types :: text) like '%"label":"delivery"%'
LIMIT 10;



-- Table: dim.userlocation

-- DROP TABLE IF EXISTS dim.userlocation;

CREATE TABLE IF NOT EXISTS dim.userlocation
(
    userid character varying(40) COLLATE pg_catalog."default" NOT NULL,
    locationid character varying(40) COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT userlocation_pkey PRIMARY KEY (userid, locationid)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.userlocation
    OWNER to citus;

REVOKE ALL ON TABLE dim.userlocation FROM akurani;
REVOKE ALL ON TABLE dim.userlocation FROM dhanraj;
REVOKE ALL ON TABLE dim.userlocation FROM varshil;

GRANT SELECT ON TABLE dim.userlocation TO akurani;

GRANT ALL ON TABLE dim.userlocation TO citus;

GRANT SELECT ON TABLE dim.userlocation TO dhanraj;

GRANT SELECT ON TABLE dim.userlocation TO varshil;