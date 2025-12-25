# Quick Reference

One-page summary of key decisions and patterns.

## Materialization Decision

| Row Count | Change Rate | Build Time | Use |
|-----------|-------------|------------|-----|
| Under 1M | Any | Under 30 sec | View or table |
| 1-10M | Any | Any | Table |
| Over 10M | Under 30% | Any | Incremental |
| Over 10M | Over 50% | Any | Table |

## Incremental Model Requirements

1. **Unique key** - identifies records for upsert
2. **Date filter** - enables partition pruning
3. **Lookback window** - catches late-arriving data  
4. **Merge strategy** - handles update conflicts

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id'
) }}

SELECT ...
FROM source

{% if is_incremental() %}
WHERE order_date >= (
    SELECT dateadd(day, -3, max(order_date)) 
    FROM {{ this }}
)
{% endif %}
```

## Selector Patterns

| Pattern | Meaning |
|---------|---------|
| `my_model` | Just this model |
| `my_model+` | Model + downstream |
| `+my_model` | Upstream + model |
| `+my_model+` | Full dependency tree |
| `staging.*` | All models in folder |
| `tag:daily` | Models with tag |

## Warehouse Sizing

| Workload | Warehouse | Threads |
|----------|-----------|---------|
| Staging/simple | Small | 2-4 |
| Standard marts | Medium | 4-8 |
| Heavy analytics | Large | 8-16 |
| Development | Small | 4 |

## SQL Optimization Patterns

1. **Push filters before joins** - reduce input size before expensive operations
2. **Select specific columns** - avoid `SELECT *` on wide tables
3. **Match join key types** - prevents runtime casting
4. **GROUP BY over window functions** - when you don't need per-row values
5. **QUALIFY for deduplication** - cleaner than ROW_NUMBER subquery

## Key Diagnostic Queries

**Find expensive models:**
```sql
SELECT query_text, total_elapsed_time / 60000 as minutes
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 7
  AND query_text LIKE '%CREATE%TABLE%'
ORDER BY total_elapsed_time DESC
LIMIT 10;
```

**Validate incremental:**
```sql
SELECT bytes_scanned / 1e9 as gb_scanned
FROM snowflake.account_usage.query_history
WHERE query_text LIKE '%your_model%'
ORDER BY start_time DESC
LIMIT 5;
```

Compare `gb_scanned` to table size. If equal, incremental isn't working.
