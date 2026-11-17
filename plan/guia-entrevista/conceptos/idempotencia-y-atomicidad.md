---
tipo: concepto
herramienta: airflow
aliases: [idempotencia, atomicidad, idempotent load, delete insert transaction]
tags: [guia-entrevista, airflow]
---
# Idempotencia y atomicidad

> [!tip] Respuesta rápida
> Idempotencia: repetir la misma carga con el mismo rango da siempre el mismo resultado final, sin duplicar. Atomicidad: la operación es todo o nada — si falla a mitad, no queda estado parcial. Son propiedades distintas pero se combinan para que reintentos y backfills sean seguros.

## Definición

**Idempotencia** es una propiedad de la operación en sí: aplicarla una vez o N veces con la misma entrada produce el mismo estado final. En un pipeline de datos esto normalmente significa que cargar el mismo rango de fechas dos veces no duplica filas — el patrón típico es *delete+insert* (borra el rango antes de insertar) o un `MERGE` por clave, en vez de un `INSERT` ciego.

**Atomicidad** es una propiedad de la ejecución: la operación se hace entera o no se hace nada — si falla a mitad, no queda estado intermedio visible. En SQL se consigue con una transacción explícita (`BEGIN`/`COMMIT`/`ROLLBACK`); sin ella, un fallo entre el `DELETE` y el `INSERT` deja la tabla sin esas filas, con nadie enterado.

Son ortogonales: puedes tener una sin la otra. Un `INSERT` suelto dentro de una transacción es atómico (no deja estado a medias) pero no idempotente (reintentarlo duplica). Para que los reintentos automáticos de un orquestador (Airflow relanzando una tarea tras un timeout) y los backfills sean seguros, necesitas las dos combinadas — y necesitas que el rango a borrar/insertar salga de [[data-interval-vs-logical-date|`data_interval`]], no de `now()`, para que cada reintento ataque exactamente el mismo rango.

## Ejemplo mínimo
En `ecb_exchange_rates.py`, la tarea `load` hace:
```python
cur.execute("begin")
cur.execute(
    "delete from RAW.ECB.EXCHANGE_RATES where rate_date between %(start)s and %(end)s",
    {"start": start, "end": end},
)
if rows:
    cur.executemany(insert_sql, rows)
cur.execute("commit")
# except: cur.execute("rollback")
```
Delete+insert del rango dentro de una transacción da idempotencia (relanzar el mismo rango no duplica) y atomicidad (un fallo a mitad hace rollback, sin filas a medio borrar/insertar).

## Errores típicos
- Confundirlas: un `INSERT` simple dentro de una transacción es atómico pero no idempotente (reintentar duplica filas).
- Hacer el delete y el insert sin transacción explícita: un fallo entre ambos deja la tabla vacía para ese rango.
- Pensar que idempotencia es solo "no fallar dos veces" en vez de "mismo resultado sin importar cuántas veces se ejecute".

## Pregunta probable
¿Qué pasaría con un INSERT simple sin este patrón? Un reintento de Airflow (por ejemplo tras un timeout de red ya aplicado) duplicaría filas para ese rango de fechas, porque no hay borrado previo que limpie lo ya insertado.

## Aparece en
- [[airflow-tarea-falla-por-credenciales]]
- [[airflow-datos-incorrectos-sin-error]]
- Relacionados: [[data-interval-vs-logical-date]], [[estrategia-incremental-merge-delete-insert-append]]
