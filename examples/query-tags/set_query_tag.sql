/*
Dynamic Query Tag Macro for dbt + Snowflake

This macro overrides dbt's default set_query_tag behavior to attach
rich metadata to every query. The metadata helps with cost attribution
and performance analysis.

Place this file in your macros/ directory.

The query tag is set as a JSON object containing:
- model: The model name
- materialized: The materialization type (view, table, incremental)
- project: The dbt project name
- target: The target environment (dev, prod)
- invocation_id: Unique ID for this dbt run (groups related queries)
- is_incremental: Whether this is an incremental run (not full refresh)

Usage:
  After adding this macro, all queries will automatically include metadata.
  No additional configuration needed.

Query the results:
  SELECT
      try_parse_json(query_tag):model::string as model_name,
      try_parse_json(query_tag):materialized::string as materialization,
      count(*) as run_count
  FROM snowflake.account_usage.query_history
  WHERE query_tag LIKE '{%'
  GROUP BY 1, 2;
*/

{% macro set_query_tag() -%}
    {% set original_query_tag = config.get('query_tag') %}
    
    {% if model is defined %}
        {# Build metadata object for models #}
        {% set query_tag_json = {
            'model': model.name,
            'materialized': config.get('materialized', 'view'),
            'project': project_name,
            'target': target.name,
            'invocation_id': invocation_id,
            'is_incremental': flags.FULL_REFRESH == false and config.get('materialized') == 'incremental'
        } %}
        
        {# Add original query_tag if one was set in config #}
        {% if original_query_tag %}
            {% do query_tag_json.update({'user_tag': original_query_tag}) %}
        {% endif %}
        
        {% set new_query_tag = tojson(query_tag_json) %}
    {% else %}
        {# For non-model queries (seeds, snapshots, hooks) #}
        {% set new_query_tag = original_query_tag or project_name %}
    {% endif %}
    
    {% set set_query_tag_sql %}
        alter session set query_tag = '{{ new_query_tag }}';
    {% endset %}
    
    {% do run_query(set_query_tag_sql) %}
    
    {{ return(original_query_tag) }}
{%- endmacro %}


{% macro unset_query_tag(original_query_tag) -%}
    /*
    Resets the query tag to its original value after model execution.
    Called automatically by dbt after each model completes.
    */
    {% if original_query_tag %}
        {% set set_query_tag_sql %}
            alter session set query_tag = '{{ original_query_tag }}';
        {% endset %}
    {% else %}
        {% set set_query_tag_sql %}
            alter session unset query_tag;
        {% endset %}
    {% endif %}
    
    {% do run_query(set_query_tag_sql) %}
{%- endmacro %}
