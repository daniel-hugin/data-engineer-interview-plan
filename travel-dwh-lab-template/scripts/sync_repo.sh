#!/usr/bin/env bash
# Despliegue por "pull": se ejecuta en el servidor de Airflow vía cron.
#   */5 * * * * /opt/data-engineer-interview-plan/travel-dwh-lab-template/scripts/sync_repo.sh >> /var/log/travel-dwh-sync.log 2>&1
# Trae main y, solo si cambió la imagen (Dockerfile o requirements), la reconstruye.
# DAGs y proyecto dbt van montados como volumen: basta con actualizar el checkout.
set -euo pipefail
LAB_DIR="${LAB_DIR:-/opt/data-engineer-interview-plan/travel-dwh-lab-template}"
cd "$LAB_DIR"

git fetch --quiet origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
[ "$LOCAL" = "$REMOTE" ] && exit 0

# --relative: rutas relativas al lab y solo los cambios dentro de él
CHANGED=$(git diff --name-only --relative "$LOCAL" "$REMOTE")
git merge --ff-only --quiet origin/main
echo "$(date -Is) desplegado ${REMOTE:0:7}"

if echo "$CHANGED" | grep -qE '^(airflow/Dockerfile|airflow/requirements.txt|requirements-dbt.txt|airflow/docker-compose.yml)$'; then
    echo "$(date -Is) cambios en la imagen/compose: reconstruyendo"
    docker compose -f airflow/docker-compose.yml --env-file airflow/.env up -d --build
fi
