-- =====================================================================
-- travel-dwh-lab · setup de Snowflake
-- Ejecutar una vez (Snowsight o `snow sql -f snowflake/setup.sql`).
-- Cada bloque usa el rol mínimo necesario, no ACCOUNTADMIN para todo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Control de costes (requiere ACCOUNTADMIN)
-- ---------------------------------------------------------------------
use role accountadmin;

create resource monitor if not exists lab_monthly_monitor
    with credit_quota = 20
    frequency = monthly
    start_timestamp = immediately
    triggers
        on 75 percent do notify
        on 100 percent do suspend
        on 110 percent do suspend_immediate;

-- ---------------------------------------------------------------------
-- 2. Roles (jerarquía funcional) · USERADMIN / SECURITYADMIN
-- ---------------------------------------------------------------------
use role useradmin;

create role if not exists loader;       -- escribe en RAW (Airflow)
create role if not exists transformer;  -- lee RAW, construye ANALYTICS (dbt prod)
create role if not exists developer;    -- lee RAW y ANALYTICS, construye ANALYTICS_DEV (dbt dev y CI)

use role securityadmin;
grant role loader to role sysadmin;
grant role transformer to role sysadmin;
grant role developer to role sysadmin;

-- ---------------------------------------------------------------------
-- 3. Warehouses: uno por tipo de carga, XS, auto-suspend agresivo
-- ---------------------------------------------------------------------
use role sysadmin;

create warehouse if not exists loading_wh
    warehouse_size = xsmall auto_suspend = 60 auto_resume = true initially_suspended = true
    comment = 'Ingesta (Airflow)';
create warehouse if not exists transforming_wh
    warehouse_size = xsmall auto_suspend = 60 auto_resume = true initially_suspended = true
    comment = 'dbt producción';
create warehouse if not exists dev_wh
    warehouse_size = xsmall auto_suspend = 60 auto_resume = true initially_suspended = true
    comment = 'dbt desarrollo y CI';

use role accountadmin;
alter warehouse loading_wh set resource_monitor = lab_monthly_monitor;
alter warehouse transforming_wh set resource_monitor = lab_monthly_monitor;
alter warehouse dev_wh set resource_monitor = lab_monthly_monitor;

use role securityadmin;
grant usage on warehouse loading_wh to role loader;
grant usage on warehouse transforming_wh to role transformer;
grant usage on warehouse dev_wh to role developer;

-- ---------------------------------------------------------------------
-- 4. Bases de datos
--    RAW            -> datos tal cual llegan (propiedad de LOADER)
--    ANALYTICS      -> producción (propiedad de TRANSFORMER)
--    ANALYTICS_DEV  -> esquemas de desarrollo y de CI por PR
-- ---------------------------------------------------------------------
use role sysadmin;

create database if not exists raw;
create database if not exists analytics;
create database if not exists analytics_dev;

create schema if not exists raw.hotel_bookings;
create schema if not exists raw.ecb;

use role securityadmin;

-- LOADER: escribe en RAW
grant usage on database raw to role loader;
grant usage, create table, create stage, create file format on schema raw.hotel_bookings to role loader;
grant usage, create table on schema raw.ecb to role loader;

-- TRANSFORMER: lee RAW, es dueño de ANALYTICS
grant usage on database raw to role transformer;
grant usage on all schemas in database raw to role transformer;
grant select on future tables in database raw to role transformer;
grant all on database analytics to role transformer;

-- DEVELOPER: lee RAW y producción (necesario para --defer en CI), construye en ANALYTICS_DEV
grant usage on database raw to role developer;
grant usage on all schemas in database raw to role developer;
grant select on future tables in database raw to role developer;
grant usage on database analytics to role developer;
grant usage on future schemas in database analytics to role developer;
grant select on future tables in database analytics to role developer;
grant select on future views in database analytics to role developer;
grant all on database analytics_dev to role developer;

-- ---------------------------------------------------------------------
-- 5. Tablas RAW (las crea LOADER, que queda como propietario)
-- ---------------------------------------------------------------------
use role loader;
use warehouse loading_wh;

create table if not exists raw.ecb.exchange_rates (
    rate_date       date          not null,
    currency        varchar(3)    not null,  -- divisa cotizada (GBP, USD, CHF...)
    base_currency   varchar(3)    not null,  -- siempre EUR en la API del BCE
    rate            number(18, 6) not null,  -- unidades de `currency` por 1 EUR
    loaded_at       timestamp_ntz not null
);

-- Todo como VARCHAR: RAW guarda lo que llega; los tipos y la limpieza van en dbt staging.
create table if not exists raw.hotel_bookings.bookings (
    hotel                          varchar,
    is_canceled                    varchar,
    lead_time                      varchar,
    arrival_date_year              varchar,
    arrival_date_month             varchar,
    arrival_date_week_number       varchar,
    arrival_date_day_of_month      varchar,
    stays_in_weekend_nights        varchar,
    stays_in_week_nights           varchar,
    adults                         varchar,
    children                       varchar,
    babies                         varchar,
    meal                           varchar,
    country                        varchar,
    market_segment                 varchar,
    distribution_channel           varchar,
    is_repeated_guest              varchar,
    previous_cancellations         varchar,
    previous_bookings_not_canceled varchar,
    reserved_room_type             varchar,
    assigned_room_type             varchar,
    booking_changes                varchar,
    deposit_type                   varchar,
    agent                          varchar,
    company                        varchar,
    days_in_waiting_list           varchar,
    customer_type                  varchar,
    adr                            varchar,
    required_car_parking_spaces    varchar,
    total_of_special_requests      varchar,
    reservation_status             varchar,
    reservation_status_date        varchar,
    -- metadatos de carga
    _source_file                   varchar,
    _source_row_number             number,
    _loaded_at                     timestamp_ntz
);

create file format if not exists raw.hotel_bookings.csv_with_header
    type = csv
    skip_header = 1
    field_optionally_enclosed_by = '"'
    null_if = ('')
    empty_field_as_null = true;

create stage if not exists raw.hotel_bookings.landing
    file_format = raw.hotel_bookings.csv_with_header;

-- Las tablas de RAW ya existían antes de los FUTURE GRANTS de la base: se conceden explícitamente
use role securityadmin;
grant select on all tables in database raw to role transformer;
grant select on all tables in database raw to role developer;

-- ---------------------------------------------------------------------
-- 6. Usuarios de servicio (autenticación por par de claves, sin contraseña)
--    Genera las claves con: scripts/generate_keypair.sh <nombre>
--    y pega aquí el contenido de la pública SIN cabecera ni pie.
-- ---------------------------------------------------------------------
use role useradmin;

create user if not exists svc_airflow
    type = service
    default_role = loader
    default_warehouse = loading_wh
    rsa_public_key = '<PEGA_AQUI_LA_CLAVE_PUBLICA_DE_svc_airflow>'
    comment = 'Airflow: ingesta + dbt prod';

create user if not exists svc_ci
    type = service
    default_role = developer
    default_warehouse = dev_wh
    rsa_public_key = '<PEGA_AQUI_LA_CLAVE_PUBLICA_DE_svc_ci>'
    comment = 'GitHub Actions: dbt CI';

use role securityadmin;
grant role loader to user svc_airflow;
grant role transformer to user svc_airflow;
grant role developer to user svc_ci;
-- Tu usuario personal también como developer (sustituye el nombre):
-- grant role developer to user <TU_USUARIO>;
