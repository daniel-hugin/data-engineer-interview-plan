---
tipo: problema
herramienta: dbt
prioridad: alta
aliases: [source freshness en warn o error, dbt source freshness falla, freshness check rojo, datos no frescos dbt, stale source dbt]
tags: [guia-entrevista, dbt]
---
# `dbt source freshness` sale en warn o error

> [!tip] Respuesta rápida
> Antes de asumir que algo está roto, mira si es **fin de semana o festivo** (el BCE no publica esos días). Si no, revisa si el DAG de carga falló o no corrió.

## Hipótesis (de más barata a más cara de comprobar)
1. **Fin de semana o festivo largo** → el BCE no publica tipos de cambio esos días; un puente de 3-4 días puede acercarse al `warn_after` sin que nada esté roto.
2. **El DAG `ecb_exchange_rates` falló o no corrió** → la tabla no se actualizó cuando debía.
3. **La API del BCE cambió de comportamiento** → formato de respuesta distinto, el DAG falla al parsear.

## Diagnóstico paso a paso
```bash
dbt source freshness --select source:ecb
```
Fuente real del repo: `ecb` en `_ecb__sources.yml`, `loaded_at_field: loaded_at`, `warn_after: 3 days`, `error_after: 5 days`.

```sql
-- última carga real en la tabla raw
select max(loaded_at) as ultima_carga
from raw.ecb.exchange_rates;
```
Compara esa fecha con hoy: si la diferencia coincide con un puente de festivos, probablemente es la hipótesis 1. Si no, revisa el estado del DAG (Airflow UI o `airflow dags list-runs -d ecb_exchange_rates`).

## Solución
- **Festivo/fin de semana**: no hay nada que arreglar; si el warn es molesto, documenta que es esperado.
- **DAG falló**: revisa logs de la tarea `load`, corrige la causa (conexión, permisos, cambio de la API) y reejecuta el rango afectado — es idempotente porque usa `data_interval_start`/`end`, así que reejecutar no duplica.
- **Cambio de la API**: ajustar el parseo en el DAG y añadir un test que capture el nuevo formato.

## Prevención
- **Alertas sobre fallos del DAG** (no solo sobre freshness): un DAG en rojo se nota antes que el freshness check, que solo corre cuando alguien lo ejecuta.
- No depender solo de `dbt source freshness` como única señal: combínalo con monitorización del DAG en Airflow.
- Ajustar `warn_after`/`error_after` con margen realista para festivos conocidos (ej. Navidad, Semana Santa).

## Cómo contarlo
El freshness check de la fuente `ecb` saltó en warn; mi primera hipótesis fue un puente de festivos, ya que el BCE no publica esos días. Lo comprobé mirando `max(loaded_at)` en la tabla raw y contrastándolo con el calendario de festivos, y confirmé que el DAG sí había corrido correctamente. Como no era un fallo real, documenté que era esperado. Para prevenirlo, prefiero alertar sobre el estado del DAG en Airflow en vez de depender solo del freshness check.

## Conceptos relacionados
- [[source-freshness-dbt]]
- [[idempotencia-y-atomicidad]]
- [[airflow-tarea-falla-por-credenciales]]
