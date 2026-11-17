---
tipo: concepto
herramienta: dbt
aliases: [capa semantica, semantic layer, dbt semantic layer, metricflow, definicion de metricas centralizada, golden record de metricas]
tags: [guia-entrevista, dbt]
---
# Capa semántica

> [!tip] Respuesta rápida
> Capa de abstracción entre el modelo físico (las tablas del warehouse) y quien consume los datos (BI, analistas, agentes de IA): define **una sola vez** qué significa cada métrica de negocio ("ingresos", "cliente activo"), para que nadie la reimplemente con una lógica distinta en cada dashboard.

## Definición

El problema que resuelve es muy concreto: sin capa semántica, es habitual que el equipo de ventas calcule "ingresos" sumando `order_amount`, finanzas lo calcule restando devoluciones, y un dashboard antiguo lo calcule de una tercera forma — los números no coinciden entre departamentos sin que nadie sepa por qué. La capa semántica centraliza la definición de cada métrica y sus dimensiones (por qué columnas se puede "cortar": fecha, región, producto), y cualquier herramienta que la consulte recibe siempre la misma lógica, traducida internamente al SQL real contra las tablas.

Desacopla el **modelo físico** (que puede cambiar: renombrar una columna, dividir una tabla) del **modelo lógico de negocio** (lo que el usuario final entiende por "ingresos") — un cambio en el esquema físico no debería obligar a tocar todos los dashboards que dependen de esa métrica, solo la definición centralizada.

Ejemplos en el ecosistema: **dbt Semantic Layer** (construido sobre MetricFlow, definido en YAML junto a los modelos), LookML de Looker, Cube.js.

**Relación con IA** (pregunta probable de entrevista): no es una capa diseñada "para" la IA — su propósito original es dar consistencia a BI humano, y existe desde antes de la IA generativa. Pero se ha vuelto especialmente relevante como base para que un agente de IA/LLM consulte datos de forma fiable: sin capa semántica, un LLM tiene que *adivinar* qué tablas unir y cómo agregar para responder "¿cuáles fueron los ingresos?", con riesgo de alucinar SQL incorrecto. Con capa semántica, el LLM consulta la métrica ya definida (vía API) en vez de improvisar la lógica de negocio.

## Ejemplo mínimo
```yaml
# metrics.yml (estilo dbt Semantic Layer / MetricFlow)
metrics:
  - name: total_revenue
    type: simple
    type_params:
      measure: order_amount
    label: "Ingresos totales"
```
Cualquier consumidor (dashboard, API, o un agente de IA) pide "total_revenue por región" sin saber ni importarle qué tabla o join hay detrás — la capa semántica lo resuelve.

## Errores típicos
- Pensar que es lo mismo que una vista o un modelo de BI: una vista es una tabla más; la capa semántica define métricas y dimensiones reutilizables entre **múltiples** herramientas, no una query fija.
- Definir la misma métrica en dos sitios (en la capa semántica y, por separado, hardcodeada en un dashboard) — rompe el propósito de tener una sola fuente de verdad.
- Confundirla con Master Data Management: la capa semántica resuelve "qué significa esta métrica", MDM resuelve "es esta la misma entidad en todos los sistemas" — problemas relacionados pero distintos.

## Pregunta probable
**¿Es la capa semántica una capa "para" la IA?** No por diseño — resuelve consistencia de métricas para BI humano desde antes de la IA generativa. Pero facilita que un agente de IA consulte datos sin improvisar lógica de negocio, por eso se promociona ahora como "AI-ready".

## Aparece en
- Relacionados: [[model-contracts-dbt]]
