with source as (
    select * from {{ source('olist', 'olist_customers_dataset') }}
)

select
    cast(customer_id as {{ dbt.type_string() }})                                    as customer_id,
    cast(customer_unique_id as {{ dbt.type_string() }})                             as customer_unique_id,
    lpad(cast(customer_zip_code_prefix as {{ dbt.type_string() }}), 5, '0')         as customer_zip_code_prefix,
    cast(customer_city as {{ dbt.type_string() }})                                  as customer_city,
    cast(customer_state as {{ dbt.type_string() }})                                 as customer_state
from source
