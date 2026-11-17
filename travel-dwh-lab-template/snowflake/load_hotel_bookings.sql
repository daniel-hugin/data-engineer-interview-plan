-- =====================================================================
-- Carga única del dataset Hotel Booking Demand en RAW.
-- 1) Descarga hotel_bookings.csv (Kaggle) a ./data/
-- 2) Sube el fichero al stage:
--      - Snowflake CLI:  snow sql -q "put file://data/hotel_bookings.csv @raw.hotel_bookings.landing auto_compress=true"
--      - o desde Snowsight: Data > RAW > HOTEL_BOOKINGS > Stages > LANDING > + Files
-- 3) Ejecuta este script.
-- Es idempotente: COPY INTO no recarga ficheros ya cargados (load metadata, 64 días).
-- =====================================================================
use role loader;
use warehouse loading_wh;

list @raw.hotel_bookings.landing;

copy into raw.hotel_bookings.bookings
from (
    select
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
        $21, $22, $23, $24, $25, $26, $27, $28, $29, $30,
        $31, $32,
        metadata$filename,
        metadata$file_row_number,
        current_timestamp()::timestamp_ntz
    from @raw.hotel_bookings.landing
)
pattern = '.*hotel_bookings.*[.]csv.*'
on_error = abort_statement;

-- Comprobación rápida: deberían ser ~119.390 filas
select count(*) as n_rows, count(distinct _source_file) as n_files
from raw.hotel_bookings.bookings;
