# Common Mistakes

Anti-patterns that waste compute and how to fix them.

## Incremental Model Mistakes

### Missing Unique Key

❌ **Wrong:**
```sql
{{ config(materialized='incremental') }}

SELECT * FROM {{ ref('source') }}
{% if is_incremental() %}
WHERE updated_at > (SELECT max(updated_at) FROM {{ this }})
{% endif %}
```

This inserts duplicates when source records update.

✅ **Right:**
```sql
{{ config(
    materialized='incremental',
    unique_key='record_id'
) }}

SELECT * FROM {{ ref('source') }}
{% if is_incremental() %}
WHERE updated_at > (SELECT max(updated_at) FROM {{ this }})
{% endif %}
```

### Filter on Transformed Column

❌ **Wrong:**
```sql
{% if is_incremental() %}
WHERE DATE_TRUNC('day', event_timestamp) > (SELECT max(event_date) FROM {{ this }})
{% endif %}
```

Functions on the source column prevent partition pruning.

✅ **Right:**
```sql
{% if is_incremental() %}
WHERE event_timestamp > (SELECT max(event_timestamp) FROM {{ this }})
{% endif %}
```

### No Lookback Window

❌ **Wrong:**
```sql
WHERE created_at > (SELECT max(created_at) FROM {{ this }})
```

Late-arriving data gets missed forever.

✅ **Right:**
```sql
WHERE created_at > (SELECT max(created_at) - interval '3 days' FROM {{ this }})
```

## Materialization Mistakes

### Everything Is Incremental

Not every large table benefits from incremental:

| Situation | Better Choice |
|-----------|---------------|
| Table is fully replaced daily | Table |
| More than 50% of rows change | Table |
| Complex deduplication logic | Table |
| Simple append-only log | Incremental |

### Views That Query Other Views

❌ **Problem:**
```
view_a -> view_b -> view_c -> dashboard
```

The dashboard query executes all three views, compounding compute.

✅ **Solution:**
- Make intermediate layers tables
- Or collapse views into fewer layers
- Or make the final layer a table

### Tables That Should Be Views

Small lookup tables (< 100k rows) that rarely change don't need to be tables:

❌ **Wasteful:**
```sql
{{ config(materialized='table') }}
SELECT * FROM {{ ref('country_codes') }}  -- 250 rows
```

✅ **Better:**
```sql
{{ config(materialized='view') }}
SELECT * FROM {{ ref('country_codes') }}
```

## SQL Mistakes

### SELECT * on Wide Tables

❌ **Wrong:**
```sql
SELECT *
FROM {{ ref('wide_table_with_200_columns') }}
WHERE date = current_date()
```

Reads all 200 columns even if you only need 5.

✅ **Right:**
```sql
SELECT 
    customer_id,
    order_date,
    total_amount,
    status
FROM {{ ref('wide_table_with_200_columns') }}
WHERE date = current_date()
```

### Late Filtering

❌ **Wrong:**
```sql
WITH all_events AS (
    SELECT * FROM events  -- 1 billion rows
),
aggregated AS (
    SELECT user_id, count(*) as event_count
    FROM all_events
    GROUP BY user_id
)
SELECT * FROM aggregated
WHERE user_id = 12345
```

Aggregates 1 billion rows, then filters to 1 user.

✅ **Right:**
```sql
WITH filtered_events AS (
    SELECT * FROM events
    WHERE user_id = 12345  -- 10,000 rows
),
aggregated AS (
    SELECT user_id, count(*) as event_count
    FROM filtered_events
    GROUP BY user_id
)
SELECT * FROM aggregated
```

### Type Mismatch in Joins

❌ **Wrong:**
```sql
SELECT *
FROM orders o
JOIN customers c ON o.customer_id = c.id  -- customer_id is VARCHAR, id is NUMBER
```

Snowflake casts every row, preventing pruning.

✅ **Right:**
```sql
SELECT *
FROM orders o
JOIN customers c ON o.customer_id = c.id::varchar
-- Or fix the source to use consistent types
```

### Window Functions Without PARTITION BY

❌ **Wrong:**
```sql
SELECT 
    *,
    ROW_NUMBER() OVER (ORDER BY created_at) as rn  -- Operates on entire table
FROM large_table
```

✅ **Right:**
```sql
SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at) as rn
FROM large_table
```

## Development Workflow Mistakes

### Running Everything in Dev

❌ **Wrong:**
```bash
dbt run  # Builds 500 models
dbt test  # Tests 500 models
```

✅ **Right:**
```bash
dbt run --select my_model+  # Builds 3 models
dbt test --select my_model+  # Tests 3 models
```

### Using Production Warehouse for Dev

❌ **Wrong:**
```yaml
# profiles.yml
dev:
  warehouse: PROD_WAREHOUSE_XL
```

Development queries compete with production.

✅ **Right:**
```yaml
dev:
  warehouse: DEV_WAREHOUSE_S
```

### Full Refresh by Default

❌ **Wrong:**
Running `--full-refresh` routinely "just to be safe"

✅ **Right:**
Only full refresh when:
- Schema changed
- Logic changed in a way that affects historical data
- Data quality issue requires rebuild

## Configuration Mistakes

### Too Many Threads

❌ **Wrong:**
```yaml
my_project:
  threads: 32  # On an X-Small warehouse
```

Causes queuing and doesn't speed up builds.

✅ **Right:**

| Warehouse | Threads |
|-----------|---------|
| X-Small   | 1-2     |
| Small     | 2-4     |
| Medium    | 4-8     |
| Large     | 8-16    |

### Same Warehouse for Everything

❌ **Wrong:**
All jobs use `TRANSFORMING` warehouse.

✅ **Right:**
```yaml
models:
  my_project:
    staging:
      +snowflake_warehouse: TRANSFORMING_S
    marts:
      +snowflake_warehouse: TRANSFORMING_M
```

Match warehouse size to workload.
