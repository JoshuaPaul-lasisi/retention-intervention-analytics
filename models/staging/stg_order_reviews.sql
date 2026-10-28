with source as (
    select * from {{ source('olist', 'olist_order_reviews_dataset') }}
)

select
    cast(review_id as {{ dbt.type_string() }})                      as review_id,
    cast(order_id as {{ dbt.type_string() }})                       as order_id,
    cast(review_score as {{ dbt.type_int() }})                      as review_score,
    cast(review_comment_title as {{ dbt.type_string() }})           as review_comment_title,
    cast(review_comment_message as {{ dbt.type_string() }})         as review_comment_message,
    cast(review_creation_date as {{ dbt.type_timestamp() }})        as review_created_at,
    cast(review_answer_timestamp as {{ dbt.type_timestamp() }})     as review_answered_at
from source
