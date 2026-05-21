	WITH params AS (
	
	    SELECT 
	        '2026-04-01'::TIMESTAMP AS from_date,
	        '2026-04-30'::TIMESTAMP AS to_date
	),
	
	base_locations AS (
	
	    SELECT
	        locationid,
	        MAX(organizationid) AS organization_id,
	        MAX(organizationname) AS organization_name,
	        MAX(locationname) AS location_name
	
	    FROM ml.modifier_interactions
	
	    GROUP BY locationid
	),
	
	th_agg AS (
	
	    SELECT
	        th.locationid,
	
	        COUNT(DISTINCT th.transactionheaderid) AS total_transactions,
	
	       SUM(th.ordersubtotal) AS total_gross_sales
	
	    FROM fact.transactionheader th
	    CROSS JOIN params p
	
	    WHERE th.businessdate BETWEEN p.from_date AND p.to_date
	      AND th.orderstatus = 'order-placed'
	      AND th.transactionheaderid NOT ILIKE 'abort%'
	
	    GROUP BY th.locationid
	),
	
	ti_agg AS (
	
	    SELECT
	        th.locationid,
	
	        SUM(ti.itemquantity * ti.itemunitprice) AS upsell_total
	
	    FROM fact.transactionheader th
	
	    INNER JOIN fact.transactionitem ti
	        ON th.transactionheaderid = ti.transactionheaderid
	
	    CROSS JOIN params p
	
	    WHERE th.businessdate BETWEEN p.from_date AND p.to_date
	      AND th.orderstatus = 'order-placed'
	      AND ti.upselllevel IS NOT NULL
	      AND th.transactionheaderid NOT ILIKE '%abort%'
	
	    GROUP BY th.locationid
	),
	
	pm_agg AS (
	
	    SELECT
	        pm.locationid,
	
	        SUM(pm.modifierquantity * pm.modifierprice)
	            AS premium_modifier_total
	
	    FROM ml.modifier_interactions pm
	    CROSS JOIN params p
	
	    WHERE pm.businessdate BETWEEN p.from_date AND p.to_date
	      AND pm.modifierprice > 0
	
	    GROUP BY pm.locationid
	)
	
	SELECT
	
	    bl.organization_id,
	    bl.organization_name,
	    bl.locationid AS location_id,
	    bl.location_name,
	
	    COALESCE(th.total_transactions, 0) AS total_transactions,
	
	   COALESCE(th.total_gross_sales, 0) AS gross_sales,
	
	    COALESCE(ti.upsell_total, 0) AS upsell_total,
	
	    COALESCE(pm.premium_modifier_total, 0)
	        AS premium_modifier_total,
	
	    COALESCE(ti.upsell_total, 0)
	    +
	    COALESCE(pm.premium_modifier_total, 0)
	        AS total_upsell_plus_premium
	
	FROM base_locations bl
	
	LEFT JOIN th_agg th
	    ON bl.locationid = th.locationid
	
	LEFT JOIN ti_agg ti
	    ON bl.locationid = ti.locationid
	
	LEFT JOIN pm_agg pm
	    ON bl.locationid = pm.locationid
	
	ORDER BY
	    bl.organization_name,
	    bl.location_name;