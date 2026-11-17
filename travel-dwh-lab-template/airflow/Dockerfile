# Contexto de build: raíz del repo (ver docker-compose.yml)
ARG AIRFLOW_VERSION=3.3.2
ARG PYTHON_VERSION=3.12
FROM apache/airflow:${AIRFLOW_VERSION}-python${PYTHON_VERSION}

ARG AIRFLOW_VERSION=3.3.2
ARG PYTHON_VERSION=3.12

# 1) Providers con las constraints oficiales: evita romper las dependencias de Airflow
COPY airflow/requirements.txt /tmp/airflow-requirements.txt
RUN pip install --no-cache-dir \
      "apache-airflow==${AIRFLOW_VERSION}" \
      -r /tmp/airflow-requirements.txt \
      --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"

# 2) dbt en un virtualenv aislado: sus dependencias no chocan con las de Airflow
COPY requirements-dbt.txt /tmp/requirements-dbt.txt
RUN python -m venv /home/airflow/dbt_venv \
 && /home/airflow/dbt_venv/bin/pip install --no-cache-dir -r /tmp/requirements-dbt.txt
