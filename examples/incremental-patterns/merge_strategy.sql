/*
examples/incremental-patterns/merge_strategy.sql

Merge strategy patterns for incremental models

The incremental_strategy config controls how dbt handles records
that exist in both the new data and the existing table.

Snowflake supports several strategies:
  - merge (default): MERGE statement with UPDATE + INSERT
  - delete+insert: DELETE matching rows, then INSERT new data
  - append: INSERT only, no matching (fastest but creates duplicates)
*/

{{ config(
    materialized='incremental',
    unique_key='event_id',
    
    -- Explicit strategy selection
    -- 'merge' is the default and usually what you want
    incremental_strategy='merge'
) }}

select
    event_id,
    user_id,
    event_type,
    event_properties,
    event_timestamp,
    
    -- Track when we last saw/updated this record
    current_timestamp() as dbt_updated_at
    
from {{ source('analytics', 'events') }}

{% if is_incremental() %}
    where event_timestamp >= (
        select dateadd(day, -3, max(event_timestamp))
        from {{ this }}
    )
{% endif %}


/*
STRATEGY COMPARISON

MERGE (default)
---------------
Best for: Most use cases, especially when records can be updated
How it works: 
  MERGE INTO target USING source ON key_match
  WHEN MATCHED THEN UPDATE SET all_columns = source_values
  WHEN NOT MATCHED THEN INSERT
Pros: Handles updates and inserts in one operation
Cons: Slightly slower than append for pure inserts


DELETE+INSERT
-------------
Best for: When merge is slow or you need to replace entire partitions
How it works:
  DELETE FROM target WHERE key IN (SELECT key FROM source)
  INSERT INTO target SELECT * FROM source
Pros: Can be faster for large batch updates
Cons: Two operations, brief window where data is deleted

Config:
  incremental_strategy='delete+insert'


APPEND
------
Best for: Immutable event streams where records never update
How it works:
  INSERT INTO target SELECT * FROM source
Pros: Fastest option, no key matching overhead
Cons: Creates duplicates if same record is processed twice

Config:
  incremental_strategy='append'
  (don't set unique_key - it's ignored anyway)


WHEN TO USE EACH STRATEGY

merge: Default choice. Records might be updated after initial insert.
       Examples: order status changes, user profile updates

delete+insert: Large batch loads where you're replacing chunks of data.
       Examples: daily file drops, partition-level reloads

append: True immutable events where duplicates are impossible or handled downstream.
       Examples: clickstream events with guaranteed unique IDs,
                 CDC streams with deduplication at source


CONTROLLING WHICH COLUMNS UPDATE

By default, merge updates all columns. To update only specific columns,
use the merge_update_columns config:

{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',
    merge_update_columns=['status', 'updated_at']
) }}

Now only 'status' and 'updated_at' get updated on matching records.
Other columns keep their existing values.
*/
