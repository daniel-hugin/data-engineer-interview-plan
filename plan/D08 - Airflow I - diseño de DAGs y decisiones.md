---
tipo: epica
dia: 8
estado: confirmado
tags: [plan-10-dias, airflow, orquestacion, idempotencia, assets]
aliases: [D8, Día 8]
---

# ÉPICA D8 — Airflow I: diseño de DAGs y decisiones

← [[D07 - CICD con GitHub Actions|Día 7]] · [[00 - Plan 10 días (índice)|Índice]] · Siguiente: [[D09 - Airflow II - depurar DAGs que fallan|Día 9]] →

**Objetivo del día:** explicar y demostrar los principios de diseño de un DAG (idempotencia, atomicidad, intervalos de datos) sobre los DAGs propios, y saber elegir cómo orquestar dbt.

**DoD de la épica:** tickets D8-01 a D8-06 en *Done*. D8-07 es opcional.

Los pools y los fallos provocados quedan para el día 9, que es el de depuración.

---

## D8-01 · Idempotencia y atomicidad, demostradas
**Tipo:** Práctica

**Definition of Done**
- [ ] `ecb_exchange_rates` lanzado dos veces para la misma fecha pasada; en Snowflake, el número de filas de ese día no cambia.
- [ ] Explicas en voz alta, sobre el código del DAG, qué lo hace **idempotente** (borrar e insertar por rango) y qué lo hace **atómico** (la transacción con `rollback`).
- [ ] Respondes en voz alta: ¿qué pasaría con un simple `INSERT` si la tarea falla a mitad y Airflow la reintenta?

## D8-02 · Intervalos de datos y *backfill*
**Tipo:** Práctica

**Definition of Done**
- [ ] Explicas, con una ejecución real, la diferencia entre `logical_date`, `data_interval_start` y `data_interval_end`, y por qué el DAG del BCE usa el intervalo y no `now()`.
- [ ] *Backfill* de una semana con el CLI de Airflow 3 (`airflow backfill create`), observado en la UI.
- [ ] Respondes en voz alta: *backfill* con el scheduler frente a carga masiva con `params` (la del histórico desde 2013). ¿Cuándo eliges cada una?
- [ ] Respondes en voz alta: ¿qué hace `catchup` y por qué en Airflow 3 viene desactivado por defecto?

## D8-03 · Planificación por Assets
**Tipo:** Práctica

**Definition of Done**
- [ ] Una carga correcta del BCE genera un evento del Asset `raw.ecb.exchange_rates` que dispara `dbt_travel_dwh` (comprobado en la UI).
- [ ] Provocas un fallo en la carga del BCE y compruebas que dbt **no** se ejecuta.
- [ ] Respondes en voz alta: Assets frente a cron fijo frente a sensor. ¿Qué problema resuelve cada uno?

## D8-04 · Sensor *deferrable*
**Tipo:** Práctica

**Definition of Done**
- [ ] Sensor *deferrable* añadido al DAG del BCE que espera a la hora de publicación de los tipos (por ejemplo, `DateTimeSensor` con `deferrable=True`).
- [ ] La tarea aparece en estado `deferred` en la UI, gestionada por el *triggerer*.
- [ ] Explicas en voz alta qué gana un sensor *deferrable* frente a uno en modo `poke` (el *slot* del worker queda libre).

## D8-05 · Orquestar dbt: BashOperator, Cosmos o dbt Cloud
**Tipo:** Estudio

**DoD:** defiendes con la estructura *contexto → opciones → elijo X porque… → riesgo y mitigación*:
1. La elección del repo (un único `dbt build` en un BashOperator) frente a Astronomer Cosmos (una tarea por modelo) frente a disparar un job de dbt Cloud. Cubre: granularidad de reintentos, visibilidad, tiempo de parseo y acoplamiento de dependencias.
2. ¿En qué momento de crecimiento del proyecto cambiarías de opción?

## D8-06 · Fundamentos y Airflow 3
**Tipo:** Estudio

**DoD:** respondes en voz alta, sin mirar notas:
1. TaskFlow API frente a operadores clásicos: ¿cuándo cada uno? El repo usa los dos: ¿por qué?
2. ¿Qué límites tiene XCom y qué harías para pasar un volumen grande de datos entre tareas?
3. Reintentos con *backoff* exponencial: ¿por qué son adecuados para una API externa como la del BCE?
4. *(Migración)* Tres cambios de Airflow 3 respecto a 2.x que afectarían a una migración real. Pista: los del montaje (Assets, *dag-processor* separado, API server y su JWT, `logical_date` en ejecuciones manuales).

## D8-07 · *(Opcional)* Cosmos en la práctica
**Tipo:** Tarea (*stretch*)

**Definition of Done**
- [ ] En una rama, Astronomer Cosmos añadido a la imagen (tras comprobar su compatibilidad con la versión de Airflow) y un DAG alternativo que renderiza el proyecto dbt como grupo de tareas.
- [ ] Comparación en la UI de ambos DAGs: número de tareas, logs por modelo y comportamiento al reintentar un modelo que falla.

---

## Notas del día
