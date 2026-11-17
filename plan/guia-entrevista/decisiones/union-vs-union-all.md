---
tipo: decision
herramienta: sql
prioridad: media
aliases: [union vs union all, por que union es mas lento, cuando usar union]
tags: [guia-entrevista, sql]
---
# `UNION` vs `UNION ALL`

> [!tip] Respuesta rápida
> `UNION ALL` concatena los resultados tal cual, sin mirar si hay repetidos — barato. `UNION` hace lo mismo y además **elimina duplicados**, lo que exige ordenar/agrupar (hash) todo el resultado combinado para detectar qué filas son idénticas — una pasada extra sobre el conjunto completo. Usa `UNION ALL` por defecto; `UNION` solo cuando el solape entre las dos consultas es posible y duplicar esa fila sería semánticamente incorrecto.

## Por qué `UNION` es más lento

Eliminar duplicados equivale a un `DISTINCT`/`GROUP BY` implícito sobre **todas** las columnas del resultado combinado: el motor necesita organizar (ordenar o hashear) el conjunto entero para poder comparar qué filas son iguales, antes de poder descartar las repetidas. `UNION ALL` se salta esa pasada por completo — solo concatena los flujos de las dos consultas según van llegando, sin necesitar ver el resultado completo a la vez.

## Cuándo necesitas `UNION` de verdad

Cuando las dos consultas pueden devolver **legítimamente la misma fila** (la misma entidad real) y quieres que aparezca una sola vez en el resultado — no por error, sino porque duplicarla sería incorrecto para la pregunta de negocio.

Ejemplo (`travel-dwh-lab`): "países que reservaron en el hotel City" `UNION` "países que reservaron en el hotel Resort". Si España reservó en los dos, con `UNION ALL` aparece dos veces; con `UNION` aparece una sola vez — correcto si la pregunta es "¿qué países reservaron en alguno de los dos hoteles?" (una lista, no un conteo de reservas).

## Regla práctica
Por defecto, `UNION ALL` — es lo que casi siempre quieres al combinar flujos que ya sabes disjuntos (particiones por fecha, por hotel, eventos de orígenes distintos). Solo cambia a `UNION` cuando el solape es posible **y** te importa que no se duplique.

## Pregunta probable
**¿Qué pasa si usas `UNION ALL` por descuido cuando sí podía haber solape?** Los conteos y sumas aguas abajo quedan inflados por las filas duplicadas — el mismo tipo de error que un fan-out de `JOIN` ([[fan-out-en-joins]]), pero causado por combinar conjuntos en vez de cruzarlos.

## Aparece en
- Relacionados: [[exists-vs-join-anti-join]], [[fan-out-en-joins]]
