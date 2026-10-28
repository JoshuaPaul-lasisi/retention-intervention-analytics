-- One row per order and seller. An order can hold items from several sellers
-- (about 1% of orders); each seller is credited with its own items' value and
-- shares the order's delivery outcome and review.

with items as (
    select
        order_id,
        seller_id,
        count(*)                            as item_count,
        sum(price)                          as items_value,
        sum(freight_value)                  as freight_value,
        sum(price) + sum(freight_value)     as seller_order_value
    from {{ ref('stg_order_items') }}
    group by order_id, seller_id
),

orders as (
    select order_id, order_purchased_at, order_purchase_date, is_completed, is_in_analysis_window
    from {{ ref('int_orders_enriched') }}
),

signals as (
    select * from {{ ref('int_delivery_and_review_signals') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['items.order_id', 'items.seller_id']) }} as order_seller_id,
    items.order_id,
    items.seller_id,
    orders.order_purchased_at,
    orders.order_purchase_date,
    cast({{ dbt.date_trunc('month', 'orders.order_purchase_date') }} as date)  as order_month,
    orders.is_completed,
    orders.is_in_analysis_window,
    items.item_count,
    items.items_value,
    items.freight_value,
    items.seller_order_value,
    signals.is_delivered,
    signals.delivery_days,
    signals.delivery_delta_days,
    signals.is_on_time,
    signals.is_late_delivery,
    signals.review_score,
    signals.is_negative_review
from items
inner join orders on orders.order_id = items.order_id
left join signals on signals.order_id = items.order_id
