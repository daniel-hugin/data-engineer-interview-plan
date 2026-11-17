---
tipo: comandos
herramienta: airflow
aliases: [chuleta airflow, comandos airflow, airflow cheatsheet, airflow cli]
tags: [guia-entrevista, airflow]
---
# Chuleta de comandos: Airflow

> [!tip] Respuesta rápida
> Úsala para "¿cómo depurarías un DAG/tarea en Airflow?". Todo se ejecuta desde el servidor donde corre Airflow, vía `docker compose exec <servicio> airflow ...`.

## Diagnóstico
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `docker compose exec scheduler airflow dags list-import-errors` | Lista DAGs que fallan al parsear (excepciones de import) | El DAG no aparece en la UI → primer comando a correr |
| `docker compose exec scheduler airflow dags report` | Tiempos de parseo de cada fichero de DAG | Sospecha de que el scheduler va lento por un parseo pesado |

## Ejecución manual
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `docker compose exec scheduler airflow tasks test <dag_id> <task_id> <fecha>` | Ejecuta **una tarea** sin tocar el metastore (no crea TaskInstance real, no respeta dependencias) | Depurar la lógica de una tarea concreta rápido |
| `docker compose exec scheduler airflow dags test <dag_id> <fecha>` | Ejecuta **el DAG completo** para una fecha, sin scheduler, sin dejar estado permanente | Validar el DAG entero de punta a punta antes de confiar en él |
| `docker compose exec scheduler airflow backfill create --dag-id <dag_id> --from-date <f1> --to-date <f2>` | Backfill real (Airflow 3), crea DagRuns de verdad y respeta pools/concurrencia | Rellenar histórico o reprocesar un rango tras un fix |

## Logs
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `docker compose logs scheduler` | Logs del scheduler (colas, heartbeats, errores de parseo) | Tareas que no arrancan o DAG que no se programa |
| `docker compose logs dag-processor` | Logs del proceso que parsea los DAGs (separado del scheduler en Airflow 3) | Error de import de un DAG, parseo lento |
| `docker compose logs triggerer` | Logs del triggerer (tareas deferrable/async) | Sensores en modo deferrable que no despiertan |

**Pools**: Admin → Pools en la UI, muestra slots usados/disponibles por pool — útil para ver si una tarea está en cola por falta de slots, no por fallo real.
**Logs de una tarea**: en la UI, Grid/Graph → click en la tarea → **Logs**, o en disco bajo el `logs/` montado por el compose.

## Conceptos relacionados
- [[airflow-dag-no-aparece]]
- [[airflow-scheduler-lento-parseo-pesado]]
- [[airflow-tarea-atascada-en-queued]]
- [[pools-max-active-tasks-max-active-runs]]
- [[data-interval-vs-logical-date]]
