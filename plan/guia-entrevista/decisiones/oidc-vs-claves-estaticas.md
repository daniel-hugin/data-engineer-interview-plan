---
tipo: decision
herramienta: dbt
prioridad: media
aliases: [oidc vs static credentials, github actions oidc snowflake, workload identity federation, claves estaticas ci]
tags: [guia-entrevista, cicd, snowflake]
---
# OIDC vs credenciales estáticas en la CI

> [!tip] Respuesta rápida
> **OIDC** cuando puedo configurar un *identity provider* de confianza en Snowflake y quiero eliminar secretos de larga vida; **claves estáticas** (como ahora) cuando el proveedor destino no soporta OIDC fácilmente o el coste de migrarlo no compensa todavía.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| OIDC (token federado) | Sin secreto de larga vida guardado en GitHub, token de corta vida emitido por GitHub y validado por Snowflake, menos superficie de robo | Requiere configurar un *external OAuth*/*security integration* en Snowflake que confíe en el emisor de tokens de GitHub, más piezas que entender | Se quiere eliminar por completo la gestión de claves/secretos rotativos en CI |
| Claves estáticas (clave privada RSA) | Simple de configurar, ya soportado de forma directa por `dbt-snowflake` | El secreto vive guardado en GitHub (`SNOWFLAKE_CI_PRIVATE_KEY`) y hay que rotarlo manualmente, riesgo si se filtra | Configuración rápida, equipo pequeño, rotación de claves ya controlada |

## En travel-dwh-lab
`dbt-ci.yml` usa hoy una clave estática: el secreto `SNOWFLAKE_CI_PRIVATE_KEY` se escribe a un fichero temporal (`$RUNNER_TEMP/snowflake_ci.p8`) en cada ejecución del job `build`. Para pasar a OIDC haría falta: 1) una *security integration* de tipo OAuth en Snowflake que confíe en el *issuer* de GitHub Actions (`token.actions.githubusercontent.com`), 2) mapear el *subject claim* del token (repo + rama) a un rol concreto, y 3) cambiar el workflow para pedir un `id-token: write` y obtener el token de OIDC en vez de leer el secreto de clave privada.

## Respuesta modelo
Contexto: la CI usa hoy una clave privada estática guardada como secreto de GitHub para autenticar `svc_ci` en Snowflake. Opciones: mantener la clave estática o migrar a OIDC. Elijo mantener la clave estática por ahora porque Snowflake soporta OIDC pero añade una pieza de configuración (security integration + mapeo de claims) que no es trivial y el equipo es pequeño; la clave rota con baja frecuencia y vive solo como secreto de GitHub Environment con aprobación. El riesgo que asumo es que un secreto de larga vida filtrado da acceso hasta que se rote manualmente; lo mitigo con el principio de mínimo privilegio (el rol `developer`/CI no puede escribir en `ANALYTICS` de producción) y lo reevaluaría si el equipo creciera o la superficie de ataque lo justificara.

## Conceptos relacionados
- [[trunk-based-vs-gitflow]]
- [[git-y-github-actions]]
- [[snowflake-vs-bigquery]]
