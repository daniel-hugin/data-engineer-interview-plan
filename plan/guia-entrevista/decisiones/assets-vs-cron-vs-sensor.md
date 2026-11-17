---
tipo: decision
herramienta: airflow
prioridad: alta
aliases: [airflow assets vs cron, data aware scheduling, sensor vs asset, dataset scheduling airflow]
tags: [guia-entrevista, airflow]
---
# Assets vs cron fijo vs sensor

> [!tip] Respuesta rápida
> **Asset** cuando quiero disparar B justo después de que A produzca datos correctos, sin hora fija; **cron** cuando el origen es predecible por horario; **sensor** cuando dependo de un sistema externo que no puede avisarme con un Asset.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| Asset (planificación por datos) | Disparo inmediato tras un evento correcto, sin horas "mágicas" que adivinar, desacopla productor/consumidor | Solo funciona entre DAGs dentro del mismo Airflow (o con Asset externo explícito) | Un DAG debe correr justo después de que otro produzca datos válidos |
| Cron fijo (`schedule="@daily"`) | Simple, predecible, fácil de razonar | Si el productor se retrasa, el consumidor corre con datos viejos o vacíos | El origen de datos llega a una hora conocida y estable |
| Sensor (poke/deferrable) | Espera activamente una condición externa (fichero, hora, API) | Ocupa un worker (poke) o depende del triggerer (deferrable); añade latencia de polling | La condición de espera no la controla un DAG de Airflow (ej. una hora de publicación externa) |

## En travel-dwh-lab
`ecb_exchange_rates` declara `outlets=[Asset(name="raw.ecb.exchange_rates")]` en su tarea `load`; `dbt_travel_dwh` usa `schedule=[ECB_EXCHANGE_RATES]` con el mismo nombre de Asset. Airflow los enlaza por nombre: dbt solo corre tras una carga **correcta** del BCE, nunca con hora fija ni tras un fallo silencioso.

## Respuesta modelo
Contexto: necesito que dbt se ejecute justo después de que lleguen los tipos de cambio nuevos, sin inventar una hora fija que podría no cuadrar con cuándo publica el BCE. Opciones: cron fijo a una hora estimada, un sensor esperando la publicación, o un Asset. Elijo Asset porque el propio DAG productor ya sabe cuándo terminó con éxito, y encadenar por evento evita tanto esperas innecesarias como construir con datos a medias. El riesgo es que si la carga del BCE falla, dbt simplemente no corre ese día (en vez de correr con datos viejos), lo cual es correcto pero hay que vigilarlo con alertas de fallo en el DAG productor, no solo confiar en el silencio del consumidor.

## Conceptos relacionados
- [[airflow-assets]]
- [[sensor-deferrable]]
- [[streams-tasks-vs-dynamic-tables]]
