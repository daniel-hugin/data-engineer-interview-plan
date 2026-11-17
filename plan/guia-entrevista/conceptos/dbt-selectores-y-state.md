---
tipo: concepto
herramienta: dbt
aliases: [dbt selectors, dbt ls, state modified, slim ci selectors, dbt graph operators]
tags: [guia-entrevista, dbt]
---
# Selectores de dbt y state

> [!tip] Respuesta rápida
> `-s modelo+` selecciona el modelo y sus descendientes; `-s +modelo` selecciona el modelo y sus ancestros. `state:modified+` compara contra un manifest guardado y selecciona lo modificado **más** todo lo que depende de ello: es exactamente lo que hace el *slim CI*.

## Definición

dbt construye un grafo de dependencias (el *DAG* de modelos) a partir de los `ref()`/`source()` entre ficheros. Los selectores (`-s`/`--select`) eligen nodos de ese grafo con distintos métodos: por nombre, `tag:`, `path:`, `source:`, o por posición relativa a otro nodo con `+` (ancestros con `+modelo`, descendientes con `modelo+`, ambos con `+modelo+`; un número tras el `+` limita la profundidad, p. ej. `1+modelo` solo el padre directo). `dbt ls` (sin `--resource-type`) selecciona modelos y sus tests juntos por defecto — no solo los `.sql`. Los ancestros con `+` llegan hasta los nodos `source:`, no se quedan en el primer modelo de staging (comprobado en `travel-dwh-lab`: `+fct_bookings` incluye `source:travel_dwh.ecb.exchange_rates` y `source:travel_dwh.hotel_bookings.bookings`).

El método `state:` compara el grafo actual contra un **manifest** (`manifest.json`) guardado de una ejecución anterior — normalmente el de producción — y selecciona lo que cambió: `state:modified` (SQL o config distinto), `state:new` (modelo que no existía), `state:deleted`. Por sí solo, `state:modified` no dice nada de lo que depende de lo modificado; por eso [[slim-ci-y-defer|Slim CI]] siempre lo combina con `+` (`state:modified+`), para construir también los descendientes y detectar si un cambio rompe algo aguas abajo antes del merge. Ver [[model-contracts-dbt]] para otro mecanismo (contratos) que protege esa misma interfaz entre capas.

## Ejemplo mínimo
```bash
dbt ls -s stg_ecb__exchange_rates+     # el modelo y todo lo que depende de él
dbt ls -s +fct_bookings                # fct_bookings y todos sus ancestros
dbt parse --target-path state          # genera manifest de referencia

# en dbt-ci.yml: estado de producción = manifest de main parseado
dbt build --select state:modified+ --defer --state "$RUNNER_TEMP/prod-state"
```

## Errores típicos
- Olvidar el `+` en `state:modified+`: sin él solo construye lo modificado, no sus descendientes, y un cambio puede romper algo aguas abajo sin que la CI lo detecte.
- Confundir `dbt run` + `dbt test` con `dbt build`: `build` intercala modelos y sus tests en el orden del grafo; si falla un test de un padre, los hijos no se construyen.
- Generar el manifest de estado sobre la rama equivocada (debe ser producción/`main`, no el propio PR).
- **Ausencia de dependencias al construir un solo modelo** (`travel-dwh-lab`, D4-01): `dbt build -s int_exchange_rates__daily --target dev` falló con `Object 'ANALYTICS_DEV.DBT_DEV_STAGING.STG_ECB__EXCHANGE_RATES' does not exist or not authorized` — el modelo padre (`stg_ecb__exchange_rates`) nunca se había construido en ese esquema `dev`, porque `-s modelo` sin `+` no incluye sus ancestros. El mensaje de Snowflake es ambiguo a propósito (mezcla "no existe" con "no autorizado" en el mismo error, por seguridad — no revela si el objeto existe a alguien sin permiso para verlo), así que ante este error hay que distinguir: ¿es un problema de grants, o simplemente el objeto nunca se creó en este entorno? Aquí era lo segundo. Solución: `dbt build -s +int_exchange_rates__daily --target dev` (con `+` delante, para construir también los ancestros).

## Pregunta probable
**¿Por qué el `+` es la pieza clave en "un PR rompe un modelo downstream que nadie tocó"?** Sin él, `state:modified` solo mira lo tocado directamente; el `+` arrastra los descendientes y hace que la CI los construya y falle antes del merge.

## Aparece en
- [[dbt-ci-rompe-modelo-downstream]]
- Relacionados: [[slim-ci-y-defer]], [[model-contracts-dbt]]
