/*
examples/incremental-patterns/lookback_window.sql

Lookback window pattern for late-arriving data

Real data doesn't arrive perfectly on time. Orders get entered
retroactively. Upstream systems have processing delays. Records
get corrected after initial entry.

A lookback window reprocesses recent data to catch these cases.
You're trading a small amount of extra processing for data accuracy.
*/

{{ config(
    materialized='incremental',
    unique_key='transaction_id'
) }}

select
    transaction_id,
    account_id,
    transaction_type,
    amount,
    transaction_date,
    posted_date,
    created_at
from {{ source('finance', 'transactions') }}

{% if is_incremental() %}
    /*
    Instead of: where transaction_date > max(transaction_date)
    We use: where transaction_date >= max(transaction_date) - 3 days
    
    This reprocesses the last 3 days on every run.
    Late transactions from yesterday get picked up today.
    The unique_key handles deduplication automatically.
    */
    where transaction_date >= (
        select dateadd(day, -3, max(transaction_date))
        from {{ this }}
    )
{% endif %}


/*
CHOOSING THE RIGHT LOOKBACK WINDOW

Run this query against your source data to see how late records arrive:

  select
      datediff(day, transaction_date, created_at) as days_late,
      count(*) as record_count
  from source_table
  where created_at >= current_date() - 30
  group by 1
  order by 1 desc

Set your lookback to cover 95-99% of observed late arrivals.
For the remaining 1-5%, schedule periodic full refreshes.

Common windows by data type:
  - Web events: 1 day (usually real-time)
  - Transactions: 3 days (bank processing delays)
  - Orders: 3-5 days (manual entry, corrections)
  - Financial close data: 7+ days (month-end adjustments)


LAYERED REFRESH STRATEGY

For outliers that arrive weeks or months late:

Routine runs (hourly/daily):
  dbt run --select this_model
  Uses the 3-day lookback, catches 95%+ of data

Weekly full refresh:
  dbt run --select this_model --full-refresh
  Catches any records that slipped through
  Schedule in your orchestrator for off-peak hours
*/
