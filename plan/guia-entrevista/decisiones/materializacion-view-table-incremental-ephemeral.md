---
tipo: decision
herramienta: dbt
prioridad: alta
aliases: [materializaciones dbt, view vs table vs incremental, ephemeral models, cuando usar incremental dbt]
tags: [guia-entrevista, dbt]
---
# Materialización: view vs table vs incremental vs ephemeral

> [!tip] Respuesta rápida
> **View** para staging (barato, siempre al día); **table** para marts que se consultan mucho; **incremental** cuando la tabla es grande y crece (no quiero reconstruir todo); **ephemeral** para un CTE intermedio que no necesito consultar ni depurar por separado.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| View | Sin coste de almacenamiento, siempre refleja la fuente | Recalcula en cada consulta, lento si hay lógica pesada o muchos consumidores | Staging: solo tipado/renombrado, pocas filas |
| Table | Rápida de consultar, materializada una vez por build | Coste de almacenamiento y de recompute completo cada build | Marts consultados por BI o muchos modelos descendentes |
| Incremental | Solo procesa filas nuevas/cambiadas, build rápido en tablas grandes | Más complejidad (unique_key, estrategia, lookback), riesgo de omitir datos tardíos | Tablas que crecen cada día y son demasiado grandes para reconstruir siempre |
| Ephemeral | No ocupa espacio ni aparece en la base, se interpola como CTE | No se puede consultar directamente ni testear por separado, dificulta depuración | Lógica intermedia de un solo uso, sin valor fuera de su modelo padre |

## En travel-dwh-lab
`dbt_project.yml` fija `staging: +materialized: view` (tipado/renombrado barato), `intermediate: +materialized: view` (el forward-fill de `int_exchange_rates__daily` se recalcula al vuelo) y `marts: +materialized: table` con `+transient: false` (producción, se consulta mucho y conserva Fail-safe). `fct_exchange_rates` (D6-01) es el único incremental: los tipos de cambio crecen cada día y pueden llegar tarde, a diferencia de los hoteles, que son un dataset estático que no se beneficia de incremental.

## Datos tardíos y `--full-refresh`

**Late-arriving data**: un registro que llega después de que su fecha ya se dio por "procesada" (una corrección del BCE de hace días, un estado de reserva que se actualiza tarde). Si el incremental filtra estrictamente "desde la última ejecución", ese dato nunca se recoge. La mitigación es una **ventana de lookback**: releer siempre los últimos N días (no solo lo nuevo), aunque ya se hubieran procesado antes — ver el caso real de `fct_exchange_rates` en [[estrategia-incremental-merge-delete-insert-append]] (7 días).

**`--full-refresh`**: tira la tabla incremental y la reconstruye entera con la lógica completa, en vez de aplicar solo el incremento. Hace falta cuando cambia la lógica del modelo de una forma que también afecta a filas ya existentes (no solo a las nuevas), o cuando cambia el esquema. Riesgos en producción: es tan caro como el build completo que el incremental existe para evitar (puede ser muy lento/caro en tablas grandes); y si la fuente RAW ya no conserva todo el histórico original (retención limitada, datos purgados aguas arriba), el resultado del *full-refresh* puede no coincidir exactamente con lo que había antes.

## Respuesta modelo
Contexto: tengo que decidir la materialización de un modelo nuevo. Opciones: view, table, incremental o ephemeral. Elijo view para todo lo que es staging porque es barato y no necesito que sobreviva entre builds; table para los marts porque los consulta BI constantemente; incremental solo cuando el volumen y el crecimiento diario lo justifican, como `fct_exchange_rates`. El riesgo de generalizar "todo incremental" es la complejidad añadida (gestionar `unique_key`, backfills, `--full-refresh`) sin necesidad real; lo mitigo empezando siempre en table/view y pasando a incremental solo cuando el tiempo de build se vuelve un problema medible.

## Conceptos relacionados
- [[estrategia-incremental-merge-delete-insert-append]]
- [[dbt-selectores-y-state]]
- [[model-contracts-dbt]]
