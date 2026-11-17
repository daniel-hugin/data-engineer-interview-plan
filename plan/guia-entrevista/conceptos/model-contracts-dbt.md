---
tipo: concepto
herramienta: dbt
aliases: [model contracts, contratos de modelo, dbt contract enforced, data_type contract]
tags: [guia-entrevista, dbt]
---
# Model contracts en dbt

> [!tip] Respuesta rápida
> `contract.enforced: true` obliga a declarar `data_type` en cada columna del `.yml`; dbt genera el DDL con esos tipos antes de ejecutar el SQL del modelo, así un cambio de tipo o columna renombrada/eliminada falla explícitamente al construir, en vez de romperse en silencio aguas abajo.

## Definición

Un model contract es una garantía estructural, no de calidad de datos. Cuando `contract.enforced: true` y declaras `data_type` en cada columna del `.yml`, dbt genera él mismo el `CREATE TABLE` con esos tipos y nombres de columna exactos **antes** de ejecutar el `SELECT` del modelo; si el `SELECT` devuelve columnas distintas (renombrada, tipo incompatible, columna que falta), el build falla ahí mismo, en tiempo de compilación/creación — no cuando algún consumidor aguas abajo se rompe en silencio semanas después.

Esto lo distingue de un test de dbt: un test corre **después** de que el modelo ya se construyó, y valida contenido (¿hay nulos?, ¿valores fuera de rango?). Un contrato valida la **forma** antes de construir. Por eso los contratos se reservan para marts/interfaces públicas (lo que consume BI u otros equipos) y no para staging, que cambia a menudo según cómo se parsea la fuente — congelarla ahí frena la iteración sin dar ningún valor real, porque staging no es una interfaz que alguien externo consuma directamente. Relacionado con [[dbt-selectores-y-state|state:modified]], que detecta *que* algo cambió; el contrato decide si ese cambio rompe la interfaz pública antes de llegar a producción.

## Ejemplo mínimo
```yaml
models:
  - name: fct_bookings
    config:
      contract: {enforced: true}
    columns:
      - name: booking_id
        data_type: number
      - name: booking_amount
        data_type: number(18,2)
```
En el repo, `fct_bookings` tiene hoy `contract.enforced: false` con un comentario pendiente: "ejercicio día 5: activarlo y declarar data_type en cada columna".

## Errores típicos
- Activar el contrato sin declarar `data_type` en todas las columnas (falla el build con error claro, pero hay que completarlo en todas, no solo en las nuevas).
- Poner contratos en modelos de staging, donde el *parsing* de la fuente aún cambia mucho.
- Olvidar que un contrato roto se detecta al construir, no es una validación de datos (eso son los tests).

## Pregunta probable
¿Por qué los contratos van en marts y no en staging? Porque el contrato congela una interfaz pública de cara a consumidores (BI, otros equipos); staging es una capa interna que se ajusta a menudo al cambiar cómo se parsea la fuente, y contratarla ahí frena iteración sin aportar valor.

## Aparece en
- [[dbt-ci-rompe-modelo-downstream]]
- [[test-generico-vs-singular]]
- Relacionados: [[slim-ci-y-defer]], [[source-freshness-dbt]]
