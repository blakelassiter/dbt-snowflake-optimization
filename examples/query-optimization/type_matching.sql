/*
examples/query-optimization/type_matching.sql

Match join key data types

When join keys have different types, Snowflake casts every row
at runtime. It can't use partition metadata for optimization.
Sometimes it falls back to slower join algorithms.

The fix is simple: standardize types in staging models.
*/


/* ANTI-PATTERN: Type mismatch on join

   orders.product_id is INTEGER
   products.product_id is VARCHAR
   Snowflake casts every row during the join.
*/

select 
    o.order_id,
    o.product_id,
    p.product_name
from orders o
left join products p
    on cast(o.product_id as varchar) = p.product_id  -- Runtime casting


/* BETTER: Fix types in staging

   Standardize the type once in staging. 
   All downstream joins are clean.
*/

-- stg_orders.sql
select
    order_id,
    cast(product_id as varchar) as product_id,  -- Standardize here
    customer_id,
    order_total,
    order_date
from {{ source('raw', 'orders') }}

-- stg_products.sql  
select
    product_id,  -- Already varchar
    product_name,
    category
from {{ source('raw', 'products') }}

-- Now downstream models join cleanly:
select 
    o.order_id,
    o.product_id,
    p.product_name
from {{ ref('stg_orders') }} o
left join {{ ref('stg_products') }} p
    on o.product_id = p.product_id  -- Both VARCHAR, no casting


/*
HOW TO FIND TYPE MISMATCHES

Check columns used in joins across your sources:
*/

select 
    table_name,
    column_name, 
    data_type
from information_schema.columns 
where column_name like '%_id'
    and table_schema = 'YOUR_SCHEMA'
order by column_name, table_name;

/*
Look for the same column name with different types across tables.
Common offenders:
  - IDs that are INTEGER in some tables, VARCHAR in others
  - Dates that are DATE in some places, TIMESTAMP in others
  - Booleans stored as VARCHAR ('Y'/'N') vs BOOLEAN


TYPE STANDARDIZATION RULES

Pick one type per concept and use it everywhere:

IDs: VARCHAR (handles numeric and alphanumeric, most flexible)
Dates: DATE (not TIMESTAMP unless you need time component)
Timestamps: TIMESTAMP_NTZ or TIMESTAMP_TZ (be consistent)
Booleans: BOOLEAN (convert Y/N/1/0 in staging)
Money: NUMBER(38,2) or similar fixed precision


WHY VARCHAR FOR IDS?

Some source systems use numeric IDs. Others use UUIDs or alphanumeric.
VARCHAR handles both. Standardizing to VARCHAR in staging means:
  - No casting surprises when a new source uses different ID format
  - Consistent behavior across all models
  - Small storage overhead (Snowflake compresses well)
*/
