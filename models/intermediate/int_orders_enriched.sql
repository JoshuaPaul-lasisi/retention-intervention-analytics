-- One row per order. Joins each order to its items, payments, products and the
-- person (customer_unique_id) behind the order-scoped customer_id.
--
-- Rules carried over from the Olist retention analysis:
--   order value      = item prices + freight
--   lead item        = most expensive item (ties go to the lower order_item_id);
--                      its category, product and seller describe the order
--   payment method   = the payment type that paid the most
--   completed        = has items and is not canceled or unavailable
--   analysis window  = purchased from analysis_start_date to snapshot_date

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select customer_id, customer_unique_id from {{ ref('stg_customers') }}
),

items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

translation as (
    select * from {{ ref('stg_product_category_name_translation') }}
),

item_totals as (
    select
        order_id,
        count(*)                    as item_count,
        count(distinct seller_id)   as seller_count,
        sum(price)                  as items_value,
        sum(freight_value)          as freight_value
    from items
    group by order_id
),

items_ranked as (
    select
        items.order_id,
        items.product_id,
        items.seller_id,
        {{ product_category_english('translation.product_category_name_english', 'products.product_category_name') }} as product_category,
        row_number() over (
            partition by items.order_id
            order by items.price desc, items.order_item_id
        ) as price_rank
    from items
    left join products on products.product_id = items.product_id
    left join translation on translation.product_category_name = products.product_category_name
),

lead_item as (
    select order_id, product_id, seller_id, product_category
    from items_ranked
    where price_rank = 1
),

payments_ranked as (
    select
        order_id,
        payment_type,
        max(payment_installments) over (partition by order_id) as payment_installments,
        max(case when payment_type = 'voucher' then 1 else 0 end) over (partition by order_id) as used_voucher_flag,
        count(*) over (partition by order_id) as payment_count,
        row_number() over (
            partition by order_id
            order by payment_value desc, payment_sequential
        ) as value_rank
    from {{ ref('stg_order_payments') }}
),

main_payment as (
    select order_id, payment_type, payment_installments, used_voucher_flag, payment_count
    from payments_ranked
    where value_rank = 1
)

select
    orders.order_id,
    orders.customer_id,
    customers.customer_unique_id,
    orders.order_status,
    orders.order_purchased_at,
    cast(orders.order_purchased_at as date)                                     as order_purchase_date,
    orders.order_approved_at,
    orders.order_delivered_carrier_at,
    orders.order_delivered_customer_at,
    orders.order_estimated_delivery_at,

    coalesce(item_totals.item_count, 0)                                         as item_count,
    coalesce(item_totals.seller_count, 0)                                       as seller_count,
    coalesce(item_totals.items_value, 0)                                        as items_value,
    coalesce(item_totals.freight_value, 0)                                      as freight_value,
    coalesce(item_totals.items_value, 0) + coalesce(item_totals.freight_value, 0) as order_value,

    lead_item.product_id                                                        as lead_product_id,
    lead_item.seller_id                                                         as lead_seller_id,
    lead_item.product_category,

    main_payment.payment_type                                                   as payment_method,
    main_payment.payment_installments,
    main_payment.payment_count,
    coalesce(main_payment.used_voucher_flag, 0) = 1                             as used_voucher,

    (orders.order_status not in ('canceled', 'unavailable')
        and item_totals.order_id is not null)                                   as is_completed,
    (orders.order_purchased_at >= {{ var_timestamp('analysis_start_date') }}
        and cast(orders.order_purchased_at as date) <= {{ var_date('snapshot_date') }}) as is_in_analysis_window

from orders
left join customers on customers.customer_id = orders.customer_id
left join item_totals on item_totals.order_id = orders.order_id
left join lead_item on lead_item.order_id = orders.order_id
left join main_payment on main_payment.order_id = orders.order_id
