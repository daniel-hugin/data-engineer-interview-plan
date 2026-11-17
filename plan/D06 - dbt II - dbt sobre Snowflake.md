---
tipo: epica
dia: 6
estado: confirmado
tags: [plan-10-dias, dbt, snowflake, incremental, snapshot, macros]
aliases: [D6, Día 6]
---

# ÉPICA D6 — dbt II: dbt sobre Snowflake (práctica)

← [[D05 - dbt I - flujo de trabajo y decisiones de modelado|Día 5]] · [[00 - Plan 10 días (índice)|Índice]] · Siguiente: [[D07 - CICD con GitHub Actions|Día 7]] →

**Objetivo del día:** construir las piezas que faltan en el proyecto (un incremental, un mart, un snapshot y una macro) y usar las configuraciones específicas de Snowflake con criterio.

**DoD de la épica:** tickets D6-01 a D6-05 en *Done*, todo en la rama `feat/d6-dbt` **sin fusionar**. D6-06 es opcional.

El incremental se hace sobre los tipos de cambio: los datos de hoteles son estáticos y no enseñarían nada, mientras que los del BCE crecen cada día y pueden corregirse a posteriori. La rama sin fusionar se usará el día 7 para abrir el PR que active la CI.

---

## D6-01 · Modelo incremental con *lookback*
**Tipo:** Práctica

**Definition of Done**
- [ ] `fct_exchange_rates` creado como incremental: estrategia `merge`, `unique_key` (`rate_date`, `quote_currency`) y ventana de *lookback* de 7 días en el filtro `is_incremental()`.
- [ ] Ejecutarlo dos veces seguidas no duplica filas (test `unique_combination_of_columns` en verde).
- [ ] Simulas un dato que llega tarde: relanzas el DAG del BCE para una fecha de hace 3 días y compruebas que el incremental lo recoge.
- [ ] El resultado incremental coincide con un `--full-refresh`: mismas filas y mismos valores.

## D6-02 · Mart de ingresos mensual
**Tipo:** Práctica

**Definition of Done**
- [ ] `mart_revenue_monthly` creado: una fila por mes, tipo de hotel y canal de distribución, con reservas, tasa de cancelación e ingreso en GBP.
- [ ] Granularidad declarada en la descripción y protegida con un test de unicidad sobre la combinación de columnas.
- [ ] Un mes validado a mano contra `fct_bookings`, con el marco de 5 pasos del [[D03 - SQL I - marco de resolución de problemas|día 3]].

## D6-03 · Snapshot (SCD tipo 2)
**Tipo:** Práctica

**Definition of Done**
- [ ] Seed `channel_commissions.csv` (canal de distribución y porcentaje de comisión) y un snapshot sobre él con estrategia `check`.
- [ ] Cambias una comisión en el CSV, vuelves a ejecutar `dbt seed` y `dbt snapshot`, y compruebas `dbt_valid_from` y `dbt_valid_to`.
- [ ] Respondes en voz alta: ¿estrategia `timestamp` o `check`, cuándo cada una? ¿En qué se diferencia un snapshot de dbt del `MERGE` del [[D04 - SQL II - rendimiento y depuración de consultas|día 4]]?

## D6-04 · Configuraciones específicas de Snowflake
**Tipo:** Práctica + estudio

**Definition of Done**
- [ ] **`query_tag`:** asignas uno propio al incremental y lo encuentras en `QUERY_HISTORY`.
- [ ] **`transient`:** compruebas con `show tables` qué tablas son *transient* y cuáles no, y explicas el *trade-off* (sin Fail-safe a cambio de menos coste de almacenamiento).
- [ ] **`snowflake_warehouse`:** el incremental usa un warehouse distinto según el target (expresión Jinja), y explicas cuándo merece la pena asignar warehouse por modelo.
- [ ] **`copy_grants`:** explicas qué problema evita al recrear una tabla.

## D6-05 · Macro propia
**Tipo:** Práctica

**Definition of Done**
- [ ] Macro `limit_data_in_dev(columna, dias)` que, solo fuera de `prod`, filtra a los últimos N días.
- [ ] Usada en un modelo; `dbt compile` muestra SQL distinto con `--target dev` y `--target prod`.
- [ ] Explicas en voz alta para qué sirve en un equipo real (coste y velocidad en desarrollo) y qué riesgo tiene (un test que pasa en dev y falla en prod).

## D6-06 · *(Opcional)* Documentación y *exposures*
**Tipo:** Tarea (*stretch*)

**Definition of Done**
- [ ] Todas las columnas de los marts tienen descripción.
- [ ] *Exposure* declarada para un dashboard hipotético que consume `mart_revenue_monthly`, visible en el grafo de `dbt docs`.

---

## Notas del día
