-- Repeat buyers summed across categories must equal repeat buyers in
-- dim_customers, and the timing mart must hold one row for each of them.

with propensity as (
    select sum(repeat_buyers) as repeat_buyers from {{ ref('mart_category_repeat_propensity') }}
),

customers as (
    select sum(case when is_repeat_buyer then 1 else 0 end) as repeat_buyers from {{ ref('dim_customers') }}
),

timing as (
    select count(*) as repeat_buyers from {{ ref('mart_email_timing_windows') }}
)

select propensity.repeat_buyers as propensity, customers.repeat_buyers as customers, timing.repeat_buyers as timing
from propensity
cross join customers
cross join timing
where propensity.repeat_buyers != customers.repeat_buyers
   or timing.repeat_buyers != customers.repeat_buyers
