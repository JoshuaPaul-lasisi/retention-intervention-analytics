{%- if target.type == 'bigquery' %}
{{
    config(
        partition_by={'field': 'order_purchase_date', 'data_type': 'date', 'granularity': 'month'},
        cluster_by=['customer_unique_id']
    )
}}
{%- endif %}

-- One row per order, every order in the source. Filter on is_completed and
-- is_in_analysis_window for the population the retention analysis uses.
-- seller_id and product_id are the order's lead (most expensive) item; orders
-- with several sellers are split out in int_order_sellers.

with orders as (
    select * from {{ ref('int_orders_enriched') }}
),

signals as (
    select * from {{ ref('int_delivery_and_review_signals') }}
),

sequenced as (
    select
        order_id,
        row_number() over (
            partition by customer_unique_id
            order by order_purchased_at, order_id
        ) as customer_order_number
    from orders
    where is_completed and is_in_analysis_window
)

select
    orders.order_id,
    orders.customer_unique_id,
    orders.customer_id,
    orders.lead_seller_id                       as seller_id,
    orders.lead_product_id                      as product_id,
    orders.order_purchase_date,
    orders.order_purchased_at,
    orders.order_status,
    orders.is_completed,
    orders.is_in_analysis_window,
    sequenced.customer_order_number,
    coalesce(sequenced.customer_order_number = 1, false) as is_first_order,
    orders.item_count,
    orders.seller_count,
    orders.items_value,
    orders.freight_value,
    orders.order_value,
    orders.product_category,
    orders.payment_method,
    orders.payment_installments,
    orders.used_voucher,
    orders.order_delivered_customer_at,
    orders.order_estimated_delivery_at,
    signals.is_delivered,
    signals.delivery_days,
    signals.delivery_delta_days,
    signals.is_on_time,
    signals.is_late_delivery,
    signals.review_score,
    signals.is_negative_review
from orders
left join signals on signals.order_id = orders.order_id
left join sequenced on sequenced.order_id = orders.order_id
