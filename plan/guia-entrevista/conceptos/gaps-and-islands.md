---
tipo: concepto
herramienta: sql
aliases: [gaps and islands, rachas consecutivas, islas de fechas, consecutive streak sql, sesionizacion]
tags: [guia-entrevista, sql]
---
# Gaps & islands

> [!tip] Respuesta rápida
> Para encontrar **rachas de días consecutivos**, restas un `ROW_NUMBER()` (ordenado por fecha) a la fecha misma: dentro de una racha esa diferencia es constante. Agrupando por esa diferencia obtienes cada "isla".

## Definición

"Gaps and islands" es el nombre clásico de un patrón SQL para agrupar filas consecutivas (una "isla") separadas por huecos ("gaps") en alguna secuencia ordenada — fechas, IDs, timestamps de eventos. Hay dos técnicas equivalentes para construir el identificador de grupo:

1. **`LAG` + bandera + suma acumulada**: comparas cada fila con la anterior para poner una bandera de "aquí empieza algo nuevo", y usas una suma acumulada de esa bandera como identificador de grupo. Generaliza a cualquier definición de "hueco" (un umbral de minutos para sesiones, un hueco de más de un valor en IDs, etc.), porque la condición de la bandera puede ser lo que quieras.
2. **Resta de un `ROW_NUMBER()`** (ver método alternativo más abajo): solo vale cuando el "hueco" se mide en pasos fijos de una secuencia regular (días consecutivos del calendario, enteros consecutivos) — pero en una sola pasada de función de ventana, sin necesitar una segunda para la suma acumulada.

El mismo patrón sirve para mucho más que fechas: detectar sesiones de usuario (hueco = más de N minutos sin actividad), rachas de valores iguales, o huecos en una secuencia de IDs que debería ser contigua.

## Ejemplo mínimo (LAG + bandera + suma acumulada)
```sql
with dated as (
    select distinct arrival_date
    from stg_hotel_bookings__bookings
),
flagged as (
    select arrival_date,
        -- bandera: 1 si hay hueco respecto al día anterior, 0 si es consecutivo
        iff(
            lag(arrival_date) over (order by arrival_date) = dateadd(day, -1, arrival_date),
            0, 1
        ) as starts_new_island
from dated
),
islands as (
    select arrival_date,
        -- suma acumulada de banderas: constante dentro de una racha
        sum(starts_new_island) over (order by arrival_date) as island_id
    from flagged
)
select island_id, min(arrival_date), max(arrival_date), count(*) as dias
from islands
group by island_id
```
`LAG` detecta si el día anterior no es consecutivo (`starts_new_island = 1`); la suma acumulada de esa bandera da un identificador constante por racha.

## Método alternativo: `fecha − ROW_NUMBER()`

Cuando el hueco se mide en días de calendario (o cualquier entero con paso fijo de 1), no hace falta `LAG` ni una suma acumulada: basta con restar un `ROW_NUMBER()` ordenado por fecha a la fecha misma. El `ROW_NUMBER` avanza siempre +1 en la fila siguiente, por definición; la fecha solo avanza +1 si no hay hueco. Mientras ambos avancen al mismo ritmo, la resta se mantiene constante — es la clave de agrupación. En cuanto hay un hueco, la fecha salta más que el `ROW_NUMBER` y la resta cambia de valor.

Ejemplo (racha más larga de días con al menos N llegadas, por hotel — `travel-dwh-lab`, D3-04):
```sql
with llegadas as (
    select hotel_type, arrival_date, count(*) as n_arrivals
    from stg_hotel_bookings__bookings
    group by hotel_type, arrival_date
    having n_arrivals >= 100
),
con_isla as (
    select
        hotel_type, arrival_date,
        arrival_date - row_number() over (
            partition by hotel_type order by arrival_date
        ) as isla
    from llegadas
),
rachas as (
    select hotel_type, isla, count(*) as racha_dias,
        min(arrival_date) as racha_inicio, max(arrival_date) as racha_fin
    from con_isla
    group by hotel_type, isla
)
select hotel_type, racha_dias, racha_inicio, racha_fin
from rachas
qualify row_number() over (partition by hotel_type order by racha_dias desc) = 1
```
Ventaja frente a `LAG`: una sola función de ventana en vez de dos pasadas (bandera + suma acumulada). Desventaja: solo funciona si el filtro de calificación (`having n_arrivals >= 100`) se aplica **antes** de calcular el `ROW_NUMBER` — si se cuela una fila que no califica, deja de ser una secuencia de enteros consecutivos sin huecos reales y el truco se rompe. `LAG` no tiene esa restricción porque la condición de "hueco" se evalúa explícitamente fila a fila, no por aritmética de posición.

## Errores típicos
- Olvidar deduplicar fechas antes de calcular el `LAG`: con varias filas por día, la comparación con "ayer" deja de ser fiable.
- La primera fila: `LAG` devuelve `NULL`, y `NULL = fecha` es `NULL`, no `true` — hace falta que el `IFF`/`CASE` trate ese `NULL` como "empieza isla" (arranca la bandera en 1).
- No decidir si los huecos de fin de semana cuentan como gap real o no, según el negocio.
- Con el método `fecha − ROW_NUMBER()`: interpretar el valor de la resta como una fecha con significado real (p. ej. "la racha empieza el día de ese valor"). Es solo una clave de agrupación — las fechas reales de inicio/fin se obtienen con `MIN`/`MAX` sobre cada grupo, no del valor de la resta.

## Pregunta probable
**¿Qué tiene en común con la sesionización?** Las dos usan `LAG` para detectar un cambio (hueco de fecha, o más de N minutos de inactividad) y una suma acumulada de esa bandera para agrupar filas consecutivas bajo un mismo identificador de racha o de sesión.

## Aparece en
- [[sql-joins-que-multiplican-filas]] (mismo marco de 5 pasos de SQL)
- Relacionados: [[funciones-de-ventana]], [[qualify]]
