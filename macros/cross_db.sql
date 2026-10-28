{#
  Small helpers for the few places where BigQuery and DuckDB SQL differ.
  BigQuery is the production target; DuckDB runs the same models locally and in CI.
#}

{# One row per calendar day, column date_day. #}
{% macro date_spine_days(start_date, end_date) %}
    {{ return(adapter.dispatch('date_spine_days')(start_date, end_date)) }}
{% endmacro %}

{% macro default__date_spine_days(start_date, end_date) %}
    select date_day
    from unnest(generate_date_array(date '{{ start_date }}', date '{{ end_date }}', interval 1 day)) as date_day
{% endmacro %}

{% macro duckdb__date_spine_days(start_date, end_date) %}
    select cast(range as date) as date_day
    from range(date '{{ start_date }}', date '{{ end_date }}' + interval 1 day, interval 1 day)
{% endmacro %}

{# ISO day of week: Monday = 1, Sunday = 7. #}
{% macro iso_day_of_week(date_expr) %}
    {{ return(adapter.dispatch('iso_day_of_week')(date_expr)) }}
{% endmacro %}

{% macro default__iso_day_of_week(date_expr) %}
    mod(extract(dayofweek from {{ date_expr }}) + 5, 7) + 1
{% endmacro %}

{% macro duckdb__iso_day_of_week(date_expr) %}
    isodow({{ date_expr }})
{% endmacro %}

{# Full English month name, e.g. January. #}
{% macro month_name(date_expr) %}
    {{ return(adapter.dispatch('month_name')(date_expr)) }}
{% endmacro %}

{% macro default__month_name(date_expr) %}
    format_date('%B', {{ date_expr }})
{% endmacro %}

{% macro duckdb__month_name(date_expr) %}
    strftime({{ date_expr }}, '%B')
{% endmacro %}

{# Exact percentile as a window function, so it can sit next to group-level columns. #}
{% macro percentile_over(expr, fraction, partition_by) %}
    {{ return(adapter.dispatch('percentile_over')(expr, fraction, partition_by)) }}
{% endmacro %}

{% macro default__percentile_over(expr, fraction, partition_by) %}
    percentile_cont({{ expr }}, {{ fraction }}) over (partition by {{ partition_by }})
{% endmacro %}

{% macro duckdb__percentile_over(expr, fraction, partition_by) %}
    quantile_cont({{ expr }}, {{ fraction }}) over (partition by {{ partition_by }})
{% endmacro %}

{# Fractional days between two timestamps. #}
{% macro days_between(start_ts, end_ts) %}
    ({{ dbt.datediff(start_ts, end_ts, 'second') }} / 86400.0)
{% endmacro %}

{# Date literal from a project var. #}
{% macro var_date(var_name) %}
    cast('{{ var(var_name) }}' as date)
{% endmacro %}

{% macro var_timestamp(var_name) %}
    cast('{{ var(var_name) }}' as {{ dbt.type_timestamp() }})
{% endmacro %}
