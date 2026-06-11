-- ============================================================
-- Stored Procedures: fact schema
-- Extracted from gas_db_merged_20260530.sql
-- Generated: 2026-05-30
-- ============================================================


--
-- TOC entry 725 (class 1255 OID 33016)
-- Name: fn_getdata(text, text, text, text); Type: FUNCTION; Schema: fact; Owner: citus
--

CREATE OR REPLACE FUNCTION fact.fn_getdata(aty text, dc text, modid text, appli text) RETURNS TABLE(companyid text, locationid text, eventtoken text, dateid integer, deviceid text, eventinstant timestamp without time zone, duration_type text)
    LANGUAGE plpgsql
    AS $BODY$
        begin 
	        RETURN QUERY
            SELECT
                e.companyid,
                e.locationid,
                e.eventtoken,
                e.dateid,
                e.deviceid,
                MIN(e.eventinstant :: timestamp without time zone) AS eventinstant,
                'starttocheckout':: text AS duration_type
            FROM 
                fact.deviceevent e
            WHERE 
                e.actiontype = aty 
                AND e.datacategory = dc
                AND e.moduleid = modid
                AND e.application = appli
            GROUP BY 
                e.companyid, e.locationid, e.eventtoken, e.dateid, e.deviceid;
        END;
        $BODY$;


ALTER FUNCTION fact.fn_getdata(aty text, dc text, modid text, appli text) OWNER TO citus;

--
-- TOC entry 974 (class 1255 OID 33017)
-- Name: updatewatermark(text); Type: FUNCTION; Schema: fact; Owner: citus
--

CREATE OR REPLACE FUNCTION fact.updatewatermark(tablename text) RETURNS void
    LANGUAGE plpgsql
    AS $BODY$
		DECLARE 
			watermarkvalue timestamp without time zone;
		BEGIN
			SELECT MAX(healthdatatime)
			INTO watermarkvalue
			FROM fact.devicestate;
	
			UPDATE fact.watermarktable
			SET watermarkvalue = watermarkvalue,
                sysupdatetime = NOW() :: TIMESTAMP
			WHERE watermarktablename = tablename;

			RETURN;
		END;
		$BODY$;


ALTER FUNCTION fact.updatewatermark(tablename text) OWNER TO citus;

--
-- TOC entry 798 (class 1255 OID 700154)
-- Name: usp_customer_menu_preferences(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_customer_menu_preferences()
    LANGUAGE sql
    AS $BODY$

TRUNCATE TABLE fact.customer_menu_preferences;

WITH part as (
    SELECT * 
    FROM fact.transactionheader as th
    WHERE 1=1--th.locationid = 'loc-637638f7-ef71-4416-85c3-dd63bb25f77d'
      --AND th.businessdate >= '2025-04-01'
      AND th.orderstatus = 'order-placed'
      AND th.frequentcustomerid is not null
), dayparts AS (
    SELECT th.frequentcustomerid, ti.transactionheaderid, ti.itemid, ti.locationid, th.orderdatelocal,
        CASE WHEN ti.itemtype = 'item' AND ti.dimmenuitemid is not null THEN ti.dimmenuitemid
             WHEN ti.itemtype <> 'item' AND ti.comboid is not null THEN ti.comboid end as dimmenuitemid,
        CASE 
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 6 AND 10  THEN 'Breakfast'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 11 AND 13 THEN 'Lunch'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 14 AND 16 THEN 'Afternoon/Snack'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 17 AND 20 THEN 'Dinner'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) >= 21 OR EXTRACT(HOUR FROM th.orderdatelocal) < 6 THEN 'Late Night'
        END AS day_parts,
        'All Day' as all_day        
    FROM part as th
    inner JOIN fact.transactionitem as ti 
            ON th.transactionheaderid = ti.transactionheaderid
           AND th.locationid = ti.locationid
    WHERE (ti.itemtype = 'item' AND ti.dimmenuitemid is not null)
       OR (ti.itemtype <> 'item' AND ti.comboid is not null)
), agg_dayparts as (
    SELECT locationid,
           frequentcustomerid, 
           day_parts, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, frequentcustomerid, day_parts, dimmenuitemid--, itemtype
), agg_all_day as (
    SELECT locationid,
           frequentcustomerid, 
           all_day, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, frequentcustomerid, all_day, dimmenuitemid--, itemtype
), Ranked1 AS (
    SELECT 
        fc.organizationid as fc_organizationid,
        --ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.frequentcustomerid,
        agg.day_parts,
        agg.itemid,
        it.ItemType,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.frequentcustomerid, agg.day_parts ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_dayparts as agg
    INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), Ranked2 AS (
    SELECT 
        fc.organizationid as fc_organizationid,
        --ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.frequentcustomerid,
        agg.all_day,
        agg.itemid,
        it.ItemType,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.frequentcustomerid, agg.all_day ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_all_day as agg
    INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), total as (
SELECT fc_organizationid as organizationid,
       --ol_organizationid,
       locationid,
       frequentcustomerid,
       day_parts,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked1 WHERE rn <= 10
UNION
SELECT fc_organizationid as organizationid,
       --ol_organizationid,
       locationid,
       frequentcustomerid,
       all_day,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked2 WHERE rn <= 10
--ORDER BY item_selection_frequency desc;
)
INSERT INTO fact.customer_menu_preferences
SELECT * from total
--WHERE fc_organizationid <> ol_organizationid
--ORDER BY frequentcustomerid


$BODY$;


ALTER PROCEDURE fact.usp_customer_menu_preferences() OWNER TO citus;

--
-- TOC entry 870 (class 1255 OID 3654115)
-- Name: usp_gem_ordertiming_to_fact_ordertiming(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_gem_ordertiming_to_fact_ordertiming()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_watermark BIGINT;

BEGIN

    SELECT COALESCE(ts, 1775002010) - 600
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.ordertiming'
      AND  source             = 'gem';

    WITH new_events AS (
        SELECT
            stg.locationid,
            stg.companyid,
            stg.token,
            stg.device,
            stg.eventcategory,
            stg.eventtype,
            fact.parse_iso_timestamp(stg.eventinstant) :: TIMESTAMP AS eventinstant,
            stg.syscosmosts
        FROM  stg.silver_kiosk_events AS stg
        WHERE stg.eventmodule   = 'kiosk'
          AND stg.application   = 'nge'
          AND stg.token         > ''
          AND stg.token         IS NOT NULL
          AND stg.syscosmosts   > v_watermark
          AND (
                  (LOWER(stg.eventcategory) = 'session'  AND LOWER(stg.eventtype) = 'started')
               OR (LOWER(stg.eventcategory) = 'service'  AND LOWER(stg.eventtype) = 'select')
               OR (LOWER(stg.eventcategory) = 'item'     AND LOWER(stg.eventtype) = 'selected')
               OR (LOWER(stg.eventcategory) = 'checkout' AND LOWER(stg.eventtype) = 'viewed')
               OR (LOWER(stg.eventcategory) = 'payment'  AND LOWER(stg.eventtype) = 'create')
               OR (LOWER(stg.eventcategory) = 'order'    AND LOWER(stg.eventtype) = 'paidinfull')
               OR (LOWER(stg.eventcategory) = 'session'  AND LOWER(stg.eventtype) = 'closed')
          )
    ),

    aggregated AS (
        SELECT
            locationid,
            MIN(companyid)                                                                                             AS companyid,
            token                                                                                                      AS eventtoken,
            MIN(device)                                                                                                AS deviceid,
            MIN(CASE WHEN LOWER(eventcategory) = 'session' AND LOWER(eventtype) = 'started'
                     THEN TO_CHAR(eventinstant, 'YYYYMMDDHH24') :: INTEGER END)                  AS dateid,
            MIN(CASE WHEN LOWER(eventcategory) = 'session'  AND LOWER(eventtype) = 'started'    THEN eventinstant END) AS sessionstart,
            MIN(CASE WHEN LOWER(eventcategory) = 'service'  AND LOWER(eventtype) = 'select'     THEN eventinstant END) AS menustart,
            MIN(CASE WHEN LOWER(eventcategory) = 'item'     AND LOWER(eventtype) = 'selected'   THEN eventinstant END) AS itemstart,
            MAX(CASE WHEN LOWER(eventcategory) = 'checkout' AND LOWER(eventtype) = 'viewed'     THEN eventinstant END) AS checkoutstart,
            MIN(CASE WHEN LOWER(eventcategory) = 'payment'  AND LOWER(eventtype) = 'create'     THEN eventinstant END) AS paymentstart,
            MAX(CASE WHEN LOWER(eventcategory) = 'order'    AND LOWER(eventtype) = 'paidinfull' THEN eventinstant END) AS paymentend,
            MAX(CASE WHEN LOWER(eventcategory) = 'session'  AND LOWER(eventtype) = 'closed'     THEN eventinstant END) AS orderend,
            MAX(syscosmosts)                                                                                           AS syscosmosts
        FROM  new_events
        GROUP BY locationid, token
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
    )
    SELECT
        nextval('fact.ordertiming_id_seq')                                                       AS id,
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
        COALESCE(ROUND(EXTRACT(EPOCH FROM (menustart     - sessionstart )) :: NUMERIC, 3), 0)   AS starttomenu,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (itemstart     - menustart    )) :: NUMERIC, 3), 0)   AS menutoitem,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (checkoutstart - itemstart    )) :: NUMERIC, 3), 0)   AS itemtocheckout,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (paymentstart  - checkoutstart)) :: NUMERIC, 3), 0)   AS checkouttopayment,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (paymentend    - paymentstart )) :: NUMERIC, 3), 0)   AS paytopaid,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (orderend      - paymentend   )) :: NUMERIC, 3), 0)   AS payendtoend,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (checkoutstart - sessionstart )) :: NUMERIC, 3), 0)   AS starttocheckout,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (orderend      - checkoutstart)) :: NUMERIC, 3), 0)   AS checkouttoend,
        COALESCE(ROUND(EXTRACT(EPOCH FROM (orderend      - sessionstart )) :: NUMERIC, 3), 0)   AS totalordertime,
        NOW() :: TIMESTAMP                                                                       AS sysinserttime,
        syscosmosts
    FROM aggregated                          -- ← no semicolon here, INSERT continues below

    ON CONFLICT (locationid, eventtoken)
    DO UPDATE SET
        -- Fill NULL timing fields with newly arrived event timestamps
        sessionstart      = COALESCE(fact.ordertiming.sessionstart,  EXCLUDED.sessionstart),
        menustart         = COALESCE(fact.ordertiming.menustart,     EXCLUDED.menustart),
        itemstart         = COALESCE(fact.ordertiming.itemstart,     EXCLUDED.itemstart),
        checkoutstart     = COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart),
        paymentstart      = COALESCE(fact.ordertiming.paymentstart,  EXCLUDED.paymentstart),
        paymentend        = COALESCE(fact.ordertiming.paymentend,    EXCLUDED.paymentend),
        orderend          = COALESCE(fact.ordertiming.orderend,      EXCLUDED.orderend),

        -- Recalculate durations using merged (best available) timestamps
        -- If existing row had sessionstart=NULL but new batch has it,
        -- we now have both ends and can compute the real duration
        starttomenu       = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.menustart,     EXCLUDED.menustart) -
                                COALESCE(fact.ordertiming.sessionstart,  EXCLUDED.sessionstart)
                            )) :: NUMERIC, 3), 0),
        menutoitem        = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.itemstart,     EXCLUDED.itemstart) -
                                COALESCE(fact.ordertiming.menustart,     EXCLUDED.menustart)
                            )) :: NUMERIC, 3), 0),
        itemtocheckout    = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart) -
                                COALESCE(fact.ordertiming.itemstart,     EXCLUDED.itemstart)
                            )) :: NUMERIC, 3), 0),
        checkouttopayment = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.paymentstart,  EXCLUDED.paymentstart) -
                                COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart)
                            )) :: NUMERIC, 3), 0),
        paytopaid         = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.paymentend,    EXCLUDED.paymentend) -
                                COALESCE(fact.ordertiming.paymentstart,  EXCLUDED.paymentstart)
                            )) :: NUMERIC, 3), 0),
        payendtoend       = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.orderend,      EXCLUDED.orderend) -
                                COALESCE(fact.ordertiming.paymentend,    EXCLUDED.paymentend)
                            )) :: NUMERIC, 3), 0),
        starttocheckout   = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart) -
                                COALESCE(fact.ordertiming.sessionstart,  EXCLUDED.sessionstart)
                            )) :: NUMERIC, 3), 0),
        checkouttoend     = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.orderend,      EXCLUDED.orderend) -
                                COALESCE(fact.ordertiming.checkoutstart, EXCLUDED.checkoutstart)
                            )) :: NUMERIC, 3), 0),
        totalordertime    = COALESCE(ROUND(EXTRACT(EPOCH FROM (
                                COALESCE(fact.ordertiming.orderend,      EXCLUDED.orderend) -
                                COALESCE(fact.ordertiming.sessionstart,  EXCLUDED.sessionstart)
                            )) :: NUMERIC, 3), 0),

        -- Always advance to latest known syscosmosts
        syscosmosts       = GREATEST(fact.ordertiming.syscosmosts, EXCLUDED.syscosmosts),
        sysupdatetime     = NOW() :: TIMESTAMP

    -- Only update if at least one timing field can be filled in
    WHERE (
        (fact.ordertiming.sessionstart  IS NULL AND EXCLUDED.sessionstart  IS NOT NULL) OR
        (fact.ordertiming.menustart     IS NULL AND EXCLUDED.menustart     IS NOT NULL) OR
        (fact.ordertiming.itemstart     IS NULL AND EXCLUDED.itemstart     IS NOT NULL) OR
        (fact.ordertiming.checkoutstart IS NULL AND EXCLUDED.checkoutstart IS NOT NULL) OR
        (fact.ordertiming.paymentstart  IS NULL AND EXCLUDED.paymentstart  IS NOT NULL) OR
        (fact.ordertiming.paymentend    IS NULL AND EXCLUDED.paymentend    IS NOT NULL) OR
        (fact.ordertiming.orderend      IS NULL AND EXCLUDED.orderend      IS NOT NULL)
    );

    UPDATE fact.watermarktable
    SET    ts = (SELECT COALESCE(MAX(syscosmosts), 1720000300) FROM fact.ordertiming),
           sysupdatetime = NOW() :: TIMESTAMP
    WHERE  watermarktablename = 'fact.ordertiming'
      AND  source             = 'gem';

END;
$BODY$;

ALTER PROCEDURE fact.usp_gem_ordertiming_to_fact_ordertiming() OWNER TO citus;
--
-- TOC entry 1083 (class 1255 OID 2984304)
-- Name: usp_gem_sent_surveys_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_gem_sent_surveys_to_fact()
    LANGUAGE plpgsql
    AS $BODY$


DECLARE
    v_max_gem_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_gem_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.sent_surveys'
      AND source             = 'gem';

    WITH delta_sent AS (

        SELECT DISTINCT ON (locationid, token)
            locationid,
            token                                           AS ordersessionid,
            NULLIF(ke.data, '') :: jsonb ->> 'orderId'      AS orderid,
            NULLIF(ke.data, '') :: jsonb                    AS survey_metadata,
            eventcategory                                   AS gem_event_category,
            eventtype                                       AS gem_event_type,
            eventinstant                                    AS gem_event_instant,
            syscosmosts                                     AS gem_syscosmosts
        FROM stg.silver_kiosk_events AS ke
        WHERE ke.eventcategory = 'Survey'
          AND ke.eventtype     = 'Sent'
          AND ke.token         > ''
          AND ke.syscosmosts   > v_max_gem_syscosmosts
        ORDER BY locationid, token, syscosmosts DESC

    )
    INSERT INTO fact.sent_surveys (
        organizationid,
        locationid,
        ordersessionid,
        orderid,
        survey_metadata,
        gem_event_category,
        gem_event_type,
        gem_event_instant,
        gem_syscosmosts,
        is_responded,
        sysinserttime
    )
    SELECT
        ol.organizationid,
        ds.locationid,
        ds.ordersessionid,
        ds.orderid,
        ds.survey_metadata,
        ds.gem_event_category,
        ds.gem_event_type,
        ds.gem_event_instant,
        ds.gem_syscosmosts,
        false                   AS is_responded,
        now() :: TIMESTAMP      AS sysinserttime
    FROM delta_sent AS ds
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = ds.locationid
        AND ol.organizationtype = 0
    WHERE NOT EXISTS (
        SELECT 1 FROM fact.sent_surveys AS fs
        WHERE fs.locationid     = ds.locationid
          AND fs.ordersessionid = ds.ordersessionid
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(gem_syscosmosts), 1775002010) FROM fact.sent_surveys),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.sent_surveys'
      AND source             = 'gem';

END;
$BODY$;


ALTER PROCEDURE fact.usp_gem_sent_surveys_to_fact() OWNER TO citus;

--
-- TOC entry 744 (class 1255 OID 3652819)
-- Name: usp_gem_usercheckedin_to_fact_usercheckedin(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_gem_usercheckedin_to_fact_usercheckedin()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_watermark     BIGINT;

BEGIN

    -- ----------------------------------------------------------
    -- Step 1 — Read the current watermark (syscosmosts bigint)
    -- ----------------------------------------------------------
    SELECT COALESCE(ts, 1775002010) - 10
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.usercheckedin'
      AND  source             = 'gem';


    -- ----------------------------------------------------------
    -- Step 2 — Upsert into fact.usercheckedin
    --
    -- data JSON path (FROM sample):
    --   "with request"    : data.request.OrderId
    --                       data.request.Order.OrderIdentity.{Name,Phone}
    --                       data.request.Payments[0].{TotalPaid, PreTipTotal,
    --                         TipAmount, PaymentIntegrationLabel,
    --                         TenderInfo.CardInfo.CardType}
    --   "without request" : data.OrderId
    --                       data.Order.OrderIdentity.{Name,Phone}
    --                       data.Payments[0].{...}
    --
    -- amountpaid : TotalPaid / 100         (cents → USD)
    -- ordertotal : (PreTipTotal + TipAmount) / 100
    -- CardType   : integer code (e.g. 4) — stored as text via jsonb ->>
    -- ----------------------------------------------------------
    WITH parsed AS (
        SELECT
            stg.locationid,
            stg.companyid                                               AS organizationid,
            stg.device                                                  AS kioskid,
            NULLIF(stg.token, '')                                       AS ordersessionid,
            stg.eventinstant                                            AS ordertimestamp,
            stg.syscosmosts,

            -- Payment status — regex guards both "Payments":[] and "Payments": []
            CASE
                WHEN stg.data ~ '"Payments"\s*:\s*\[\s*\]' THEN 'unpaid'
                ELSE 'paid'
            END                                                         AS paymentstatus,

            -- OrderId
            CASE
                WHEN stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' ->> 'OrderId'
                ELSE     stg.data::jsonb ->> 'OrderId'
            END                                                         AS orderid,

            -- CustomerName
            CASE
                WHEN stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' -> 'Order' -> 'OrderIdentity' ->> 'Name'
                ELSE     stg.data::jsonb -> 'Order' -> 'OrderIdentity' ->> 'Name'
            END                                                         AS customername,

            -- CustomerPhone
            CASE
                WHEN stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' -> 'Order' -> 'OrderIdentity' ->> 'Phone'
                ELSE     stg.data::jsonb -> 'Order' -> 'OrderIdentity' ->> 'Phone'
            END                                                         AS customerphone,

            -- AmountPaid: TotalPaid cents → USD
            CASE
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                     AND stg.data LIKE '{"request"%'
                    THEN (stg.data::jsonb -> 'request' -> 'Payments' -> 0 ->> 'TotalPaid')::numeric / 100
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                    THEN (stg.data::jsonb -> 'Payments' -> 0 ->> 'TotalPaid')::numeric / 100
            END                                                         AS amountpaid,

            -- OrderTotal: (PreTipTotal + TipAmount) cents → USD
            CASE
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                     AND stg.data LIKE '{"request"%'
                    THEN (
                            (stg.data::jsonb -> 'request' -> 'Payments' -> 0 ->> 'PreTipTotal')::numeric +
                            (stg.data::jsonb -> 'request' -> 'Payments' -> 0 ->> 'TipAmount')::numeric
                         ) / 100
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                    THEN (
                            (stg.data::jsonb -> 'Payments' -> 0 ->> 'PreTipTotal')::numeric +
                            (stg.data::jsonb -> 'Payments' -> 0 ->> 'TipAmount')::numeric
                         ) / 100
            END                                                         AS ordertotal,

            -- PaymentMethod
            CASE
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                     AND stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' -> 'Payments' -> 0 ->> 'PaymentIntegrationLabel'
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                    THEN stg.data::jsonb -> 'Payments' -> 0 ->> 'PaymentIntegrationLabel'
            END                                                         AS paymentmethod,

            -- PaymentCardType: integer code stored as text (e.g. '4')
            CASE
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                     AND stg.data LIKE '{"request"%'
                    THEN stg.data::jsonb -> 'request' -> 'Payments' -> 0 -> 'TenderInfo' -> 'CardInfo' ->> 'CardType'
                WHEN stg.data NOT SIMILAR TO '%"Payments"\s*:\s*\[\s*\]%'
                    THEN stg.data::jsonb -> 'Payments' -> 0 -> 'TenderInfo' -> 'CardInfo' ->> 'CardType'
            END                                                         AS paymentcardtype

        FROM  stg.silver_kiosk_events AS stg
        WHERE LOWER(stg.eventtype)  = 'usercheckedin'
          AND LOWER(stg.severity)   = 'information'
          AND stg.syscosmosts        > v_watermark
          AND stg.data               IS NOT NULL
          AND EXISTS (
                  SELECT 1
                  FROM   dim.location AS dl
                  WHERE  dl.locationid = stg.locationid
              )
    ),

    deduped AS (
        SELECT DISTINCT ON (locationid, orderid)
            locationid,
            organizationid,
            kioskid,
            ordersessionid,
            ordertimestamp,
            orderid,
            customername,
            customerphone,
            paymentstatus,
            amountpaid,
            ordertotal,
            paymentmethod,
            paymentcardtype,
            syscosmosts
        FROM  parsed
        WHERE orderid IS NOT NULL
        ORDER BY locationid, orderid,
                 ordertimestamp DESC
    )

    INSERT INTO fact.usercheckedin (
        organizationid,
        locationid,
        kioskid,
        ordersessionid,
        ordertimestamp,
        orderid,
        customername,
        customerphone,
        paymentstatus,
        amountpaid,
        ordertotal,
        paymentmethod,
        paymentcardtype,
        syscosmosts,
        sysinserttime
    )
    SELECT
        organizationid,
        locationid,
        kioskid,
        ordersessionid,
        ordertimestamp,
        orderid,
        customername,
        customerphone,
        paymentstatus,
        amountpaid,
        ordertotal,
        paymentmethod,
        paymentcardtype,
        syscosmosts,
        NOW()::timestamp
    FROM deduped
    ON CONFLICT (locationid, orderid)
    DO UPDATE SET
        organizationid  = COALESCE(EXCLUDED.organizationid,  fact.usercheckedin.organizationid),
        kioskid         = COALESCE(EXCLUDED.kioskid,         fact.usercheckedin.kioskid),
        ordersessionid  = COALESCE(EXCLUDED.ordersessionid,  fact.usercheckedin.ordersessionid),
        ordertimestamp  = COALESCE(EXCLUDED.ordertimestamp,  fact.usercheckedin.ordertimestamp),
        customername    = COALESCE(EXCLUDED.customername,    fact.usercheckedin.customername),
        customerphone   = COALESCE(EXCLUDED.customerphone,   fact.usercheckedin.customerphone),
        paymentstatus   = COALESCE(EXCLUDED.paymentstatus,   fact.usercheckedin.paymentstatus),
        amountpaid      = COALESCE(EXCLUDED.amountpaid,      fact.usercheckedin.amountpaid),
        ordertotal      = COALESCE(EXCLUDED.ordertotal,      fact.usercheckedin.ordertotal),
        paymentmethod   = COALESCE(EXCLUDED.paymentmethod,   fact.usercheckedin.paymentmethod),
        paymentcardtype = COALESCE(EXCLUDED.paymentcardtype, fact.usercheckedin.paymentcardtype);

    UPDATE fact.usercheckedin
    SET orderdatelocal = ordertimestamp::TIMESTAMPTZ AT TIME ZONE l.timezone
    FROM dim.organization as l
    WHERE l.id = usercheckedin.locationid 
    and usercheckedin.orderdatelocal IS NULL;

    UPDATE fact.usercheckedin
    SET dateid = cast(to_char(orderdatelocal, 'YYYYMMDDHH24') as integer)
    WHERE dateid IS NULL;
    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- ----------------------------------------------------------
    UPDATE fact.watermarktable
    SET    ts = (SELECT coalesce(max(syscosmosts), 1775002010) FROM fact.usercheckedin),
           sysupdatetime = NOW() :: TIMESTAMP
    WHERE  watermarktablename = 'fact.usercheckedin'
      AND  source             = 'gem';

END;
$BODY$;


ALTER PROCEDURE fact.usp_gem_usercheckedin_to_fact_usercheckedin() OWNER TO citus;

--
-- TOC entry 581 (class 1255 OID 3650132)
-- Name: usp_gsh_devicestate_to_fact_devicestate(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_gsh_devicehealth_to_fact_devicestate()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_watermark     TIMESTAMP;

BEGIN

    -- ----------------------------------------------------------
    -- Step 1 — Read the current watermark
    -- ----------------------------------------------------------
    SELECT COALESCE(watermarkvalue, '1970-01-01 00:00:00'::timestamp)
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.devicestate'
      AND  source             = 'gsh';

    -- ----------------------------------------------------------
    -- Step 2 — Insert qualifying rows into fact.devicestate
    -- ----------------------------------------------------------
    WITH live_locations AS (
        SELECT DISTINCT
            o.id      AS locationid,
            k.kioskid AS deviceid
        FROM  dim.organization AS o
        INNER JOIN dim.kiosk   AS k ON o.id = k.locationid
        WHERE o.active      = true
          AND o.status      = 2
          AND k.istestkiosk = false
    ),

    delta AS (
        SELECT
            stg.companyid,
            stg.locationid,
            stg.deviceid,
            stg.healthdatatime                                          AS lasteventtime,
            stg.statuschangetime,
            ROUND(
                GREATEST(
                    0,
                    EXTRACT(EPOCH FROM (stg.healthdatatime - stg.statuschangetime)) / 60.0
                )::numeric, 3
            )                                                           AS duration,
            REPLACE(
                REPLACE(
                    REPLACE(SUBSTRING(stg.healthdatatime::text, 1, 13), 
                            '-', ''),
                    ' ', ''),
                'T', ''
            ) :: INTEGER                                                AS dateid,
            CASE stg.status
                WHEN 'Ok'      THEN 'Up'
                WHEN 'Dormant' THEN 'Caution'
                WHEN 'Unknown' THEN 'Down'
                ELSE                'PartialUp'
            END                                                         AS state
        FROM  stg.fact_devicestate AS stg
        INNER JOIN live_locations  AS ll
               ON  ll.locationid = stg.locationid
              AND  ll.deviceid   = stg.deviceid
        WHERE stg.healthdatatime > v_watermark
          AND NOT EXISTS (
                  SELECT 1
                  FROM   fact.devicestate AS f
                  WHERE  f.deviceid      = stg.deviceid
                    AND  f.locationid    = stg.locationid
                    AND  f.lasteventtime = stg.healthdatatime
              )
    )

    INSERT INTO fact.devicestate (
        id,
        companyid,
        locationid,
        deviceid,
        dateid,
        state,
        lasteventtime,
        statuschangetime,
        duration,
        sysinserttime
    )
    SELECT
        NEXTVAL('fact.devicestate_id_seq'),
        companyid,
        locationid,
        deviceid,
        dateid,
        state,
        lasteventtime,
        statuschangetime,
        duration,
        NOW()::timestamp
    FROM delta;


    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- ----------------------------------------------------------

        UPDATE fact.watermarktable
        SET    watermarkvalue = (SELECT COALESCE(MAX(lasteventtime) - INTERVAL '10 seconds', '1970-01-01 00:00:00'::TIMESTAMP) FROM fact.devicestate),
               sysupdatetime  = NOW() :: TIMESTAMP
        WHERE  watermarktablename = 'fact.devicestate'
          AND  source             = 'gsh';



END;
$BODY$;


ALTER PROCEDURE fact.usp_gsh_devicehealth_to_fact_devicestate() OWNER TO citus;

--
-- TOC entry 1039 (class 1255 OID 3650138)
-- Name: usp_gsh_devicetelemetry_to_fact_devicetelemetry(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_gsh_devicetelemetry_to_fact_devicetelemetry()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_watermark TIMESTAMP;

BEGIN

    -- ----------------------------------------------------------
    -- Step 1 — Read the current watermark
    -- Conservative: lesser of MAX(cputimestamp) and MAX(memorytimestamp)
    -- mirrors ADF sourcedevicetelemetry query
    -- ----------------------------------------------------------
    SELECT COALESCE(watermarkvalue, '1970-01-01 00:00:00'::timestamp)
    INTO   v_watermark
    FROM   fact.watermarktable
    WHERE  watermarktablename = 'fact.devicetelemetry'
      AND  source             = 'gsh';

    -- ----------------------------------------------------------
    -- Step 2 — Upsert into fact.devicetelemetry
    --
    -- Qualifications:
    --   a) cputimestamp OR memorytimestamp beats the watermark
    --   b) Location is live (dim.organization status=2, active=true,
    --      dim.kiosk istestkiosk=false)
    --   c) locationid exists in dim.organization
    --      (mirrors ADF ExistingLocations exists check)
    --
    -- cpu/memory normalization (mirrors ADF CastFields derivedColumn):
    --   ksk-% devices with value <= 1  → keep as-is (already a ratio)
    --   all others with value > 1      → divide by 100
    --
    -- Upsert key: (deviceid, locationid, dateid)
    --   On conflict: update metric values and timestamps,
    --                preserve original sysinserttime
    -- ----------------------------------------------------------
    WITH live_locations_kiosks AS (
        SELECT DISTINCT
            o.id      AS locationid,
            k.kioskid AS deviceid
        FROM  dim.organization AS o
        INNER JOIN dim.kiosk   AS k ON o.id = k.locationid
        WHERE o.active      = true
          AND o.status      = 2
          AND k.istestkiosk = false
    ),

    delta AS (
        SELECT DISTINCT ON (stg.locationid, stg.deviceid, stg.dateid)
            stg.deviceid,
            stg.locationid,
            stg.dateid,
            stg.cputimestamp,
            stg.memorytimestamp,
            CASE
                WHEN stg.deviceid LIKE 'ksk-%' AND stg.cpuvalue    <= 1 THEN stg.cpuvalue
                WHEN stg.cpuvalue    > 1                                 THEN stg.cpuvalue    / 100
            END AS cpuvalue,
            CASE
                WHEN stg.deviceid LIKE 'ksk-%' AND stg.memoryvalue <= 1 THEN stg.memoryvalue
                WHEN stg.memoryvalue > 1                                 THEN stg.memoryvalue / 100
            END AS memoryvalue
        FROM  stg.fact_devicetelemetry AS stg
        INNER JOIN live_locations_kiosks AS ll
               ON  ll.locationid = stg.locationid
              AND  ll.deviceid   = stg.deviceid
        WHERE EXISTS (
                  SELECT 1
                  FROM   dim.organization AS o
                  WHERE  o.id = stg.locationid
              )
          AND (stg.cputimestamp >= v_watermark OR stg.memorytimestamp >= v_watermark)
        ORDER BY
            stg.deviceid,
            stg.locationid,
            stg.dateid,
            GREATEST(stg.cputimestamp, stg.memorytimestamp) DESC  -- latest reading wins
    )

    INSERT INTO fact.devicetelemetry (
        deviceid,
        locationid,
        dateid,
        cpuvalue,
        memoryvalue,
        cputimestamp,
        memorytimestamp,
        sysinserttime,
        sysupdatetime
    )
    SELECT
        deviceid,
        locationid,
        dateid,
        cpuvalue,
        memoryvalue,
        cputimestamp,
        memorytimestamp,
        NOW()::timestamp,
        NULL
    FROM delta
    ON CONFLICT (deviceid, locationid, dateid)
    DO UPDATE SET
        cpuvalue        = COALESCE(EXCLUDED.cpuvalue,        fact.devicetelemetry.cpuvalue),
        memoryvalue     = COALESCE(EXCLUDED.memoryvalue,     fact.devicetelemetry.memoryvalue),
        cputimestamp    = COALESCE(EXCLUDED.cputimestamp,    fact.devicetelemetry.cputimestamp),
        memorytimestamp = COALESCE(EXCLUDED.memorytimestamp, fact.devicetelemetry.memorytimestamp),
        sysupdatetime   = NOW()::timestamp;
        -- sysinserttime deliberately excluded — preserves original insert time

    -- ----------------------------------------------------------
    -- Step 3 — Advance the watermark
    -- Conservative: lesser of MAX(cputimestamp) and MAX(memorytimestamp)
    -- ----------------------------------------------------------
    UPDATE fact.watermarktable
    SET    watermarkvalue = (
               SELECT LEAST(MAX(cputimestamp), MAX(memorytimestamp)) - INTERVAL '10 seconds'
               FROM   fact.devicetelemetry
           ),
           sysupdatetime = NOW() :: TIMESTAMP
    WHERE  watermarktablename = 'fact.devicetelemetry'
      AND  source             = 'gsh';

END;
$BODY$;


ALTER PROCEDURE fact.usp_gsh_devicetelemetry_to_fact_devicetelemetry() OWNER TO citus;

--
-- TOC entry 901 (class 1255 OID 2874333)
-- Name: usp_item_recommendations_stage_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_item_recommendations_stage_to_fact()
    LANGUAGE plpgsql
    AS $BODY$

BEGIN

insert into fact.recommendations 
(transactionheaderid, locationid, recommendationid, offereditems, selecteditems, isconverted, prompttimestamp, sysinserttime, syscosmosts)
select rc.transactionheaderid,
       rc.locationid,
       rc.recommendationid, 
       rc.offereditems :: jsonb, 
       rc.selecteditems :: jsonb, 
       case when (rc.selecteditems = '[]' or rc.selecteditems is null) then false else true end as isconverted,
       rc.prompttimestamp, 
       rc.sysinserttime,
       rc.syscosmosts
from stg.recommendations as rc
where not exists (select 1 from fact.recommendations as th where th.transactionheaderid = rc.transactionheaderid and th.recommendationid = rc.recommendationid);

END;
$BODY$;


ALTER PROCEDURE fact.usp_item_recommendations_stage_to_fact() OWNER TO citus;

--
-- TOC entry 630 (class 1255 OID 700153)
-- Name: usp_location_menu_preferences(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_location_menu_preferences()
    LANGUAGE sql
    AS $BODY$

TRUNCATE TABLE fact.location_menu_preferences;

WITH part as (
    SELECT * 
    FROM fact.transactionheader as th
    WHERE 1=1 
      --AND th.locationid = 'loc-x4pw1awq97'-- 'loc-637638f7-ef71-4416-85c3-dd63bb25f77d'
      --AND th.businessdate >= '2025-04-01'
      AND th.orderstatus = 'order-placed'
), dayparts AS (
    SELECT ti.transactionheaderid, ti.itemid, ti.locationid, th.orderdatelocal,
        CASE WHEN ti.itemtype = 'item' AND ti.dimmenuitemid is not null THEN ti.dimmenuitemid
             WHEN ti.itemtype <> 'item' AND ti.comboid is not null THEN ti.comboid end as dimmenuitemid,
        CASE 
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 6 AND 10  THEN 'Breakfast'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 11 AND 13 THEN 'Lunch'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 14 AND 16 THEN 'Afternoon/Snack'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) BETWEEN 17 AND 20 THEN 'Dinner'
            WHEN EXTRACT(HOUR FROM th.orderdatelocal) >= 21 OR EXTRACT(HOUR FROM th.orderdatelocal) < 6 THEN 'Late Night'
        END AS day_parts,
        'All Day' as all_day        
    FROM part as th
    INNER JOIN fact.transactionitem as ti 
            ON th.transactionheaderid = ti.transactionheaderid
           AND th.locationid = ti.locationid
    WHERE (ti.itemtype = 'item' AND ti.dimmenuitemid is not null)
       OR (ti.itemtype <> 'item' AND ti.comboid is not null)
), agg_dayparts as (
    SELECT locationid,
           day_parts, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, day_parts, dimmenuitemid--, itemtype
), agg_all_day as (
    SELECT locationid,
           all_day, 
           dimmenuitemid as itemid,
           --itemtype,
           COUNT(*) as OrdersCount
    FROM dayparts
    GROUP BY locationid, all_day, dimmenuitemid--, itemtype
), Ranked1 AS (
    SELECT 
        --fc.organizationid as fc_organizationid,
        ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.day_parts,
        agg.itemid,
        it.itemtype,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.day_parts ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_dayparts as agg
    --INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT * FROM dim.organizationlocation where organizationtype = 0) as ol on agg.locationid = ol.locationid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), Ranked2 AS (
    SELECT 
        --fc.organizationid as fc_organizationid,
        ol.organizationid as ol_organizationid,
        agg.locationid,
        agg.all_day,
        agg.itemid,
        it.itemtype,
        agg.OrdersCount AS item_selection_frequency,
        NULL AS ItemTags,
        ROW_NUMBER() OVER(PARTITION BY agg.locationid, agg.all_day ORDER BY agg.OrdersCount DESC) AS rn
    FROM agg_all_day as agg
    --INNER JOIN dim.frequentcustomer as fc ON agg.frequentcustomerid = fc.frequentcustomerid
    INNER JOIN (SELECT * FROM dim.organizationlocation where organizationtype = 0) as ol on agg.locationid = ol.locationid
    INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' AND dimmenuitemid is not null THEN dimmenuitemid
                                     WHEN itemtype <> 'item' AND comboid is not null THEN comboid end as itemid, itemtype 
                FROM fact.transactionitem 
                WHERE (itemtype = 'item' AND dimmenuitemid is not null)
                   OR (itemtype <> 'item' AND comboid is not null)) as it 
            ON agg.itemid = it.itemid
), total as (
SELECT --fc_organizationid as organizationid,
       ol_organizationid as organizationid,
       locationid,
       day_parts,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked1 WHERE rn <= 10
UNION
SELECT --fc_organizationid as organizationid,
       ol_organizationid as organizationid,
       locationid,
       all_day,
       itemid,
       ItemType,
       item_selection_frequency,
       ItemTags :: jsonb,
       now() as sysinserttime
FROM Ranked2 WHERE rn <= 10
--ORDER BY item_selection_frequency desc;
)
INSERT INTO fact.location_menu_preferences
SELECT * from total
--WHERE fc_organizationid <> ol_organizationid
--ORDER BY item_selection_frequency desc

$BODY$;


ALTER PROCEDURE fact.usp_location_menu_preferences() OWNER TO citus;

--
-- TOC entry 960 (class 1255 OID 2247996)
-- Name: usp_location_statistics(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_location_statistics()
    LANGUAGE plpgsql
    AS $BODY$

BEGIN

TRUNCATE TABLE fact.location_statistics;

WITH org_loc_lookup AS (
    SELECT DISTINCT ol.organizationid, ol.organizationname, 
           ol.locationid, ol.locationname
    FROM dim.organizationlocation AS ol
    WHERE 1=1 
      --AND (CASE WHEN 'com-3owh66znkd' NOT LIKE 'loc-%' THEN ol.organizationid ELSE ol.locationid END) = 'com-3owh66znkd'
      AND ol.organizationtype = 0
), order_items AS (
    SELECT ti.*
    FROM (
        SELECT ol.organizationid, ol.organizationname, ol.locationname, ti.* 
        FROM fact.transactionitem AS ti
        INNER JOIN org_loc_lookup as ol
			ON ti.locationid = ol.locationid
        WHERE 1=1
          AND ti.transactionheaderid LIKE 'ordevt-%'
    ) as ti
), frequent_customers as (
    SELECT fc.organizationid, 
           count(*) as number_of_frequent_customers,
           sum(fc.ordercount) as orders_placed_by_freq_customers,
           sum(fc.amountspent) as amount_spent_by_freq_customers,
           sum(fc.amountspent) / case when sum(fc.ordercount) > 0 then sum(fc.ordercount) else 1 end as avg_amount_spent_by_freq_customers
    FROM dim.frequentcustomer as fc
    GROUP BY fc.organizationid
), org_agg_trxn as (
	SELECT ol.organizationid, 
           count(*) as org_total_order_count,
           sum(th.ordertotal) as org_total_sales_amount,
           round(avg(th.ordertotal), 3) as org_avg_order_amount
	FROM fact.transactionheader as th 
    INNER JOIN org_loc_lookup as ol
            ON th.locationid = ol.locationid
    WHERE th.orderstatus = 'order-placed'
	GROUP BY organizationid
), loc_agg_trxn as (
	SELECT th.locationid, 
           count(*) as loc_total_order_count,
           sum(th.ordertotal) as loc_total_sales_amount,
           round(avg(th.ordertotal), 3) as loc_avg_order_amount
	FROM fact.transactionheader as th 
    WHERE th.orderstatus = 'order-placed'
	GROUP BY th.locationid
), loc_agg as (
	SELECT organizationid, locationid, 
           count(*) as total_items_ordered_within_loc
	FROM order_items
	GROUP BY organizationid, locationid
), loc_itm_agg as (
	SELECT organizationid, locationid, dimmenuitemid, 
    count(*) as item_selection_frequency_within_loc,
    max(itemunitprice) as itemunitprice
	FROM order_items
	GROUP BY organizationid, locationid, dimmenuitemid
), item_statistics AS (
	SELECT lia.organizationid, lia.locationid, lia.dimmenuitemid, lia.itemunitprice,
           lia.item_selection_frequency_within_loc,
           la.total_items_ordered_within_loc,
           100 * lia.item_selection_frequency_within_loc :: NUMERIC(8,3) / la.total_items_ordered_within_loc as pct_item_selection_freq_within_loc,
           dense_rank() OVER(PARTITION by lia.locationid ORDER BY item_selection_frequency_within_loc DESC) as loc_item_popularity
	FROM loc_itm_agg as lia
    INNER JOIN loc_agg as la 
            ON lia.organizationid = la.organizationid
           AND lia.locationid = la.locationid
), item_details AS (
    SELECT its.organizationid, its.locationid, 
    jsonb_agg(
        jsonb_build_object(
            'menuitemid', its.dimmenuitemid, 
            'x_times_selected', its.item_selection_frequency_within_loc,
            'total_items_selected', its.total_items_ordered_within_loc,
            'pct_of_all_items',  its.pct_item_selection_freq_within_loc,
            'item_class_type', mi.item_class_type,
            'itemunitprice', COALESCE(its.itemunitprice, mi.itemunitprice),
            'loc_item_popularity', loc_item_popularity
        ) ORDER BY loc_item_popularity ASC, item_selection_frequency_within_loc DESC
    ) as loc_item_popularity
    FROM item_statistics as its 
    LEFT JOIN dim.menuitem as mi
           ON its.dimmenuitemid = mi.menuitemid
    WHERE loc_item_popularity <= 20
    GROUP BY its.organizationid, its.locationid
), order_types AS (
SELECT locationid, jsonb_agg(value->>'label') AS order_type_labels
FROM (SELECT * FROM dim.kioskdetails 
      WHERE dim.is_valid_jsonb(order_types) 
        AND locationid IN (SELECT locationid FROM org_loc_lookup)
      ) as ld
CROSS JOIN LATERAL jsonb_each(ld.order_types :: jsonb -> 'options')
GROUP BY locationid
)
INSERT INTO fact.location_statistics
SELECT DISTINCT 
olk.organizationid,
olk.organizationname,
olk.locationid,
olk.locationname,
l.city,
l.state,
l.country,
l.active as isactive,
l.timezone,
ot.order_type_labels,
itd.loc_item_popularity,
COALESCE(la.loc_total_order_count, 0) as loc_total_order_count,
COALESCE(la.loc_total_sales_amount, 0) as loc_total_sales_amount,
COALESCE(la.loc_avg_order_amount, 0) as loc_avg_order_amount,
COALESCE(oa.org_total_order_count, 0) as org_total_order_count,
COALESCE(oa.org_total_sales_amount, 0) as org_total_sales_amount,
COALESCE(oa.org_avg_order_amount, 0) as org_avg_order_amount,
COALESCE(fc.number_of_frequent_customers, 0) as number_of_frequent_customers,
COALESCE(fc.orders_placed_by_freq_customers, 0) as orders_placed_by_freq_customers,
COALESCE(fc.amount_spent_by_freq_customers, 0) as amount_spent_by_freq_customers,
COALESCE(ROUND(fc.avg_amount_spent_by_freq_customers, 3), 0) as avg_amount_spent_by_freq_customers,
now() :: TIMESTAMP as sysupdatetime
FROM org_loc_lookup as olk
LEFT JOIN dim.organization as l
       ON olk.locationid = l.id
LEFT JOIN order_types as ot
       ON olk.locationid = ot.locationid
LEFT JOIN item_details as itd
       ON olk.locationid = itd.locationid
LEFT JOIN loc_agg_trxn as la 
       ON olk.locationid = la.locationid
LEFT JOIN org_agg_trxn as oa
       ON olk.organizationid = oa.organizationid
LEFT JOIN frequent_customers as fc 
       ON olk.organizationid = fc.organizationid;

END;
$BODY$;


ALTER PROCEDURE fact.usp_location_statistics() OWNER TO citus;

--
-- TOC entry 525 (class 1255 OID 2951716)
-- Name: usp_modifier_impression_analysis(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_modifier_impression_analysis()
    LANGUAGE plpgsql
    AS $BODY$


BEGIN

WITH delta_impressions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_impressions' AND source = 'nge')
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_impressions as mim 
                  WHERE mim.locationid = mrc.locationid
                    AND mim.transactionheaderid = mrc.transactionheaderid)
), modifier_impressions AS (
SELECT mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       CASE WHEN mrc.orderid LIKE 'ord-%' AND LENGTH(mrc.orderid) > 4  THEN mrc.orderid
            WHEN mrc.orderid    = 'ord-'  AND mrc.ordersessionid <> '' THEN CONCAT(mrc.orderid, mrc.ordersessionid)
            ELSE CONCAT('ord-', SUBSTRING(mrc.transactionheaderid, 8, LENGTH(mrc.transactionheaderid)))
       END as orderid,                
       outer_elem->>'itemId'                 AS menuitemid,
       rec->>'modifierId'                    AS modifierid,
       outer_elem->>'parentModifierId'       AS parent_modifier_id,
       outer_elem->>'selectionType'          AS selection_type,
      (outer_elem->>'nestingDepth')::INTEGER AS nesting_depth,    
      (rec->>'position')::INTEGER            AS position,
      (rec->>'score')::NUMERIC(5, 3)         AS score,
       outer_elem->>'strategy'               AS strategy,
       outer_elem->>'context'                AS context,
      (rec->>'selected')::boolean            AS selected,
      (rec->>'preDeselected')::boolean       AS pre_deselected,
      (rec->>'confirmedRemoved')::boolean    AS confirmed_removed,
      (rec->>'preSelected')::boolean         AS pre_selected,
       mrc.businessdate, 
       mrc.orderdatelocal,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime    
FROM delta_impressions as mrc,
    -- Step 1: unnest the top-level array
    jsonb_array_elements(modifier_impressions) AS outer_elem,
    -- Step 2: unnest the nested recommendations array
    jsonb_array_elements(outer_elem->'recommendations') AS rec
)
INSERT INTO fact.modifier_impressions
SELECT *, NULL :: TIMESTAMP as sysupdatetime
FROM modifier_impressions;

UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_impressions),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_impressions'
  AND source = 'nge';

END;
$BODY$;


ALTER PROCEDURE fact.usp_modifier_impression_analysis() OWNER TO citus;

--
-- TOC entry 1354 (class 1255 OID 2951719)
-- Name: usp_modifier_interaction_analysis(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_modifier_interaction_analysis()
    LANGUAGE plpgsql
    AS $BODY$

BEGIN

WITH delta_interactions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge-Interactions')
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_interactions as mim 
                  WHERE mim.locationid = mrc.locationid
                    AND mim.transactionheaderid = mrc.transactionheaderid)
), modifier_interactions AS (
SELECT mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       CASE WHEN mrc.orderid LIKE 'ord-%' AND LENGTH(mrc.orderid) > 4  THEN mrc.orderid
            WHEN mrc.orderid    = 'ord-'  AND mrc.ordersessionid <> '' THEN CONCAT(mrc.orderid, mrc.ordersessionid)
            ELSE CONCAT('ord-', SUBSTRING(mrc.transactionheaderid, 8, LENGTH(mrc.transactionheaderid)))
       END as orderid,                
       outer_elem->>'itemId' as menuitemid,
       outer_elem->>'action' as action,
       outer_elem->>'modifierId' as modifierid,
       (outer_elem->>'recordedAt')::TIMESTAMP as recorded_at,
       (outer_elem->>'nestingDepth') :: INTEGER as nesting_depth,
       outer_elem->>'selectionType' as selection_type,
       outer_elem->>'modifierGroupId' as modifiergroupid,
       outer_elem->>'parentModifierId' as parent_modifier_id,
       mrc.businessdate, 
       mrc.orderdatelocal,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime    
FROM delta_interactions as mrc,
    -- Step 1: unnest the top-level array
    jsonb_array_elements(modifier_interactions) AS outer_elem
), trxn_enrichment AS (
SELECT mi.locationid,
       mi.transactionheaderid,
       mi.ordersessionid,
       CASE WHEN mi.orderid LIKE 'ord-%' AND LENGTH(mi.orderid) > 4  THEN mrc.orderid
            WHEN mi.orderid    = 'ord-'  AND mi.ordersessionid <> '' THEN CONCAT(mi.orderid, mi.ordersessionid)
            ELSE CONCAT('ord-', SUBSTRING(mi.transactionheaderid, 8, LENGTH(mi.transactionheaderid)))
       END as orderid,                
       imd.itemid as orderitemid,
       mi.menuitemid,
       mi.modifiergroupid,
       mi.modifierid,
       imd.modifiername,
       mi.parent_modifier_id,
       mi.nesting_depth,
       imd.modifierquantity,
       imd.modifierprice,
       imd.freequantity,
       mi.selection_type,
       mi.action,
       mi.recorded_at as session_recorded_at,
       mi.businessdate,
       mi.orderdatelocal,
       mi.frequentcustomerid,
       mi.syscosmosts,
       mi.sysinserttime
    FROM modifier_interactions as mi 
    LEFT JOIN fact.transactionitem as ti 
        ON mi.locationid = ti.locationid
        AND mi.transactionheaderid = ti.transactionheaderid
        AND mi.menuitemid = ti.dimmenuitemid
    LEFT JOIN fact.itemmodifier as imd 
        ON mi.transactionheaderid = imd.transactionheaderid
        AND ti.itemid = imd.itemid
        AND mi.modifiergroupid = imd.modifiergroupid
        AND mi.modifierid = imd.modifierid
)
INSERT INTO fact.modifier_interactions
SELECT *, 
       NULL :: TIMESTAMP as sysupdatetime, 
       5 as sourceid
FROM trxn_enrichment;

UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_interactions WHERE sourceid = 5),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge-Interactions';


WITH delta_modifier_trxns AS (
SELECT *
FROM fact.itemmodifier as im
WHERE locationid LIKE 'loc-%'
  AND (syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge-Options') OR
       syscosmosts IS NULL)
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_interactions as mint 
                  WHERE mint.locationid = im.locationid
                    AND mint.transactionheaderid = im.transactionheaderid)
), modfr_enrichment AS (
SELECT mt.locationid,
       mt.transactionheaderid,
       ti.ordersessionid,
       ti.orderid,                
       ti.itemid as orderitemid,
       ti.dimmenuitemid as menuitemid,
       mt.modifiergroupid,
       mt.modifierid,
       mt.modifiername,
       NULL :: TEXT as parent_modifier_id,
       NULL :: INTEGER as nesting_depth,
       mt.modifierquantity,
       mt.modifierprice,
       mt.freequantity,
       CASE WHEN mgm.is_default = False AND mg.min_selection = 0 AND mg.max_selection >= 0 THEN 'optional'
            WHEN mgm.is_default = False AND mg.min_selection >= 1 AND mg.max_selection >= 1 THEN 'required'
            WHEN mgm.is_default = True THEN 'default' END selection_type,

       CASE WHEN mgm.is_default = False AND mg.min_selection = 0 AND mg.max_selection >= 0 AND mt.modifierquantity >= 1 THEN 'added'                  --optional modifier added
            WHEN mgm.is_default = False AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'selected'              --required modifier selected
            WHEN mgm.is_default = True AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity >= 1 THEN 'kept'                   --default modifier left selected
            WHEN mgm.is_default = True AND mg.min_selection >= 1 AND mg.max_selection >= 1 AND mt.modifierquantity = 0 THEN 'removed' END AS action,  --default modifier de-selected
       NULL :: TEXT as session_recorded_at,
       mt.businessdate,
       ti.orderdatelocal,
       ti.frequentcustomerid,
       mt.syscosmosts,
       mt.sysinserttime
FROM delta_modifier_trxns as mt
LEFT JOIN dim.modifier_group_mapping as mgm
    ON mgm.modifiergroupid = mt.modifiergroupid
    AND mgm.modifierid = mt.modifierid
LEFT JOIN dim.modifier_group as mg 
    ON mg.modifiergroupid = mt.modifiergroupid
LEFT JOIN fact.transactionitem as ti 
    ON mt.transactionheaderid = ti.transactionheaderid
    AND mt.itemid = ti.itemid
)
INSERT INTO fact.modifier_interactions
SELECT *, 
       NULL :: TIMESTAMP as sysupdatetime, 
       6 as sourceid
FROM modfr_enrichment;


/*
UPDATE fact.modifier_interactions
SET modifierquantity = im.modifierquantity,
    modifierprice = im.modifierprice,
    freequantity = im.freequantity
FROM fact.itemmodifier as im 
WHERE modifier_interactions.transactionheaderid = im.transactionheaderid
  AND modifier_interactions.orderid = im.orderid 
  AND modifier_interactions.modifiergroupid = im.modifiergroupid
  AND modifier_interactions.modifierid = im.modifierid
  AND modifier_interactions.modifierquantity IS NULL
  AND modifier_interactions.modifierprice IS NULL
  AND modifier_interactions.freequantity IS NULL;
*/
UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(syscosmosts), 1775002010) - 10 FROM fact.modifier_interactions WHERE sourceid = 6),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge-Options';

END;
$BODY$;


ALTER PROCEDURE fact.usp_modifier_interaction_analysis() OWNER TO citus;

--
-- TOC entry 540 (class 1255 OID 2874430)
-- Name: usp_modifier_recommendation_analysis(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_modifier_recommendation_analysis()
    LANGUAGE plpgsql
    AS $BODY$

BEGIN

WITH delta_impressions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_impressions')
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_impressions as mim 
                  WHERE mim.locationid = mrc.locationid
                    AND mim.transactionheaderid = mrc.transactionheaderid)
), modifier_impressions AS (
SELECT mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       CASE WHEN mrc.orderid LIKE 'ord-%' AND LENGTH(mrc.orderid) > 4  THEN mrc.orderid
            WHEN mrc.orderid    = 'ord-'  AND mrc.ordersessionid <> '' THEN CONCAT(mrc.orderid, mrc.ordersessionid)
            ELSE CONCAT('ord-', SUBSTRING(mrc.transactionheaderid, 8, LENGTH(mrc.transactionheaderid)))
       END as orderid,                
       outer_elem->>'itemId'                 AS menuitemid,
       rec->>'modifierId'                    AS modifierid,
       outer_elem->>'parentModifierId'       AS parent_modifier_id,
       outer_elem->>'selectionType'          AS selection_type,
      (outer_elem->>'nestingDepth')::INTEGER AS nesting_depth,    
      (rec->>'position')::INTEGER            AS position,
      (rec->>'score')::NUMERIC(5, 3)         AS score,
       outer_elem->>'strategy'               AS strategy,
       outer_elem->>'context'                AS context,
      (rec->>'selected')::boolean            AS selected,
      (rec->>'preDeselected')::boolean       AS pre_deselected,
      (rec->>'confirmedRemoved')::boolean    AS confirmed_removed,
      (rec->>'preSelected')::boolean         AS pre_selected,
       mrc.businessdate, 
       mrc.orderdatelocal,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime    
FROM delta_impressions as mrc,
    -- Step 1: unnest the top-level array
    jsonb_array_elements(modifier_impressions) AS outer_elem,
    -- Step 2: unnest the nested recommendations array
    jsonb_array_elements(outer_elem->'recommendations') AS rec
)
INSERT INTO fact.modifier_impressions
SELECT *, NULL :: TIMESTAMP as sysupdatetime
FROM modifier_impressions;

UPDATE fact.watermarktable
SET ts = (SELECT max(syscosmosts) - 10 FROM fact.modifier_impressions),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_impressions'
  AND source = 'nge';

WITH delta_interactions AS (
SELECT *
FROM fact.modifier_recommendations as mrc
WHERE syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge')
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_interactions as mim 
                  WHERE mim.locationid = mrc.locationid
                    AND mim.transactionheaderid = mrc.transactionheaderid)
), modifier_interactions AS (
SELECT mrc.locationid,
       mrc.transactionheaderid,
       mrc.ordersessionid,
       CASE WHEN mrc.orderid LIKE 'ord-%' AND LENGTH(mrc.orderid) > 4  THEN mrc.orderid
            WHEN mrc.orderid    = 'ord-'  AND mrc.ordersessionid <> '' THEN CONCAT(mrc.orderid, mrc.ordersessionid)
            ELSE CONCAT('ord-', SUBSTRING(mrc.transactionheaderid, 8, LENGTH(mrc.transactionheaderid)))
       END as orderid,                
       outer_elem->>'itemId' as menuitemid,
       outer_elem->>'action' as action,
       outer_elem->>'modifierId' as modifierid,
       (outer_elem->>'recordedAt')::TIMESTAMP as recorded_at,
       (outer_elem->>'nestingDepth') :: INTEGER as nesting_depth,
       outer_elem->>'selectionType' as selection_type,
       outer_elem->>'modifierGroupId' as modifiergroupid,
       outer_elem->>'parentModifierId' as parent_modifier_id,
       mrc.businessdate, 
       mrc.orderdatelocal,
       mrc.frequentcustomerid,
       mrc.syscosmosts,
       mrc.sysinserttime    
FROM delta_interactions as mrc,
    -- Step 1: unnest the top-level array
    jsonb_array_elements(modifier_interactions) AS outer_elem
), trxn_enrichment AS (
SELECT mi.locationid,
       mi.transactionheaderid,
       mi.ordersessionid,
       mi.orderid,
       imd.itemid as orderitemid,
       mi.menuitemid,
       mi.modifiergroupid,
       mi.modifierid,
       imd.modifiername,
       mi.parent_modifier_id,
       mi.nesting_depth,
       imd.modifierquantity,
       imd.modifierprice,
       imd.freequantity,
       mi.selection_type,
       mi.action,
       mi.recorded_at as session_recorded_at,
       mi.businessdate,
       mi.orderdatelocal,
       mi.frequentcustomerid,
       mi.syscosmosts,
       mi.sysinserttime
    FROM modifier_interactions as mi 
    LEFT JOIN fact.transactionitem as ti 
        ON mi.locationid = ti.locationid
        AND mi.transactionheaderid = ti.transactionheaderid
        AND mi.menuitemid = ti.dimmenuitemid
    LEFT JOIN fact.itemmodifier as imd 
        ON mi.transactionheaderid = imd.transactionheaderid
        AND ti.itemid = imd.itemid
        AND mi.modifiergroupid = imd.modifiergroupid
        AND mi.modifierid = imd.modifierid
)
INSERT INTO fact.modifier_interactions
SELECT *, NULL :: TIMESTAMP as sysupdatetime
FROM trxn_enrichment;

UPDATE fact.watermarktable
SET ts = (SELECT max(syscosmosts) - 10 FROM fact.modifier_interactions WHERE modifiername IS NOT NULL),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge';


WITH delta_modifier_trxns AS (
SELECT *
FROM fact.itemmodifier as im
WHERE (syscosmosts > (SELECT ts FROM fact.watermarktable WHERE watermarktablename = 'fact.modifier_interactions' AND source = 'nge-Options') OR
       syscosmosts IS NULL)
  AND NOT EXISTS (SELECT 1 FROM fact.modifier_interactions as mint 
                  WHERE mint.locationid = im.locationid
                    AND mint.transactionheaderid = im.transactionheaderid)
), modfr_enrichment AS (
SELECT mt.locationid,
       mt.transactionheaderid,
       ti.ordersessionid,
       ti.orderid,
       ti.itemid as orderitemid,
       ti.dimmenuitemid as menuitemid,
       mt.modifiergroupid,
       mt.modifierid,
       mt.modifiername,
       NULL :: TEXT as parent_modifier_id,
       NULL :: INTEGER as nesting_depth,
       mt.modifierquantity,
       mt.modifierprice,
       mt.freequantity,
       CASE WHEN m.min_quantity = 0 AND m.max_quantity > 0 THEN 'optional'
            WHEN m.min_quantity >= 1 AND m.max_quantity >= 1 THEN 'default' END selection_type,
       CASE WHEN m.min_quantity = 0 AND m.max_quantity > 0 AND mt.modifierquantity > 0 THEN 'added'
            WHEN m.min_quantity >= 1 AND m.max_quantity >= 1 AND mt.modifierquantity >= 1 THEN 'kept'
            WHEN m.min_quantity >= 1 AND m.max_quantity >= 1 AND mt.modifierquantity = 0 THEN 'removed' END AS action,
       NULL :: TEXT as session_recorded_at,
       mt.businessdate,
       ti.orderdatelocal,
       ti.frequentcustomerid,
       mt.syscosmosts,
       mt.sysinserttime
FROM delta_modifier_trxns as mt
LEFT JOIN dim.modifier as m 
    ON mt.modifierid = m.modifierid
LEFT JOIN fact.transactionitem as ti 
    ON mt.transactionheaderid = ti.transactionheaderid
    AND mt.itemid = ti.itemid
)
INSERT INTO fact.modifier_interactions
SELECT *, NULL :: TIMESTAMP as sysupdatetime 
FROM modfr_enrichment;

UPDATE fact.modifier_interactions
SET modifierquantity = im.modifierquantity,
    modifierprice = im.modifierprice,
    freequantity = im.freequantity
FROM fact.itemmodifier as im 
WHERE modifier_interactions.transactionheaderid = im.transactionheaderid
  AND modifier_interactions.orderid = im.orderid 
  AND modifier_interactions.modifiergroupid = im.modifiergroupid
  AND modifier_interactions.modifierid = im.modifierid
  AND modifier_interactions.modifierquantity IS NULL
  AND modifier_interactions.modifierprice IS NULL
  AND modifier_interactions.freequantity IS NULL;

UPDATE fact.watermarktable
SET ts = (SELECT max(syscosmosts) - 10 FROM fact.modifier_interactions WHERE modifiername IS NOT NULL),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.modifier_interactions'
  AND source = 'nge-Options';

END;
$BODY$;


ALTER PROCEDURE fact.usp_modifier_recommendation_analysis() OWNER TO citus;

--
-- TOC entry 1117 (class 1255 OID 3615966)
-- Name: usp_nge_update_itemssurvey(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_nge_update_itemssurvey()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_max_nge_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_nge_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'nge';


    WITH delta_responses AS (

        SELECT DISTINCT ON (locationid, orderid, surveyid, itemid)
            locationid,
            orderid,
            surveyid,
            surveytransid,
            itemid,
            itemrating,
            surveytransstatus,
            surveycompletedtimestamp,
            nge_syscosmosts
        FROM stg.fact_itemssurvey
        WHERE nge_syscosmosts > v_max_nge_syscosmosts
        ORDER BY locationid, orderid, surveyid, itemid, nge_syscosmosts DESC

    )
    UPDATE fact.itemssurvey AS f
    SET
        organizationid              = COALESCE(os.organizationid, ol.organizationid),
        surveytransid               = dr.surveytransid,
        itemrating                  = dr.itemrating,
        surveytransstatus           = dr.surveytransstatus,
        surveycompletedtimestamp    = dr.surveycompletedtimestamp,
        nge_syscosmosts             = dr.nge_syscosmosts,
        is_responded                = CASE WHEN dr.surveytransstatus = '2'
                                          THEN true ELSE false END,
        sysupdatetime               = now() :: TIMESTAMP
    FROM delta_responses AS dr
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = dr.locationid
        AND th.transactionheaderid = dr.orderid
        AND th.orderstatus         = 'order-placed'
    INNER JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = dr.locationid
        AND ol.organizationtype = 0
    INNER JOIN dim.occasionsurvey AS os
        ON  os.organizationid = ol.organizationid
        AND os.surveyid       = dr.surveyid
    WHERE f.locationid    = dr.locationid
      AND f.orderid       = dr.orderid
      AND f.surveyid      = dr.surveyid
      AND f.itemid        = dr.itemid
      AND f.sysupdatetime IS NULL;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(nge_syscosmosts), 1775002010) FROM fact.itemssurvey),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'nge';

END;
$BODY$;


ALTER PROCEDURE fact.usp_nge_update_itemssurvey() OWNER TO citus;

--
-- TOC entry 967 (class 1255 OID 676702)
-- Name: usp_offer_analysis(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_offer_analysis()
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
        SELECT * FROM fact.recommendations AS rc
        WHERE rc.syscosmosts > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1 FROM fact.vw_offer_analysis AS oa
                WHERE oa.locationid          = rc.locationid
                  AND oa.transactionheaderid = rc.transactionheaderid
              )
), rec AS (
        SELECT
            rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.offereditems,
            rc.prompttimestamp,
            rc.prompttimestamp :: TIMESTAMP                                 AS upsellprompttime,
            rc.syscosmosts,
            element.value ->> 'itemId'       :: TEXT                       AS offered_itemid,
            element.value ->> 'upsellLevel'  :: TEXT                       AS offered_upselllevel,
            element.value ->> 'promptItemId' :: TEXT                       AS offered_prmpid,
            element.value ->> 'upsellGroupId':: TEXT                       AS offered_upslgrpid
        FROM delta AS rc,
            LATERAL jsonb_array_elements(rc.offereditems) element(value)
), selected AS (
        SELECT
            rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.selecteditems,
            rc.prompttimestamp,
            element.value ->> 'itemId'       :: TEXT                       AS selected_itemid,
            element.value ->> 'quantity'     :: TEXT                       AS selected_quantity,
            element.value ->> 'upsellLevel'  :: TEXT                       AS selected_upselllevel,
            element.value ->> 'promptItemId' :: TEXT                       AS selected_prmpid,
            element.value ->> 'upsellGroupId':: TEXT                       AS selected_upslgrpid
        FROM delta AS rc,
            LATERAL jsonb_array_elements(rc.selecteditems) element(value)
), item_analysis AS (
        SELECT
            r.locationid,
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid                                                AS offereditem,
            r.offered_upselllevel                                           AS offereditem_upselllevel,
            r.offered_prmpid                                                AS offered_promptitemid,
            r.offered_upslgrpid                                             AS offered_upsellgroupid,
            s.selected_itemid                                               AS selecteditem,
            s.selected_upselllevel                                          AS selecteditem_upselllevel,
            s.selected_prmpid                                               AS selected_promptitemid,
            s.selected_upslgrpid                                            AS selected_upsellgroupid,
            CASE
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'item'     THEN 'Item Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'order'    THEN 'Order Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'       THEN 'Smart Order Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai-order' THEN 'Smart Order Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai-item'  THEN 'Smart Item Upsells'
                ELSE NULL
            END                                                             AS upselltype,
            COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)            AS upsellgroupid,
            ul.upsellgroupname,
            CASE
                WHEN lower(s.selected_quantity) = ANY (ARRAY['true', '1']) THEN 1
                ELSE lower(s.selected_quantity) :: INTEGER
            END                                                             AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            NOW()                                                           AS sysinserttime
        FROM (SELECT * FROM rec WHERE rec.offered_itemid LIKE 'itm-%') AS r
        LEFT JOIN selected                  AS s
            ON  s.transactionheaderid :: TEXT = r.transactionheaderid :: TEXT
            AND s.recommendationid    :: TEXT = r.recommendationid    :: TEXT
            AND s.selected_itemid     :: TEXT = r.offered_itemid      :: TEXT
        LEFT JOIN dim.upsellgrouplookup     AS ul
            ON  ul.upsellgroupid :: TEXT = COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)
), category_analysis AS (
        SELECT
            r.locationid,
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid                                                AS offereditem,
            r.offered_upselllevel                                           AS offereditem_upselllevel,
            r.offered_prmpid                                                AS offered_promptitemid,
            r.offered_upslgrpid                                             AS offered_upsellgroupid,
            s.selected_itemid                                               AS selecteditem,
            s.selected_upselllevel                                          AS selecteditem_upselllevel,
            s.selected_prmpid                                               AS selected_promptitemid,
            s.selected_upslgrpid                                            AS selected_upsellgroupid,
            CASE
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'item'     THEN 'Item Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'order'    THEN 'Order Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai'       THEN 'Smart Order Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai-order' THEN 'Smart Order Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'ai-item'  THEN 'Smart Item Upsells'
                ELSE NULL
            END                                                             AS upselltype,
            COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)            AS upsellgroupid,
            ul.upsellgroupname,
            CASE
                WHEN lower(s.selected_quantity) = ANY (ARRAY['true', '1']) THEN 1
                ELSE lower(s.selected_quantity) :: INTEGER
            END                                                             AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            NOW()                                                           AS sysinserttime
        FROM (SELECT * FROM rec WHERE rec.offered_itemid LIKE 'cat-%') AS r
        INNER JOIN dim.category_hierarchy   AS ctg
            ON  ctg.categoryid = r.offered_itemid
        INNER JOIN (
                SELECT * FROM selected
                WHERE selected.selected_itemid NOT IN (SELECT offered_itemid FROM rec)
              )                             AS s
            ON  s.transactionheaderid :: TEXT = r.transactionheaderid :: TEXT
            AND s.recommendationid    :: TEXT = r.recommendationid    :: TEXT
            AND s.selected_itemid             = ctg.menuitemid
        LEFT JOIN dim.upsellgrouplookup     AS ul
            ON  ul.upsellgroupid :: TEXT = COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)
), total AS (
        SELECT * FROM item_analysis
        UNION
        SELECT * FROM category_analysis
)
INSERT INTO fact.vw_offer_analysis (
    locationid,
    transactionheaderid,
    recommendationid,
    offereditem,
    offereditem_upselllevel,
    offered_promptitemid,
    offered_upsellgroupid,
    selecteditem,
    selecteditem_upselllevel,
    selected_promptitemid,
    selected_upsellgroupid,
    upselltype,
    upsellgroupid,
    upsellgroupname,
    quantity,
    prompttimestamp,
    upsellprompttime,
    syscosmosts,
    sysinserttime
)
SELECT
    locationid,
    transactionheaderid,
    recommendationid,
    offereditem,
    offereditem_upselllevel,
    offered_promptitemid,
    offered_upsellgroupid,
    selecteditem,
    selecteditem_upselllevel,
    selected_promptitemid,
    selected_upsellgroupid,
    upselltype,
    upsellgroupid,
    upsellgroupname,
    quantity,
    prompttimestamp,
    upsellprompttime,
    syscosmosts,
    sysinserttime
FROM total;

    UPDATE fact.watermarktable
    SET ts            = rec.maxts,
        sysupdatetime = NOW() :: TIMESTAMP
    FROM (
        SELECT
            COALESCE(MAX(syscosmosts), 1500000010)  AS maxts,
            'fact.recommendations'                  AS tablename,
            'nge'                                   AS source
        FROM fact.recommendations
    ) AS rec
    WHERE watermarktable.watermarktablename = rec.tablename
      AND watermarktable.source             = rec.source;

END;
$BODY$;


ALTER PROCEDURE fact.usp_offer_analysis() OWNER TO citus;

--
-- TOC entry 651 (class 1255 OID 2993069)
-- Name: usp_sent_surveys_to_fact_itemssurvey(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_max_gem_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_gem_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'gem';

    DROP TABLE IF EXISTS temp_delta_sent_surveys;
    CREATE TEMPORARY TABLE temp_delta_sent_surveys (
        organizationid       TEXT COLLATE pg_catalog."default",
        locationid           TEXT COLLATE pg_catalog."default",
        ordersessionid       TEXT COLLATE pg_catalog."default",
        transactionheaderid  TEXT COLLATE pg_catalog."default",
        gem_event_category   TEXT COLLATE pg_catalog."default",
        gem_event_type       TEXT COLLATE pg_catalog."default",
        surveyid             TEXT COLLATE pg_catalog."default",
        itemid               TEXT COLLATE pg_catalog."default",
        is_responded         BOOLEAN,
        gem_event_instant    TEXT COLLATE pg_catalog."default",
        gem_syscosmosts      BIGINT,
        sysinserttime        TIMESTAMP,
        sysupdatetime        TIMESTAMP
    );

    WITH delta_sent_surveys AS (

        SELECT
            organizationid,
            locationid,
            ordersessionid,
            orderid                                                             AS transactionheaderid,
            gem_event_category,
            gem_event_type,
            survey_metadata,
            CASE WHEN jsonb_typeof(survey_metadata -> 'surveyIds') = 'array'
                 THEN survey_metadata -> 'surveyIds'
            END                                                                 AS surveyid_array,
            CASE WHEN survey_metadata ->> 'surveyIds' NOT LIKE '[%]'
                 THEN survey_metadata ->> 'surveyIds'
            END                                                                 AS surveyid_text,
            CASE WHEN jsonb_typeof(survey_metadata -> 'itemId') = 'array'
                 THEN survey_metadata -> 'itemId'
            END                                                                 AS itemid_array,
            CASE WHEN survey_metadata ->> 'itemId' NOT LIKE '[%]'
                 THEN survey_metadata ->> 'itemId'
            END                                                                 AS itemid_text,
            is_responded,
            gem_event_instant,
            gem_syscosmosts,
            sysinserttime,
            sysupdatetime
        FROM fact.sent_surveys AS ss
        WHERE ss.gem_syscosmosts > v_max_gem_syscosmosts
          AND NOT EXISTS (
              SELECT 1 FROM fact.itemssurvey AS its
              WHERE its.locationid = ss.locationid
                AND its.orderid    = ss.orderid
          )

    ), flattened_survey_trxns AS (

        SELECT
            dss.organizationid,
            dss.locationid,
            dss.ordersessionid,
            dss.transactionheaderid,
            dss.gem_event_category,
            dss.gem_event_type,
            TRIM(flat_survey.surveyid)                                          AS surveyid,
            dss.is_responded,
            dss.gem_event_instant,
            dss.gem_syscosmosts,
            dss.sysinserttime,
            dss.sysupdatetime
        FROM delta_sent_surveys AS dss
        CROSS JOIN LATERAL (
            SELECT unnest(
                CASE WHEN dss.surveyid_array IS NOT NULL
                     THEN ARRAY(SELECT jsonb_array_elements_text(dss.surveyid_array))
                     WHEN dss.surveyid_text  IS NOT NULL
                     THEN string_to_array(dss.surveyid_text, ',')
                END
            ) AS surveyid
        ) AS flat_survey

    ), flattened_item_trxns AS (

        SELECT
            dss.locationid,
            dss.transactionheaderid,
            TRIM(flat_item.itemid)                                              AS itemid
        FROM delta_sent_surveys AS dss
        CROSS JOIN LATERAL (
            SELECT unnest(
                CASE WHEN dss.itemid_array IS NOT NULL
                     THEN ARRAY(SELECT jsonb_array_elements_text(dss.itemid_array))
                     WHEN dss.itemid_text  IS NOT NULL
                     THEN string_to_array(dss.itemid_text, ',')
                END
            ) AS itemid
        ) AS flat_item

    ), joined_surveys_with_items AS (

        SELECT
            st.organizationid,
            st.locationid,
            st.ordersessionid,
            st.transactionheaderid,
            st.gem_event_category,
            st.gem_event_type,
            st.surveyid,
            it.itemid,
            st.is_responded,
            st.gem_event_instant,
            st.gem_syscosmosts,
            st.sysinserttime,
            st.sysupdatetime
        FROM flattened_survey_trxns AS st
        LEFT JOIN flattened_item_trxns AS it
            ON  it.locationid          = st.locationid
            AND it.transactionheaderid = st.transactionheaderid

    )
    INSERT INTO temp_delta_sent_surveys
    SELECT DISTINCT ON (locationid, transactionheaderid, surveyid, itemid) * 
    FROM joined_surveys_with_items
    ORDER BY locationid, transactionheaderid, surveyid, itemid, gem_syscosmosts DESC;

    INSERT INTO fact.itemssurvey (
        organizationid,
        locationid,
        ordersessionid,
        orderid,
        surveyissuedtimestamp,
        gem_event_category,
        gem_event_type,
        surveyid,
        itemid,
        is_responded,
        gem_event_instant,
        gem_syscosmosts,
        sysinserttime,
        sysupdatetime,
        sourceid
    )
    SELECT
        tds.organizationid,
        tds.locationid,
        tds.ordersessionid,
        tds.transactionheaderid,
        fact.parse_iso_timestamp(tds.gem_event_instant)     AS surveyissuedtimestamp,
        tds.gem_event_category,
        tds.gem_event_type,
        tds.surveyid,
        tds.itemid,
        tds.is_responded,
        tds.gem_event_instant,
        tds.gem_syscosmosts,
        tds.sysinserttime,
        tds.sysupdatetime,
        2                                                   AS sourceid
    FROM temp_delta_sent_surveys AS tds
    WHERE NOT EXISTS (
        SELECT 1 FROM fact.itemssurvey AS its
        WHERE its.organizationid = tds.organizationid
          AND its.locationid     = tds.locationid
          AND its.orderid        = tds.transactionheaderid
          AND its.surveyid       = tds.surveyid
          AND its.itemid         = tds.itemid
    )
      AND EXISTS (
        SELECT 1 FROM fact.transactionheader AS th
        WHERE th.locationid          = tds.locationid
          AND th.transactionheaderid = tds.transactionheaderid
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(gem_syscosmosts), 1775002010) FROM fact.itemssurvey),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.itemssurvey'
      AND source             = 'gem';

END;
$BODY$;


ALTER PROCEDURE fact.usp_sent_surveys_to_fact_itemssurvey() OWNER TO citus;

--
-- TOC entry 1106 (class 1255 OID 3618756)
-- Name: usp_silver_aborted_orders_and_items_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

--CALL fact.usp_silver_aborted_orders_and_items_to_fact();

CREATE OR REPLACE PROCEDURE fact.usp_silver_aborted_orders_and_items_to_fact()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'gem';


    -- ----------------------------------------------------------------
    -- Stage the aborted order delta into a temp table so both the
    -- header INSERT and the item INSERT share the same result without
    -- repeating the dedup + filter logic.
    --
    -- DISTINCT ON (locationid, token) ordered by syscosmosts DESC keeps
    -- the latest event per session — mirrors ADF ROW_NUMBER() OVER
    -- (PARTITION BY location, token ORDER BY id DESC) filtered to rn = 1.
    -- ----------------------------------------------------------------
    DROP TABLE IF EXISTS temp_aborted_delta;
    CREATE TEMPORARY TABLE temp_aborted_delta AS
    SELECT DISTINCT ON (ke.locationid, ke.token)
        ke.id,
        CONCAT('abort-', ke.id)                                          AS transactionheaderid,
        ke.locationid,
        ke.device                                                        AS kioskid,
        ke.token                                                         AS ordersessionid,
        -- orderid: 'ord-' + order.sessionId from data JSON
        -- fallback to token if sessionId is absent
        CONCAT('ord-',
            COALESCE(
                NULLIF(ke.data :: jsonb -> 'order' ->> 'sessionId', ''),
                ke.token
            )
        )                                                                AS orderid,
        -- itemsessionid: raw sessionId without 'ord-' prefix
        -- mirrors ADF select2: itemsessionid = itemsessionid.order.sessionId
        COALESCE(
            NULLIF(ke.data :: jsonb -> 'order' ->> 'sessionId', ''),
            ke.token
        )                                                                AS itemsessionid,
        -- orderstatus: mirrors ADF case(exception → Abandoned, ordercancelled → Cancelled)
        CASE LOWER(ke.eventtype)
            WHEN 'exception'      THEN 'Abandoned'
            WHEN 'ordercancelled' THEN 'Cancelled'
            ELSE ke.eventtype
        END                                                              AS orderstatus,
        -- channel: extracted from data JSON via LIKE pattern
        -- mirrors ADF: case(like(data,'%"channel":0%'), 'Kiosk', ...)
        CASE
            WHEN ke.data LIKE '%"channel":0%' THEN 'Kiosk'
            WHEN ke.data LIKE '%"channel":1%' THEN 'OnlineOrdering'
            WHEN ke.data LIKE '%"channel":2%' THEN 'External'
            ELSE 'Kiosk'
        END                                                              AS channel,
        fact.parse_iso_timestamp(ke.eventinstant)                        AS orderdateutc,
        ke.syscosmosts
    FROM stg.silver_kiosk_events AS ke
    -- Real kiosk filter — mirrors ADF EXISTS against dim.kiosk WHERE istestkiosk = False
    INNER JOIN dim.kiosk AS dk
        ON  dk.kioskid     = ke.device
        AND dk.istestkiosk = false
    WHERE ke.eventcategory IN ('Order', 'insight')
      AND ke.eventtype     IN ('Cancelled', 'OrderCancelled', 'Abandoned', 'Exception')
      AND ke.syscosmosts   > v_max_syscosmosts
      -- Skip sessions already written as aborted orders
      AND NOT EXISTS (
          SELECT 1 FROM fact.transactionheader AS th
          WHERE th.locationid          = ke.locationid
            AND th.transactionheaderid = CONCAT('abort-', ke.id)
      )
    ORDER BY ke.locationid, ke.token, ke.syscosmosts DESC;


    -- ----------------------------------------------------------------
    -- INSERT fact.transactionheader
    --
    -- Session timing scoped to sessions in the current delta batch —
    -- avoids a full scan of silver_kiosk_events on every run.
    -- Same event filter pattern as usp_silver_transaction_header_to_fact.
    -- ----------------------------------------------------------------
    WITH session_timing AS (

        SELECT
            ke.locationid,
            ke.token,
            MIN(CASE WHEN LOWER(ke.eventcategory) = 'session'
                          AND LOWER(ke.eventtype)  = 'started'
                     THEN ke.eventinstant END)                           AS orderstarttime,
            MIN(CASE WHEN LOWER(ke.eventcategory) IN ('order', 'insight')
                          AND LOWER(ke.eventtype)  = 'revieworderclicked'
                     THEN ke.eventinstant END)                           AS reviewordertime,
            MIN(CASE WHEN LOWER(ke.eventcategory) IN ('order', 'insight')
                          AND LOWER(ke.eventtype)  = 'checkoutclicked'
                     THEN ke.eventinstant END)                           AS checkouttime,
            MIN(CASE WHEN LOWER(ke.eventcategory) = 'payment'
                          AND LOWER(ke.eventtype)  = 'create'
                     THEN ke.eventinstant END)                           AS paystarttime,
            MAX(CASE WHEN LOWER(ke.eventcategory) IN ('session', 'order')
                          AND LOWER(ke.eventtype)  = 'closed'
                     THEN ke.eventinstant END)                           AS sessionendtime
        FROM stg.silver_kiosk_events AS ke
        INNER JOIN temp_aborted_delta AS ad
            ON  ad.locationid     = ke.locationid
            AND ad.ordersessionid = ke.token
        WHERE LOWER(ke.severity) = 'information'
          AND (
                (LOWER(ke.eventcategory) = 'session'             AND LOWER(ke.eventtype) = 'started')            OR
                (LOWER(ke.eventcategory) IN ('order', 'insight') AND LOWER(ke.eventtype) = 'revieworderclicked') OR
                (LOWER(ke.eventcategory) IN ('order', 'insight') AND LOWER(ke.eventtype) = 'checkoutclicked')    OR
                (LOWER(ke.eventcategory) = 'payment'             AND LOWER(ke.eventtype) = 'create')             OR
                (LOWER(ke.eventcategory) IN ('session', 'order') AND LOWER(ke.eventtype) = 'closed')
              )
        GROUP BY ke.locationid, ke.token
        
    )
    INSERT INTO fact.transactionheader (
        id,
        transactionheaderid,
        orderid,
        locationid,
        kioskid,
        ordersessionid,
        dateid,
        orderdateutc,
        orderdatelocal,
        orderstatus,
        numberofitems,
        numberofpayments,
        ordersredeemedrewards,
        ordersubtotal,
        ordertotal,
        ordertax,
        ordertip,
        orderdiscount,
        orderbalance,
        paymentstatus,
        sourcefile,
        createddate,
        orderstarttime,
        reviewordertime,
        checkouttime,
        paystarttime,
        sessionendtime,
        precheckouttime,
        postcheckouttime,
        menupagetime,
        reviewpagetime,
        paymentpagetime,
        totalordertime,
        channel,
        syscosmosts,
        sourceid
    )
    SELECT
        nextval('fact.transactionheader_id_seq')                                        AS id,
        ad.transactionheaderid,
        CASE WHEN ad.orderid LIKE 'ord-%' AND LENGTH(ad.orderid) > 4  THEN orderid
             WHEN ad.orderid    = 'ord-'  AND ad.ordersessionid <> '' THEN CONCAT(ad.orderid, ad.ordersessionid)
             ELSE CONCAT('ord-', SUBSTRING(ad.transactionheaderid, 7, LENGTH(ad.transactionheaderid)))
        END AS orderid,
        ad.locationid,
        ad.kioskid,
        ad.ordersessionid,
        CAST(TO_CHAR(
            (ad.orderdateutc :: TIMESTAMPTZ AT TIME ZONE loc.timezone) :: TIMESTAMP,
            'YYYYMMDDHH24'
        ) AS INTEGER)                                                                   AS dateid,
        ad.orderdateutc,
        (ad.orderdateutc :: TIMESTAMPTZ AT TIME ZONE loc.timezone) :: TIMESTAMP        AS orderdatelocal,
        ad.orderstatus,
        0 :: SMALLINT                                                                   AS numberofitems,
        0 :: SMALLINT                                                                   AS numberofpayments,
        0.000 :: NUMERIC(12,3)                                                         AS ordersredeemedrewards,
        0.000 :: NUMERIC(12,3)                                                         AS ordersubtotal,
        0.000 :: NUMERIC(12,3)                                                         AS ordertotal,
        0.000 :: NUMERIC(12,3)                                                         AS ordertax,
        0.000 :: NUMERIC(12,3)                                                         AS ordertip,
        0.000 :: NUMERIC(12,3)                                                         AS orderdiscount,
        0.000 :: NUMERIC(12,3)                                                         AS orderbalance,
        'None'                                                                          AS paymentstatus,
        'NGE'                                                                           AS sourcefile,
        now() :: TIMESTAMP                                                              AS createddate,
        fact.parse_iso_timestamp(st.orderstarttime)  :: TIMESTAMP                      AS orderstarttime,
        fact.parse_iso_timestamp(st.reviewordertime) :: TIMESTAMP                      AS reviewordertime,
        fact.parse_iso_timestamp(st.checkouttime)    :: TIMESTAMP                      AS checkouttime,
        fact.parse_iso_timestamp(st.paystarttime)    :: TIMESTAMP                      AS paystarttime,
        fact.parse_iso_timestamp(st.sessionendtime)  :: TIMESTAMP                      AS sessionendtime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.checkouttime) :: TIMESTAMP    - fact.parse_iso_timestamp(st.orderstarttime) :: TIMESTAMP
        ))                                                                              AS precheckouttime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.sessionendtime) :: TIMESTAMP  - fact.parse_iso_timestamp(st.checkouttime) :: TIMESTAMP
        ))                                                                              AS postcheckouttime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.reviewordertime) :: TIMESTAMP - fact.parse_iso_timestamp(st.orderstarttime) :: TIMESTAMP
        ))                                                                              AS menupagetime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.checkouttime) :: TIMESTAMP    - fact.parse_iso_timestamp(st.reviewordertime) :: TIMESTAMP
        ))                                                                              AS reviewpagetime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.sessionendtime) :: TIMESTAMP - fact.parse_iso_timestamp(st.paystarttime) :: TIMESTAMP
        ))                                                                              AS paymentpagetime,
        EXTRACT(EPOCH FROM (
            fact.parse_iso_timestamp(st.sessionendtime) :: TIMESTAMP  - fact.parse_iso_timestamp(st.orderstarttime) :: TIMESTAMP
        ))                                                                              AS totalordertime,
        ad.channel,
        ad.syscosmosts,
        2                                                                               AS sourceid
    FROM temp_aborted_delta AS ad
    LEFT JOIN session_timing AS st
        ON  st.locationid = ad.locationid
        AND st.token      = ad.ordersessionid
    LEFT JOIN dim.organization AS loc
        ON  loc.id = ad.locationid
    ON CONFLICT (locationid, transactionheaderid)
    DO NOTHING;


    -- ----------------------------------------------------------------
    -- INSERT fact.transactionitem — placeholder stub per aborted order
    --
    -- Mirrors ADF WriteToItems: one fixed row per aborted order with
    -- itemid = 'itemid' and itemname = 'itemname' as placeholders.
    -- PK (transactionheaderid, itemid, itemname) guarantees exactly
    -- one stub row regardless of reruns.
    -- ----------------------------------------------------------------
    INSERT INTO fact.transactionitem (
        transactionheaderid,
        itemid,
        itemsessionid,
        itemname,
        itemquantity,
        itemunitprice,
        upselllevel,
        upsellpromptitemid,
        orderid,
        ordersessionid,
        orderdateutc,
        sysinserttime,
        locationid
    )
    SELECT
        ad.transactionheaderid,
        'itemid'                AS itemid,
        ad.itemsessionid,
        'itemname'              AS itemname,
        0 :: SMALLINT           AS itemquantity,
        0.000 :: NUMERIC(12,3)  AS itemunitprice,
        ''                      AS upselllevel,
        ''                      AS upsellpromptitemid,
        CASE WHEN ad.orderid LIKE 'ord-%' AND LENGTH(ad.orderid) > 4  THEN orderid
             WHEN ad.orderid    = 'ord-'  AND ad.ordersessionid <> '' THEN CONCAT(ad.orderid, ad.ordersessionid)
             ELSE CONCAT('ord-', SUBSTRING(ad.transactionheaderid, 7, LENGTH(ad.transactionheaderid)))
        END AS orderid,
        ad.ordersessionid,
        ad.orderdateutc,
        now() :: TIMESTAMP      AS sysinserttime,
        ad.locationid
    FROM temp_aborted_delta AS ad
    ON CONFLICT (transactionheaderid, itemid, itemname)
    DO NOTHING;


    -- Advance watermark to max GEM syscosmosts across all sourceid = 2 headers
    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionheader WHERE sourceid = 2),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'gem';

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_aborted_orders_and_items_to_fact() OWNER TO citus;

--
-- TOC entry 1419 (class 1255 OID 3623319)
-- Name: usp_silver_item_modifiers_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_silver_item_modifiers_to_fact()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;

BEGIN

    -- Capture watermark once upfront; subtract 10s as a safety overlap buffer
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.itemmodifier'
      AND source             = 'nge';

    WITH delta AS (
        -- Deduplicate: keep latest Cosmos snapshot per (header, item, group, modifier)
        SELECT DISTINCT ON (
            transactionheaderid,
            orderitemid,
            options_modifiergroupid,
            options_modifierid
        )
            transactionheaderid,
            orderid,
            orderitemid                             AS itemid,
            options_modifiergroupid                 AS modifiergroupid,
            options_modifierid                      AS modifierid,
            options_modifiername                    AS modifiername,
            COALESCE(options_modifierquantity, 1)   AS modifierquantity,
            options_modifierunitprice               AS modifierprice,
            modifier_freequantity                   AS freequantity,
            locationid,
            businessdate :: DATE                    AS businessdate,
            syscosmosts
        FROM stg.silver_item_modifiers
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND options_modifierid      IS NOT NULL
          AND options_modifiergroupid IS NOT NULL
          AND orderitemid             IS NOT NULL
          AND syscosmosts > v_max_syscosmosts
        ORDER BY
            transactionheaderid,
            orderitemid,
            options_modifiergroupid,
            options_modifierid,
            syscosmosts DESC
    )
    INSERT INTO fact.itemmodifier (
        transactionheaderid,
        orderid,
        itemid,
        modifiergroupid,
        modifierid,
        modifiername,
        modifierquantity,
        modifierprice,
        freequantity,
        sysinserttime,
        locationid,
        businessdate,
        syscosmosts
    )
    SELECT
        d.transactionheaderid,
        ti.orderid,                
        d.itemid,
        d.modifiergroupid,
        d.modifierid,
        d.modifiername,
        d.modifierquantity,
        d.modifierprice,
        d.freequantity,
        NOW() :: TIMESTAMP  AS sysinserttime,
        d.locationid,
        d.businessdate,
        d.syscosmosts
    FROM delta as d
    INNER JOIN fact.transactionitem as ti 
            ON ti.transactionheaderid = d.transactionheaderid
           AND ti.itemid              = d.itemid
    ON CONFLICT (transactionheaderid, itemid, modifiergroupid, modifierid)
    DO UPDATE SET
        modifiername     = EXCLUDED.modifiername,
        modifierquantity = EXCLUDED.modifierquantity,
        modifierprice    = EXCLUDED.modifierprice,
        freequantity     = EXCLUDED.freequantity,
        sysupdatetime    = NOW() :: TIMESTAMP,
        -- only advance if incoming snapshot is genuinely newer
        syscosmosts      = GREATEST(EXCLUDED.syscosmosts, fact.itemmodifier.syscosmosts);

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.itemmodifier),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.itemmodifier'
      AND source             = 'nge';

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_item_modifiers_to_fact() OWNER TO citus;

--
-- TOC entry 1241 (class 1255 OID 3605479)
-- Name: usp_silver_kiosk_events_to_fact_deviceevent(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_silver_kiosk_events_to_fact_deviceevent()
    LANGUAGE plpgsql
    AS $BODY$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 600
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.deviceevent'
      AND source             = 'gem';

    WITH new_events AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- DISTINCT ON natural key, latest syscosmosts wins
        -- NOT EXISTS mirrors ADF negate exists against AnalyticsDbEvents:
        --   location == locationid
        --   token    == eventtoken
        --   category == datacategory
        --   type     == actiontype
        --   instant  == eventinstant
        -- EXISTS dim.organizationlocation mirrors ADF dimOrgLoc exists check
        --   and aligns with the FK constraint on fact.deviceevent

        SELECT DISTINCT ON (
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant
        )
            ske.application,
            ske.companyid,
            ske.locationid,
            ske.eventmodule,
            ske.eventcategory,
            ske.eventtype,
            ske.severity,
            ske.token,
            ske.eventinstant,
            ske.username,
            ske.userid,
            ske.device,
            ske.summary,
            ske.data,
            ske.syscosmosticks,
            ske.syscosmosts
        FROM stg.silver_kiosk_events            AS ske
        WHERE ske.syscosmosts   > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.deviceevent           AS de
                WHERE de.locationid   = ske.locationid
                  AND de.eventtoken   = ske.token
                  AND de.datacategory = ske.eventcategory
                  AND de.actiontype   = ske.eventtype
                  AND de.eventinstant = ske.eventinstant
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organizationlocation   AS ol
                WHERE ol.locationid     = ske.locationid
                  AND ol.organizationid = ske.companyid
              )
        ORDER BY
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant,
            ske.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.deviceevent (
        application,
        companyid,
        locationid,
        moduleid,
        datacategory,
        actiontype,
        severity,
        eventtoken,
        eventinstant,
        dateid,
        username,
        userid,
        deviceid,
        devicename,
        summary,
        eventdata,
        syscosmosticks,
        sysinserttime,
        syscosmosts
    )
    SELECT
        application,
        companyid,
        locationid,
        eventmodule                                                         AS moduleid,
        eventcategory                                                       AS datacategory,
        eventtype                                                           AS actiontype,
        severity,
        token                                                               AS eventtoken,
        eventinstant,
        REPLACE(REPLACE(SUBSTRING(eventinstant, 1, 13), '-', ''), 'T', '')
            :: INTEGER                                                      AS dateid,
        username,
        userid,
        device                                                              AS deviceid,
        device                                                              AS devicename,
        summary,
        data                                                                AS eventdata,
        syscosmosticks,
        NOW() :: TIMESTAMP                                                  AS sysinserttime,
        syscosmosts
    FROM new_events;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.deviceevent),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.deviceevent'
      AND source             = 'gem';
END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_kiosk_events_to_fact_deviceevent() OWNER TO citus;

--
-- TOC entry 982 (class 1255 OID 3605480)
-- Name: usp_silver_kiosk_events_to_fact_userbehaviour(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_silver_kiosk_events_to_fact_userbehaviour()
    LANGUAGE plpgsql
    AS $BODY$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    -- -10 buffer mirrors transactionheader pattern to catch late-arriving events
    SELECT COALESCE(ts, 1775002010) - 600
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.userbehaviour'
      AND source             = 'gem';


    WITH new_events AS (

        SELECT DISTINCT ON (
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant
        )
            ske.locationid,
            ske.token                               AS ordersessionidentifier,
            ske.eventcategory,
            ske.eventinstant,
            ske.eventtype,
            ske.data,
            ske.device,
            ske.syscosmosts
        FROM stg.silver_kiosk_events                AS ske
        WHERE ske.eventmodule      = 'kiosk'
          AND ske.eventcategory    = 'insight'
          AND ske.syscosmosts      > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.userbehaviour             AS ub
                WHERE ub.locationid             = ske.locationid
                  AND ub.ordersessionidentifier = ske.token
                  AND ub.eventcategory          = ske.eventcategory
                  AND ub.eventtype              = ske.eventtype
                  AND ub.eventinstant           = ske.eventinstant
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organization               AS o
                WHERE o.id = ske.locationid
              )
        ORDER BY
            ske.locationid,
            ske.token,
            ske.eventcategory,
            ske.eventtype,
            ske.eventinstant,
            ske.syscosmosts DESC NULLS LAST

    ), parsed_events AS (

        SELECT
            ne.locationid,
            ne.ordersessionidentifier,
            ne.eventcategory,
            ne.eventinstant,
            ne.eventtype,
            ne.syscosmosts,
            ne.device,
            fact.parse_iso_timestamp(ne.eventinstant)                             AS busdate,
            REPLACE(REPLACE(SUBSTRING(ne.eventinstant, 1, 13), '-', ''), 'T', '')
                :: INTEGER                                                         AS dateid,
            NULLIF(TRIM(ne.data::jsonb->>'view'),         '')                     AS view_name,
            COALESCE(NULLIF(TRIM(ne.data::jsonb->>'element'),   ''), 'None')      AS element_name,
            COALESCE(NULLIF(TRIM(ne.data::jsonb->>'elementId'), ''), 'None')      AS source_element_id,
            NULLIF(TRIM(ne.data::jsonb->>'quantity'), '')::INTEGER                AS quantity,
            NULLIF(TRIM(ne.data::jsonb->>'itemSessionId'), '')                    AS itemsessionidentifier
        FROM new_events ne
        WHERE ne.data IS NOT NULL
          AND ne.data <> ''

    ), enriched AS (

        SELECT
            pe.locationid,
            pe.ordersessionidentifier,
            pe.eventcategory,
            pe.eventinstant,
            pe.eventtype,
            pe.syscosmosts,
            pe.busdate,
            pe.dateid,
            pe.itemsessionidentifier,
            pe.quantity,
            ot.id                                   AS ordertype,
            dv.viewid                               AS viewidentifier,
            de.elementid                            AS elementidentifier,
            'None'  :: TEXT                         AS daypart,
            NOW()   :: TIMESTAMP                    AS createddate
        FROM parsed_events                          AS pe
        LEFT JOIN dim.ordertype                     AS ot
            ON  ot.locationid = pe.locationid
            AND ot.kioskid    = pe.device
        LEFT JOIN dim.view                          AS dv
            ON  dv.viewname   = pe.view_name
        LEFT JOIN dim.element                       AS de
            ON  de.elementname     = pe.element_name
            AND de.sourceelementid = pe.source_element_id

    )
    INSERT INTO fact.userbehaviour (
        id,
        busdate,
        locationid,
        dateid,
        daypart,
        ordertype,
        eventtype,
        ordersessionidentifier,
        viewidentifier,
        itemsessionidentifier,
        elementidentifier,
        quantity,
        createddate,
        syscosmosts,
        eventinstant,
        eventcategory
    )
    SELECT
        nextval('fact.userbehaviour_id_seq'),
        busdate :: TIMESTAMP AS busdate,
        locationid,
        dateid,
        daypart,
        ordertype,
        eventtype,
        ordersessionidentifier,
        viewidentifier,
        itemsessionidentifier,
        elementidentifier,
        quantity,
        createddate,
        syscosmosts,
        eventinstant,
        eventcategory
    FROM enriched;

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_kiosk_events_to_fact_userbehaviour() OWNER TO citus;


CREATE OR REPLACE PROCEDURE fact.usp_stg_gem_failed_order_job_notifications_to_fact()
    LANGUAGE plpgsql
    AS $BODY$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1767225610) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.gem_failed_order_job_notifications'
      AND source             = 'gem-Job';


    WITH new_notifications AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- DISTINCT ON natural key, latest syscosmosts wins
        -- NOT EXISTS deduplicates against fact on:
        --   incidentid == incidentid
        --   eventtoken == eventtoken

        SELECT DISTINCT ON (
            stg.incidentid,
            stg.eventtoken
        )
            stg.incidentid,
            stg.application,
            stg.organizationid,
            stg.locationid,
            stg.eventmodule,
            stg.eventcategory,
            stg.eventtype,
            stg.eventtoken,
            stg.incidentcount,
            stg.firstoccurred,
            stg.lastoccurred,
            stg.incidenttype,
            stg.notificationtypeid,
            stg.syscosmosts
        FROM stg.gem_failed_order_job_notifications     AS stg
        WHERE stg.syscosmosts   > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.gem_failed_order_job_notifications    AS f
                WHERE f.incidentid = stg.incidentid :: BIGINT
                  AND f.eventtoken = stg.eventtoken
              )
        ORDER BY
            stg.incidentid,
            stg.eventtoken,
            stg.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.gem_failed_order_job_notifications (
        incidentid,
        application,
        organizationid,
        locationid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidentcount,
        firstoccurred,
        lastoccurred,
        incidenttype,
        notificationtypeid,
        syscosmosts,
        sysinserttime
    )
    SELECT
        incidentid :: BIGINT,
        application,
        organizationid,
        locationid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidentcount,
        firstoccurred,
        lastoccurred,
        incidenttype,
        notificationtypeid,
        syscosmosts,
        NOW() :: TIMESTAMP      AS sysinserttime
    FROM new_notifications;


    UPDATE fact.watermarktable
    SET ts            = (SELECT COALESCE(MAX(syscosmosts), 0) FROM fact.gem_failed_order_job_notifications),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.gem_failed_order_job_notifications'
      AND source             = 'gem-Job';

END;
$BODY$;

ALTER PROCEDURE fact.usp_stg_gem_failed_order_job_notifications_to_fact() OWNER TO citus;



CREATE OR REPLACE PROCEDURE fact.usp_silver_cep_incidents_to_fact_cep_incidents()
    LANGUAGE plpgsql
    AS $BODY$
DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1767225610) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.cep_incidents'
      AND source             = 'gem';


    WITH new_error_events AS (

        -- ── Source filter + dedup ─────────────────────────────
        -- stg.silver_cep_incidents is pre-filtered at the bronze→silver
        -- layer (application=nge, module=connector, severity=critical,
        -- category=order, type=ordersubmitresponse), so no re-filtering needed.
        -- DISTINCT ON natural key, latest syscosmosts wins.
        -- NOT EXISTS mirrors ADF negate exists against GASfactCEPIncidents:
        --   id        == incidentkey
        --   token     == eventtoken
        -- EXISTS dim.organizationlocation mirrors ADF ExistingLocations check

        SELECT DISTINCT ON (
            sci.id,
            sci.token
        )
            sci.id,
            sci.application,
            sci.companyid,
            sci.locationid,
            sci.eventmodule,
            sci.eventcategory,
            sci.eventtype,
            sci.severity,
            sci.token,
            sci.eventinstant,
            sci.device,
            sci.data,
            sci.syscosmosts
        FROM stg.silver_cep_incidents               AS sci
        WHERE sci.syscosmosts   > v_max_syscosmosts
          AND NOT EXISTS (
                SELECT 1
                FROM fact.cep_incidents              AS ci
                WHERE ci.incidentkey = sci.id :: BIGINT
                  AND ci.eventtoken  = sci.token
              )
          AND EXISTS (
                SELECT 1
                FROM dim.organizationlocation        AS ol
                WHERE ol.locationid     = sci.locationid
                  AND ol.organizationid = sci.companyid
              )
        ORDER BY
            sci.id,
            sci.token,
            sci.syscosmosts DESC NULLS LAST

    )
    INSERT INTO fact.cep_incidents (
        incidentkey,
        application,
        organizationid,
        locationid,
        deviceid,
        eventmodule,
        eventcategory,
        eventtype,
        eventtoken,
        incidenttype,
        incidentcount,
        eventinstant,
        firstoccurred,
        lastoccurred,
        notificationtypeid,
        incidentdata,
        syscosmosts,
        sysinserttime,
        severity
    )
    -- ── gemJobCEP left join mirrored here ──────────────────────
    -- ADF joins error events LEFT JOIN gemCEPIncidents
    -- (Cosmos job='asa-failed-order') on:
    --   incidentkey  == incidentid
    --   errortoken   == eventtoken
    --   eventcategory == eventcategory
    --   eventtype    == eventtype
    -- Incident metadata (counts, timestamps) enriched from
    -- fact.gem_failed_order_job_notifications
    SELECT
        nee.id :: BIGINT                                                    AS incidentkey,
        nee.application,
        nee.companyid                                                       AS organizationid,
        nee.locationid,
        nee.device                                                          AS deviceid,
        nee.eventmodule,
        nee.eventcategory,
        nee.eventtype,
        nee.token                                                           AS eventtoken,
        gfojn.incidenttype,
        gfojn.incidentcount,
        nee.eventinstant,
        fact.parse_iso_timestamp(gfojn.firstoccurred) :: TIMESTAMP          AS firstoccurred,
        fact.parse_iso_timestamp(gfojn.lastoccurred) :: TIMESTAMP           AS firstoccurred,
        gfojn.notificationtypeid,
        nee.data                                                            AS incidentdata,
        nee.syscosmosts,
        NOW() :: TIMESTAMP                                                  AS sysinserttime,
        nee.severity
    FROM new_error_events                               AS nee
    LEFT JOIN fact.gem_failed_order_job_notifications   AS gfojn
        ON  gfojn.incidentid    = nee.id :: BIGINT
        AND gfojn.eventtoken    = nee.token
        AND gfojn.eventcategory = nee.eventcategory
        AND gfojn.eventtype     = nee.eventtype;


    UPDATE fact.watermarktable
    SET ts            = (SELECT COALESCE(MAX(syscosmosts), 0) FROM fact.cep_incidents),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.cep_incidents'
      AND source             = 'gem';

END;
$BODY$;

ALTER PROCEDURE fact.usp_silver_cep_incidents_to_fact_cep_incidents() OWNER TO citus;


--
-- TOC entry 1479 (class 1255 OID 3629703)
-- Name: usp_silver_modifier_impressions_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

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
        CASE WHEN d.orderid LIKE 'ord-%' AND LENGTH(d.orderid) > 4  THEN d.orderid
             WHEN d.orderid    = 'ord-'  AND d.ordersessionid <> '' THEN CONCAT(d.orderid, d.ordersessionid)
             ELSE CONCAT('ord-', SUBSTRING(d.transactionheaderid, 8, LENGTH(d.transactionheaderid)))
        END as orderid,                
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
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_impressions),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.modifier_impressions'
      AND source             = 'nge';

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_modifier_impressions_to_fact() OWNER TO citus;

--
-- TOC entry 732 (class 1255 OID 3623322)
-- Name: usp_silver_modifier_interactions_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

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
            CASE WHEN di.orderid LIKE 'ord-%' AND LENGTH(di.orderid) > 4  THEN di.orderid
                 WHEN di.orderid    = 'ord-'  AND di.ordersessionid <> '' THEN CONCAT(di.orderid, di.ordersessionid)
                 ELSE CONCAT('ord-', SUBSTRING(di.transactionheaderid, 8, LENGTH(di.transactionheaderid)))
            END as orderid,                
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
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_interactions WHERE sourceid = 5),
        sysupdatetime = NOW() :: TIMESTAMP
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
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_interactions WHERE sourceid = 6),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.modifier_interactions'
      AND source             = 'nge-Options';

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_modifier_interactions_to_fact() OWNER TO citus;

--
-- TOC entry 919 (class 1255 OID 3623321)
-- Name: usp_silver_modifier_recommendations_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_silver_modifier_recommendations_to_fact()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;

BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.modifier_recommendations'
      AND source             = 'nge';

    WITH delta AS (
        -- Deduplicate: keep latest snapshot per (locationid, transactionheaderid)
        SELECT DISTINCT ON (locationid, transactionheaderid)
            locationid,
            transactionheaderid,
            ordersessionid,
            orderid,
            modifier_impressions,
            modifier_interactions,      -- intentionally nullable; CosmosDB filter only guards impressions
            businessdate :: DATE        AS businessdate,
            orderdateutc,
            frequentcustomerid,
            syscosmosts
        FROM stg.silver_modifier_recommendations
        WHERE (is_test_order = FALSE OR is_test_order IS NULL)
          AND syscosmosts        >  v_max_syscosmosts
          -- mirror CosmosDB source filter: skip orders with no impressions data
          AND modifier_impressions IS NOT NULL
          AND modifier_impressions != '[]'
        ORDER BY locationid, transactionheaderid, syscosmosts DESC
    )
    INSERT INTO fact.modifier_recommendations (
        locationid,
        transactionheaderid,
        ordersessionid,
        orderid,
        modifier_impressions,
        modifier_interactions,
        businessdate,
        orderdateutc,
        orderdatelocal,
        frequentcustomerid,
        syscosmosts,
        sysinserttime
    )
    SELECT
        d.locationid,
        d.transactionheaderid,
        d.ordersessionid,
        th.orderid,
        d.modifier_impressions :: JSONB,
        d.modifier_interactions :: JSONB,
        d.businessdate,
        fact.parse_iso_timestamp(d.orderdateutc)    AS orderdateutc,
        th.orderdatelocal                           AS orderdatelocal,
        d.frequentcustomerid,
        d.syscosmosts,
        NOW() :: TIMESTAMP                          AS sysinserttime
    FROM delta d
    -- Mirror ADF ExistingOrders step: only load if the parent order is already in the fact layer
    INNER JOIN fact.transactionheader th
            ON th.locationid          = d.locationid
           AND th.transactionheaderid = d.transactionheaderid
    -- Mirror ADF NewModfrRecs step (negate:true): skip if already recorded
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.modifier_recommendations mr
        WHERE mr.locationid          = d.locationid
          AND mr.transactionheaderid = d.transactionheaderid
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.modifier_recommendations),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.modifier_recommendations'
      AND source             = 'nge';

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_modifier_recommendations_to_fact() OWNER TO citus;

--
-- TOC entry 664 (class 1255 OID 3553218)
-- Name: usp_silver_transaction_header_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_header_to_fact()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 600
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'nge';


    WITH delta_transactions AS (
        -- DISTINCT ON replaces ROW_NUMBER() + WHERE row_num = 1
        -- Keeps the latest version of each transaction per location
        SELECT DISTINCT ON (locationid, transactionheaderid)
            transactionheaderid,
            CASE WHEN orderid LIKE 'ord-%' AND LENGTH(orderid) > 4  THEN orderid
                 WHEN orderid    = 'ord-'  AND ordersessionid <> '' THEN CONCAT(orderid, ordersessionid)
                 ELSE CONCAT('ord-', SUBSTRING(transactionheaderid, 8, LENGTH(transactionheaderid)))
            END as orderid,                
            locationid,
            kioskid,
            ordersessionid,
            fact.parse_iso_timestamp(orderdateutc)  AS orderdateutc,
            order_completion_status                 AS orderstatus,
            CASE WHEN ordertype = ''
                   OR ordertype IS NULL THEN order_type_label
                 ELSE ordertype
            END                                     AS ordertypeid,
            numberofitems,
            numberofpayments,
            usd_reward          :: NUMERIC(12,3)    AS ordersredeemedrewards,
            usd_subtotal        :: NUMERIC(12,3)    AS ordersubtotal,
            usd_amount          :: NUMERIC(12,3)    AS ordertotal,
            usd_tax             :: NUMERIC(12,3)    AS ordertax,
            usd_tip             :: NUMERIC(12,3)    AS ordertip,
            usd_discount        :: NUMERIC(12,3)    AS orderdiscount,
            usd_charity_amount  :: NUMERIC(12,3)    AS charityamount,
            usd_service_charge  :: NUMERIC(12,3)    AS orderservicecharge,
            businessdate        :: DATE             AS businessdate,
            CASE channel
                WHEN 0 THEN 'Kiosk'
                WHEN 1 THEN 'OnlineOrdering'
                ELSE 'External'
            END                                     AS channel,
            guest_count                             AS guestcount,
            frequentcustomerid,
            customername,
            syscosmosts
        FROM stg.silver_transaction_header
        WHERE (is_test_order = False OR is_test_order IS NULL)
          AND syscosmosts > v_max_syscosmosts
        ORDER BY locationid, transactionheaderid, orderdateutc DESC

    ), qualified_trxns AS (

        SELECT
            dt.*,
            ot.id                                                        AS ordertype,
            dt.orderdateutc :: TIMESTAMPTZ AT TIME ZONE l.timezone       AS orderdatelocal
        FROM delta_transactions AS dt
        LEFT JOIN dim.ordertype AS ot
            ON  dt.locationid  = ot.locationid
            AND dt.kioskid     = ot.kioskid
            AND dt.ordertypeid = ot.ordertypeid
        LEFT JOIN dim.organization AS l
            ON dt.locationid = l.id

    ), aggregated_kiosk_events AS (

        -- Pre-filtered to only the sessions present in this batch.
        -- Avoids a full scan of silver_kiosk_events on every run.
        SELECT
            ke.locationid,
            ke.token,
            min(CASE WHEN lower(ke.eventcategory) = 'session'
                          AND lower(ke.eventtype)  = 'started'
                     THEN ke.eventinstant END)                           AS orderstarttime,
            min(CASE WHEN lower(ke.eventcategory) IN ('order','insight')
                          AND lower(ke.eventtype)  = 'revieworderclicked'
                     THEN ke.eventinstant END)                           AS reviewordertime,
            min(CASE WHEN lower(ke.eventcategory) IN ('order','insight')
                          AND lower(ke.eventtype)  = 'checkoutclicked'
                     THEN ke.eventinstant END)                           AS checkouttime,
            min(CASE WHEN lower(ke.eventcategory) = 'payment'
                          AND lower(ke.eventtype)  = 'create'
                     THEN ke.eventinstant END)                           AS paystarttime,
            max(CASE WHEN lower(ke.eventcategory) IN ('session','order')
                          AND lower(ke.eventtype)  = 'closed'
                     THEN ke.eventinstant END)                           AS sessionendtime
        FROM stg.silver_kiosk_events AS ke
        INNER JOIN qualified_trxns AS qt
            ON  qt.locationid     = ke.locationid
            AND qt.ordersessionid = ke.token
        WHERE lower(ke.severity) = 'information'
          AND (
                (lower(ke.eventcategory) = 'session'               AND lower(ke.eventtype) = 'started')            OR
                (lower(ke.eventcategory) IN ('order', 'insight')   AND lower(ke.eventtype) = 'revieworderclicked') OR
                (lower(ke.eventcategory) IN ('order', 'insight')   AND lower(ke.eventtype) = 'checkoutclicked')    OR
                (lower(ke.eventcategory) = 'payment'               AND lower(ke.eventtype) = 'create')             OR
                (lower(ke.eventcategory) IN ('session', 'order')   AND lower(ke.eventtype) = 'closed')
              )
        GROUP BY ke.locationid, ke.token

    ), orders_enriched AS (

        SELECT DISTINCT ON (locationid, transactionheaderid)
            qt.*,
            fact.parse_iso_timestamp(ke.orderstarttime)  :: TIMESTAMP AS orderstarttime,
            fact.parse_iso_timestamp(ke.reviewordertime) :: TIMESTAMP AS reviewordertime,
            fact.parse_iso_timestamp(ke.checkouttime)    :: TIMESTAMP AS checkouttime,
            fact.parse_iso_timestamp(ke.paystarttime)    :: TIMESTAMP AS paystarttime,
            fact.parse_iso_timestamp(ke.sessionendtime)  :: TIMESTAMP AS sessionendtime
        FROM qualified_trxns AS qt
        LEFT JOIN aggregated_kiosk_events AS ke
            ON  ke.locationid = qt.locationid
            AND ke.token      = qt.ordersessionid
        ORDER BY locationid, transactionheaderid, orderdateutc DESC

    )
    INSERT INTO fact.transactionheader (
        id,
        transactionheaderid,
        orderid,
        locationid,
        kioskid,
        ordersessionid,
        dateid,
        orderdateutc,
        orderdatelocal,
        orderstatus,
        ordertype,
        numberofitems,
        numberofpayments,
        ordersredeemedrewards,
        ordersubtotal,
        ordertotal,
        ordertax,
        ordertip,
        orderdiscount,
        orderbalance,
        paymentstatus,
        sourcefile,
        createddate,
        orderstarttime,
        reviewordertime,
        checkouttime,
        paystarttime,
        sessionendtime,
        precheckouttime,
        postcheckouttime,
        menupagetime,
        reviewpagetime,
        paymentpagetime,
        totalordertime,
        businessdate,
        frequentcustomerid,
        channel,
        guestcount,
        charityamount,
        syscosmosts,
        sourceid,
        orderservicecharge,
        customername
    )
    SELECT
        nextval('fact.transactionheader_id_seq')                    AS id,
        transactionheaderid,
        orderid,
        locationid,
        kioskid,
        ordersessionid,
        CAST(TO_CHAR(orderdatelocal, 'YYYYMMDDHH24') AS INTEGER)    AS dateid,
        orderdateutc,
        orderdatelocal,
        orderstatus,
        ordertype,
        numberofitems,
        numberofpayments,
        ordersredeemedrewards,
        ordersubtotal,
        ordertotal,
        ordertax,
        ordertip,
        orderdiscount,
        0.0 :: NUMERIC(12,3)                                        AS orderbalance,
        CASE WHEN numberofpayments > 0 THEN 'paid' END              AS paymentstatus,
        'NGE'                                                        AS sourcefile,
        now() :: TIMESTAMP                                           AS createddate,
        orderstarttime,
        reviewordertime,
        checkouttime,
        paystarttime,
        sessionendtime,
        EXTRACT(EPOCH FROM (checkouttime    - orderstarttime))      AS precheckouttime,
        EXTRACT(EPOCH FROM (sessionendtime  - checkouttime))        AS postcheckouttime,
        EXTRACT(EPOCH FROM (reviewordertime - orderstarttime))      AS menupagetime,
        EXTRACT(EPOCH FROM (checkouttime    - reviewordertime))     AS reviewpagetime,
        EXTRACT(EPOCH FROM (sessionendtime  - paystarttime))        AS paymentpagetime,
        EXTRACT(EPOCH FROM (sessionendtime  - orderstarttime))      AS totalordertime,
        businessdate,
        frequentcustomerid,
        channel,
        guestcount,
        charityamount,
        syscosmosts,
        1 :: INTEGER                                                 AS sourceid,
        orderservicecharge,
        customername
    FROM orders_enriched

    ON CONFLICT (locationid, transactionheaderid)
    DO UPDATE SET
        ordertype        = EXCLUDED.ordertype,
        orderstarttime   = COALESCE(fact.transactionheader.orderstarttime,   EXCLUDED.orderstarttime),
        reviewordertime  = COALESCE(fact.transactionheader.reviewordertime,  EXCLUDED.reviewordertime),
        checkouttime     = COALESCE(fact.transactionheader.checkouttime,     EXCLUDED.checkouttime),
        paystarttime     = COALESCE(fact.transactionheader.paystarttime,     EXCLUDED.paystarttime),
        sessionendtime   = COALESCE(fact.transactionheader.sessionendtime,   EXCLUDED.sessionendtime),
        precheckouttime  = COALESCE(
                               fact.transactionheader.precheckouttime,
                               EXTRACT(EPOCH FROM (EXCLUDED.checkouttime    - EXCLUDED.orderstarttime))
                           ),
        postcheckouttime = COALESCE(
                               fact.transactionheader.postcheckouttime,
                               EXTRACT(EPOCH FROM (EXCLUDED.sessionendtime  - EXCLUDED.checkouttime))
                           ),
        menupagetime     = COALESCE(
                               fact.transactionheader.menupagetime,
                               EXTRACT(EPOCH FROM (EXCLUDED.reviewordertime - EXCLUDED.orderstarttime))
                           ),
        reviewpagetime   = COALESCE(
                               fact.transactionheader.reviewpagetime,
                               EXTRACT(EPOCH FROM (EXCLUDED.checkouttime    - EXCLUDED.reviewordertime))
                           ),
        paymentpagetime  = COALESCE(
                               fact.transactionheader.paymentpagetime,
                               EXTRACT(EPOCH FROM (EXCLUDED.sessionendtime  - EXCLUDED.paystarttime))
                           ),
        totalordertime   = COALESCE(
                               fact.transactionheader.totalordertime,
                               EXTRACT(EPOCH FROM (EXCLUDED.sessionendtime  - EXCLUDED.orderstarttime))
                           ),
        updateddate      = now() :: TIMESTAMP
    WHERE (
        (fact.transactionheader.ordertype       IS NULL AND EXCLUDED.ordertype       IS NOT NULL) OR
        (fact.transactionheader.orderstarttime  IS NULL AND EXCLUDED.orderstarttime  IS NOT NULL) OR
        (fact.transactionheader.reviewordertime IS NULL AND EXCLUDED.reviewordertime IS NOT NULL) OR
        (fact.transactionheader.checkouttime    IS NULL AND EXCLUDED.checkouttime    IS NOT NULL) OR
        (fact.transactionheader.paystarttime    IS NULL AND EXCLUDED.paystarttime    IS NOT NULL) OR
        (fact.transactionheader.sessionendtime  IS NULL AND EXCLUDED.sessionendtime  IS NOT NULL)
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionheader WHERE sourceid = 1),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionheader'
      AND source             = 'nge';

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_transaction_header_to_fact() OWNER TO citus;

--
-- TOC entry 1430 (class 1255 OID 3600414)
-- Name: usp_silver_transaction_item_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_item_to_fact()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_max_syscosmosts BIGINT;
BEGIN

    SELECT COALESCE(ts, 1775002010) - 600
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionitem'
      AND source             = 'nge';

    WITH delta_items AS (

        SELECT * FROM (
            SELECT DISTINCT ON (
                transactionheaderid,
                COALESCE(orderitemid, itemsessionid, menuitemid),
                itemname
            )
                transactionheaderid,
                orderid,                
                locationid,
                ordersessionid,
                itemsessionid,
                COALESCE(orderitemid, itemsessionid, menuitemid)                    AS itemid,
                menuitemid                                                           AS raw_menuitemid,
                itemname,
                itemquantity                :: SMALLINT                             AS itemquantity,
                usd_itemunitprice           :: NUMERIC(12,3)                        AS itemunitprice,
                categoryid                                                           AS raw_categoryid,
                (NULLIF(items_upsell_source, '') :: json ->> 'upsellLevelType')     AS upselllevel,
                (NULLIF(items_upsell_source, '') :: json ->> 'upsellPromptItemId')  AS upsellpromptitemid,
                NULL :: TEXT                                                         AS comboid,
                'item' :: TEXT                                                       AS itemtype,
                businessdate                :: DATE                                 AS businessdate,
                fact.parse_iso_timestamp(orderdateutc)                              AS orderdateutc,
                frequentcustomerid,
                syscosmosts
            FROM stg.silver_transaction_item
            WHERE syscosmosts > v_max_syscosmosts
              AND (is_test_order = false OR is_test_order IS NULL)
            ORDER BY
                transactionheaderid,
                COALESCE(orderitemid, itemsessionid, menuitemid),
                itemname,
                syscosmosts DESC
        ) regular_items

        UNION ALL

        SELECT * FROM (
            SELECT DISTINCT ON (
                transactionheaderid,
                combo_order_item_id,
                combo_name
            )
                transactionheaderid,
                orderid,                
                locationid,
                ordersessionid,
                combo_item_session_id                                                AS itemsessionid,
                combo_order_item_id                                                  AS itemid,
                NULL :: TEXT                                                         AS raw_menuitemid,
                combo_name                                                           AS itemname,
                combo_quantity              :: SMALLINT                              AS itemquantity,
                (cents_combo_unit_price / 100.0) :: NUMERIC(12,3)                    AS itemunitprice,
                NULL :: TEXT                                                         AS raw_categoryid,
                (NULLIF(combo_upsell_source, '') :: json ->> 'upsellLevelType')      AS upselllevel,
                (NULLIF(combo_upsell_source, '') :: json ->> 'upsellPromptItemId')   AS upsellpromptitemid,
                combo_id                                                             AS comboid,
                'combo' :: TEXT                                                      AS itemtype,
                businessdate                :: DATE                                  AS businessdate,
                fact.parse_iso_timestamp(orderdateutc)                               AS orderdateutc,
                frequentcustomerid,
                syscosmosts
            FROM stg.silver_transaction_combo_items
            WHERE syscosmosts > v_max_syscosmosts
              AND (is_test_order = false OR is_test_order IS NULL)
            ORDER BY
                transactionheaderid,
                combo_order_item_id,
                combo_name,
                syscosmosts DESC
        ) combo_headers

        UNION ALL

        SELECT * FROM (
            SELECT DISTINCT ON (
                transactionheaderid,
                component_item_order_item_id,
                component_item_name
            )
                transactionheaderid,
                orderid,                
                locationid,
                ordersessionid,
                component_item_session_id                                            AS itemsessionid,
                component_item_order_item_id                                         AS itemid,
                component_item_menu_item_id                                          AS raw_menuitemid,
                component_item_name                                                  AS itemname,
                component_item_quantity     :: SMALLINT                             AS itemquantity,
                component_item_unit_price   :: NUMERIC(12,3)                        AS itemunitprice,
                NULL :: TEXT                                                         AS raw_categoryid,
                (NULLIF(component_item_upsell_source, '') :: json ->> 'upsellLevelType')    AS upselllevel,
                (NULLIF(component_item_upsell_source, '') :: json ->> 'upsellPromptItemId') AS upsellpromptitemid,
                combo_id                                                             AS comboid,
                'combocomponent' :: TEXT                                             AS itemtype,
                businessdate                :: DATE                                 AS businessdate,
                fact.parse_iso_timestamp(orderdateutc)                              AS orderdateutc,
                frequentcustomerid,
                syscosmosts
            FROM stg.silver_transaction_combo_items
            WHERE syscosmosts > v_max_syscosmosts
              AND (is_test_order = false OR is_test_order IS NULL)
              AND component_item_order_item_id IS NOT NULL
              AND component_item_name          IS NOT NULL
            ORDER BY
                transactionheaderid,
                component_item_order_item_id,
                component_item_name,
                syscosmosts DESC
        ) combo_components

    ), resolved AS MATERIALIZED (

        SELECT
            di.transactionheaderid,
            di.orderid,
            di.locationid,
            di.ordersessionid,
            di.itemsessionid,
            di.itemid,
            di.itemname,
            di.itemquantity,
            di.itemunitprice,
            di.raw_menuitemid                                                       AS dimmenuitemid,
            mi.id                                                                   AS menuitemid,
            ic.id                                                                   AS categoryid,
            di.upselllevel,
            di.upsellpromptitemid,
            di.comboid,
            di.itemtype,
            di.businessdate,
            di.orderdateutc,
            di.frequentcustomerid,
            di.syscosmosts
        FROM delta_items AS di
        LEFT JOIN dim.menuitem AS mi
            ON  mi.menuitemid  = di.raw_menuitemid
        LEFT JOIN dim.itemcategory AS ic
            ON  ic.locationid  = di.locationid
            AND ic.categoryid  = di.raw_categoryid

    ), gem_events AS (

        -- Scoped to only sessions present in the current delta batch
        -- to avoid a full scan of fact.userbehaviour
        SELECT
            ub.locationid,
            ub.token,
            ub.eventtype,
            fact.parse_iso_timestamp(eventinstant) :: TIMESTAMP AS eventtime
        FROM stg.silver_kiosk_events ub
        WHERE ub.eventtype IN (
            'ItemCustomizeClicked', 'CustomizeItemSelected', 'ComboCustomizeClicked',
            'RegularItemSelected',  'ComboComponentItemSelected', 'AddToCartClicked',
            'ComboSizeSelected',    'ComboItemSelected',          'AddAsIsSelected'
        )
          AND EXISTS (
              SELECT 1
              FROM resolved r
              WHERE r.ordersessionid = ub.token
                AND r.locationid     = ub.locationid
          )

    ), item_timing AS (

        SELECT
            r.transactionheaderid,
            r.itemid,
            r.itemname,
            r.itemtype,
            r.ordersessionid,
            r.itemsessionid,
            MAX(CASE WHEN ge.eventtype IN ('AddToCartClicked', 'AddAsIsSelected')
                THEN ge.eventtime END)                                              AS addtocarttime,
            MAX(CASE WHEN ge.eventtype IN (
                'RegularItemSelected', 'ComboComponentItemSelected',
                'ComboComponentSelected', 'ComboItemSelected')
                THEN ge.eventtime END)                                              AS itemselectedtime,
            SUM(CASE WHEN ge.eventtype IN (
                'CustomizeItemSelected', 'ComboCustomizeClicked', 'ItemCustomizeClicked')
                THEN 1 ELSE 0 END)                                                 AS customize_count,
            SUM(CASE WHEN ge.eventtype = 'ComboSizeSelected'
                THEN 1 ELSE 0 END)                                                 AS upgrade_count
        FROM resolved r
        LEFT JOIN gem_events ge
            ON  ge.token = r.ordersessionid
            AND ge.locationid             = r.locationid
        GROUP BY
            r.transactionheaderid, r.itemid, r.itemname,
            r.itemtype, r.ordersessionid, r.itemsessionid

    )
    INSERT INTO fact.transactionitem (
        transactionheaderid,
        categoryid,
        menuitemid,
        itemid,
        comboid,
        ordersessionid,
        itemsessionid,
        itemname,
        itemquantity,
        itemunitprice,
        upselllevel,
        upsellpromptitemid,
        orderid,
        itemtype,
        customize,
        upgrade,
        asis,
        itemselectedtime,
        addtocarttime,
        totaltime,
        orderdateutc,
        orderdatelocal,
        businessdate,
        sysinserttime,
        sysupdatetime,
        locationid,
        dimmenuitemid,
        syscosmosts,
        frequentcustomerid
    )
    SELECT DISTINCT ON (r.transactionheaderid, r.itemid, r.itemname)
        r.transactionheaderid,
        r.categoryid,
        r.menuitemid,
        r.itemid,
        r.comboid,
        r.ordersessionid,
        r.itemsessionid,
        r.itemname,
        r.itemquantity,
        r.itemunitprice,
        r.upselllevel,
        r.upsellpromptitemid,
        th.orderid,
        r.itemtype,
        COALESCE(t.customize_count, 0) >= 1                                         AS customize,
        COALESCE(t.upgrade_count,   0) >= 1                                         AS upgrade,
        COALESCE(t.customize_count, 0) <  1                                         AS asis,
        t.itemselectedtime,
        t.addtocarttime,
        ABS(COALESCE(
            EXTRACT(EPOCH FROM (t.addtocarttime - t.itemselectedtime)) :: NUMERIC(7,3),
            0
        ))                                                                           AS totaltime,
        r.orderdateutc,
        (r.orderdateutc :: TIMESTAMPTZ AT TIME ZONE org.timezone) :: TIMESTAMP      AS orderdatelocal,
        r.businessdate,
        NOW() :: TIMESTAMP                                                           AS sysinserttime,
        NOW() :: TIMESTAMP                                                           AS sysupdatetime,
        r.locationid,
        r.dimmenuitemid,
        r.syscosmosts,
        r.frequentcustomerid
    FROM resolved AS r
    LEFT JOIN item_timing AS t
        ON  t.transactionheaderid = r.transactionheaderid
        AND t.itemid              = r.itemid
        AND t.itemname            = r.itemname
        AND t.itemtype            = r.itemtype
        AND t.ordersessionid      = r.ordersessionid
        AND t.itemsessionid       = r.itemsessionid
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = r.locationid
        AND th.transactionheaderid = r.transactionheaderid
    LEFT JOIN dim.organization AS org
        ON  org.id = r.locationid
    --WHERE NOT EXISTS (
    --    SELECT 1
    --    FROM fact.transactionitem AS ti
    --    WHERE ti.transactionheaderid = r.transactionheaderid
    --      AND ti.itemid              = r.itemid
    --      AND ti.itemname            = r.itemname
    --)
    ORDER BY r.transactionheaderid, r.itemid, r.itemname, r.orderdateutc DESC
    ON CONFLICT (transactionheaderid, itemid, itemname)
    DO UPDATE SET
        customize        = EXCLUDED.customize,
        upgrade          = EXCLUDED.upgrade,
        asis             = EXCLUDED.asis,
        itemselectedtime = EXCLUDED.itemselectedtime,
        addtocarttime    = EXCLUDED.addtocarttime,
        totaltime        = EXCLUDED.totaltime,
        sysupdatetime    = NOW() :: TIMESTAMP
    WHERE
        fact.transactionitem.itemselectedtime IS NULL
        OR fact.transactionitem.addtocarttime IS NULL;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionitem WHERE transactionheaderid LIKE 'ordevt-%'),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionitem'
      AND source             = 'nge';

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_transaction_item_to_fact() OWNER TO citus;

--
-- TOC entry 958 (class 1255 OID 3553220)
-- Name: usp_silver_transaction_payment_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_payment_to_fact()
    LANGUAGE plpgsql
    AS $BODY$


DECLARE
    v_max_syscosmosts BIGINT;

BEGIN

    -- Capture watermark once upfront
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionpayment'
      AND source             = 'nge';


    WITH delta AS (
        -- Deduplicate: keep latest row per (location, header, payment)
        SELECT DISTINCT ON (locationid, transactionheaderid, payment_transactionid)
            transactionheaderid,
            orderid,
            locationid,
            kioskid,
            payment_integration_id          AS paymentintegrationid,
            payment_transactionid           AS paymentid,
            payment_amount  :: NUMERIC(12,3) AS paymentamt,
            payment_method                  AS paymentmethod,
            payment_integration_label       AS paymentintegrationlabel,
            payment_card_name               AS paymentcardtype,
            orderdateutc,
            syscosmosts
        FROM stg.silver_transaction_payment
        WHERE (is_test_order = False OR is_test_order IS NULL)
          AND syscosmosts > v_max_syscosmosts
        ORDER BY locationid, transactionheaderid, payment_transactionid, syscosmosts DESC
    )
    INSERT INTO fact.transactionpayment (
        transactionheaderid,
        paymentintegrationid,
        paymentid,
        paymentamt,
        orderid,
        locationid,
        kioskid,
        paymentmethod,
        paymentintegrationlabel,
        orderdateutc,
        sysinserttime,
        paymentcardtype,
        syscosmosts
    )
    SELECT
        d.transactionheaderid,
        d.paymentintegrationid,
        d.paymentid,
        d.paymentamt,
        th.orderid,
        d.locationid,
        d.kioskid,
        d.paymentmethod,
        d.paymentintegrationlabel,
        fact.parse_iso_timestamp(d.orderdateutc)  AS orderdateutc,
        now() :: TIMESTAMP                        AS sysinserttime,
        d.paymentcardtype,
        d.syscosmosts
    FROM delta as d
    INNER JOIN fact.transactionheader as th
            ON th.locationid          = d.locationid
           AND th.transactionheaderid = d.transactionheaderid
    WHERE NOT EXISTS (
            SELECT 1
            FROM fact.transactionpayment AS tp
            WHERE tp.locationid           = d.locationid
              AND tp.transactionheaderid  = d.transactionheaderid
              AND tp.paymentid            = d.paymentid
              AND tp.paymentintegrationid = d.paymentintegrationid
    );
    --ON CONFLICT (locationid, transactionheaderid, paymentintegrationid, paymentid)
    --DO NOTHING;  -- payments are immutable once recorded

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionpayment),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionpayment'
      AND source             = 'nge';

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_transaction_payment_to_fact() OWNER TO citus;

--
-- TOC entry 1095 (class 1255 OID 3629704)
-- Name: usp_silver_transaction_refunds_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_silver_transaction_refunds_to_fact()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_watermark     BIGINT;

BEGIN

    -- Capture watermark
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_watermark
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.transactionrefunds'
      AND source             = 'nge';

    WITH delta AS (
        -- Deduplicate: keep latest refund snapshot per (locationid, transactionheaderid)
        SELECT DISTINCT ON (locationid, transactionheaderid)
            locationid,
            transactionheaderid,
            orderid,
            original_transaction_id         AS paymentid,       -- c.originalTransactionId in CosmosDB
            refund_transaction_id           AS refundtransactionid,
            refund_type                     AS refundtype,
            refunded_amount                 AS refundamount,
            fact.parse_iso_timestamp(orderdateutc) AS orderdateutc,
            syscosmosts
        FROM stg.silver_transaction_refunds as tr
        WHERE syscosmosts > v_watermark
        AND EXISTS (SELECT 1 FROM fact.transactionpayment as tp 
                    WHERE tp.locationid = tr.locationid
                      AND tp.orderid    = tr.orderid
                    )
        ORDER BY locationid, transactionheaderid, syscosmosts DESC
    )
    INSERT INTO fact.transactionrefunds (
        transactionheaderid,
        orderid,
        locationid,
        refundtransactionid,
        paymentid,
        refundamount,
        refundtype,
        orderdateutc,
        sysinserttime,
        syscosmosts
    )
    SELECT
        d.transactionheaderid,
        d.orderid,
        d.locationid,
        d.refundtransactionid,
        d.paymentid,
        d.refundamount,
        d.refundtype,
        d.orderdateutc,
        NOW() :: TIMESTAMP      AS sysinserttime,
        d.syscosmosts
    FROM delta d
    -- mirror ADF ExistingPayments step: only load refunds for orders already in fact layer
    INNER JOIN fact.transactionheader th
            ON th.locationid = d.locationid 
           AND th.orderid    = d.orderid
    -- mirror ADF NewRefunds step (negate:true): skip if already recorded
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.transactionrefunds tr
        WHERE tr.locationid = d.locationid
          AND tr.transactionheaderid = d.transactionheaderid
    );

    -- ----------------------------------------------------------
    -- Update paymentstatus on transactionheader for all refunds
    -- in this batch. ROW_NUMBER() picks the latest refund event
    -- per order in case of multiple partial/full refund records.
    -- Scoped to current batch via v_watermark (same value used
    -- in the INSERT above) to avoid re-processing old refunds.
    -- ----------------------------------------------------------
    WITH latest_refunds AS (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY locationid, orderid
                   ORDER BY orderdateutc DESC
               ) AS rn
        FROM fact.transactionrefunds
        WHERE COALESCE(syscosmosts, 1775002010) > v_watermark
    )
    UPDATE fact.transactionheader
    SET paymentstatus = CASE LOWER(r.refundtype)
                            WHEN 'fullrefund' THEN 'Fully refunded'
                            ELSE                   'Partially refunded'
                        END,
        updateddate   = NOW() :: TIMESTAMP
    FROM latest_refunds r
    WHERE fact.transactionheader.locationid = r.locationid
      AND fact.transactionheader.orderid    = r.orderid
      AND r.rn = 1;

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.transactionrefunds),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.transactionrefunds'
      AND source             = 'nge';

END;
$BODY$;


ALTER PROCEDURE fact.usp_silver_transaction_refunds_to_fact() OWNER TO citus;

--
-- TOC entry 1098 (class 1255 OID 3607278)
-- Name: usp_silver_upsell_recommendations_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

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


ALTER PROCEDURE fact.usp_silver_upsell_recommendations_to_fact() OWNER TO citus;

--
-- TOC entry 1386 (class 1255 OID 3613228)
-- Name: usp_stg_occasionsurveydetail_to_fact(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_stg_occasionsurveydetail_to_fact()
    LANGUAGE plpgsql
    AS $BODY$

DECLARE
    v_max_syscosmosts_nge   BIGINT;
    v_max_syscosmosts_gem   BIGINT;
BEGIN

    -- Separate watermarks to avoid one source suppressing the other
    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts_nge
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.occasionsurveydetail'
      AND source             = 'nge';

    SELECT COALESCE(ts, 1775002010) - 10
    INTO v_max_syscosmosts_gem
    FROM fact.watermarktable
    WHERE watermarktablename = 'fact.occasionsurveydetail'
      AND source             = 'gem';


    -- ================================================================
    -- Stream 1: NGE Survey Feedbacks (sourceid = 1)     [UNCHANGED]
    --
    -- Dedup key  : (locationid, surveytransid, orderid)
    -- Lookups    : dim.organizationlocation → organizationid
    --              dim.occasionsurvey       → validates survey exists
    -- Gate       : fact.transactionheader INNER JOIN (orderstatus = 'order-placed')
    -- ordersessionid resolved from transactionheader (not in Cosmos NGE source)
    -- ================================================================
    INSERT INTO fact.occasionsurveydetail (
        organizationid,
        locationid,
        dateid,
        surveyid,
        surveytransid,
        orderid,
        ordersessionid,
        surveyrating,
        surveytransstatus,
        surveycompletedtimestamp,
        surveylocaltimestamp,
        surveytype,
        sysinserttime,
        syscosmosts,
        sourceid
    )
    SELECT DISTINCT ON (stg.locationid, stg.surveytransid, stg.orderid)
        ol.organizationid,
        stg.locationid,
        stg.dateid,
        stg.surveyid,
        stg.surveytransid,
        stg.orderid,
        COALESCE(stg.ordersessionid, th.ordersessionid)                     AS ordersessionid,
        stg.surveyrating,
        stg.surveytransstatus,
        stg.surveycompletedtimestamp,
        stg.surveylocaltimestamp,
        COALESCE(
            stg.surveytype,
            CASE WHEN stg.surveyrating ~ '^\d+$' THEN 1 ELSE 2 END
        )                                                                   AS surveytype,
        now() :: TIMESTAMP                                                  AS sysinserttime,
        stg.syscosmosts,
        1                                                                   AS sourceid
    FROM stg.fact_occasionsurveydetail AS stg
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid          = stg.locationid
        AND th.transactionheaderid = stg.orderid
        AND th.orderstatus         = 'order-placed'
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = stg.locationid
        AND ol.organizationtype = 0
    INNER JOIN dim.occasionsurvey AS os
        ON  os.organizationid = ol.organizationid
        AND os.surveyid       = stg.surveyid
    WHERE stg.syscosmosts   > v_max_syscosmosts_nge
    AND NOT EXISTS (
        SELECT 1
        FROM fact.occasionsurveydetail AS f
        WHERE f.locationid      = stg.locationid
            AND f.surveytransid = stg.surveytransid
            AND f.orderid       = stg.orderid
            AND f.sourceid      = 2
    );

    -- ================================================================
    -- Stream 2: GEM Skipped Surveys (sourceid = 2)      [MODIFIED]
    --
    -- Source     : stg.silver_kiosk_events (replaces stg.fact_occasionsurveydetail)
    -- Dedup key  : (locationid, ordersessionid) WHERE sourceid = 2
    -- Lookups    : dim.organizationlocation → organizationid
    -- Gate       : fact.transactionheader INNER JOIN on ordersessionid
    --              → resolves orderid = transactionheaderid
    --              → validates orderstatus = 'order-placed'
    -- Sparse insert: no surveyid, surveyrating, surveytransstatus, surveytype
    -- ================================================================
    WITH delta_skipped AS (

        -- Deduplicate within the incoming batch.
        -- A session could theoretically produce multiple 'skipped' events;
        -- keep the latest one by syscosmosts.
        SELECT DISTINCT ON (locationid, token)
            locationid,
            token           AS ordersessionid,
            eventinstant    AS surveycompletedtimestamp,
            syscosmosts
        FROM stg.silver_kiosk_events
        WHERE eventmodule               = 'kiosk'
          AND eventcategory             = 'Survey'
          AND eventtype                 = 'SurveySkipped'
          AND token                     > ''
          AND syscosmosts               > v_max_syscosmosts_gem
        ORDER BY locationid, token, syscosmosts DESC

    )
    INSERT INTO fact.occasionsurveydetail (
        organizationid,
        locationid,
        orderid,
        ordersessionid,
        surveycompletedtimestamp,
        sysinserttime,
        syscosmosts,
        sourceid
    )
    SELECT
        ol.organizationid,
        ds.locationid,
        th.transactionheaderid          AS orderid,
        ds.ordersessionid,
        ds.surveycompletedtimestamp,
        now() :: TIMESTAMP              AS sysinserttime,
        ds.syscosmosts,
        2                               AS sourceid
    FROM delta_skipped AS ds
    -- Resolves orderid and validates the order exists and was placed
    INNER JOIN fact.transactionheader AS th
        ON  th.locationid     = ds.locationid
        AND th.ordersessionid = ds.ordersessionid
        AND th.orderstatus    = 'order-placed'
    LEFT JOIN dim.organizationlocation AS ol
        ON  ol.locationid       = ds.locationid
        AND ol.organizationtype = 0
    WHERE NOT EXISTS (
        SELECT 1
        FROM fact.occasionsurveydetail AS f
        WHERE f.locationid    = ds.locationid
          AND f.ordersessionid = ds.ordersessionid
          AND f.sourceid      = 2
    );

    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.occasionsurveydetail WHERE sourceid = 1),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.occasionsurveydetail'
      AND source             = 'nge';


    UPDATE fact.watermarktable
    SET ts = (SELECT COALESCE(MAX(syscosmosts), 1775002010) FROM fact.occasionsurveydetail WHERE sourceid = 2),
        sysupdatetime = NOW() :: TIMESTAMP
    WHERE watermarktablename = 'fact.occasionsurveydetail'
      AND source             = 'gem';



END;
$BODY$;


ALTER PROCEDURE fact.usp_stg_occasionsurveydetail_to_fact() OWNER TO citus;

--
-- TOC entry 1222 (class 1255 OID 630014)
-- Name: usp_update_datetime_fields(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_update_datetime_fields()
    LANGUAGE plpgsql
    AS $BODY$
BEGIN

UPDATE fact.transactionheader 
   SET orderdatelocal = ((transactionheader.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE l.timezone),
       updateddate    = NOW()
FROM dim.organization AS l
WHERE (l.id = transactionheader.locationid) AND (transactionheader.orderdatelocal IS NULL);

UPDATE fact.transactionheader 
   SET orderdatelocal = ((transactionheader.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE 'America/New_York'::text),
       updateddate    = NOW()
WHERE (transactionheader.orderdatelocal IS NULL);

UPDATE fact.transactionheader 
   SET dateid      = (to_char(transactionheader.orderdatelocal, 'YYYYMMDDHH24'::text))::integer,
       updateddate = NOW()
WHERE (transactionheader.dateid IS NULL);

UPDATE fact.transactionheader 
   SET businessdate = (transactionheader.orderdatelocal)::date,
       updateddate = NOW()
WHERE (transactionheader.businessdate IS NULL);

UPDATE fact.transactionheader 
   SET abtestid = abtests.abtestid
FROM dim.abtests
WHERE (abtests.ordersessionid = transactionheader.ordersessionid) AND (transactionheader.abtestid IS NULL);



UPDATE fact.transactionitem 
   SET orderdatelocal = ((transactionitem.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE l.timezone),
       sysupdatetime  = NOW()
FROM dim.organization AS l
WHERE (l.id = transactionitem.locationid) AND (transactionitem.orderdatelocal IS NULL);

UPDATE fact.transactionitem
   SET orderdatelocal = ((transactionitem.orderdateutc) :: TIMESTAMPTZ AT TIME ZONE 'America/New_York'::text),
       sysupdatetime  = NOW()
WHERE (transactionitem.orderdatelocal IS NULL);

UPDATE fact.transactionitem 
   SET businessdate  = (transactionitem.orderdatelocal)::date,
       sysupdatetime = NOW()
WHERE (transactionitem.businessdate IS NULL);



END;
$BODY$;


ALTER PROCEDURE fact.usp_update_datetime_fields() OWNER TO citus;

--
-- TOC entry 1448 (class 1255 OID 3024871)
-- Name: usp_update_occasion_survey_datetime_fields(); Type: PROCEDURE; Schema: fact; Owner: citus
--

CREATE OR REPLACE PROCEDURE fact.usp_update_occasion_survey_datetime_fields()
    LANGUAGE plpgsql
    AS $BODY$

BEGIN

UPDATE fact.occasionsurveydetail
SET organizationid = ol.organizationid
FROM (select * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
WHERE occasionsurveydetail.locationid = ol.locationid 
  and occasionsurveydetail.organizationid is null;

UPDATE fact.itemssurvey
SET organizationid = ol.organizationid
FROM (select * FROM dim.organizationlocation WHERE organizationtype = 0) as ol 
WHERE itemssurvey.locationid = ol.locationid 
  and itemssurvey.organizationid is null;

UPDATE fact.occasionsurveydetail
SET surveylocaltimestamp = surveycompletedtimestamp::TIMESTAMPTZ AT TIME ZONE l.timezone
FROM (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end as timezone FROM dim.location) as l
WHERE occasionsurveydetail.locationid = l.locationid
  and occasionsurveydetail.surveylocaltimestamp is null;

UPDATE fact.occasionsurveydetail
SET surveylocaltimestamp = surveycompletedtimestamp::TIMESTAMPTZ AT TIME ZONE 'America/New_York'
WHERE surveylocaltimestamp is null;

UPDATE fact.itemssurvey
SET surveylocaltimestamp = surveycompletedtimestamp::TIMESTAMPTZ AT TIME ZONE l.timezone
FROM (select distinct locationid, case when timezone is null or timezone='' then 'America/New_York' else timezone end as timezone FROM dim.location) as l
WHERE itemssurvey.locationid = l.locationid
  and itemssurvey.surveylocaltimestamp is null;

UPDATE fact.itemssurvey
SET surveylocaltimestamp = surveycompletedtimestamp::TIMESTAMPTZ AT TIME ZONE 'America/New_York'
WHERE surveylocaltimestamp is null;

UPDATE fact.occasionsurveydetail
SET dateid = cast(to_char(surveylocaltimestamp, 'YYYYMMDDHH24') as INTEGER)
WHERE dateid is null;

UPDATE fact.itemssurvey
SET dateid = cast(to_char(surveylocaltimestamp, 'YYYYMMDDHH24') as INTEGER)
WHERE dateid is null;

DELETE FROM fact.occasionsurveydetail as osd
WHERE NOT EXISTS (SELECT 1 FROM dim.occasionsurvey as os 
                WHERE os.organizationid = osd.organizationid
                  AND os.surveyid = osd.surveyid);

DELETE FROM fact.itemssurvey as its 
WHERE NOT EXISTS (SELECT 1 FROM dim.occasionsurvey as os 
                WHERE os.organizationid = its.organizationid
                  AND os.surveyid = its.surveyid);

UPDATE fact.watermarktable
SET ts = tr.maxts,
    sysupdatetime = NOW() :: TIMESTAMP
FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.occasionsurveydetail' as tablename FROM fact.occasionsurveydetail WHERE sourceid = 1) as tr 
WHERE watermarktable.watermarktablename = tr.tablename
  AND watermarktable.source = 'nge';

UPDATE fact.watermarktable
SET ts = tr.maxts,
    sysupdatetime = NOW() :: TIMESTAMP
FROM (SELECT coalesce(max(syscosmosts), 1500000010) as maxts, 'fact.occasionsurveydetail' as tablename FROM fact.occasionsurveydetail WHERE sourceid = 2) as tr 
WHERE watermarktable.watermarktablename = tr.tablename
  AND watermarktable.source = 'gem';

UPDATE fact.watermarktable
SET ts = (SELECT coalesce(max(nge_syscosmosts), 1720000300) - 10 FROM fact.itemssurvey),
    sysupdatetime = NOW() :: TIMESTAMP
WHERE watermarktablename = 'fact.itemssurvey'
  AND source = 'nge';


END;
$BODY$;


ALTER PROCEDURE fact.usp_update_occasion_survey_datetime_fields() OWNER TO citus;