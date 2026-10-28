with source as (
    select * from {{ source('olist', 'olist_sellers_dataset') }}
)

select
    cast(seller_id as {{ dbt.type_string() }})                                  as seller_id,
    lpad(cast(seller_zip_code_prefix as {{ dbt.type_string() }}), 5, '0')       as seller_zip_code_prefix,
    cast(seller_city as {{ dbt.type_string() }})                                as seller_city,
    cast(seller_state as {{ dbt.type_string() }})                               as seller_state
from source
