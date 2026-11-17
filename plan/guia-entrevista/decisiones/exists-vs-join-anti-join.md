---
tipo: decision
herramienta: sql
prioridad: media
aliases: [exists vs join, anti-join sql, not exists vs not in vs left join, cuando usar exists]
tags: [guia-entrevista, sql]
---
# `EXISTS` vs `JOIN`, y las tres formas de anti-join

> [!tip] Respuesta rápida
> `EXISTS` cuando solo necesitas filtrar por "¿hay coincidencia?", sin sacar columnas de la otra tabla — y, a diferencia de un `JOIN`, nunca duplica filas aunque haya varias coincidencias (inmune al fan-out). Para "¿NO hay coincidencia?" (*anti-join*), usa `NOT EXISTS` o `LEFT JOIN ... WHERE ... IS NULL` — **nunca `NOT IN`** si la subconsulta puede traer `NULL`s (ver [[sql-not-in-con-nulls]]).

## `EXISTS` vs `JOIN`: cuándo cada uno

| | `JOIN` | `EXISTS` |
|---|---|---|
| Necesitas columnas de la otra tabla | Sí | No — solo filtra |
| Varias coincidencias por fila | Duplica la fila (fan-out, ver [[fan-out-en-joins]]) | Nunca duplica — evalúa a verdadero/falso una vez |
| Qué comunica el código | "combino estos dos conjuntos" | "filtro por si existe algo" |

Si la pregunta es "¿esta reserva tiene algún tipo de cambio ese día?" y no necesitas el valor del tipo de cambio, `EXISTS` es más preciso que un `JOIN` — y evita tener que acordarte de poner `DISTINCT` o arriesgarte al fan-out si la tabla de la derecha tiene varias filas por clave.

## Las tres formas de *anti-join* ("filas de A que NO están en B")

| Forma | ¿Le afectan los `NULL` de B? | Recomendación |
|---|---|---|
| `NOT EXISTS` | No | Preferida por defecto |
| `LEFT JOIN ... WHERE b.clave IS NULL` | No | Igual de válida, más intuitiva viniendo de `JOIN` |
| `NOT IN (subconsulta)` | **Sí** — un solo `NULL` en la subconsulta hace que devuelva 0 filas siempre | Evitar contra columnas *nullable* |

El mecanismo del fallo de `NOT IN` está desarrollado en detalle en [[sql-not-in-con-nulls]] — aquí solo la comparación de cuándo elegir cada forma.

## Ejemplo mínimo (travel-dwh-lab, D4-02)

Reservas cuyo `market_segment` no está en una lista de control (con un `NULL` dentro a propósito):
```sql
-- LEFT JOIN + IS NULL y NOT EXISTS: ambas dan 106.547 filas
select a.*
from stg_hotel_bookings__bookings a
left join market_segment_control b on a.market_segment = b.market_segment
where b.market_segment is null;

-- NOT IN con la misma lista (que incluye un NULL): 0 filas, el bug
select *
from stg_hotel_bookings__bookings a
where a.market_segment not in (select market_segment from market_segment_control);
```

## Pregunta probable
**¿Por qué `EXISTS` no sufre el problema del fan-out que sí tiene un `JOIN`?** Porque `EXISTS` se evalúa como una condición booleana por cada fila de la izquierda — le da igual si hay 1 o 100 coincidencias en la subconsulta, la fila de fuera se devuelve como mucho una vez. Un `JOIN` en cambio produce una fila de salida **por cada combinación** de coincidencia, así que con varias coincidencias por clave, duplica.

## Aparece en
- Relacionados: [[sql-not-in-con-nulls]], [[fan-out-en-joins]], [[sql-joins-que-multiplican-filas]]
