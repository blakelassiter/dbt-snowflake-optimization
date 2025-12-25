/*
models/staging/stg_product_categories.sql

View materialization example

Use views when:
  - Data is small (under 100k rows typically)
  - Source data changes frequently and staleness matters
  - Downstream models need current-as-of-query results
  - The transformation is simple (filters, renames, type casts)

Trade-off: Every downstream query re-executes this logic.
That's fine for small reference tables, expensive for large ones.
*/

{{ config(
    materialized='view'
) }}

/*
Product categories change infrequently and the table is small.
View ensures downstream queries always see current mappings
without requiring a dbt run after someone updates a category.
*/

select
    category_id,
    category_name,
    parent_category_id,
    
    -- Standardize the display name format
    initcap(trim(category_name)) as category_display_name,
    
    -- Flag for active categories
    case 
        when status = 'A' then true 
        else false 
    end as is_active,
    
    created_at,
    updated_at

from {{ source('catalog', 'product_categories') }}

-- Only include categories that have been reviewed
where reviewed_date is not null
