# travel-dwh-lab

Laboratorio de ingeniería de datos para una empresa de viajes ficticia:
**Snowflake + dbt + Airflow + GitHub Actions**. Forma parte del [plan de 10 días](../README.md).

Pregunta de negocio de partida: *¿cuánto ingresamos, por canal y segmento, en la divisa
de reporting (GBP), y cuántas reservas perdemos por cancelación?*

## Arquitectura

```
GitHub ── PR ──► Actions: sqlfluff ─► dbt build (slim CI) en ANALYTICS_DEV.ci_pr_<n>_*
   │
   └── main ◄── pull cada 5 min (scripts/sync_repo.sh) ── servidor Airflow
                                                            │
             API BCE ──► DAG ecb_exchange_rates ──► RAW.ECB ─┤ (Asset)
                                                            ▼
             CSV Kaggle ──► stage + COPY INTO ──► RAW.HOTEL_BOOKINGS
                                                            │
                                         DAG dbt_travel_dwh ▼
                                 ANALYTICS.{STAGING, INTERMEDIATE, MARTS}
```

## Fuentes

| Fuente | Carga | Por qué |
|---|---|---|
| Hotel Booking Demand (Kaggle, ~119k reservas 2015-2017) | Única: stage + `COPY INTO` | Reservas, cancelaciones, canales, ADR |
| Tipos de cambio de referencia del BCE (GBP, USD, CHF) | Diaria: Airflow | Normalizar ingresos; huecos de fin de semana |

## Estructura

Los comandos de este README se ejecutan desde esta carpeta (`travel-dwh-lab-template/`) salvo que se indique otra cosa.

```
snowflake/setup.sql            roles, warehouses, BBDD, usuarios, resource monitor
snowflake/load_hotel_bookings.sql
scripts/generate_keypair.sh    claves RSA para usuarios de servicio
scripts/sync_repo.sh           despliegue por pull en el servidor de Airflow
dbt/                           proyecto dbt (staging -> intermediate -> marts)
dbt/.envrc.example             variables de dbt para direnv (opcional)
airflow/                       Dockerfile, docker-compose y DAGs
requirements-dbt.txt           dbt y SQLFluff (también lo usa la imagen de Airflow)
requirements-dev.txt           lo anterior + pre-commit, para trabajar en local
.sqlfluff                      configuración del lint de SQL
keys/                          claves privadas (ignorado por git)
data/                          CSV de Kaggle (ignorado por git)
```

En la raíz del repo, no aquí, están `.pre-commit-config.yaml` y `.github/workflows/dbt-ci.yml` (CI: lint + slim CI + limpieza de esquemas): GitHub y pre-commit solo los buscan en la raíz. Por eso los pasos del workflow usan `working-directory: travel-dwh-lab-template/...` y su filtro `paths:` solo lo dispara cuando cambia el proyecto dbt, no las notas del plan.

## Puesta en marcha

### 1. Snowflake
1. Crea la cuenta de prueba.
2. `scripts/generate_keypair.sh svc_airflow` y `scripts/generate_keypair.sh svc_ci`.
3. Pega las claves públicas en `snowflake/setup.sql` y ejecútalo.
4. Descarga `hotel_bookings.csv` a `data/`, súbelo al stage y ejecuta `snowflake/load_hotel_bookings.sql`.

### 2. dbt en local
```bash
python -m venv .venv && . .venv/bin/activate   # en Nushell: overlay use .venv/bin/activate.nu
pip install -r requirements-dev.txt
pre-commit install                             # opcional: lint y detección de claves en cada commit
cd dbt
export DBT_PROFILES_DIR=. SNOWFLAKE_ACCOUNT=<org>-<cuenta> SNOWFLAKE_USER=<tu_usuario> \
       SNOWFLAKE_PRIVATE_KEY_PATH=../keys/<tu_clave>.p8
dbt deps && dbt debug
```
En lugar de los `export`, puedes usar [direnv](https://direnv.net/): `cp .envrc.example .envrc`, rellénalo y ejecuta `direnv allow` dentro de `dbt/`. El `.envrc` está en `.gitignore`.

El primer `dbt build` hazlo cuando haya tipos de cambio en `RAW.ECB` (paso 3): `fct_bookings` los necesita para convertir los ingresos a GBP.

### 3. Airflow

Puedes correrlo en local o en cualquier servidor propio con Docker.

```bash
cp airflow/.env.example airflow/.env      # rellenar
cp <ruta>/svc_airflow.p8 keys/ && chmod 644 keys/svc_airflow.p8   # legible por el UID 50000
docker compose -f airflow/docker-compose.yml --env-file airflow/.env up -d --build
```
La UI queda en `http://localhost:8080` (o el host donde corras el compose).

Si ya tienes Airflow en tu propia infraestructura (una VM, un contenedor LXC, Kubernetes…), no necesitas el compose: monta `airflow/dags/`, `dbt/` y `keys/` en las rutas que define `airflow/docker-compose.yml`, instala dbt en un virtualenv aparte con `requirements-dbt.txt` y define las mismas variables de entorno.

Si lo despliegas en un servidor remoto, `scripts/sync_repo.sh` sirve de ejemplo de despliegue por *pull* vía cron. Ajusta `LAB_DIR` a la ruta de esta carpeta en el servidor:
```bash
crontab -e   # */5 * * * * /opt/data-engineer-interview-plan/travel-dwh-lab-template/scripts/sync_repo.sh >> /var/log/travel-dwh-sync.log 2>&1
```

Carga histórica: activa `ecb_exchange_rates` y lánzalo a mano con
`start_period=2013-01-01`, `end_period=<hoy>`. Al terminar, el Asset dispara `dbt_travel_dwh`,
que construye `ANALYTICS` (producción).

### 4. GitHub
- Secrets del environment `ci`: `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_CI_USER`, `SNOWFLAKE_CI_PRIVATE_KEY`.
- Protección de `main`: PR obligatorio + checks `lint` y `build` en verde.
- El slim CI necesita que producción exista: ejecuta antes el DAG de dbt una vez.

## Decisiones (y alternativas descartadas)

| Decisión | Por qué | Alternativa |
|---|---|---|
| Un warehouse XS por tipo de carga | Aislar costes y atribuirlos | Uno compartido: más simple, sin visibilidad |
| RAW todo en VARCHAR | RAW = lo que llegó; tipar en staging es reversible | Tipar en `COPY`: rechaza filas sin dejar rastro |
| Rol fijado por target en `profiles.yml` | El usuario de CI no puede escribir en prod | Rol por variable: un error de target llega a prod |
| CI en `ANALYTICS_DEV`, esquema por PR | Aislamiento entre PRs y limpieza por prefijo | Una BD de CI compartida: colisiones |
| Manifest de prod = `dbt parse` de main | Sin artefactos que almacenar | Subir `manifest.json` como artefacto en cada deploy |
| Lint sin conexión (templater jinja) | Barato, sin secretos, falla rápido | Templater dbt: más preciso, necesita Snowflake |
| Despliegue por pull | Nada expuesto; sin runner self-hosted | Runner self-hosted: riesgo con PRs de forks |
| LocalExecutor | Un nodo; Celery solo añade piezas | Celery/K8s cuando haya varios workers |
| dbt en virtualenv propio | Sin conflictos de dependencias con Airflow | Mismo entorno: roturas al actualizar |
| dbt disparado por Asset | Corre cuando hay datos, no a una hora | Cron fijo: corre aunque la carga falle |
| Ingesta delete+insert por rango | Idempotente: reintentos y backfills seguros | Append: duplicados al reintentar |
| FX del día de la reserva + forward fill | Es cuando se fija el precio; el BCE no publica fines de semana | Día de llegada; o descartar reservas sin tipo |

## Ejercicios por día del plan

- **Días 1-2:** ejecutar `setup.sql`; mirar el Query Profile de `fct_bookings`; consultar `ACCOUNT_USAGE.QUERY_HISTORY` filtrando por `query_tag`.
- **Días 3-4:** consultas sobre `fct_bookings`: tasa de cancelación por canal y mes, top-3 países por ingreso y hotel, rachas de días con ocupación creciente (*gaps & islands*).
- **Día 5:** activar el contrato de `fct_bookings`; convertirlo en incremental (¿qué `unique_key`? ¿qué hacer con reservas que cambian de estado?).
- **Día 6:** `mart_revenue_monthly`; snapshot SCD2 de `reservation_status`.
- **Día 7:** abrir un PR que rompa un test y ver cómo lo bloquea la CI; modificar el workflow.
- **Día 8:** probar Astronomer Cosmos en lugar del BashOperator.
- **Día 9:** romper los DAGs a propósito (ver lista abajo) y depurarlos.

### Fallos para el día 9

Provócalos en copias (`airflow/dags/lab_debug_*.py`) en tu instancia de Airflow, no en los DAGs del repo.

1. Importar un paquete que no está en la imagen → error de importación del DAG.
2. Conexión `snowflake_default` mal escrita → fallo en `load`.
3. Una llamada HTTP a nivel de módulo → parseo lento del dag-processor.
4. Pool de 1 slot compartido por dos DAGs → tareas atascadas en `queued`.
5. Usar `datetime.now()` en lugar del data interval → backfill que carga siempre el mismo día.
6. Quitar los permisos de lectura del usuario sobre `keys/` → error de autenticación.
