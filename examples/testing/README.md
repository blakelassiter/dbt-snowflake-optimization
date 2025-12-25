# Testing Configuration

Properly configured tests catch data issues early and validate that optimization changes haven't broken anything.

## Essential Tests for Optimization

### 1. Primary Key Tests

Every model should test its primary key for uniqueness and completeness:

```yaml
models:
  - name: fct_orders
    columns:
      - name: order_id
        data_tests:
          - unique
          - not_null
```

### 2. Incremental Model Validation

For incremental models, test that the unique key is truly unique. Duplicates indicate merge issues:

```yaml
models:
  - name: fct_orders
    columns:
      - name: order_id
        data_tests:
          - unique:
              config:
                where: "order_date >= current_date() - 7"
```

### 3. Referential Integrity

Validate foreign key relationships work correctly:

```yaml
models:
  - name: fct_orders
    columns:
      - name: customer_id
        data_tests:
          - relationships:
              to: ref('dim_customers')
              field: customer_id
```

### 4. Accepted Values

Ensure categorical columns contain expected values:

```yaml
models:
  - name: fct_orders
    columns:
      - name: order_status
        data_tests:
          - accepted_values:
              values: ['pending', 'shipped', 'delivered', 'cancelled']
```

## Test Performance Considerations

### Use the where Config

For large tables, limit tests to recent data:

```yaml
data_tests:
  - unique:
      config:
        where: "created_date >= current_date() - 30"
```

### Tag and Select Tests

Run expensive tests less frequently:

```yaml
data_tests:
  - unique:
      config:
        tags: ['daily']
  - my_expensive_test:
      config:
        tags: ['weekly']
```

```bash
# Daily CI
dbt test --select tag:daily

# Weekly full validation
dbt test
```

## Files in This Folder

- `schema_example.yml` - Complete schema file with test patterns
- `custom_test_incremental.sql` - Validates incremental models work correctly
