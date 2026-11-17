---
tipo: problema
herramienta: sql
prioridad: alta
aliases: [fan-out en joins, join duplica filas, row explosion, join multiplica resultados, cuenta mal tras un join]
tags: [guia-entrevista, sql]
---
# La consulta cuenta o suma más de la cuenta después de un join

> [!tip] Respuesta rápida
> Un **fan-out**: el lado derecho del join no es único para la clave esperada, así que cada fila izquierda se multiplica. Cuenta filas antes y después del join para confirmarlo.

## Hipótesis (de más barata a más cara de comprobar)
1. **La tabla derecha no es única para la clave del join** → `select count(*)` antes y después del join; si crece, hay fan-out.
2. **Falta un filtro que debería dejar la relación 1:1** → caso real: `int_exchange_rates__daily` tiene una fila por `(calendar_date, quote_currency)`. Si `fct_bookings` uniera sin filtrar divisa, cada reserva se triplicaría (GBP/USD/CHF). El modelo lo evita con `fx as (select * from int_exchange_rates__daily where quote_currency = '{{ var("reporting_currency") }}')` antes del `left join on bookings.booking_date = fx.rate_date`.
3. **Duplicados en la fuente** (recarga que no deduplicó) → revisar `qualify row_number()` en el staging.

## Diagnóstico paso a paso
```sql
-- 1. Filas antes del join
select count(*) from stg_hotel_bookings__bookings;

-- 2. Filas después del join
select count(*) from fct_bookings;

-- 3. Busca la clave no-única en el lado derecho
select quote_currency, rate_date, count(*)
from int_exchange_rates__daily
group by 1, 2
having count(*) > 1;
```
Si (2) > (1), hay fan-out. Si (3) devuelve filas, la clave no es única.

## Solución
- **Filtrar antes de unir**: aplica el `where` que deja la relación 1:1 (como el filtro de `reporting_currency`).
- **Agregar antes de unir**: si necesitas varias filas del lado derecho, agrégalas a la granularidad de la izquierda con un CTE y `group by`.
- Nunca "arreglar" con `distinct` al final: oculta el problema sin corregirlo.

## Prevención
- Test genérico de dbt `unique` (o `unique_combination_of_columns`) sobre la clave de join en el modelo de origen.
- Documentar la granularidad esperada de cada modelo en el `.yml`.
- Code review: cualquier `left join` sobre una tabla con grano distinto al principal es sospechoso por defecto.

## Cómo contarlo
En el proyecto, `fct_bookings` une reservas con tipos de cambio diarios por divisa; sin filtrar `reporting_currency`, cada reserva se triplicaría. Lo detecté comparando `count(*)` antes/después del join y viendo duplicados por `(rate_date, quote_currency)`. La solución fue filtrar el CTE `fx` a una sola divisa antes de unir, dejando la relación 1:1. Lo prevengo con un test `unique` sobre la clave de join.

## Conceptos relacionados
- [[fan-out-en-joins]]
- [[qualify]]
- [[test-generico-vs-singular]]
