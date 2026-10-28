-- A second order on the same calendar day as the first is a split cart, not a
-- return. None may reach the timing mart.

select customer_unique_id, first_order_date, second_order_date
from {{ ref('mart_email_timing_windows') }}
where second_order_date <= first_order_date
