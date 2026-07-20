--CALL fact.usp_gem_ordertiming_to_fact_ordertiming()

SELECT *
FROM fact.ordertiming
WHERE sysinserttime IS NOT NULL
ORDER BY sysinserttime DESC
LIMIT 1000;

ALTER TABLE IF EXISTS fact.ordertiming
    ADD COLUMN IF NOT EXISTS sysupdatetime TIMESTAMP;


SELECT ot.locationid, ot.eventtoken, ot.deviceid, ot.dateid,
    COUNT(*) as dupl
FROM fact.ordertiming as ot
GROUP BY ot.locationid, ot.eventtoken, ot.deviceid, ot.dateid
HAVING COUNT(*) > 1
ORDER BY dupl DESC
LIMIT 100;

ALTER TABLE IF EXISTS fact.ordertiming DROP CONSTRAINT IF EXISTS locationid_eventtoken_unq;
ALTER TABLE IF EXISTS fact.ordertiming ADD CONSTRAINT locationid_eventtoken_unq UNIQUE (locationid, eventtoken, deviceid, sessionstart);

--DELETE FROM fact.ordertiming WHERE sysinserttime = (SELECT max(sysinserttime) FROM fact.ordertiming)

-- Table: fact.ordertiming

-- DROP TABLE IF EXISTS fact.ordertiming;

-- Table: fact.ordertiming

-- DROP TABLE IF EXISTS fact.ordertiming;

CREATE TABLE IF NOT EXISTS fact.ordertiming
(
    id bigint NOT NULL DEFAULT nextval('fact.ordertiming_id_seq'::regclass),
    companyid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    eventtoken text COLLATE pg_catalog."default",
    dateid integer,
    deviceid text COLLATE pg_catalog."default",
    sessionstart timestamp without time zone,
    menustart timestamp without time zone,
    itemstart timestamp without time zone,
    checkoutstart timestamp without time zone,
    paymentstart timestamp without time zone,
    paymentend timestamp without time zone,
    orderend timestamp without time zone,
    starttomenu numeric(7,3),
    menutoitem numeric(7,3),
    itemtocheckout numeric(7,3),
    checkouttopayment numeric(7,3),
    paytopaid numeric(7,3),
    payendtoend numeric(7,3),
    starttocheckout numeric(7,3),
    checkouttoend numeric(7,3),
    totalordertime numeric(7,3),
    sysinserttime timestamp without time zone,
    syscosmosts bigint,
    sysupdatetime TIMESTAMP,
    CONSTRAINT ordertiming_pkey PRIMARY KEY (id),
    CONSTRAINT locationid_eventtoken_unq UNIQUE (locationid, eventtoken)
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.ordertiming
    OWNER to citus;



-- Table: stg.silver_kiosk_events

-- DROP TABLE IF EXISTS stg.silver_kiosk_events;

CREATE TABLE IF NOT EXISTS stg.silver_kiosk_events
(
    id text COLLATE pg_catalog."default",
    application text COLLATE pg_catalog."default",
    companyid text COLLATE pg_catalog."default",
    locationid text COLLATE pg_catalog."default",
    eventmodule text COLLATE pg_catalog."default",
    eventcategory text COLLATE pg_catalog."default",
    eventtype text COLLATE pg_catalog."default",
    severity text COLLATE pg_catalog."default",
    token text COLLATE pg_catalog."default",
    eventinstant text COLLATE pg_catalog."default",
    username text COLLATE pg_catalog."default",
    userid text COLLATE pg_catalog."default",
    device text COLLATE pg_catalog."default",
    devicename text COLLATE pg_catalog."default",
    summary text COLLATE pg_catalog."default",
    data text COLLATE pg_catalog."default",
    syscosmosticks bigint,
    syscosmosts bigint,
    silver_transform_time text COLLATE pg_catalog."default",
    silver_folderpath text COLLATE pg_catalog."default",
    sysinserttime timestamp without time zone
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS stg.silver_kiosk_events
    OWNER to citus;
-- Index: ix_silver_kiosk_events_syscosmosts_brin

-- DROP INDEX IF EXISTS stg.ix_silver_kiosk_events_syscosmosts_brin;

CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_syscosmosts_brin
    ON stg.silver_kiosk_events USING brin
    (syscosmosts)
    WITH (pages_per_range=128)
    TABLESPACE pg_default;


CREATE SEQUENCE IF NOT EXISTS fact.ordertiming_id_seq;

ALTER SEQUENCE fact.ordertiming_id_seq OWNER TO citus;

-- Advance to current max if table already has rows
SELECT setval('fact.ordertiming_id_seq', (SELECT COALESCE(MAX(id), 0) FROM fact.ordertiming));

ALTER TABLE fact.ordertiming
    ALTER COLUMN id SET DEFAULT NEXTVAL('fact.ordertiming_id_seq');



-- ============================================================
-- fact.usp_gem_ordertiming_to_fact_ordertiming
--
-- Source   : stg.silver_kiosk_events
--            eventmodule = 'kiosk', application = 'nge'
--            token non-empty, 7 event type/category combinations
-- Target   : fact.ordertiming
-- Watermark: fact.watermarktable (watermarktablename = 'fact.ordertiming',
--                                  source            = 'gem')
--            Tracked in ts (bigint) via syscosmosts
--            Default: 1720000300 (matches ADF pipeline default)
--
-- Strategy : Insert-only — sessions already in fact.ordertiming
--            are skipped (mirrors ADF negate:true exists check
--            on (locationid, eventtoken))
--
-- Pivoting : 7 event types aggregated per (locationid, companyid,
--            token, device, dateid) into stage timestamps:
--              sessionstart  = MIN(session/started)
--              menustart     = MIN(service/select)
--              itemstart     = MIN(item/selected)
--              checkoutstart = MAX(checkout/viewed)
--              paymentstart  = MIN(payment/create)
--              paymentend    = MAX(order/paid in full)
--              orderend      = MAX(session/closed)
--
-- Durations: EXTRACT(EPOCH FROM (ts2 - ts1)) → seconds
--            ADF minus() returns ms then /1000; PostgreSQL EPOCH
--            returns seconds directly — no /1000 needed
--            NULL → 0 via COALESCE (mirrors ADF iifNull)
-- ============================================================

CREATE OR REPLACE PROCEDURE fact.usp_gem_ordertiming_to_fact_ordertiming()
LANGUAGE plpgsql
AS $BODY$

DECLARE
    v_watermark BIGINT;

BEGIN

    -- ----------------------------------------------------------
    -- Step 1 — Read the current watermark
    -- ----------------------------------------------------------
    SELECT COALESCE(ts, 1720000300) - 10
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.ordertiming'
      AND  source             = 'gem';

    -- ----------------------------------------------------------
    -- Step 2 — Pivot and insert new sessions into fact.ordertiming
    -- ----------------------------------------------------------
    WITH new_events AS (
        -- Filter to the 7 event types needed for ordertiming
        -- and skip sessions already present in the fact table
        -- (mirrors ADF negate:true exists on locationid + token)
        SELECT
            stg.locationid,
            stg.companyid,
            stg.token,
            stg.device,
            -- dateid: mirrors ADF replace(replace(substring(instant,0,13),'-',''),'T','')
            REPLACE(
                REPLACE(SUBSTRING(stg.eventinstant, 1, 13), '-', ''),
                'T', ''
            ) :: INTEGER                                            AS dateid,
            stg.eventcategory                                       AS eventcategory,
            stg.eventtype                                           AS eventtype,
            fact.parse_iso_timestamp(stg.eventinstant) :: TIMESTAMP AS eventinstant,
            stg.syscosmosts
        FROM  stg.silver_kiosk_events AS stg
        WHERE stg.eventmodule   = 'kiosk'
          AND stg.application   = 'nge'
          AND stg.token         > ''
          AND stg.token         IS NOT NULL
          --AND stg.syscosmosts   > v_watermark
          AND (
                  (LOWER(stg.eventcategory) = 'session'  AND LOWER(stg.eventtype) = 'started')
               OR (LOWER(stg.eventcategory) = 'service'  AND LOWER(stg.eventtype) = 'select')
               OR (LOWER(stg.eventcategory) = 'item'     AND LOWER(stg.eventtype) = 'selected')
               OR (LOWER(stg.eventcategory) = 'checkout' AND LOWER(stg.eventtype) = 'viewed')
               OR (LOWER(stg.eventcategory) = 'payment'  AND LOWER(stg.eventtype) = 'create')
               OR (LOWER(stg.eventcategory) = 'order'    AND LOWER(stg.eventtype) = 'paidinfull')
               OR (LOWER(stg.eventcategory) = 'session'  AND LOWER(stg.eventtype) = 'closed')
          )
          AND NOT EXISTS (
                  SELECT 1
                  FROM   fact.ordertiming AS f
                  WHERE  f.locationid  = stg.locationid
                    AND  f.eventtoken  = stg.token
              )
    ),

    aggregated AS (
        -- Pivot 7 event types into one row per session
        -- mirrors ADF aggregate() transformation
        SELECT
            locationid,
            companyid,
            token                                                                                                        AS eventtoken,
            device                                                                                                       AS deviceid,
            dateid,
            MIN(CASE WHEN LOWER(eventcategory) = 'session'  AND LOWER(eventtype) = 'started'      THEN eventinstant END) AS sessionstart,
            MIN(CASE WHEN LOWER(eventcategory) = 'service'  AND LOWER(eventtype) = 'select'       THEN eventinstant END) AS menustart,
            MIN(CASE WHEN LOWER(eventcategory) = 'item'     AND LOWER(eventtype) = 'selected'     THEN eventinstant END) AS itemstart,
            MAX(CASE WHEN LOWER(eventcategory) = 'checkout' AND LOWER(eventtype) = 'viewed'       THEN eventinstant END) AS checkoutstart,
            MIN(CASE WHEN LOWER(eventcategory) = 'payment'  AND LOWER(eventtype) = 'create'       THEN eventinstant END) AS paymentstart,
            MAX(CASE WHEN LOWER(eventcategory) = 'order'    AND LOWER(eventtype) = 'paidinfull'   THEN eventinstant END) AS paymentend,
            MAX(CASE WHEN LOWER(eventcategory) = 'session'  AND LOWER(eventtype) = 'closed'       THEN eventinstant END) AS orderend,
            MAX(syscosmosts)                                                                                             AS syscosmosts
        FROM  new_events
        GROUP BY locationid, companyid, token, device, dateid
    )

    INSERT INTO fact.ordertiming (
        id,
        companyid,
        locationid,
        eventtoken,
        dateid,
        deviceid,
        sessionstart,
        menustart,
        itemstart,
        checkoutstart,
        paymentstart,
        paymentend,
        orderend,
        -- Durations in seconds (EXTRACT(EPOCH) returns seconds directly)
        -- COALESCE to 0 mirrors ADF iifNull(..., 0)
        starttomenu,
        menutoitem,
        itemtocheckout,
        checkouttopayment,
        paytopaid,
        payendtoend,
        starttocheckout,
        checkouttoend,
        totalordertime,
        sysinserttime,
        syscosmosts
        -- id: DEFAULT NEXTVAL('fact.ordertiming_id_seq')
    )
    SELECT
        nextval('fact.ordertiming_id_seq') as id,
        companyid,
        locationid,
        eventtoken,
        dateid,
        deviceid,
        sessionstart,
        menustart,
        itemstart,
        checkoutstart,
        paymentstart,
        paymentend,
        orderend,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (menustart     - sessionstart )) :: NUMERIC, 3), 0) AS starttomenu,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (itemstart     - menustart    )) :: NUMERIC, 3), 0) AS menutoitem,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (checkoutstart - itemstart    )) :: NUMERIC, 3), 0) AS itemtocheckout,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (paymentstart  - checkoutstart)) :: NUMERIC, 3), 0) AS checkouttopayment,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (paymentend    - paymentstart )) :: NUMERIC, 3), 0) AS paytopaid,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (orderend      - paymentend   )) :: NUMERIC, 3), 0) AS payendtoend,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (checkoutstart - sessionstart )) :: NUMERIC, 3), 0) AS starttocheckout,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (orderend      - checkoutstart)) :: NUMERIC, 3), 0) AS checkouttoend,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (orderend      - sessionstart )) :: NUMERIC, 3), 0) AS totalordertime,
        NOW()::timestamp                                                                     AS sysinserttime,
        syscosmosts
    FROM aggregated;

    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- Mirrors ADF: MaxCosmosTs reads MAX(syscosmosts) from fact.ordertiming
    -- ----------------------------------------------------------
    UPDATE fact.watermarktable
    SET    ts = (SELECT COALESCE(MAX(syscosmosts), 1720000300) FROM fact.ordertiming)
    WHERE  watermarktablename = 'fact.ordertiming'
      AND  source             = 'gem';

END;
$BODY$;

ALTER PROCEDURE fact.usp_gem_ordertiming_to_fact_ordertiming() OWNER TO citus;