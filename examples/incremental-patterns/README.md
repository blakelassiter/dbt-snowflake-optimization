# Incremental Model Patterns

Many "incremental" models aren't actually incremental. They have `materialized='incremental'` in the config but scan the full source table on every run. The query history shows full table scans. The config lies.

This happens because incremental models need four components working together. Miss one and you're paying for full scans while thinking you're optimized.

## The 4 Required Components

| Component | Purpose | What Happens Without It |
|-----------|---------|------------------------|
| Unique key | Identifies records for upsert | Duplicates or unpredictable updates |
| Date filter | Enables partition pruning | Full table scan every run |
| Lookback window | Catches late-arriving data | Missing or stale records |
| Merge strategy | Handles update conflicts | Wrong data on conflicts |

## Files in This Folder

| File | Component Demonstrated |
|------|----------------------|
| `date_filter.sql` | Basic incremental with date-based filtering |
| `lookback_window.sql` | Handling late-arriving data |
| `composite_key.sql` | When no single column is unique |
| `surrogate_key.sql` | Creating a unique key from multiple columns |
| `merge_strategy.sql` | Controlling how updates are handled |
| `validate_incremental.sql` | How to verify your model is actually incremental |

## How to Verify Your Model is Incremental

Run this after a normal (non-full-refresh) dbt run:

```sql
SELECT 
    query_text,
    bytes_scanned / 1e9 as gb_scanned,
    rows_produced,
    total_elapsed_time / 1000 as seconds
FROM snowflake.account_usage.query_history
WHERE query_text LIKE '%your_model_name%'
    AND start_time >= current_date() - 1
ORDER BY start_time DESC;
```

Compare `bytes_scanned` to your full table size. If they're roughly equal, your incremental isn't working.

## Common Failure Modes

**No `is_incremental()` block:**
```sql
-- This scans everything, every time
{{ config(materialized='incremental', unique_key='id') }}
select * from source_table
where status = 'active'  -- No is_incremental() check
```

**Filtering on non-date columns:**
```sql
{% if is_incremental() %}
where status = 'pending'  -- Scans every partition to find pending records
{% endif %}
```

**Missing lookback window:**
```sql
{% if is_incremental() %}
where order_date > (select max(order_date) from {{ this }})
-- Late-arriving data from yesterday is permanently missed
{% endif %}
```
