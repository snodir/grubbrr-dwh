--CALL fact.usp_silver_modifier_interactions_to_fact();

SELECT * FROM stg.silver_modifier_interactions;
SELECT * FROM fact.modifier_interactions;

ALTER TABLE IF EXISTS fact.modifier_interactions
DROP CONSTRAINT IF EXISTS trxnid_menuitemid_modfrgrpid_modfrid_pk

-- Table: fact.modifier_interactions

-- DROP TABLE IF EXISTS fact.modifier_interactions;

CREATE TABLE IF NOT EXISTS fact.modifier_interactions
(
    locationid text COLLATE pg_catalog."default",
    transactionheaderid text COLLATE pg_catalog."default" NOT NULL,
    ordersessionid text COLLATE pg_catalog."default",
    orderid text COLLATE pg_catalog."default",
    orderitemid text COLLATE pg_catalog."default",
    menuitemid text COLLATE pg_catalog."default",
    modifiergroupid text COLLATE pg_catalog."default" NOT NULL,
    modifierid text COLLATE pg_catalog."default" NOT NULL,
    modifiername text COLLATE pg_catalog."default",
    parent_modifier_id text COLLATE pg_catalog."default",
    nesting_depth integer,
    modifierquantity integer,
    modifierprice numeric(12,3),
    freequantity integer,
    selection_type text COLLATE pg_catalog."default",
    action text COLLATE pg_catalog."default",
    session_recorded_at text COLLATE pg_catalog."default",
    businessdate date,
    orderdatelocal timestamp without time zone,
    frequentcustomerid text COLLATE pg_catalog."default",
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    sysupdatetime timestamp without time zone,
    sourceid integer
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.modifier_interactions
    OWNER to citus;


-- Table: stg.silver_modifier_interactions

-- DROP TABLE IF EXISTS stg.silver_modifier_interactions;

CREATE TABLE IF NOT EXISTS stg.silver_modifier_interactions
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
    modifierid text COLLATE pg_catalog."default",
    modifiergroupid text COLLATE pg_catalog."default",
    parent_modifier_id text COLLATE pg_catalog."default",
    selection_type text COLLATE pg_catalog."default",
    modifier_interactions_action text COLLATE pg_catalog."default",
    modifier_interactions_recorded_at text COLLATE pg_catalog."default",
    modifier_interactions_nesting_depth integer,
    order_completion_status text COLLATE pg_catalog."default",
    bronze_filepath text COLLATE pg_catalog."default",
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_modifier_interactions
    OWNER to citus;


-- ============================================================
-- 3. fact.usp_load_modifier_interactions
--
--    Source  : stg.silver_modifier_interactions  (behavioral events
--              from upsellInformation.modifierInteractions — distinct
--              from the item-option modifiers in silver_item_modifiers)
--    Enrich  : stg.silver_item_modifiers via LATERAL join to back-fill
--              orderitemid, modifiername, modifierquantity, modifierprice,
--              freequantity — columns present on the finalised order but
--              not on the raw interaction event.  LEFT JOIN is intentional:
--              interactions for items removed before checkout will not
--              match and those columns will be NULL.
--    PK      : none declared — logical dedup key:
--              (transactionheaderid, modifiergroupid, modifierid,
--               action, session_recorded_at)
--    Note    : orderdatelocal and sourceid have no source in the silver
--              layer and are left NULL.
-- ============================================================

-- PROCEDURE: fact.usp_modifier_interaction_analysis()

-- DROP PROCEDURE IF EXISTS fact.usp_modifier_interaction_analysis();

CREATE OR REPLACE PROCEDURE fact.usp_silver_modifier_interactions_to_fact()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_watermark_interactions    BIGINT;
    v_watermark_options         BIGINT;

BEGIN

    -- ----------------------------------------------------------
    -- Capture both watermarks upfront before any DML
    -- ----------------------------------------------------------
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_watermark_interactions
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.modifier_interactions'
      AND source             = 'nge-Interactions';

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_watermark_options
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.modifier_interactions'
      AND source             = 'nge-Options';

    -- ==============================================================
    -- Part 1: Behavioral interaction events
    --         Source  : stg.silver_modifier_interactions
    --                   (pre-flattened from upsellInformation.modifierInteractions)
    --         sourceid: 5
    -- ==============================================================
    WITH delta_interactions AS (
        SELECT DISTINCT ON (
            transactionheaderid,
            modifiergroupid,
            modifierid,
            modifier_interactions_action,
            modifier_interactions_recorded_at
        )
            locationid,
            transactionheaderid,
            ordersessionid,
            orderid,
            menuitemid,
            modifierid,
            modifiergroupid,
            parent_modifier_id,
            selection_type,
            modifier_interactions_action            AS action,
            modifier_interactions_recorded_at       AS session_recorded_at,
            modifier_interactions_nesting_depth     AS nesting_depth,
            businessdate :: DATE                    AS businessdate,
            orderdateutc,
            frequentcustomerid,
            syscosmosts,
            sysinserttime
        FROM stg.silver_modifier_interactions
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND syscosmosts > v_watermark_interactions
        ORDER BY
            transactionheaderid,
            modifiergroupid,
            modifierid,
            modifier_interactions_action,
            modifier_interactions_recorded_at,
            syscosmosts DESC
    ),
    trxn_enrichment AS (
        SELECT
            di.locationid,
            di.transactionheaderid,
            di.ordersessionid,
            di.orderid,
            imd.itemid                              AS orderitemid,
            di.menuitemid,
            di.modifiergroupid,
            di.modifierid,
            imd.modifiername,
            di.parent_modifier_id,
            di.nesting_depth,
            imd.modifierquantity,
            imd.modifierprice,
            imd.freequantity,
            di.selection_type,
            di.action,
            di.session_recorded_at,
            di.businessdate,
            ti.orderdatelocal,                       
            di.frequentcustomerid,
            di.syscosmosts,
            di.sysinserttime
        FROM delta_interactions di
        LEFT JOIN fact.transactionitem ti
               ON ti.locationid          = di.locationid
              AND ti.transactionheaderid = di.transactionheaderid
              AND ti.dimmenuitemid       = di.menuitemid
        LEFT JOIN fact.itemmodifier imd
               ON imd.transactionheaderid = di.transactionheaderid
              AND imd.itemid             = ti.itemid
              AND imd.modifiergroupid    = di.modifiergroupid
              AND imd.modifierid         = di.modifierid
        WHERE NOT EXISTS (
            SELECT 1
            FROM fact.modifier_interactions mint
            WHERE mint.transactionheaderid  = di.transactionheaderid
              AND mint.modifiergroupid      = di.modifiergroupid
              AND mint.modifierid           = di.modifierid
              AND mint.action               = di.action
              AND mint.session_recorded_at  = di.session_recorded_at
        )
    )
    INSERT INTO fact.modifier_interactions
    SELECT *,
           NULL :: TIMESTAMP  AS sysupdatetime,
           5                  AS sourceid
    FROM trxn_enrichment;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_interactions WHERE sourceid = 5)
    WHERE watermarktablename = 'fact.modifier_interactions'
      AND source             = 'nge-Interactions';


    -- ==============================================================
    -- Part 2: Options-derived interactions (inferred action/selection_type
    --         from ordered modifiers in fact.itemmodifier + dim lookups)
    --         Source  : fact.itemmodifier (unchanged)
    --         sourceid: 6
    -- ==============================================================
    WITH delta_modifier_trxns AS (
        SELECT *
        FROM fact.itemmodifier im
        WHERE locationid LIKE 'loc-%'
          AND (syscosmosts > v_watermark_options OR syscosmosts IS NULL)
          AND NOT EXISTS (
                SELECT 1
                FROM fact.modifier_interactions mint
                WHERE mint.locationid          = im.locationid
                  AND mint.transactionheaderid = im.transactionheaderid
          )
    ),
    modfr_enrichment AS (
        SELECT
            mt.locationid,
            mt.transactionheaderid,
            ti.ordersessionid,
            ti.orderid,
            ti.itemid                               AS orderitemid,
            ti.dimmenuitemid                        AS menuitemid,
            mt.modifiergroupid,
            mt.modifierid,
            mt.modifiername,
            NULL :: TEXT                            AS parent_modifier_id,
            NULL :: INTEGER                         AS nesting_depth,
            mt.modifierquantity,
            mt.modifierprice,
            mt.freequantity,
            CASE WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 THEN 'optional'
                 WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 THEN 'required'
                 WHEN mgm.is_default = TRUE                                                      THEN 'default'
            END                                     AS selection_type,
            CASE WHEN mgm.is_default = FALSE AND mg.min_selection = 0  AND mg.max_selection >= 0 AND mt.modifierquantity >= 1 THEN 'added'
                 WHEN mgm.is_default = FALSE AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'selected'
                 WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'kept'
                 WHEN mgm.is_default = TRUE  AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity = 0  THEN 'removed'
            END                                     AS action,
            NULL :: TEXT                            AS session_recorded_at,
            mt.businessdate,
            ti.orderdatelocal,
            ti.frequentcustomerid,
            mt.syscosmosts,
            mt.sysinserttime
        FROM delta_modifier_trxns mt
        LEFT JOIN dim.modifier_group_mapping mgm
               ON mgm.modifiergroupid = mt.modifiergroupid
              AND mgm.modifierid      = mt.modifierid
        LEFT JOIN dim.modifier_group mg
               ON mg.modifiergroupid  = mt.modifiergroupid
        LEFT JOIN fact.transactionitem ti
               ON ti.transactionheaderid = mt.transactionheaderid
              AND ti.itemid              = mt.itemid
    )
    INSERT INTO fact.modifier_interactions
    SELECT *,
           NULL :: TIMESTAMP  AS sysupdatetime,
           6                  AS sourceid
    FROM modfr_enrichment;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_interactions WHERE sourceid = 6)
    WHERE watermarktablename = 'fact.modifier_interactions'
      AND source             = 'nge-Options';

END;
$BODY$;
ALTER PROCEDURE fact.usp_silver_modifier_interactions_to_fact()
    OWNER TO citus;