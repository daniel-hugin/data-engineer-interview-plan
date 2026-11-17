---
tipo: problema
herramienta: snowflake
prioridad: alta
aliases: [query lenta en Snowflake, consulta ha empezado a tardar más, slow query snowflake, rendimiento query snowflake, query performance degradation]
tags: [guia-entrevista, snowflake]
---
# La query tarda muchísimo (o ha empezado a tardar más que antes)

> [!tip] Respuesta rápida
> Abre el **Query Profile** y mira el operador más costoso: casi siempre es pérdida de *pruning*, *spilling* a disco, o cola por concurrencia. Diagnostica antes de tocar el tamaño del warehouse.

## Hipótesis (de más barata a más cara de comprobar)
0. **Cambió el código/modelo** → la más barata de todas, ni siquiera es una consulta SQL: `git log`/`git diff` del modelo, o comparar `query_text` entre la ejecución buena y la mala en `QUERY_HISTORY`. Compruébalo antes que nada — descarta de un vistazo la mitad de las hipótesis siguientes si el SQL no cambió.
1. **No usó la caché de resultados** → misma query exacta, re-ejecutada sin cambios en los datos; revisa si salió de `RESULT_SCAN`/caché en `QUERY_HISTORY`.
2. **Pérdida de pruning** → filtro sobre columna envuelta en función o con conversión implícita de tipo (`where to_varchar(fecha) = '...'` en vez de `where fecha = '...'`).
3. **Spilling a disco** → warehouse demasiado pequeño para el volumen intermedio (joins/agregaciones grandes).
4. **Cola por concurrencia** → varias queries esperando el mismo warehouse (`queued_overload_time` > 0).
5. **Alguien redimensionó el warehouse** → cambio de tamaño que afecta a todos los usuarios de ese warehouse.

## Diagnóstico paso a paso
```sql
-- bytes escaneados vs totales, spilling, tiempo en cola, tamaño del warehouse
select
  query_id, warehouse_name, warehouse_size, total_elapsed_time,
  bytes_scanned, partitions_scanned, partitions_total,
  bytes_spilled_to_local_storage, bytes_spilled_to_remote_storage,
  queued_overload_time
from snowflake.account_usage.query_history
where query_text ilike '%mi_query%'
order by start_time desc
limit 20;
```
La columna `warehouse_size` deja ver si el tamaño cambió entre la ejecución rápida y la lenta (hipótesis 5) sin tener que buscar en otro sitio.
En el **Query Profile** (UI), busca el operador con mayor % de tiempo y revisa "Partitions scanned / Partitions total" (pruning) y "Bytes spilled" (tamaño insuficiente).

## Solución
- **Pruning perdido**: reescribe el filtro para que compare el tipo nativo de la columna, sin envolverla en funciones.
- **Spilling**: sube el warehouse un tamaño (escalar *arriba*) solo para esa carga puntual, o reescribe la query para reducir el intermedio.
- **Cola**: separa cargas en warehouses distintos o activa multi-cluster si el patrón lo justifica.
- **Caché no usada**: si el resultado debía ser igual, revisa si cambiaron los datos subyacentes (invalida la caché).

## Prevención
- *Clustering keys* si el patrón de filtro es estable y la tabla es grande.
- Dimensionar el warehouse según el volumen real, no "por si acaso".
- `query_tag` en cada job para poder filtrar `QUERY_HISTORY` por origen.

## Cómo contarlo
Una query que antes iba rápido empezó a tardar mucho; mi primera hipótesis fue pérdida de pruning por un filtro con conversión de tipo. Lo comprobé en el Query Profile mirando particiones escaneadas vs totales, y confirmé spilling a disco en el mismo perfil. La solución fue corregir el filtro y, puntualmente, subir el warehouse. Para prevenirlo, uso `query_tag` y reviso clustering keys si el patrón de filtro es estable.

## Conceptos relacionados
- [[query-profile-metricas-y-diagnostico]]
- [[micro-particiones-y-clustering-keys]]
- [[caches-de-snowflake]]
- [[escalar-warehouse-arriba-vs-fuera]]
