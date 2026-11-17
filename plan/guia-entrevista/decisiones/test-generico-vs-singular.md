---
tipo: decision
herramienta: dbt
prioridad: media
aliases: [generic vs singular test, test genericos dbt, test singular dbt, severity error vs warn]
tags: [guia-entrevista, dbt]
---
# Test genérico vs test singular

> [!tip] Respuesta rápida
> **Genérico** (`unique`, `not_null`, `relationships`, o uno propio parametrizable) para reglas reutilizables entre columnas/modelos; **singular** (un `.sql` en `tests/`) para una regla de negocio concreta de un solo modelo.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| Genérico | Reutilizable en cualquier columna/modelo, se declara en YAML, soporta `where:` y `store_failures` | Limitado a lo que el macro de test ya parametriza | Unicidad, not_null, relaciones, rangos — reglas que se repiten |
| Singular | SQL libre, cualquier lógica de negocio, directo en un fichero | No reutilizable sin convertirlo en genérico | Una regla de negocio específica de un modelo (ej. "ninguna reserva no cancelada con 0 noches") |

## En travel-dwh-lab
`_marts__models.yml` usa genéricos (`unique`, `not_null`) sobre `booking_id`, `fx_rate_eur_to_reporting` y `revenue_eur` de `fct_bookings`. Un test singular natural para este dataset (D5-03) sería uno que compruebe que ninguna reserva no cancelada tiene `total_nights = 0` — regla de negocio concreta, no reutilizable en otro modelo.

## `store_failures`: dónde ver las filas que fallaron

Por defecto un test solo dice *cuántas* filas fallaron, no cuáles. Con `config: store_failures: true` (en genérico o singular), dbt materializa las filas que fallan en una tabla real cada vez que corre el test — en `travel-dwh-lab`, en el esquema `analytics_dev.dbt_dev_dbt_test__audit`, una tabla por test. El propio log de `dbt test` te da la ruta exacta ("See test failures: select * from ...").

## Un gotcha real de selección (D5-03)

`dbt test --select <modelo>` usa por defecto selección indirecta **"eager"**: arrastra también cualquier test *singular* que referencie ese modelo con `ref()`, aunque solo quisieras ejecutar los tests genéricos de columna. Pasó en `travel-dwh-lab`: al seleccionar `stg_hotel_bookings__bookings` para probar un cambio en un test genérico, se coló también el test singular de "reserva no cancelada con 0 noches" (680 filas, `severity: error` por defecto), dando un `ERROR` inesperado que no tenía que ver con lo que se estaba probando. Ver [[dbt-selectores-y-state]].

## Respuesta modelo
Contexto: tengo que decidir si una regla va como test genérico o singular, y qué `severity` darle. Opciones: genérico reutilizable, singular ad-hoc, con `severity: error` o `warn`. Elijo singular para la regla de "reserva no cancelada con 0 noches" porque es específica de `fct_bookings` y no la voy a reutilizar en otro modelo; le pongo `severity: warn` porque el dataset real (Hotel Booking Demand) tiene casos legítimos de 0 noches y bloquear el build sería un falso positivo constante. El riesgo es que un `warn` se ignore sistemáticamente y deje de servir de alerta; lo mitigo revisando los warns en cada PR en vez de solo mirar si el build está verde.

## Conceptos relacionados
- [[model-contracts-dbt]]
- [[source-freshness-dbt]]
- [[dbt]]
