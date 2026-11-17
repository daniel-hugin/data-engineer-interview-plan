---
tipo: chuleta
aliases: [chuleta rápida, cheat sheet, resumen entrevista, respuestas rápidas, quick reference]
tags: [guia-entrevista, resumen]
---
# Chuleta rápida

> [!tip] Cómo usar esta página
> Guia rapida para ensayar respuestas. En esta pagina tienes algunos conceptos clave que pueden funcionar como palanca para desarrollar todas las respuestas. Si necesitas más detalle, sigue el enlace a la nota completa con diagnóstico, código y "cómo contarlo".

## Marcos a aplicar siempre

**Cualquier pregunta de SQL** (marco del día 3):

1. **Granularidad del resultado** — ¿una fila por qué?
2. **Granularidad de las entradas y fan-out** — ¿algún join puede multiplicar filas?
3. **CTEs** — descompón, no todo en un `SELECT`.
4. **Casos borde** — NULLs, duplicados, fechas límite.
5. **Validar con conteos** — antes/después del join, por grupo.

**Cualquier pregunta de decisión debe seguir el siguiente patrón**: **Contexto → Opciones → Elección justificada… → Riesgo y cómo lo mitigo.**

---

## Problemas — síntoma → causa más probable

- **[[sql-joins-que-multiplican-filas|La consulta cuenta/suma de más tras un join]]:** fan-out — el lado derecho no es único para la clave. Cuenta filas antes/después.
- **[[sql-not-in-con-nulls|NOT IN devuelve 0 filas]]:** un NULL en la subconsulta vuelve `UNKNOWN` toda la comparación. Usa `NOT EXISTS` o `LEFT JOIN ... IS NULL`.
- **[[snowflake-query-lenta|La query tarda muchísimo]]:** abre el Query Profile — casi siempre pérdida de *pruning*, *spilling* o cola por concurrencia. Diagnostica antes de tocar el tamaño del warehouse.
- **[[snowflake-factura-se-duplica|La factura se ha duplicado]]:** agrupa `WAREHOUSE_METERING_HISTORY` por día/warehouse — `AUTO_SUSPEND` alto, warehouse subido de tamaño sin bajar, o query nueva escaneando de más.
- **[[dbt-ci-rompe-modelo-downstream|Un PR rompe un modelo que nadie tocó]]:** normal — `state:modified+` construye también los descendientes del modelo cambiado.
- **[[dbt-source-freshness-en-rojo|Source freshness en rojo/warn]]:** primero descarta fin de semana/festivo (el BCE no publica); si no, el DAG de carga falló.
- **[[airflow-dag-no-aparece|El DAG no aparece en la UI]]:** casi siempre error de importación — `airflow dags list-import-errors` primero.
- **[[airflow-tarea-falla-por-credenciales|La tarea falla al conectar con Snowflake]]:** `snowflake_conn_id` mal nombrado, permisos del `.p8`, o fingerprint público/privado que no coincide (`JWT token is invalid`).
- **[[airflow-scheduler-lento-parseo-pesado|El scheduler va lento]]:** código a nivel de módulo (HTTP, BBDD, `sleep`) ejecutándose en cada parseo, no dentro de una tarea.
- **[[airflow-tarea-atascada-en-queued|Tarea atascada en queued/scheduled]]:** mira los **pools** antes que el executor — un pool pequeño compartido se llena rápido.
- **[[airflow-datos-incorrectos-sin-error|Todo verde pero los datos están mal]]:** el más peligroso, sin alerta — `now()` en vez de `data_interval_start`/`end` en un backfill.

## Decisiones — un clic de la respuesta

- **[[snowflake-vs-bigquery|Snowflake vs BigQuery]]:** Snowflake para aislar cargas con warehouses y controlar coste/concurrencia; BigQuery para cero gestión de infra ya viviendo en GCP.
- **[[escalar-warehouse-arriba-vs-fuera|Escalar arriba vs hacia fuera]]:** arriba si una query pesada va lenta sola; hacia fuera si muchas queries concurrentes se encolan aunque cada una rinda bien.
- **[[copy-into-vs-snowpipe-vs-snowpipe-streaming|COPY INTO vs Snowpipe vs Streaming]]:** `COPY INTO` para batch orquestado; Snowpipe para casi-tiempo-real por eventos de stage; Streaming para filas individuales de baja latencia.
- **[[streams-tasks-vs-dynamic-tables|Streams+Tasks vs Dynamic Tables]]:** Streams+Tasks si necesitas lógica explícita y control del trigger; Dynamic Tables si quieres declarar el resultado y que Snowflake gestione el refresco.
- **[[materializacion-view-table-incremental-ephemeral|view/table/incremental/ephemeral]]:** view para staging; table para marts consultados mucho; incremental si la tabla crece mucho; ephemeral para un CTE intermedio de usar y tirar.
- **[[estrategia-incremental-merge-delete-insert-append|merge vs delete+insert vs append vs microbatch]]:** merge si hay upsert por `unique_key`; delete+insert para reemplazar rangos completos; append solo si el dato nunca cambia; microbatch para ventanas de tiempo grandes.
- **[[test-generico-vs-singular|Test genérico vs singular]]:** genérico para reglas reutilizables (`unique`, `not_null`); singular para una regla de negocio puntual de un modelo.
- **[[snapshot-timestamp-vs-check|Snapshot timestamp vs check]]:** `timestamp` si hay columna de actualización fiable; `check` si no la hay y hay que comparar columnas.
- **[[orquestar-dbt-bashoperator-vs-cosmos-vs-dbt-cloud|BashOperator vs Cosmos vs dbt Cloud]]:** BashOperator si el proyecto es pequeño; Cosmos si quieres reintentos/logs por modelo; dbt Cloud si no quieres gestionar infraestructura de ejecución.
- **[[assets-vs-cron-vs-sensor|Assets vs cron vs sensor]]:** Asset para disparar justo tras datos listos sin hora fija; cron si el origen es predecible por horario; sensor si dependes de un sistema externo sin Asset.
- **[[trunk-based-vs-gitflow|Trunk-based vs GitFlow]]:** trunk-based para datos con despliegue continuo y PRs cortos; GitFlow para releases de producto largas y coordinadas.
- **[[oidc-vs-claves-estaticas|OIDC vs claves estáticas]]:** OIDC si puedes montar un *identity provider* de confianza y quieres eliminar secretos de larga vida; claves estáticas si el coste de migrar no compensa todavía (es lo que hay hoy en el repo).

## Preguntas tipo casi seguras

Las cuatro de la práctica del día 10, con su nota directa:

1. *"Migramos de BigQuery a Snowflake, ¿qué te preocupa primero?"* → [[snowflake-vs-bigquery]]
2. *"La factura de Snowflake se ha duplicado este mes, ¿qué haces?"* → [[snowflake-factura-se-duplica]]
3. *"¿Cosmos o un único `dbt build` en Airflow?"* → [[orquestar-dbt-bashoperator-vs-cosmos-vs-dbt-cloud]]
4. *"Un DAG que lleva meses funcionando falla esta noche, guíame por tu proceso."* → orden de comprobación: [[airflow-dag-no-aparece]] (¿importa?) → [[airflow-tarea-falla-por-credenciales]] (¿falla una tarea?) → [[airflow-tarea-atascada-en-queued]] (¿no arranca?) → [[airflow-datos-incorrectos-sin-error]] (¿verde pero mal?). Dilo en ese orden: de lo que cambió (código/credenciales) a lo que se agotó (pools/recursos) a lo silencioso (datos).

## Conceptos: definición de 10 segundos

**SQL** — [[fan-out-en-joins]]: join que multiplica filas sin dar error, por clave no única del lado derecho. [[qualify]]: filtra sobre una función de ventana sin CTE extra. [[gaps-and-islands]]: `fecha - row_number()` constante dentro de una racha. [[scd-tipo-2-con-merge]]: un `MERGE` no puede cerrar y abrir la misma clave a la vez; se resuelve duplicándola en una tabla de cambios. [[funciones-de-ventana]]: `ROW_NUMBER` sin huecos, `RANK` con huecos, `DENSE_RANK` sin huecos tras empate.

**Snowflake** — [[arquitectura-tres-capas-snowflake]]: storage / compute (warehouses) / cloud services, cada capa escala y se paga aparte. [[micro-particiones-y-clustering-keys]]: bloques ~16MB con min/max por columna; *pruning* los descarta, *clustering key* reordena físicamente. [[caches-de-snowflake]]: metadata, resultados (24h), disco local del warehouse (se pierde al suspender). [[time-travel-fail-safe-zero-copy-cloning]]: ventana configurable / +7 días solo soporte / clon copy-on-write sin duplicar storage.

**dbt** — [[dbt-selectores-y-state]]: `modelo+` descendientes, `+modelo` ancestros, `state:modified+` compara contra un manifest. [[slim-ci-y-defer]]: construye solo lo seleccionado, resuelve el resto leyendo producción vía `--defer`. [[model-contracts-dbt]]: declara `data_type` por columna, falla explícito si cambia. [[source-freshness-dbt]]: compara `loaded_at_field` contra ahora con umbrales warn/error.

**Airflow** — [[airflow-assets]]: DAG productor declara `outlets`, consumidor se planifica con `schedule=[Asset]`, enlazados por nombre. [[idempotencia-y-atomicidad]]: mismo resultado al repetir / todo-o-nada si falla a mitad. [[data-interval-vs-logical-date]]: el intervalo es el rango real a procesar, nunca uses `now()` para eso. [[sensor-deferrable]]: libera el slot del worker mientras espera, lo gestiona el *triggerer*. [[xcom]]: valores pequeños entre tareas vía metastore, no datasets grandes. [[taskflow-api-vs-operadores-clasicos]]: `@task` para Python puro, operador clásico para procesos externos. [[pools-max-active-tasks-max-active-runs]]: pool cruza DAGs, `max_active_tasks` dentro de un DAG, `max_active_runs` entre ejecuciones del mismo DAG.

## Comandos de emergencia


| Si te preguntan...                        | Comando                                                                 |
| ----------------------------------------- | ----------------------------------------------------------------------- |
| ¿Por qué va lenta esta query?           | Query Profile +`QUERY_HISTORY` — ver [[sql-y-snowflake]]               |
| ¿Cómo sabes qué construirá la CI?     | `dbt ls -s state:modified+ --state state` — ver [[dbt]]                |
| ¿El DAG no aparece, por dónde empiezas? | `airflow dags list-import-errors` — ver [[airflow]]                    |
| ¿Cómo evitas push directo a main?       | Branch protection + checks obligatorios — ver [[git-y-github-actions]] |

## Conceptos relacionados

- [[00 - Índice guía entrevista]]
