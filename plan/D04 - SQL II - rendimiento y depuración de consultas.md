---
tipo: epica
dia: 4
estado: confirmado
tags: [plan-10-dias, sql, rendimiento, snowflake, scd2]
aliases: [D4, Día 4]
---

# ÉPICA D4 — SQL II: rendimiento y depuración de consultas

← [[D03 - SQL I - marco de resolución de problemas|Día 3]] · [[00 - Plan 10 días (índice)|Índice]] · Siguiente: [[D05 - dbt I - flujo de trabajo y decisiones de modelado|Día 5]] →

**Objetivo del día:** detectar por qué una consulta devuelve datos incorrectos o va lenta, saber corregirlo, e implementar un SCD tipo 2 con SQL puro.

**DoD de la épica:** los seis tickets (D4-01 a D4-06) en *Done*.

**Aviso para D4-03:** la tabla de reservas (unas 119.000 filas) cabe en una o dos micro-particiones, así que no permite ver el *pruning*. Ese ticket usa `SNOWFLAKE_SAMPLE_DATA`, con tablas de cientos de millones de filas.

---

## D4-01 · Joins que multiplican filas
**Tipo:** Práctica

**Definition of Done**
- [ ] Reproduces un *fan-out* real con tus datos: une las reservas con `int_exchange_rates__daily` **sin** filtrar la divisa y comprueba que cada reserva aparece tres veces (GBP, USD, CHF) y que el ingreso total se triplica. Si no cargaste el BCE en D2-07, hazlo con una tabla de ejemplo (`VALUES`) que tenga claves duplicadas.
- [ ] Lo detectas con conteos antes y después del join, y lo corriges.
- [ ] Explicas en voz alta qué test de dbt habría evitado el problema y en qué modelo lo pondrías.

## D4-02 · `EXISTS`, `IN`, `JOIN` y la trampa de `NOT IN`
**Tipo:** Práctica + estudio

**Definition of Done**
- [ ] Escribes el mismo *anti-join* de tres formas: `NOT EXISTS`, `NOT IN` y `LEFT JOIN … WHERE … IS NULL`.
- [ ] Demuestras con un ejemplo que `NOT IN` devuelve **cero filas** cuando la subconsulta contiene un `NULL`.
- [ ] Respondes en voz alta: ¿cuándo usarías `EXISTS` en lugar de un `JOIN` para filtrar?
- [ ] Respondes en voz alta: ¿por qué `UNION` puede ser mucho más lento que `UNION ALL`, y cuándo necesitas el primero?

## D4-03 · Filtrado temprano, *pruning* y plan de ejecución
**Tipo:** Práctica

**Definition of Done**
- [ ] Sobre `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.LINEITEM`, comparas dos versiones de la misma consulta: filtrando por un rango de fechas sobre la columna tal cual, y envolviendo la columna en una función o una conversión.
- [ ] En el Query Profile de cada una anotas las particiones escaneadas frente a las totales.
- [ ] Ejecutas `EXPLAIN` sobre una de ellas y sabes leer los operadores principales.
- [ ] Explicas en voz alta por qué filtrar pronto, sobre columnas «limpias», ayuda al *pruning*, y qué papel juegan las *clustering keys*.

## D4-04 · SCD tipo 2 con `MERGE`
**Tipo:** Práctica

**Definition of Done**
- [ ] Creas una dimensión pequeña con `valid_from`, `valid_to` e `is_current`, y la cargas con una primera versión de los datos (`VALUES`).
- [ ] Aplicas una segunda carga con cambios, altas y registros sin cambios mediante un `MERGE`. Resultado: el registro modificado tiene su fila antigua cerrada y una nueva vigente; el alta aparece; lo que no cambió queda intacto.
- [ ] Repetir la segunda carga **no cambia nada**: es idempotente.
- [ ] Explicas en voz alta por qué un único `MERGE` no puede cerrar la fila antigua e insertar la nueva para la misma clave, y cómo lo resuelve el truco de la tabla de cambios con la clave duplicada.

## D4-05 · «La consulta pasó de 2 a 40 minutos»
**Tipo:** Estudio

**DoD:** respondes en voz alta con un proceso ordenado de lo más barato de comprobar a lo más caro, que cubra al menos cinco hipótesis y diga dónde mira cada una.

| Hipótesis | Dónde lo miras |
|---|---|
| Cambio en el SQL o en el modelo | Historial de Git, `QUERY_HISTORY` (comparar `query_text`) |
| Crecimiento del volumen de datos | `QUERY_HISTORY` (bytes escaneados), conteos de la tabla |
| Pérdida de *pruning* | Query Profile (particiones escaneadas / totales) |
| *Spilling* a disco | Query Profile (bytes spilled local / remoto) |
| Cola por concurrencia en el warehouse | `QUERY_HISTORY` (`queued_overload_time`) |
| Cambio de tamaño del warehouse | `QUERY_HISTORY` (`warehouse_size`), historial de `ALTER WAREHOUSE` |
| Caché perdida | `QUERY_HISTORY` (uso de caché de resultados), `AUTO_SUSPEND` |

## D4-06 · Práctica cronometrada
**Tipo:** Práctica

**Definition of Done**
- [ ] 5 ejercicios de nivel medio o difícil, con un máximo de **20 minutos** cada uno.
- [ ] Al menos 4 de los 5 resueltos dentro del tiempo.
- [ ] Registro en la tabla de abajo.

| # | Ejercicio | Patrón | Tiempo | ¿En tiempo? | Error | Caso borde |
|---|---|---|---|---|---|---|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| 4 | | | | | | |
| 5 | | | | | | |

---

## Notas del día
