---
tipo: concepto
herramienta: snowflake
aliases: [cache de resultados, result cache, metadata cache, warehouse cache, local disk cache, cachés snowflake]
tags: [guia-entrevista, snowflake]
---
# Las tres cachés de Snowflake

> [!tip] Respuesta rápida
> Tres cachés: **metadata** (cloud services, min/max y conteos por partición), **resultados** (24h, misma query + mismo rol + datos sin cambios) y **disco local del warehouse** (SSD, se pierde al suspender).

## Definición

Snowflake separa el caché en tres capas independientes, cada una con su propio dueño, duración y lo que la invalida:

1. **Caché de metadatos** — vive en Cloud Services, siempre disponible, no depende de ningún warehouse. Para cada micro-partición guarda min/max por columna, conteos y nulos; es la base de la poda (*pruning*) que vimos en [[arquitectura-tres-capas-snowflake]] y [[micro-particiones-y-clustering-keys]]. Se actualiza automáticamente con cada escritura, nunca "se pierde" ni hay que gestionarla.
2. **Caché de resultados** — también en Cloud Services, dura hasta 24h. Snowflake la reutiliza si la query es textualmente idéntica (mismo hash de la query compilada) y los datos subyacentes no han cambiado desde la última ejecución. No requiere ningún warehouse activo para servirse — por eso una query repetida puede resolverse con el warehouse suspendido. Se desactiva por sesión con `alter session set use_cached_result = false`.
3. **Caché de disco local** — vive en el SSD de cada warehouse, es la que guarda las micro-particiones *crudas* ya leídas de storage remoto (no resultados de query). Es propia de cada warehouse (dos warehouses no la comparten) y se pierde por completo al suspenderse, porque los nodos de cómputo se apagan. Afecta directamente a la decisión de `AUTO_SUSPEND`: ver [[escalar-warehouse-arriba-vs-fuera]].

La confusión más habitual es tratar la caché de resultados y la de disco local como si fueran la misma cosa: la primera es a nivel de cuenta y sobrevive a la suspensión del warehouse; la segunda es por warehouse y no sobrevive.

## Ejemplo mínimo
```sql
-- repetir la misma query: la resuelve la caché de resultados (coste ~0)
select count(*) from raw.hotel_bookings.bookings;

-- desactivarla para forzar re-ejecución real
alter session set use_cached_result = false;
```

## Errores típicos
- Pensar que `AUTO_SUSPEND` bajo no afecta al rendimiento: suspende el warehouse y pierde la caché local de disco, así que el siguiente arranque va "en frío".
- Confundir la caché de resultados (24h, a nivel de cuenta) con la caché local (por warehouse, se pierde al suspender).
- Creer que cambiar una fila de la tabla no invalida la caché de resultados: sí la invalida.

## Pregunta probable
**¿Qué pierdes si pones `AUTO_SUSPEND` muy bajo?** La caché local de disco del warehouse; la siguiente query reconstruye ese caché leyendo de almacenamiento remoto, más lenta pero más barata en créditos ociosos.

## Aparece en
- [[snowflake-query-lenta]]
- Relacionados: [[arquitectura-tres-capas-snowflake]], [[escalar-warehouse-arriba-vs-fuera]]
