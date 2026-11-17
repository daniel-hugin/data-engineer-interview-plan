---
tipo: problema
herramienta: snowflake
prioridad: alta
aliases: [factura de snowflake duplicada, coste de snowflake disparado, snowflake bill spike, créditos consumidos de más, warehouse cost spike]
tags: [guia-entrevista, snowflake]
---
# La factura de Snowflake se ha duplicado este mes

> [!tip] Respuesta rápida
> Agrupa `WAREHOUSE_METERING_HISTORY` por día y warehouse para ver **cuándo y dónde** subió el consumo; casi siempre es un `AUTO_SUSPEND` alto, un warehouse que alguien subió de tamaño y no bajó, o una query nueva escaneando mucho más.

## Hipótesis (de más barata a más cara de comprobar)
1. **`AUTO_SUSPEND` alto o quitado** → el warehouse queda encendido sin trabajo, consumiendo créditos.
2. **Alguien subió el tamaño de un warehouse para una carga puntual y no lo bajó** → revisar historial de `ALTER WAREHOUSE`.
3. **Multi-cluster escalando sin necesidad** → más clusters activos de los que el patrón de uso justifica.
4. **Query o modelo nuevo escaneando mucho más** → pérdida de pruning, o un `dbt run --full-refresh` que no debía ser full.
5. **Resource monitor mal configurado** → sin umbrales, o con umbrales demasiado altos para avisar a tiempo.

## Diagnóstico paso a paso
```sql
-- consumo de créditos por día y warehouse
select
  warehouse_name,
  date_trunc('day', start_time) as dia,
  sum(credits_used) as creditos
from snowflake.account_usage.warehouse_metering_history
group by 1, 2
order by 2 desc, 3 desc;

-- queries más caras del warehouse sospechoso en el periodo
select query_id, query_text, warehouse_name, bytes_scanned, total_elapsed_time
from snowflake.account_usage.query_history
where warehouse_name = 'WAREHOUSE_SOSPECHOSO'
  and start_time >= dateadd(day, -7, current_timestamp())
order by bytes_scanned desc
limit 20;
```
Busca el día donde el consumo da el salto y cruza con cambios de ese día (deploys, backfills, `full-refresh`).

## Solución
Según la causa: bajar `AUTO_SUSPEND` a un valor corto (ej. 60s, como `loading_wh`/`transforming_wh`/`dev_wh` en el repo), volver a dimensionar el warehouse al tamaño base, revisar si el multi-cluster necesita límite máximo, o corregir la query/modelo que perdió pruning.

## Prevención
- **Resource monitor** con umbrales de aviso y suspensión, como `lab_monthly_monitor` del repo: 20 créditos/mes, notifica al 75%, suspende en 100% y 110%.
- `AUTO_SUSPEND` corto por defecto en todos los warehouses.
- Revisión periódica de `WAREHOUSE_METERING_HISTORY` antes de que llegue la factura, no después.

## Cómo contarlo
Detecté un pico de coste y mi primera hipótesis fue un warehouse sin `AUTO_SUSPEND` corto o redimensionado y olvidado. Lo comprobé agrupando `WAREHOUSE_METERING_HISTORY` por día y warehouse, lo que me llevó al día y al warehouse exactos, y luego a la query causante en `QUERY_HISTORY`. La solución fue devolver el warehouse a su tamaño base y acortar `AUTO_SUSPEND`. Para prevenirlo, dejamos un resource monitor con avisos al 75% y corte al 100-110%, como el `lab_monthly_monitor` del proyecto.

## Conceptos relacionados
- [[escalar-warehouse-arriba-vs-fuera]]
- [[micro-particiones-y-clustering-keys]]
- [[snowflake-query-lenta]]
