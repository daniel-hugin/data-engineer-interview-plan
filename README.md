# Plan de 10 días — preparación de entrevista técnica (Data Engineer)

Plan de estudio de 10 días para preparar una entrevista técnica de Data Engineer centrada en **Snowflake**, **SQL**, **dbt**, **CI/CD con GitHub Actions** y **Airflow**. Incluye un laboratorio práctico y un tutor configurado para [Claude Code](https://claude.com/claude-code) que te guía sin darte las respuestas.

Cada día es una épica con tickets concretos y su *Definition of Done*. Los tickets son de cuatro tipos:

- **Tarea**: pasos concretos para configurar o ejecutar algo.
- **Práctica**: escribir SQL, modelos de dbt o DAGs, o provocar fallos y arreglarlos.
- **Estudio**: preguntas teóricas para responder en voz alta, sin mirar notas.
- *(Opcional)*: mismo tipo que su base, pero no bloquea la épica si vas justo de tiempo.

## Qué hay en el repo

```
├── README.md                    ← este fichero
├── CLAUDE.md                    ← instrucciones del tutor para Claude Code
├── perfil.example.md            ← plantilla de tu perfil
├── progreso.example.md          ← plantilla del registro de sesiones
├── .github/workflows/dbt-ci.yml ← CI: lint + slim CI (se prueba en el día 7)
├── plan/                        ← el plan (vault de Obsidian)
│   ├── 00 - Plan 10 días (índice).md
│   ├── 00 - Índice guía entrevista.md
│   ├── 01 - Chuleta rápida.md
│   ├── D01 … D10 - <título>.md
│   └── guia-entrevista/         ← conceptos, decisiones, problemas y comandos
└── travel-dwh-lab-template/     ← el laboratorio (Snowflake + dbt + Airflow)
```

## Primeros pasos

1. **Clona el repo** (o haz un fork si quieres guardar tu trabajo en GitHub).
2. **Crea tu perfil y tu registro de progreso** a partir de las plantillas, y rellena `perfil.md`:
   ```bash
   cp perfil.example.md perfil.md
   cp progreso.example.md progreso.md
   ```
   Los dos están en `.gitignore`: tus datos no se suben aunque tu fork sea público.
3. **Abre la carpeta `plan/` como vault** en [Obsidian](https://obsidian.md/), para que los enlaces `[[...]]` funcionen. También puedes leer los `.md` con cualquier editor.
4. **Monta el laboratorio** siguiendo su [README](travel-dwh-lab-template/README.md): cuenta de Snowflake, dbt en local, Airflow y GitHub.
5. **Empieza por el índice**, [`00 - Plan 10 días (índice)`](<plan/00 - Plan 10 días (índice).md>): ahí están los diez días, su estado y las dependencias entre ellos. Sigue los días en orden; cada nota enlaza a la siguiente.

## Estudiar con el tutor (Claude Code)

Abre Claude Code en la raíz del repo. Al leer `CLAUDE.md`, actúa como tutor: localiza en qué día estás, lee la nota de ese día y adapta las explicaciones a tu perfil. Cómo trabaja:

- **Tareas:** te guía paso a paso y comprueba con evidencia (la salida de un comando o una consulta) que se cumple cada punto del DoD.
- **Prácticas:** primero lo intentas tú. Si te atascas, te da pistas de menos a más; la solución completa solo si la pides.
- **Estudio:** te hace las preguntas de una en una, sin darte la respuesta antes. Después te corrige y repregunta como un entrevistador. Las preguntas de decisión las puntúa con una rúbrica.
- **Cierre:** las casillas del DoD las marcas tú. Al final de cada sesión, el tutor anota en `progreso.md` qué has avanzado y qué preguntas te costaron, para el repaso del día 10.

Sin Claude Code, el plan funciona igual: sigue los tickets por tu cuenta y usa la guía para comprobar tus respuestas.

## La guía de entrevista

`plan/guia-entrevista/` es material de referencia: conceptos, decisiones con la estructura *contexto → opciones → elijo X porque… → riesgo y mitigación*, problemas típicos (síntoma → diagnóstico → solución) y comandos por herramienta. `01 - Chuleta rápida.md` resume lo esencial para el último repaso.

Contiene las respuestas a muchas preguntas de estudio, así que consúltala **después** de contestar, no antes.

## El laboratorio

`travel-dwh-lab-template/` es un laboratorio de ingeniería de datos para una empresa de viajes ficticia: Snowflake, un proyecto dbt base y DAGs de Airflow, listos para empezar por el ticket D1-01. La CI con GitHub Actions (`.github/workflows/dbt-ci.yml`) también viene montada; en el día 7 la pones a prueba y la modificas. Su [README](travel-dwh-lab-template/README.md) explica la arquitectura, la puesta en marcha y las decisiones de diseño con sus alternativas.

## Seguridad

- Las claves (`keys/`, `*.p8`, `*.pem`) y los ficheros de variables (`.env`, `.envrc`) están en `.gitignore`. Rellena solo tus copias locales, nunca las plantillas `.example`.
- `.claude/settings.json` impide que Claude lea las claves, use el target `prod` de dbt o haga push a `main`. El CLAUDE.md añade más límites, como no ejecutar sentencias que modifiquen Snowflake sin tu confirmación.
- Si usas pre-commit (`pip install -r travel-dwh-lab-template/requirements-dev.txt` y `pre-commit install`), el hook `detect-private-key` bloquea cualquier commit que incluya una clave privada.

## Qué no es esto

Este plan no sustituye la documentación oficial de cada herramienta: es una guía de estudio con ejercicios prácticos sobre un proyecto concreto. Las preguntas de *Estudio* están pensadas para responderlas en voz alta, como en una entrevista real, no para leerlas y pasar a la siguiente.
