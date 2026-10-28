with source as (
    select * from {{ source('olist', 'olist_geolocation_dataset') }}
)

select
    lpad(cast(geolocation_zip_code_prefix as {{ dbt.type_string() }}), 5, '0')      as zip_code_prefix,
    cast(geolocation_lat as {{ dbt.type_float() }})                                 as latitude,
    cast(geolocation_lng as {{ dbt.type_float() }})                                 as longitude,
    cast(geolocation_city as {{ dbt.type_string() }})                               as city,
    cast(geolocation_state as {{ dbt.type_string() }})                              as state
from source
