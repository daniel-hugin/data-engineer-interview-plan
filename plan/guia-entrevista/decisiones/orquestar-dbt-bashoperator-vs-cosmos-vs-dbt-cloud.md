---
tipo: decision
herramienta: airflow
prioridad: alta
aliases: [cosmos vs bashoperator, orquestar dbt en airflow, dbt cloud vs airflow, astronomer cosmos]
tags: [guia-entrevista, airflow, dbt]
---
# Orquestar dbt: BashOperator vs Astronomer Cosmos vs dbt Cloud

> [!tip] Respuesta rápida
> **Un `dbt build` en BashOperator** cuando el proyecto es pequeño y el acoplamiento no importa; **Cosmos** cuando quiero reintentos y logs por modelo; **dbt Cloud** cuando no quiero gestionar la infraestructura de ejecución en absoluto.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| BashOperator (un `dbt build`) | Simple, un solo paso de parseo, bajo acoplamiento con Airflow | Reintento es todo-o-nada: si falla el modelo 50 de 60, se reintentan los 60 | Proyecto pequeño/mediano, pocos modelos, parseo rápido |
| Cosmos | Una tarea por modelo: reintentos granulares, logs y estado por modelo en la UI de Airflow | Más tareas = más overhead de scheduler, tiempo de parseo del DAG sube con el nº de modelos | Proyecto grande donde ver qué modelo exacto falló importa |
| dbt Cloud | Cero infraestructura propia, UI y API de jobs ya hechas | Dependencia de un servicio externo, coste de licencia, menos control de la orquestación global | No se quiere mantener ejecución propia y ya se paga dbt Cloud |

## En travel-dwh-lab
`dbt_travel_dwh.py` usa un único `BashOperator` con `dbt deps && dbt build`. El comentario del propio DAG lo justifica: con `LocalExecutor` daría igual separar tareas, pero con Celery/Kubernetes cada tarea podría ir a otro worker y `dbt_packages` no existiría ahí — separar en varias tareas sin compartir el `packages-install-path` rompería el build. Es la decisión correcta para el tamaño actual del proyecto (3 capas, pocos modelos).

## Respuesta modelo
Contexto: tengo que decidir cómo ejecutar dbt desde Airflow. Opciones: un `dbt build` en BashOperator, Cosmos (tarea por modelo) o dbt Cloud. Elijo BashOperator porque el proyecto tiene pocos modelos y el tiempo de parseo es bajo; separar por modelo con Cosmos añadiría overhead de scheduler sin beneficio real todavía. El riesgo es perder granularidad: si falla un modelo, se reintenta todo el build. Lo mitigo con `execution_timeout` y mirando los logs de dbt (que sí indican qué modelo exacto falló) en vez de depender de que Airflow lo muestre por tarea. Cambiaría a Cosmos en el momento en que el número de modelos o el tiempo de build crecieran lo bastante para que un reintento completo sea caro, o cuando el equipo crezca y necesite ver el estado por modelo en la UI sin leer logs de texto.

## Conceptos relacionados
- [[airflow-assets]]
- [[taskflow-api-vs-operadores-clasicos]]
- [[slim-ci-y-defer]]
