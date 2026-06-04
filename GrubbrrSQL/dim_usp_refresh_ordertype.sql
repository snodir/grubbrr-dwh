--CALL dim.usp_refresh_ordertype();

SELECT sth.transactionheaderid, ot.*
FROM dim.ordertype as ot 
INNER JOIN stg.silver_transaction_header as sth
    ON sth.locationid = ot.locationid
   AND sth.kioskid = ot.kioskid
   AND CASE WHEN sth.ordertype = '' OR sth.ordertype IS NULL THEN order_type_label ELSE sth.ordertype END = ot.ordertypeid

SELECT * FROM dim.ordertype ORDER BY id DESC;
SELECT * FROM stg.silver_transaction_header ORDER BY syscosmosts DESC;
-- Table: dim.ordertype

-- DROP TABLE IF EXISTS dim.ordertype;

CREATE TABLE IF NOT EXISTS dim.ordertype
(
    id bigint NOT NULL,
    locationid text COLLATE pg_catalog."default" NOT NULL,
    kioskid text COLLATE pg_catalog."default" NOT NULL,
    ordertypeid text COLLATE pg_catalog."default" NOT NULL,
    ordertypelabel text COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT ordertype_pk PRIMARY KEY (id)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS dim.ordertype
    OWNER to citus;



-- ============================================================
-- dim.ordertype  –  Sequence Setup + Refresh Procedure
-- Source  : stg.silver_transaction_header
--           (dim data derived from transaction data –
--            same CosmosDB container as CosmosDB orders ADF pipeline)
-- Target  : dim.ordertype
-- Pattern : ADF loads stg.silver_transaction_header
--           → usp_refresh_ordertype() → dim.ordertype
-- Natural key  : (locationid, kioskid, ordertypeid)
-- Surrogate key: id BIGINT (sequence-based)
-- Notes   : ordertypeid fallback – if blank/NULL use order_type_label
--           (mirrors ADF derivedColumn3 logic)
--           is_test_order filter mirrors ADF CosmosDB query predicate
--           kioskid filter mirrors ADF: kioskId > ''
-- ============================================================


-- ============================================================
-- SECTION 1 – AUDIT COLUMNS (one-time, safe to re-run)
-- ============================================================

ALTER TABLE dim.ordertype
    ADD COLUMN IF NOT EXISTS sysinserttime TIMESTAMP WITHOUT TIME ZONE,
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP WITHOUT TIME ZONE;


-- ============================================================
-- SECTION 2 – SEQUENCE SETUP (one-time, safe to re-run)
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS dim.ordertype_id_seq;

SELECT setval(
    'dim.ordertype_id_seq',
    COALESCE((SELECT MAX(id) FROM dim.ordertype), 0)
);

ALTER TABLE dim.ordertype
    ALTER COLUMN id SET DEFAULT nextval('dim.ordertype_id_seq');


-- ============================================================
-- SECTION 3 – REFRESH STORED PROCEDURE
-- ============================================================

--SELECT * FROM stg.silver_transaction_header;

CREATE OR REPLACE PROCEDURE dim.usp_refresh_ordertype()
LANGUAGE plpgsql
AS $BODY$
BEGIN

    -- ── Step 1: deduplicate source ────────────────────────────
    -- Derives dimension data from transaction history.
    -- ordertypeid fallback: if blank/NULL → fall back to order_type_label
    --   mirrors ADF: case(ordertypeid=='' || isNull(ordertypeid), ordertypelabel, ordertypeid)
    -- Filters replicated from ADF CosmosDB source query:
    --   • kioskid > ''                    (non-empty kiosk)
    --   • is_test_order = false OR NULL   (exclude test orders)
    -- Rows where both ordertype and order_type_label are blank carry
    -- no useful dimension value and are excluded.
    -- DISTINCT ON picks the row with the highest CosmosDB source timestamp
    -- per natural key (syscosmosts bigint – more reliable than ETL load time).

    CREATE TEMP TABLE tmp_ordertype ON COMMIT DROP AS
    SELECT DISTINCT ON (locationid, kioskid, ordertypeid)
        locationid,
        kioskid,
        COALESCE(NULLIF(TRIM(ordertype), ''), order_type_label)      AS ordertypeid,
        COALESCE(NULLIF(TRIM(order_type_label), ''), ordertype)      AS ordertypelabel
    FROM stg.silver_transaction_header
    WHERE (is_test_order = FALSE OR is_test_order IS NULL)
      AND COALESCE(NULLIF(TRIM(ordertype), ''), NULLIF(TRIM(order_type_label), '')) IS NOT NULL
    ORDER BY
        locationid,
        kioskid,
        COALESCE(NULLIF(TRIM(ordertype), ''), order_type_label),
        syscosmosts DESC NULLS LAST;

    CREATE INDEX ix_tmp_ordertype
        ON tmp_ordertype (locationid, kioskid, ordertypeid);
    ANALYZE tmp_ordertype;


    -- ── Step 2: INSERT net-new order types ───────────────────

    INSERT INTO dim.ordertype (
        id,
        locationid,
        kioskid,
        ordertypeid,
        ordertypelabel,
        sysinserttime
    )
    SELECT
        nextval('dim.ordertype_id_seq'),
        t.locationid,
        t.kioskid,
        t.ordertypeid,
        t.ordertypelabel,
        NOW()::TIMESTAMP
    FROM tmp_ordertype t
    WHERE NOT EXISTS (
        SELECT 1
        FROM dim.ordertype d
        WHERE d.locationid  = t.locationid
          AND d.kioskid     = t.kioskid
          AND d.ordertypeid = t.ordertypeid
    );


    -- ── Step 3: UPDATE changed label ─────────────────────────
    -- ordertypelabel is the only mutable attribute.
    -- IS DISTINCT FROM guard avoids touching unchanged rows.

    UPDATE dim.ordertype d
    SET
        ordertypelabel = t.ordertypelabel,
        sysupdatetime  = NOW()::TIMESTAMP
    FROM tmp_ordertype t
    WHERE d.locationid   = t.locationid
      AND d.kioskid      = t.kioskid
      AND d.ordertypeid  = t.ordertypeid
      AND d.ordertypelabel IS DISTINCT FROM t.ordertypelabel;

END;
$BODY$;

ALTER PROCEDURE dim.usp_refresh_ordertype()
    OWNER TO citus;