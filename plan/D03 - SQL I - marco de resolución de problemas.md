---
tipo: epica
dia: 3
estado: confirmado
tags: [plan-10-dias, sql, ventanas, entrevista]
aliases: [D3, Día 3]
---
# ÉPICA D3 — SQL I: marco de resolución de problemas

← [[D02 - Snowflake - operación, monitorización y decisiones|Día 2]] · [[00 - Plan 10 días (índice)|Índice]] · Siguiente: [[D04 - SQL II - rendimiento y depuración de consultas|Día 4]] →

**Objetivo del día:** resolver problemas de SQL con un método explícito y reconocible, y dominar los patrones que más aparecen en entrevistas.

**DoD de la épica:** todos los tickets en *Done*.

Los ejercicios propios usan `stg_hotel_bookings__bookings`, que no depende del histórico del BCE. Para sesionización y retención se usan ejercicios externos o datos de ejemplo, porque el dataset de hoteles no tiene identificador de cliente ni eventos.

---

## D3-01 · Marco de resolución en 5 pasos
**Tipo:** Estudio + práctica

**Definition of Done**
- [ ] Enumeras de memoria los 5 pasos: granularidad del resultado, granularidad de las entradas y riesgo de *fan-out*, descomposición en CTEs, casos borde, validación con conteos.
- [ ] Resuelves un ejercicio dejando un comentario SQL que marque cada paso.
- [ ] Respondes en voz alta:
    1. ¿Qué es el *fan-out* en un join y cómo lo detectas antes de que te infle una suma?
    2. ¿Qué diferencia hay entre `COUNT(*)`, `COUNT(col)` y `COUNT(DISTINCT col)` cuando hay NULLs?

## D3-02 · Funciones de ventana
**Tipo:** Práctica

**Definition of Done**
- [ ] Sobre las reservas: llegadas por hotel y mes, con un **total acumulado** del año y la **variación respecto al mes anterior** con `LAG`.
- [ ] Respondes en voz alta: diferencia entre `ROW_NUMBER`, `RANK` y `DENSE_RANK` ante empates, con un ejemplo.
- [ ] Respondes en voz alta: qué cambia al usar `ROWS BETWEEN` frente a `RANGE BETWEEN` en un total acumulado.

## D3-03 · Top-N por grupo y deduplicación con `QUALIFY`
**Tipo:** Práctica

**Definition of Done**
- [ ] Los **3 países con más noches reservadas** (no canceladas) por tipo de hotel, resuelto con `QUALIFY`.
- [ ] El mismo resultado sin `QUALIFY` (subconsulta o CTE), para cuando el motor no lo soporte.
- [ ] Respondes en voz alta: cómo deduplicarías una tabla RAW quedándote con la versión más reciente de cada registro (el patrón de `stg_ecb__exchange_rates`).

## D3-04 · Gaps & islands
**Tipo:** Práctica

**Definition of Done**
- [ ] Sobre las reservas: la **racha más larga de días consecutivos** con al menos N llegadas por hotel (elige un N que dé resultados interesantes).
- [ ] Explicas en voz alta el truco de la diferencia entre la fecha y el `ROW_NUMBER` para identificar cada isla.

## D3-05 · Sesionización y retención por cohortes
**Tipo:** Práctica

Teoría: [[sesionizacion-y-retencion-cohortes]]

**Definition of Done**
- [ ] **Sesionización:** con una tabla de eventos de ejemplo (`user_id`, `event_ts`, creada con `VALUES`), asignas un identificador de sesión con la regla de 30 minutos de inactividad.
- [ ] **Retención:** resuelves un ejercicio de retención por cohortes de DataLemur o StrataScratch.
- [ ] Explicas en voz alta qué tienen en común sesionización y gaps & islands (`LAG` más una suma acumulada de banderas).

## D3-06 · Práctica externa narrada
**Tipo:** Práctica

**Definition of Done**
- [ ] 5 ejercicios de nivel medio o difícil en DataLemur o StrataScratch, **narrando en voz alta** mientras los resuelves.
- [ ] Para cada uno, registro en la tabla de abajo: patrón usado, tiempo, error cometido (si lo hubo) y caso borde que casi se escapa.

| # | Ejercicio | Patrón | Tiempo | Error | Caso borde |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |

---

## Notas del día
