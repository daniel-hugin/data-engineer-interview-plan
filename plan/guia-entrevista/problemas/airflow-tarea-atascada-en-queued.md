---
tipo: problema
herramienta: airflow
prioridad: alta
aliases: [tarea atascada en queued, tarea en scheduled mucho tiempo, task stuck queued, pool lleno airflow, max_active_tasks bloqueado]
tags: [guia-entrevista, airflow]
---
# La tarea lleva mucho tiempo en `queued` o `scheduled`

> [!tip] Respuesta rápida
> Antes de pensar en el executor, mira los **pools**: un pool pequeño (ej. 1 slot) compartido por tareas de varios DAGs se llena rápido y deja todo lo demás esperando.

## Hipótesis (de más barata a más cara de comprobar)
1. **Pool lleno** → ejemplo típico: un pool `snowflake` de 1 slot, con tareas de dos DAGs distintos queriendo usarlo a la vez; solo una corre, el resto queda en `queued`.
2. **`max_active_tasks` o `max_active_runs` alcanzado** → el propio DAG limita cuántas tareas o runs concurrentes puede tener, y ya está en el máximo.
3. **Slots del executor agotados o workers caídos** → no es un límite lógico sino falta de capacidad real para ejecutar.

## Diagnóstico paso a paso
1. UI de Airflow → **Admin → Pools**: mira slots usados vs totales del pool implicado, y qué tareas los ocupan.
2. Revisa la configuración del DAG: `max_active_tasks`, `max_active_runs` en la definición.
3. En el servidor de Airflow:
```bash
docker compose logs scheduler
```
Busca mensajes sobre slots agotados, workers no disponibles, o tareas esperando pool.

## Solución
- **Pool lleno**: aumenta el tamaño del pool si el recurso real lo permite, o separa las tareas en pools distintos si no deberían competir entre sí.
- **Límites del DAG**: sube `max_active_tasks`/`max_active_runs` si el recurso subyacente (ej. el warehouse) puede soportarlo.
- **Executor sin capacidad**: añade workers o revisa por qué están caídos (logs, recursos del host).

## Prevención
- **Dimensionar pools según el recurso real que protegen** (ej. un pool `snowflake` de 1 slot solo tiene sentido si de verdad un solo warehouse no soporta concurrencia; si no, es un cuello de botella artificial).
- Documentar qué pools existen y por qué, para no crear dos DAGs que compitan sin saberlo por el mismo pool.
- Alertar cuando una tarea lleva más de X minutos en `queued`, no solo cuando falla.

## Cómo contarlo
Una tarea llevaba mucho tiempo en `queued`; la primera hipótesis fue un pool lleno, porque el pool `snowflake` tenía solo 1 slot y dos DAGs lo usaban a la vez. Lo confirmé en la vista de Pools de la UI, viendo los slots ocupados y qué tarea los tenía. La solución fue separar las tareas en pools distintos según si realmente competían por el mismo recurso. Para prevenirlo, reviso que el tamaño del pool corresponda al recurso real que protege, no a un número arbitrario.

## Conceptos relacionados
- [[pools-max-active-tasks-max-active-runs]]
- [[airflow-scheduler-lento-parseo-pesado]]
- [[sensor-deferrable]]
