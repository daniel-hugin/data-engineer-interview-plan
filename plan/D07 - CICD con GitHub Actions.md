---
tipo: epica
dia: 7
estado: confirmado
tags: [plan-10-dias, cicd, github-actions, dbt, slim-ci]
aliases: [D7, Día 7]
---

# ÉPICA D7 — CI/CD con GitHub Actions

← [[D06 - dbt II - dbt sobre Snowflake|Día 6]] · [[00 - Plan 10 días (índice)|Índice]] · Siguiente: [[D08 - Airflow I - diseño de DAGs y decisiones|Día 8]] →

**Objetivo del día:** tener el ciclo PR → CI → merge → despliegue funcionando sobre el repo real, y saber defender cada decisión del pipeline.

**DoD de la épica:** tickets D7-01 a D7-06 en *Done*.

**Requisito:** el *slim CI* usa `--defer` y lee de producción, así que el DAG `dbt_travel_dwh` tiene que haberse ejecutado al menos una vez en `prod`.

---

## D7-01 · Secretos y protección de rama
**Tipo:** Tarea

**Definition of Done**
- [ ] Environment `ci` creado en GitHub con los secretos `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_CI_USER` y `SNOWFLAKE_CI_PRIVATE_KEY`.
- [ ] Protección de `main`: PR obligatorio y checks `lint` y `build` requeridos.
- [ ] Un `git push` directo a `main` es rechazado.

## D7-02 · Primer PR: slim CI en acción
**Tipo:** Práctica

**Definition of Done**
- [ ] Producción construida al menos una vez (DAG `dbt_travel_dwh` ejecutado en Airflow).
- [ ] PR abierto desde `feat/d6-dbt` ([[D06 - dbt II - dbt sobre Snowflake|día 6]]); `lint` y `build` en verde. Si SQLFluff falla, se corrige el SQL, no la configuración del linter.
- [ ] En los logs del job `build`, solo se seleccionan los modelos nuevos o modificados y sus descendientes.
- [ ] Durante la ejecución aparecen esquemas `ci_pr_<n>_*` en `ANALYTICS_DEV`, y al terminar ya no están.

## D7-03 · Romperlo a propósito (la pregunta tipo)
**Tipo:** Práctica

**Definition of Done**
- [ ] En otra rama renombras una columna en un modelo de staging sin tocar sus descendientes, y abres el PR.
- [ ] La CI falla en un modelo aguas abajo que nadie tocó, y GitHub bloquea el merge.
- [ ] Respondes en voz alta: «Un PR rompe un modelo downstream que nadie tocó. ¿Cómo evitas que llegue a producción?» Incluye por qué `state:modified+` lleva el `+` y el papel de la protección de rama y de los contratos del [[D05 - dbt I - flujo de trabajo y decisiones de modelado|día 5]].

## D7-04 · Merge y despliegue
**Tipo:** Práctica

**Definition of Done**
- [ ] PR del día 6 fusionado.
- [ ] En menos de 5 minutos, el log de `sync_repo.sh` en tu servidor de Airflow muestra el nuevo commit desplegado.
- [ ] En la siguiente ejecución del DAG de dbt, los modelos nuevos aparecen en `ANALYTICS`.
- [ ] Explicas en voz alta la cadena completa: PR → CI → merge → pull en el servidor → Airflow → `prod`, y qué valida cada paso.

## D7-05 · Fundamentos de GitHub Actions
**Tipo:** Estudio

**DoD:** respondes en voz alta, sin mirar notas:
1. Diferencia entre los triggers `pull_request`, `push`, `workflow_dispatch` y `schedule`. ¿Por qué `pull_request_target` es peligroso en un repo público?
2. ¿Por qué los PRs desde un fork no reciben los secretos del repo, y cómo afecta eso a tu CI?
3. ¿Para qué sirven `concurrency` y `cancel-in-progress` en tu workflow?
4. ¿Qué es una matriz y cuándo la usarías en un pipeline de datos?
5. ¿Qué aportan los *environments* con aprobación obligatoria frente a los secretos del repo?

## D7-06 · Decisiones del pipeline
**Tipo:** Estudio

**DoD:** defiendes cada decisión con la estructura *contexto → opciones → elijo X porque… → riesgo y mitigación*:
1. Trunk-based frente a GitFlow para un equipo de datos.
2. Dónde guardar el `manifest.json` de producción: parsear `main` (la elección del repo) frente a subirlo como artefacto o a un bucket.
3. OIDC frente a credenciales estáticas: qué haría falta para que GitHub se autentique en Snowflake sin una clave guardada, y qué se gana.
4. Por qué la CI construye en `ANALYTICS_DEV` con un rol que no puede escribir en producción.
5. Qué bloquea un merge y qué solo avisa (lint, tests en `error` o `warn`, *freshness*).

---

## Notas del día
