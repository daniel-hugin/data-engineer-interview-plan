---
tipo: problema
herramienta: airflow
prioridad: alta
aliases: [DAG no aparece en la UI, DAG desaparece de Airflow, dag not showing up, import error airflow, dag_id duplicado]
tags: [guia-entrevista, airflow]
---
# El DAG no aparece en la UI (o desaparece)

> [!tip] Respuesta rápida
> Casi siempre es un **error de importación**. Empieza por `airflow dags list-import-errors`: te da el fichero y la traza exacta, sin tener que adivinar.

## Hipótesis (de más barata a más cara de comprobar)
1. **Error de importación** → excepción al cargar el módulo (import que falla, variable/conexión que no existe en tiempo de parseo).
2. **Error de sintaxis** → typo, indentación, paréntesis sin cerrar.
3. **`dag_id` duplicado** → dos ficheros (o el mismo DAG definido dos veces) con el mismo `dag_id`; Airflow se queda con uno o con ninguno.
4. **Fichero fuera de `dags_folder`** → está en el repo pero no en la ruta que el scheduler escanea (o el despliegue por *pull* no lo trajo).

## Diagnóstico paso a paso
```bash
# 1. lista errores de importación con fichero y traceback
airflow dags list-import-errors

# 2. confirma que el DAG existe para Airflow
airflow dags list | grep <dag_id>

# 3. si sospechas dag_id duplicado
grep -r "dag_id" dags/ | grep "<dag_id>"
```
Ejecuta esto en el servidor donde corre Airflow.

## Solución
- **Import error**: corrige la excepción exacta que muestra el traceback (módulo no instalado, variable de Airflow no definida, etc.).
- **Sintaxis**: corrige el fichero; valida localmente con `python dags/mi_dag.py` antes de hacer push.
- **`dag_id` duplicado**: renombra uno de los dos, o elimina el fichero duplicado/viejo.
- **Fuera de carpeta**: mueve el fichero a `dags/` y confirma que el despliegue por *pull* lo trajo (`git log` en el servidor).

## Prevención
- **CI que importe los DAGs** antes de desplegar (ej. un step que corra `python -c "import dags.mi_dag"` o `airflow dags list-import-errors` en un entorno de prueba).
- Convención de nombres para `dag_id` únicos (prefijo por dominio, ej. `ecb_exchange_rates`).
- No poner lógica pesada a nivel de módulo que pueda fallar en el parseo (ver scheduler lento).

## Cómo contarlo
Un DAG dejó de aparecer en la UI; la hipótesis más barata era un error de importación, así que empecé por `airflow dags list-import-errors` en vez de leer el código a ciegas. El comando señaló el fichero y la línea exacta del fallo. La causa era un `dag_id` duplicado entre dos ficheros. La solución fue renombrar uno; para prevenirlo, propondría un check en CI que importe los DAGs antes de desplegar.

## Conceptos relacionados
- [[airflow-scheduler-lento-parseo-pesado]]
- [[taskflow-api-vs-operadores-clasicos]]
- [[airflow]]
