# dbt + Snowflake Optimization

Practical patterns and diagnostic queries for reducing dbt + Snowflake costs. Based on real optimization work that achieved 60% cost reduction on production data pipelines.

This repository contains runnable code examples, not just documentation. Everything here has been tested in production environments.

## What's Here

```
├── examples/
│   ├── materialization/       # View vs table vs incremental decisions
│   ├── incremental-patterns/  # The 4 components of working incremental models
│   ├── query-optimization/    # SQL patterns that reduce compute
│   ├── warehouse-config/      # dbt_project.yml configurations
│   ├── development-workflows/ # Selector patterns and dev environment setup
│   ├── query-tags/            # Trace dbt models in Snowflake query history
│   ├── macros/                # Reusable utility macros
│   ├── testing/               # Test configuration patterns
│   ├── sources/               # Source freshness configuration
│   └── ci-cd/                 # Slim CI and GitHub Actions workflows
├── diagnostic-queries/        # Snowflake queries to find optimization opportunities
├── sample-data/              # Scripts to generate test data
└── docs/                     # Troubleshooting, common mistakes, reference guides
```

## Quick Start

**Find your most expensive models:**

```sql
SELECT 
    query_text,
    total_elapsed_time / 1000 / 60 as minutes,
    bytes_scanned / 1e9 as gb_scanned,
    warehouse_name
FROM snowflake.account_usage.query_history
WHERE start_time >= current_date() - 30
    AND query_text LIKE '%CREATE%TABLE%'
ORDER BY total_elapsed_time DESC
LIMIT 20;
```

**Check if your incremental models are actually incremental:**

```sql
SELECT 
    query_text,
    bytes_scanned / 1e9 as gb_scanned,
    rows_produced,
    total_elapsed_time / 1000 as seconds
FROM snowflake.account_usage.query_history
WHERE query_text LIKE '%my_incremental_model%'
    AND start_time >= current_date() - 7
ORDER BY start_time DESC;
```

If `bytes_scanned` equals your full table size on every run, the model isn't pruning partitions effectively.

## The 4 Decisions That Matter

Most dbt + Snowflake costs trace back to four decision points:

| Decision | Potential Impact | Complexity |
|----------|------------------|------------|
| Materialization strategy | 80-95% per model | Low |
| Incremental model design | 85-90% per model | Medium |
| Development workflows | 95%+ dev compute | Low |
| Warehouse sizing | 40-50% overall | Low |

The examples in this repo cover each of these.

## Materialization Decision Framework

Not every large table needs to be incremental. Not every small table should be a view.

| Row Count | Change Rate | Build Time | Recommendation |
|-----------|-------------|------------|----------------|
| Under 1M | Any | Under 30 sec | View or table |
| 1-10M | Any | Any | Table |
| Over 10M | Under 30% | Any | Incremental |
| Over 10M | Over 50% | Any | Table |

See `examples/materialization/` for implementation patterns.

## Incremental Models - The 4 Required Components

Many "incremental" models aren't actually incremental. They have the config but scan the full table every run.

A working incremental model needs:

1. **Unique key** - identifies records for upsert
2. **Date filter** - enables partition pruning
3. **Lookback window** - catches late-arriving data
4. **Merge strategy** - handles update conflicts

Miss any one and you're paying for full table scans. See `examples/incremental-patterns/` for each component.

## Development Workflow Savings

```bash
# This wastes compute
dbt run

# This doesn't
dbt run --select my_model+
```

Running `dbt run` during development means rebuilding 100 models when you changed 1. The `--select` flag with the `+` suffix builds your model and its downstream dependencies only.

See `examples/development-workflows/` for selector patterns.

## Query Tags for Cost Attribution

Query tags let you trace dbt models back to their Snowflake query history. Essential for understanding which models drive costs.

```sql
-- Cost by model (last 30 days)
SELECT 
    try_parse_json(query_tag):model::string as model_name,
    sum(total_elapsed_time) / 1000 / 60 as total_minutes
FROM snowflake.account_usage.query_history
WHERE query_tag LIKE '{%'
GROUP BY 1
ORDER BY 2 DESC;
```

See `examples/query-tags/` for the `set_query_tag` macro and analysis queries.

## CI/CD with Slim CI

Build only what changed in pull requests:

```bash
# Download production manifest, then:
dbt build --select state:modified+ --defer --state ./prod-state
```

This can reduce CI build times from 30 minutes to 2 minutes. See `examples/ci-cd/` for GitHub Actions workflows and setup guides.

## Troubleshooting

When something goes wrong, check `docs/troubleshooting.md` for:
- Incremental models that aren't actually incremental
- Sudden cost increases
- Slow models
- Warehouse queuing

And `docs/common_mistakes.md` for anti-patterns to avoid.

## Full Article Series

These examples come from an 8-part series with full context and explanations:

**[Complete Series Index](https://medium.com/@blakelassiter/the-complete-guide-to-dbt-snowflake-optimization-8-part-series-af4b2a1f213e)** — Overview and reading guide

1. [How I Cut Our dbt + Snowflake Costs by 60%](https://medium.com/@blakelassiter/how-i-cut-our-dbt-snowflake-costs-by-60-fc8e946c4b37)
2. [4 Decisions That Control 90% of Your dbt + Snowflake Costs](https://medium.com/@blakelassiter/4-decisions-that-control-90-of-your-dbt-snowflake-costs-299113dc408c)
3. [dbt Materialization Strategy: Why Most Models Are Wrong](https://medium.com/@blakelassiter/dbt-materialization-strategy-why-most-models-are-wrong-094848667a09)
4. [dbt Incremental Models: The 4 Components Most Teams Miss](https://medium.com/@blakelassiter/dbt-incremental-models-the-4-components-most-teams-miss-78a8572511e8)
5. [dbt Development Workflow: How We Cut Build Time by 98%](https://medium.com/@blakelassiter/dbt-development-workflow-how-we-cut-build-time-by-98-5eb25b682116)
6. [5 SQL Patterns for Faster Snowflake Queries in dbt](https://medium.com/@blakelassiter/5-sql-patterns-for-faster-snowflake-queries-in-dbt-fa3d8c695322)
7. [Snowflake Warehouse Sizing for dbt: A Practical Guide](https://medium.com/@blakelassiter/snowflake-warehouse-sizing-for-dbt-a-practical-guide-2f674a720f29)
8. [Building dbt Optimization Into Team Culture](https://medium.com/@blakelassiter/building-dbt-optimization-into-team-culture-514fa64409c2)

**[Free Essentials Guide + Quick Reference Card](https://blakelassiter.gumroad.com/l/dbt-snowflake-optimization)** — Condensed PDF reference

## Contributing

Found an issue or have a pattern to add? PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT - see [LICENSE](LICENSE)

## About
Maintained by [Blake Lassiter](https://www.linkedin.com/in/blakelassiter/) - Principal Data Architect & Engineer focused on modern data stack optimization and production AI systems.
