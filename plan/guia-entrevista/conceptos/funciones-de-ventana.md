---
tipo: concepto
herramienta: sql
aliases: [window functions, row_number rank dense_rank, rows between range between, funciones analiticas sql, ventanas sql]
tags: [guia-entrevista, sql]
---
# Funciones de ventana: ranking y framing

> [!tip] Respuesta rápida
> `ROW_NUMBER` siempre da números distintos; `RANK` deja huecos tras un empate; `DENSE_RANK` no deja huecos. `ROWS BETWEEN` opera por posición física; `RANGE BETWEEN` opera por valor lógico (filas con el mismo valor de orden cuentan juntas).

## Definición

Una función de ventana calcula un valor por fila **sin colapsar el resultado** en grupos, a diferencia de `GROUP BY`: cada fila conserva su identidad, pero el cálculo (`SUM`, `RANK`, `LAST_VALUE`...) se hace sobre una "ventana" de filas relacionadas, definida por `OVER (PARTITION BY ... ORDER BY ... <frame>)`. `PARTITION BY` es el equivalente al `GROUP BY` de un agregado normal (delimita el grupo), `ORDER BY` define el orden dentro de la partición (necesario para rankings y acumulados), y la cláusula de *frame* (`ROWS`/`RANGE BETWEEN`) acota qué filas de la partición entran en el cálculo para la fila actual.

Hay tres familias: funciones de **ranking** (`ROW_NUMBER`, `RANK`, `DENSE_RANK` — difieren en cómo tratan los empates), funciones de **valor** (`LAG`, `LEAD`, `FIRST_VALUE`, `LAST_VALUE` — miran otra fila de la partición) y funciones **agregadas** usadas como ventana (`SUM`, `AVG`... con `OVER`, dan un acumulado o total por partición sin perder el detalle de fila). El patrón [[gaps-and-islands]] combina `LAG` (valor) con una suma acumulada (agregada); [[qualify|QUALIFY]] es el mecanismo para filtrar sobre el resultado de cualquiera de estas sin un CTE aparte.

## Ejemplo mínimo
```sql
-- forward fill real en int_exchange_rates__daily.sql: rellena fines de semana
-- con el último tipo publicado, por divisa, fila a fila hasta la actual
last_value(rates.rate) ignore nulls over (
    partition by spine.quote_currency
    order by spine.calendar_date
    rows between unbounded preceding and current row
) as rate
```
`ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW` = "desde el principio de la partición hasta esta fila, por posición física". `IGNORE NULLS` hace que `LAST_VALUE` salte huecos y arrastre el último valor real.

Empate `[10, 10, 8]` → `ROW_NUMBER`: 1,2,3 · `RANK`: 1,1,3 · `DENSE_RANK`: 1,1,2.

## Errores típicos
- Esperar comportamiento de `ROWS` al usar `RANGE` cuando hay valores repetidos en la columna de orden: el acumulado "salta" de golpe para todas las filas iguales.
- Olvidar `PARTITION BY` y acumular sobre toda la tabla en vez de por grupo.
- Usar `RANK` para un "top 3 por grupo" con empates: puede devolver más de 3 filas.

## Pregunta probable
**¿Qué cambia entre ROWS y RANGE en un acumulado?** `ROWS` cuenta filas físicas; `RANGE` agrupa por el valor de la columna de orden, así que con duplicados el acumulado salta en vez de ir fila a fila.

## Aparece en
- [[sql-joins-que-multiplican-filas]]
- Relacionados: [[qualify]], [[gaps-and-islands]]
