# Selector Patterns

The `--select` flag is more powerful than most teams realize. This is a complete reference.

## Basic Patterns

| Pattern | Meaning |
|---------|---------|
| `my_model` | Just this model |
| `my_model+` | Model + everything downstream |
| `+my_model` | Everything upstream + model |
| `+my_model+` | Full dependency tree |

## Folder Selection

| Pattern | Meaning |
|---------|---------|
| `staging.*` | All models in staging/ folder |
| `marts.finance.*` | All models in marts/finance/ folder |
| `path:models/staging` | Alternative syntax |

## Tag Selection

| Pattern | Meaning |
|---------|---------|
| `tag:daily` | Models tagged with 'daily' |
| `tag:critical+` | Tagged models + downstream |
| `+tag:finance` | Upstream of tagged models + tagged models |

Add tags to models in the config:

```sql
{{ config(
    materialized='table',
    tags=['daily', 'finance']
) }}
```

## Source Selection

| Pattern | Meaning |
|---------|---------|
| `source:raw.orders` | Models that reference this source |
| `source:raw.orders+` | Source references + downstream |
| `source:raw.*` | Models referencing any table in 'raw' |

## State-Based Selection (requires manifest)

| Pattern | Meaning |
|---------|---------|
| `state:modified` | Models with code changes |
| `state:modified+` | Modified models + downstream |
| `state:new` | Newly added models |

Requires passing `--state` flag with path to previous manifest:
```bash
dbt run --select state:modified+ --state ./target-previous
```

## Exposure Selection

| Pattern | Meaning |
|---------|---------|
| `+exposure:weekly_report` | Everything upstream of an exposure |

## Combining Selectors

**Union (OR):** Space-separated
```bash
dbt run --select model_a model_b model_c
```

**Intersection (AND):** Comma-separated
```bash
dbt run --select tag:daily,staging.*
# Models that have the 'daily' tag AND are in staging folder
```

**Exclusion:** Use `--exclude`
```bash
dbt run --select staging.* --exclude staging.stg_legacy_orders
# All staging models except stg_legacy_orders
```

## Depth Limiting

| Pattern | Meaning |
|---------|---------|
| `my_model+1` | Model + 1 level downstream |
| `1+my_model` | 1 level upstream + model |
| `1+my_model+1` | 1 level each direction |

```bash
# Just immediate children, not grandchildren
dbt run --select my_model+1
```

## Practical Examples

**Working on a staging model:**
```bash
# Build the staging model and everything that depends on it
dbt run --select stg_orders+
```

**Deploying changes to a mart:**
```bash
# Build everything upstream first, then the mart
dbt run --select +dim_customers
```

**Testing a change to intermediate logic:**
```bash
# Full dependency tree to see all impacts
dbt run --select +int_order_items+
```

**Daily production run for specific models:**
```bash
dbt run --select tag:daily
```

**CI/CD for changed models:**
```bash
dbt run --select state:modified+ --state ./target-previous
```

**Refresh a specific source's downstream:**
```bash
dbt run --select source:salesforce.accounts+
```

## Team Conventions

Document your team's common patterns. Examples:

```bash
# Recommended patterns for our project
alias dbt-staging="dbt run --select staging.*"
alias dbt-marts="dbt run --select marts.*"
alias dbt-daily="dbt run --select tag:daily"
```

Add to project README so everyone uses consistent approaches.
