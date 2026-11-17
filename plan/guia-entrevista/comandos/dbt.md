---
tipo: comandos
herramienta: dbt
aliases: [chuleta dbt, comandos dbt, dbt cheatsheet, dbt cli]
tags: [guia-entrevista, dbt]
---
# Chuleta de comandos: dbt

> [!tip] Respuesta rápida
> Úsala para "¿qué comando dbt usarías para X?": ciclo básico, selectores/state, slim CI y materializaciones. **Siempre `--target dev` o `--target ci`, nunca `--target prod` desde el portátil.**

## Ciclo básico
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `dbt debug` | Verifica conexión y config del profile | Primer paso si algo falla raro |
| `dbt run` | Materializa modelos (no corre tests) | Solo quieres construir |
| `dbt test` | Corre tests (schema + singulares), no reconstruye | Validar sin reconstruir |
| `dbt build` | `run` + `test` + `seed` + `snapshot` en el orden correcto del DAG | Uso normal diario, en vez de encadenar comandos |
| `dbt seed` | Carga CSVs de `seeds/` como tablas | Datos de referencia pequeños (ej. mapeos) |
| `dbt snapshot` | Captura cambios históricos (SCD tipo 2) | Tablas fuente que mutan y quieres histórico |

## Selectores y state
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `dbt ls -s stg_ecb__exchange_rates+` | Lista el modelo y todo lo que depende de él (downstream) | Ver impacto de tocar un staging |
| `dbt ls -s +fct_bookings` | Lista el modelo y todo lo que lo alimenta (upstream) | Ver de dónde viene un fact |
| `dbt ls -s path:models/staging` | Lista por carpeta | Trabajar solo una capa |
| `dbt ls -s tag:<tag>` | Lista por tag en `dbt_project.yml`/config | Agrupar por dominio o frecuencia |
| `dbt parse --target-path state` | Genera `manifest.json` sin ejecutar nada | Crear el "estado" de referencia (ej. de main) |
| `dbt ls -s state:modified+ --state state` | Lista lo modificado respecto a ese estado, y sus downstream | Ver qué tocaría el slim CI antes de correrlo |

## CI / slim CI
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `dbt build --select state:modified+ --defer --state <path>` | Construye solo lo modificado y downstream; lo no tocado se **lee de prod** vía `--defer` | Esto es literal lo que hace `dbt-ci.yml`: compara contra el manifest de `main` parseado aparte, construye en `ci_pr_<n>` |
| `dbt source freshness` | Comprueba si una fuente está "fresca" según `loaded_at_field` y umbrales | Antes de confiar en un staging si la fuente puede llegar tarde |
| `dbt run-operation drop_schemas_by_prefix --args "{prefix: ci_pr_42}"` | Corre la macro que borra esquemas `ci_pr_*` en cascada | Limpieza del `build` tras CI (paso `if: always()` en el workflow); la macro **rechaza correr contra `target.name == 'prod'`** y exige prefijo de ≥5 caracteres |

## Materializaciones y refresh
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `dbt docs generate` | Genera el manifest + catálogo para la doc | Antes de servir o publicar docs |
| `dbt docs serve` | Levanta la doc en local | Explorar linaje y descripciones |
| `dbt compile --target dev` | Renderiza el SQL final (con jinja resuelto) sin ejecutar | Ver qué SQL real se manda a Snowflake |
| `dbt build -s <modelo> --full-refresh` | Fuerza reconstrucción completa de un incremental | Cambiaste la lógica incremental o hay datos corruptos acumulados |

> [!warning] Seguridad de targets
> `dev` y `ci` son los únicos targets permitidos desde el portátil. `prod` solo lo toca Airflow (rol `transformer`, warehouse `transforming_wh`). Nunca `--target prod` en local.

## Conceptos relacionados
- [[dbt-selectores-y-state]]
- [[slim-ci-y-defer]]
- [[dbt-ci-rompe-modelo-downstream]]
- [[source-freshness-dbt]]
- [[materializacion-view-table-incremental-ephemeral]]
