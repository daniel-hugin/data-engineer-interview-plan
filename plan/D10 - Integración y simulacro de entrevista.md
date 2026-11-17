---
tipo: epica
dia: 10
estado: confirmado
tags: [plan-10-dias, entrevista, simulacro, integracion]
aliases: [D10, Día 10]
---

# ÉPICA D10 — Integración y simulacro de entrevista

← [[D09 - Airflow II - depurar DAGs que fallan|Día 9]] · [[00 - Plan 10 días (índice)|Índice]]

**Objetivo del día:** poder contar el proyecto completo de forma clara y responder preguntas de decisión con estructura, como en la entrevista real.

**DoD de la épica:** tickets D10-01 a D10-05 en *Done*. D10-06 es opcional.

---

## D10-01 · El proyecto de punta a punta
**Tipo:** Práctica

**Definition of Done**
- [ ] Cadena completa ejecutada y seguida en vivo: DAG del BCE → evento del Asset → DAG de dbt → `mart_revenue_monthly` actualizado en `ANALYTICS`.
- [ ] Arquitectura dibujada de memoria en papel: fuentes, Airflow, Snowflake con sus tres bases y roles, dbt con sus capas, y GitHub con la CI.
- [ ] Proyecto contado en **3 minutos** cronometrados: qué problema resuelve, cómo está montado y dos decisiones de las que estés orgulloso.

## D10-02 · El repo listo para enseñar
**Tipo:** Tarea

**Definition of Done**
- [ ] El README refleja lo que existe: tabla de decisiones actualizada con los cambios de los días 6 a 9.
- [ ] Escáner de secretos sobre **todo el historial** de Git (por ejemplo `gitleaks detect`), sin hallazgos.
- [ ] Decidido si el repo pasa a público para la entrevista, y documentado.

## D10-03 · Repaso de puntos débiles
**Tipo:** Estudio

**Definition of Done**
- [ ] Revisadas las *Notas del día* de [[D01 - Snowflake - arquitectura y traducción desde BigQuery|D1]] a [[D09 - Airflow II - depurar DAGs que fallan|D9]], con la lista de preguntas de estudio que costaron.
- [ ] Todas las de esa lista respondidas otra vez en voz alta, sin mirar notas.

| Día | Pregunta que costó | ¿Superada en el repaso? |
|---|---|---|
| | | |

## D10-04 · Simulacro grabado
**Tipo:** Práctica

**Definition of Done**
- [ ] Grabación respondiendo estas cuatro preguntas, con un máximo de 3 minutos cada una:
    1. «Migramos de BigQuery a Snowflake: ¿qué te preocupa primero?»
    2. «La factura de Snowflake se ha duplicado este mes. ¿Qué haces?»
    3. «¿Cosmos o un único `dbt build` en Airflow?»
    4. «Un DAG que lleva meses funcionando falla esta noche. Guíame por tu proceso.»
- [ ] Dos preguntas más, elegidas al azar entre los tickets de estudio de D1 a D9.
- [ ] Cada respuesta evaluada con la rúbrica.
- [ ] Al menos 5 de las 6 respuestas cumplen los cinco criterios; las que no, repetidas.

**Rúbrica**

| Criterio | P1 | P2 | P3 | P4 | P5 | P6 |
|---|---|---|---|---|---|---|
| Estructura *contexto → opciones → elijo X porque… → riesgo y mitigación* | | | | | | |
| Elección concreta (no se queda en «depende») | | | | | | |
| Ejemplo propio (del repo o de la experiencia) | | | | | | |
| Riesgo nombrado y su mitigación | | | | | | |
| Menos de 3 minutos | | | | | | |

## D10-05 · Preguntas para el entrevistador
**Tipo:** Tarea

**Definition of Done**
- [ ] Al menos cinco preguntas que ayuden a decidir y demuestren criterio. Ideas: versión de Airflow y planes de migración, control del coste de Snowflake, cómo es su CI de dbt, cómo se reparte la propiedad de los modelos, qué esperan del puesto en los primeros 90 días.

1.
2.
3.
4.
5.

## D10-06 · *(Opcional)* Simulacro con Claude
**Tipo:** Práctica (*stretch*)

**Definition of Done**
- [ ] Entrevista simulada de 30 minutos en el chat: Claude hace de entrevistador, con repreguntas, y al final da una valoración con la misma rúbrica.

---

## Notas del día
