---
tipo: concepto
herramienta: dbt
aliases: [staging vs intermediate, capas de modelado dbt, dbt layering, stg int fct dim, arquitectura de modelos dbt]
tags: [guia-entrevista, dbt]
---
# Capas de modelado en dbt: staging, intermediate, marts

> [!tip] Respuesta rápida
> **Staging** (`stg_*`): 1:1 con una fuente, solo tipar/renombrar/limpiar, sin mezclar fuentes ni lógica de negocio. **Intermediate** (`int_*`): combina o transforma staging con lógica de negocio que aún no es un hecho/dimensión final. **Marts** (`fct_*`/`dim_*`): el producto final, lo que consume BI o un analista. La capa se decide por **qué hace el modelo**, no por dónde "toca" ponerse algo.

## Definición

Es una convención (no una obligación de dbt) para no meter toda la complejidad de una transformación en un único SQL gigante, y para poder testear/depurar cada paso por separado:

- **Staging**: un modelo por tabla de origen. Tipar columnas (`try_to_number`, `try_to_date`...), renombrar a un estándar legible, limpiar casos obvios (`'NA'` → `NULL`). **Nunca** hace `JOIN` con otra fuente ni aplica una decisión de negocio — eso ya no sería "limpiar lo que llegó".
- **Intermediate**: combina varios staging, o aplica una transformación con lógica de negocio que necesita su propio nombre y sus propios tests, pero que todavía no es el resultado final que alguien consulta directamente. Es la capa que existe para que los marts no tengan que ser ilegibles.
- **Marts**: el modelo que responde a una pregunta de negocio concreta, al grano que espera quien lo consume (`fct_` = tabla de hechos, grano transaccional; `dim_` = dimensión). Aquí es donde se declaran los contratos de grano (tests de `unique`/`not_null` sobre la clave), porque es la interfaz con el exterior.

La pregunta para decidir la capa no es "¿dónde pongo esto?", es "¿qué hace este modelo?": si solo tipa una fuente → staging; si combina fuentes o aplica una regla de negocio reutilizable → intermediate; si es el resultado que alguien va a consultar tal cual → marts.

## Ejemplo mínimo (travel-dwh-lab)

```
stg_hotel_bookings__bookings   staging   tipa el CSV de Kaggle, 1:1 con raw.hotel_bookings.bookings
stg_ecb__exchange_rates        staging   tipa raw.ecb.exchange_rates, 1:1 con esa fuente

int_exchange_rates__daily      intermediate
    combina stg_ecb__exchange_rates con un calendario generado (no es una fuente)
    y aplica una decisión de negocio (forward-fill de fines de semana) —
    por eso no es staging: ya no es "la fuente tal cual, tipada"

fct_bookings                   marts
    combina stg_hotel_bookings__bookings + int_exchange_rates__daily,
    aplica la regla de negocio final (tipo del día de la reserva, revenue=0 si cancelada),
    y es lo que consulta un analista — aquí viven los tests de unique/not_null sobre booking_id
```

Materialización habitual (ver `dbt_project.yml` del repo): `staging`/`intermediate` como `view` (barato, siempre al día, no ocupa storage); `marts` como `table` (lo que consulta BI no debería recompilarse en cada query).

## Errores típicos
- Meter lógica de negocio en staging (p. ej. calcular `revenue` ahí) — rompe la idea de que staging es un mapeo fiel y auditable de la fuente; si cambia la regla de negocio, no sabes si el problema es el dato de origen o la regla.
- Saltarse intermediate y amontonar varios `JOIN` + lógica compleja directo en el mart — funciona, pero hace el modelo final difícil de leer y de testear por partes.
- Crear una capa intermediate "porque toca", sin que combine nada ni aporte lógica — una capa de más sin motivo es la abstracción prematura de dbt: tres modelos no necesitan cuatro capas.
- Confundir esto con las "tres capas de Snowflake" ([[arquitectura-tres-capas-snowflake]]) — son conceptos completamente distintos (Storage/Compute/Cloud Services es infraestructura; staging/intermediate/marts es organización de modelos dbt).

## Pregunta probable
**¿Cómo decides si algo es intermediate o va directo al mart?** Si la transformación combina fuentes o encapsula una regla de negocio que querrías testear o reutilizar por separado (como el forward-fill de tipos de cambio), es intermediate. Si es una combinación simple y de un solo uso para llegar al resultado final, puede ir directo en el mart — no hay una regla rígida, es legibilidad y reutilización.

**¿Por qué los tests de grano (unique/not_null sobre la clave) van en el mart y no en el intermediate?** Porque el grano que importa es el que promete el modelo que consume alguien externo — un intermediate puede tener legítimamente varias filas por "entidad de negocio" (como `int_exchange_rates__daily`, varias filas por día) sin que eso sea un error; el mart es quien declara el contrato final. Ver [[dbt-selectores-y-state]] para el caso real de `travel-dwh-lab` donde esto se comprobó con un fan-out.

## Aparece en
- Relacionados: [[materializacion-view-table-incremental-ephemeral]], [[model-contracts-dbt]], [[dbt-selectores-y-state]]
