---
tipo: decision
herramienta: snowflake
prioridad: media
aliases: [streams and tasks, dynamic tables, cdc en snowflake, tasks nativas snowflake]
tags: [guia-entrevista, snowflake]
---
# Streams + Tasks vs Dynamic Tables

> [!tip] Respuesta rápida
> **Streams + Tasks** cuando necesito lógica de transformación explícita y control fino del *trigger*; **Dynamic Tables** cuando quiero declarar el resultado final y que Snowflake gestione el refresco incremental por mí.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| Streams + Tasks | CDC explícito (qué cambió desde el último consumo), control total del SQL y la cadencia | Más código a mantener, hay que encadenar tasks y gestionar dependencias a mano | Transformaciones con lógica procedural o condicional sobre los cambios |
| Dynamic Tables | Declarativo (defines el SELECT final, Snowflake calcula el refresco incremental), `target_lag` simple | Menos control sobre el *cómo* se refresca, caja algo más negra para depurar | Pipelines de transformación simples tipo vista materializada con refresco gestionado |

## En travel-dwh-lab
El repo no usa ninguna de las dos: tanto la carga del BCE como la construcción de dbt se orquestan con **Airflow**, no con Tasks nativas de Snowflake. La razón (D2-05.3): Airflow ya orquesta todo el pipeline (ingesta HTTP externa al BCE, que Snowflake no puede hacer nativamente) y usar Tasks añadiría un segundo orquestador paralelo para una sola pieza, duplicando donde vive la lógica de dependencias y de alertas.

## Respuesta modelo
Contexto: la carga del BCE podría hacerse con Tasks nativas de Snowflake en vez de Airflow. Opciones: Tasks (todo dentro de Snowflake) o Airflow (orquestador externo). Elijo Airflow porque la extracción es una llamada HTTP a una API externa y necesito reintentos con backoff, un *data interval* explícito y un Asset que dispare dbt después — piezas que Airflow ya me da y Tasks no cubre bien (Tasks es fuerte para SQL encadenado dentro de Snowflake, no para llamadas HTTP externas). Cambiaría de opinión si toda la lógica viviera ya dentro de Snowflake (p. ej. un Stream sobre una tabla ya cargada por otro proceso) y no necesitara llamar a APIs externas; ahí Streams+Tasks o Dynamic Tables evitarían mantener un DAG solo para encadenar SQL.

## Conceptos relacionados
- [[copy-into-vs-snowpipe-vs-snowpipe-streaming]]
- [[airflow-assets]]
- [[arquitectura-tres-capas-snowflake]]
