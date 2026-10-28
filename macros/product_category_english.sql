{#
  English category name. Two Portuguese categories are missing from Olist's
  translation table, so they are mapped here; products with no category are 'unknown'.
#}
{% macro product_category_english(english_col, portuguese_col) %}
    coalesce(
        {{ english_col }},
        case {{ portuguese_col }}
            when 'pc_gamer' then 'pc_gamer'
            when 'portateis_cozinha_e_preparadores_de_alimentos' then 'kitchen_portables_and_food_prep'
        end,
        'unknown'
    )
{% endmacro %}
