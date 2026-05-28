CALL fact.usp_silver_modifier_impressions_to_fact();

SELECT * FROM stg.silver_modifier_impressions;
SELECT * FROM fact.modifier_impressions;

-- Table: fact.modifier_impressions

-- DROP TABLE IF EXISTS fact.modifier_impressions;

CREATE TABLE IF NOT EXISTS fact.modifier_impressions
(
    locationid text COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    parent_modifier_id text COLLATE pg_catalog."default",
    selection_type text COLLATE pg_catalog."default",
    nesting_depth integer,
    "position" integer,
    score numeric(5,3),
    strategy text COLLATE pg_catalog."default",
    context text COLLATE pg_catalog."default",
    selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    pre_selected boolean,
    businessdate date,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.modifier_impressions
    OWNER to citus;

-- Table: stg.silver_modifier_impressions

-- DROP TABLE IF EXISTS stg.silver_modifier_impressions;

CREATE TABLE IF NOT EXISTS stg.silver_modifier_impressions
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
    menuitemid text COLLATE pg_catalog."default",
    parentmodifierid text COLLATE pg_catalog."default",
    selection_type text COLLATE pg_catalog."default",
    modifier_impressions_nesting_depth integer,
    modifier_impressions_context text COLLATE pg_catalog."default",
    strategy text COLLATE pg_catalog."default",
    modifierid text COLLATE pg_catalog."default",
    score integer,
    "position" integer,
    selected boolean,
    pre_selected boolean,
    pre_deselected boolean,
    confirmed_removed boolean,
    order_completion_status text COLLATE pg_catalog."default",
    bronze_filepath text COLLATE pg_catalog."default",
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_modifier_impressions
    OWNER to citus;

-- PROCEDURE: fact.usp_modifier_impression_analysis()

-- DROP PROCEDURE IF EXISTS fact.usp_modifier_impression_analysis();

CREATE OR REPLACE PROCEDURE fact.usp_silver_modifier_impressions_to_fact()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_watermark_impressions     BIGINT;

BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_watermark_impressions
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.modifier_impressions'
      AND source             = 'nge';

    WITH delta_impressions AS (
        SELECT DISTINCT ON (
            locationid,
            transactionheaderid,
            menuitemid,
            modifierid,
            position
        )
            locationid,
            transactionheaderid,
            ordersessionid,
            orderid,
            menuitemid,
            modifierid,
            parentmodifierid                        AS parent_modifier_id,
            selection_type,
            modifier_impressions_nesting_depth      AS nesting_depth,
            position,
            score :: NUMERIC(5,3)                   AS score,
            strategy,
            modifier_impressions_context            AS context,
            selected,
            pre_deselected,
            confirmed_removed,
            pre_selected,
            businessdate :: DATE                    AS businessdate,
            orderdateutc,
            frequentcustomerid,
            syscosmosts,
            sysinserttime
        FROM stg.silver_modifier_impressions
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND modifierid IS NOT NULL
          AND syscosmosts > v_watermark_impressions
        ORDER BY
            locationid,
            transactionheaderid,
            menuitemid,
            modifierid,
            position,
            syscosmosts DESC
    )
    INSERT INTO fact.modifier_impressions (
        locationid,
        transactionheaderid,
        ordersessionid,
        orderid,
        menuitemid,
        modifierid,
        parent_modifier_id,
        selection_type,
        nesting_depth,
        position,
        score,
        strategy,
        context,
        selected,
        pre_deselected,
        confirmed_removed,
        pre_selected,
        businessdate,
        orderdatelocal,
        frequentcustomerid,
        syscosmosts,
        sysinserttime
    )
    SELECT
        d.locationid,
        d.transactionheaderid,
        d.ordersessionid,
        d.orderid,
        d.menuitemid,
        d.modifierid,
        d.parent_modifier_id,
        d.selection_type,
        d.nesting_depth,
        d.position,
        d.score,
        d.strategy,
        d.context,
        d.selected,
        d.pre_deselected,
        d.confirmed_removed,
        d.pre_selected,
        d.businessdate,
        fact.parse_iso_timestamp(d.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE ol.timezone AS orderdatelocal,
        d.frequentcustomerid,
        d.syscosmosts,
        NOW() :: TIMESTAMP                                                               AS sysinserttime
    FROM delta_impressions d
    LEFT JOIN dim.organization AS ol
           ON ol.id       = d.locationid
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.modifier_impressions mi
        WHERE mi.locationid          = d.locationid
          AND mi.transactionheaderid = d.transactionheaderid
          AND mi.menuitemid          = d.menuitemid
          AND mi.modifierid          = d.modifierid
          AND mi.position            = d.position
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_impressions)
    WHERE watermarktablename = 'fact.modifier_impressions'
      AND source             = 'nge';

END;
$BODY$;
ALTER PROCEDURE fact.usp_silver_modifier_impressions_to_fact()
    OWNER TO citus;


