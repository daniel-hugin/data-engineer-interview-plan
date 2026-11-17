---
tipo: problema
herramienta: airflow
prioridad: alta
aliases: [scheduler de airflow va lento, parseo de DAGs lento, dagbag import timeout, scheduler performance, parsing pesado a nivel de modulo]
tags: [guia-entrevista, airflow]
---
# El scheduler va lento

> [!tip] Respuesta rápida
> Casi siempre es **código a nivel de módulo** (llamadas HTTP, conexión a BBDD, `sleep`, cálculos pesados) que se ejecuta en cada parseo del fichero, no dentro de una tarea. El scheduler reparsea los DAGs constantemente.

## Hipótesis (de más barata a más cara de comprobar)
1. **Lógica pesada fuera de un `@task`** → cualquier código al nivel superior del fichero (fuera de operadores/funciones de tarea) corre cada vez que el `DagFileProcessor` parsea el fichero, no solo cuando se ejecuta la tarea.
2. **Muchos DAGs o ficheros grandes** → el volumen total de parseo supera lo razonable para el intervalo configurado.
3. **`dagbag_import_timeout` demasiado ajustado** para el tiempo real que tarda el parseo.

## Diagnóstico paso a paso
```bash
# tiempo de parseo por DAG, ordenado de más lento a más rápido
airflow dags report
```
Busca el/los DAGs con mayor tiempo de importación. Compara ese número contra `dagbag_import_timeout` (configuración del scheduler): si se acerca o lo supera, el scheduler puede marcar el DAG como fallido al parsear o ralentizar el resto de la cola de parseo.

Revisa el código del DAG sospechoso buscando, a nivel de módulo (fuera de funciones):
- llamadas HTTP (`requests.get(...)`)
- conexiones a base de datos
- `time.sleep(...)`
- lecturas de ficheros grandes o cálculos no triviales

## Solución
Mueve toda esa lógica dentro de un `@task` (TaskFlow) o dentro del `execute()` de un operador, para que solo corra cuando la tarea se ejecuta, no en cada parseo:

```python
# mal: corre en cada parseo del scheduler
config = requests.get("https://api.ejemplo.com/config").json()

# bien: solo corre cuando la tarea se ejecuta
@task
def cargar_config():
    return requests.get("https://api.ejemplo.com/config").json()
```

## Prevención
- **Code review** específico para imports y código pesado a nivel de módulo en cada PR de DAGs.
- Medir `airflow dags report` periódicamente como parte de la rutina de mantenimiento, no solo cuando ya hay síntomas.
- Mantener los DAGs "declarativos": definición de estructura arriba, lógica real siempre dentro de tareas.

## Cómo contarlo
El scheduler empezó a ir lento en general; la hipótesis fue código pesado a nivel de módulo en alguno de los DAGs, ya que ese código corre en cada parseo, no solo al ejecutar la tarea. Lo confirmé con `airflow dags report`, que mostró un DAG con tiempo de importación mucho mayor que el resto, cerca del `dagbag_import_timeout`. La causa era una llamada HTTP fuera de cualquier tarea. La solución fue moverla dentro de un `@task`. Lo prevengo con code review centrado en imports y código a nivel de módulo.

## Conceptos relacionados
- [[taskflow-api-vs-operadores-clasicos]]
- [[airflow-dag-no-aparece]]
- [[data-interval-vs-logical-date]]
