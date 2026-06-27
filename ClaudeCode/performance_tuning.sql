SELECT * FROM pg_stat_activity;

-- Raw table size (no indexes, no TOAST)
SELECT pg_relation_size('your_table');

-- Table size including TOAST but excluding indexes
SELECT pg_table_size('your_table');

-- Index size only
SELECT pg_indexes_size('your_table');

-- Total size (table + indexes + TOAST)
SELECT pg_total_relation_size('your_table');

-- ============================================================
-- Performance Tuning: Recommended Indexes
-- Generated: 2026-06-02
-- Scope: dim, fact, ml, stg schemas
--
-- Notes:
--   • All indexes use IF NOT EXISTS — safe to re-run.
--   • In production add CONCURRENTLY to avoid locking:
--       CREATE INDEX CONCURRENTLY IF NOT EXISTS ...
--   • Citus: indexes on distributed tables must include the
--     distribution column, or be created per-shard. Review
--     each suggestion against your distribution key before applying.
--   • Run ANALYZE <table> after creating indexes on large tables
--     so the planner picks them up immediately.
-- ============================================================


-- ============================================================
-- stg.silver_kiosk_events
-- Most heavily queried staging table: every watermark-based SP
-- reads it. Three distinct access patterns drive these indexes.
-- ============================================================

-- syscosmosts is the universal watermark filter (> v_watermark).
-- Without this, every SP does a full scan on the largest stg table.
CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_syscosmosts
    ON stg.silver_kiosk_events (syscosmosts);

-- usp_gem_ordertiming and usp_gem_usercheckedin filter on
-- eventmodule + application + (eventcategory, eventtype) combinations.
-- Composite covers the most selective leading columns first.
CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_module_app_cat_type
    ON stg.silver_kiosk_events (eventmodule, application, eventcategory, eventtype);

-- token / ordersessionid is the grouping key in ordertiming and
-- the dedup key in sent_surveys. Frequent equality and > '' filters.
CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_token
    ON stg.silver_kiosk_events (token)
    WHERE token IS NOT NULL AND token > '';

-- locationid appears in EXISTS sub-selects and joins to dim.location.
CREATE INDEX IF NOT EXISTS ix_silver_kiosk_events_locationid
    ON stg.silver_kiosk_events (locationid);


-- ============================================================
-- fact.transactionheader
-- The central fact table — joined or filtered in almost every SP.
-- ============================================================

-- Most SPs filter on orderstatus = 'order-placed'.
-- Partial index keeps it small and tight.
CREATE INDEX IF NOT EXISTS ix_transactionheader_status_placed
    ON fact.transactionheader (locationid, businessdate)
    WHERE orderstatus = 'order-placed';

-- businessdate range filters appear in all incremental SPs
-- (ml.transactions, upsell_analysis, etc.).
CREATE INDEX IF NOT EXISTS ix_transactionheader_businessdate
    ON fact.transactionheader (businessdate);

-- transactionheaderid is the join key for transactionitem,
-- itemmodifier, recommendations, surveys, and more.
CREATE INDEX IF NOT EXISTS ix_transactionheader_transactionheaderid
    ON fact.transactionheader (transactionheaderid);

-- frequentcustomerid used in customer_menu_preferences and
-- usp_customer_menu_preferences joins.
CREATE INDEX IF NOT EXISTS ix_transactionheader_frequentcustomerid
    ON fact.transactionheader (frequentcustomerid)
    WHERE frequentcustomerid IS NOT NULL;


-- ============================================================
-- fact.transactionitem
-- Joined to transactionheader on every order-level SP.
-- ============================================================

-- Primary join path: (transactionheaderid) to expand header → items.
CREATE INDEX IF NOT EXISTS ix_transactionitem_transactionheaderid
    ON fact.transactionitem (transactionheaderid);

-- (locationid, transactionheaderid) used in modifier interaction
-- enrichment joins and location-scoped item aggregations.
CREATE INDEX IF NOT EXISTS ix_transactionitem_locationid_thid
    ON fact.transactionitem (locationid, transactionheaderid);

-- dimmenuitemid used in item popularity stats and menu preference SPsl.
CREATE INDEX IF NOT EXISTS ix_transactionitem_dimmenuitemid
    ON fact.transactionitem (dimmenuitemid)
    WHERE dimmenuitemid IS NOT NULL;

-- businessdate range filter used in incremental ml SPs.
CREATE INDEX IF NOT EXISTS ix_transactionitem_businessdate
    ON fact.transactionitem (businessdate);

-- transactionheaderid LIKE 'ordevt-%' filter in usp_location_statistics
-- and usp_master_keys_for_duplicate_items.  text_pattern_ops enables
-- prefix LIKE without a full scan.
CREATE INDEX IF NOT EXISTS ix_transactionitem_thid_pattern
    ON fact.transactionitem (transactionheaderid text_pattern_ops);


-- ============================================================
-- fact.itemmodifier
-- Joined in modifier interaction analysis and ml.modifier_interactions.
-- ============================================================

-- Primary join: (transactionheaderid, itemid) from modifier interaction SPs.
CREATE INDEX IF NOT EXISTS ix_itemmodifier_thid_itemid
    ON fact.itemmodifier (transactionheaderid, itemid);

-- locationid-based watermark filter in usp_modifier_interaction_analysis.
CREATE INDEX IF NOT EXISTS ix_itemmodifier_locationid_syscosmosts
    ON fact.itemmodifier (locationid, syscosmosts);

-- (modifiergroupid, modifierid) join to dim.modifier_group_mapping.
CREATE INDEX IF NOT EXISTS ix_itemmodifier_modgrp_modifier
    ON fact.itemmodifier (modifiergroupid, modifierid);


-- ============================================================
-- fact.modifier_recommendations
-- Source table for both modifier impression and interaction SPs.
-- ============================================================

-- Watermark + NOT EXISTS dedup filter is the most common access pattern.
CREATE INDEX IF NOT EXISTS ix_modifier_recommendations_syscosmosts
    ON fact.modifier_recommendations (syscosmosts);

-- (locationid, transactionheaderid) used in the NOT EXISTS sub-selects
-- that prevent double-loading impressions and interactions.
CREATE INDEX IF NOT EXISTS ix_modifier_recommendations_loc_thid
    ON fact.modifier_recommendations (locationid, transactionheaderid);

-- businessdate for incremental ml SP range scans.
CREATE INDEX IF NOT EXISTS ix_modifier_recommendations_businessdate
    ON fact.modifier_recommendations (businessdate);


-- ============================================================
-- fact.modifier_impressions
-- Written by impression analysis SPs; also read by ml.usp_refresh_modifier_impressions.
-- ============================================================

-- Incremental delete/insert anchored on MAX(businessdate).
CREATE INDEX IF NOT EXISTS ix_fact_modifier_impressions_businessdate
    ON fact.modifier_impressions (businessdate);

-- NOT EXISTS sub-select dedup key.
CREATE INDEX IF NOT EXISTS ix_fact_modifier_impressions_loc_thid
    ON fact.modifier_impressions (locationid, transactionheaderid);


-- ============================================================
-- fact.modifier_interactions
-- Same dual-access pattern as modifier_impressions.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_fact_modifier_interactions_businessdate
    ON fact.modifier_interactions (businessdate);

CREATE INDEX IF NOT EXISTS ix_fact_modifier_interactions_loc_thid
    ON fact.modifier_interactions (locationid, transactionheaderid);

-- sourceid filter used in watermark updates (WHERE sourceid = 5 / 6).
CREATE INDEX IF NOT EXISTS ix_fact_modifier_interactions_sourceid
    ON fact.modifier_interactions (sourceid);


-- ============================================================
-- fact.recommendations
-- Read by usp_offer_analysis and usp_item_recommendations_stage_to_fact.
-- ============================================================

-- Watermark filter.
CREATE INDEX IF NOT EXISTS ix_recommendations_syscosmosts
    ON fact.recommendations (syscosmosts);

-- NOT EXISTS dedup: (locationid, transactionheaderid).
CREATE INDEX IF NOT EXISTS ix_recommendations_loc_thid
    ON fact.recommendations (locationid, transactionheaderid);


-- ============================================================
-- fact.vw_offer_analysis
-- Read by ml.usp_refresh_upsell_analysis; NOT EXISTS dedup key.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_vw_offer_analysis_loc_thid
    ON fact.vw_offer_analysis (locationid, transactionheaderid);


-- ============================================================
-- fact.watermarktable
-- Read at the start of every incremental SP (one row per pipeline).
-- Already small but hit repeatedly; a covering index avoids heap fetches.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_watermarktable_name_source
    ON fact.watermarktable (watermarktablename, source);


-- ============================================================
-- fact.devicestate
-- NOT EXISTS sub-select in usp_gsh_devicehealth uses
-- (deviceid, locationid, lasteventtime).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_devicestate_device_loc_eventtime
    ON fact.devicestate (deviceid, locationid, lasteventtime);


-- ============================================================
-- fact.sent_surveys
-- NOT EXISTS dedup on (locationid, ordersessionid).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_sent_surveys_loc_session
    ON fact.sent_surveys (locationid, ordersessionid);


-- ============================================================
-- fact.itemssurvey
-- usp_nge_update_itemssurvey filters on (locationid, orderid,
-- surveyid, itemid) AND sysupdatetime IS NULL.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_itemssurvey_loc_order_survey_item
    ON fact.itemssurvey (locationid, orderid, surveyid, itemid)
    WHERE sysupdatetime IS NULL;


-- ============================================================
-- fact.usercheckedin
-- Post-insert UPDATE sets orderdatelocal WHERE IS NULL,
-- then another UPDATE sets dateid WHERE IS NULL.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_usercheckedin_orderdatelocal_null
    ON fact.usercheckedin (locationid)
    WHERE orderdatelocal IS NULL;

CREATE INDEX IF NOT EXISTS ix_usercheckedin_dateid_null
    ON fact.usercheckedin (locationid)
    WHERE dateid IS NULL;


-- ============================================================
-- dim.organizationlocation
-- Every SP that needs org context filters on organizationtype = 0.
-- A partial index on this constant predicate is highly efficient.
-- ============================================================

-- Used in joins: locationid → org context.
CREATE INDEX IF NOT EXISTS ix_organizationlocation_locationid_type0
    ON dim.organizationlocation (locationid)
    WHERE organizationtype = 0;

-- Used in joins: organizationid → location list.
CREATE INDEX IF NOT EXISTS ix_organizationlocation_organizationid_type0
    ON dim.organizationlocation (organizationid)
    WHERE organizationtype = 0;


-- ============================================================
-- dim.catalog
-- Joined on catalogid (lookup) and on (organizationid, gem_location_id)
-- in usp_refresh_modifier_impressions / interactions / ml SPs.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_catalog_catalogid
    ON dim.catalog (catalogid);

CREATE INDEX IF NOT EXISTS ix_catalog_org_gemloc
    ON dim.catalog (organizationid, gem_location_id);


-- ============================================================
-- dim.menuitem
-- Joined on menuitemid in virtually every transaction SP.
-- Also joined on (catalogid, menuitemid) in modifier impression SPs.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_menuitem_menuitemid
    ON dim.menuitem (menuitemid);

CREATE INDEX IF NOT EXISTS ix_menuitem_catalogid_menuitemid
    ON dim.menuitem (catalogid, menuitemid);


-- ============================================================
-- dim.modifier
-- Joined on (catalogid) then modifierid in ml modifier SPs.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_modifier_catalogid_modifierid
    ON dim.modifier (catalogid, modifierid);


-- ============================================================
-- dim.modifier_group
-- Joined on modifiergroupid in interaction classification logic.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_modifier_group_modifiergroupid
    ON dim.modifier_group (modifiergroupid);


-- ============================================================
-- dim.modifier_group_mapping
-- Joined on (modifiergroupid, modifierid) for selection_type /
-- action classification in usp_modifier_interaction_analysis.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_modifier_group_mapping_grp_modifier
    ON dim.modifier_group_mapping (modifiergroupid, modifierid);


-- ============================================================
-- dim.item_modifier_group_modifier_mapping
-- Joined on (catalogid, modifierid) in ml.usp_refresh_modifier_impressions.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_imgm_catalogid_modifierid
    ON dim.item_modifier_group_modifier_mapping (catalogid, modifierid);

-- Also joined on (catalogid, menuitemid) in ml.usp_refresh_item_modifiergroup_modifier_mapping.
CREATE INDEX IF NOT EXISTS ix_imgm_catalogid_menuitemid
    ON dim.item_modifier_group_modifier_mapping (catalogid, menuitemid);


-- ============================================================
-- dim.category_hierarchy
-- Joined on menuitemid in ml.usp_refresh_menu_entities.
-- Natural key (locationid, categoryid, menuitemid) drives the
-- upsert NOT EXISTS in usp_refresh_category_hierarchy.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_category_hierarchy_menuitemid
    ON dim.category_hierarchy (menuitemid);

CREATE INDEX IF NOT EXISTS ix_category_hierarchy_loc_cat_item
    ON dim.category_hierarchy (locationid, categoryid, menuitemid);


-- ============================================================
-- dim.itemcategory
-- Joined on (id) in ml.usp_refresh_transactions (LEFT JOIN on ti.categoryid).
-- Upsert NOT EXISTS uses (locationid, categoryid).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_itemcategory_locationid_categoryid
    ON dim.itemcategory (locationid, categoryid);


-- ============================================================
-- dim.kiosk
-- Joined on (locationid, kioskid) in usp_grubbrr_install_base
-- and usp_gsh_devicehealth (live_locations CTE).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_kiosk_locationid_kioskid
    ON dim.kiosk (locationid, kioskid);

-- Filtered on istestkiosk = false in device health / telemetry SPs.
CREATE INDEX IF NOT EXISTS ix_kiosk_locationid_nottest
    ON dim.kiosk (locationid)
    WHERE istestkiosk = false;


-- ============================================================
-- dim.frequentcustomer
-- Joined on frequentcustomerid in preference SPs.
-- Joined on organizationid in location_statistics.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_frequentcustomer_frequentcustomerid
    ON dim.frequentcustomer (frequentcustomerid);

CREATE INDEX IF NOT EXISTS ix_frequentcustomer_organizationid
    ON dim.frequentcustomer (organizationid);


-- ============================================================
-- dim.organization
-- Joined on id; filtered on (status = 2, active = true) in
-- device health and telemetry live_locations CTEs.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_organization_id
    ON dim.organization (id);

-- Partial index for the live-location filter used in device SPs.
CREATE INDEX IF NOT EXISTS ix_organization_live
    ON dim.organization (id)
    WHERE status = 2 AND active = true;


-- ============================================================
-- dim.element
-- usp_refresh_element NOT EXISTS check on (sourceelementid, elementname).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_element_sourceelementid_name
    ON dim.element (sourceelementid, elementname);


-- ============================================================
-- ml.transactions
-- Incremental delete/insert anchored on MAX(businessdate).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_ml_transactions_businessdate
    ON ml.transactions (businessdate);


-- ============================================================
-- ml.modifier_impressions
-- Incremental delete/insert anchored on MAX(businessdate).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_ml_modifier_impressions_businessdate
    ON ml.modifier_impressions (businessdate);


-- ============================================================
-- ml.modifier_interactions
-- Incremental delete/insert anchored on MAX(businessdate).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_ml_modifier_interactions_businessdate
    ON ml.modifier_interactions (businessdate);


-- ============================================================
-- ml.upsell_analysis
-- Incremental delete/insert anchored on MAX(businessdate).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_ml_upsell_analysis_businessdate
    ON ml.upsell_analysis (businessdate);


-- ============================================================
-- ml.weather
-- Incremental delete/insert anchored on MAX(weatherdate).
-- Joined to fact.transactionheader on (locationid, weatherdate, hh).
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_ml_weather_locationid_date_hh
    ON ml.weather (locationid, weatherdate, hh);


-- ============================================================
-- stg staging tables — DISTINCT ON dedup patterns
-- Each SPs creates a temp table using DISTINCT ON (key cols)
-- ORDER BY key cols, <timestamp> DESC.  Indexes on the staging
-- tables speed up the ORDER BY sort that drives DISTINCT ON.
-- ============================================================

-- stg.dim_frequentcustomer: DISTINCT ON (frequentcustomerid) ORDER BY sysinserttime DESC
CREATE INDEX IF NOT EXISTS ix_stg_frequentcustomer_id_sysinsert
    ON stg.dim_frequentcustomer (frequentcustomerid, sysinserttime DESC);

-- stg.dim_catalog: DISTINCT ON (catalogid) ORDER BY catalog_modified_on DESC
CREATE INDEX IF NOT EXISTS ix_stg_catalog_id_modifiedon
    ON stg.dim_catalog (catalogid, catalog_modified_on DESC NULLS LAST);

-- stg.dim_itemcategory: DISTINCT ON (locationid, categoryid) ORDER BY category_modified_on DESC
CREATE INDEX IF NOT EXISTS ix_stg_itemcategory_loc_cat_modified
    ON stg.dim_itemcategory (locationid, categoryid, category_modified_on DESC NULLS LAST);

-- stg.dim_kiosk: DISTINCT ON (locationid, kioskid) ORDER BY devicecreatedon DESC
CREATE INDEX IF NOT EXISTS ix_stg_kiosk_loc_kioskid_created
    ON stg.dim_kiosk (locationid, kioskid, devicecreatedon DESC NULLS LAST);

-- stg.dim_kiosk_config: DISTINCT ON (locationid) ORDER BY syscosmosts DESC
CREATE INDEX IF NOT EXISTS ix_stg_kiosk_config_loc_syscosmosts
    ON stg.dim_kiosk_config (locationid, syscosmosts DESC);

-- stg.dim_kiosk_appearance: DISTINCT ON (locationid) ORDER BY syscosmosts DESC
CREATE INDEX IF NOT EXISTS ix_stg_kiosk_appearance_loc_syscosmosts
    ON stg.dim_kiosk_appearance (locationid, syscosmosts DESC);

-- stg.dim_category_hierarchy: DISTINCT ON (locationid, categoryid, menuitemid)
--   ORDER BY mapping_modified_on DESC
CREATE INDEX IF NOT EXISTS ix_stg_category_hierarchy_key_modified
    ON stg.dim_category_hierarchy (locationid, categoryid, menuitemid, mapping_modified_on DESC NULLS LAST);

-- stg.dim_pos_provider / dim_loyalty_configuration / dim_payment_provider:
--   DISTINCT ON (locationid, provider) ORDER BY syscosmosts DESC
CREATE INDEX IF NOT EXISTS ix_stg_pos_provider_loc_syscosmosts
    ON stg.dim_pos_provider (locationid, syscosmosts DESC);

CREATE INDEX IF NOT EXISTS ix_stg_loyalty_config_loc_syscosmosts
    ON stg.dim_loyalty_configuration (locationid, syscosmosts DESC);

CREATE INDEX IF NOT EXISTS ix_stg_payment_provider_loc_syscosmosts
    ON stg.dim_payment_provider (locationid, syscosmosts DESC);

-- stg.fact_devicestate: watermark filter healthdatatime > v_watermark
-- and join on (locationid, deviceid).
CREATE INDEX IF NOT EXISTS ix_stg_fact_devicestate_loc_device_time
    ON stg.fact_devicestate (locationid, deviceid, healthdatatime);


-- ============================================================
-- etl.bronze_partition_registry
-- Queried by status and entity for pipeline orchestration.
-- ============================================================

CREATE INDEX IF NOT EXISTS ix_bronze_registry_entity_status
    ON etl.bronze_partition_registry (entity, status);

CREATE INDEX IF NOT EXISTS ix_bronze_registry_partition_date
    ON etl.bronze_partition_registry (partition_date);
