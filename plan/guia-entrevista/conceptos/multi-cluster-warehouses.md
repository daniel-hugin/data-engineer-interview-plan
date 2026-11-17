---
tipo: concepto
herramienta: snowflake
aliases: [multi-cluster warehouse, max_cluster_count, min_cluster_count, scaling_policy, auto-scaling snowflake, economy vs standard scaling]
tags: [guia-entrevista, snowflake]
---
# Multi-cluster warehouses: `MAX_CLUSTER_COUNT` y `SCALING_POLICY`

> [!tip] Respuesta rápida
> Un warehouse multi-cluster añade **clústeres idénticos** (mismo tamaño) para repartir consultas concurrentes, entre `MIN_CLUSTER_COUNT` y `MAX_CLUSTER_COUNT`. `SCALING_POLICY='standard'` añade cluster rápido en cuanto hay cola; `'economy'` espera más, priorizando coste sobre latencia. Cada clúster activo factura créditos por separado — `MAX_CLUSTER_COUNT` es tu techo de coste ante un pico de concurrencia.

## Definición

Escalar hacia fuera (ver [[escalar-warehouse-arriba-vs-fuera]]) no es solo un concepto, es una configuración concreta del warehouse con tres parámetros:

- **`MIN_CLUSTER_COUNT`**: cuántos clústeres están siempre activos mientras el warehouse está encendido (por defecto 1 — es lo que convierte un warehouse normal en multi-cluster en cuanto subes esto, o subes el máximo).
- **`MAX_CLUSTER_COUNT`**: el techo — cuántos clústeres puede llegar a activar Snowflake automáticamente si la cola de consultas lo justifica. Cada clúster es una copia idéntica del warehouse (mismo tamaño), no una versión más grande.
- **`SCALING_POLICY`**: cómo decide Snowflake *cuándo* añadir o quitar un clúster. `STANDARD` (por defecto) reacciona rápido ante cualquier señal de cola, priorizando que las consultas no esperen — puede activar un clúster nuevo aunque el existente todavía tuviera algo de margen. `ECONOMY` es más conservador: intenta encajar más consultas en los clústeres ya activos antes de sumar uno nuevo, y los apaga más agresivamente en cuanto baja la carga — cambia latencia por coste.

El punto clave de facturación: **cada clúster activo cuenta créditos por separado**, al ritmo que le corresponda por tamaño (igual que un warehouse normal). Si `MAX_CLUSTER_COUNT` no tiene un techo pensado, un pico de concurrencia inesperado puede activar varios clústeres a la vez, multiplicando el gasto en poco tiempo — por eso este parámetro, junto con un *resource monitor* (ver `lab_monthly_monitor` del lab) como red de seguridad a nivel de cuenta, es la palanca real de control de coste al activar multi-cluster, no solo una casilla que se enciende y se olvida.

## Ejemplo mínimo
```sql
alter warehouse bi_wh set
  warehouse_size = 'small'
  min_cluster_count = 1
  max_cluster_count = 3
  scaling_policy = 'economy';
```
Un BI warehouse que puede crecer hasta 3 clústeres pequeños ante concurrencia, pero prioriza coste sobre reacción inmediata.

## Errores típicos
- Dejar `MAX_CLUSTER_COUNT` alto "por si acaso", sin relacionarlo con el pico de concurrencia real esperado: un pico puntual puede disparar el gasto sin que nadie lo decidiera explícitamente.
- Pensar que multi-cluster acelera una consulta individual: no — cada clúster es del mismo tamaño que el original, solo reparte consultas *distintas* entre clústeres; una query pesada sola sigue igual de lenta.
- Usar `SCALING_POLICY='standard'` por defecto cuando el coste importa más que la latencia, sin plantearse `'economy'`.
- Olvidar que esto es un eje independiente de escalar hacia arriba: se pueden combinar (varios clústeres, cada uno más grande), aunque no es el punto de partida habitual.

## Pregunta probable
**¿Cómo limitarías el riesgo de coste al activar multi-cluster en un warehouse de BI?** Fijando un `MAX_CLUSTER_COUNT` acorde al pico de concurrencia esperado (no "sin límite"), usando `SCALING_POLICY='economy'` si la latencia no es crítica, y dejando un *resource monitor* a nivel de cuenta como red de seguridad independiente del warehouse concreto.

## Aparece en
- [[escalar-warehouse-arriba-vs-fuera]]
- Relacionados: [[arquitectura-tres-capas-snowflake]], [[caches-de-snowflake]]
