{#-
    Decisión de negocio: el ingreso se convierte con el tipo del día de la RESERVA
    (cuando se fija el precio), no del día de llegada. Documentarlo evita discusiones.
    Las reservas canceladas se conservan con ingreso 0 para poder medir la tasa de cancelación.
-#}
with

bookings as (
    select * from {{ ref('stg_hotel_bookings__bookings') }}
),

fx as (
    select * from {{ ref('int_exchange_rates__daily') }}
    where quote_currency = '{{ var("reporting_currency") }}'
)

select
    bookings.booking_id,
    bookings.hotel_type,
    bookings.booking_date,
    bookings.arrival_date,
    bookings.lead_time_days,
    bookings.total_nights,
    bookings.adults,
    bookings.children,
    bookings.babies,
    bookings.country_code,
    bookings.market_segment,
    bookings.distribution_channel,
    bookings.customer_type,
    bookings.deposit_type,
    bookings.is_repeated_guest,
    bookings.is_canceled,
    bookings.is_room_reassigned,
    bookings.special_requests,
    bookings.adr_eur,

    iff(bookings.is_canceled, 0, bookings.adr_eur * bookings.total_nights) as revenue_eur,

    fx.rate as fx_rate_eur_to_reporting,
    fx.is_filled as is_fx_rate_filled,
    iff(bookings.is_canceled, 0, bookings.adr_eur * bookings.total_nights * fx.rate)
        as revenue_reporting_currency
from bookings
left join fx
    on bookings.booking_date = fx.rate_date
