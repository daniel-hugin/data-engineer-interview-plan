---
tipo: concepto
herramienta: sql
aliases: [qualify snowflake, deduplicar con qualify, top n por grupo, row_number qualify, qualify clause]
tags: [guia-entrevista, sql]
---
# QUALIFY

> [!tip] Respuesta rápida
> `QUALIFY` filtra sobre el resultado de una función de ventana sin necesitar una subconsulta o CTE extra. Es el atajo de Snowflake (y BigQuery) para deduplicar o sacar el top-N por grupo en una sola pasada.

## Definición

En el orden lógico de ejecución de SQL, `WHERE` se evalúa antes de calcular cualquier [[funciones-de-ventana|función de ventana]] (por eso no puedes filtrar por `ROW_NUMBER()` en un `WHERE`), y `HAVING` filtra después de un `GROUP BY` pero tampoco ve el resultado de una ventana si no hay agregación. `QUALIFY` ocupa el hueco que falta: se evalúa **después** de calcular las funciones de ventana del `SELECT`, así que puede filtrar directamente por su resultado, sin envolver la query en un CTE/subconsulta solo para poder aplicar un `WHERE` sobre una columna calculada.

Es sintaxis de Snowflake y BigQuery (entre otros), no estándar ANSI — en motores que no lo soportan (Postgres, MySQL) hay que volver al patrón CTE + `WHERE rn = 1`, que hace exactamente lo mismo con una capa extra. El caso de uso más común es deduplicar (quedarte con 1 fila por clave según algún criterio de "más reciente/mejor") o sacar un top-N por grupo en una sola pasada, sin aplanar el resto de columnas con un `GROUP BY`.

## Ejemplo mínimo
```sql
-- dedup real en stg_ecb__exchange_rates.sql: si una recarga deja duplicados, gana la última
select *
from source
qualify row_number() over (
    partition by rate_date, currency
    order by loaded_at desc
) = 1
```

## Errores típicos
- Usar `QUALIFY` en un motor que no lo soporta (Postgres, MySQL): hace falta CTE + `WHERE row_number() = 1`.
- Olvidar el `ORDER BY` dentro de la ventana: sin él, "la más reciente" no está garantizada.
- Confundir `QUALIFY` (filtra tras calcular la ventana) con `WHERE` (filtra antes, no puede ver el resultado de la ventana).

## Pregunta probable
**¿Cómo lo harías sin QUALIFY?** Con un CTE que calcule `row_number()` y un `SELECT` externo con `WHERE rn = 1`: mismo resultado, una capa más.

## Aparece en
- [[sql-joins-que-multiplican-filas]]
- Relacionados: [[fan-out-en-joins]], [[funciones-de-ventana]]
