# Source Configuration

Sources define your raw data tables and enable freshness monitoring. Properly configured sources catch upstream issues before they affect downstream models.

## Why Sources Matter for Optimization

1. **Freshness checks** - Know immediately when source data stops arriving
2. **Lineage tracking** - Understand dependencies from raw data to final models
3. **Documentation** - Central place for source table metadata

## Freshness Configuration

Source freshness compares a timestamp column against expected update frequency:

```yaml
sources:
  - name: raw_ecommerce
    database: raw
    schema: ecommerce
    freshness:
      warn_after: {count: 12, period: hour}
      error_after: {count: 24, period: hour}
    loaded_at_field: _etl_loaded_at
    tables:
      - name: orders
      - name: customers
```

Run freshness checks:
```bash
dbt source freshness
```

## Freshness Best Practices

### Set Appropriate Thresholds

Match thresholds to your data's actual update frequency:

| Source Update Cadence | Warn After | Error After |
|----------------------|------------|-------------|
| Real-time / hourly   | 2 hours    | 4 hours     |
| Daily                | 36 hours   | 48 hours    |
| Weekly               | 8 days     | 10 days     |

### Use Table-Level Overrides

Different tables may have different SLAs:

```yaml
sources:
  - name: raw_ecommerce
    freshness:
      warn_after: {count: 24, period: hour}
    tables:
      - name: orders
        # Orders are critical - tighter SLA
        freshness:
          warn_after: {count: 6, period: hour}
          error_after: {count: 12, period: hour}
      - name: product_catalog
        # Catalog updates weekly
        freshness:
          warn_after: {count: 8, period: day}
```

### Filter Freshness Checks

For tables with partitions or late-arriving data:

```yaml
tables:
  - name: events
    loaded_at_field: event_timestamp
    freshness:
      warn_after: {count: 4, period: hour}
      filter: event_date >= current_date() - 1
```

## Files in This Folder

- `sources_example.yml` - Complete source configuration with freshness
- `source_freshness_report.sql` - Query to analyze freshness history
