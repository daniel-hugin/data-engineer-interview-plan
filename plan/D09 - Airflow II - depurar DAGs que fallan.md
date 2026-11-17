---
tipo: epica
dia: 9
estado: confirmado
tags: [plan-10-dias, airflow, debugging, troubleshooting]
aliases: [D9, Día 9]
---

# ÉPICA D9 — Airflow II: depurar DAGs que fallan

← [[D08 - Airflow I - diseño de DAGs y decisiones|Día 8]] · [[00 - Plan 10 días (índice)|Índice]] · Siguiente: [[D10 - Integración y simulacro de entrevista|Día 10]] →

**Objetivo del día:** diagnosticar con método los fallos típicos de Airflow, del síntoma a la causa y de la causa al arreglo, y saber explicarlo en voz alta.

**DoD de la épica:** todos los tickets en *Done*, y ninguna copia `lab_debug_*` en `dags/` al terminar.

> ⚠ **No romper los DAGs reales del repo.** Tu servidor de Airflow despliega `main` cada 5 minutos y los DAGs de producción dejarían de cargar datos. Trabajar con copias sin versionar en el servidor (`dags/lab_debug_*.py`) y borrarlas al terminar: `sync_repo.sh` no toca los ficheros que no están en Git.

---

## D9-01 · Kit de diagnóstico
**Tipo:** Práctica

**Definition of Done**
- [ ] Ejecutas con `docker compose exec`, y sabes cuándo usar cada uno:
    - `airflow dags list-import-errors`
    - `airflow dags report` (tiempo de parseo por fichero)
    - `airflow tasks test <dag> <tarea> <fecha>`
    - `airflow dags test <dag> <fecha>`
    - `docker compose logs <servicio>` para scheduler, dag-processor y triggerer
- [ ] Localizas los logs de una tarea en la UI y en el volumen de logs.

## D9-02 · Fallo 1: el DAG no aparece
**Tipo:** Práctica

**Definition of Done**
- [ ] En una copia del DAG importas un paquete que no está en la imagen; lo detectas en el aviso de la UI y con `list-import-errors`, y lo arreglas.
- [ ] Repites con un error de sintaxis y con un `dag_id` duplicado, y explicas qué hace Airflow en cada caso.

## D9-03 · Fallo 2: la tarea falla por credenciales
**Tipo:** Práctica

**Definition of Done**
- [ ] En una copia, `snowflake_conn_id` cambiado por uno inexistente; diagnosticado con los logs de la tarea y con `airflow tasks test`.
- [ ] Permiso de lectura de `keys/svc_airflow.p8` quitado temporalmente (`chmod 600`, propiedad de root); error localizado en los logs y explicado (el usuario 50000 del contenedor no puede leerla).
- [ ] Explicas en voz alta por qué `airflow tasks test` es la herramienta adecuada: ejecuta la tarea sin dejar estado en la base de datos ni depender del scheduler.

## D9-04 · Fallo 3: código pesado al parsear
**Tipo:** Práctica

**Definition of Done**
- [ ] En una copia, una llamada HTTP y un `time.sleep(20)` a nivel de módulo.
- [ ] Tiempo de parseo medido antes y después con `airflow dags report`; si se supera `dagbag_import_timeout`, observado el error de *timeout*.
- [ ] Explicas en voz alta por qué el código a nivel de módulo se ejecuta en **cada** parseo y dónde debe ir.

## D9-05 · Fallo 4: tareas atascadas en `queued` o `scheduled`
**Tipo:** Práctica

**Definition of Done**
- [ ] Pool `snowflake` de 1 *slot*, con tareas de dos DAGs asignadas y lanzadas a la vez; una queda esperando.
- [ ] Diagnosticado en la vista de pools de la UI y resuelto.
- [ ] Respondes en voz alta: diferencia entre pools, `max_active_tasks` y `max_active_runs`. ¿Cuándo usarías un pool en un entorno real con Snowflake?

## D9-06 · Fallo 5: datos incorrectos sin error
**Tipo:** Práctica

**Definition of Done**
- [ ] En una copia, `_resolve_period` usa `now()` en lugar del intervalo de datos; *backfill* de 3 días lanzado.
- [ ] En Snowflake, las 3 ejecuciones cargaron el mismo día y los días del *backfill* faltan, aunque Airflow lo marca todo en verde.
- [ ] Explicas en voz alta por qué es el fallo más peligroso y qué lo habría detectado: *freshness*, conteos por fecha, tests de continuidad.

## D9-07 · Checklist por síntoma
**Tipo:** Estudio

**DoD:** respondes en voz alta, sin mirar notas:
1. La tabla *síntoma → qué revisar* para los seis casos: DAG que no aparece, scheduler lento, tarea en `queued`, tarea que falla, datos incorrectos o duplicados, y tareas zombi.
2. ¿Qué es una tarea zombi, qué la provoca y cómo la detecta Airflow?
3. «Un DAG que lleva meses funcionando falla esta noche. Guíame por tu proceso.» Con un orden de comprobaciones, de lo que cambió a lo que se rompió.

Tabla de referencia (para repasar, no para mirar durante la evaluación):

| Síntoma | Qué revisar |
|---|---|
| El DAG no aparece | Errores de importación (`airflow dags list-import-errors`), sintaxis, ruta de `dags_folder` |
| Scheduler lento | Código pesado a nivel superior del fichero (llamadas a APIs o BBDD al parsear) |
| Tarea en `queued` eternamente | Pools llenos, `max_active_tasks`, slots del executor, workers caídos |
| Tarea falla | Logs de la tarea, `airflow tasks test dag_id task_id fecha`, conexiones/variables |
| Datos incorrectos o duplicados | Fechas mal usadas (`now()` en vez del data interval), falta de idempotencia |
| Zombies / tareas muertas | Memoria del worker, timeouts, heartbeats |

---

## Notas del día
