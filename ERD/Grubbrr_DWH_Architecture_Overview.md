# Grubbrr Data Warehouse — Architecture Overview

*Owner: Nate | Last updated: July 2026*

## 1. Purpose & Scope

This page documents the architecture of `gas_db`, Grubbrr's analytics data warehouse: how data flows from operational Cosmos DB sources into a queryable PostgreSQL warehouse, the storage layers involved, the orchestration layer (Azure Data Factory), and the conventions the codebase follows. It's meant as a reference for engineers working on ETL pipelines, dimensional modeling, or ML feature pipelines against this warehouse.

---

## 2. High-Level Architecture

The warehouse follows a **medallion (Bronze / Silver / Gold)** pattern:

```
Cosmos DB (operational)  →  Message Bus  →  ADLS Gen2 Bronze (raw JSON)
        →  ADF Copy Activity  →  PostgreSQL Silver staging (stg schema)
        →  Stored procedure distribution  →  PostgreSQL Gold (fact / dim schemas)
```

**Why this shape:**
- Reading directly from Cosmos DB for ETL would compete with production RU budget, so a Message Bus decouples operational writes from analytics ingestion.
- ADLS Gen2 Bronze gives a durable, replayable raw layer partitioned by time.
- Silver staging lives natively in PostgreSQL (not as ADLS Parquet) — ADF Data Flows could not preserve deeply nested JSON structures (e.g. `upsellInformation.modifierImpressions`), so Copy Activity + stored procedures replaced Data Flow transforms for these entities.
- Gold (`fact`/`dim`) tables are what BI, ML, and reporting consume.

---

## 3. Storage Layers

### 3.1 Bronze (ADLS Gen2)
- Path convention: `bronze/{orders|events}/raw/yyyy/mm/dd/hh/*.json`
- Raw, append-only JSON exactly as received from the Message Bus.
- Watermarking and idempotency tracked in `etl.bronze_partition_registry` (columns: `dateid`, `layer`, `entity`, `partition_path`, `partition_date/year/month/day/hour`, `status`, `file_count`, `started_at`, …) — this is what lets partitions be safely re-processed without duplication.
- **Known bottleneck:** hour-folders can contain 50K–250K small JSON files. ADF Copy Activity throughput plateaus around 130–150 files/sec regardless of DIU settings once file counts get this high. An Azure Function is being built to compact these into fewer, larger NDJSON files (byte-level concatenation, async Python) before Copy Activity reads them. Hosting plan (Consumption vs. Premium) is still an open decision.

### 3.2 Silver (PostgreSQL `stg` schema — 45 tables)
- Intake tables receive data via ADF Copy Activity directly from Bronze JSON (column names are case-sensitive, double-quoted, and mirror the Cosmos JSON field names exactly, e.g. `"locationId"`, `"orderId"`, `"kioskSessionId"` — this mapping must never be snake_cased in ADF sink configs).
- A **fan-out pattern** distributes single intake tables into multiple entity-specific silver tables via master stored procedures:
  - `fact.usp_distribute_silver_transaction_entities(p_partition_path)` → fans `stg.silver_all_transaction_entities` into `stg.silver_transaction_header`, `silver_transaction_item`, `silver_transaction_payment`, `silver_transaction_refunds`, `silver_transaction_combo_items`, `silver_upsell_recommendations`, `silver_modifier_impressions`, `silver_modifier_interactions`, `silver_item_modifiers`, and more (9+ entity tables from one intake table).
  - `fact.usp_distribute_silver_gem_events(p_partition_path)` → same pattern for GEM device/kiosk event telemetry into `stg.silver_all_gem_events` → `silver_kiosk_events`, etc.
- **Partition-scoped idempotency:** every staging/silver target table carries a `bronze_folderpath` column. Re-runs use `DELETE WHERE bronze_folderpath = p_partition_path` rather than `TRUNCATE`, so partitions can be safely retried in parallel without wiping unrelated data.
- **Exception — sliding window table:** `stg.silver_kiosk_events` uses a 15-minute sliding `DELETE` window instead of partition-path deletes, because 8+ downstream stored procedures join it on `ordersessionid = token` across hour boundaries, and a strict partition-path delete would break those cross-boundary joins.

### 3.3 Gold (PostgreSQL `fact`, `dim`, `ml` schemas)
- **`dim` schema — 41 tables.** Dimensions (organization, location, kiosk, menuitem, modifier, catalog, category_hierarchy, frequentcustomer, weather, occasionsurvey, ordertype, etc.), refreshed via a consistent `dim.usp_refresh_*` family (20 procedures) using a temp-table + index + `ANALYZE` + separate `INSERT`/`UPDATE` pattern.
- **`fact` schema — 33 tables.** Transactional and event facts (transactionheader/item/payment/refunds, deviceevent, userbehaviour, devicestate, devicetelemetry, ordertiming, occasionsurveydetail, itemssurvey, modifier_impressions/interactions/recommendations, usercheckedin, cep_incidents, location_statistics, etc.), loaded via 36 `fact.usp_*` stored procedures.
- **`ml` schema — 8 tables.** Denormalized feature tables for Smart Upsell / Smart Menus models (`menu_entities`, `item_modifiergroup_modifier_mapping`, `modifier_impressions`, `modifier_interactions`, `modifier_item_match`, `transactions`, `upsell_analysis`, `weather`), refreshed by 8 `ml.usp_refresh_*` procedures.
- **`etl` schema.** Operational metadata — currently `etl.bronze_partition_registry`.

---

## 4. Orchestration (Azure Data Factory)

Factory: `df-gas-test-eastus`. Inventory: **67 pipelines, 80 data flows, 198 datasets, 15 linked services, 4 triggers.**

### 4.1 Linked Services
| Name | Type | Purpose |
|---|---|---|
| ADLSgas, StgADLSgas, ADLSsus | AzureBlobFS | ADLS Gen2 Bronze/staging storage |
| CosmosGXS, CosmosNGE, CosmosNGEGrubbrrLoyalty, CosmosPOS, EventsCosmosNew, OrdersCosmosNew | CosmosDb | Operational source systems (orders, events, loyalty, POS) |
| OrdersPGNew, PostgresGMS, PostgresGOU, ServicesPGNew | AzurePostgreSql | `gas_db` (Citus) and related Postgres services |
| LoadKiosksFromCosmosDbToAnalyticsDb | AzureFunction | Kiosk data load function |
| kyv_grubbrr_dev | AzureKeyVault | Secrets |

### 4.2 Scheduled Triggers → Master Pipelines
| Trigger | Pipeline | Purpose |
|---|---|---|
| GASOrders | `DimensionsFactsMaster` | Primary dimension + fact refresh cycle |
| GEMEvents | `GEM_GSH_GOU_Master` | Device/kiosk event pipeline (GEM/GSH/GOU sources) |
| RefreshMLTables | `RefreshMLTables` | ML feature table refresh |
| TwiceDaily | `GrubbrrInstallBaseDashboard` | Install-base reporting refresh |

### 4.3 Key Pipeline Groups
- **Bronze ingestion:** `IngestToBronze`, `BronzeOrdersToGAS`, `BronzeEventsToGAS`, `BronzeOrdersToSilverAndGAS`, `BronzeEventsToSilverAndGAS`, `BronzeSilverGASMaster` — Copy Activity + `ForEach` fan-out from Bronze into staging, orchestrated per partition.
- **Silver → Gold distribution:** `SilverOrdersToGAS`, `SilverEventsToGAS`, `gasTransactionsToAnalyticsDb`, `gxsTransactionsToAnalyticsDb` — call the `usp_distribute_silver_*` and `usp_silver_*_to_fact` stored procedures.
- **Dimension refresh:** `DimensionMaster` → fans out to `DimensionKiosks`, `DimensionMenuItems`, `DimensionMenuModifiers`, `DimensionOrganizationLocationCatalog`, `DimensionFrequentCustomer`, `DimensionABTests`, `DimensionWeatherInfo`, `DimensionMasterItemsAndModifiers`, `DimensionUpdateOrdersToAnalyticsDb`.
- **Fact refresh:** `FactsMaster` → fans out to device/telemetry, transaction, and survey fact pipelines (`gshDeviceHealthToAnalyticsDbFactDeviceState`, `gshDeviceTelemetryToAnalyticsDb`, `OccasionSurveyOrdersFeedback`, `TransactionPaymentRefunds`, `gemOrderTimingtoAnalyticsDb`, `gemUserCheckedInToPG`, etc.).
- **Upsell / recommendations:** `UpsellRecommendationsToGAS`, `ModifierUpsellRecommendationsToGAS`.
- **ML feature pipelines:** `RefreshMLTables`, `TrainingDataForML` (and `V2`/`Compressed`/`FastPartition`/`Separate` variants), `ChildPipTrainingDataML`.
- **Housekeeping:** `UpdateDateTimeFields`, `UpdateFieldsInTrxnFactTables`, `AbortedOrdersAndItemsToPG`, `ADFEventLoggingTemplate` (shared logging template called via `WebActivity`).

---

## 5. Incremental Load / Watermarking Framework

- **`fact.watermarktable`** — columns `watermarktablename`, `watermarkcolumn`, `watermarkvalue`, `ticks`, `ts`, `source`, `sysinserttime`, `sysupdatetime`. One row per source/table combination (e.g. `source = 'nge'`).
- **Read pattern:** stored procedures read using `COALESCE(ts, seed) - 10` to build a small overlap buffer, avoiding boundary-skipped rows.
- **Write pattern:** `fact.updatewatermark(tablename)` updates `watermarkvalue` to `MAX(...)` of the relevant timestamp column after a successful load.
- **Deduplication convention:** `DISTINCT ON (...) ... ORDER BY syscosmosts DESC NULLS LAST` is the standard idiom used across silver-to-fact procedures for keeping the latest version of a row per natural key.
- **Known pitfall (fixed):** an earlier bug had `AND syscosmosts > v_max_syscosmosts` filters in several stored procedures, which silently skipped rows because `syscosmosts` ordering doesn't reliably align with hour-folder boundaries. Fix: remove the redundant filter; rely on `ON CONFLICT` for idempotent re-processing instead.
- **`ON CONFLICT DO UPDATE` guards:** all fact upserts use `IS DISTINCT FROM` / `COALESCE` guards and `WHERE` predicates to suppress no-op writes (e.g. GEM event timing fields — `itemselectedtime`, `addtocarttime`, etc. — in `fact.usp_silver_transaction_item_to_fact`).

---

## 6. Stored Procedure Inventory

| Schema | Procedures | Examples |
|---|---|---|
| `dim` | 20 | `usp_refresh_organization`, `usp_refresh_location_kiosk_details`, `usp_refresh_menuitem`, `usp_refresh_modifiergroup_modifier_mapping`, `usp_grubbrr_install_base` |
| `fact` | 36 | `usp_distribute_silver_transaction_entities`, `usp_distribute_silver_gem_events`, `usp_silver_transaction_item_to_fact`, `usp_gsh_devicehealth_to_fact_devicestate`, `usp_offer_analysis`, `usp_location_statistics` |
| `ml` | 8 | `usp_refresh_menu_entities`, `usp_refresh_item_modifier_matching`, `usp_refresh_upsell_analysis`, `usp_refresh_transactions` |
| Helpers | — | `fact.fn_getdata(aty, dc, modid, appli)` (event duration lookups), `fact.updatewatermark(tablename)` |

**Standard `dim.usp_refresh_*` pattern:** build into a temp table → index it → `ANALYZE` → separate `INSERT` for new rows and `UPDATE` for changed rows (rather than a blanket upsert), which keeps large dimension refreshes fast and lock-light on Citus.

---

## 7. Fuzzy Matching / ML Support Infrastructure

Built to support Smart Upsell and Smart Menus models:
- Ported `rapidfuzz.fuzz.token_sort_ratio` from Python into native PostgreSQL functions: `dim.ml_normalize`, `dim.token_sort`, `dim.token_sort_ratio`, `dim.tsr_presorted`.
- `ml.usp_run_item_modifier_matching` sources directly from already-denormalized `ml.item_modifiergroup_modifier_mapping` and `ml.menu_entities`, avoiding redundant joins against raw dimension tables.
- Grain correction applied: primary key on the mapping table is `(organizationid, locationid, modifierid)`, not just `(organizationid, modifierid)` — the earlier grain silently collapsed rows across locations.

---

## 8. Indexing Conventions

Index inventory: 32 (`dim`), 37 (`fact`), 16 (`ml`), 16 (`stg`) — **101 indexes total**, 14 of which are BRIN.

- **BRIN indexes** on `syscosmosts` (and similar monotonic watermark columns) with `pages_per_range = 128` are the standard choice for large, append-mostly fact tables — e.g. `ix_deviceevent_syscosmosts_brin`, `ix_transactionheader_syscosmosts_brin`, `ix_userbehaviour_syscosmosts_brin`, `ix_silver_kiosk_events_syscosmosts_brin`. BRIN is preferred over B-tree here because these columns are large, monotonically-ish increasing, and scanned in ranges rather than point-looked-up.
- **Schema audit findings (open items):**
  - Zero index coverage on `syscosmosts` watermark columns across ~35 tables — BRIN recommended as the fix.
  - Missing indexes on several modifier fact tables.
  - Roughly 10 fact tables have no primary key at all.
  - `fact.ordertiming` was found missing a unique constraint that its own `ON CONFLICT` clause depends on — a live bug, not just a performance gap.
  - Redundant indexes exist across multiple `fact`/`dim` tables.
  - Sequence cache tuning needed in places (see §9).
  - DDL drift identified against `gas_db_ddls_merged_20260530.sql` — the merged DDL file is not fully in sync with the live schema.

---

## 9. Sequences & Surrogate Keys

- Convention: `nextval()`-based sequences for surrogate keys (not `IDENTITY` columns), explicitly linked via `ALTER SEQUENCE ... OWNED BY`.
- A dedicated synchronization script (`gas_db_sequence_synchronization.sql`) resets sequences to `COALESCE(MAX(id), 0)` of their owning column and (re)attaches them as column defaults — used to recover sequences after bulk loads, migrations, or `IDENTITY`-to-sequence conversions. Covers: `dim.element`, `dim.view`, `dim.frequentcustomer`, `dim.itemcategory`, `dim.kiosk`, `dim.menuitem`, `dim.occasionsurvey`, `dim.ordertype`, `fact.devicestate`, `fact.ordertiming`, `fact.transactionheader`, `fact.userbehaviour`.

---

## 10. Deduplication Infrastructure

Per-location `ROW_NUMBER()` / `ctid`-based `DELETE` stored procedures, with `syscosmosts DESC` as the tie-breaker, applied against:
- `fact.occasionsurveydetail`
- `fact.itemssurvey`
- `fact.deviceevent` (~176M rows — via `usp_dedup_deviceevent_by_location`, looping per location with mid-loop `COMMIT`s to avoid long-running transactions on a large table)
- `fact.userbehaviour` (~36M rows — rebuilt as a combined `INSERT` covering all enrichment joins in one pass)

Supporting tuning work: unique constraints added post-dedup, `autovacuum_vacuum_scale_factor = 0.02` on these tables, and `VACUUM VERBOSE` used to confirm I/O-bound (not CPU-bound) runs.

---

## 11. Other Data Model Notes

- `dim.item_modifier_group_modifier_mapping`, `dim.category_hierarchy`, `dim.duplicate_items_master`, and `dim.grubbrr_source_lookup` support catalog normalization across POS/kiosk sources.
- Several `_bkp` tables exist (`dim.frequentcustomer_bkp`, `dim.itemcategory_bkp`, `dim.ordertype_bkp`, `dim.weather_bkp`, `fact.recommendations_bkp`) — pre-migration backups kept alongside live tables.
- `fact.watermarktable`, `fact.pipelinerunstatus`, `fact.gem_failed_order_job_notifications`, and `etl.bronze_partition_registry` form the operational/observability layer for the pipeline itself, separate from business fact tables.
- Two reporting views exist: `dim.vw_grubbrrinstallbase` / `dim.vw_grubbrrinstallbase_all_devices` (install-base dashboard) and `fact.vw_offer_analysis`.

---

## 12. Open Items / Roadmap

1. Azure Function for Bronze small-file compaction (NDJSON concatenation) — hosting plan (Consumption vs. Premium) undecided.
2. BRIN index rollout across the ~35 tables missing `syscosmosts` coverage.
3. Add primary keys to the ~10 fact tables currently without one.
4. Add the missing unique constraint on `fact.ordertiming` required by its `ON CONFLICT` clause.
5. Clean up redundant indexes identified in the schema audit.
6. Resolve DDL drift against `gas_db_ddls_merged_20260530.sql`.
7. Sequence cache tuning for high-throughput surrogate key sequences.

---

*This document reflects the ARM template for `df-gas-test-eastus`, the merged DDL snapshot (`gas_db_ddls_merged_20260530.sql`), `dim`/`fact`/`ml` stored procedure files, `gas_indexes.sql`, and `gas_db_sequence_synchronization.sql`, cross-referenced with prior engineering work on this warehouse.*
