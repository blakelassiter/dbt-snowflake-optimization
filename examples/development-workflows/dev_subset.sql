/*
examples/development-workflows/dev_subset.sql

Limiting data in development environments

Developers don't need 10 years of historical data to test
transformations. A 90-day subset is usually sufficient and
dramatically faster.

This pattern uses dbt's target.name to apply different filters
in dev vs prod environments.
*/

{{ config(
    materialized='table'
) }}

select
    order_id,
    customer_id,
    order_date,
    order_total,
    status,
    created_at
from {{ source('sales', 'orders') }}

-- Apply date filter only in dev environment
{% if target.name == 'dev' %}
where order_date >= current_date() - 90  -- 90 days for dev
{% endif %}


/*
HOW IT WORKS

The target.name comes from your profiles.yml configuration.
When running with --target dev, the filter applies.
When running with --target prod, no filter - full data.


PROFILES.YML SETUP

my_project:
  target: dev  # Default target
  outputs:
    dev:
      type: snowflake
      warehouse: DEV_WH
      database: ANALYTICS_DEV
      schema: public
      threads: 4
      # ... connection settings

    prod:
      type: snowflake
      warehouse: PROD_WH
      database: ANALYTICS
      schema: public
      threads: 8
      # ... connection settings


ALTERNATIVE: Use a variable

For more control, use a dbt variable:

{{ config(materialized='table') }}

select * from {{ source('sales', 'orders') }}
where order_date >= current_date() - {{ var('lookback_days', 90) }}

Then override in production:
  dbt run --vars '{"lookback_days": 3650}'


WHAT TO SUBSET

Good candidates for dev subsetting:
  - Large fact tables (orders, events, transactions)
  - Historical snapshots
  - Log data

Usually keep full data for:
  - Dimension tables (customers, products) - typically smaller
  - Reference data
  - Lookup tables


SAMPLE DATA ALTERNATIVE

For very large tables, even 90 days might be too much.
Consider sampling:

{% if target.name == 'dev' %}
where order_date >= current_date() - 30
    and mod(hash(order_id), 10) = 0  -- 10% sample
{% endif %}

This gives you 10% of the last 30 days - enough to test
transformations without waiting for full dataset builds.


TESTING EDGE CASES

Subsetting can hide edge cases that only exist in old data.
Periodically run full builds in a staging environment to catch these.
But daily development doesn't need full data.
*/
