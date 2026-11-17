"""Ingesta diaria de tipos de cambio del BCE a RAW.ECB.EXCHANGE_RATES.

Decisiones:
- Idempotente: borra e inserta el rango de fechas en una transacción.
  Reejecutar un día (o un backfill) nunca duplica filas.
- El rango sale del data interval, no de `now()`: así los backfills cargan el día correcto.
- Carga histórica: lanzar a mano con params start_period / end_period (YYYY-MM-DD),
  p. ej. desde 2013-01-01, en una sola ejecución.
- Fines de semana y festivos el BCE devuelve 404 "sin datos": no es un error.
"""

from __future__ import annotations

import csv
import io
from datetime import date, timedelta

import pendulum
import requests
from airflow.providers.snowflake.hooks.snowflake import SnowflakeHook
from airflow.sdk import Asset, Param, dag, get_current_context, task


ECB_URL = "https://data-api.ecb.europa.eu/service/data/EXR/D.{currencies}.EUR.SP00.A"
CURRENCIES = ["GBP", "USD", "CHF"]
TARGET_TABLE = "RAW.ECB.EXCHANGE_RATES"

# Mismo nombre en el DAG productor y en el consumidor: Airflow los enlaza por nombre.
ECB_EXCHANGE_RATES = Asset(name="raw.ecb.exchange_rates")


def _resolve_period(context) -> tuple[date, date]:
    params = context["params"]
    if params.get("start_period"):
        start = date.fromisoformat(params["start_period"])
        end = date.fromisoformat(params.get("end_period") or params["start_period"])
        return start, end

    interval_start = context.get("data_interval_start")
    interval_end = context.get("data_interval_end")
    if interval_start is None or interval_end is None:
        # Ejecución manual sin logical date: cargar ayer
        yesterday = pendulum.now("UTC").subtract(days=1).date()
        return yesterday, yesterday

    # Intervalo diario [D, D+1): solo el día D
    return interval_start.date(), (interval_end - timedelta(days=1)).date()


@dag(
    dag_id="ecb_exchange_rates",
    schedule="@daily",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    default_args={
        "retries": 3,
        "retry_delay": timedelta(minutes=5),
        "retry_exponential_backoff": True,
    },
    params={
        "start_period": Param("", type="string", description="Carga manual: fecha inicial YYYY-MM-DD"),
        "end_period": Param("", type="string", description="Carga manual: fecha final YYYY-MM-DD"),
    },
    tags=["ingesta", "ecb"],
)
def ecb_exchange_rates():
    @task
    def extract() -> dict:
        context = get_current_context()
        start, end = _resolve_period(context)

        response = requests.get(
            ECB_URL.format(currencies="+".join(CURRENCIES)),
            params={
                "startPeriod": start.isoformat(),
                "endPeriod": end.isoformat(),
                "format": "csvdata",
            },
            timeout=60,
        )
        if response.status_code == 404:
            rows: list[dict] = []
        else:
            response.raise_for_status()
            rows = [
                {
                    "rate_date": r["TIME_PERIOD"],
                    "currency": r["CURRENCY"],
                    "rate": r["OBS_VALUE"],
                }
                for r in csv.DictReader(io.StringIO(response.text))
                if r.get("OBS_VALUE")
            ]

        print(f"{len(rows)} tipos entre {start} y {end}")
        # Pocas filas (incluso el histórico completo son unos miles): caben en XCom.
        # Con volúmenes grandes se escribiría a un stage y se pasaría solo la ruta.
        return {"start": start.isoformat(), "end": end.isoformat(), "rows": rows}

    @task(outlets=[ECB_EXCHANGE_RATES])
    def load(payload: dict) -> int:
        hook = SnowflakeHook(snowflake_conn_id="snowflake_default")
        conn = hook.get_conn()
        cur = conn.cursor()
        try:
            cur.execute("begin")
            cur.execute(
                f"delete from {TARGET_TABLE} where rate_date between %(start)s and %(end)s",
                {"start": payload["start"], "end": payload["end"]},
            )
            if payload["rows"]:
                cur.executemany(
                    f"insert into {TARGET_TABLE} (rate_date, currency, base_currency, rate, loaded_at) "
                    "values (%(rate_date)s, %(currency)s, 'EUR', %(rate)s, current_timestamp())",
                    payload["rows"],
                )
            cur.execute("commit")
        except Exception:
            cur.execute("rollback")
            raise
        finally:
            cur.close()
            conn.close()
        return len(payload["rows"])

    load(extract())


ecb_exchange_rates()
