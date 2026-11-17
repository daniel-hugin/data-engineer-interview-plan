---
tipo: concepto
herramienta: sql
aliases: [fan-out, join que multiplica filas, duplicated rows join, row explosion, join fan-out]
tags: [guia-entrevista, sql]
---
# Fan-out en un join

> [!tip] Respuesta rápida
> Un join "explota" cuando el lado al que te unes tiene **más de una fila por clave** de la esperada. No da error: produce filas de más que inflan sumas y conteos en silencio.

## Definición

Todo join tiene una **cardinalidad** implícita entre las dos tablas: 1:1, 1:N o N:M según cuántas filas del lado derecho pueden coincidir con cada fila del lado izquierdo. El fan-out ocurre cuando asumes 1:1 (o 1:N controlado) pero la relación real es 1:N sin que lo esperaras — el motor no lo detecta como error porque sintácticamente el join es válido, simplemente genera una fila por cada coincidencia. El resultado tiene más filas que la tabla izquierda original, y cualquier `SUM`/`COUNT` posterior sobre esas filas queda inflado en la misma proporción.

No es lo mismo que un producto cartesiano puro (que vendría de un join sin ninguna condición `ON`): aquí la condición existe y es parcialmente correcta, solo le falta alguna columna que acote la relación a 1:1 — como la divisa en el ejemplo de abajo. La función de ventana [[qualify|QUALIFY]] es una forma de detectar y cortar el fan-out en la propia query (quedarte solo con la fila "buena" por grupo); las [[funciones-de-ventana|funciones de ventana]] en general son la herramienta para razonar sobre "cuántas filas por clave" antes de que se conviertan en un bug silencioso.

**Fan-out no es sinónimo de "duplicados"** — es una causa concreta de duplicación (cardinalidad 1:N inesperada en un `JOIN`), pero hay otras causas de filas duplicadas que no tienen nada que ver con un join: filas repetidas ya en el origen (un fallo de carga insertó la misma fila dos veces — por eso [[idempotencia-y-atomicidad|idempotencia]] en la carga importa), un `UNION` sin `DISTINCT` donde dos fuentes solapan, un `GROUP BY` al que le falta una columna de la clave real (mezcla grupos que debían ir separados), o un `CROSS JOIN` accidental (producto cartesiano completo, no un join con condición parcialmente correcta). Y a la inversa: el fan-out tampoco es siempre un error — a veces es la intención (reservas → noches, una fila por noche a propósito); el problema aparece solo cuando asumes 1:1 y el join resulta ser 1:N sin que lo esperaras.

## Ejemplo mínimo
```sql
-- MAL: una reserva se une a 3 filas de fx (GBP, USD, CHF) → el ingreso se triplica
select b.booking_id, b.adr_eur * fx.rate as revenue
from bookings b
left join int_exchange_rates__daily fx
    on b.booking_date = fx.rate_date;   -- falta filtrar la divisa

-- BIEN (como hace fct_bookings.sql):
left join int_exchange_rates__daily fx
    on b.booking_date = fx.rate_date
where fx.quote_currency = '{{ var("reporting_currency") }}'
```

Otro caso real (pregunta de entrevista): `historial_reservas` tiene varias filas por `id_reserva` (una por cambio de estado/importe). Unir `reservas` directamente a `historial_reservas` sin deduplicar antes multiplicaría cada reserva por su número de cambios históricos:
```sql
-- MAL: cada reserva se multiplica por el número de cambios que ha tenido
select r.id_cliente, h.estado, h.importe
from reservas r
join historial_reservas h on r.id_reserva = h.id_reserva;

-- BIEN: deduplicar al estado actual ANTES de unir
with estado_actual as (
    select id_reserva, estado, importe
    from historial_reservas
    qualify row_number() over (partition by id_reserva order by fecha_cambio desc) = 1
)
select r.id_cliente, e.estado, e.importe
from reservas r
join estado_actual e on r.id_reserva = e.id_reserva;
```

## Errores típicos
- Unir por fecha sin fijar también la divisa, el canal o cualquier otra columna que repita la fila padre N veces.
- Validar solo el `count(*)` final sin comparar con el conteo de la tabla izquierda antes del join.
- No distinguir `COUNT(*)` (cuenta NULLs) de `COUNT(columna)` (no los cuenta) al verificar.

## Pregunta probable
**¿Cómo lo detectas antes de que te infle una suma?** Cuentas filas de la tabla izquierda antes del join y las comparas con el resultado después: si crecen, hay fan-out; revisas la cardinalidad de la clave del lado derecho.

## Aparece en
- [[sql-joins-que-multiplican-filas]]
- Relacionados: [[qualify]], [[funciones-de-ventana]]
