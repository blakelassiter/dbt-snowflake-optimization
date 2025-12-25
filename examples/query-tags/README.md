# Query Tags

Query tags let you trace dbt models back to their Snowflake query history. This is essential for cost attribution and debugging.

## Why Query Tags Matter

When you run `dbt run`, Snowflake sees dozens of queries with no indication of which dbt model generated them. Query tags solve this by attaching metadata to every query.

Without query tags:
- "Which model is causing that 45-minute query?"
- "How much does the orders model cost per month?"
- "Which models are using the most compute?"

With query tags:
- Filter QUERY_HISTORY by model name, materialization type, or run ID
- Calculate cost per model
- Track performance trends over time

## Three Ways to Set Query Tags

### 1. Profile Level (profiles.yml)

Sets a default tag for all queries in a connection:

```yaml
my_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: abc12345.us-east-1
      user: "{{ env_var('DBT_USER') }}"
      password: "{{ env_var('DBT_PASSWORD') }}"
      database: analytics
      warehouse: transforming
      schema: dev
      query_tag: dbt_dev
```

### 2. Model Level (dbt_project.yml or config block)

Override the default for specific models:

```yaml
# dbt_project.yml
models:
  my_project:
    staging:
      +query_tag: staging_models
    marts:
      +query_tag: mart_models
```

Or in a model's config block:

```sql
{{ config(
    materialized='incremental',
    query_tag='orders_incremental'
) }}
```

### 3. Dynamic Tags (set_query_tag macro)

For rich metadata, override the `set_query_tag` macro. See `set_query_tag.sql` in this folder.

## Querying Tagged Results

```sql
SELECT 
    query_tag,
    count(*) as query_count,
    sum(total_elapsed_time) / 1000 / 60 as total_minutes,
    sum(bytes_scanned) / 1e12 as tb_scanned
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 30
    AND query_tag IS NOT NULL
GROUP BY query_tag
ORDER BY total_minutes DESC;
```

## JSON Query Tags

For complex analysis, use JSON-formatted tags:

```sql
SELECT 
    try_parse_json(query_tag):model::string as model_name,
    try_parse_json(query_tag):materialized::string as materialization,
    count(*) as runs,
    avg(total_elapsed_time) / 1000 as avg_seconds
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 7
    AND query_tag LIKE '{%'
GROUP BY 1, 2
ORDER BY avg_seconds DESC;
```

## Files in This Folder

- `set_query_tag.sql` - Custom macro for dynamic query tags
- `query_tag_analysis.sql` - Diagnostic queries for tagged data
