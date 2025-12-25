/*
models/marts/fct_order_items.sql

Incremental materialization example

Use incremental when:
  - Table is large (10M+ rows)
  - Less than 30% of data changes between runs
  - There's a reliable date/timestamp column for filtering
  - The transformation is expensive enough to justify complexity

This order items fact table grows by ~50k rows daily but has
50M+ historical rows. Rebuilding everything hourly is wasteful.
Incremental processes only recent data.

IMPORTANT: This model demonstrates all 4 required components:
  1. unique_key - for upsert behavior
  2. Date filter in is_incremental() block - for partition pruning
  3. Lookback window - for late-arriving data
  4. Merge strategy - for handling conflicts (implicit with unique_key)
*/

{{ config(
    materialized='incremental',
    unique_key='order_item_id',
    
    -- Cluster on commonly filtered columns for better query performance
    cluster_by=['order_date', 'product_category']
) }}

with source_items as (
    select * from {{ source('sales', 'order_items') }}
),

orders as (
    select order_id, customer_id, order_status
    from {{ ref('stg_orders') }}
),

products as (
    select product_id, product_name, category as product_category
    from {{ ref('stg_products') }}
)

select
    -- Surrogate key for the fact table
    {{ dbt_utils.generate_surrogate_key(['si.order_id', 'si.line_item_number']) }} 
        as order_item_id,
    
    si.order_id,
    si.line_item_number,
    o.customer_id,
    si.product_id,
    
    -- Product attributes for easier querying
    p.product_name,
    p.product_category,
    
    -- Measures
    si.quantity,
    si.unit_price,
    si.quantity * si.unit_price as line_total,
    si.discount_amount,
    (si.quantity * si.unit_price) - coalesce(si.discount_amount, 0) as net_line_total,
    
    -- Date fields
    si.order_date,
    si.shipped_date,
    
    -- Order status from parent order
    o.order_status,
    
    -- Metadata
    si.created_at,
    si.updated_at

from source_items si
left join orders o on si.order_id = o.order_id
left join products p on si.product_id = p.product_id

{% if is_incremental() %}
    /*
    COMPONENT 2: Date filter for partition pruning
    COMPONENT 3: 3-day lookback for late-arriving data
    
    This is what makes it actually incremental. Without this block,
    dbt scans the entire source table on every run.
    
    The 3-day lookback catches orders that were:
      - Entered retroactively
      - Delayed in upstream processing
      - Corrected after initial entry
    
    Adjust the lookback window based on your data patterns.
    Query diagnostic-queries/late_arriving_data.sql to determine
    the right window for your data.
    */
    where si.order_date >= (
        select dateadd(day, -3, max(order_date)) 
        from {{ this }}
    )
{% endif %}
