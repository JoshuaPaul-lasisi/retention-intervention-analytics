-- One row per seller: delivery and review record over qualifying orders
-- (completed, inside the analysis window).

with seller_orders as (
    select * from {{ ref('int_order_sellers') }}
    where is_completed and is_in_analysis_window
)

select
    seller_id,
    count(*)                                                                as order_count,
    sum(case when is_delivered then 1 else 0 end)                           as delivered_order_count,
    sum(seller_order_value)                                                 as gmv,
    avg(delivery_days)                                                      as avg_delivery_days,
    avg(delivery_delta_days)                                                as avg_delivery_delta_days,
    sum(case when is_late_delivery then 1 else 0 end)                       as late_order_count,
    avg(case when is_late_delivery then 1.0 when is_delivered then 0.0 end) as late_delivery_rate,
    avg(case when is_on_time then 1.0 when is_delivered then 0.0 end)       as on_time_rate,
    avg(review_score)                                                       as avg_review_score,
    avg(case when is_negative_review then 1.0 when review_score is not null then 0.0 end) as negative_review_rate,
    min(order_purchase_date)                                                as first_order_date,
    max(order_purchase_date)                                                as last_order_date
from seller_orders
group by seller_id
