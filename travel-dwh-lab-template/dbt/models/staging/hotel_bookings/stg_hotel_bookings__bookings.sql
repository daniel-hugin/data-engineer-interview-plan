with

source as (
    select * from {{ source('hotel_bookings', 'bookings') }}
),

typed as (
    select
        -- el dataset no trae id: fichero + nº de fila es estable entre cargas
        md5(_source_file || '|' || _source_row_number::varchar) as booking_id,

        hotel as hotel_name,
        case hotel
            when 'City Hotel' then 'city'
            when 'Resort Hotel' then 'resort'
        end as hotel_type,

        try_to_boolean(is_canceled) as is_canceled,
        reservation_status,
        try_to_date(reservation_status_date) as reservation_status_date,

        try_to_number(lead_time) as lead_time_days,
        date_from_parts(
            try_to_number(arrival_date_year),
            month(to_date(arrival_date_month || ' 1 2000', 'MMMM DD YYYY')),
            try_to_number(arrival_date_day_of_month)
        ) as arrival_date,

        try_to_number(stays_in_weekend_nights) as weekend_nights,
        try_to_number(stays_in_week_nights) as week_nights,

        try_to_number(adults) as adults,
        try_to_number(nullif(children, 'NA')) as children,  -- 'NA' en el CSV original
        try_to_number(babies) as babies,

        meal as meal_plan,
        nullif(country, 'NULL') as country_code,
        market_segment,
        distribution_channel,
        customer_type,
        deposit_type,
        nullif(trim(agent), 'NULL') as agent_id,
        nullif(trim(company), 'NULL') as company_id,

        try_to_boolean(is_repeated_guest) as is_repeated_guest,
        try_to_number(previous_cancellations) as previous_cancellations,
        try_to_number(previous_bookings_not_canceled) as previous_bookings_not_canceled,

        reserved_room_type,
        assigned_room_type,
        try_to_number(booking_changes) as booking_changes,
        try_to_number(days_in_waiting_list) as days_in_waiting_list,
        try_to_number(required_car_parking_spaces) as required_car_parking_spaces,
        try_to_number(total_of_special_requests) as special_requests,

        -- Average Daily Rate. Los hoteles son portugueses: la moneda es EUR
        try_to_number(adr, 10, 2) as adr_eur,

        _loaded_at
    from source
)

select
    *,
    dateadd(day, -lead_time_days, arrival_date) as booking_date,
    weekend_nights + week_nights as total_nights,
    reserved_room_type != assigned_room_type as is_room_reassigned
from typed
