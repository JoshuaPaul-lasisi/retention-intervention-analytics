with source as (
    select * from {{ source('olist', 'olist_order_items_dataset') }}
)

select
    cast(order_id as {{ dbt.type_string() }})                   as order_id,
    cast(order_item_id as {{ dbt.type_int() }})                 as order_item_id,
    cast(product_id as {{ dbt.type_string() }})                 as product_id,
    cast(seller_id as {{ dbt.type_string() }})                  as seller_id,
    cast(shipping_limit_date as {{ dbt.type_timestamp() }})     as shipping_limit_at,
    cast(price as {{ dbt.type_numeric() }})                     as price,
    cast(freight_value as {{ dbt.type_numeric() }})             as freight_value
from source
