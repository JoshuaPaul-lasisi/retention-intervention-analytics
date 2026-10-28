-- Calendar spine from date_spine_start to date_spine_end. Weeks start on Monday.

with spine as (
    {{ date_spine_days(var('date_spine_start'), var('date_spine_end')) }}
),

parts as (
    select
        date_day,
        {{ iso_day_of_week('date_day') }} as iso_day_of_week
    from spine
)

select
    date_day,
    extract(year from date_day)                                                     as year,
    extract(quarter from date_day)                                                  as quarter,
    extract(month from date_day)                                                    as month,
    {{ month_name('date_day') }}                                                    as month_name,
    cast({{ dbt.date_trunc('month', 'date_day') }} as date)                        as month_start_date,
    cast({{ dbt.dateadd('day', '1 - iso_day_of_week', 'date_day') }} as date)      as week_start_date,
    extract(day from date_day)                                                      as day_of_month,
    iso_day_of_week,
    iso_day_of_week in (6, 7)                                                       as is_weekend,
    date_day >= {{ var_date('analysis_start_date') }}
        and date_day <= {{ var_date('snapshot_date') }}                             as is_in_analysis_window
from parts
