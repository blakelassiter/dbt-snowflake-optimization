/*
Lookback Filter Macro

Generates a date filter for incremental models with a configurable
lookback window to catch late-arriving data.

Arguments:
  date_column: The column to filter on (string)
  lookback_days: Number of days to look back (integer, default 3)

Usage:
  {% if is_incremental() %}
  WHERE event_date >= {{ lookback_filter('event_date', 3) }}
  {% endif %}

Output:
  (SELECT max(event_date) - interval '3 days' FROM {{ this }})

Why use this:
  - Consistent lookback logic across all incremental models
  - Easy to adjust lookback period in one place
  - Handles the subquery against {{ this }} correctly
*/

{% macro lookback_filter(date_column, lookback_days=3) %}
    (SELECT max({{ date_column }}) - interval '{{ lookback_days }} days' FROM {{ this }})
{% endmacro %}


/*
Alternative: Fixed date lookback (simpler but less flexible)

Use this version if you want a rolling window from current date
rather than from max date in the table.

{% macro lookback_filter_fixed(lookback_days=3) %}
    current_date() - {{ lookback_days }}
{% endmacro %}
*/
