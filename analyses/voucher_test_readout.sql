-- Voucher test readout. Compile with `dbt compile -s voucher_test_readout` and
-- run the SQL in target/compiled once the outcome window has closed.
--
-- Metric: share of each group that places a completed order within
-- voucher_metric_window_days of assignment, on a later day than both the
-- assignment and the first order (so neither the first order nor a split cart
-- counts as a return). The difference
-- comes with a 95% interval (normal approximation); if the interval crosses
-- zero the voucher has not shown an effect.

with assigned as (
    select customer_unique_id, first_order_date, assigned_group, assigned_at
    from {{ ref('mart_voucher_holdout_framework') }}
    where assigned_group is not null
),

returns as (
    select distinct assigned.customer_unique_id
    from assigned
    inner join {{ ref('fct_orders') }} as orders
        on orders.customer_unique_id = assigned.customer_unique_id
    where orders.is_completed
      and orders.order_purchase_date > assigned.assigned_at
      and orders.order_purchase_date > assigned.first_order_date
      and {{ dbt.datediff('assigned.assigned_at', 'orders.order_purchase_date', 'day') }}
          <= {{ var('voucher_metric_window_days') }}
),

by_group as (
    select
        assigned.assigned_group,
        count(*)                                                    as customers,
        count(returns.customer_unique_id)                           as repeaters,
        count(returns.customer_unique_id) * 1.0 / count(*)          as repeat_rate
    from assigned
    left join returns on returns.customer_unique_id = assigned.customer_unique_id
    group by assigned.assigned_group
),

compared as (
    select
        t.customers                                                 as treatment_customers,
        t.repeat_rate                                               as treatment_repeat_rate,
        h.customers                                                 as holdout_customers,
        h.repeat_rate                                               as holdout_repeat_rate,
        t.repeat_rate - h.repeat_rate                               as lift,
        sqrt(t.repeat_rate * (1 - t.repeat_rate) / t.customers
             + h.repeat_rate * (1 - h.repeat_rate) / h.customers)   as lift_standard_error
    from by_group as t
    cross join by_group as h
    where t.assigned_group = 'treatment'
      and h.assigned_group = 'holdout'
)

select
    *,
    lift - 1.96 * lift_standard_error                               as lift_ci_low,
    lift + 1.96 * lift_standard_error                               as lift_ci_high
from compared
