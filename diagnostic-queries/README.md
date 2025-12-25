# Diagnostic Queries

These queries help you find optimization opportunities in your Snowflake account. Run them against `snowflake.account_usage` views.

**Note:** Account usage data has a latency of 45 minutes to 3 hours. For real-time analysis, use `snowflake.information_schema` views instead.

## Files in This Folder

| File | Purpose |
|------|---------|
| `find_expensive_models.sql` | Identify highest-cost dbt models |
| `validate_incremental.sql` | Verify incremental models are pruning |
| `analyze_query_patterns.sql` | Find common inefficiencies |
| `late_arriving_data.sql` | Determine appropriate lookback windows |
| `warehouse_queuing.sql` | Detect thread/warehouse mismatches |
| `weekly_trend.sql` | Track compute usage over time |
| `dev_vs_prod.sql` | Compare development and production compute |

## Quick Diagnostics

**Find your top 10 most expensive models:**
```sql
SELECT query_text, total_elapsed_time / 60000 as minutes
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 7
  AND query_text LIKE '%CREATE%TABLE%'
ORDER BY total_elapsed_time DESC
LIMIT 10;
```

**Check development vs production spend:**
```sql
SELECT warehouse_name, sum(credits_used) as total_credits
FROM snowflake.account_usage.warehouse_metering_history
WHERE start_time >= current_date() - 30
GROUP BY warehouse_name
ORDER BY total_credits DESC;
```

## Using These Queries

1. Run the relevant query in your Snowflake worksheet
2. Replace placeholder values (YOUR_MODEL, YOUR_SCHEMA) with your actual values
3. Adjust date ranges as needed
4. Export results for analysis or sharing

## What to Look For

**Expensive models:** The top 20% of models by compute often account for 80% of costs. Focus optimization efforts there.

**Failed incrementals:** If `bytes_scanned` on incremental runs equals full table size, the incremental logic isn't working.

**Dev waste:** If development warehouses use more credits than production, there's opportunity in selective builds.

**Warehouse queuing:** Non-zero queue time means threads are too high for the warehouse size.
