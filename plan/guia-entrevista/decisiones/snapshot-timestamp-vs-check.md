---
tipo: decision
herramienta: dbt
prioridad: media
aliases: [dbt snapshot strategy, timestamp vs check strategy, scd2 con dbt snapshot]
tags: [guia-entrevista, dbt]
---
# Snapshot de dbt: estrategia `timestamp` vs `check`

> [!tip] Respuesta rápida
> **`timestamp`** cuando la fuente trae una columna de actualización fiable (`updated_at`); **`check`** cuando no la trae y hay que comparar columnas concretas para detectar el cambio.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| `timestamp` | Barato: compara una sola columna de fecha, fiable si la fuente la mantiene bien | Si la fuente no actualiza ese campo correctamente, el snapshot no detecta el cambio | La fuente tiene `updated_at`/similar y se puede confiar en él |
| `check` | No depende de que la fuente mantenga timestamps, compara las columnas que importan (`check_cols`) | Más coste de comparación, hay que elegir bien qué columnas vigilar | Fuentes sin timestamp fiable, como un CSV o seed simple |

## En travel-dwh-lab
`channel_commissions.csv` (seed de D6-03, canal + % de comisión) no tiene columna de actualización, así que el snapshot usa `check` sobre la columna de comisión: al cambiar un valor en el CSV y volver a `dbt seed` + `dbt snapshot`, la fila antigua cierra su `dbt_valid_to` y se abre una nueva con `dbt_valid_from`.

## Respuesta modelo
Contexto: necesito versionar los cambios de `channel_commissions.csv` para poder calcular ingresos históricos con la comisión vigente en cada momento. Opciones: `timestamp` o `check`. Elijo `check` porque el CSV no trae ningún campo de actualización fiable, así que dbt tiene que comparar directamente el valor de la comisión para decidir si hay cambio. La diferencia con el `MERGE` manual de SCD2 del día 4 es que ahí yo controlo exactamente qué fila se cierra y cuál se abre con SQL explícito; el snapshot de dbt automatiza ese mismo patrón a partir de una ejecución programada, a cambio de menos control fino sobre el momento exacto de corte.

## Conceptos relacionados
- [[scd-tipo-2-con-merge]]
- [[estrategia-incremental-merge-delete-insert-append]]
