/*
examples/incremental-patterns/surrogate_key.sql

Surrogate key pattern for incremental models

When your natural key is composite (multiple columns), you can
create a single surrogate key that combines them. This gives you:
  - Simpler merge operations (single column match)
  - Consistent key format across tables
  - Smaller index footprint

dbt_utils provides generate_surrogate_key() for this purpose.
*/

{{ config(
    materialized='incremental',
    
    -- Single column key, even though it's derived from multiple source columns
    unique_key='order_item_key'
) }}

select
    -- Create a single surrogate key from the composite natural key
    -- This generates a consistent hash from the input columns
    {{ dbt_utils.generate_surrogate_key(['order_id', 'line_item_number']) }} 
        as order_item_key,
    
    -- Keep the natural key columns for reference
    order_id,
    line_item_number,
    
    -- Rest of the columns
    product_id,
    quantity,
    unit_price,
    quantity * unit_price as line_total,
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
HOW generate_surrogate_key WORKS

It concatenates the column values with a delimiter, then hashes them.
Roughly equivalent to:
  md5(coalesce(cast(order_id as varchar), '') || '-' || 
      coalesce(cast(line_item_number as varchar), ''))

The result is a deterministic string that:
  - Is always the same for the same input values
  - Is different for different input values (extremely high probability)
  - Handles nulls gracefully


WHEN TO USE SURROGATE KEYS VS COMPOSITE KEYS

Use surrogate keys when:
  - Natural key has 3+ columns
  - You need consistent key format across tables
  - The key columns have different data types
  - You're joining to fact tables frequently

Use composite keys when:
  - Natural key is just 2 columns
  - Merge performance isn't a concern
  - You want to avoid adding a column

Both work. Surrogate keys scale better for complex scenarios.


IMPORTANT: CONSISTENCY

If you use a surrogate key, generate it the same way everywhere.
This staging model creates the key:

  {{ dbt_utils.generate_surrogate_key(['order_id', 'line_item_number']) }}

Any downstream model that needs to join should use the same key,
not re-generate it from the source columns.
*/
