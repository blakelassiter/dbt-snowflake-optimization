/*
examples/incremental-patterns/date_filter.sql

Basic date filter pattern for incremental models

The date filter is what enables Snowflake's partition pruning.
Without it, your "incremental" model scans every row.

Snowflake stores data in micro-partitions (50-500MB chunks).
Date columns typically align with partition boundaries because
data arrives chronologically. Filtering on dates lets Snowflake
skip entire partitions without reading them.
*/

{{ config(
    materialized='incremental',
    unique_key='event_id'
) }}

select
    event_id,
    user_id,
    event_type,
    event_properties,
    event_timestamp,
    event_date
from {{ source('analytics', 'events') }}

{% if is_incremental() %}
    /*
    This WHERE clause is the critical piece.
    It limits source scanning to recent data only.
    
    Snowflake sees: "only need data after X date"
    Snowflake does: skips all partitions before that date
    Result: scanning 50k rows instead of 50M
    */
    where event_date > (
        select max(event_date) from {{ this }}
    )
{% endif %}


/*
WHAT HAPPENS ON EACH RUN:

First run (table doesn't exist):
  - is_incremental() returns false
  - WHERE clause is skipped
  - Full source table is read
  - Table is created with all historical data

Subsequent runs (table exists):
  - is_incremental() returns true
  - WHERE clause filters to events after max existing date
  - Only new partitions are scanned
  - New records are merged into existing table
*/
