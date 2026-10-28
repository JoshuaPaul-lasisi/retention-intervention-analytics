with products as (
    select * from {{ ref('stg_products') }}
),

translation as (
    select * from {{ ref('stg_product_category_name_translation') }}
)

select
    products.product_id,
    products.product_category_name                                  as product_category_portuguese,
    {{ product_category_english('translation.product_category_name_english', 'products.product_category_name') }} as product_category,
    products.product_weight_g,
    products.product_length_cm,
    products.product_height_cm,
    products.product_width_cm,
    products.product_length_cm * products.product_height_cm * products.product_width_cm as product_volume_cm3,
    products.product_photo_count,
    products.product_name_length,
    products.product_description_length
from products
left join translation on translation.product_category_name = products.product_category_name
