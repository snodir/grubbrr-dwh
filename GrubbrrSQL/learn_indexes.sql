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