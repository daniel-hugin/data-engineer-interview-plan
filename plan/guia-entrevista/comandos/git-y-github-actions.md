---
tipo: comandos
herramienta: git
aliases: [chuleta git, comandos github actions, git cheatsheet, ci cheatsheet]
tags: [guia-entrevista, git]
---
# Chuleta de comandos: Git y GitHub Actions

> [!tip] Respuesta rápida
> Úsala para "¿cómo es tu flujo de PR?" y "¿cómo verificarías la CI?". Flujo: rama → PR → checks obligatorios → merge. **Nunca push directo a `main`.**

## Flujo de rama y PR
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `git checkout -b <rama>` | Crea rama de trabajo desde main | Empezar cualquier cambio |
| `git push -u origin <rama>` | Publica la rama (con confirmación) | Antes de abrir el PR |
| `gh pr create` | Abre el PR contra `main` | Al terminar el cambio en la rama |
| `gh pr checks` | Muestra el estado de los checks del PR actual | Ver si `lint`/`build` han pasado |
| `gh run list` | Lista las ejecuciones recientes de workflows | Ubicar la ejecución de CI del PR |
| `gh run view --log` | Log completo de una ejecución | Ver por qué falló `lint` o `build` |

## CI
| Dato | Detalle |
|---|---|
| **Protección de `main`** | Requiere los checks `lint` y `build` en verde antes de poder mergear el PR |
| **`concurrency` + `cancel-in-progress`** | En `dbt-ci.yml`: `group: dbt-ci-${{ pull_request.number }}`, `cancel-in-progress: true` — un push nuevo al mismo PR **cancela la ejecución anterior**, así no se gastan créditos de Snowflake en builds obsoletos |
| **Job `lint`** | Corre `sqlfluff lint dbt/models` sin secretos ni conexión a Snowflake: falla rápido y barato antes de tocar la base de datos |
| **Job `build`** | Hace `dbt parse --target prod` sobre `main` para tener el manifest de producción, y luego `dbt build --select state:modified+ --defer --state ...` sobre el PR (slim CI); limpia con `drop_schemas_by_prefix` al final (`if: always()`) |

## Seguridad
| Comando | Qué hace | Cuándo usarlo |
|---|---|---|
| `gitleaks detect` | Escanea **todo el historial** del repo buscando secretos (claves, tokens) commiteados | Antes de abrir un PR si tocaste algo cerca de credenciales, o como chequeo periódico |

Otros puntos de seguridad del repo: la clave privada de CI se escribe a un fichero temporal en `$RUNNER_TEMP` con `chmod 600` y nunca se imprime; los secretos (`SNOWFLAKE_CI_PRIVATE_KEY`, etc.) viven en el `environment: ci` de GitHub, no en el repo.

## Conceptos relacionados
- [[trunk-based-vs-gitflow]]
- [[oidc-vs-claves-estaticas]]
- [[slim-ci-y-defer]]
- [[dbt-ci-rompe-modelo-downstream]]
