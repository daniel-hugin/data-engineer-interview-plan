---
tipo: indice
aliases: [índice guía entrevista, guia entrevista, interview guide index, mapa de la guía]
tags: [guia-entrevista]
---
# Índice — guía de respuestas para las entrevistas.

> [!tip] Respuesta rápida
> Empieza por **[[01 - Chuleta rápida]]** — es la página de un vistazo. Vuelve aquí solo para navegar a una nota concreta por herramienta.

Esta guía es para **consultar en vivo** durante la entrevista: síntoma → diagnóstico → solución → por qué, y decisiones con la estructura *contexto → opciones → elijo X porque… → riesgo y mitigación*. Todo enlazado entre sí con enlaces internos (wikilinks).

## Por dónde empezar
1. **[[01 - Chuleta rápida]]** — un vistazo a todo: marcos, problemas, decisiones y conceptos en una página.
2. Si necesitas profundizar, entra en la nota concreta desde las tablas de abajo o desde los enlaces de la chuleta.

---

## SQL

| Problemas | Decisiones | Conceptos |
|---|---|---|
| [[sql-joins-que-multiplican-filas\|La consulta cuenta/suma de más tras un join]] | — | [[fan-out-en-joins]] |
| [[sql-not-in-con-nulls\|NOT IN devuelve 0 filas]] | [[exists-vs-join-anti-join]] | [[qualify]] |
| | [[union-vs-union-all]] | |
| | | [[gaps-and-islands]] |
| | | [[sesionizacion-y-retencion-cohortes]] |
| | | [[scd-tipo-2-con-merge]] |
| | | [[funciones-de-ventana]] |

Comandos: [[sql-y-snowflake]]

## Snowflake

| Problemas | Decisiones | Conceptos |
|---|---|---|
| [[snowflake-query-lenta\|La query tarda muchísimo]] | [[snowflake-vs-bigquery]] | [[arquitectura-tres-capas-snowflake]] |
| [[snowflake-factura-se-duplica\|La factura se ha duplicado]] | [[escalar-warehouse-arriba-vs-fuera]] | [[micro-particiones-y-clustering-keys]] |
| [[snowflake-jwt-token-invalid\|dbt debug falla con "JWT token is invalid"]] | [[copy-into-vs-snowpipe-vs-snowpipe-streaming]] | [[caches-de-snowflake]] |
| | [[streams-tasks-vs-dynamic-tables]] | [[time-travel-fail-safe-zero-copy-cloning]] |
| | | [[data-sharing-y-marketplace]] |
| | | [[multi-cluster-warehouses]] |
| | | [[query-profile-metricas-y-diagnostico]] |

Comandos: [[sql-y-snowflake]]

## dbt

| Problemas | Decisiones | Conceptos |
|---|---|---|
| [[dbt-ci-rompe-modelo-downstream\|Un PR rompe un modelo que nadie tocó]] | [[materializacion-view-table-incremental-ephemeral]] | [[dbt-selectores-y-state]] |
| [[dbt-source-freshness-en-rojo\|Source freshness en rojo/warn]] | [[estrategia-incremental-merge-delete-insert-append]] | [[model-contracts-dbt]] |
| [[dbt-modelo-lento-tabla-creciente\|Un modelo que iba rápido ahora tarda mucho (tabla creció)]] | | [[capas-staging-intermediate-marts]] |
| | [[test-generico-vs-singular]] | [[source-freshness-dbt]] |
| | | [[capa-semantica]] |
| | [[snapshot-timestamp-vs-check]] | [[slim-ci-y-defer]] |

Comandos: [[dbt]]

## Airflow

| Problemas | Decisiones | Conceptos |
|---|---|---|
| [[airflow-dag-no-aparece\|El DAG no aparece]] | [[orquestar-dbt-bashoperator-vs-cosmos-vs-dbt-cloud]] | [[airflow-assets]] |
| [[airflow-tarea-falla-por-credenciales\|La tarea falla al conectar]] | [[assets-vs-cron-vs-sensor]] | [[idempotencia-y-atomicidad]] |
| [[airflow-scheduler-lento-parseo-pesado\|El scheduler va lento]] | | [[data-interval-vs-logical-date]] |
| [[airflow-tarea-atascada-en-queued\|Tarea atascada en queued]] | | [[sensor-deferrable]] |
| [[airflow-datos-incorrectos-sin-error\|Todo verde pero los datos están mal]] | | [[xcom]] |
| [[airflow-reserva-con-dato-antiguo\|Verde pero una reserva tiene datos antiguos]] | | |
| | | [[taskflow-api-vs-operadores-clasicos]] |
| | | [[pools-max-active-tasks-max-active-runs]] |

Comandos: [[airflow]]

## CI/CD (GitHub Actions + Git)

| Decisiones |
|---|
| [[trunk-based-vs-gitflow]] |
| [[oidc-vs-claves-estaticas]] |

Problema relacionado: [[dbt-ci-rompe-modelo-downstream]] · Comandos: [[git-y-github-actions]]

---

## Preguntas tipo casi seguras

Ver la sección dedicada en **[[01 - Chuleta rápida]]** — mapea las 4 preguntas literales de la práctica del día 10 a su nota directa, incluido el orden de comprobación para "un DAG que lleva meses funcionando falla esta noche".

## Todas las notas por carpeta

- **`problemas/`** (14): sql-joins-que-multiplican-filas, sql-not-in-con-nulls, snowflake-query-lenta, snowflake-factura-se-duplica, snowflake-jwt-token-invalid, dbt-ci-rompe-modelo-downstream, dbt-source-freshness-en-rojo, dbt-modelo-lento-tabla-creciente, airflow-dag-no-aparece, airflow-tarea-falla-por-credenciales, airflow-scheduler-lento-parseo-pesado, airflow-tarea-atascada-en-queued, airflow-datos-incorrectos-sin-error, airflow-reserva-con-dato-antiguo
- **`decisiones/`** (14): snowflake-vs-bigquery, escalar-warehouse-arriba-vs-fuera, copy-into-vs-snowpipe-vs-snowpipe-streaming, streams-tasks-vs-dynamic-tables, materializacion-view-table-incremental-ephemeral, estrategia-incremental-merge-delete-insert-append, test-generico-vs-singular, snapshot-timestamp-vs-check, orquestar-dbt-bashoperator-vs-cosmos-vs-dbt-cloud, assets-vs-cron-vs-sensor, trunk-based-vs-gitflow, oidc-vs-claves-estaticas, exists-vs-join-anti-join, union-vs-union-all
- **`conceptos/`** (26): arquitectura-tres-capas-snowflake, micro-particiones-y-clustering-keys, caches-de-snowflake, time-travel-fail-safe-zero-copy-cloning, data-sharing-y-marketplace, multi-cluster-warehouses, query-profile-metricas-y-diagnostico, capa-semantica, fan-out-en-joins, qualify, gaps-and-islands, sesionizacion-y-retencion-cohortes, scd-tipo-2-con-merge, funciones-de-ventana, dbt-selectores-y-state, capas-staging-intermediate-marts, model-contracts-dbt, source-freshness-dbt, slim-ci-y-defer, idempotencia-y-atomicidad, data-interval-vs-logical-date, airflow-assets, sensor-deferrable, xcom, taskflow-api-vs-operadores-clasicos, pools-max-active-tasks-max-active-runs
- **`comandos/`** (4): sql-y-snowflake, dbt, airflow, git-y-github-actions

## Conceptos relacionados
- [[01 - Chuleta rápida]]
