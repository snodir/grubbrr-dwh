select * from fact.transactionheader where transactionheaderid = 'ordevt-P5LOYP1V6SCAK6FP';
select * from fact.transactionitem where transactionheaderid = 'ordevt-P5LOYP1V6SCAK6FP';
select * from fact.recommendations where transactionheaderid = 'ordevt-P5LOYP1V6SCAK6FP';

ALTER TABLE IF EXISTS fact.vw_offer_analysis
--DROP CONSTRAINT trxnid_recommendationid_itemid_uidx,-- IF EXISTS,
ADD CONSTRAINT trxnid_recommendationid_itemid_uidx UNIQUE (locationid, transactionheaderid, recommendationid, offereditem) --21 seconds



--INSERT INTO fact.recommendations()
SELECT th.locationid, th.transactionheaderid, th.syscosmosts
FROM fact.transactionheader as th
WHERE th.locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992' 
  AND th.transactionheaderid = 'ordevt-P5LOYP1V6SCAK6FP'



SELECT th.businessdate, rc.*
FROM fact.recommendations as rc 
INNER JOIN fact.transactionheader as th 
        ON th.locationid          = rc.locationid
       AND th.transactionheaderid = rc.transactionheaderid
       AND rc.locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
WHERE th.businessdate >= '2026-05-20' :: DATE AND th.businessdate < '2026-06-18' :: DATE
  AND rc.offereditems :: TEXT LIKE '%"Order"%'
ORDER BY rc.prompttimestamp DESC



SELECT rc.offereditems, rc.selecteditems, ti.*
FROM fact.transactionitem as ti 
INNER JOIN fact.recommendations as rc 
        ON rc.locationid = ti.locationid
       AND rc.transactionheaderid = ti.transactionheaderid
WHERE ti.locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
  --AND ti.transactionheaderid = 'ordevt-C2RTP61WKYMW1GIV'
  AND ti.businessdate >= '2026-05-20' :: DATE AND ti.businessdate < '2026-06-18' :: DATE
  AND ti.upselllevel IS NOT NULL AND ti.upselllevel <> ''
ORDER BY ti.orderdateutc DESC; --LIMIT 100;

SELECT th.businessdate, oa.*
FROM fact.vw_offer_analysis as oa 
INNER JOIN fact.transactionheader as th 
        ON th.locationid          = oa.locationid
       AND th.transactionheaderid = oa.transactionheaderid
       --AND oa.locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
WHERE 1=1 --AND oa.locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
AND oa.offereditem_upselllevel = 'AI-Order' AND oa.selecteditem_upselllevel = 'AI-Order'
--AND oa.selecteditem IS NOT NULL
AND th.businessdate >= '2026-05-20' :: DATE AND th.businessdate < '2026-06-18' :: DATE
ORDER BY oa.prompttimestamp DESC
LIMIT 1000;


SELECT *
FROM fact.transactionitem as ti
WHERE ti.locationid         = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
  AND ti.businessdate BETWEEN '2026-05-20' :: DATE AND '2026-06-18' :: DATE
  AND ti.upselllevel        = 'Order'
  AND EXISTS (SELECT 1 FROM fact.vw_offer_analysis as oa
              WHERE oa.locationid          = ti.locationid
                AND oa.transactionheaderid = ti.transactionheaderid
                )

SELECT *
FROM fact.vw_offer_analysis as oa
WHERE oa.locationid              = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
  AND oa.offereditem_upselllevel = 'Order'
  --AND oa.offereditem          LIKE 'itm-%'
  AND EXISTS (SELECT 1 FROM fact.transactionitem as ti
              WHERE ti.locationid          = oa.locationid
                AND ti.transactionheaderid = oa.transactionheaderid
                AND ti.businessdate BETWEEN '2026-05-20' :: DATE AND '2026-06-18' :: DATE
                AND ti.upselllevel         = 'AI-Order'
                --AND oa.offereditem_upselllevel = 'Order'
                )

UPDATE fact.vw_offer_analysis
SET upselltype               = 'Smart Order Upsells',
    selecteditem_upselllevel = 'AI-Order',
    offereditem_upselllevel  = 'AI-Order',
    sysupdatetime            = NOW() :: TIMESTAMP
WHERE locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
  AND offereditem_upselllevel = 'Order' 
  AND selecteditem_upselllevel = 'Order'
  AND EXISTS (SELECT 1 FROM fact.transactionitem as ti
              WHERE ti.locationid          = vw_offer_analysis.locationid
                AND ti.transactionheaderid = vw_offer_analysis.transactionheaderid
                AND ti.businessdate BETWEEN '2026-05-20' :: DATE AND '2026-06-18' :: DATE
                AND ti.upselllevel         = 'AI-Order'
                --AND vw_offer_analysis.offereditem_upselllevel = 'Order'
                )


UPDATE fact.transactionitem
SET upselllevel   = CASE WHEN upselllevel IN ('AI', 'AIOrder') THEN 'AI-Order'
                         WHEN upselllevel IN ('Item', 'AIItem') THEN 'AI-Item'
                         ELSE upselllevel END,
    sysupdatetime = NOW() :: TIMESTAMP
WHERE locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
  AND businessdate >= '2026-05-20' :: DATE AND businessdate < '2026-06-18' :: DATE
  AND upselllevel IS NOT NULL AND upselllevel <> ''

UPDATE fact.recommendations
SET offereditems = REPLACE(
                       REPLACE(
                           REPLACE(
                               REPLACE(offereditems :: TEXT, '"AIOrder"', '"AI-Order"'), 
                               '"AI"', '"AI-Order"'), 
                          '"Item"', '"AI-Item"'), 
                       '"AIItem"', '"AI-Item"') :: JSONB,
    selecteditems = REPLACE(
                       REPLACE(
                           REPLACE(
                               REPLACE(selecteditems :: TEXT, '"AIOrder"', '"AI-Order"'), 
                               '"AI"', '"AI-Order"'), 
                          '"Item"', '"AI-Item"'), 
                       '"AIItem"', '"AI-Item"') :: JSONB
--SELECT FROM fact.recommendations
WHERE locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
  AND EXISTS (SELECT 1 FROM fact.transactionheader as th
              WHERE th.locationid          = recommendations.locationid
                AND th.transactionheaderid = recommendations.transactionheaderid
                AND th.businessdate       >= '2026-05-20' :: DATE 
                AND th.businessdate        < '2026-06-18' :: DATE )



UPDATE fact.transactionitem
SET upselllevel   = 'AI-Order',
    sysupdatetime = NOW() :: TIMESTAMP
FROM fact.vw_offer_analysis as oa 
WHERE transactionitem.locationid        = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992' -- oa.locationid
  AND transactionitem.transactionheaderid = oa.transactionheaderid
  AND transactionitem.businessdate BETWEEN '2026-05-20' :: DATE AND '2026-06-18' :: DATE
  AND transactionitem.upselllevel = 'Order'
  --AND oa.offereditem_upselllevel = 'AI-Order' --AND oa.selecteditem_upselllevel = 'AI-Order';




--DELETE FROM fact.vw_offer_analysis WHERE EXISTS (SELECT 1 FROM fact.transactionheader as th
              WHERE th.locationid          = vw_offer_analysis.locationid
                AND th.transactionheaderid = vw_offer_analysis.transactionheaderid
                AND th.businessdate       >= '2026-05-20' :: DATE 
                AND th.businessdate        < '2026-06-18' :: DATE );


--INSERT 0 1,125,331
INSERT INTO fact.vw_offer_analysis(
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
FROM fact.vw_offer_analysis_hhc as hhc 
WHERE NOT EXISTS (SELECT 1  FROM fact.vw_offer_analysis as oa
                  WHERE oa.locationid = hhc.locationid
                    AND oa.transactionheaderid = hhc.transactionheaderid
                    AND oa.recommendationid = hhc.recommendationid
                    AND oa.offereditem = hhc.offereditem
)

WITH delta AS (
    SELECT th.businessdate, rc.*
    FROM fact.recommendations as rc 
    INNER JOIN fact.transactionheader as th 
            ON th.locationid          = rc.locationid
        AND th.transactionheaderid = rc.transactionheaderid
        --AND rc.locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992'
    WHERE th.businessdate >= '2026-05-20' :: DATE AND th.businessdate < '2026-06-18' :: DATE
--ORDER BY rc.prompttimestamp DESC
), rec AS (
        SELECT
            rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.offereditems,
            rc.prompttimestamp,
            rc.prompttimestamp :: TIMESTAMP                            AS upsellprompttime,
            rc.syscosmosts,
            (arr.obj ->> 'itemId')       :: TEXT                       AS offered_itemid,
            (arr.obj ->> 'upsellLevel')  :: TEXT                       AS offered_upselllevel,
            (arr.obj ->> 'promptItemId') :: TEXT                       AS offered_prmpid,
            (arr.obj ->> 'upsellGroupId'):: TEXT                       AS offered_upslgrpid
        FROM delta AS rc
        LEFT JOIN LATERAL jsonb_array_elements(rc.offereditems) AS arr(obj) ON TRUE
), selected AS (
        SELECT
            rc.transactionheaderid,
            rc.locationid,
            rc.recommendationid,
            rc.selecteditems,
            rc.prompttimestamp,
            (arr.obj ->> 'itemId')       :: TEXT                       AS selected_itemid,
            (arr.obj ->> 'quantity')     :: TEXT                       AS selected_quantity,
            (arr.obj ->> 'upsellLevel')  :: TEXT                       AS selected_upselllevel,
            (arr.obj ->> 'promptItemId') :: TEXT                       AS selected_prmpid,
            (arr.obj ->> 'upsellGroupId'):: TEXT                       AS selected_upslgrpid
        FROM delta AS rc
        LEFT JOIN LATERAL jsonb_array_elements(rc.selecteditems) arr(obj) ON TRUE
), item_analysis AS (
        SELECT
            r.locationid,
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid                                                AS offereditem,
            CASE
                WHEN lower(r.offered_upselllevel) = 'item'                         THEN 'Item'
                WHEN lower(r.offered_upselllevel) = 'order'                        THEN 'Order'
                WHEN lower(r.offered_upselllevel) IN ('ai-item', 'aiitem')         THEN 'AI-Item'
                WHEN lower(r.offered_upselllevel) IN ('ai', 'ai-order', 'aiorder') THEN 'AI-Order'
                ELSE r.offered_upselllevel
            END                                                             AS offereditem_upselllevel,
            r.offered_prmpid                                                AS offered_promptitemid,
            r.offered_upslgrpid                                             AS offered_upsellgroupid,
            s.selected_itemid                                               AS selecteditem,
            CASE
                WHEN lower(s.selected_upselllevel) = 'item'                         THEN 'Item'
                WHEN lower(s.selected_upselllevel) = 'order'                        THEN 'Order'
                WHEN lower(s.selected_upselllevel) IN ('ai-item', 'aiitem')         THEN 'AI-Item'
                WHEN lower(s.selected_upselllevel) IN ('ai', 'ai-order', 'aiorder') THEN 'AI-Order'
                ELSE s.selected_upselllevel
            END                                                             AS selecteditem_upselllevel,
            s.selected_prmpid                                               AS selected_promptitemid,
            s.selected_upslgrpid                                            AS selected_upsellgroupid,
            CASE
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'item'                         THEN 'Item Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'order'                        THEN 'Order Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) IN ('ai-item', 'aiitem')         THEN 'Smart Item Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) IN ('ai', 'ai-order', 'aiorder') THEN 'Smart Order Upsells'
                ELSE COALESCE(s.selected_upselllevel, r.offered_upselllevel)
            END                                                             AS upselltype,
            COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)             AS upsellgroupid,
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
        LEFT JOIN selected AS s
            ON  s.locationid          :: TEXT = r.locationid          :: TEXT
            AND s.transactionheaderid :: TEXT = r.transactionheaderid :: TEXT
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
            CASE
                WHEN lower(r.offered_upselllevel) = 'item'                         THEN 'Item'
                WHEN lower(r.offered_upselllevel) = 'order'                        THEN 'Order'
                WHEN lower(r.offered_upselllevel) IN ('ai-item', 'aiitem')         THEN 'AI-Item'
                WHEN lower(r.offered_upselllevel) IN ('ai', 'ai-order', 'aiorder') THEN 'AI-Order'
                ELSE r.offered_upselllevel
            END                                                             AS offereditem_upselllevel,
            r.offered_prmpid                                                AS offered_promptitemid,
            r.offered_upslgrpid                                             AS offered_upsellgroupid,
            s.selected_itemid                                               AS selecteditem,
            CASE
                WHEN lower(s.selected_upselllevel) = 'item'                         THEN 'Item'
                WHEN lower(s.selected_upselllevel) = 'order'                        THEN 'Order'
                WHEN lower(s.selected_upselllevel) IN ('ai-item', 'aiitem')         THEN 'AI-Item'
                WHEN lower(s.selected_upselllevel) IN ('ai', 'ai-order', 'aiorder') THEN 'AI-Order'
                ELSE s.selected_upselllevel
            END                                                             AS selecteditem_upselllevel,
            s.selected_prmpid                                               AS selected_promptitemid,
            s.selected_upslgrpid                                            AS selected_upsellgroupid,
            CASE
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'item'                         THEN 'Item Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) = 'order'                        THEN 'Order Level Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) IN ('ai-item', 'aiitem')         THEN 'Smart Item Upsells'
                WHEN lower(COALESCE(s.selected_upselllevel, r.offered_upselllevel)) IN ('ai', 'ai-order', 'aiorder') THEN 'Smart Order Upsells'
                ELSE COALESCE(s.selected_upselllevel, r.offered_upselllevel)
            END                                                             AS upselltype,
            COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)             AS upsellgroupid,
            ul.upsellgroupname,
            CASE
                WHEN lower(s.selected_quantity) = ANY (ARRAY['true', '1']) THEN 1
                ELSE lower(s.selected_quantity) :: INTEGER
            END                                                             AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            NOW()                                                           AS sysinserttime
        FROM (SELECT * FROM rec 
              WHERE rec.offered_itemid LIKE 'cat-%'
                AND EXISTS 
                    (SELECT 1 FROM selected
                     WHERE selected.locationid          = rec.locationid
                       AND selected.transactionheaderid = rec.transactionheaderid
                       AND selected.recommendationid    = rec.recommendationid
                       AND selected.selected_itemid IS NOT NULL)
                ) AS r
        INNER JOIN dim.category_hierarchy   AS ctg
            ON  ctg.locationid = r.locationid
            AND ctg.categoryid = r.offered_itemid
        INNER JOIN (
                SELECT * FROM selected
                WHERE EXISTS --selected.selected_itemid NOT IN (SELECT offered_itemid FROM rec) 
                    (SELECT 1 FROM rec
                     WHERE rec.locationid          = selected.locationid
                       AND rec.transactionheaderid = selected.transactionheaderid
                       AND rec.recommendationid    = selected.recommendationid
                       AND rec.offered_itemid LIKE 'cat-%'
                       AND selected.selected_itemid IS NOT NULL)
              ) AS s
            ON  s.locationid          :: TEXT = r.locationid          :: TEXT
            AND s.transactionheaderid :: TEXT = r.transactionheaderid :: TEXT
            AND s.recommendationid    :: TEXT = r.recommendationid    :: TEXT
            AND s.selected_itemid             = ctg.menuitemid
        LEFT JOIN dim.upsellgrouplookup     AS ul
            ON  ul.upsellgroupid :: TEXT = COALESCE(s.selected_upslgrpid, r.offered_upslgrpid)
), unselected_category AS (
        SELECT
            r.locationid,
            r.transactionheaderid,
            r.recommendationid,
            r.offered_itemid                                                AS offereditem,
            CASE
                WHEN lower(r.offered_upselllevel) = 'item'                         THEN 'Item'
                WHEN lower(r.offered_upselllevel) = 'order'                        THEN 'Order'
                WHEN lower(r.offered_upselllevel) IN ('ai-item', 'aiitem')         THEN 'AI-Item'
                WHEN lower(r.offered_upselllevel) IN ('ai', 'ai-order', 'aiorder') THEN 'AI-Order'
                ELSE r.offered_upselllevel
            END                                                             AS offereditem_upselllevel,
            r.offered_prmpid                                                AS offered_promptitemid,
            r.offered_upslgrpid                                             AS offered_upsellgroupid,
            NULL :: TEXT                                                    AS selecteditem,
            NULL :: TEXT                                                    AS selecteditem_upselllevel,
            NULL :: TEXT                                                    AS selected_promptitemid,
            NULL :: TEXT                                                    AS selected_upsellgroupid,
            CASE
                WHEN lower(r.offered_upselllevel) = 'item'                         THEN 'Item Level Upsells'
                WHEN lower(r.offered_upselllevel) = 'order'                        THEN 'Order Level Upsells'
                WHEN lower(r.offered_upselllevel) IN ('ai-item', 'aiitem')         THEN 'Smart Item Upsells'
                WHEN lower(r.offered_upselllevel) IN ('ai', 'ai-order', 'aiorder') THEN 'Smart Order Upsells'
                ELSE r.offered_upselllevel
            END                                                             AS upselltype,
            r.offered_upslgrpid                                             AS upsellgroupid,
            ul.upsellgroupname,
            NULL :: INTEGER                                                 AS quantity,
            r.prompttimestamp,
            r.upsellprompttime,
            r.syscosmosts,
            NOW()                                                           AS sysinserttime
        FROM rec as r
        LEFT JOIN dim.upsellgrouplookup     AS ul
               ON ul.upsellgroupid :: TEXT = r.offered_upslgrpid :: TEXT
        WHERE r.offered_itemid LIKE 'cat-%'
          AND EXISTS 
                    (SELECT 1 FROM selected
                     WHERE selected.locationid          = r.locationid
                       AND selected.transactionheaderid = r.transactionheaderid
                       AND selected.recommendationid    = r.recommendationid
                       AND selected.selected_itemid IS NULL)
), total AS (
        SELECT * FROM item_analysis
        UNION
        SELECT * FROM category_analysis
        UNION
        SELECT * FROM unselected_category
)
INSERT INTO fact.vw_offer_analysis_hhc (
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

/*
-- Table: fact.vw_offer_analysis

-- DROP TABLE IF EXISTS fact.vw_offer_analysis_hhc;

CREATE TABLE IF NOT EXISTS fact.vw_offer_analysis_hhc
(
    locationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    transactionheaderid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    recommendationid character varying(50) COLLATE pg_catalog."default" NOT NULL,
    offereditem character varying(50) COLLATE pg_catalog."default" NOT NULL,
    selecteditem character varying(50) COLLATE pg_catalog."default",
    upselltype character varying(50) COLLATE pg_catalog."default",
    upsellgroupid character varying(50) COLLATE pg_catalog."default",
    upsellgroupname text COLLATE pg_catalog."default",
    quantity integer,
    prompttimestamp text COLLATE pg_catalog."default",
    upsellprompttime timestamp without time zone,
    syscosmosts bigint,
    sysinserttime timestamp without time zone,
    offereditem_upselllevel text COLLATE pg_catalog."default",
    offered_promptitemid text COLLATE pg_catalog."default",
    offered_upsellgroupid text COLLATE pg_catalog."default",
    selecteditem_upselllevel text COLLATE pg_catalog."default",
    selected_promptitemid text COLLATE pg_catalog."default",
    selected_upsellgroupid text COLLATE pg_catalog."default",
    CONSTRAINT trxnid_recommendationid_itemid_unq UNIQUE (locationid, transactionheaderid, recommendationid, offereditem),
    CONSTRAINT locationid_trxnid_recommendationid_fkey FOREIGN KEY (locationid, transactionheaderid, recommendationid)
        REFERENCES fact.recommendations (locationid, transactionheaderid, recommendationid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS fact.vw_offer_analysis_hhc
    OWNER to citus;

*/











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
VALUES

-- Prompt 1: Item-level, no selection
(
    'ordevt-P5LOYP1V6SCAK6FP',
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992',
    'f0b71f84-8721-42d0-bf2a-e4aa31778a5e',
    '[
        {"itemId": "itm-cffb5cd5-2086-41a6-9b7f-8e2123e6aa14", "upsellGroupId": "", "upsellLevel": "Item", "promptItemId": "itm-76e6276d-73b3-4b84-b1ef-009fb8701877"},
        {"itemId": "itm-1b44e9cc-c651-45e1-8b77-c0d97bda672b", "upsellGroupId": "", "upsellLevel": "Item", "promptItemId": "itm-76e6276d-73b3-4b84-b1ef-009fb8701877"},
        {"itemId": "itm-581515ec-47a9-4abc-aea2-9db4537f87c2", "upsellGroupId": "", "upsellLevel": "Item", "promptItemId": "itm-76e6276d-73b3-4b84-b1ef-009fb8701877"},
        {"itemId": "itm-de018b7f-0ea7-4e80-8f1f-b498fc12a3bd", "upsellGroupId": "", "upsellLevel": "Item", "promptItemId": "itm-76e6276d-73b3-4b84-b1ef-009fb8701877"}
    ]'::jsonb,
    '[]'::jsonb,
    false,
    '2026-05-22T03:38:07Z',
    NOW(),
    1779421605
),

-- Prompt 2: Item-level, no selection
(
    'ordevt-P5LOYP1V6SCAK6FP',
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992',
    '951d5859-e258-4386-9d63-0f9fcfdd4f00',
    '[
        {"itemId": "itm-185e8a5b-61f3-459a-9905-dd9ebbb827dc", "upsellGroupId": "", "upsellLevel": "Item", "promptItemId": "itm-dd091cf4-727e-4da0-be99-d2b05ce4f35a"},
        {"itemId": "itm-28057ab2-675c-466a-8d16-0a24d92a548f", "upsellGroupId": "", "upsellLevel": "Item", "promptItemId": "itm-dd091cf4-727e-4da0-be99-d2b05ce4f35a"},
        {"itemId": "itm-b42f0252-840d-4a6d-bde5-aea3dc96401b", "upsellGroupId": "", "upsellLevel": "Item", "promptItemId": "itm-dd091cf4-727e-4da0-be99-d2b05ce4f35a"},
        {"itemId": "itm-76e6276d-73b3-4b84-b1ef-009fb8701877", "upsellGroupId": "", "upsellLevel": "Item", "promptItemId": "itm-dd091cf4-727e-4da0-be99-d2b05ce4f35a"}
    ]'::jsonb,
    '[]'::jsonb,
    false,
    '2026-05-22T03:39:14Z',
    NOW(),
    1779421605
),

-- Prompt 3: AI-Order level, converted (1 item selected)
(
    'ordevt-P5LOYP1V6SCAK6FP',
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992',
    'fcc06fb4-2f88-4b9c-b6b8-46fadaf99cfe',
    '[
        {"itemId": "itm-185e8a5b-61f3-459a-9905-dd9ebbb827dc", "upsellGroupId": "", "upsellLevel": "AI-Order", "promptItemId": ""},
        {"itemId": "itm-1b749dcb-f4ff-43ef-b3b5-52cff9a37583", "upsellGroupId": "", "upsellLevel": "AI-Order", "promptItemId": ""},
        {"itemId": "itm-581515ec-47a9-4abc-aea2-9db4537f87c2", "upsellGroupId": "", "upsellLevel": "AI-Order", "promptItemId": ""},
        {"itemId": "itm-c7a051df-d97e-4fed-a3b7-273c756b13bf", "upsellGroupId": "", "upsellLevel": "AI-Order", "promptItemId": ""}
    ]'::jsonb,
    '[
        {"itemId": "itm-581515ec-47a9-4abc-aea2-9db4537f87c2", "upsellGroupId": "upslg-f2846026-f2cc-4cff-9e02-87cd5c155dcc", "upsellLevel": "AI-Order", "promptItemId": "", "quantity": 1, "modifiers": []}
    ]'::jsonb,
    true,
    '2026-05-22T03:45:54Z',
    NOW(),
    1779421605
)

ON CONFLICT (transactionheaderid, recommendationid)
DO UPDATE SET
    offereditems    = EXCLUDED.offereditems,
    selecteditems   = EXCLUDED.selecteditems,
    isconverted     = EXCLUDED.isconverted,
    prompttimestamp = EXCLUDED.prompttimestamp,
    sysinserttime   = EXCLUDED.sysinserttime,
    syscosmosts     = EXCLUDED.syscosmosts;


INSERT INTO fact.vw_offer_analysis (
    locationid,
    transactionheaderid,
    recommendationid,
    offereditem,
    selecteditem,
    upselltype,
    upsellgroupid,
    upsellgroupname,
    quantity,
    prompttimestamp,
    upsellprompttime,
    syscosmosts,
    sysinserttime
)
VALUES

-- =============================================
-- Prompt 1 (f0b71f84) | Item Level | No selections
-- =============================================
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    'f0b71f84-8721-42d0-bf2a-e4aa31778a5e',
    'itm-cffb5cd5-2086-41a6-9b7f-8e2123e6aa14',  -- offereditem
    NULL,                                          -- no match in selecteditems
    'Item Level Upsells',                          -- upsellLevel = 'Item'
    '',                                            -- coalesce(selected_upslgrpid, offered_upslgrpid) = ''
    NULL,                                          -- dim.upsellgrouplookup lookup; unknown here
    NULL,                                          -- selected_quantity is NULL
    '2026-05-22T03:38:07Z',
    '2026-05-22 03:38:07'::timestamp,
    1779421605,
    NOW()
),
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    'f0b71f84-8721-42d0-bf2a-e4aa31778a5e',
    'itm-1b44e9cc-c651-45e1-8b77-c0d97bda672b',
    NULL, 'Item Level Upsells', '', NULL, NULL,
    '2026-05-22T03:38:07Z', '2026-05-22 03:38:07'::timestamp, 1779421605, NOW()
),
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    'f0b71f84-8721-42d0-bf2a-e4aa31778a5e',
    'itm-581515ec-47a9-4abc-aea2-9db4537f87c2',
    NULL, 'Item Level Upsells', '', NULL, NULL,
    '2026-05-22T03:38:07Z', '2026-05-22 03:38:07'::timestamp, 1779421605, NOW()
),
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    'f0b71f84-8721-42d0-bf2a-e4aa31778a5e',
    'itm-de018b7f-0ea7-4e80-8f1f-b498fc12a3bd',
    NULL, 'Item Level Upsells', '', NULL, NULL,
    '2026-05-22T03:38:07Z', '2026-05-22 03:38:07'::timestamp, 1779421605, NOW()
),

-- =============================================
-- Prompt 2 (951d5859) | Item Level | No selections
-- =============================================
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    '951d5859-e258-4386-9d63-0f9fcfdd4f00',
    'itm-185e8a5b-61f3-459a-9905-dd9ebbb827dc',
    NULL, 'Item Level Upsells', '', NULL, NULL,
    '2026-05-22T03:39:14Z', '2026-05-22 03:39:14'::timestamp, 1779421605, NOW()
),
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    '951d5859-e258-4386-9d63-0f9fcfdd4f00',
    'itm-28057ab2-675c-466a-8d16-0a24d92a548f',
    NULL, 'Item Level Upsells', '', NULL, NULL,
    '2026-05-22T03:39:14Z', '2026-05-22 03:39:14'::timestamp, 1779421605, NOW()
),
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    '951d5859-e258-4386-9d63-0f9fcfdd4f00',
    'itm-b42f0252-840d-4a6d-bde5-aea3dc96401b',
    NULL, 'Item Level Upsells', '', NULL, NULL,
    '2026-05-22T03:39:14Z', '2026-05-22 03:39:14'::timestamp, 1779421605, NOW()
),
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    '951d5859-e258-4386-9d63-0f9fcfdd4f00',
    'itm-76e6276d-73b3-4b84-b1ef-009fb8701877',
    NULL, 'Item Level Upsells', '', NULL, NULL,
    '2026-05-22T03:39:14Z', '2026-05-22 03:39:14'::timestamp, 1779421605, NOW()
),

-- =============================================
-- Prompt 3 (fcc06fb4) | AI-Order Level | 1 conversion
-- =============================================
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    'fcc06fb4-2f88-4b9c-b6b8-46fadaf99cfe',
    'itm-185e8a5b-61f3-459a-9905-dd9ebbb827dc',
    NULL, 'Smart Order Upsells', '', NULL, NULL,   -- offered but not selected
    '2026-05-22T03:45:54Z', '2026-05-22 03:45:54'::timestamp, 1779421605, NOW()
),
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    'fcc06fb4-2f88-4b9c-b6b8-46fadaf99cfe',
    'itm-1b749dcb-f4ff-43ef-b3b5-52cff9a37583',
    NULL, 'Smart Order Upsells', '', NULL, NULL,
    '2026-05-22T03:45:54Z', '2026-05-22 03:45:54'::timestamp, 1779421605, NOW()
),
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    'fcc06fb4-2f88-4b9c-b6b8-46fadaf99cfe',
    'itm-581515ec-47a9-4abc-aea2-9db4537f87c2',
    'itm-581515ec-47a9-4abc-aea2-9db4537f87c2',   -- ✅ offered_itemid = selected_itemid → CONVERTED
    'Smart Order Upsells',
    'upslg-f2846026-f2cc-4cff-9e02-87cd5c155dcc', -- from selecteditems.upsellGroupId
    NULL,                                          -- dim.upsellgrouplookup lookup; unknown here
    1,                                             -- quantity '1' → CASE maps to integer 1
    '2026-05-22T03:45:54Z', '2026-05-22 03:45:54'::timestamp, 1779421605, NOW()
),
(
    'loc-bc017a27-667a-4bcd-b10c-a0e21794d992', 'ordevt-P5LOYP1V6SCAK6FP',
    'fcc06fb4-2f88-4b9c-b6b8-46fadaf99cfe',
    'itm-c7a051df-d97e-4fed-a3b7-273c756b13bf',
    NULL, 'Smart Order Upsells', '', NULL, NULL,
    '2026-05-22T03:45:54Z', '2026-05-22 03:45:54'::timestamp, 1779421605, NOW()
)

ON CONFLICT (transactionheaderid, recommendationid, offereditem)
DO NOTHING; -- mirrors the SP's delta filter: existing rows are skipped

SELECT * FROM dim.upsellgrouplookup