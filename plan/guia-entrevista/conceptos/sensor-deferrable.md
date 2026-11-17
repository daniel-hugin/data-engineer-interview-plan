---
tipo: concepto
herramienta: airflow
aliases: [deferrable sensor, sensor diferible, triggerer, smart sensors]
tags: [guia-entrevista, airflow]
---
# Sensor deferrable

> [!tip] Respuesta rápida
> Un sensor normal ("poke") ocupa un slot de worker todo el tiempo que espera. Un sensor `deferrable=True` libera ese slot: la espera la gestiona el proceso **triggerer** (asíncrono, muy ligero), y el worker solo vuelve a ocuparse cuando la condición se cumple.

## Definición

Un sensor espera a que se cumpla una condición externa (una hora, un fichero, una fila en una tabla) antes de dejar avanzar el DAG. En modo **poke** (el clásico), el worker comprueba la condición a intervalos y se queda bloqueado ocupando un slot todo el tiempo que dure la espera, aunque el 99% de ese tiempo no esté haciendo nada.

Un sensor **deferrable** delega la espera a un proceso distinto, el **triggerer**: en vez de bloquear un worker, la tarea se serializa y el triggerer (un loop async muy ligero, puede vigilar miles de condiciones a la vez con poca memoria) se encarga de comprobar la condición. Cuando se cumple, el triggerer dispara un evento y un worker vuelve a tomar la tarea solo para ese instante final. El resultado: esperas largas (horas) no consumen capacidad de worker, solo la del triggerer. El modo intermedio, `reschedule`, libera el slot *entre* cada poke pero sigue siendo un worker el que vuelve a comprobar cada vez — no delega nada a un proceso async distinto. Esto compite directamente por los mismos recursos que [[pools-max-active-tasks-max-active-runs|pools y max_active_tasks]] gestionan desde otro ángulo.

## Ejemplo mínimo
```python
from airflow.providers.standard.sensors.date_time import DateTimeSensor

wait_for_ecb_publication = DateTimeSensor(
    task_id="wait_for_ecb_publication",
    target_time="{{ data_interval_end }}",
    deferrable=True,
)
```
Esperando la hora de publicación diaria del BCE: sin `deferrable`, esa espera (horas) bloquea un worker entero haciendo nada.

## Errores típicos
- No tener el **triggerer** desplegado/corriendo: sin él, `deferrable=True` no sirve de nada, las tareas no se reanudan.
- Usar poke (`mode="poke"`) con tiempos de espera largos: consume slots de worker que otras tareas necesitan, puede provocar cuellos de botella en todo el cluster.
- Confundir `deferrable` con `reschedule`: `reschedule` libera el slot entre pokes pero sigue poll-eando con un worker periódicamente; `deferrable` delega la espera entera al triggerer con un evento async, sin polling de worker.

## Pregunta probable
**¿Qué diferencia hay entre un sensor en modo poke y uno deferrable?** El de poke bloquea un worker mientras espera (comprobando la condición a intervalos, ocupando el slot todo el rato). El deferrable entrega el control al triggerer y libera el worker; cuando la condición se cumple, el triggerer reactiva la tarea y un worker la reanuda. Mejor uso de recursos con esperas largas.

## Aparece en
- [[airflow-tarea-atascada-en-queued]]
- Relacionados: [[assets-vs-cron-vs-sensor]], [[pools-max-active-tasks-max-active-runs]]
