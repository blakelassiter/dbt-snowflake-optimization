# Code Review Checklist

Use this checklist when reviewing dbt model pull requests.

## Materialization

- [ ] Is the materialization type appropriate for the table size?
- [ ] If over 10M rows, should this be incremental?
- [ ] If incremental, are all 4 components present?
  - [ ] Unique key defined
  - [ ] Date filter in `{% if is_incremental() %}` block
  - [ ] Lookback window for late-arriving data
  - [ ] Appropriate merge strategy

## Incremental Models

- [ ] Is the `unique_key` actually unique?
- [ ] Does the date filter column align with partition boundaries?
- [ ] Is the lookback window appropriate for this data source?
- [ ] Will `bytes_scanned` be significantly lower than full table size?

## SQL Efficiency

- [ ] Are filters applied before joins (not after)?
- [ ] Is `SELECT *` avoided (except in staging models)?
- [ ] Are join key data types matched?
- [ ] Could window functions be replaced with `GROUP BY`?
- [ ] Is `QUALIFY` used for deduplication (vs ROW_NUMBER subquery)?

## Warehouse Configuration

- [ ] Is the model assigned to an appropriate warehouse?
- [ ] Should this model override the folder default?
- [ ] For heavy models, is there a Large warehouse option?

## Development Impact

- [ ] Can this be tested with `--select` patterns?
- [ ] Is there a dev subset filter using `target.name`?
- [ ] Are there comments explaining non-obvious logic?

## General

- [ ] Does the model name follow conventions?
- [ ] Are there tests for critical columns?
- [ ] Is there documentation for the model?
- [ ] Does the model have appropriate tags?

---

## Quick Questions to Ask

1. **"How big will this table be in 6 months?"**
   - Informs materialization choice

2. **"How often does the source data change?"**
   - Determines if incremental is worth the complexity

3. **"Can this filter be pushed earlier?"**
   - Reduces join and scan costs

4. **"Do downstream queries need all these columns?"**
   - Avoids unnecessary `SELECT *`

5. **"What happens if this runs twice with the same data?"**
   - Tests incremental idempotency
