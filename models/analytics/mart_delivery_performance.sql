-- One row per seller and month: delivery and review record over qualifying
-- orders, for spotting seller relationships that are hurting customers.
--
-- on_time_rate counts deliveries on or before the estimate. late_order_count
-- counts deliveries more than late_delivery_threshold_days after it, the point
-- where bad reviews take off.

with seller_orders as (
    select * from {{ ref('int_order_sellers') }}
    where is_completed and is_in_analysis_window
),

sellers as (
    select seller_id, seller_state, seller_region, late_delivery_rate, avg_review_score
    from {{ ref('dim_sellers') }}
),

monthly as (
    select
        seller_id,
        order_month,
        count(*)                                                                as order_count,
        sum(case when is_delivered then 1 else 0 end)                           as delivered_order_count,
        avg(case when is_on_time then 1.0 when is_delivered then 0.0 end)       as on_time_rate,
        sum(case when is_late_delivery then 1 else 0 end)                       as late_order_count,
        avg(case when is_late_delivery then 1.0 when is_delivered then 0.0 end) as late_delivery_rate,
        avg(delivery_days)                                                      as avg_delivery_days,
        avg(delivery_delta_days)                                                as avg_delivery_delta_days,
        avg(review_score)                                                       as avg_review_score,
        sum(case when is_negative_review then 1 else 0 end)                     as negative_review_count,
        sum(seller_order_value)                                                 as gmv
    from seller_orders
    group by seller_id, order_month
)

select
    {{ dbt_utils.generate_surrogate_key(['monthly.seller_id', 'monthly.order_month']) }} as seller_month_id,
    monthly.seller_id,
    monthly.order_month,
    sellers.seller_state,
    sellers.seller_region,
    monthly.order_count,
    monthly.delivered_order_count,
    monthly.on_time_rate,
    monthly.late_order_count,
    monthly.late_delivery_rate,
    monthly.avg_delivery_days,
    monthly.avg_delivery_delta_days,
    monthly.avg_review_score,
    monthly.negative_review_count,
    monthly.gmv,
    sellers.late_delivery_rate                                              as seller_lifetime_late_delivery_rate,
    sellers.avg_review_score                                                as seller_lifetime_avg_review_score
from monthly
inner join sellers on sellers.seller_id = monthly.seller_id
