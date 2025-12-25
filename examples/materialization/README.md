# Materialization Examples

Choosing the right materialization is the highest-leverage optimization decision in dbt. A single change can reduce model cost by 80-95%.

## The Core Trade-off

- **Views**: Re-execute transformation logic on every query. Zero build cost, ongoing query cost.
- **Tables**: Execute transformation once, serve pre-computed results. Build cost once, cheap queries.
- **Incremental**: Execute transformation on changed data only. Lowest build cost for large tables.

## Files in This Folder

| File | Use Case |
|------|----------|
| `view_example.sql` | Small reference data, infrequently queried |
| `table_example.sql` | Medium tables, frequently queried |
| `incremental_example.sql` | Large tables with append-mostly patterns |

## Quick Decision Guide

Ask these questions in order:

1. **Under 1M rows and builds in under 30 seconds?** → View or table, your preference
2. **1-10M rows?** → Table (incremental overhead not worth it)
3. **Over 10M rows with less than 30% change rate?** → Incremental
4. **Over 10M rows with over 50% change rate?** → Table (merge overhead exceeds savings)

## The Math

Consider a 50M row fact table queried 10 times per hour.

**As a view:**
- Build cost: 0
- Query cost: 15 minutes × 10 queries × 24 hours = 3,600 minutes daily

**As a table:**
- Build cost: 15 minutes (once)
- Query cost: 3 seconds × 10 queries × 24 hours = 12 minutes daily
- Total: 27 minutes daily

**As incremental (with 50k daily additions):**
- Build cost: 30 seconds (once)
- Query cost: 3 seconds × 10 queries × 24 hours = 12 minutes daily
- Total: 12.5 minutes daily

Views cost 288x more than tables for this pattern. Incremental saves another 50% over tables.
