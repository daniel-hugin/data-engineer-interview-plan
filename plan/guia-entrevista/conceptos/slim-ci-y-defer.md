---
tipo: concepto
herramienta: dbt
aliases: [slim CI, dbt defer, state modified, dbt build state]
tags: [guia-entrevista, dbt]
---
# Slim CI y `--defer`

> [!tip] Respuesta rápida
> `--select state:modified+ --defer --state <manifest>` construye en CI solo lo que cambió (y sus downstream), y resuelve los `ref()` a modelos no seleccionados leyendo su definición ya construida en producción (vía el manifest), sin reconstruirlos. Ahorra tiempo y cómputo en cada PR.

## Definición

Slim CI resuelve un problema de coste/tiempo: en un proyecto grande, reconstruir **todo** el DAG de dbt en cada PR es lento y caro, cuando normalmente un PR solo toca un puñado de modelos. La solución combina dos piezas de [[dbt-selectores-y-state|selectores y state]]: `--select state:modified+` elige solo lo que cambió respecto a un manifest de referencia (más sus descendientes), y `--defer --state <manifest>` resuelve cualquier `ref()` hacia un modelo **no seleccionado** apuntando a su relación ya construida en producción (leyendo el manifest), en vez de construirlo también en el entorno de CI.

El manifest de referencia normalmente es el de producción (`main` ya parseado o construido), no el del propio PR — comparar contra el manifest equivocado hace que `state:modified` no detecte cambios reales, o marque como "modificado" algo que no lo es de verdad. Esto depende de que exista una build de producción previa de la que leer: si nunca se construyó, no hay manifest contra el que comparar ni relaciones que diferir, y el job cae a un `dbt build` completo (más lento, pero sigue siendo correcto).

## Ejemplo mínimo
En `.github/workflows/dbt-ci.yml`, el job `build` hace checkout de `main` y corre `dbt parse --target prod --target-path "$RUNNER_TEMP/prod-state"` (solo parsea, no conecta a Snowflake) para tener el manifest de producción. Luego, sobre el PR:
```bash
dbt build --select state:modified+ --defer --state "$RUNNER_TEMP/prod-state"
```
Si ese estado no existe (producción nunca se construyó), cae a un `dbt build` completo.

## Errores típicos
- Usar `--defer` sin que producción se haya construido nunca: no hay manifest de referencia, y el CI tiene que hacer el build completo (más lento, pero correcto).
- Comparar contra un manifest desactualizado (de una rama vieja): `state:modified+` puede no detectar cambios reales o marcar cambios que ya no existen.
- Olvidar el `+` en `state:modified+`: sin él no se construyen los modelos downstream afectados, y un modelo roto puede pasar CI sin probar lo que depende de él.

## Pregunta probable
¿Qué pasa si production nunca se ha construido con este job? El workflow cae al `dbt build` completo sin `--defer`, porque no existe `prod-state` contra el que comparar — es el requisito previo para que Slim CI funcione.

## Aparece en
- [[dbt-ci-rompe-modelo-downstream]]
- [[dbt-selectores-y-state]]
- Relacionados: [[model-contracts-dbt]], [[trunk-based-vs-gitflow]]
