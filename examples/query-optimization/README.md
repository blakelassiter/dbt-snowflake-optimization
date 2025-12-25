# Query Optimization Patterns

These SQL patterns can improve query performance by 10-100x. They're not obscure tricks - they're fundamental to how Snowflake processes data.

## How Snowflake Works (Quick Version)

**Columnar storage:** Data is stored by column, not by row. Selecting 5 columns from a 150-column table only reads those 5 columns. SELECT * reads everything.

**Micro-partitions:** Data is organized into 50-500MB chunks. Each partition has metadata about what's inside (min/max values per column). Snowflake can skip entire partitions when filtering if it knows the data isn't there.

**Query optimizer:** Snowflake decides how to execute your query. Some patterns give it better options than others.

## Files in This Folder

| File | Pattern | Typical Impact |
|------|---------|---------------|
| `early_filter.sql` | Push filters before joins | 10-100x improvement |
| `column_selection.sql` | Avoid SELECT * on wide tables | 5-15x improvement |
| `type_matching.sql` | Match join key data types | 5-20x improvement |
| `group_by_vs_window.sql` | Use GROUP BY instead of window functions | 2-10x improvement |
| `qualify_dedup.sql` | Use QUALIFY for deduplication | 2-5x improvement |

## Priority Order

If you're doing a code review, check these in order:

1. **Are filters applied before joins?** Biggest impact. Joining 50M rows then filtering is expensive.
2. **Is SELECT * used on wide tables?** Easy to fix. Only select columns you need.
3. **Are join key types matched?** Type casting on every row kills performance.
4. **Are window functions used where GROUP BY would work?** GROUP BY is simpler and faster.
5. **Is deduplication done with ROW_NUMBER + subquery?** QUALIFY is cleaner and sometimes faster.

## Common Anti-Patterns

```sql
-- Anti-pattern: Join everything, then filter
SELECT * FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.order_date = current_date()  -- Filter after joining 50M x 10M

-- Better: Filter first, then join
WITH todays_orders AS (
    SELECT * FROM orders WHERE order_date = current_date()  -- 20k rows
)
SELECT * FROM todays_orders o
JOIN customers c ON o.customer_id = c.id  -- Join 20k, not 50M
```

```sql
-- Anti-pattern: SELECT * on a wide table
SELECT * FROM user_profiles  -- 150 columns

-- Better: Select what you need
SELECT user_id, email, signup_date FROM user_profiles  -- 3 columns
```
