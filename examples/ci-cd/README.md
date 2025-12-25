# CI/CD Configuration

Continuous integration for dbt catches issues before they reach production and reduces wasted compute by building only what changed.

## Slim CI Basics

The `state:modified` selector compares your current code against a previous state (usually production) and builds only what changed:

```bash
# Build only modified models and their downstream dependencies
dbt build --select state:modified+
```

This can reduce CI build times from 30 minutes to 2 minutes on large projects.

## How state:modified Works

dbt compares `manifest.json` files between environments:
1. Your production job generates a manifest after each run
2. CI jobs download the production manifest
3. dbt compares the manifests to find differences
4. Only modified models (and their children) are built

Changes that trigger rebuilds:
- SQL file modifications
- Config changes (materialization, schema, etc.)
- Macro changes that affect the model
- Upstream model changes (with `+` suffix)

## Essential CI Commands

```bash
# Modified models + downstream
dbt build --select state:modified+

# With deferral to production for unmodified upstream
dbt build --select state:modified+ --defer --state ./prod-artifacts

# Fail fast on first error
dbt build --select state:modified+ --fail-fast

# Clone incrementals first (for accurate testing)
dbt clone --select state:modified+,config.materialized:incremental,state:old
dbt build --select state:modified+
```

## State Selection Options

| Selector | Description |
|----------|-------------|
| `state:modified` | Models with code or config changes |
| `state:modified+` | Modified models + downstream dependencies |
| `+state:modified` | Modified models + upstream dependencies |
| `state:new` | Models that don't exist in comparison state |
| `state:old` | Models that exist in comparison but not current |

More specific selectors (dbt 1.6+):
- `state:modified.body` - SQL changes only
- `state:modified.configs` - Config changes only

## Files in This Folder

- `slim_ci.md` - Detailed Slim CI setup guide
- `github_actions_pr.yml` - GitHub Actions workflow for PR checks
- `github_actions_deploy.yml` - GitHub Actions workflow for production deployment
