# Troubleshooting Guide

Common problems and how to diagnose them.

## My Incremental Model Isn't Incremental

**Symptoms:**
- Run time doesn't decrease after first build
- `bytes_scanned` is similar to full table size on every run
- Warehouse queuing increases during incremental runs

**Diagnosis:**

1. Check if incremental is actually running:
```sql
SELECT 
    query_text,
    bytes_scanned / 1e9 as gb_scanned,
    total_elapsed_time / 1000 as seconds
FROM snowflake.account_usage.query_history
WHERE query_text ILIKE '%my_model%'
    AND start_time >= current_date() - 7
ORDER BY start_time DESC;
```

If `bytes_scanned` equals your full table size, the WHERE clause isn't pruning.

2. Check the compiled SQL:
```bash
dbt compile --select my_model
cat target/compiled/my_project/models/my_model.sql
```

Look for the `is_incremental()` block and verify the date filter.

**Common Causes:**

| Cause | Solution |
|-------|----------|
| Date column isn't clustered | Snowflake auto-clusters, but check with `SYSTEM$CLUSTERING_INFORMATION` |
| Filter uses function on column | Use `WHERE date_col >= X` not `WHERE DATE_TRUNC('day', date_col) >= X` |
| Missing `unique_key` | Add `unique_key` config to enable MERGE instead of INSERT |
| Wrong `is_incremental()` logic | Ensure filter references `{{ this }}` correctly |

## Costs Suddenly Increased

**Diagnosis:**

1. Find the spike:
```sql
SELECT 
    date_trunc('hour', start_time) as hour,
    sum(total_elapsed_time) / 1000 / 60 as total_minutes,
    sum(bytes_scanned) / 1e12 as tb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 7
    AND warehouse_name = 'TRANSFORMING'
GROUP BY 1
ORDER BY 1;
```

2. Find the culprit queries:
```sql
SELECT 
    query_text,
    bytes_scanned / 1e9 as gb_scanned,
    total_elapsed_time / 1000 / 60 as minutes
FROM snowflake.account_usage.query_history
WHERE start_time BETWEEN '2024-01-15 10:00' AND '2024-01-15 12:00'
ORDER BY bytes_scanned DESC
LIMIT 20;
```

**Common Causes:**

| Cause | Indicator | Solution |
|-------|-----------|----------|
| New model is expensive | Large `bytes_scanned` | Review SQL, add filters |
| Source table grew | More data processed | Switch to incremental |
| Full refresh ran | Spike on specific run | Check job configuration |
| Upstream model changed | Multiple models affected | Check upstream dependency |
| Someone ran `dbt run` in dev | Dev target queries | Use `--select` in dev |

## Model Is Slow

**Diagnosis:**

Check the query profile in Snowflake:
1. Find the query_id in query_history
2. Run `SELECT * FROM TABLE(GET_QUERY_OPERATOR_STATS('query_id'))`
3. Look for: spillage, partition scans, join explosions

**Common Causes:**

| Pattern | Cause | Solution |
|---------|-------|----------|
| High spillage | Warehouse too small | Increase warehouse size or optimize query |
| Full table scan | Missing filters | Add WHERE clause before aggregation |
| Many partitions scanned | Bad clustering | Add cluster key or filter on cluster column |
| Join produces many rows | Cartesian or bad join | Check join conditions |
| Window function slowness | Too much data | Add PARTITION BY to limit scope |

## Warehouse Queuing

**Symptoms:**
- Jobs take longer than expected
- `queued_overload_time` is high in query_history

**Diagnosis:**
```sql
SELECT 
    date_trunc('hour', start_time) as hour,
    avg(queued_overload_time) / 1000 as avg_queue_seconds,
    max(queued_overload_time) / 1000 as max_queue_seconds,
    count(*) as query_count
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 7
    AND warehouse_name = 'TRANSFORMING'
GROUP BY 1
HAVING avg_queue_seconds > 1
ORDER BY 1;
```

**Solutions:**

1. Reduce concurrency: Lower dbt threads
2. Increase warehouse: Use larger size for parallel workloads
3. Separate workloads: Use different warehouses for different jobs
4. Stagger schedules: Don't run everything at midnight

## Tests Failing After Optimization

**Common Issues:**

1. **Unique test fails on incremental**
   - Cause: Merge isn't de-duplicating properly
   - Check: `unique_key` matches the tested column
   - Check: No multiple rows with same key in source

2. **Not null test fails**
   - Cause: New incremental logic has different NULL handling
   - Check: Source data for NULLs
   - Check: COALESCE or default values in model

3. **Relationship test fails**
   - Cause: Incremental timing issue - fact loads before dimension
   - Solution: Ensure dimensions run before facts
   - Workaround: Add `where` config to test recent data only

## dbt Run Never Finishes

**Diagnosis:**

1. Check what's running:
```sql
SELECT query_text, start_time, warehouse_name
FROM snowflake.account_usage.query_history
WHERE execution_status = 'RUNNING'
    AND user_name = 'DBT_USER';
```

2. Check for blocked queries:
```sql
SELECT * FROM snowflake.account_usage.query_history
WHERE execution_status = 'BLOCKED';
```

**Common Causes:**

- Large model with insufficient warehouse
- Lock contention on tables
- Network issues between dbt and Snowflake
- Infinite loop in macro logic
