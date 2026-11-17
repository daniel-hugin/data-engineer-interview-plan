"""Construye el proyecto dbt en producción cuando llegan tipos de cambio nuevos.

Decisiones:
- schedule = Asset: se dispara tras una carga correcta del BCE, sin horas "mágicas".
- Un único BashOperator para `dbt deps && dbt build`: con LocalExecutor daría igual
  separarlos, pero con Celery/Kubernetes cada tarea puede ir a otro worker y
  dbt_packages no existiría. Alternativa a evaluar (día 8): Astronomer Cosmos,
  una tarea por modelo, con reintentos y logs por modelo.
- dbt escribe target/, logs y paquetes en /tmp: el proyecto se monta en solo lectura.
"""

from __future__ import annotations

import os
from datetime import timedelta

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import Asset, dag

# Mismo nombre en el DAG productor y en el consumidor: Airflow los enlaza por nombre.
ECB_EXCHANGE_RATES = Asset(name="raw.ecb.exchange_rates")

DBT_BIN = os.environ.get("DBT_BIN", "/home/airflow/dbt_venv/bin/dbt")
DBT_PROJECT_DIR = os.environ.get("DBT_PROJECT_DIR", "/opt/airflow/dbt")

DBT_ENV = {
    "DBT_TARGET": "prod",
    "DBT_TARGET_PATH": "/tmp/dbt/target",
    "DBT_LOG_PATH": "/tmp/dbt/logs",
    "DBT_PACKAGES_INSTALL_PATH": "/tmp/dbt/dbt_packages",
}


@dag(
    dag_id="dbt_travel_dwh",
    schedule=[ECB_EXCHANGE_RATES],
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=10)},
    tags=["dbt", "transformacion"],
)
def dbt_travel_dwh():
    source_freshness = BashOperator(
        task_id="dbt_source_freshness",
        bash_command=f"{DBT_BIN} deps --quiet && {DBT_BIN} source freshness",
        cwd=DBT_PROJECT_DIR,
        env=DBT_ENV,
        append_env=True,
    )

    build = BashOperator(
        task_id="dbt_build",
        bash_command=f"{DBT_BIN} deps --quiet && {DBT_BIN} build",
        cwd=DBT_PROJECT_DIR,
        env=DBT_ENV,
        append_env=True,
        execution_timeout=timedelta(minutes=30),
    )

    source_freshness >> build


dbt_travel_dwh()
