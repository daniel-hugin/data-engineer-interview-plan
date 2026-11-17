---
tipo: decision
herramienta: snowflake
prioridad: media
aliases: [copy into vs snowpipe, ingesta batch vs streaming snowflake, snowpipe streaming, carga de datos snowflake]
tags: [guia-entrevista, snowflake]
---
# COPY INTO vs Snowpipe vs Snowpipe Streaming

> [!tip] Respuesta rápida
> **COPY INTO** para cargas batch orquestadas (cron/Airflow); **Snowpipe** para casi-tiempo-real disparado por eventos de fichero en un stage; **Snowpipe Streaming** para filas individuales de baja latencia sin pasar por ficheros.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| `COPY INTO` | Simple, idempotente vía metadatos de carga (64 días), control total del momento de carga | Latencia = frecuencia del orquestador, no eventos | Carga batch diaria/horaria con un orquestador (Airflow) |
| Snowpipe | Se dispara automáticamente al llegar un fichero al stage (notificación cloud), casi tiempo real sin cron | Overhead de gestión por fichero pequeño, factura por carga (no por tiempo de warehouse) | Ficheros que llegan a intervalos irregulares y quieres baja latencia sin poll |
| Snowpipe Streaming | Filas individuales vía API, sin ficheros intermedios, latencia de segundos | Más complejidad de integración, pensado para volúmenes altos y continuos | CDC o eventos fila a fila de alta frecuencia |

## En travel-dwh-lab
`load_hotel_bookings.sql` usa `COPY INTO raw.hotel_bookings.bookings` sobre el stage `@raw.hotel_bookings.landing`: es una carga única/manual del dataset de Kaggle, así que batch simple es lo correcto. El `COPY INTO` es idempotente porque Snowflake recuerda los ficheros ya cargados (metadatos de carga, retenidos 64 días): reejecutarlo con el mismo fichero carga 0 filas.

## Respuesta modelo
Contexto: necesito decidir cómo ingerir datos en RAW. Opciones: `COPY INTO` batch, Snowpipe por eventos, o Snowpipe Streaming fila a fila. Elijo `COPY INTO` orquestado por Airflow para el BCE y los hoteles porque ambas fuentes llegan en lotes (un fichero CSV, una respuesta de API) y la latencia de "una vez al día" es aceptable; no necesito la complejidad de Snowpipe ni Streaming. El riesgo es que si el volumen o la frecuencia creciera mucho (eventos cada pocos segundos), el cron de Airflow generaría muchos micro-lotes ineficientes; lo mitigaría pasando a Snowpipe Streaming si la frecuencia bajara de minutos a segundos.

## Conceptos relacionados
- [[streams-tasks-vs-dynamic-tables]]
- [[idempotencia-y-atomicidad]]
- [[sql-y-snowflake]]
