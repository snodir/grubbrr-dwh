# DWH Performance Analysis — gas_db (2026-05-30)
> Grubbrr Data Warehouse · Azure CosmosDB for PostgreSQL (Citus 16)  
> Schemas reviewed: `dim`, `fact`, `stg`, `etl`, `ml`

---

## 1. Redundant & Duplicate Indexes

These indexes overlap with existing ones and add write overhead with zero read benefit.

### 1a. `dim.datedim` — 3 indexes doing the work of 1

```sql
-- Existing:
CREATE INDEX idx_datedim_dateid  ON dim.datedim (dateid);
CREATE INDEX idx_datedim_datets  ON dim.datedim (datets);
CREATE INDEX IX_dateid_datets    ON dim.datedim (dateid, datets);
```

`idx_datedim_dateid` is fully covered by `IX_dateid_datets` (dateid is the leading column).  
The PK `datedim_pk (dateid)` is commented out — once restored it supersedes all three.

**Action:**
```sql
DROP INDEX IF EXISTS dim.idx_datedim_dateid;  -- covered by IX_dateid_datets
-- Restore the PK when ready; then IX_dateid_datets also becomes redundant.
```

---

### 1b. `fact.devicehealth` — exact duplicate deviceid indexes

```sql
-- Both index the identical single column:
CREATE INDEX deviceid_idx               ON fact.devicehealth (deviceid);
CREATE INDEX idx_devicehealth_deviceid  ON fact.devicehealth (deviceid);
-- Plus a covering index that already handles deviceid-only scans:
CREATE INDEX devicehealth_idx           ON fact.devicehealth
    (deviceid, locationid, companyid)
    INCLUDE (devicetype, status, healthdatatype, healthdatatime, statuschangetime);
```

`deviceid_idx` and `idx_devicehealth_deviceid` are byte-for-byte identical. `devicehealth_idx` makes both redundant for deviceid-only lookups since deviceid is its leading column.

**Action:**
```sql
DROP INDEX IF EXISTS fact.deviceid_idx;
DROP INDEX IF EXISTS fact.idx_devicehealth_deviceid;
```

---

### 1c. `fact.devicestate` — locationid index shadowed by composite

```sql
CREATE INDEX idx_devicestate            ON fact.devicestate (locationid, companyid, deviceid);
CREATE INDEX idx_devicestate_locationid ON fact.devicestate (locationid);  -- redundant
```

The composite index handles all locationid-only scans (leading column).

**Action:**
```sql
DROP INDEX IF EXISTS fact.idx_devicestate_locationid;
```

---

### 1d. `fact.devicetelemetry` — PK covers the single-column indexes

The PK is `PRIMARY KEY (locationid, deviceid, dateid)`. Yet:

```sql
CREATE INDEX idx_devicetelemetry          ON fact.devicetelemetry (locationid, deviceid);
CREATE INDEX idx_devicetelemetry_locationid ON fact.devicetelemetry (locationid);
```

Both are redundant — the PK index already supports leading-column lookups for `(locationid, deviceid)` and `(locationid)` alone.

**Action:**
```sql
DROP INDEX IF EXISTS fact.idx_devicetelemetry;
DROP INDEX IF EXISTS fact.idx_devicetelemetry_locationid;
-- Keep idx_devicetelemetry_dateid — dateid is the 3rd PK column and cannot use the PK for dateid-only scans.
```

---

### 1e. `dim.organizationlocation` — single-column organizationid index shadowed

```sql
CREATE INDEX IX_organizationid_locationid         ON dim.organizationlocation (organizationid, locationid)
    INCLUDE (organizationname, locationname);       -- composite + covering
CREATE INDEX idx_organizationlocation_organizationid ON dim.organizationlocation (organizationid); -- redundant
```

`organizationid` is the leading column of `IX_organizationid_locationid`, so single-column lookups on `organizationid` use it.  
`idx_organizationlocation_locationid` is still needed (locationid is not a leading column of the composite index).

**Action:**
```sql
DROP INDEX IF EXISTS dim.idx_organizationlocation_organizationid;
```

---

### 1f. End-of-file duplicate declarations

At the bottom of `gas_db_ddls_merged_20260530.sql`, six indexes are declared a second time with `CREATE INDEX IF NOT EXISTS` after already being created mid-file:

```sql
-- These are duplicate declarations (already created above in the same file):
CREATE INDEX IF NOT EXISTS idx_fact_transactionitem_locationid   ON fact.transactionitem(locationid);
CREATE INDEX IF NOT EXISTS idx_fact_transactionpayment_locationid ON fact.transactionpayment(locationid);
CREATE INDEX IF NOT EXISTS idx_fact_itemmodifier_locationid       ON fact.itemmodifier(locationid);
CREATE INDEX IF NOT EXISTS ix_dim_menuitem_catalogid              ON dim.menuitem(catalogid);
CREATE INDEX IF NOT EXISTS ix_dim_modifier_catalogid              ON dim.modifier(catalogid);
CREATE INDEX IF NOT EXISTS ix_dim_modifiergroup_catalogid         ON dim.modifier_group(catalogid);
```

`IF NOT EXISTS` makes them harmless at runtime, but they add noise to the DDL file and should be removed from the footer block to keep the file canonical.

---

## 2. Missing Critical Indexes

### 2a. `fact.ordertiming` — missing UNIQUE constraint required by ON CONFLICT

`usp_gem_ordertiming_to_fact_ordertiming` does:

```sql
INSERT INTO fact.ordertiming ...
ON CONFLICT (locationid, eventtoken) DO UPDATE ...
```

PostgreSQL requires a unique index or constraint on `(locationid, eventtoken)` for `ON CONFLICT` to work. The current DDL only defines `PRIMARY KEY (id)`. **This procedure will throw an error at runtime.**

**Action (critical fix):**
```sql
CREATE UNIQUE INDEX IF NOT EXISTS uq_ordertiming_loc_token
    ON fact.ordertiming (locationid, eventtoken);
```

---

### 2b. `fact.transactionheader` — missing businessdate and frequentcustomerid indexes

`businessdate` (DATE) is the primary column for time-range analytics but has no index. `dateid` (YYYYMMDDHH integer) is indexed, but `businessdate` is used directly in the stored procs and by ML/reporting queries.

`frequentcustomerid` is used in multiple joins across `usp_customer_menu_preferences` and ML tables with no index support.

`orderstatus` is filtered (`orderstatus = 'order-placed'`) in the customer preferences proc with no index.

```sql
CREATE INDEX IF NOT EXISTS idx_th_businessdate
    ON fact.transactionheader (businessdate);

CREATE INDEX IF NOT EXISTS idx_th_locationid_businessdate
    ON fact.transactionheader (locationid, businessdate)
    INCLUDE (orderstatus, frequentcustomerid, ordertotal);

CREATE INDEX IF NOT EXISTS idx_th_frequentcustomerid
    ON fact.transactionheader (frequentcustomerid)
    WHERE frequentcustomerid IS NOT NULL;

-- Partial index for the common "placed + identified customer" filter:
CREATE INDEX IF NOT EXISTS idx_th_placed_fc
    ON fact.transactionheader (locationid, frequentcustomerid, orderdatelocal)
    WHERE orderstatus = 'order-placed' AND frequentcustomerid IS NOT NULL;
```

---

### 2c. `fact.transactionitem` — missing dimmenuitemid and businessdate indexes

`usp_customer_menu_preferences` and `usp_master_keys_for_duplicate_items` both join on `dimmenuitemid`. No index exists.

```sql
CREATE INDEX IF NOT EXISTS idx_ti_dimmenuitemid
    ON fact.transactionitem (dimmenuitemid)
    WHERE dimmenuitemid IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ti_businessdate
    ON fact.transactionitem (locationid, businessdate);

CREATE INDEX IF NOT EXISTS idx_ti_frequentcustomerid
    ON fact.transactionitem (frequentcustomerid)
    WHERE frequentcustomerid IS NOT NULL;
```

---

### 2d. `stg.silver_kiosk_events` — missing composite filter index

Multiple stored procs query this table with the same triple filter:
- `usp_refresh_element`: `eventmodule='kiosk' AND eventcategory='insight'`
- `usp_refresh_view`: same
- `usp_gem_ordertiming_to_fact_ordertiming`: `eventmodule='kiosk' AND application='nge'`
- `usp_gem_sent_surveys_to_fact`: `eventcategory='Survey' AND eventtype='Sent'`

The BRIN on `syscosmosts` helps with watermark filtering but not with category/type predicates.

```sql
-- For element + view refresh procs:
CREATE INDEX IF NOT EXISTS idx_ske_module_category_ts
    ON stg.silver_kiosk_events (eventmodule, eventcategory, syscosmosts)
    WHERE eventmodule = 'kiosk' AND eventcategory = 'insight';

-- For ordertiming proc (filters on eventcategory + eventtype pairs):
CREATE INDEX IF NOT EXISTS idx_ske_app_module_ts
    ON stg.silver_kiosk_events (application, eventmodule, eventcategory, eventtype, syscosmosts)
    WHERE eventmodule = 'kiosk' AND application = 'nge';

-- For sent_surveys proc:
CREATE INDEX IF NOT EXISTS idx_ske_survey_sent_ts
    ON stg.silver_kiosk_events (eventcategory, eventtype, locationid, syscosmosts)
    WHERE eventcategory = 'Survey' AND eventtype = 'Sent';
```

---

### 2e. Staging tables used in DISTINCT ON — missing (locationid, syscosmosts DESC) indexes

`usp_refresh_dim_location_kiosk_details` runs multiple `DISTINCT ON (locationid) … ORDER BY locationid, syscosmosts DESC` queries against these staging tables with no supporting indexes:

```sql
CREATE INDEX IF NOT EXISTS idx_stg_kiosk_config_loc_ts
    ON stg.dim_kiosk_config (locationid, syscosmosts DESC);

CREATE INDEX IF NOT EXISTS idx_stg_kiosk_appearance_loc_ts
    ON stg.dim_kiosk_appearance (locationid, syscosmosts DESC);

CREATE INDEX IF NOT EXISTS idx_stg_pos_provider_loc_ts
    ON stg.dim_pos_provider (locationid, syscosmosts DESC);

CREATE INDEX IF NOT EXISTS idx_stg_loyalty_config_loc_ts
    ON stg.dim_loyalty_configuration (locationid, syscosmosts DESC);

CREATE INDEX IF NOT EXISTS idx_stg_payment_provider_loc_ts
    ON stg.dim_payment_provider (locationid, syscosmosts DESC);
```

---

### 2f. `fact.devicestate.healthdatatime` — missing index for updatewatermark()

```sql
CREATE OR REPLACE FUNCTION fact.updatewatermark(tablename text)
-- Does: SELECT MAX(healthdatatime) FROM fact.devicestate  -- full table scan every call
```

```sql
CREATE INDEX IF NOT EXISTS idx_devicestate_healthdatatime
    ON fact.devicestate (healthdatatime DESC);
```

---

### 2g. `etl.bronze_partition_registry` — missing status + entity composite index

The ETL orchestration layer almost certainly queries "pending partitions for entity X":

```sql
CREATE INDEX IF NOT EXISTS idx_bpr_entity_status
    ON etl.bronze_partition_registry (entity, status)
    INCLUDE (partition_date, adf_pipeline_run_id);

CREATE INDEX IF NOT EXISTS idx_bpr_partition_date
    ON etl.bronze_partition_registry (partition_date);
```

---

### 2h. `dim.datedim.yearval` — type-cast barrier in businessdate view

`dim.businessdate` filters with:

```sql
WHERE ((d.yearval)::numeric = EXTRACT(year FROM now()))
```

Casting `yearval` to `numeric` prevents index use. `yearval` is an `integer`.

**Action — fix the view and add a supporting index:**
```sql
-- In the view definition, change both occurrences:
WHERE d.yearval = EXTRACT(year FROM now())::integer          -- drop the ::numeric cast
WHERE d.yearval = EXTRACT(year FROM (now() - '1 year'::interval))::integer

-- Add a supporting index:
CREATE INDEX IF NOT EXISTS idx_datedim_yearval ON dim.datedim (yearval);
```

---

## 3. Sequence Cache Tuning

All sequences use `CACHE 1`. On a Citus cluster with concurrent ETL pipelines, every `nextval()` hits the coordinator for a WAL write. For high-volume fact tables this is a significant bottleneck.

```sql
-- High-volume fact tables — raise cache significantly:
ALTER SEQUENCE fact.transactionheader_id_seq CACHE 500;
ALTER SEQUENCE fact.userbehaviour_id_seq     CACHE 500;
ALTER SEQUENCE fact.ordertiming_id_seq       CACHE 200;
ALTER SEQUENCE fact.devicestate_id_seq       CACHE 200;

-- Medium-volume dim tables:
ALTER SEQUENCE dim.frequentcustomer_customerkey_seq CACHE 100;
ALTER SEQUENCE dim.menuitem_id_seq                  CACHE 100;
ALTER SEQUENCE dim.itemcategory_id_seq              CACHE 50;
ALTER SEQUENCE dim.kiosk_id_seq                     CACHE 50;

-- Small/rare-insert tables — leave at 1 or set to 10:
ALTER SEQUENCE dim.element_elementid_seq            CACHE 10;
ALTER SEQUENCE dim.occasionsurvey_surveykey_seq     CACHE 10;
ALTER SEQUENCE dim.ordertype_id_seq                 CACHE 10;
ALTER SEQUENCE dim.view_id_seq                      CACHE 10;
```

> **Note:** Higher cache values mean gaps in sequence numbers on coordinator restart, but that is normal and expected for surrogate keys.

---

## 4. Stored Procedure Issues

### 4a. LIKE with prefix on un-indexed text column (usp_master_keys_for_duplicate_items)

```sql
-- Current: cannot use a standard btree index in UTF-8 default collation
WHERE transactionheaderid LIKE 'ordevt-%'

-- Option 1: change to equality/starts-with friendly expression
WHERE LEFT(transactionheaderid, 7) = 'ordevt-'

-- Option 2: add a text_pattern_ops index for LIKE prefix lookups
CREATE INDEX IF NOT EXISTS idx_ti_txnheaderid_pattern
    ON fact.transactionitem (transactionheaderid text_pattern_ops);
```

---

### 4b. Duplicated subquery in usp_customer_menu_preferences

The `it` subquery (resolving itemid/itemtype from `fact.transactionitem`) is written identically inside both `Ranked1` and `Ranked2`. This causes two full scans of `transactionitem`:

```sql
-- Current: identical subquery in both CTEs
INNER JOIN (SELECT DISTINCT CASE WHEN itemtype = 'item' ... END as itemid, itemtype
            FROM fact.transactionitem WHERE ...) as it ON agg.itemid = it.itemid  -- ×2

-- Fix: materialize it once as a CTE at the top
WITH item_types AS (
    SELECT DISTINCT
        CASE WHEN itemtype = 'item' AND dimmenuitemid IS NOT NULL THEN dimmenuitemid
             WHEN itemtype <> 'item' AND comboid IS NOT NULL THEN comboid
        END AS itemid,
        itemtype
    FROM fact.transactionitem
    WHERE (itemtype = 'item' AND dimmenuitemid IS NOT NULL)
       OR (itemtype <> 'item' AND comboid IS NOT NULL)
), ...
-- Then reference item_types in both Ranked1 and Ranked2
```

---

### 4c. usp_refresh_location_kiosk_details vs usp_refresh_dim_location_kiosk_details — code duplication

These two procedures are byte-for-byte identical in body. One of them is almost certainly a legacy copy left over from a rename. Keeping both creates a maintenance hazard (fixing a bug in one doesn't fix it in the other).

**Action:** Determine which procedure name is called by ADF pipelines and drop the other:
```sql
DROP PROCEDURE IF EXISTS dim.usp_refresh_location_kiosk_details();
-- or
DROP PROCEDURE IF EXISTS dim.usp_refresh_dim_location_kiosk_details();
```

---

### 4d. usp_grubbrr_install_base vs usp_grubbrr_install_base_all_devices — 500+ lines duplicated

Both procedures share ~490 identical lines (CTEs `order_types_identities`, `json_order_types`, `array_order_types`, `device_details`, `total`). Only the final INSERT's WHERE clause differs.

**Refactor approach:** Extract the shared logic into a helper function (or a temp table populated by a shared proc), then call it from both procs:

```sql
-- Helper: populates a temp table with the full join result
CREATE OR REPLACE PROCEDURE dim._build_install_base_tmp()
LANGUAGE plpgsql AS $$
BEGIN
    CREATE TEMP TABLE tmp_install_base ON COMMIT DROP AS
    WITH order_types_identities AS (...),
         ...
         total AS (...)
    SELECT * FROM total;
END;
$$;

-- Live proc: calls helper, then filters
CREATE OR REPLACE PROCEDURE dim.usp_grubbrr_install_base()
LANGUAGE plpgsql AS $$
BEGIN
    TRUNCATE TABLE dim.vw_grubbrrinstallbase;
    CALL dim._build_install_base_tmp();
    INSERT INTO dim.vw_grubbrrinstallbase
    SELECT * FROM tmp_install_base
    WHERE location_status = 'Live' AND is_loc_active AND kiosk_mode = 'Live';
END;
$$;
```

---

### 4e. is_valid_jsonb() called per-row in hot paths

In both install base procs, `dim.is_valid_jsonb(kiosks)` and `dim.is_valid_jsonb(order_types)` are called per row during the `FROM` clause filter. This is an `IMMUTABLE` PL/pgSQL function that traps exceptions — exceptions in PL/pgSQL are expensive even when caught.

**If the upstream ETL guarantees valid JSON before writing to `dim.kioskdetails`**, the guards can be removed. Otherwise, consider a persisted boolean flag:

```sql
ALTER TABLE dim.kioskdetails ADD COLUMN IF NOT EXISTS kiosks_is_valid BOOLEAN;
-- Populate once, then maintain with a trigger or ETL step.
-- Index for the filter:
CREATE INDEX IF NOT EXISTS idx_kioskdetails_kiosks_valid
    ON dim.kioskdetails (locationid) WHERE kiosks_is_valid = TRUE;
```

---

### 4f. DISTINCT on 100+ columns in usp_grubbrr_install_base

The `total` CTE ends with `SELECT DISTINCT` across ~120 columns. PostgreSQL must sort or hash all rows on all 120 columns to deduplicate. The root cause (joining one location/kiosk to multiple org rows) should be fixed at the join level:

```sql
-- Current:
INNER JOIN (SELECT * FROM dim.organizationlocation WHERE organizationtype = 0) AS ol
-- Potential source of duplication

-- Better: ensure the subquery itself returns one row per locationid
INNER JOIN (
    SELECT DISTINCT ON (locationid) *
    FROM dim.organizationlocation
    WHERE organizationtype = 0
    ORDER BY locationid
) AS ol ON dd.location_id = ol.locationid
-- Then remove DISTINCT from SELECT in the outer query
```

---

## 5. Schema Design Observations

### 5a. dim.view has no primary key or unique constraint

The `dimelement_pkey` and `survey_pkey` constraints are in the commented-out block. `dim.view` currently has no PK — only `idx_view_viewid`. Since `usp_refresh_view` inserts `nextval()`-generated keys without a PK, duplicate `viewid` values are theoretically possible.

```sql
ALTER TABLE dim.view ADD CONSTRAINT view_pk PRIMARY KEY (viewid);
-- Or at minimum:
CREATE UNIQUE INDEX IF NOT EXISTS uq_view_viewid ON dim.view (viewid);
CREATE UNIQUE INDEX IF NOT EXISTS uq_view_name   ON dim.view (viewname);
```

---

### 5b. fact.transactionheader — dual timestamp columns, inconsistent usage

Both `orderdateutc` (TEXT) and `orderdatelocal` (TIMESTAMP) exist, and `businessdate` (DATE) is derived from them. Storing a timestamp as TEXT defeats indexing. If `orderdateutc` is only used for raw storage/audit, that's fine — but it should never appear in WHERE clauses or joins. Verify no ad-hoc queries are filtering on `orderdateutc` as a string.

---

### 5c. fact.ordertiming missing a unique constraint for natural key

Beyond the ON CONFLICT fix in section 2a, the natural key `(locationid, eventtoken)` should be formally declared:

```sql
-- Already recommended above — restated for schema completeness:
ALTER TABLE fact.ordertiming
    ADD CONSTRAINT uq_ordertiming_loc_token UNIQUE (locationid, eventtoken);
-- This also serves as the ON CONFLICT target, replacing the index-only approach.
```

---

## 6. Sequence Synchronization Script (Minor)

In `gas_db_sequence_synchronization.sql`, the `setval()` call for an empty table returns `0`, and a subsequent `nextval()` would return `1` — correct. However, if the sequence already exists and was used beyond the table's current max (e.g. after a restore or partial delete), `setval(..., 0)` would reset the sequence below the highest used key, causing a duplicate key violation on the next insert.

**Safer pattern (already partially implied by COALESCE but worth making explicit):**

```sql
SELECT setval(
    'dim.element_elementid_seq',
    GREATEST(
        (SELECT COALESCE(MAX(elementid), 0) FROM dim.element),
        (SELECT last_value FROM dim.element_elementid_seq)
    )
);
```

Apply this `GREATEST(MAX, last_value)` pattern to all `setval()` calls in the synchronization script.

---

## 7. Summary Checklist

| Priority | Area | Action |
|---|---|---|
| 🔴 Critical | `fact.ordertiming` | Add `UNIQUE (locationid, eventtoken)` — ON CONFLICT will fail without it |
| 🟠 High | `fact.transactionheader` | Add indexes on `businessdate`, `frequentcustomerid`, partial on `orderstatus` |
| 🟠 High | `stg.silver_kiosk_events` | Add composite partial indexes for event module/category/type filters |
| 🟠 High | `fact.devicehealth` | Drop duplicate `deviceid_idx` / `idx_devicehealth_deviceid` |
| 🟠 High | `usp_gem_ordertiming_to_fact_ordertiming` | Blocked until unique constraint added (see Critical) |
| 🟡 Medium | All sequences | Raise `CACHE` for high-volume tables |
| 🟡 Medium | `dim.businessdate` view | Fix `::numeric` cast to `::integer` on `yearval`; add `idx_datedim_yearval` |
| 🟡 Medium | `stg.*` provider tables | Add `(locationid, syscosmosts DESC)` indexes for DISTINCT ON dedup procs |
| 🟡 Medium | `fact.transactionitem` | Add indexes on `dimmenuitemid`, `businessdate`, `frequentcustomerid` |
| 🟡 Medium | `usp_customer_menu_preferences` | Remove duplicated `item_types` subquery |
| 🟡 Medium | `fact.devicestate` | Drop `idx_devicestate_locationid` (covered by composite) |
| 🟡 Medium | `fact.devicetelemetry` | Drop `idx_devicetelemetry` + `idx_devicetelemetry_locationid` (covered by PK) |
| 🟢 Low | Install base procs | Refactor shared 490-line CTE into a helper procedure |
| 🟢 Low | `usp_refresh_location_kiosk_details` | Reconcile with `usp_refresh_dim_location_kiosk_details` (one is a dead copy) |
| 🟢 Low | Sequence sync script | Apply `GREATEST(MAX, last_value)` pattern to all `setval()` calls |
| 🟢 Low | `dim.view` | Restore or add PK/unique constraint |
| 🟢 Low | DDL file footer | Remove 6 duplicate `CREATE INDEX IF NOT EXISTS` declarations |
