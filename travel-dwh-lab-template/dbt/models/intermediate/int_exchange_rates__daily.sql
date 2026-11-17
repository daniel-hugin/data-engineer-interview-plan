{#-
    El BCE solo publica en días hábiles, pero se reserva cualquier día.
    Decisión: para fines de semana y festivos se usa el último tipo publicado
    (forward fill), y se marca con is_filled para poder auditarlo.
-#}
with

calendar as (
    -- generator + row_number en vez de seq4() directamente: seq4 no garantiza ausencia de huecos
    select
        dateadd(
            day,
            row_number() over (order by seq4()) - 1,
            '{{ var("fx_start_date") }}'::date
        ) as calendar_date
    from table(generator(rowcount => 10000))
    qualify calendar_date <= current_date()
),

currencies as (
    select distinct quote_currency
    from {{ ref('stg_ecb__exchange_rates') }}
),

rates as (
    select * from {{ ref('stg_ecb__exchange_rates') }}
),

spine as (
    select
        calendar.calendar_date,
        currencies.quote_currency
    from calendar
    cross join currencies
)

select
    spine.calendar_date as rate_date,
    'EUR' as base_currency,
    spine.quote_currency,
    last_value(rates.rate) ignore nulls over (
        partition by spine.quote_currency
        order by spine.calendar_date
        rows between unbounded preceding and current row
    ) as rate,
    rates.rate is null as is_filled
from spine
left join rates
    on
        spine.calendar_date = rates.rate_date
        and spine.quote_currency = rates.quote_currency
