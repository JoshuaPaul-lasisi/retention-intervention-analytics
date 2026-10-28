-- One row per order: how the delivery went against the promise, and what the
-- customer said about it.
--
-- delivery_delta_days is actual minus estimated delivery, in fractional days:
-- positive means late, negative means early. A delivery is late when it lands
-- more than late_delivery_threshold_days after the estimate; past that point the
-- share of one and two-star reviews jumps to 60% or more.

with orders as (
    select
        order_id,
        order_purchased_at,
        order_delivered_customer_at,
        order_estimated_delivery_at
    from {{ ref('stg_orders') }}
),

reviews_ranked as (
    select
        order_id,
        review_id,
        review_score,
        review_created_at,
        review_answered_at,
        count(*) over (partition by order_id) as review_count,
        row_number() over (
            partition by order_id
            order by review_answered_at desc, review_id
        ) as recency_rank
    from {{ ref('stg_order_reviews') }}
),

latest_review as (
    select * from reviews_ranked where recency_rank = 1
)

select
    orders.order_id,
    orders.order_delivered_customer_at is not null                                          as is_delivered,
    {{ days_between('orders.order_purchased_at', 'orders.order_delivered_customer_at') }}   as delivery_days,
    {{ days_between('orders.order_estimated_delivery_at', 'orders.order_delivered_customer_at') }} as delivery_delta_days,
    case
        when orders.order_delivered_customer_at is null then null
        when orders.order_delivered_customer_at <= orders.order_estimated_delivery_at then true
        else false
    end                                                                                     as is_on_time,
    case
        when orders.order_delivered_customer_at is null then null
        when {{ days_between('orders.order_estimated_delivery_at', 'orders.order_delivered_customer_at') }}
             > {{ var('late_delivery_threshold_days') }} then true
        else false
    end                                                                                     as is_late_delivery,

    latest_review.review_id,
    latest_review.review_score,
    coalesce(latest_review.review_count, 0)                                                 as review_count,
    latest_review.review_created_at,
    latest_review.review_answered_at,
    {{ dbt.datediff('latest_review.review_created_at', 'latest_review.review_answered_at', 'second') }} / 3600.0 as review_response_hours,
    latest_review.review_score <= 2                                                         as is_negative_review

from orders
left join latest_review on latest_review.order_id = orders.order_id
