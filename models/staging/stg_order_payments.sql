with source as (
    select * from {{ source('olist', 'olist_order_payments_dataset') }}
)

select
    cast(order_id as {{ dbt.type_string() }})               as order_id,
    cast(payment_sequential as {{ dbt.type_int() }})        as payment_sequential,
    cast(payment_type as {{ dbt.type_string() }})           as payment_type,
    cast(payment_installments as {{ dbt.type_int() }})      as payment_installments,
    cast(payment_value as {{ dbt.type_numeric() }})         as payment_value
from source
