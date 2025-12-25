# Sample Data

The examples in this repository use generic table and column names. To test them yourself, you can either:

1. **Adapt to your own data** - Replace table/column names with your actual schemas
2. **Generate sample data** - Use the scripts below to create test tables

## Sample Data Generation

These scripts create simple test tables that match the examples.

### Orders Table

```sql
-- Create a sample orders table
CREATE OR REPLACE TABLE sample_orders AS
SELECT
    seq4() as order_id,
    mod(seq4(), 100000) as customer_id,
    dateadd(day, -mod(seq4(), 365), current_date()) as order_date,
    round(random() * 500 + 10, 2) as order_total,
    case mod(seq4(), 5)
        when 0 then 'pending'
        when 1 then 'processing'
        when 2 then 'shipped'
        when 3 then 'delivered'
        else 'completed'
    end as order_status,
    dateadd(second, seq4(), '2024-01-01'::timestamp) as created_at,
    dateadd(second, seq4() + mod(seq4(), 86400), '2024-01-01'::timestamp) as updated_at
FROM table(generator(rowcount => 1000000));  -- 1M rows
```

### Customers Table

```sql
-- Create a sample customers table
CREATE OR REPLACE TABLE sample_customers AS
SELECT
    seq4() as customer_id,
    'customer_' || seq4() || '@example.com' as email,
    'Company ' || seq4() as company_name,
    case mod(seq4(), 4)
        when 0 then 'starter'
        when 1 then 'standard'
        when 2 then 'growth'
        else 'enterprise'
    end as segment,
    dateadd(day, -mod(seq4(), 1000), current_date()) as created_at
FROM table(generator(rowcount => 100000));  -- 100k rows
```

### Order Items Table (for incremental examples)

```sql
-- Create a sample order_items table
CREATE OR REPLACE TABLE sample_order_items AS
SELECT
    seq4() as order_item_id,
    mod(seq4(), 1000000) as order_id,
    mod(seq4(), 10000) as product_id,
    mod(seq4(), 10) + 1 as line_item_number,
    mod(seq4(), 5) + 1 as quantity,
    round(random() * 100 + 5, 2) as unit_price,
    dateadd(day, -mod(seq4(), 365), current_date()) as order_date,
    dateadd(second, seq4(), '2024-01-01'::timestamp) as created_at
FROM table(generator(rowcount => 5000000));  -- 5M rows
```

### Products Table

```sql
-- Create a sample products table  
CREATE OR REPLACE TABLE sample_products AS
SELECT
    seq4() as product_id,
    'Product ' || seq4() as product_name,
    case mod(seq4(), 5)
        when 0 then 'Electronics'
        when 1 then 'Clothing'
        when 2 then 'Home'
        when 3 then 'Sports'
        else 'Other'
    end as category,
    round(random() * 200 + 10, 2) as base_price
FROM table(generator(rowcount => 10000));  -- 10k rows
```

## Testing Incremental Behavior

To test incremental model behavior:

1. Create the source table
2. Build your incremental model (first run = full load)
3. Insert new rows into the source
4. Build again (should only process new rows)
5. Check `bytes_scanned` in query history

```sql
-- Add new rows to test incremental
INSERT INTO sample_order_items
SELECT
    (SELECT max(order_item_id) FROM sample_order_items) + seq4() as order_item_id,
    mod(seq4(), 1000000) as order_id,
    mod(seq4(), 10000) as product_id,
    mod(seq4(), 10) + 1 as line_item_number,
    mod(seq4(), 5) + 1 as quantity,
    round(random() * 100 + 5, 2) as unit_price,
    current_date() as order_date,  -- Today's date
    current_timestamp() as created_at
FROM table(generator(rowcount => 10000));  -- Add 10k new rows
```

## Cleanup

```sql
DROP TABLE IF EXISTS sample_orders;
DROP TABLE IF EXISTS sample_customers;
DROP TABLE IF EXISTS sample_order_items;
DROP TABLE IF EXISTS sample_products;
```
