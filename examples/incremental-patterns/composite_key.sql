/*
examples/incremental-patterns/composite_key.sql

Composite unique key pattern

When no single column uniquely identifies a record, you need
multiple columns together. Common examples:
  - Order + line item number
  - Date + account + transaction type
  - User + session + event sequence

dbt supports this with a list syntax for unique_key.
*/

{{ config(
    materialized='incremental',
    
    -- List syntax for composite keys
    unique_key=['order_id', 'line_item_number']
) }}

select
    order_id,
    line_item_number,
    product_id,
    quantity,
    unit_price,
    line_total,
    order_date,
    updated_at
from {{ source('sales', 'order_line_items') }}

{% if is_incremental() %}
    where order_date >= (
        select dateadd(day, -3, max(order_date))
        from {{ this }}
    )
{% endif %}


/*
HOW SNOWFLAKE HANDLES COMPOSITE KEYS

The merge statement becomes:

  MERGE INTO target t
  USING source s
  ON t.order_id = s.order_id 
     AND t.line_item_number = s.line_item_number
  WHEN MATCHED THEN UPDATE ...
  WHEN NOT MATCHED THEN INSERT ...

Performance note: Composite keys are slightly less efficient than
single-column keys because the merge must match on multiple columns.
For most cases this is negligible. For very large tables with complex
keys, consider creating a surrogate key instead (see surrogate_key.sql).


COMMON COMPOSITE KEY PATTERNS

Fact tables with line items:
  unique_key=['order_id', 'line_number']
  unique_key=['invoice_id', 'line_item_id']

Time-series with multiple dimensions:
  unique_key=['date', 'account_id', 'metric_type']
  unique_key=['timestamp', 'device_id', 'sensor_type']

Slowly changing dimensions (SCD Type 2):
  unique_key=['entity_id', 'valid_from']
*/
