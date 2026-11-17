---
tipo: concepto
herramienta: snowflake
aliases: [time travel, fail-safe, zero-copy cloning, clonado snowflake, recuperación de datos]
tags: [guia-entrevista, snowflake]
---
# Time Travel, Fail-safe y zero-copy cloning

> [!tip] Respuesta rápida
> **Time Travel**: consultar/restaurar datos como estaban hasta N días atrás, ventana que tú configuras. **Fail-safe**: 7 días más, solo accesibles por soporte de Snowflake, para desastres. **Zero-copy cloning**: copia una tabla/esquema/BD sin duplicar almacenamiento (copy-on-write).

## Definición

Las tres funcionalidades dependen de lo mismo: las [[micro-particiones-y-clustering-keys|micro-particiones]] de Snowflake son **inmutables** — un `UPDATE`/`DELETE` nunca modifica una partición existente, escribe particiones nuevas y cambia qué conjunto de particiones es "la versión activa" de la tabla (un intercambio de puntero de metadatos, atómico e instantáneo). Las particiones viejas no desaparecen al momento; se quedan disponibles mientras dura su ventana de retención.

**Time Travel** es esa ventana, configurable por ti (`DATA_RETENTION_TIME_IN_DAYS`, hasta 90 días en Enterprise+, 1 día por defecto en Standard): mientras dura, puedes consultar o restaurar cualquier versión anterior con SQL normal (`AT`/`BEFORE`, `UNDROP TABLE`) — es autoservicio, no necesitas a nadie de soporte. **Fail-safe** es una ventana fija adicional de 7 días que arranca justo cuando se acaba el Time Travel: ya no es autoservicio, solo Snowflake Support puede recuperar esos datos, pensado como red de última instancia para desastres (no para "borré una tabla por error", eso debe cubrirlo Time Travel). Ambas ventanas siguen consumiendo almacenamiento facturable aunque la tabla "activa" ya no muestre esos datos.

**Zero-copy cloning** usa la misma inmutabilidad en la otra dirección: `CREATE ... CLONE` crea un objeto nuevo que apunta a las mismas micro-particiones del original, sin copiar ni un byte — también una operación de metadatos, instantánea sin importar el tamaño. El clon es escribible desde el primer momento; al modificarlo se escriben particiones nuevas solo para lo que cambia, el original no se toca, y el storage extra que empiezas a pagar es únicamente el de la divergencia. A diferencia de un table snapshot de BigQuery (fundamentalmente de solo lectura), el clon de Snowflake es una tabla normal desde el minuto uno, y se puede aplicar a una base de datos o esquema entero en un solo comando.

## Ejemplo mínimo
```sql
-- Time Travel: consultar cómo estaba hace 1 hora, o antes de un instante dado
select * from raw.hotel_bookings.bookings at(offset => -3600);
select * from raw.hotel_bookings.bookings before(statement => '<query_id>');

-- recuperar una tabla borrada por error, dentro de la ventana de Time Travel
undrop table raw.hotel_bookings.bookings;

-- Zero-copy clone para probar sin coste de almacenamiento
create database analytics_dev_clone clone analytics;
```

## Errores típicos
- Pensar que Fail-safe es recuperable por el usuario: no lo es, solo por soporte de Snowflake.
- Olvidar que las tablas `transient`/`temporary` tienen Fail-safe reducido o nulo: es el *trade-off* de coste frente a recuperación.
- Creer que un clon zero-copy consume el mismo espacio que el original: solo consume cuando diverge (nuevas micro-particiones).

## Pregunta probable
**¿Qué añade Fail-safe sobre Time Travel?** Una ventana fija de 7 días no configurable, tras agotar Time Travel, solo para recuperación de desastres por Snowflake, no autoservicio.

## Aparece en
- [[snowflake-vs-bigquery]]
- Relacionados: [[arquitectura-tres-capas-snowflake]], [[micro-particiones-y-clustering-keys]]
