---
tipo: problema
herramienta: airflow
prioridad: alta
aliases: [airflow en verde pero datos mal, backfill duplica datos, now() en vez de data interval, datos incorrectos sin fallo, silent data error airflow]
tags: [guia-entrevista, airflow]
---
# Airflow dice que todo salió bien pero los datos están mal

> [!tip] Respuesta rápida
> El fallo más peligroso porque **no hay alerta**: el DAG usa `now()` en vez del intervalo de datos (`data_interval_start`/`end`). Un backfill de varios días carga el mismo rango una y otra vez, y Airflow lo marca todo en verde.

## Hipótesis (de más barata a más cara de comprobar)
1. **`now()`/`today()` en vez de `data_interval_start`/`end`** → cada ejecución del backfill carga "hoy" en vez del día que le corresponde a ese run. Resultado: días repetidos y huecos, pero cada tarea individual tiene éxito, así que todo aparece verde.
2. Otras causas menos probables si la anterior no aplica: lógica de `delete`/`insert` sin rango correcto, o commit parcial sin rollback ante error silencioso.

## Diagnóstico paso a paso
```sql
-- compara qué fechas se cargaron realmente contra lo esperado
select rate_date, count(*)
from raw.ecb.exchange_rates
group by rate_date
order by rate_date;
```
Si ves un `rate_date` con muchas más filas que el resto, o fechas ausentes que deberían estar, es la señal.

```bash
# busca el patrón en el código del DAG
grep -n "now()\|today()" airflow/dags/*.py
```
En el caso real del repo, `_resolve_period` debe construir el rango a partir de `data_interval_start`/`data_interval_end` del contexto de Airflow (no de `now()`), salvo carga manual explícita con params `start_period`/`end_period`.

## Solución
Usar siempre el intervalo de datos del contexto, nunca la hora real de ejecución:

```python
# mal: todas las ejecuciones de un backfill cargan "hoy"
start = datetime.now()

# bien: cada run usa su propio intervalo
start = context["data_interval_start"]
end = context["data_interval_end"]
```
Después de corregir, reejecutar el rango afectado: como la tarea `load` hace `delete` + `insert` dentro de una transacción (`begin`/`commit`, `rollback` en el `except`) sobre el rango exacto, reejecutar es seguro y no duplica.

## Prevención
- **Tests de continuidad de fechas**: comprobar que no faltan ni se repiten fechas en la tabla raw.
- **Conteos por fecha post-carga**: una tarea o check que compare filas esperadas vs reales por `rate_date`.
- Code review explícito: cualquier uso de `now()`/`today()` dentro de una tarea que depende del intervalo de ejecución es sospechoso por defecto.

## Cómo contarlo
Un backfill de varios días dejó la tabla con fechas duplicadas y huecos, pero Airflow marcaba todo en verde. La hipótesis fue que `_resolve_period` usaba `now()` en vez del intervalo de datos, así que cada run cargaba "hoy" en vez de su propio día. Lo confirmé agrupando por `rate_date` y viendo conteos anómalos, y revisando el código con `grep "now()"`. La solución fue usar `data_interval_start`/`end` del contexto y reejecutar el rango, seguro gracias al `delete`+`insert` transaccional. Lo prevengo con tests de continuidad de fechas y conteos post-carga.

## Conceptos relacionados
- [[data-interval-vs-logical-date]]
- [[idempotencia-y-atomicidad]]
- [[gaps-and-islands]]
