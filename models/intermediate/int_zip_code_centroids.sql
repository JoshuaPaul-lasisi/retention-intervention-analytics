-- One row per zip code prefix: the average of its geolocation points. The raw
-- geolocation table holds about a million points for 19,000 prefixes, so it
-- has to be collapsed before anything joins to it.

select
    zip_code_prefix,
    avg(latitude)       as latitude,
    avg(longitude)      as longitude,
    count(*)            as point_count
from {{ ref('stg_geolocation') }}
group by zip_code_prefix
