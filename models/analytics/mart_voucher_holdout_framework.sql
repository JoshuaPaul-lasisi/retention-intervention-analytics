-- One row per customer eligible for the voucher test, as of the snapshot date.
--
-- Eligible means:
--   1. first order in a high-propensity category (mart_category_repeat_propensity)
--   2. has not bought again yet
--   3. inside the category's timing window: at least
--      voucher_min_days_since_first_order days since the first order (the parcel
--      has arrived) and no more than the category's 75th percentile of days to
--      repeat (past that, most natural repeats have already happened)
--
-- assigned_group stays null until the assignment is made outside dbt
-- (scripts/assign_holdout.py) and loaded back as the voucher_test_assignments
-- seed. The outcome metric is a repeat purchase within
-- voucher_metric_window_days of assignment (analyses/voucher_test_readout.sql).

with customers as (
    select * from {{ ref('dim_customers') }}
    where has_qualifying_order
      and not is_repeat_buyer
),

categories as (
    select first_order_category, repeat_rate
    from {{ ref('mart_category_repeat_propensity') }}
    where is_high_propensity
),

timing as (
    select first_order_category, median_days_to_repeat, p75_days_to_repeat
    from {{ ref('mart_email_timing_windows_by_category') }}
),

assignments as (
    select * from {{ ref('voucher_test_assignments') }}
),

candidates as (
    select
        customers.customer_unique_id,
        customers.customer_state,
        customers.customer_region,
        customers.first_order_id,
        customers.first_order_date,
        customers.first_order_category,
        customers.first_order_value,
        {{ dbt.datediff('customers.first_order_date', var_date('snapshot_date'), 'day') }} as days_since_first_order,
        categories.repeat_rate                      as category_repeat_rate,
        timing.median_days_to_repeat                as category_median_days_to_repeat,
        timing.p75_days_to_repeat                   as category_p75_days_to_repeat
    from customers
    inner join categories on categories.first_order_category = customers.first_order_category
    inner join timing on timing.first_order_category = customers.first_order_category
)

select
    candidates.*,
    {{ var_date('snapshot_date') }}                 as eligibility_snapshot_date,
    assignments.assigned_group,
    assignments.assigned_at
from candidates
left join assignments on assignments.customer_unique_id = candidates.customer_unique_id
where candidates.days_since_first_order >= {{ var('voucher_min_days_since_first_order') }}
  and candidates.days_since_first_order <= candidates.category_p75_days_to_repeat
