---
tipo: concepto
herramienta: snowflake
aliases: [arquitectura snowflake, three-layer architecture, storage compute cloud services, capas de snowflake, snowflake architecture]
tags: [guia-entrevista, snowflake]
---
# Arquitectura de tres capas de Snowflake

> [!tip] Respuesta rápida
> Snowflake separa **almacenamiento**, **cómputo** (warehouses) y **servicios en la nube** (metadata, optimizador, RBAC). Cada capa escala y se paga por separado, así que varios equipos leen los mismos datos sin pelearse por recursos: cada uno usa su propio warehouse.

## Definición

Snowflake usa una arquitectura **multi-clúster de datos compartidos** (*shared-data architecture*) con tres capas independientes, cada una escalable y facturable por separado:

1. **Almacenamiento**: los datos se reorganizan automáticamente en formato columnar comprimido, divididos en [[micro-particiones-y-clustering-keys|micro-particiones]], sobre el object storage del cloud provider (S3, Blob, GCS). No hay índices ni llaves de distribución que definir a mano.
2. **Cómputo**: los *virtual warehouses* son clústeres de máquinas virtuales, totalmente aislados entre sí — un `dbt build` pesado en un warehouse no ralentiza a un analista de BI en otro. Se escalan hacia arriba (más potencia) o hacia fuera (multi-cluster, más concurrencia) en segundos.
3. **Cloud Services**: la capa "cerebro", siempre encendida — autenticación, RBAC, optimización de queries, metadatos de micro-partición y transacciones ACID. No se paga por separado salvo que el consumo de metadata supere la asignación gratuita.

### Qué pasa al lanzar un `SELECT`
1. **Cloud Services** parsea la query, comprueba permisos (RBAC) y mira si el resultado ya está en caché.
2. Si no hay caché, delega en el **warehouse** activo, que ejecuta la query.
3. El warehouse lee de **almacenamiento** solo las micro-particiones necesarias (poda, ver [[micro-particiones-y-clustering-keys]]).
4. El resultado se guarda en caché — ver el detalle de las tres cachés distintas en [[caches-de-snowflake]].

## Ejemplo mínimo
```sql
-- cada rol usa su propio warehouse: no compiten por cómputo
use role loader; use warehouse loading_wh;            -- ingesta
use role transformer; use warehouse transforming_wh;  -- dbt prod
use role developer; use warehouse dev_wh;             -- dbt dev / CI
```
(de `setup.sql` en travel-dwh-lab)

## Errores típicos
- Pensar que pagar más cómputo implica pagar más almacenamiento: son independientes.
- Olvidar que cloud services también tiene coste, aunque pequeño, en operaciones de metadata muy pesadas.

## Pregunta probable
**¿Cómo pueden dos equipos consultar las mismas tablas a la vez sin competir por recursos?** Cada uno usa su propio warehouse (su propia capa de cómputo); ambos leen del mismo almacenamiento compartido sin bloquearse.

## Aparece en
- [[snowflake-vs-bigquery]]
- Relacionados: [[micro-particiones-y-clustering-keys]], [[caches-de-snowflake]]
