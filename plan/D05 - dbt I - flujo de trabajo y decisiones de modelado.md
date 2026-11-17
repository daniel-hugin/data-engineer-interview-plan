---
tipo: epica
dia: 5
estado: confirmado
tags: [plan-10-dias, dbt, modelado, tests, contratos]
aliases: [D5, Día 5]
---

# ÉPICA D5 — dbt I: flujo de trabajo y decisiones de modelado

← [[D04 - SQL II - rendimiento y depuración de consultas|Día 4]] · [[00 - Plan 10 días (índice)|Índice]] · Siguiente: [[D06 - dbt II - dbt sobre Snowflake|Día 6]] →

**Objetivo del día:** dominar el ciclo de trabajo de dbt sobre el proyecto y saber justificar cada decisión de modelado: capa, materialización, tests y contratos.

**DoD de la épica:** todos los tickets en *Done*.

**Requisito:** el D5-01 necesita el histórico del BCE cargado. Si el [[D02 - Snowflake - operación, monitorización y decisiones|D2-07]] no está hecho, deja de ser opcional aquí.

---

## D5-01 · El proyecto completo en verde
**Tipo:** Tarea

**Definition of Done**
- [ ] Histórico del BCE cargado desde 2013 (D2-07 hecho).
- [ ] `dbt build` en `dev` sin errores (los *warn* son aceptables).
- [ ] `dbt docs generate` y `dbt docs serve`: navegas el grafo de linaje de `fct_bookings` hasta sus dos fuentes.
- [ ] Explicas en voz alta qué responsabilidad tiene cada capa con tus modelos como ejemplo: por qué `stg_` es una vista que solo tipa y renombra, por qué el forward fill del FX va en `int_`, y por qué `fct_bookings` es una tabla.

## D5-02 · Selectores y `state`
**Tipo:** Práctica

**Definition of Done**
- [ ] Con `dbt ls`, predices antes de ejecutar y luego compruebas qué devuelven: `-s stg_ecb__exchange_rates+`, `-s +fct_bookings`, `-s path:models/staging` y `-s tag:<un tag que añadas>`.
- [ ] Generas un manifest de referencia (`dbt parse --target-path state`), modificas un modelo de staging y compruebas qué selecciona `dbt ls -s state:modified+ --state state`. Es exactamente lo que hace la CI.
- [ ] Respondes en voz alta: diferencia entre `dbt build` y `dbt run` + `dbt test`. ¿Qué pasa con un modelo aguas abajo si falla un test de su padre?

## D5-03 · Tests genéricos y singulares
**Tipo:** Práctica

**Definition of Done**
- [ ] Añades un **test singular** en `tests/` (por ejemplo: ninguna reserva no cancelada tiene `total_nights = 0`), lo ejecutas y analizas lo que encuentra. Pista: el dataset tiene reservas de 0 noches.
- [ ] Decides si ese test va con `severity: error` o `warn` y lo justificas.
- [ ] Añades a un test genérico una configuración `where:` o `store_failures: true` y revisas dónde guarda dbt las filas que fallan.
- [ ] Respondes en voz alta: ¿cuándo usas un test genérico y cuándo uno singular?

## D5-04 · *Source freshness*
**Tipo:** Práctica

**Definition of Done**
- [ ] `dbt source freshness` ejecutado; interpretas el resultado de la fuente `ecb`.
- [ ] Explicas en voz alta por qué los umbrales son 3 días (*warn*) y 5 días (*error*), y por qué el dataset de hoteles no tiene *freshness*.

## D5-05 · *Model contracts*
**Tipo:** Práctica

**Definition of Done**
- [ ] Activas el contrato de `fct_bookings` (`contract.enforced: true`) declarando el `data_type` de cada columna, y el build pasa.
- [ ] Rompes el contrato a propósito (cambias un tipo o renombras una columna en el SQL) y lees el error.
- [ ] Respondes en voz alta: ¿qué diferencia hay entre un contrato y un test? ¿Por qué los contratos suelen ponerse en los marts y no en staging?

## D5-06 · Materializaciones e incrementales
**Tipo:** Estudio

**DoD:** respondes en voz alta, sin mirar notas:
1. View, table, incremental y ephemeral: ¿cuándo eliges cada una? Pon un ejemplo de tu proyecto o de tu experiencia.
2. Estrategias incrementales en Snowflake (`merge`, `delete+insert`, `append`, `microbatch`): ¿qué hace cada una y cuándo la elegirías?
3. ¿Cómo tratas los datos que llegan tarde (*late-arriving data*) en un incremental? ¿Qué es una ventana de *lookback*?
4. ¿Cuándo hace falta un `--full-refresh` y qué riesgos tiene en producción?
5. *(Pregunta tipo)* «¿Cuándo convertirías un modelo en incremental y qué riesgos asumes?»

---

## Notas del día
