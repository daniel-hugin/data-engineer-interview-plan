---
tipo: concepto
herramienta: airflow
aliases: [data interval, logical date, execution date, data_interval_start end]
tags: [guia-entrevista, airflow]
---
# `data_interval` vs `logical_date`

> [!tip] Respuesta rápida
> `data_interval_start`/`data_interval_end` son el rango real de datos a procesar en ese run (ej. `[D, D+1)` para un diario). `logical_date` es solo la marca histórica que identifica la ejecución (equivalente al viejo `execution_date`). Para decidir qué datos cargar hay que usar el intervalo, no `now()` ni el logical date suelto.

## Definición

Antes de Airflow 2.2, cada DAG run tenía un único `execution_date` que servía a la vez de identificador y de "fecha de los datos" — funcionaba mal con calendarios no contiguos (ej. solo días laborables). Airflow lo sustituyó por dos conceptos separados: `logical_date` es solo la marca que identifica de forma única esa ejecución (lo que antes era `execution_date`, mantenido por compatibilidad); `data_interval_start`/`data_interval_end` es el rango real `[start, end)` de datos que ese run debe procesar, calculado a partir del `schedule` del DAG.

La separación importa porque un run programado para "hoy" en realidad procesa el intervalo que **terminó** antes de dispararse (en un `@daily`, el run que se etiqueta con la fecha D procesa los datos de D, pero se ejecuta físicamente al principio de D+1). Usar el intervalo en vez de `now()` o el logical date suelto es lo que hace que un backfill reconstruya exactamente el rango que le corresponde a cada ejecución histórica, no la fecha en que se relanza. Ver [[idempotencia-y-atomicidad]] para por qué esto, combinado con un patrón delete+insert, hace los backfills seguros de repetir.

## Ejemplo mínimo
En `ecb_exchange_rates.py`, `_resolve_period(context)` construye el rango así:
```python
start = context["data_interval_start"]
end = context["data_interval_end"] - timedelta(days=1)  # intervalo es [D, D+1)
```
salvo carga manual con params `start_period`/`end_period`; y si no hay intervalo (trigger manual sin logical date), carga "ayer". El comentario del fichero lo resume: "El rango sale del data interval, no de `now()`: así los backfills cargan el día correcto".

## Errores típicos
- Usar `now()` o `datetime.today()` dentro de la tarea para decidir qué cargar: un backfill de hace tres meses cargaría la fecha de hoy, no la fecha que tocaba.
- Olvidar el ajuste de `-1 día` al `end`: el intervalo es semiabierto `[start, end)`, así que `end` tal cual no pertenece al rango que se quiere cargar.
- Confundir `logical_date` con el intervalo: el logical date es un punto, el intervalo es un rango.

## Pregunta probable
¿Cómo garantiza esto que un backfill cargue el día correcto? Porque el rango se deriva del intervalo de esa ejecución concreta (fijo para ese run), no del momento en que el backfill realmente se ejecuta.

## Aparece en
- [[airflow-datos-incorrectos-sin-error]]
- [[idempotencia-y-atomicidad]]
- Relacionados: [[airflow-assets]], [[pools-max-active-tasks-max-active-runs]]
