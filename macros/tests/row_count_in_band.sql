{#
  Fails when the model's row count falls outside [min_rows, max_rows].
  Catches a truncated or duplicated load that an equal-row-count test against
  the raw table would miss (both sides would be wrong together).
#}
{% test row_count_in_band(model, min_rows, max_rows) %}

with counted as (
    select count(*) as row_count from {{ model }}
)

select row_count
from counted
where row_count < {{ min_rows }}
   or row_count > {{ max_rows }}

{% endtest %}
