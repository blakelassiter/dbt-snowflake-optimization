# Warehouse Configuration

Warehouse sizing has an outsized impact on cost. A dbt run that takes 60 minutes on a Small warehouse doesn't take 30 minutes on a Medium - it might take 45 minutes at 2x the cost.

## The Key Insight

Bigger warehouses don't scale linearly with performance. Cost doubles with each size increment. Performance improvement is often 20-40%, not 100%.

| Size | Credits/Hour | Typical dbt Use |
|------|-------------|----------------|
| X-Small | 1 | Testing, tiny reference tables |
| Small | 2 | Staging models, development |
| Medium | 4 | Standard production workloads |
| Large | 8 | Heavy transformations (if proven necessary) |

## Files in This Folder

| File | Purpose |
|------|---------|
| `dbt_project_example.yml` | Warehouse assignment by model folder |
| `thread_configuration.md` | How threads and warehouse size interact |
| `model_level_override.sql` | Setting warehouse for specific models |

## Right-Sizing by Workload

Different model types have different compute needs. Running everything on the same warehouse wastes money.

**Staging models:** Simple column selection, type casting, filters. Small warehouse is fine.

**Intermediate models:** Moderate joins and aggregations. Medium warehouse typically.

**Heavy analytics:** Complex multi-table joins, window functions, large aggregations. Consider Medium or Large, but test first.

## The Math

**Before (everything on Medium):**
- 100 models, 45 min runtime
- 4 credits/hour = 3 credits per run
- 24 runs/day = 72 credits/day

**After (right-sized):**
- 50 staging on Small: 15 min @ 2 credits/hr = 0.5 credits
- 30 intermediate on Medium: 10 min @ 4 credits/hr = 0.67 credits  
- 20 heavy on Medium: 8 min @ 4 credits/hr = 0.53 credits
- Per run: ~1.7 credits
- 24 runs/day = ~41 credits/day

**Savings: ~40%**

## When to Upsize

Valid reasons to use a larger warehouse:
- Hard SLA requirements (reports must finish by 6am)
- Time-critical windows (month-end close)
- After SQL optimization is exhausted
- High parallelism opportunity (many independent models)

Invalid reasons:
- "This model is slow" (optimize the SQL first)
- "We've always used Large"
- "Small feels too small"
