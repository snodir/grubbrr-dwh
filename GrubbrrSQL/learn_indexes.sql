/*
Great topic — indexing strategy in a Data Warehouse is quite different from an OLTP system. Here's a breakdown:


--CALL ml.usp_refresh_item_modifiergroup_modifier_mapping(p_organizationid => 'org-5cf80db5-7a28-4dcf-846b-8cdf5f362269');

--without an index on catalogid, and unique constraint on menuitemid, this took more than 20 minutes, 
--and even did not complete, 
--but after adding these 2, it took 00:00:01.766 (hh:mm:ss.ms)

---

## How Indexes Are Used in DW Tables

In a DW, queries are typically:
- **Large analytical scans** (aggregations, GROUP BY, window functions)
- **Multi-table joins** (fact ↔ dimension)
- **Filtered aggregations** on date ranges, status columns, tenant IDs, etc.

So indexes are used **selectively** — not on every column like OLTP, but on:

| Use Case | Index Type |
|---|---|
| Date/time range filters (`WHERE created_at BETWEEN`) | B-tree |
| Low-cardinality filters (`WHERE status = 'active'`) | Partial B-tree or BRIN |
| Join keys (FK → dimension PK) | B-tree |
| Large append-only fact tables by date | BRIN |
| Full-text or JSONB columns | GIN |

**BRIN (Block Range Index)** is particularly valuable in DW fact tables because:
- Data is naturally ordered by ingestion/event time
- BRIN is extremely small (stores min/max per block range, not per row)
- Perfect for `WHERE event_date >= ...` on large fact tables

---

## How Indexes Affect Batch Data Loading

This is where DW indexing gets tricky — **indexes hurt write performance**:

- Every `INSERT`/`UPDATE` must maintain all indexes on the table
- The more indexes, the slower your ADF pipeline loads
- On large batch loads (millions of rows), this overhead compounds significantly

**What happens during a batch load with indexes present:**

```
Insert row → update B-tree index 1 → update B-tree index 2 → update BRIN → ...
             (random I/O)              (random I/O)           (sequential I/O)
```

B-tree indexes cause **random I/O** during writes, which is expensive at scale.

---

## Best Practices

### 1. Drop → Load → Rebuild pattern for large loads
```sql
-- Before ADF pipeline load
*/

DROP INDEX CONCURRENTLY idx_fact_orders_created_at;

/*
-- ADF bulk insert runs here (much faster)

-- After load completes
*/


CREATE INDEX CONCURRENTLY idx_fact_orders_created_at 
ON fact_orders (created_at);


/*```
`CONCURRENTLY` avoids locking the table for reads during rebuild.

---

### 2. Use BRIN over B-tree on large fact tables
```sql
-- For a 500M row fact table ordered by event time
*/


CREATE INDEX idx_fact_events_brin 
ON fact_events USING BRIN (event_timestamp)
WITH (pages_per_range = 128);

/*```
BRIN has near-zero write overhead vs B-tree.

---

### 3. Partial indexes for common filtered queries
```sql
-- Only index active/recent records instead of full table
*/

CREATE INDEX idx_orders_active 
ON fact_orders (customer_id, created_at)
WHERE status != 'cancelled';

/*
```
Smaller index = faster writes + faster reads.

---

### 4. Index only what your queries actually use
Run this to find unused indexes — dead weight during loads:
```sql
*/

SELECT * --schemaname, tablename, indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan > 0
--ORDER BY schemaname, tablename;


/*```

---

### 5. Covering indexes for frequent aggregation queries
```sql
-- Avoid heap fetch entirely for this common reporting query

*/
CREATE INDEX idx_orders_covering
ON fact_orders (tenant_id, created_at)
INCLUDE (order_total, status);

/*
```

---

### 6. In Citus — align indexes with distribution column
```sql
-- Distribution column (tenant_id) should lead the index
-- so the planner can push the query down to a single shard
*/
CREATE INDEX idx_fact_orders_tenant_date
ON fact_orders (tenant_id, created_at);

/*
```
An index that doesn't include the distribution column can't be used for shard pruning, making it much less effective.

---

## Summary Mental Model

| Table Type | Strategy |
|---|---|
| Large fact table | BRIN on date, B-tree on FK/distribution col only |
| Dimension table | B-tree on PK (auto), B-tree on natural key lookups |
| Staging/temp tables | **No indexes** — drop before load, they're transient |
| Aggregate/summary tables | Index columns used in downstream BI/reporting filters |

The golden rule in DW: **index for reads, but always measure the write cost** — especially relevant when your ADF pipelines are loading millions of rows on a schedule.
*/


-- # BRIN Indexes on Timestamp columns

SELECT schemaname, tablename, attname, inherited, null_frac, avg_width, correlation
FROM pg_stats
WHERE tablename = 'transactionheader'
  AND attname = 'syscosmosts';

--SELECT count(syscosmosts), count(*) FROM fact.transactionheader --2,607,836	3,244,031

--transactionitem   fact	transactionitem	    syscosmosts	False	0.7107	    8	-0.59242475
--transactionheader fact	transactionheader	syscosmosts	False	0.72356665	8	 0.38891634  fact	transactionheader	syscosmosts	False	0.19506666	8	0.595906
--userbehaviour     fact	userbehaviour	    syscosmosts	False	0.7826667	8	-0.48464713


/*Great use case — an epoch seconds column like `syscosmosts` is actually **ideal for BRIN**, arguably better than a regular timestamp in some ways. Here's a deep dive:

---

## How BRIN Works Internally

BRIN doesn't index individual row values. Instead it divides the table's **physical storage into block ranges** and stores just the **min/max value per range**:

```
Physical Blocks:   [0-127]        [128-255]      [256-383]
BRIN stores:       min=1700000000  min=1700086400  min=1700172800
                   max=1700086399  max=1700172799  max=1700259199
```

When a query runs `WHERE syscosmosts >= 1700500000`, PostgreSQL:
1. Checks each range's min/max in the BRIN index
2. **Skips entire block ranges** where `max < 1700500000`
3. Only scans blocks where the range overlaps your filter

This is why it's called a **lossy** index — it doesn't pinpoint exact rows, it eliminates irrelevant blocks.

---

## Why Epoch Seconds (syscosmosts) Is Perfect for BRIN

BRIN's effectiveness depends entirely on **correlation** — how well the physical row order matches the column's value order.

Your `syscosmosts` column has **natural correlation** because:
- Rows are inserted roughly in chronological order from the OLTP source
- ADF pipelines load batches sequentially, appending newer epochs at the end
- Older loads sit in earlier blocks, newer loads in later blocks

You can measure this correlation:

```sql
*/
SELECT attname, correlation
FROM pg_stats
WHERE tablename = 'transactionheader' --deviceevent
  AND attname = 'syscosmosts';
/*```

A value close to `1.0` means perfect physical order correlation → **BRIN will be extremely effective**.
A value close to `0` means random ordering → BRIN loses most of its value.

---

## Creating the BRIN Index on syscosmosts

```sql
*/
CREATE INDEX idx_fact_table_syscosmosts_brin
ON your_fact_table USING BRIN (syscosmosts)
WITH (pages_per_range = 128);  -- tune this
/*```

### Choosing `pages_per_range`

| Value | Index Size | Selectivity | When to Use |
|---|---|---|---|
| 16 | Larger | More precise | Smaller tables, very selective queries |
| 128 | Medium | Balanced | **Good default for large fact tables** |
| 256 | Tiny | Coarser | Huge tables, range queries span days/weeks |

For a very large fact table with ADF daily batch loads, `128` is a solid starting point.

---

## Querying with Epoch Seconds

Since `syscosmosts` is epoch seconds, your WHERE clauses would look like:

```sql
*/
-- Last 7 days
WHERE syscosmosts >= EXTRACT(EPOCH FROM NOW() - INTERVAL '7 days')::BIGINT

-- Specific date range
WHERE syscosmosts BETWEEN EXTRACT(EPOCH FROM '2024-01-01'::TIMESTAMPTZ)::BIGINT
                      AND EXTRACT(EPOCH FROM '2024-02-01'::TIMESTAMPTZ)::BIGINT

-- Convert on the fly for readability
WHERE TO_TIMESTAMP(syscosmosts) >= '2024-01-01'::TIMESTAMPTZ
/*```

**Important caveat:** wrapping `syscosmosts` in a function like `TO_TIMESTAMP()` on the left side **can prevent index usage** depending on the planner. Prefer keeping the raw epoch value on the left and converting constants on the right:

```sql*/
-- BETTER - index can be used
WHERE syscosmosts >= EXTRACT(EPOCH FROM '2024-01-01'::TIMESTAMPTZ)::BIGINT

-- WORSE - planner may skip the index
WHERE TO_TIMESTAMP(syscosmosts) >= '2024-01-01'
/*```

---

## BRIN vs B-tree on syscosmosts — Concrete Comparison

| | BRIN | B-tree |
|---|---|---|
| Index size (500M rows) | ~50–200 KB | ~10–20 GB |
| Write overhead per batch | Near zero | High (random I/O per row) |
| Point lookup (`= value`) | Poor | Excellent |
| Range scan (`BETWEEN`) | Excellent if correlated | Excellent |
| ADF batch load impact | Negligible | Significant slowdown |
| After bulk load maintenance | Auto (or manual `BRIN_SUMMARIZE`) | Rebuild recommended |

---

## One Extra Step After ADF Batch Loads

BRIN indexes on new pages aren't automatically summarized in older PostgreSQL versions. After a large ADF load, run:

```sql*/

-- Summarize only the new unsummarized ranges (fast, non-blocking)
SELECT BRIN_SUMMARIZE_NEW_VALUES('idx_fact_table_syscosmosts_brin');

-- Or force full re-summarization if data was heavily updated
SELECT BRIN_SUMMARIZE_RANGE('idx_fact_table_syscosmosts_brin', 0, 2147483647);
/*```

In PostgreSQL 13+ with `autosummarize = on` (the default), this happens automatically — but for large ADF loads it's good practice to call it explicitly at the end of your pipeline to ensure the index is current before downstream queries run.

---

## In Citus Context

On your Citus cluster, if `syscosmosts` is **not** your distribution column (e.g., `tenant_id` is), the BRIN index still works — but it operates **per shard**. Each shard maintains its own BRIN structure, so the block range correlation holds within each shard as long as your ADF pipeline loads data in time order per tenant.



Good practical question. There's no universal answer — it depends on **table size + row width + query range granularity**. Let me break it down properly.

---

## The Core Formula

```
rows_per_page  = 8192 (page size bytes) / avg_row_width_bytes
total_pages    = total_rows / rows_per_page
rows_per_range = pages_per_range × rows_per_page
```

The goal is: **each BRIN range should roughly correspond to one meaningful query time window** (e.g., one day, one batch load).

---

## First — Measure Your Actual Row Width

```sql
*/
SELECT
    relname                             AS table_name,
    n_live_tup                          AS live_rows,
    pg_relation_size(oid)               AS table_bytes,
    pg_relation_size(oid) / 
        NULLIF(n_live_tup, 0)           AS avg_bytes_per_row,
    pg_relation_size(oid) / 8192        AS total_pages
FROM pg_class
WHERE relname = 'your_fact_table';

/*```

Typical fact table row widths:
- Lean fact (few FKs + metrics): ~80–120 bytes → ~68–100 rows/page
- Medium fact (many FKs + metrics): ~150–250 bytes → ~33–55 rows/page
- Wide fact (lots of columns): ~300–500 bytes → ~16–27 rows/page

---

## Recommended pages_per_range by Table Size

Assuming **medium row width (~150 bytes, ~55 rows/page)** and **daily batch loads via ADF**:

| Table Size | Total Pages | pages_per_range | Rows per Range | Approx Range = |
|---|---|---|---|---|
| 1M rows | ~12,000 | **16** | ~880 | few hours of data |
| 5M rows | ~60,000 | **32** | ~1,760 | ~half day |
| 10M rows | ~120,000 | **64** | ~3,500 | ~1 day |
| 50M rows | ~600,000 | **64–128** | ~3,500–7,000 | 1–2 days |
| 100M rows | ~1,200,000 | **128** | ~7,000 | ~1–2 days |
| 200M rows | ~2,400,000 | **128–256** | ~7,000–14,000 | 2–3 days |

---

## Decision Logic to Pick Your Value

```
If your queries filter by:
    hours/minutes  →  use 16
    single day     →  use 32–64
    week ranges    →  use 128
    month ranges   →  use 256
```

Also factor in **how many rows ADF loads per batch**:

```sql
-- Rough check: how many rows land per day?
*/

SELECT
    DATE(TO_TIMESTAMP(syscosmosts)) AS load_date,
    COUNT(*)                        AS rows_per_day
FROM your_fact_table
GROUP BY 1
ORDER BY 1 DESC
LIMIT 14;
/*```

Ideally **one BRIN range ≈ one ADF batch** — that way each load fills a range cleanly and the min/max per range stays tight and selective.

---

## Validate Your Choice After Creation

```sql
*/
-- Check how many ranges were created and average range size
SELECT
    br.pages_per_range,
    COUNT(*)                        AS total_ranges,
    ROUND(AVG(br.value_2::BIGINT - 
              br.value_1::BIGINT))  AS avg_epoch_span_per_range
FROM brin_page_items(
    get_raw_page('your_fact_table_brin_index_name', 2), 
    'idx_your_table_syscosmosts_brin'
) br
GROUP BY 1;
/*```

You want `avg_epoch_span_per_range` to be in the ballpark of **one day (86400 seconds)** for typical DW reporting queries — tight enough to skip most ranges, not so tight the index becomes bulky.

---

## Practical Recommendation for Your Setup

Given your ADF pipelines load in batches and tables range 1M–200M rows:

| Your Table | Start With |
|---|---|
| 1M – 5M rows | `pages_per_range = 32` |
| 5M – 20M rows | `pages_per_range = 64` |
| 20M – 200M rows | `pages_per_range = 128` |

Start conservative, then use `EXPLAIN ANALYZE` to see how many blocks BRIN is eliminating — if it's still scanning too many blocks, lower the value and rebuild.

*/