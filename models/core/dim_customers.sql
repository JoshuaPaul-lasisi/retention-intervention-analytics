-- One row per person (customer_unique_id), with region and lifetime purchase
-- history over qualifying orders.

with customers as (
    select * from {{ ref('int_customers_deduplicated') }}
),

regions as (
    select * from {{ ref('brazil_state_regions') }}
),

zip_centroids as (
    select * from {{ ref('int_zip_code_centroids') }}
)

select
    customers.customer_unique_id,
    customers.customer_id_count,
    customers.customer_zip_code_prefix,
    customers.customer_city,
    customers.customer_state,
    regions.region                              as customer_region,
    zip_centroids.latitude                      as customer_latitude,
    zip_centroids.longitude                     as customer_longitude,
    customers.has_qualifying_order,
    customers.first_order_id,
    customers.first_order_date,
    customers.first_order_category,
    customers.first_order_value,
    customers.second_purchase_date,
    customers.days_to_second_purchase,
    customers.last_order_date,
    customers.lifetime_orders,
    customers.purchase_days,
    customers.lifetime_value,
    customers.is_repeat_buyer,
    customers.is_repeat_window_observed,
    customers.is_repeat_within_window
from customers
left join regions on regions.state_code = customers.customer_state
left join zip_centroids on zip_centroids.zip_code_prefix = customers.customer_zip_code_prefix
