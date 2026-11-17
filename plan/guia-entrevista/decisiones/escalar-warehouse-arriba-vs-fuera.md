---
tipo: decision
herramienta: snowflake
prioridad: alta
aliases: [scale up vs scale out, escalar warehouse, warehouse grande vs multi-cluster, vertical vs horizontal scaling snowflake]
tags: [guia-entrevista, snowflake]
---
# Escalar un warehouse: hacia arriba (tamaño) vs hacia fuera (multi-cluster)

> [!tip] Respuesta rápida
> Escalo **hacia arriba** (más tamaño) cuando una sola consulta pesada va lenta; escalo **hacia fuera** (multi-cluster) cuando muchas consultas concurrentes se encolan aunque cada una sea rápida.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| Hacia arriba (XS→S→M…) | Más memoria/CPU por consulta, reduce *spilling* a disco, acelera una query individual | No ayuda si el problema es volumen de usuarios concurrentes, coste por crédito se duplica por talla | Una consulta o un batch concreto tarda mucho, con *spilling* visible en el Query Profile |
| Hacia fuera (multi-cluster) | Añade clústeres idénticos para repartir consultas concurrentes, escala automática entre mín/máx | No acelera una consulta individual, cada clúster activo cuesta créditos | Muchos usuarios/BI lanzando queries a la vez y `queued_overload_time` sube en `QUERY_HISTORY` |

## En travel-dwh-lab
Los tres warehouses del `setup.sql` (`loading_wh`, `transforming_wh`, `dev_wh`) son de un solo clúster en XS: con el volumen actual (~119k reservas, carga diaria del BCE) no hace falta ni escalar arriba ni multi-cluster. Si `dev_wh` empezara a encolar consultas de varios desarrolladores y CI a la vez, el primer paso sería multi-cluster (2-3 clústeres XS) antes que subir a S, porque el cuello de botella sería concurrencia, no tamaño de consulta individual.

## Respuesta modelo
Contexto: una consulta en un warehouse XS tarda 30s y en M tarda 8s — ¿cuál es más barato? Opciones: quedarme en XS (1 crédito/hora) o subir a M (4 créditos/hora). Elijo comparar crédito-segundo: XS = 30s × 1 = 30 unidades; M = 8s × 4 = 32 unidades, prácticamente igual, pero si hay *spilling* en XS el M puede ganar al evitar reintentos. El riesgo de escalar arriba por defecto es pagar 4x sin necesidad cuando el cuello de botella real es concurrencia, no tamaño de consulta; lo mitigo revisando primero el Query Profile (operador costoso, spilling) antes de tocar el tamaño.

## Conceptos relacionados
- [[query-profile-metricas-y-diagnostico]]
- [[multi-cluster-warehouses]]
- [[micro-particiones-y-clustering-keys]]
- [[caches-de-snowflake]]
- [[snowflake-query-lenta]]
