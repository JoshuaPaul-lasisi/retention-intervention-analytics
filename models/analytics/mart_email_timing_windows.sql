-- One row per repeat buyer: how long they took to come back.
--
-- is_in_timing_sample marks the buyers used to set send windows: first order
-- at least 180 days before the snapshot and back within 180 days. Without that
-- cut, recent cohorts could only ever show short gaps and would pull the
-- windows forward.

select
    customer_unique_id,
    first_order_category,
    customer_region,
    first_order_date,
    second_purchase_date                                                    as second_order_date,
    days_to_second_purchase                                                 as days_to_repeat,
    {{ dbt.datediff('first_order_date', 'second_purchase_date', 'day') }}  as calendar_days_to_repeat,
    coalesce(is_repeat_within_window, false)                                as is_in_timing_sample
from {{ ref('dim_customers') }}
where is_repeat_buyer
