# Development Workflows

Development compute can account for 30-40% of total Snowflake spend. It's hidden because it's spread across engineers throughout the day, never showing up as a single line item.

The fix is simple: stop running `dbt run` and start running `dbt run --select model+`.

## The Math

Team of 10 engineers. Each runs dbt 5 times per day while developing. Project has 100 models. Full run takes 20 minutes.

```
10 engineers × 5 runs × 20 minutes = 1,000 minutes daily
```

That's 16.7 hours of compute per day. Just for development.

With selective builds:
```
10 engineers × 5 runs × 20 seconds = 16.7 minutes daily
```

60x reduction in development compute.

## Files in This Folder

| File | Purpose |
|------|---------|
| `selector_patterns.md` | Complete reference for --select syntax |
| `dev_subset.sql` | Limiting data in dev environments |
| `common_workflows.md` | Patterns for typical development tasks |

## Quick Reference

```bash
# Single model
dbt run --select my_model

# Model + downstream (most common for development)
dbt run --select my_model+

# Model + upstream
dbt run --select +my_model

# Model + both directions
dbt run --select +my_model+

# All models in a folder
dbt run --select staging.*

# Models with a tag
dbt run --select tag:daily

# Multiple specific models
dbt run --select model_a model_b model_c
```

The `+` is the key:
- `my_model+` = my_model and everything downstream
- `+my_model` = everything upstream and my_model
- `+my_model+` = full dependency tree in both directions

## The Velocity Benefit

Beyond compute savings, selective builds improve development velocity.

20-second feedback loops vs 20-minute feedback loops:
- Engineers stay in flow state
- Faster iteration means better solutions
- Less context switching
- More experiments tried

The compute savings are nice. The productivity gain is bigger.
