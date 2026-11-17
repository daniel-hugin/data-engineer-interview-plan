#!/usr/bin/env bash
# Genera un par de claves RSA para un usuario de servicio de Snowflake.
# Uso: scripts/generate_keypair.sh svc_airflow
set -euo pipefail
name="${1:?Uso: $0 <nombre_usuario>}"
out="keys"
mkdir -p "$out"
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out "$out/${name}.p8" -nocrypt
openssl rsa -in "$out/${name}.p8" -pubout -out "$out/${name}.pub"
chmod 600 "$out/${name}.p8"
echo "Clave privada: $out/${name}.p8 (NO la subas al repo)"
echo "Clave pública para Snowflake (pégala en rsa_public_key):"
grep -v "PUBLIC KEY" "$out/${name}.pub" | tr -d '\n'; echo
