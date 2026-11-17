---
tipo: concepto
herramienta: airflow
aliases: [taskflow api, operadores clasicos, bashoperator vs taskflow, decoradores airflow, task decorator]
tags: [guia-entrevista, airflow]
---
# TaskFlow API vs operadores clásicos

> [!tip] Respuesta rápida
> TaskFlow (`@dag`/`@task`) escribes Python puro y Airflow infiere el XCom (lo que devuelves de una función se pasa a la siguiente). Los operadores clásicos (`BashOperator`, `PythonOperator`...) se instancian explícitamente y conectas tareas con `>>`. Ambos conviven en el mismo repo según lo que cada DAG necesita.

## Definición

Los operadores clásicos (`BashOperator`, `PythonOperator`, `SnowflakeOperator`...) son la forma original de definir tareas en Airflow: instancias de una clase, con sus dependencias conectadas explícitamente (`a >> b`), y el paso de datos entre tareas gestionado a mano con `xcom_push`/`xcom_pull` si hace falta. La **TaskFlow API** (desde Airflow 2.0) añade los decoradores `@dag`/`@task`: escribes funciones Python normales, y Airflow convierte automáticamente el valor de retorno de una en un [[xcom|XCom]] que la siguiente función recibe como argumento, sin boilerplate.

No son mecanismos incompatibles ni excluyentes — son dos formas de declarar tareas sobre el mismo motor de ejecución, y se pueden mezclar en el mismo DAG. TaskFlow brilla cuando hay lógica Python real con datos que fluyen entre tareas; los operadores clásicos siguen siendo más directos cuando la tarea es "ejecutar un comando externo" (un script, un `dbt build`), donde envolver un `subprocess` dentro de una función `@task` no aporta nada sobre un `BashOperator` ya hecho para eso.

## Ejemplo mínimo
TaskFlow en `ecb_exchange_rates.py`:
```python
@task
def extract() -> dict: ...

@task(outlets=[ECB_EXCHANGE_RATES])
def load(payload: dict) -> int: ...

load(extract())  # XCom implícito, legible como código normal
```
Clásico en `dbt_travel_dwh.py`:
```python
source_freshness = BashOperator(task_id="dbt_source_freshness", bash_command="...")
build = BashOperator(task_id="dbt_build", bash_command="...")
source_freshness >> build
```

## Errores típicos
- Forzar TaskFlow para todo: cuando la tarea es "ejecutar un comando" (como `dbt build`), un `BashOperator` es más directo que envolver un subprocess dentro de una función `@task`.
- Forzar operadores clásicos para lógica Python con dependencias de datos entre tareas: ahí TaskFlow evita el boilerplate de `xcom_pull`/`xcom_push` manual.
- Pensar que son incompatibles: se pueden mezclar en el mismo DAG.

## Pregunta probable
**¿Por qué este repo usa TaskFlow en un DAG y BashOperator clásico en otro?** `ecb_exchange_rates` es lógica Python (llamar a una API, transformar, cargar a Snowflake) con paso de datos entre tareas: TaskFlow es natural ahí. `dbt_travel_dwh` solo ejecuta comandos de shell (`dbt source freshness`, `dbt build`); no hay datos Python que pasar entre tareas, así que `BashOperator` con `>>` es más simple y explícito.

## Aparece en
- [[airflow-dag-no-aparece]]
- Relacionados: [[xcom]], [[orquestar-dbt-bashoperator-vs-cosmos-vs-dbt-cloud]]
