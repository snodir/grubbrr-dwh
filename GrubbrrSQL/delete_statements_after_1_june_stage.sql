-- ============================================================
-- DELETE records inserted this month from all fact.* tables
-- Generated: 2026-06-16
-- Filter anchor: '2026-06-01 00:00:00+00' :: TIMESTAMP = 2026-06-01
-- ============================================================

SELECT * FROM fact.prod_to_stage_migration_audit;
SELECT '2026-06-01 00:00:00+00' :: TIMESTAMP;
SELECT '2026-06-01 00:00:00+00' :: TIMESTAMP;
-- ============================================================
-- GROUP 1: sysinserttime (23 tables)
-- ============================================================

DELETE FROM fact.gem_failed_order_job_notifications WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --542***2026-07-04=43

DELETE FROM fact.cep_incidents WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --65***2026-07-04===240

DELETE FROM fact.customer_menu_preferences WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP;--***2026-07-04=0

DELETE FROM fact.devicestate WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --1,239***2026-07-04===5,820

DELETE FROM fact.devicetelemetry WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --***2026-07-04===2

DELETE FROM fact.itemmodifier WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --58,334--***2026-07-04===56,977

DELETE FROM fact.itemssurvey WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --0***2026-07-04===0

DELETE FROM fact.location_menu_preferences WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP;--***2026-07-04=0

DELETE FROM fact.modifier_impressions WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --0***2026-07-04===162

DELETE FROM fact.modifier_interactions WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --0***2026-07-04===57,136

DELETE FROM fact.modifier_recommendations WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --0***2026-07-04===0

DELETE FROM fact.occasionsurveydetail WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --1,902***2026-07-04===14,265

DELETE FROM fact.ordertiming WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --20,616***2026-07-04===61,858

DELETE FROM fact.recommendations WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --12,686***2026-07-04=12,383

DELETE FROM fact.recommendations_bkp WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP;--***2026-07-04=0

DELETE FROM fact.sent_surveys WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP;--***2026-07-04===1

DELETE FROM fact.transactionitem WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --31,974***2026-07-04===46,477

DELETE FROM fact.transactionpayment WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --12,889***2026-07-04===13,264

DELETE FROM fact.transactionrefunds WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --8***2026-07-04===11

DELETE FROM fact.usercheckedin WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --0***2026-07-04===0

DELETE FROM fact.vw_offer_analysis WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --4,793***2026-07-04===23,435

-- ⚠️  watermarktable is an ETL control table — confirm this is intentional
-- DELETE FROM fact.watermarktable WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP;


-- ============================================================
-- GROUP 2: createddate (3 tables)
-- ============================================================

DELETE FROM fact.transactionheader WHERE createddate >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --16,436***2026-07-04===29,781

DELETE FROM fact.userbehaviour WHERE createddate >= '2026-06-30 00:00:00.000' :: TIMESTAMP; --174,803***2m:35s***2026-07-04===541,402***04m:52s

--2026-06-29 12:57:24.408227

DELETE FROM fact.deviceevent WHERE sysinserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP; --1,325,932***7m:12s***2026-07-04=4,305,544***04m:56s

DELETE FROM fact.userbehaviour_exceptions WHERE createddate >= '2026-06-01 00:00:00+00' :: TIMESTAMP;--***2026-07-04=


-- ============================================================
-- GROUP 3: Non-standard timestamp column (3 tables)
-- ============================================================

-- fact.devicehealth uses "inserttime" (not sysinserttime)
DELETE FROM fact.devicehealth WHERE inserttime >= '2026-06-01 00:00:00+00' :: TIMESTAMP;

-- fact.pos_sales_details uses "created_on" (not sysinserttime)
DELETE FROM fact.pos_sales_details WHERE created_on >= '2026-06-01 00:00:00+00' :: TIMESTAMP;

-- fact.pipelinerunstatus uses "pipelinetriggertime" as the closest proxy for insert time
DELETE FROM fact.pipelinerunstatus WHERE pipelinetriggertime >= '2026-06-01 00:00:00+00' :: TIMESTAMP;


-- ============================================================
-- GROUP 4: No suitable insert-time column — SKIPPED (3 tables)
-- ============================================================
-- These tables have no column that reliably tracks row insertion time.
-- Handle manually if needed.
--
-- fact.peripheralhealth   → no timestamp column at all
-- fact.peripheralstate    → only statestart / stateend (state period bounds, not insert time)
-- fact.timingsdatalake    → only timing_value (pipeline timing marker, not insert time)
-- fact.location_statistics → only sysupdatetime; skipped because it reflects the last
--                            UPDATE time, not INSERT time, so it could hit rows inserted
--                            in prior months that were refreshed this month.