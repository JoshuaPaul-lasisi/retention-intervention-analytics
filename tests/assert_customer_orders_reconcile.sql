-- Lifetime orders on dim_customers must add up to the qualifying orders in
-- fct_orders. A gap means the deduplication dropped or double-counted people.

with from_dim as (
    select sum(lifetime_orders) as order_count from {{ ref('dim_customers') }}
),

from_fact as (
    select count(*) as order_count
    from {{ ref('fct_orders') }}
    where is_completed and is_in_analysis_window
)

select from_dim.order_count as dim_orders, from_fact.order_count as fact_orders
from from_dim
cross join from_fact
where from_dim.order_count != from_fact.order_count
