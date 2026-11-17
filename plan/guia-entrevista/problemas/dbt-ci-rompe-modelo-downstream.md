---
tipo: problema
herramienta: dbt
prioridad: alta
aliases: [PR rompe modelo que no toqué, dbt CI falla en modelo downstream, state modified+ falla, breaking change dbt CI, modelo descendiente roto]
tags: [guia-entrevista, dbt]
---
# Un PR rompe un modelo que nadie tocó en este PR

> [!tip] Respuesta rápida
> Normal: `state:modified+` también construye los **descendientes** del modelo cambiado (el `+`). Si tu PR cambia un staging, cualquier mart que dependa de él se reconstruye y puede romperse, aunque el PR no lo tocara directamente.

## Hipótesis (de más barata a más cara de comprobar)
1. **Cambio en un modelo de staging sin ajustar su descendiente** → el cambio de columna/tipo/nombre se propaga y el downstream no lo esperaba.
2. **El downstream asumía una forma de los datos que ya no se cumple** → sin contrato, nadie lo detecta hasta el build.
3. **Race condition o estado de prod desactualizado** → el `--state` con el que compara no refleja el último `main`.

## Diagnóstico paso a paso
```bash
# en el job "build" del workflow dbt-ci.yml:
# 1. checkout de main -> dbt parse --target prod --target-path .../prod-state (sin conectar a Snowflake)
# 2. sobre el PR: dbt build --select state:modified+ --defer --state .../prod-state
```
1. Lee el log de GitHub Actions del job `build` y localiza el primer modelo que falla.
2. Pregúntate: ¿quién lo construye? `dbt ls --select <modelo>+ --resource-type model` para ver sus descendientes y confirmar que es downstream del cambio real.
3. Compara la definición de columnas antes/después en el PR (`git diff`) para ver qué cambió exactamente en el modelo origen.

## Solución
- **Corregir en el mismo PR**: ajusta el modelo downstream para que siga funcionando con el nuevo shape (ej. renombrar columna en ambos sitios).
- **Model contracts en marts**: si el mart tiene contrato (`contract: {enforced: true}` con columnas y tipos declarados), el build falla rápido y explícito en vez de con un error confuso más abajo.

## Prevención
- **Branch protection** con el check `build` obligatorio antes de mergear a `main`.
- **Model contracts** en los marts críticos (como `fct_bookings`), para que un cambio de forma falle en CI con un mensaje claro.
- Revisar `dbt ls --select state:modified+` antes de abrir el PR, para saber de antemano qué se va a reconstruir.

## Cómo contarlo
Un PR que solo tocaba un modelo de staging rompió un mart en CI; la hipótesis fue que `state:modified+` reconstruye también los descendientes, así que el mart se recompiló con el cambio de forma del staging. Lo confirmé con `dbt ls --select <modelo>+` para ver que el mart roto era descendiente directo. La solución fue ajustar el mart en el mismo PR; para prevenirlo, propondría un model contract en los marts críticos para que el fallo sea explícito desde el principio.

## Conceptos relacionados
- [[dbt-selectores-y-state]]
- [[model-contracts-dbt]]
- [[slim-ci-y-defer]]
