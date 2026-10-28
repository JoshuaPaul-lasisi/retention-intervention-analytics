-- One row per first-order category: how often its first-time buyers come back.
-- This is the targeting list for follow-up email.
--
-- repeat_rate is the 180-day repeat rate over buyers whose first order was at
-- least 180 days before the snapshot, so recent buyers who have not had time
-- to return do not drag the rate down. The 95% Wilson interval shows how much
-- of a gap between categories is noise. Only categories with at least
-- min_category_buyers observed buyers are ranked.

with customers as (
    select * from {{ ref('dim_customers') }}
    where has_qualifying_order
),

overall as (
    select
        avg(case when is_repeat_within_window then 1.0 else 0.0 end) as overall_repeat_rate
    from customers
    where is_repeat_window_observed
),

by_category as (
    select
        first_order_category,
        count(*)                                                                    as first_time_buyers,
        sum(case when is_repeat_buyer then 1 else 0 end)                            as repeat_buyers,
        sum(case when is_repeat_window_observed then 1 else 0 end)                  as observed_buyers,
        sum(case when is_repeat_within_window then 1 else 0 end)                    as repeat_buyers_within_window,
        avg(case when is_repeat_within_window then days_to_second_purchase end)     as avg_days_to_second_purchase
    from customers
    group by first_order_category
),

rates as (
    select
        by_category.*,
        overall.overall_repeat_rate,
        repeat_buyers_within_window * 1.0 / nullif(observed_buyers, 0)              as repeat_rate,
        observed_buyers >= {{ var('min_category_buyers') }}                         as is_ranked
    from by_category
    cross join overall
),

intervals as (
    select
        *,
        -- Wilson score interval, z = 1.96
        (repeat_rate + 1.96 * 1.96 / (2 * observed_buyers)
            - 1.96 * sqrt(repeat_rate * (1 - repeat_rate) / observed_buyers
                          + 1.96 * 1.96 / (4 * observed_buyers * observed_buyers)))
            / (1 + 1.96 * 1.96 / observed_buyers)                                   as repeat_rate_ci_low,
        (repeat_rate + 1.96 * 1.96 / (2 * observed_buyers)
            + 1.96 * sqrt(repeat_rate * (1 - repeat_rate) / observed_buyers
                          + 1.96 * 1.96 / (4 * observed_buyers * observed_buyers)))
            / (1 + 1.96 * 1.96 / observed_buyers)                                   as repeat_rate_ci_high
    from rates
)

select
    first_order_category,
    first_time_buyers,
    repeat_buyers,
    observed_buyers,
    repeat_buyers_within_window,
    repeat_rate,
    repeat_rate_ci_low,
    repeat_rate_ci_high,
    overall_repeat_rate,
    repeat_rate / nullif(overall_repeat_rate, 0)                                    as lift_vs_overall,
    avg_days_to_second_purchase,
    is_ranked,
    case
        when is_ranked then rank() over (
            partition by is_ranked
            order by repeat_rate desc
        )
    end                                                                             as propensity_rank,
    coalesce(
        is_ranked and repeat_rate >= overall_repeat_rate * {{ var('high_propensity_min_lift') }},
        false
    )                                                                               as is_high_propensity
from intervals
