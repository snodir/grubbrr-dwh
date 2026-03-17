WITH params AS (
  SELECT (CURRENT_DATE - INTERVAL '1 day')::date AS report_date
),
installbase AS (
  SELECT DISTINCT ON (location_id)
    organization_name,
    location_name,
    location_id,
    location_status,
    is_loc_active,
    is_kiosk_deleted,
    is_test_kiosk
  FROM dim.vw_grubbrrinstallbase
  WHERE location_status = 'Live'
    AND is_loc_active = TRUE
    AND is_kiosk_deleted = FALSE
    AND is_test_kiosk = FALSE
    AND organization_name NOT IN (
      'NCR GRUBBRR Lab1',
      'G Toast Lab',
      'AN Test Organization',
      'CEP Events',
      'Oracle Simphony POS Gen-1(BFi)',
      'Olo Sandbox'
    )
  ORDER BY location_id
),
th_aggr AS (
  SELECT
    th.locationid,
    th.businessdate,
    COUNT(DISTINCT th.transactionheaderid) AS total_transactions,
    SUM(th.numberofitems) AS total_items,
    SUM(th.numberofpayments) AS total_payments,
    SUM(th.ordersredeemedrewards) AS total_rewards,
    SUM(th.ordersubtotal) AS total_subtotal,
    SUM(th.ordertotal) AS total_sales,
    SUM(th.ordertax) AS total_tax,
    SUM(th.ordertip) AS total_tip,
    SUM(th.orderdiscount) AS total_discount,
    SUM(th.orderbalance) AS total_balance
  FROM fact.transactionheader th
  JOIN params p
    ON th.businessdate = p.report_date
  WHERE th.transactionheaderid NOT ILIKE '%abort%'
  GROUP BY th.locationid, th.businessdate
),
ti_aggr AS (
  SELECT
    th.locationid,
    th.businessdate,
    SUM(ti.itemquantity) AS total_itemquantity,
    SUM(ti.itemunitprice * ti.itemquantity) AS total_itemprice,
    SUM(CASE WHEN LOWER(TRIM(ti.upselllevel)) = 'item' THEN 1 ELSE 0 END) AS upsell_item_count,
    SUM(CASE WHEN LOWER(TRIM(ti.upselllevel)) = 'order' THEN 1 ELSE 0 END) AS upsell_order_count,
    SUM(CASE WHEN TRIM(COALESCE(ti.upselllevel,'')) = '' THEN 1 ELSE 0 END) AS upsell_blank_count,
    SUM(CASE WHEN ti.upselllevel IS NULL THEN 1 ELSE 0 END) AS upsell_null_count
  FROM fact.transactionheader th
  JOIN fact.transactionitem ti
    ON th.transactionheaderid = ti.transactionheaderid
  JOIN params p
    ON th.businessdate = p.report_date
  WHERE th.transactionheaderid NOT ILIKE '%abort%'
  GROUP BY th.locationid, th.businessdate
)
SELECT
  gb.organization_name,
  gb.location_name,
  gb.location_id,
  p.report_date AS businessdate,
  COALESCE(th.total_transactions,0) AS total_transactions,
  COALESCE(th.total_items,0) AS total_items,
  COALESCE(th.total_payments,0) AS total_payments,
  COALESCE(th.total_rewards,0) AS total_rewards,
  COALESCE(th.total_subtotal,0) AS total_subtotal,
  COALESCE(th.total_sales,0) AS total_sales,
  COALESCE(th.total_tax,0) AS total_tax,
  COALESCE(th.total_tip,0) AS total_tip,
  COALESCE(th.total_discount,0) AS total_discount,
  COALESCE(th.total_balance,0) AS total_balance,
  COALESCE(ti.total_itemquantity,0) AS total_itemquantity,
  COALESCE(ti.total_itemprice,0) AS total_itemprice,
  COALESCE(ti.upsell_item_count,0) AS upsell_item_count,
  COALESCE(ti.upsell_order_count,0) AS upsell_order_count,
  COALESCE(ti.upsell_blank_count,0) AS upsell_blank_count,
  COALESCE(ti.upsell_null_count,0) AS upsell_null_count
FROM installbase gb
CROSS JOIN params p
LEFT JOIN th_aggr th
  ON gb.location_id = th.locationid
LEFT JOIN ti_aggr ti
  ON gb.location_id = ti.locationid
ORDER BY gb.organization_name, gb.location_name;
