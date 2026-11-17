---
tipo: comandos
herramienta: snowflake
aliases: [chuleta snowflake, comandos sql snowflake, snowflake cheatsheet, diagnóstico query snowflake]
tags: [guia-entrevista, snowflake]
---
# Chuleta de comandos: SQL y Snowflake

> [!tip] Respuesta rápida
> Úsala cuando te pregunten "¿cómo verificarías/diagnosticarías X en Snowflake?". Cubre roles/warehouses, por qué una query va lenta y cómo verificar una carga.

## Coste y warehouses
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `show warehouses;` | Lista warehouses, tamaño, auto_suspend | Verificar config de `setup.sql` (XS, auto_suspend=60) |
| `show resource monitors;` | Lista resource monitors y umbrales | Comprobar `lab_monthly_monitor` (75%/100%/110%) |
| `show roles like '%er'` | Roles cuyo nombre acaba en "er" | Ver `loader`, `transformer`, `developer` de un vistazo |
| `show schemas in database raw;` | Esquemas de una base | Ver `hotel_bookings`, `ecb` en RAW |
| `desc user <usuario>;` | Detalle de un usuario (rol default, warehouse default) | Verificar `svc_airflow`/`svc_ci` tras `setup.sql` |
| `show grants to user <usuario>;` | Roles concedidos a un usuario | Confirmar que `svc_ci` tiene `developer` |
| Créditos por warehouse, 7 días: ver abajo | Consumo real | Pregunta típica: "¿cómo verías qué warehouse come más crédito?" |

```sql
select
    warehouse_name,
    sum(credits_used) as credits_7d
from snowflake.account_usage.warehouse_metering_history
where start_time >= dateadd('day', -7, current_timestamp())
group by warehouse_name
order by credits_7d desc;
```

## Diagnóstico de una query
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `alter session set use_cached_result = false;` | Desactiva result cache | Para medir tiempo real, sin que el cache falsee el benchmark |
| `explain <query>;` | Plan de ejecución sin ejecutar | Ver qué operadores y en qué orden, antes de lanzarla |
| Top 10 queries lentas por tag: ver abajo | Encuentra la query concreta | Cuando alguien reporta "esto va lento" y tienes `query_tag` |
| **Query Profile en Snowsight** | Vista gráfica de ejecución ya corrida | Mirar: **operador más costoso** (% tiempo), **particiones escaneadas/totales** (si escanea casi todas = falta filtro o clustering), **spilling a local/remote disk** (si hay spilling = warehouse demasiado pequeño para esa query) |

```sql
select
    query_id, query_text, total_elapsed_time, warehouse_name
from snowflake.account_usage.query_history
where query_tag = 'mi_tag'
order by total_elapsed_time desc
limit 10;
```

> [!note] `INFORMATION_SCHEMA` vs `ACCOUNT_USAGE`
> `INFORMATION_SCHEMA` es **en tiempo real** pero solo guarda ~7 días y solo ve lo del contexto de base actual. `ACCOUNT_USAGE` tiene **latencia de hasta 45-90 min** pero retiene **1 año** y ve todo la cuenta. Para auditoría histórica usa `ACCOUNT_USAGE`; para "qué está pasando ahora mismo", `INFORMATION_SCHEMA`.

## Carga de datos
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `list @raw.hotel_bookings.landing;` | Fichero(s) en el stage | Antes del `copy into`, para confirmar que el CSV subió |
| `copy into ... on_error = abort_statement` | Carga masiva desde stage a tabla | Carga real de `load_hotel_bookings.sql` (ver abajo) |

```sql
copy into raw.hotel_bookings.bookings
from (
    select $1, $2, $3, /* ... */ $31, $32,
        metadata$filename, metadata$file_row_number, current_timestamp()::timestamp_ntz
    from @raw.hotel_bookings.landing
)
pattern = '.*hotel_bookings.*[.]csv.*'
on_error = abort_statement;
```
`COPY INTO` es idempotente: no recarga ficheros ya cargados (load metadata, 64 días de retención).

## Conceptos relacionados
- [[snowflake-query-lenta]]
- [[snowflake-factura-se-duplica]]
- [[caches-de-snowflake]]
- [[micro-particiones-y-clustering-keys]]
