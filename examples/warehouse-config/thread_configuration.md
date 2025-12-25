# Thread Configuration

Threads and warehouse size work together. Misconfiguring them wastes resources.

## What Threads Do

The `threads` setting in dbt controls how many models run in parallel. If you have 100 models and threads=8, dbt runs up to 8 models simultaneously (respecting dependencies).

## Matching Threads to Warehouse Size

| Warehouse Size | Compute Nodes | Recommended Threads |
|----------------|---------------|---------------------|
| X-Small | 1 | 1-2 |
| Small | 2 | 2-4 |
| Medium | 4 | 4-8 |
| Large | 8 | 8-16 |
| X-Large | 16 | 16-24 |

**Too many threads:** Queries pile up waiting for warehouse resources. You see queuing in query history. No performance gain, potential timeouts.

**Too few threads:** Warehouse capacity sits idle while models run sequentially. You're paying for compute that isn't being used.

## How to Set Threads

Threads are set in `profiles.yml`:

```yaml
my_project:
  target: prod
  outputs:
    dev:
      type: snowflake
      warehouse: DEV_WH  # Small
      threads: 4
      # ... other connection settings
    
    prod:
      type: snowflake
      warehouse: PROD_WH  # Medium
      threads: 8
      # ... other connection settings
```

## Detecting Thread Misconfiguration

**Signs of too many threads:**

Run this query to check for warehouse queuing:

```sql
SELECT 
    warehouse_name,
    avg(queued_overload_time) / 1000 as avg_queued_seconds,
    max(queued_overload_time) / 1000 as max_queued_seconds,
    count(*) as query_count
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 7
    AND warehouse_name LIKE '%DBT%'
    AND queued_overload_time > 0
GROUP BY warehouse_name
ORDER BY avg_queued_seconds DESC;
```

If you see consistent queuing during dbt runs, reduce threads or increase warehouse size.

**Signs of too few threads:**

Check if your warehouse is underutilized during dbt runs. Look at the Snowflake Warehouses page in the UI - if credit usage stays flat and low during runs, threads might be the bottleneck.

## Thread Considerations

**Sequential dependencies:** If Model C depends on Model B depends on Model A, those three run sequentially regardless of thread count. High parallelism only helps when you have many independent models.

**Model runtime variance:** If you have 1 model that takes 10 minutes and 50 that take 30 seconds, high thread count doesn't help much. The 10-minute model is the bottleneck.

**Memory:** Each thread consumes memory on the Snowflake virtual warehouse. For very complex queries, fewer threads might perform better.

## Practical Recommendation

Start with threads matching your warehouse compute nodes (4 for Medium). Monitor for queuing. Adjust up if no queuing and warehouse has headroom, adjust down if seeing consistent queues.

Most projects do fine with threads=4 on a Medium warehouse.
