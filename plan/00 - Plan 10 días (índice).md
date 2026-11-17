---
tipo: indice
tags: [plan-10-dias, entrevista-data-engineer]
aliases: [Plan 10 días, Índice plan]
---

# Plan de 10 días — preparación de entrevista técnica (Data Engineer)

Plan para repasar los temas que pidieron en la entrevista técnica: Snowflake (desde BigQuery), CI/CD con GitHub, SQL, dbt y Airflow. Cada día es una **épica** con tickets y su **Definition of Done**. Los diez días están confirmados.

La práctica se hace sobre el repo `travel-dwh-lab` (Snowflake + dbt + Airflow + GitHub Actions), con datos de Hotel Booking Demand y tipos de cambio del BCE. Airflow corre en tu propio entorno, por ejemplo local con docker compose.

## Días

| Día | Épica | Bloque | Estado |
|---|---|---|---|
| 1 | [[D01 - Snowflake - arquitectura y traducción desde BigQuery]] | Snowflake | Pendiente |
| 2 | [[D02 - Snowflake - operación, monitorización y decisiones]] | Snowflake | Pendiente |
| 3 | [[D03 - SQL I - marco de resolución de problemas]] | SQL | Pendiente |
| 4 | [[D04 - SQL II - rendimiento y depuración de consultas]] | SQL | Pendiente |
| 5 | [[D05 - dbt I - flujo de trabajo y decisiones de modelado]] | dbt | Pendiente |
| 6 | [[D06 - dbt II - dbt sobre Snowflake]] | dbt | Pendiente |
| 7 | [[D07 - CICD con GitHub Actions]] | CI/CD | Pendiente |
| 8 | [[D08 - Airflow I - diseño de DAGs y decisiones]] | Airflow | Pendiente |
| 9 | [[D09 - Airflow II - depurar DAGs que fallan]] | Airflow | Pendiente |
| 10 | [[D10 - Integración y simulacro de entrevista]] | Integración | Pendiente |

Cambia el **Estado** a *En curso* o *Done* a medida que avances.

## Dependencias entre días

Algunos tickets necesitan algo de un día anterior. Si te saltas uno, revisa esta lista:

- **D2-07 (histórico del BCE):** opcional el día 2, obligatorio para D4-01, D5-01 y todo lo que use `fct_bookings` o tipos de cambio.
- **D6 en la rama `feat/d6-dbt` sin fusionar:** es el PR que activa la CI en D7-02.
- **Producción construida una vez** (DAG `dbt_travel_dwh`): necesaria para el *slim CI* con `--defer` en D7.
- **D9:** se trabaja con copias `dags/lab_debug_*.py` sin versionar, nunca con los DAGs del repo.

## Cómo se usa

- **Tarea o práctica:** se cierra cuando todas las casillas de su DoD están marcadas.
- **Estudio:** se cierra cuando respondes las preguntas en voz alta, sin mirar notas.
- **Épica:** se cierra cuando todos sus tickets obligatorios están en *Done*. Los opcionales no bloquean.
- **Notas del día:** al final de cada nota; el día 10 las usa para el repaso de puntos débiles.

## Consejo transversal

En este tipo de entrevistas, «depende» solo puntúa si va seguido de **de qué depende** y de **una elección concreta**. Estructura para responder preguntas de decisión: *contexto → opciones → elijo X porque… → riesgo que asumo y cómo lo mitigo*.
