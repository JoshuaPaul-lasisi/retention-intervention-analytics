with sellers as (
    select * from {{ ref('stg_sellers') }}
),

performance as (
    select * from {{ ref('int_seller_performance') }}
),

regions as (
    select * from {{ ref('brazil_state_regions') }}
),

zip_centroids as (
    select * from {{ ref('int_zip_code_centroids') }}
)

select
    sellers.seller_id,
    sellers.seller_zip_code_prefix,
    sellers.seller_city,
    sellers.seller_state,
    regions.region                                  as seller_region,
    zip_centroids.latitude                          as seller_latitude,
    zip_centroids.longitude                         as seller_longitude,
    coalesce(performance.order_count, 0)            as order_count,
    coalesce(performance.delivered_order_count, 0)  as delivered_order_count,
    coalesce(performance.gmv, 0)                    as total_gmv,
    performance.avg_delivery_days,
    performance.avg_delivery_delta_days,
    performance.late_delivery_rate,
    performance.on_time_rate,
    performance.avg_review_score,
    performance.negative_review_rate,
    performance.first_order_date,
    performance.last_order_date
from sellers
left join performance on performance.seller_id = sellers.seller_id
left join regions on regions.state_code = sellers.seller_state
left join zip_centroids on zip_centroids.zip_code_prefix = sellers.seller_zip_code_prefix
