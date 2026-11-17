---
tipo: concepto
herramienta: snowflake
aliases: [micro-particiones, micro-partitions, pruning, clustering keys, partitioning snowflake]
tags: [guia-entrevista, snowflake]
---
# Micro-particiones y clustering keys

> [!tip] Respuesta rápida
> Snowflake parte cada tabla sola en micro-particiones de **50-500MB sin comprimir** (~16MB comprimidas) con metadata de min/max por columna. El optimizador descarta particiones que no pueden contener filas del filtro: eso es el ***pruning***. No eliges partición como en BigQuery; como mucho defines una *clustering key* para ordenar físicamente los datos.

## Definición

Snowflake divide automáticamente cada tabla en micro-particiones de 50-500MB sin comprimir (~16MB comprimidas), por defecto **según el orden en que se insertaron los datos** — no eliges columna de partición como en BigQuery. Para cada micro-partición, Cloud Services guarda metadatos ligeros: valor mínimo y máximo de cada columna, conteos, nulos. Esos metadatos son la base del *pruning*: antes de leer nada, el optimizador descarta las particiones cuyo rango min/max no puede contener filas que cumplan el filtro, sin tocar el storage real (ver [[arquitectura-tres-capas-snowflake]] para dónde encaja esto en el ciclo de un `SELECT`, y [[caches-de-snowflake]] para la caché de metadatos que lo sostiene).

El pruning solo funciona si la columna del filtro está correlacionada con el orden físico de los datos. Si filtras por una columna sin relación con ese orden (un ID aleatorio, por ejemplo), cada micro-partición contiene casi todo el rango de valores posible y no se puede descartar ninguna. La solución es una **clustering key**: declararla le dice a Snowflake que mantenga los datos reordenados físicamente según esa columna, mediante un proceso de fondo (*automatic reclustering*) que consume créditos. Por eso solo tiene sentido en tablas grandes con un patrón de filtro estable y conocido — en una tabla pequeña, el coste de mantener el reclustering no compensa ningún ahorro real en el escaneo.

## Cómo medir la clusterización: `SYSTEM$CLUSTERING_INFORMATION`

Antes de asumir que un filtro va a podar algo, se puede comprobar si la columna está realmente bien clusterizada:
```sql
select system$clustering_information('mi_tabla', '(mi_columna)');
```
Devuelve, entre otros campos, `average_depth` y `average_overlaps`. Pensar en cada micro-partición como una "caja" que guarda el rango mín-máx de esa columna:

- **`average_overlaps`**: de media, ¿con cuántas *otras* particiones se solapa el rango de una partición? Cerca de 0 = rangos bien separados (buena clusterización). Cerca del total de particiones = casi todas se solapan con casi todas (mala clusterización).
- **`average_depth`**: si eliges un valor cualquiera de la columna, ¿en cuántas particiones aparece? Cerca de 1 = ese valor vive en una sola partición (el filtro solo necesita leer esa). Cerca del total de particiones = ese valor está repartido por casi todas (no hay nada que podar, filtres como filtres).

**Caso real comprobado en `travel-dwh-lab`** (D4-03): `SNOWFLAKE_SAMPLE_DATA.TPCH_SF10.LINEITEM` sobre `l_shipdate` dio `average_depth: 116` y `average_overlaps: 115` sobre `116` particiones totales — el peor caso posible. Ninguna de las dos versiones de la consulta (filtro limpio vs. filtro con función) podía podar nada, porque no era un problema de cómo se escribió el filtro: la tabla simplemente no está clusterizada por `l_shipdate` (se cargó en un orden — probablemente por `l_orderkey` — sin relación con esa columna, y `l_shipdate = l_orderdate + desfase aleatorio` destruye cualquier correlación). Lección: comprobar la clusterización real **antes** de diagnosticar el filtro, o se puede confundir "mal escrito" con "no hay nada que podar aquí".

## Ejemplo mínimo
```sql
-- filtrar sobre la columna "limpia" ayuda al pruning
select * from snowflake_sample_data.tpch_sf10.lineitem
where l_shipdate >= '1998-01-01' and l_shipdate < '1998-02-01';

-- envolver la columna en una función rompe el pruning
select * from snowflake_sample_data.tpch_sf10.lineitem
where to_varchar(l_shipdate, 'YYYY-MM') = '1998-01';
```

## Errores típicos
- Filtrar con una función sobre la columna de fecha (`to_varchar`, conversiones) en vez de con un rango literal: Snowflake no puede usar el min/max de la partición.
- Pensar que hace falta declarar partición como en BigQuery: aquí es automático; la clustering key es opcional, solo para tablas muy grandes con patrones de filtro estables.
- Poner clustering key en una tabla pequeña: coste de reclustering sin beneficio real.
- Asumir que un filtro "limpio" va a podar sin comprobar antes si la columna está realmente clusterizada (`SYSTEM$CLUSTERING_INFORMATION`) — si no lo está, ningún filtro va a podar nada, y el problema no está en cómo se escribió la consulta.

## Pregunta probable
**¿En qué se diferencian de BigQuery?** BigQuery exige declarar partición y cluster; Snowflake las genera sola por orden de carga, y el *pruning* depende de que el filtro sea "sargable" sobre esas columnas.

## Aparece en
- [[snowflake-query-lenta]]
- Relacionados: [[arquitectura-tres-capas-snowflake]], [[caches-de-snowflake]]
