-- One row per first-order category, plus an all_categories row: the spread of
-- days between first and second purchase, over the timing sample.
--
-- The median is when half of the buyers who return have already done so.
-- suggested_send_day is the 25th percentile: an email sent then lands before
-- three quarters of natural repeats. Categories with fewer than
-- min_category_repeaters repeat buyers should use the all_categories row.

with sample as (
    select first_order_category, days_to_repeat
    from {{ ref('mart_email_timing_windows') }}
    where is_in_timing_sample

    union all

    select 'all_categories' as first_order_category, days_to_repeat
    from {{ ref('mart_email_timing_windows') }}
    where is_in_timing_sample
),

with_percentiles as (
    select
        first_order_category,
        days_to_repeat,
        {{ percentile_over('days_to_repeat', 0.10, 'first_order_category') }} as p10_days,
        {{ percentile_over('days_to_repeat', 0.25, 'first_order_category') }} as p25_days,
        {{ percentile_over('days_to_repeat', 0.50, 'first_order_category') }} as median_days,
        {{ percentile_over('days_to_repeat', 0.75, 'first_order_category') }} as p75_days,
        {{ percentile_over('days_to_repeat', 0.90, 'first_order_category') }} as p90_days
    from sample
)

select
    first_order_category,
    count(*)                                                                as repeat_buyers,
    avg(days_to_repeat)                                                     as mean_days_to_repeat,
    max(p10_days)                                                           as p10_days_to_repeat,
    max(p25_days)                                                           as p25_days_to_repeat,
    max(median_days)                                                        as median_days_to_repeat,
    max(p75_days)                                                           as p75_days_to_repeat,
    max(p90_days)                                                           as p90_days_to_repeat,
    avg(case when days_to_repeat <= 30 then 1.0 else 0.0 end)               as share_within_30_days,
    avg(case when days_to_repeat <= 60 then 1.0 else 0.0 end)               as share_within_60_days,
    avg(case when days_to_repeat <= 90 then 1.0 else 0.0 end)               as share_within_90_days,
    round(max(p25_days))                                                    as suggested_send_day,
    count(*) >= {{ var('min_category_repeaters') }}                         as has_enough_repeaters
from with_percentiles
group by first_order_category
