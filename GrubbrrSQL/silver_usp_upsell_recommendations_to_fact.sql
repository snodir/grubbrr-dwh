
SELECT * FROM stg.silver_upsell_recommendations

--CALL fact.usp_silver_upsell_recommendations_to_fact();

SELECT * 
FROM fact.recommendations as r
ORDER BY r.sysinserttime DESC
LIMIT 1000;

-- Table: fact.recommendations

-- DROP TABLE IF EXISTS fact.recommendations;


SELECT count(distinct CONCAT(table_schema, table_name)) 
FROM information_schema.columns 
WHERE table_schema IN ('dim','fact','ml','stg')

CREATE TABLE IF NOT EXISTS fact.recommendations
(
    transactionheaderid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    recommendationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    offereditems jsonb,
    selecteditems jsonb,
    isconverted boolean,
    prompttimestamp text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone,
    syscosmosts bigint,
    CONSTRAINT locationid_trxnid_recommendationid_pk PRIMARY KEY (locationid, transactionheaderid, recommendationid),
    CONSTRAINT transactionheaderid_recommendationid_uidx UNIQUE (transactionheaderid, recommendationid),
    CONSTRAINT location_transactionheaderid_fk FOREIGN KEY (locationid, transactionheaderid)
        REFERENCES fact.transactionheader (locationid, transactionheaderid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.recommendations
    OWNER to citus;

-- Table: stg.silver_upsell_recommendations

-- DROP TABLE IF EXISTS stg.silver_upsell_recommendations;

CREATE TABLE IF NOT EXISTS stg.silver_upsell_recommendations
(
    transactionheaderid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    ordersessionid text COLLATE pg_catalog."default",
    orderdateutc text COLLATE pg_catalog."default",
    businessdate text COLLATE pg_catalog."default",
    syscosmosts bigint,
    locationid text COLLATE pg_catalog."default",
    kioskid text COLLATE pg_catalog."default",
    kiosk_name text COLLATE pg_catalog."default",
    kiosk_mode integer,
    is_test_order boolean,
    frequentcustomerid text COLLATE pg_catalog."default",
    recommendationid text COLLATE pg_catalog."default",
    prompttimestamp text COLLATE pg_catalog."default",
    modal_version text COLLATE pg_catalog."default",
    offered_items text COLLATE pg_catalog."default",
    selected_items text COLLATE pg_catalog."default",
    order_completion_status text COLLATE pg_catalog."default",
    bronze_filepath text COLLATE pg_catalog."default",
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_upsell_recommendations
    OWNER to citus;


CREATE OR REPLACE PROCEDURE fact.usp_silver_upsell_recommendations_to_fact()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.recommendations'
      AND source             = 'nge';


    WITH delta AS (

        SELECT DISTINCT ON (locationid, transactionheaderid, recommendationid)
            transactionheaderid,
            locationid,
            recommendationid,
            NULLIF(offered_items, '')  :: JSONB                 AS offereditems,
            NULLIF(selected_items, '') :: JSONB                 AS selecteditems,
            CASE
                WHEN selected_items IS NULL
                  OR selected_items  IN ('', '[]', 'null')      THEN false
                ELSE true
            END                                                  AS isconverted,
            prompttimestamp,
            syscosmosts
        FROM stg.silver_upsell_recommendations
        WHERE syscosmosts > v_max_syscosmosts
          AND (is_test_order = false OR is_test_order IS NULL)
          AND recommendationid IS NOT NULL
          AND offered_items    IS NOT NULL
        ORDER BY
            locationid,
            transactionheaderid,
            recommendationid,
            syscosmosts DESC

    )
    INSERT INTO fact.recommendations (
        transactionheaderid,
        locationid,
        recommendationid,
        offereditems,
        selecteditems,
        isconverted,
        prompttimestamp,
        sysinserttime,
        syscosmosts
    )
    SELECT
        d.transactionheaderid,
        d.locationid,
        d.recommendationid,
        d.offereditems,
        d.selecteditems,
        d.isconverted,
        d.prompttimestamp,
        NOW() :: TIMESTAMP      AS sysinserttime,
        d.syscosmosts
    FROM delta d
    INNER JOIN fact.transactionheader th
        ON  th.locationid          = d.locationid
        AND th.transactionheaderid = d.transactionheaderid
    ON CONFLICT (locationid, transactionheaderid, recommendationid)
    DO UPDATE SET
        selecteditems = EXCLUDED.selecteditems,
        isconverted   = EXCLUDED.isconverted,
        syscosmosts   = EXCLUDED.syscosmosts
    WHERE
        fact.recommendations.isconverted IS DISTINCT FROM true;

END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_upsell_recommendations_to_fact()
    OWNER to citus;