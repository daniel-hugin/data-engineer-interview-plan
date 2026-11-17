---
tipo: decision
herramienta: dbt
prioridad: alta
aliases: [incremental strategy dbt, merge vs delete insert, append incremental, late arriving data, microbatch]
tags: [guia-entrevista, dbt, snowflake]
---
# Estrategia incremental: merge vs delete+insert vs append vs microbatch

> [!tip] Respuesta rápida
> **merge** cuando los registros pueden actualizarse (upsert por `unique_key`); **delete+insert** cuando quiero reemplazar rangos completos (p. ej. por fecha); **append** solo si el dato nunca cambia una vez escrito; **microbatch** para ventanas de tiempo grandes y predecibles.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| `merge` | Upsert real: actualiza lo que cambió, inserta lo nuevo, en una sola operación | Requiere `unique_key` bien definido, algo más caro que append | Dimensiones o hechos que se pueden corregir tras su carga |
| `delete+insert` | Simple de razonar: borra el rango y vuelve a insertar | Ventana borrada no existe durante la transacción si falla a mitad sin rollback | Reemplazo de rangos completos (ej. un día entero) |
| `append` | Más rápido, sin lógica de comparación | Duplica si se reejecuta sin control | Eventos inmutables que nunca se corrigen (logs) |
| `microbatch` | Pensado para rangos de tiempo grandes, reprocesa por lotes de tiempo definidos | Más reciente en dbt, requiere `event_time` y `batch_size` | Históricos muy grandes particionados por tiempo |

## En travel-dwh-lab
`fct_exchange_rates` (D6-01) usa `merge` con `unique_key = (rate_date, quote_currency)` y una ventana de *lookback* de 7 días dentro del filtro `is_incremental()`: si el BCE publica o corrige un tipo de hace unos días (*late-arriving data*), el incremental lo recoge porque siempre re-mira los últimos 7 días, no solo "desde la última carga". El DAG `ecb_exchange_rates.py`, en cambio, usa `delete+insert` en SQL puro (no dbt) sobre el rango exacto del *data interval*, dentro de una transacción con `rollback`.

## Respuesta modelo
Contexto: tengo que convertir un modelo en incremental. Opciones: merge, delete+insert, append o microbatch. Elijo `merge` con *lookback* de 7 días para los tipos de cambio porque el BCE puede publicar con retraso o corregir un valor, y necesito que una reejecución recoja esas correcciones sin reprocesar todo el histórico. El riesgo que asumo es que el `unique_key` esté mal definido y el merge inserte duplicados en vez de actualizar; lo mitigo con un test `unique_combination_of_columns` sobre `(rate_date, quote_currency)` y comparando el resultado incremental contra un `--full-refresh` antes de confiar en él en producción.

## Conceptos relacionados
- [[materializacion-view-table-incremental-ephemeral]]
- [[idempotencia-y-atomicidad]]
- [[scd-tipo-2-con-merge]]
