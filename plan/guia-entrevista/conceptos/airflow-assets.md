---
tipo: concepto
herramienta: airflow
aliases: [airflow assets, data assets, datasets airflow, planificacion dirigida por datos, data-aware scheduling]
tags: [guia-entrevista, airflow]
---
# Assets (planificación dirigida por datos)

> [!tip] Respuesta rápida
> En vez de encadenar DAGs por hora (cron), un DAG **productor** declara que produce un `Asset` (`outlets=[...]`), y un DAG **consumidor** se planifica con `schedule=[Asset(...)]`. Airflow los enlaza por el `name` del asset: cuando el productor termina bien, dispara al consumidor.

## Definición

Un `Asset` es una señal lógica (identificada por un `name`, normalmente una URI como `raw.ecb.exchange_rates`) que representa "este dato existe y se actualizó" — no transporta ningún dato en sí, solo es un evento. Cuando una tarea declara `outlets=[MiAsset]` y termina en éxito, Airflow registra un **asset event** con timestamp. Un DAG planificado con `schedule=[MiAsset]` se dispara en cuanto aparece un evento nuevo de ese asset desde su última ejecución exitosa.

Esto sustituye a la planificación por `cron` para dependencias entre DAGs: en vez de adivinar una hora en la que "probablemente" ya habrán llegado los datos (planificación [[data-interval-vs-logical-date|por tiempo]]), el consumidor se dispara por la señal real de que el productor terminó. Es planificación **dirigida por datos**, no por reloj — la comparación directa con otras formas de disparar un DAG está en [[assets-vs-cron-vs-sensor]].

Un matiz importante: si `schedule` recibe una lista de varios assets, Airflow por defecto exige que **todos** tengan un evento nuevo (lógica AND) antes de disparar al consumidor; para lógica OR hace falta `AssetAny(...)`. Esto es relevante si el DAG consumidor depende de más de una fuente (p. ej. tipos de cambio *y* reservas) y quieres decidir si debe esperar a ambas o dispararse con cualquiera.

## Ejemplo mínimo
Mismo `Asset`, mismo nombre, en los dos DAGs:
```python
# ecb_exchange_rates.py (productor)
ECB_EXCHANGE_RATES = Asset(name="raw.ecb.exchange_rates")

@task(outlets=[ECB_EXCHANGE_RATES])
def load(payload: dict) -> int: ...
```
```python
# dbt_travel_dwh.py (consumidor)
ECB_EXCHANGE_RATES = Asset(name="raw.ecb.exchange_rates")

@dag(schedule=[ECB_EXCHANGE_RATES], ...)
def dbt_travel_dwh(): ...
```

## Errores típicos
- Escribir nombres de asset distintos entre productor y consumidor (típo, mayúsculas): Airflow los enlaza **por nombre exacto**, si no coincide no se conecta nada y el consumidor nunca se dispara.
- Seguir usando cron en el consumidor "por si acaso": pierdes la garantía de que los datos están realmente listos, y vuelves a horas mágicas.
- Pensar que el asset transporta datos: no, solo es una señal de "esto se actualizó"; los datos siguen pasando por la tabla en Snowflake.

## Pregunta probable
**¿Por qué `dbt_travel_dwh` usa `schedule=[Asset(...)]` en vez de una hora fija?** Porque dbt debe construir después de que lleguen tipos de cambio nuevos, no "probablemente ya habrán llegado a las X". Con una hora fija, si el BCE se retrasa o la ingesta falla, dbt construye con datos viejos sin avisar. Con el asset, solo se dispara cuando la carga realmente tuvo éxito.

## Aparece en
- [[airflow-dag-no-aparece]]
- Relacionados: [[assets-vs-cron-vs-sensor]], [[data-interval-vs-logical-date]]
