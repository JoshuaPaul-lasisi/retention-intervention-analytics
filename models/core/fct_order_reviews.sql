-- One row per review and order. Olist sometimes sends one survey for several
-- orders (the same review_id on more than one order) and sometimes several
-- surveys for one order, so the grain is the pair.

with reviews as (
    select * from {{ ref('stg_order_reviews') }}
),

orders as (
    select order_id, customer_unique_id, lead_seller_id, product_category, order_purchase_date
    from {{ ref('int_orders_enriched') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['reviews.review_id', 'reviews.order_id']) }} as order_review_id,
    reviews.review_id,
    reviews.order_id,
    orders.customer_unique_id,
    orders.lead_seller_id                                       as seller_id,
    orders.product_category,
    orders.order_purchase_date,
    reviews.review_score,
    cast(reviews.review_created_at as date)                     as review_creation_date,
    reviews.review_answered_at,
    {{ dbt.datediff('reviews.review_created_at', 'reviews.review_answered_at', 'second') }} / 3600.0 as response_time_hours,
    case
        when reviews.review_score <= 2 then 'negative'
        when reviews.review_score = 3 then 'neutral'
        else 'positive'
    end                                                         as sentiment_flag,
    reviews.review_comment_message is not null                  as has_comment
from reviews
left join orders on orders.order_id = reviews.order_id
