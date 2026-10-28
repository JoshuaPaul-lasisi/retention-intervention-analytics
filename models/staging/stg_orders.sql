with source as (
    select * from {{ source('olist', 'olist_orders_dataset') }}
)

select
    cast(order_id as {{ dbt.type_string() }})                              as order_id,
    cast(customer_id as {{ dbt.type_string() }})                           as customer_id,
    cast(order_status as {{ dbt.type_string() }})                          as order_status,
    cast(order_purchase_timestamp as {{ dbt.type_timestamp() }})           as order_purchased_at,
    cast(order_approved_at as {{ dbt.type_timestamp() }})                  as order_approved_at,
    cast(order_delivered_carrier_date as {{ dbt.type_timestamp() }})       as order_delivered_carrier_at,
    cast(order_delivered_customer_date as {{ dbt.type_timestamp() }})      as order_delivered_customer_at,
    cast(order_estimated_delivery_date as {{ dbt.type_timestamp() }})      as order_estimated_delivery_at
from source
