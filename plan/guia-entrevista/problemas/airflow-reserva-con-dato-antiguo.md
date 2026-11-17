---
tipo: problema
herramienta: airflow
prioridad: alta
aliases: [dato antiguo sin error, stale data airflow, reserva desactualizada, race condition commit snowflake, recuperar datos con time travel, falta una modificacion]
tags: [guia-entrevista, airflow, snowflake]
---
# El proceso termina en verde pero algunas reservas tienen datos antiguos

> [!tip] Respuesta rápida
> Distinto del caso de fechas duplicadas ([[airflow-datos-incorrectos-sin-error]]): aquí el síntoma es por **fila concreta**, no por rango. Sospechoso principal: un `INSERT` sin upsert dejando convivir la versión vieja y la nueva, o una condición de carrera entre ejecuciones donde gana quien hace *commit* último, no quien tiene el dato más reciente.

## Hipótesis (de más barata a más cara de comprobar)
1. **`INSERT` sin upsert**: la tarea de carga inserta sin `DELETE`/`MERGE` previo por clave — conviven fila vieja y nueva para la misma reserva, y cualquier lectura sin dedup puede devolver cualquiera de las dos.
2. **Condición de carrera entre ejecuciones solapadas**: dos runs (backfill mal planificado, `max_active_runs` sin fijar, o un reintento) escriben la misma reserva; en Snowflake gana quien hace *commit* primero ([[arquitectura-tres-capas-snowflake|concurrencia optimista]]), no quien tiene el dato más reciente — si el run con datos viejos comitea después, sobrescribe al bueno.
3. **Snapshot desactualizado por timing con la fuente**: la extracción leyó el sistema origen justo antes de que se confirmara el cambio real — no es un fallo de código, es un problema de cuándo se dispara la extracción.
4. **El downstream no se disparó**: el RAW está bien, pero el modelo transformado que consulta el usuario no se reconstruyó — típicamente por un nombre de [[airflow-assets|Asset]] que no coincide exactamente entre productor y consumidor.
5. **XCom obsoleto en un reintento**: una tarea reintentada reutiliza estado de una ejecución anterior en vez de recalcular desde cero.

## Diagnóstico paso a paso
```sql
-- 1. ¿hay duplicados para la reserva afectada, o solo una fila con timestamp viejo?
select id_reserva, *, _loaded_at
from raw.reservas
where id_reserva = '<la_reserva_afectada>'
order by _loaded_at desc;
```
```bash
# 2. ¿hubo ejecuciones solapadas del mismo DAG?
airflow dags list-runs -d <dag_id> --no-backfill

# 3. ¿la tarea hace upsert real o INSERT suelto?
grep -n "insert\|merge\|delete" airflow/dags/<dag>.py
```
```sql
-- 4. si el RAW ya está bien, ¿el downstream corrió después de la carga?
select max(start_time) from table(information_schema.query_history())
where query_tag = 'travel_dwh_prod';
-- comparar contra la hora de la última carga RAW
```
Si nada de lo anterior explica el caso, el último recurso es mirar logs/XCom de esa ejecución concreta en la UI de Airflow (reintentos, payload recibido).

## Solución
- **`INSERT` sin upsert** → `DELETE` + `INSERT` transaccional por clave (patrón ya usado en `ecb_exchange_rates.py`) o `MERGE` explícito — hace la carga [[idempotencia-y-atomicidad|idempotente]].
- **Carrera entre runs** → `max_active_runs=1` en el DAG; si el solape es entre DAGs distintos sobre la misma tabla, serializarlos con una dependencia explícita o un *pool* de 1 slot.
- **Timing con la fuente** → sensor [[sensor-deferrable|deferrable]] que espere una señal real de "disponible", no una hora fija.
- **Downstream no disparado** → corregir el nombre del `Asset` para que coincida exactamente, y forzar un *trigger* manual del consumidor (el fix no reconstruye retroactivamente lo ya servido mal).
- **XCom obsoleto** → eliminar cualquier estado compartido entre ejecuciones que no pase explícitamente por el contexto/XCom de esa tarea.

## Recuperación de los datos ya afectados
Primero, lo más barato: si el sistema origen todavía tiene el valor correcto, re-extraer para esas reservas concretas basta — no hace falta recuperación forense.

Si el valor correcto ya no está en origen, usar [[time-travel-fail-safe-zero-copy-cloning|Time Travel]] para recuperarlo de Snowflake, **sin revertir toda la tabla** (puede haber datos nuevos legítimos desde entonces):
```sql
select *
from raw.reservas at(offset => -3600)  -- o before(statement => '<query_id>')
where id_reserva in (...);
-- aplicar selectivamente con MERGE solo sobre esas filas
```
Limitación: solo dentro de la ventana de retención configurada — pasado ese plazo, Time Travel no sirve.

Si es contaminación por duplicados (hipótesis 1) y no pérdida real, no hace falta Time Travel — solo deduplicar con `QUALIFY ROW_NUMBER() OVER (PARTITION BY id_reserva ORDER BY _loaded_at DESC) = 1` y borrar lo obsoleto.

## Cómo saber que no faltan modificaciones (completitud, no solo duplicados)
Detectar "faltan filas" es más difícil que detectar duplicados porque no hay nada en la propia tabla que avise de un hueco — hace falta un punto de comparación externo:
- **Comparar el conjunto de IDs** (no solo el conteo — un conteo puede coincidir por casualidad) entre lo modificado en origen y lo cargado, con un `EXCEPT`, si hay acceso de consulta al origen o a su log de cambios.
- Si el origen tiene una secuencia/watermark incremental, comprobar que no hay huecos en la secuencia capturada (mismo patrón que [[gaps-and-islands]], aplicado a un `change_id` en vez de a fechas).
- Reconciliación por agregado (suma de importes, conteo de reservas activas) cuando no hay acceso fila a fila al origen — avisa de que falta algo, aunque no diga exactamente qué.

## Validación de que un fix es correcto
- Probar la tarea aislada con `airflow tasks test <dag_id> <task_id> <fecha>`.
- Repetir la prueba de idempotencia: ejecutar la carga corregida dos veces sobre el mismo rango y comparar que el resultado es idéntico.
- Relanzar las queries de diagnóstico originales y confirmar que ya no detectan el síntoma.
- `dbt build`/`dbt test` completo para confirmar que el fix no rompió nada downstream.
- Vigilar los próximos runs **programados** (no solo la prueba manual) — una prueba aislada no reproduce condiciones de carrera reales del scheduler.

## Cómo contarlo
Una reserva concreta mostraba un valor antiguo aunque el DAG había terminado en verde. Primero comprobé si había filas duplicadas para esa clave (no las había) y comparé el `_loaded_at` de la fila contra la última ejecución esperada — era de una ejecución anterior, así que esa fila nunca se volvió a tocar. Revisando el historial de runs encontré una ejecución solapada por un backfill mal planificado: dos runs escribieron la misma reserva, y el que tenía el dato viejo hizo *commit* después, sobrescribiendo al bueno — en Snowflake gana quien comitea último, no quien tiene el dato más reciente. La solución fue fijar `max_active_runs=1` y volver a cargar el rango afectado; como el valor correcto ya no estaba en origen, lo recuperé con Time Travel comparando el estado de la tabla justo antes del commit malo. Lo prevengo con un test de unicidad por `id_reserva` y comparando el timestamp de la última carga RAW contra el de la última ejecución de dbt downstream.

## Conceptos relacionados
- [[idempotencia-y-atomicidad]]
- [[airflow-assets]]
- [[time-travel-fail-safe-zero-copy-cloning]]
- [[gaps-and-islands]]
- [[sensor-deferrable]]
- [[airflow-datos-incorrectos-sin-error]]
