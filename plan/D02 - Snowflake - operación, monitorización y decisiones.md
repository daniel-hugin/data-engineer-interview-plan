---
tipo: epica
dia: 2
estado: confirmado
tags: [plan-10-dias, snowflake, monitorizacion, costes]
aliases: [D2, Día 2]
---

# ÉPICA D2 — Snowflake: operación, monitorización y decisiones

← [[D01 - Snowflake - arquitectura y traducción desde BigQuery|Día 1]] · [[00 - Plan 10 días (índice)|Índice]] · Siguiente: [[D03 - SQL I - marco de resolución de problemas|Día 3]] →

**Objetivo del día:** saber operar Snowflake con criterio de coste (cargar datos, diagnosticar una consulta, vigilar el gasto) y poder defender cuándo usarlo y cómo dimensionarlo.

**DoD de la épica:** tickets D2-01 a D2-06 en *Done*. D2-07 es opcional.

---

## D2-01 · Carga de Hotel Booking Demand
**Tipo:** Tarea

**Definition of Done**
- [ ] CSV subido al stage `@raw.hotel_bookings.landing` y `load_hotel_bookings.sql` ejecutado.
- [ ] `select count(*)` sobre `raw.hotel_bookings.bookings` devuelve unas 119.390 filas.
- [ ] Al volver a ejecutar el `COPY INTO`, carga 0 filas, y sabes explicar por qué (metadatos de carga y cuánto tiempo se conservan).
- [ ] `dbt build -s stg_hotel_bookings__bookings` en verde (el test de `adr_eur` puede dar *warn*).

## D2-02 · Diagnóstico con Query Profile y cachés
**Tipo:** Tarea

**Definition of Done**
- [ ] Consulta pesada sobre `SNOWFLAKE_SAMPLE_DATA` (por ejemplo, una agregación sobre `TPCH_SF10.LINEITEM`) en `dev_wh`, con su **Query Profile** abierto.
- [ ] Identificas en el perfil: el operador más costoso, las particiones escaneadas frente a las totales (*pruning*) y si hay *spilling* local o remoto.
- [ ] Repites la consulta con un filtro por fecha y compruebas que mejora el *pruning*.
- [ ] Repites la consulta idéntica y compruebas que la resuelve la **caché de resultados**. Después la desactivas con `alter session set use_cached_result = false` y ves la diferencia.

## D2-03 · Monitorización del gasto
**Tipo:** Tarea

**Definition of Done**
- [ ] Consulta con los **créditos consumidos por warehouse en los últimos 7 días** (`WAREHOUSE_METERING_HISTORY`).
- [ ] Consulta con las 10 consultas más lentas de tu usuario, filtrando por `query_tag` (`QUERY_HISTORY`).
- [ ] Estado del *resource monitor* comprobado: créditos usados frente a la cuota.
- [ ] Sabes explicar la diferencia entre `INFORMATION_SCHEMA` y `SNOWFLAKE.ACCOUNT_USAGE`: latencia, retención y alcance.

## D2-04 · Rendimiento y coste
**Tipo:** Estudio

**DoD:** respondes en voz alta, sin mirar notas:
1. ¿Cuándo escalas un warehouse **hacia arriba** (más tamaño) y cuándo **hacia fuera** (multi-cluster)? Da un síntoma concreto de cada caso.
2. Explica las tres cachés de Snowflake: dónde vive cada una y qué la invalida.
3. ¿Qué pierdes si pones `AUTO_SUSPEND` muy bajo? ¿Y si lo pones muy alto?

## D2-05 · Ingesta y transformación nativas
**Tipo:** Estudio

**DoD:** respondes en voz alta, sin mirar notas:
1. `COPY INTO`, Snowpipe y Snowpipe Streaming: ¿cuándo usarías cada uno?
2. Streams + Tasks frente a Dynamic Tables: ¿qué problema resuelven y cuándo elegirías uno u otro?
3. La carga del BCE podría hacerse con Tasks nativas de Snowflake en lugar de Airflow. ¿Por qué la orquestamos con Airflow? ¿En qué caso cambiarías de opinión?

## D2-06 · «¿Lo usarías como warehouse?»
**Tipo:** Estudio

**DoD:** respondes las dos lecturas de la pregunta con la estructura *contexto → opciones → elijo X porque… → riesgo y mitigación*:
1. **Snowflake como data warehouse:** cuándo lo elegirías frente a BigQuery, y cuándo te quedarías en BigQuery.
2. **Dimensionado de virtual warehouses:** cómo los repartirías en una empresa con ingesta, transformación con dbt y BI, usando tu `setup.sql` como ejemplo.

## D2-07 · *(Opcional)* Conectar Airflow y cargar el histórico del BCE
**Tipo:** Tarea (*stretch*)

**Definition of Done**
- [ ] `svc_airflow.p8` copiado a tu servidor de Airflow y `airflow/.env` completado con la cuenta y la conexión de Snowflake.
- [ ] DAG `ecb_exchange_rates` lanzado a mano con `start_period=2013-01-01`.
- [ ] `raw.ecb.exchange_rates` contiene datos desde 2013 de GBP, USD y CHF.

---

## Notas del día
