# Reusable Macros

Simple macros that reduce boilerplate and enforce consistency across models.

## What's Here

| Macro | Purpose |
|-------|---------|
| `lookback_filter` | Standardized date filtering with configurable lookback window |
| `limit_dev` | Automatically limits data in dev environments |
| `log_model_timing` | Logs execution timing for debugging |

## lookback_filter

Generates a consistent date filter with a lookback window for late-arriving data.

```sql
{{ config(materialized='incremental') }}

SELECT *
FROM {{ ref('stg_events') }}
{% if is_incremental() %}
WHERE event_date >= {{ lookback_filter('event_date', 3) }}
{% endif %}
```

Generates:
```sql
WHERE event_date >= (SELECT max(event_date) - interval '3 days' FROM analytics.events)
```

## limit_dev

Limits row counts in development to speed up iteration.

```sql
SELECT *
FROM {{ ref('large_source_table') }}
{{ limit_dev(10000) }}
```

In dev: adds `LIMIT 10000`
In prod: adds nothing

## log_model_timing

Adds timing logs to help identify slow sections in complex models.

```sql
{{ log_model_timing('Starting aggregation') }}

WITH aggregated AS (
    SELECT ...
)

{{ log_model_timing('Aggregation complete, starting joins') }}

SELECT ...
```

Outputs to the dbt log with timestamps.

## Installation

Copy the `.sql` files from this folder to your project's `macros/` directory.

## Customization

These are intentionally simple. Common modifications:
- Adjust default lookback days
- Add additional dev/prod logic
- Include model name in timing logs
