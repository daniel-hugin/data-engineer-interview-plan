---
tipo: problema
herramienta: sql
prioridad: alta
aliases: [NOT IN devuelve vacío, NOT IN con NULL, not in no funciona, NOT IN returns no rows, subconsulta con nulls]
tags: [guia-entrevista, sql]
---
# NOT IN me devuelve 0 filas y no entiendo por qué

> [!tip] Respuesta rápida
> Si la subconsulta de `NOT IN` tiene **un solo NULL**, toda la comparación se vuelve `UNKNOWN` y la fila se descarta, aunque el valor no esté en la lista. Usa `NOT EXISTS` o un `LEFT JOIN ... WHERE IS NULL`.

## Hipótesis (de más barata a más cara de comprobar)
1. **Hay un NULL en la columna de la subconsulta** → es la causa casi siempre que `NOT IN` da menos filas de las esperadas.

## Diagnóstico paso a paso
```sql
-- ¿hay NULLs en la columna que alimenta el NOT IN?
select count(*)
from subconsulta
where columna is null;
```
Si el conteo es mayor que 0, ahí está el problema: SQL evalúa `valor NOT IN (a, b, NULL)` como `valor <> a AND valor <> b AND valor <> NULL`, y `valor <> NULL` es `UNKNOWN`. Un `AND` con `UNKNOWN` nunca da `TRUE`, así que la fila nunca pasa el filtro.

## Solución
Tres formas equivalentes de resolverlo, evitando el problema del NULL:

```sql
-- 1. NOT EXISTS (recomendado: no le afectan los NULLs)
select *
from tabla_a a
where not exists (
  select 1 from tabla_b b where b.clave = a.clave
);

-- 2. LEFT JOIN + IS NULL
select a.*
from tabla_a a
left join tabla_b b on b.clave = a.clave
where b.clave is null;

-- 3. NOT IN pero limpiando los NULLs explícitamente (menos robusto, evitar)
select *
from tabla_a
where clave not in (select clave from tabla_b where clave is not null);
```

## Prevención
- Evitar `NOT IN` contra columnas *nullable* como regla general; usar `NOT EXISTS` por defecto.
- Si el linter o el style guide del equipo lo permite, prohibir `NOT IN` con subconsultas en revisiones de código.
- Añadir un test que falle si la columna de la subconsulta tiene NULLs inesperados.

## Cómo contarlo
Me encontré una consulta con `NOT IN` que devolvía cero filas cuando debía devolver varias. La hipótesis fue un NULL en la subconsulta, y lo comprobé con `count(*) where columna is null`, que confirmó el caso. La solución fue reescribirlo con `NOT EXISTS`, que no se ve afectado por NULLs. Para prevenirlo, evito `NOT IN` contra columnas nullable y prefiero `NOT EXISTS` o `LEFT JOIN` por defecto.

## Conceptos relacionados
- [[sql-joins-que-multiplican-filas]]
- [[qualify]]
- [[sql-y-snowflake]]
