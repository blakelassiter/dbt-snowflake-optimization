/*
examples/query-optimization/column_selection.sql

Select specific columns instead of SELECT *

Snowflake is columnar - data is stored by column, not by row.
When you SELECT *, Snowflake reads every column from storage.
When you select 5 specific columns, it only reads those 5.

On wide tables (50+ columns), this difference is massive.
*/


/* ANTI-PATTERN: SELECT * on a wide table

   user_profiles has 150 columns: preferences, settings, metadata, etc.
   This query reads all 150 columns from storage.
*/

select *
from user_profiles
where subscription_tier = 'premium'


/* BETTER: Select only needed columns

   We only need 5 columns for this report.
   Snowflake reads ~3% of the data.
*/

select
    user_id,
    email,
    signup_date,
    subscription_tier,
    last_login_date
from user_profiles
where subscription_tier = 'premium'


/*
IMPACT EXAMPLE

Table: 10M rows, 150 columns, 50GB storage

SELECT * reads ~50GB
SELECT 5 columns reads ~1.5GB

That's 97% less I/O. Query time drops from 45 seconds to 3 seconds.


WHEN SELECT * IS ACCEPTABLE

Staging models often legitimately pass through all columns:

-- stg_orders.sql
select * from {{ source('raw', 'orders') }}

This is fine because:
  1. Staging models are intentionally passthrough
  2. You want all source columns available downstream
  3. The model is often a view anyway

The problem is SELECT * in intermediate or mart models where you
genuinely don't need all columns.


CODE REVIEW GUIDELINE

Staging models: SELECT * is acceptable
Intermediate/mart models: Should explicitly list columns

Exception: If an intermediate model needs to pass through all columns
from a staging model, document why in a comment.


PRACTICAL TIP

When selecting from a wide table and unsure which columns you need,
start with the columns you know and add more as needed.
Don't start with * and remove later - you'll forget.

Instead of:
  select * from big_table  -- "I'll pare it down later"

Do:
  select
      id,
      created_at,
      status
      -- add columns as needed
  from big_table
*/
