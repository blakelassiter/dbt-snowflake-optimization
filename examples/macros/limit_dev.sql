/*
Dev Environment Limiter Macro

Automatically limits data in development environments to speed up
iteration. Does nothing in production.

Arguments:
  row_limit: Maximum rows to return in dev (integer, default 10000)

Usage:
  SELECT *
  FROM {{ ref('large_source_table') }}
  {{ limit_dev(10000) }}

In dev target: Adds "LIMIT 10000"
In prod target: Adds nothing

Configuration:
  The macro checks target.name against a list of production target names.
  Adjust prod_targets list to match your environment naming.
*/

{% macro limit_dev(row_limit=10000) %}
    {# Define which targets are considered production #}
    {% set prod_targets = ['prod', 'production', 'prd'] %}
    
    {% if target.name | lower not in prod_targets %}
        LIMIT {{ row_limit }}
    {% endif %}
{% endmacro %}


/*
Alternative: Sample-based limiting (percentage)

Use this version to get a random sample rather than first N rows.
Better for preserving data distribution.

{% macro sample_dev(sample_percent=10) %}
    {% set prod_targets = ['prod', 'production', 'prd'] %}
    
    {% if target.name | lower not in prod_targets %}
        SAMPLE ({{ sample_percent }})
    {% endif %}
{% endmacro %}
*/


/*
Alternative: Date-based limiting

Use this version to limit by date range rather than row count.
Better for time-series data.

{% macro date_limit_dev(date_column, days=30) %}
    {% set prod_targets = ['prod', 'production', 'prd'] %}
    
    {% if target.name | lower not in prod_targets %}
        WHERE {{ date_column }} >= current_date() - {{ days }}
    {% endif %}
{% endmacro %}
*/
