---
tipo: decision
herramienta: dbt
prioridad: media
aliases: [trunk based development, gitflow, estrategia de ramas equipo de datos, branching strategy]
tags: [guia-entrevista, cicd]
---
# Trunk-based vs GitFlow para un equipo de datos

> [!tip] Respuesta rápida
> **Trunk-based** (ramas cortas desde `main`, PR pequeños, CI por PR) para equipos de datos con despliegue continuo; **GitFlow** (ramas `develop`/`release`/`hotfix`) cuando hay versiones con ciclos de release largos y coordinados.

## Opciones
| Opción | Ventajas | Inconvenientes | Cuándo elegirla |
|---|---|---|---|
| Trunk-based | Integración continua, PRs pequeños y rápidos de revisar, menos conflictos de merge, CI valida cada cambio contra `main` | Exige disciplina de PRs pequeños y feature flags para trabajo a medio terminar | Pipelines de datos con despliegue frecuente, pocos entornos (dev/ci/prod) |
| GitFlow | Útil cuando hay releases versionadas y coordinadas con otros equipos/clientes | Ramas de larga vida, merges grandes y tardíos, más probabilidad de conflicto y de "funciona en mi rama" | Software con versiones distribuidas (no el caso típico de un DWH interno) |

## En travel-dwh-lab
El repo usa trunk-based: ramas cortas (`feat/d6-dbt`) que abren PR contra `main`, con CI (`dbt-ci.yml`) que corre *slim CI* sobre lo modificado y bloquea el merge si falla. No hay rama `develop` intermedia ni releases versionadas — Airflow despliega `main` directamente cada 5 minutos.

## Respuesta modelo
Contexto: tengo que justificar la estrategia de ramas de un pipeline de datos interno. Opciones: trunk-based o GitFlow. Elijo trunk-based porque no distribuyo software con versiones a clientes externos — tengo un único destino de despliegue (`main` → producción vía despliegue por pull) y lo que necesito es feedback rápido por PR, no coordinar releases. El riesgo es que un PR grande rompa `main` igualmente si se revisa mal; lo mitigo con CI obligatoria (slim build) y protección de rama que exige checks en verde antes de fusionar, en vez de depender solo de la disciplina de ramas largas de GitFlow.

## Conceptos relacionados
- [[oidc-vs-claves-estaticas]]
- [[dbt-ci-rompe-modelo-downstream]]
- [[git-y-github-actions]]
