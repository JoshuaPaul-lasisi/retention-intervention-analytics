-- One row per person (customer_unique_id).
--
-- Olist issues a new customer_id for every order, so counting customer_id finds
-- no repeat buyers at all. This model collapses every customer_id onto the
-- customer_unique_id behind it and rebuilds the purchase history per person.
--
-- Purchase history uses qualifying orders only: completed and inside the
-- analysis window. A repeat purchase is a qualifying order on a later calendar
-- day than the first; a second order on the same day is a split cart, not a
-- return (about a third of apparent second orders).
--
-- Every person in the customer table gets a row, including the few whose only
-- orders were canceled or fall outside the window (has_qualifying_order = false).

with customer_ids as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('int_orders_enriched') }}
),

-- Address: take the customer_id record on the person's earliest order.
addresses_ranked as (
    select
        customer_ids.customer_unique_id,
        customer_ids.customer_zip_code_prefix,
        customer_ids.customer_city,
        customer_ids.customer_state,
        row_number() over (
            partition by customer_ids.customer_unique_id
            order by orders.order_purchased_at, customer_ids.customer_id
        ) as address_rank
    from customer_ids
    left join orders on orders.customer_id = customer_ids.customer_id
),

persons as (
    select
        customer_unique_id,
        count(*) as customer_id_count
    from customer_ids
    group by customer_unique_id
),

qualifying_orders as (
    select
        customer_unique_id,
        order_id,
        order_purchased_at,
        order_purchase_date,
        order_value,
        product_category,
        row_number() over (
            partition by customer_unique_id
            order by order_purchased_at, order_id
        ) as order_sequence
    from orders
    where is_completed and is_in_analysis_window
),

first_orders as (
    select * from qualifying_orders where order_sequence = 1
),

history as (
    select
        customer_unique_id,
        min(order_purchased_at)                 as first_order_at,
        max(order_purchased_at)                 as last_order_at,
        count(*)                                as lifetime_orders,
        count(distinct order_purchase_date)     as purchase_days,
        sum(order_value)                        as lifetime_value
    from qualifying_orders
    group by customer_unique_id
),

second_purchase as (
    select
        qualifying_orders.customer_unique_id,
        min(qualifying_orders.order_purchased_at) as second_purchase_at
    from qualifying_orders
    inner join first_orders
        on first_orders.customer_unique_id = qualifying_orders.customer_unique_id
    where qualifying_orders.order_purchase_date > first_orders.order_purchase_date
    group by qualifying_orders.customer_unique_id
),

joined as (
    select
        persons.customer_unique_id,
        persons.customer_id_count,
        addresses_ranked.customer_zip_code_prefix,
        addresses_ranked.customer_city,
        addresses_ranked.customer_state,

        history.customer_unique_id is not null                  as has_qualifying_order,
        first_orders.order_id                                   as first_order_id,
        history.first_order_at,
        cast(history.first_order_at as date)                    as first_order_date,
        first_orders.product_category                           as first_order_category,
        first_orders.order_value                                as first_order_value,
        second_purchase.second_purchase_at,
        cast(second_purchase.second_purchase_at as date)        as second_purchase_date,
        {{ days_between('history.first_order_at', 'second_purchase.second_purchase_at') }} as days_to_second_purchase,
        history.last_order_at,
        cast(history.last_order_at as date)                     as last_order_date,
        coalesce(history.lifetime_orders, 0)                    as lifetime_orders,
        coalesce(history.purchase_days, 0)                      as purchase_days,
        coalesce(history.lifetime_value, 0)                     as lifetime_value
    from persons
    inner join addresses_ranked
        on addresses_ranked.customer_unique_id = persons.customer_unique_id
        and addresses_ranked.address_rank = 1
    left join history on history.customer_unique_id = persons.customer_unique_id
    left join first_orders on first_orders.customer_unique_id = persons.customer_unique_id
    left join second_purchase on second_purchase.customer_unique_id = persons.customer_unique_id
)

select
    *,
    second_purchase_at is not null                              as is_repeat_buyer,
    -- The 180-day repeat outcome is only known for people who first bought at
    -- least 180 days before the snapshot.
    has_qualifying_order
        and {{ dbt.datediff('first_order_date', var_date('snapshot_date'), 'day') }} >= {{ var('repeat_window_days') }}
                                                                as is_repeat_window_observed,
    case
        when not has_qualifying_order then null
        when {{ dbt.datediff('first_order_date', var_date('snapshot_date'), 'day') }} < {{ var('repeat_window_days') }} then null
        when days_to_second_purchase <= {{ var('repeat_window_days') }} then true
        else false
    end                                                         as is_repeat_within_window
from joined
