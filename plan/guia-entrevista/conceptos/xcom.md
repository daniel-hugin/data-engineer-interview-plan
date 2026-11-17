---
tipo: concepto
herramienta: airflow
aliases: [xcom, cross communication, paso de datos entre tareas, metastore airflow]
tags: [guia-entrevista, airflow]
---
# XCom

> [!tip] Respuesta rápida
> Mecanismo de Airflow para pasar valores pequeños entre tareas, guardados en el metastore (la BD de Airflow). Pensado para datos de control o volúmenes pequeños, **no** para mover datasets grandes: eso satura el metastore y ralentiza todo el scheduler.

## Definición

XCom ("cross-communication") es el mecanismo de Airflow para que una tarea deje un valor disponible para otra. Cada valor se guarda con una clave (`key`), asociado a la tarea y al DAG run que lo produjo, en el **metastore** — la base de datos de metadatos de Airflow (normalmente Postgres), la misma que guarda el estado de todos los DAGs, tareas y conexiones. Con [[taskflow-api-vs-operadores-clasicos|TaskFlow]], el push/pull es implícito (el valor de retorno de una función `@task` se convierte en el XCom que recibe la siguiente); con operadores clásicos se hace explícito con `xcom_push`/`xcom_pull`.

El límite de diseño es que el metastore no está pensado para mover datos grandes: es la misma base que el scheduler consulta constantemente para decidir qué ejecutar, así que llenarla con payloads de millones de filas no solo arriesga el límite de tamaño del motor subyacente, degrada el rendimiento de **todo** el scheduler, no solo de esa tarea. El patrón correcto para datasets grandes es que la tarea productora escriba a un almacén externo (un stage de Snowflake, un bucket) y pase por XCom solo una referencia — la ruta o el identificador —, nunca los datos en sí.

## Ejemplo mínimo
De `ecb_exchange_rates.py`, `extract()` devuelve y `load()` recibe por XCom implícito (TaskFlow):
```python
# Pocas filas (incluso el histórico completo son unos miles): caben en XCom.
# Con volúmenes grandes se escribiría a un stage y se pasaría solo la ruta.
return {"start": start.isoformat(), "end": end.isoformat(), "rows": rows}
```
```python
load(extract())  # el dict completo viaja por XCom entre las dos tareas
```

## Errores típicos
- Pasar DataFrames enteros o miles/millones de filas por XCom "porque es cómodo": el backend por defecto (metastore) tiene límites de tamaño (en Postgres, por ejemplo, el límite práctico del campo es de unos pocos GB pero rendimiento se degrada mucho antes).
- No plantearse la alternativa: escribir el resultado a un stage de Snowflake o storage externo, y pasar por XCom solo la **ruta** o el nombre del fichero.
- Olvidar que XCom pull/push añade carga al metastore: con muchas tareas en paralelo pasando payloads grandes, puede convertirse en cuello de botella del scheduler.

## Pregunta probable
**¿Qué harías si el payload del BCE fuera de millones de filas en vez de unos miles?** No lo pasaría por XCom: la tarea de extracción escribiría el resultado a un stage (o a una tabla de staging en Snowflake) y por XCom solo pasaría la referencia (ruta, nombre de fichero o query id) para que la siguiente tarea la recoja de ahí.

## Aparece en
- [[airflow-datos-incorrectos-sin-error]]
- Relacionados: [[taskflow-api-vs-operadores-clasicos]], [[copy-into-vs-snowpipe-vs-snowpipe-streaming]]
