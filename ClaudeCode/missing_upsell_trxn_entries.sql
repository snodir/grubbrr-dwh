select * from fact.transactionheader where transactionheaderid = 'ordevt-P5LOYP1V6SCAK6FP';
select * from fact.transactionitem where transactionheaderid = 'ordevt-P5LOYP1V6SCAK6FP';
select * from fact.recommendations where transactionheaderid = 'ordevt-P5LOYP1V6SCAK6FP';


--INSERT INTO fact.recommendations()
SELECT th.locationid, th.transactionheaderid, th.syscosmosts
FROM fact.transactionheader as th
WHERE th.locationid = 'loc-bc017a27-667a-4bcd-b10c-a0e21794d992' 
  AND th.transactionheaderid = 'ordevt-P5LOYP1V6SCAK6FP'



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