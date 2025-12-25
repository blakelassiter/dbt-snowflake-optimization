# Common Development Workflows

Patterns for typical dbt development tasks.

## Starting Work on a Model

```bash
# 1. Build the model and its downstream dependencies
dbt run --select my_model+

# 2. Run tests on the model
dbt test --select my_model

# 3. If you need fresh upstream data, build that first
dbt run --select +my_model
```

## Iterating on a Model

When actively developing, run just the model (not downstream):

```bash
# Fast iteration - just this model
dbt run --select my_model

# Once the logic is right, verify downstream isn't broken
dbt run --select my_model+
```

## Adding a New Model

```bash
# 1. Build the new model
dbt run --select new_model

# 2. Run tests
dbt test --select new_model

# 3. Verify it builds correctly with fresh upstream data
dbt run --select +new_model

# 4. Check downstream compatibility (if anything depends on it)
dbt run --select new_model+
```

## Debugging a Failed Production Run

```bash
# 1. Build just the failed model to reproduce
dbt run --select failed_model

# 2. If it depends on something that might have bad data
dbt run --select +failed_model

# 3. Run with verbose logging
dbt --debug run --select failed_model
```

## Refreshing Specific Sources

When upstream source data changes and you need to propagate:

```bash
# Everything that depends on a source
dbt run --select source:raw.orders+

# Multiple sources
dbt run --select source:raw.orders+ source:raw.customers+
```

## Pre-PR Validation

Before opening a pull request:

```bash
# 1. Run your changed models + downstream
dbt run --select my_model+

# 2. Run all tests on affected models
dbt test --select my_model+

# 3. Compile to check for SQL errors without running
dbt compile --select my_model+

# 4. Check documentation is current
dbt docs generate --select my_model+
```

## CI/CD Patterns

Using state-based selection for efficient CI:

```bash
# Only build models that changed
dbt run --select state:modified+ --state ./previous-manifest

# Run tests on changed models
dbt test --select state:modified+ --state ./previous-manifest
```

Requires storing the manifest.json from the last successful run.

## Full Refresh for Incremental Models

When incremental models need a complete rebuild:

```bash
# Single model
dbt run --select my_incremental_model --full-refresh

# All incremental models with a tag
dbt run --select tag:incremental --full-refresh

# Careful: this rebuilds everything, use selectively
dbt run --full-refresh  # Don't do this casually
```

## Testing in Isolation

To test a model without affecting others:

```bash
# Build to a different schema
dbt run --select my_model --target dev_sandbox

# Or use schema override
dbt run --select my_model --vars '{"schema_suffix": "_test"}'
```

## Folder-Based Development

When working on a specific area:

```bash
# All staging models
dbt run --select staging.*

# All finance mart models
dbt run --select marts.finance.*

# Staging + what depends on it
dbt run --select staging.*+
```

## Team Aliases

Add to your shell profile for quick access:

```bash
# ~/.bashrc or ~/.zshrc

# Quick model run
alias dbt-m='dbt run --select'

# Model + downstream
alias dbt-md='dbt run --select'
dbt-md() { dbt run --select "$1+"; }

# Full chain
alias dbt-chain='dbt run --select'
dbt-chain() { dbt run --select "+$1+"; }

# Run + test
dbt-rt() { dbt run --select "$1+" && dbt test --select "$1+"; }
```
