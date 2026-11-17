with

source as (
    select * from {{ source('ecb', 'exchange_rates') }}
),

deduplicated as (
    -- defensivo: si una recarga dejara duplicados, gana la última
    select *
    from source
    qualify row_number() over (
        partition by rate_date, currency
        order by loaded_at desc
    ) = 1
)

select
    rate_date,
    base_currency,
    currency as quote_currency,
    rate,
    loaded_at
from deduplicated
