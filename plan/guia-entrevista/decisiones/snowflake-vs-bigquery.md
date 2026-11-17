---
tipo: decision
herramienta: snowflake
prioridad: alta
aliases: [snowflake vs bigquery, bigquery vs snowflake, migracion bigquery a snowflake, bigquery to snowflake migration]
tags: [guia-entrevista, snowflake]
---
# Snowflake vs BigQuery

> [!tip] Respuesta rápida
> Elijo Snowflake cuando quiero aislar cargas de trabajo con warehouses independientes y control fino de coste/concurrencia; BigQuery cuando quiero cero gestión de infraestructura y ya vivo en el ecosistema GCP.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| Snowflake | Compute/storage separados, warehouses independientes por carga, RBAC jerárquico, multi-cloud | Hay que dimensionar y gestionar warehouses, coste por segundo de cómputo activo | Varios equipos/cargas que no deben competir por recursos; necesitas multi-cloud |
| BigQuery | Serverless, sin warehouses que gestionar, slots on-demand o reservados, fuerte integración GCP | Menos control fino de aislamiento entre cargas, modelo de coste (bytes escaneados) puede sorprender | Equipo pequeño, ya en GCP, cargas analíticas ad-hoc variables |

## En travel-dwh-lab
Tres warehouses XS de un solo clúster (`loading_wh`, `transforming_wh`, `dev_wh`) separan ingesta Airflow, transformaciones dbt en prod y dbt dev/CI, cada uno con `auto_suspend = 60` y bajo el resource monitor `lab_monthly_monitor` (20 créditos/mes). Es el equivalente a reservar slots dedicados por carga en BigQuery: en vez de competir por un pool compartido, cada proceso tiene su propio "carril" y se paga solo mientras está activo.

## Respuesta modelo
Venimos de BigQuery y migramos a Snowflake. Lo que me preocuparía primero no es la sintaxis SQL (es muy similar) sino el modelo de coste y aislamiento: en BigQuery el cómputo es serverless y compartido vía slots; en Snowflake cada carga necesita su propio warehouse bien dimensionado o paga de más o compite por recursos. Opciones: un warehouse único para todo (simple pero sin aislamiento) o varios warehouses por función (ingesta, transformación, BI). Elijo varios warehouses pequeños porque en nuestro proyecto separamos Airflow, dbt prod y dbt dev/CI con XS y auto-suspend agresivo, evitando que una carga pesada bloquee a otra. El riesgo es la proliferación de warehouses y el olvido de auto-suspend disparando coste; lo mitigamos con un resource monitor que notifica al 75% y suspende al 100-110%.

## Conceptos relacionados
- [[arquitectura-tres-capas-snowflake]]
- [[caches-de-snowflake]]
