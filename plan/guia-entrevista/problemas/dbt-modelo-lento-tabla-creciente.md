---
tipo: problema
herramienta: dbt
prioridad: alta
aliases: [modelo dbt cada vez más lento, tabla de 40 millones de filas, full-refresh innecesario, spilling sintoma no causa, incremental roto]
tags: [guia-entrevista, dbt, snowflake]
---
# Un modelo de dbt que antes iba rápido ahora tarda mucho más (tabla ha crecido)

> [!tip] Respuesta rápida
> Sospechoso principal: el modelo reprocesa el histórico completo en cada build (es `table`/full-refresh cuando debería ser `incremental`, o es incremental con el filtro roto), y el coste crece con el **tamaño total** de la tabla, no con lo nuevo. El *spilling*, si aparece, suele ser **síntoma** del volumen real, no la causa — no asumas que escalar el warehouse lo arregla del todo.

## Hipótesis (de más barata a más cara de comprobar)
1. **Cambio reciente en el código**: `git log` del modelo y de sus fuentes — a veces el aumento coincide con un commit concreto.
2. **Materialización incorrecta o rota**: ¿es `table` (full-refresh por diseño) cuando debería ser `incremental`? ¿O ya es `incremental` pero el filtro de `is_incremental()` está mal escrito y acaba escaneando casi todo igual?
3. **Pérdida de poda**: si la tabla creció, el patrón de filtro que antes correlacionaba bien con el orden de inserción puede haber dejado de hacerlo — ver [[micro-particiones-y-clustering-keys]].
4. **Un `JOIN` con una tabla que también ha crecido**: fan-out que antes no se notaba con poco volumen, ahora sí — ver [[fan-out-en-joins]].
5. **Spilling**: hipótesis cara y a menudo engañosa — con 40M filas es *esperable* que aparezca spilling en operaciones intermedias grandes, pero eso no significa que sea la causa a atacar. Es un síntoma del volumen, no un problema independiente.

## Diagnóstico paso a paso
```bash
grep -n "insert\|merge\|delete" airflow/dags/*.py  # si aplica, o git log del modelo
```
```sql
-- particiones/bytes escaneados vs total de la tabla: ¿se lee todo o solo lo nuevo?
-- ver conceptos/query-profile-metricas-y-diagnostico.md para la lectura completa de estas métricas
```
Para distinguir "full-refresh por diseño" de "incremental roto", mirar el **SQL compilado** real de la ejecución:
```bash
cat target/compiled/<proyecto>/models/.../<modelo>.sql
```
Si ves un `CREATE OR REPLACE TABLE ... AS SELECT` completo sin ningún filtro por fecha/timestamp, es full-refresh. Si ves un `MERGE` pero con un `WHERE` que no recorta nada (o ausente), el incremental está mal escrito.

## Solución
Definir o corregir la materialización incremental:
```sql
{{ config(
    materialized='incremental',
    unique_key='id_reserva',
    incremental_strategy='merge'
) }}

select ...
{% if is_incremental() %}
where fecha_actualizacion > (select max(fecha_actualizacion) from {{ this }})
{% endif %}
```
Elegir la estrategia (`merge`/`append`/`delete+insert`) según el caso — ver [[estrategia-incremental-merge-delete-insert-append]] y [[materializacion-view-table-incremental-ephemeral]] para el detalle de cada una.

**No perseguir el spilling como si fuera la causa**: si después del fix el modelo sigue derramando a disco pero ahora procesa solo una fracción de los datos (y el tiempo total bajó drásticamente), el spilling restante es proporcional al volumen real que sí hace falta procesar — ya no es el problema.

## Validación del fix
1. `dbt run --select <modelo> --full-refresh --target dev` — primera ejecución en modo incremental, reconstruye desde cero.
2. Ejecuciones siguientes normales: comprobar en el Query Profile que las particiones/bytes escaneados son una fracción pequeña del total, no el 100%.
3. Medir el tiempo: debería volver a un orden de magnitud parecido al original.
4. `select count(*)` antes/después, y comprobar unicidad por `unique_key` si usas `merge` (sin duplicados).
5. Probar el caso borde "no hay datos nuevos desde la última carga" — no debe fallar ni reprocesar de más.
6. `dbt test` completo para confirmar que no se rompió nada downstream.
7. Todo en `dev`/`ci` antes de tocar `prod`.

## Prevención
- Alertar si el tiempo de ejecución de un modelo crece más rápido que el volumen de datos esperado (indicio de full-refresh disfrazado de normal).
- Code review: cualquier modelo sobre una tabla que se sabe que va a crecer sin límite debería justificar explícitamente por qué es `table` y no `incremental`, si lo es.
- Revisar periódicamente el Query Profile de los modelos más pesados, no solo cuando alguien se queja.

## Cómo contarlo
Un modelo de dbt sobre una tabla de reservas pasó de 2 a 8 minutos al crecer la tabla a 40 millones de filas. Primero descarté cambios recientes en el código (`git log` limpio). La hipótesis principal fue que el modelo reprocesaba todo el histórico en cada build — lo confirmé en el Query Profile viendo que las particiones escaneadas eran prácticamente el 100% de la tabla. Antes de tocar nada, descarté que el *spilling* visible fuera la causa real: con ese volumen, cierto spilling es esperable, y confirmé esto probando a escalar el warehouse de XS a M en un caso similar — el tiempo bajó pero el volumen derramado apenas cambió, lo que indica que el spilling era síntoma del volumen, no el cuello de botella en sí. La solución fue definir correctamente la materialización `incremental` con un filtro por timestamp, validar con un `--full-refresh` inicial y confirmar que las ejecuciones siguientes escaneaban solo una fracción de la tabla.

## Conceptos relacionados
- [[query-profile-metricas-y-diagnostico]]
- [[materializacion-view-table-incremental-ephemeral]]
- [[estrategia-incremental-merge-delete-insert-append]]
- [[fan-out-en-joins]]
- [[micro-particiones-y-clustering-keys]]
