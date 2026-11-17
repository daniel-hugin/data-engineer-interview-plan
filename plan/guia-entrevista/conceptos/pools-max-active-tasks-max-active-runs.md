---
tipo: concepto
herramienta: airflow
aliases: [pools airflow, max_active_tasks, max_active_runs, concurrencia airflow, slots airflow]
tags: [guia-entrevista, airflow]
---
# Pools, max_active_tasks, max_active_runs

> [!tip] Respuesta rápida
> Tres límites de concurrencia distintos. **Pool**: slots compartidos entre tareas de distintos DAGs (ej. limitar conexiones simultáneas a Snowflake). **max_active_tasks**: cuántas tareas de **un mismo DAG** corren en paralelo. **max_active_runs**: cuántas ejecuciones (runs) de **ese DAG** están activas a la vez.

## Definición

Airflow tiene varios ejes de concurrencia independientes, fáciles de confundir porque todos "limitan cuántas cosas corren a la vez" pero a distinto nivel:

- **`max_active_tasks`** (antes `concurrency`): cuántas *tareas* de un mismo DAG pueden ejecutarse en paralelo, dentro de un mismo run o entre runs solapados de ese DAG.
- **`max_active_runs`**: cuántas *ejecuciones completas* (runs) de ese DAG pueden estar activas simultáneamente — independiente de cuántas tareas tenga cada run.
- **Pool**: un conjunto de slots compartido **entre DAGs distintos**, para limitar el acceso a un recurso externo concreto (p. ej. conexiones a un warehouse de Snowflake). Una tarea se asigna a un pool con `pool="nombre"`; si el pool tiene N slots, solo N tareas de cualquier DAG que use ese pool corren a la vez, sin importar los límites de `max_active_tasks`/`max_active_runs` de cada DAG por separado.

La combinación importa: puedes tener `max_active_runs=1` (no se solapan dos backfills del mismo DAG) y aun así necesitar un pool si varios DAGs *distintos* atacan el mismo warehouse a la vez. Ver [[sensor-deferrable]] para otro mecanismo (liberar el worker durante una espera) que alivia presión sobre estos mismos límites de concurrencia.

## Ejemplo mínimo
Del repo, `max_active_runs=1` en ambos DAGs:
```python
@dag(
    dag_id="ecb_exchange_rates",
    schedule="@daily",
    max_active_runs=1,   # no se superponen cargas del mismo rango
    ...
)
```
```python
@dag(
    dag_id="dbt_travel_dwh",
    schedule=[ECB_EXCHANGE_RATES],
    max_active_runs=1,   # no se solapan dos `dbt build` sobre las mismas tablas
    ...
)
```
Un pool no aparece en el código actual, pero se declararía así para limitar conexiones a Snowflake:
```python
BashOperator(task_id="dbt_build", pool="snowflake_pool", ...)
```

## Errores típicos
- Confundir `max_active_tasks` (paralelismo dentro de un DAG) con `max_active_runs` (paralelismo entre ejecuciones del mismo DAG): son ejes distintos.
- No usar un pool y asumir que Snowflake aguanta conexiones ilimitadas: con muchos DAGs lanzando queries a la vez, puedes saturar el warehouse o chocar con límites de conexión.
- Poner `max_active_runs=1` por costumbre sin pensar si el DAG realmente necesita exclusión (aquí sí: evita pisar el mismo rango de fechas o reconstruir las mismas tablas dos veces a la vez).

## Pregunta probable
**¿Cuándo usarías un pool con Snowflake en un entorno real?** Cuando varios DAGs/tareas lanzan queries a Snowflake en paralelo y quieres limitar cuántas conexiones concurrentes se abren (por coste de warehouse, por límites de conexión, o para no competir por el mismo warehouse con otras cargas). Creas un pool con N slots y asignas esa tarea al pool; aunque haya 20 tareas listas, solo N corren a la vez contra Snowflake.

## Aparece en
- [[snowflake-factura-se-duplica]]
- Relacionados: [[sensor-deferrable]], [[escalar-warehouse-arriba-vs-fuera]]
