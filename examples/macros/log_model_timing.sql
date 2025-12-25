/*
Model Timing Logger Macro

Logs messages with timestamps to help identify slow sections
in complex models. Output appears in dbt logs.

Arguments:
  message: Description of current step (string)

Usage:
  {{ log_model_timing('Starting heavy aggregation') }}
  
  WITH aggregated AS (
      SELECT ...
  )
  
  {{ log_model_timing('Aggregation complete') }}

Output in logs:
  [2024-01-15 10:23:45] orders_model: Starting heavy aggregation
  [2024-01-15 10:24:12] orders_model: Aggregation complete

Note:
  This macro only logs during compilation/execution.
  It does not affect the generated SQL or query performance.
*/

{% macro log_model_timing(message) %}
    {% if execute %}
        {% set model_name = model.name if model is defined else 'unknown' %}
        {{ log('[' ~ modules.datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S') ~ '] ' ~ model_name ~ ': ' ~ message, info=True) }}
    {% endif %}
{% endmacro %}


/*
Alternative: Run hooks for start/end timing

For automatic timing of every model without adding macro calls,
use pre and post hooks in dbt_project.yml:

models:
  my_project:
    +pre-hook: "{{ log_model_timing('Starting') }}"
    +post-hook: "{{ log_model_timing('Complete') }}"
*/


/*
Debug logging macro

For verbose debugging that only appears in dev:

{% macro debug_log(message) %}
    {% set prod_targets = ['prod', 'production'] %}
    
    {% if execute and target.name | lower not in prod_targets %}
        {{ log('[DEBUG] ' ~ message, info=True) }}
    {% endif %}
{% endmacro %}
*/
