---
tipo: problema
herramienta: snowflake
prioridad: alta
aliases: [JWT token is invalid, 390144, JWT_TOKEN_INVALID_USER_IN_ISSUER, dbt debug falla con JWT, error autenticación key pair snowflake]
tags: [guia-entrevista, snowflake]
---
# `dbt debug` falla con "JWT token is invalid"

> [!tip] Respuesta rápida
> El mensaje de error del cliente es genérico y casi siempre engañoso. En vez de adivinar por el mensaje, consulta `INFORMATION_SCHEMA.LOGIN_HISTORY` — da un `error_code` específico (p. ej. `JWT_TOKEN_INVALID_USER_IN_ISSUER`) que apunta directo a la causa real.

## Hipótesis (de más barata a más cara de comprobar)
1. **Variables de entorno no exportadas en la shell actual** → si abriste una shell nueva, se pierden (`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PRIVATE_KEY_PATH`, `SNOWFLAKE_PRIVATE_KEY_PASSPHRASE`).
2. **Reloj del portátil desincronizado** → el JWT de key-pair auth tiene vida muy corta; con `timedatectl status` se descarta en segundos.
3. **Passphrase o ruta de clave incorrectas** → se detecta con un error distinto y más explícito ("Password was not given but private key is encrypted"), no exactamente este.
4. **Fingerprint público/privado no coincide** → hipótesis cara de comprobar pero concluyente: regenerar el fingerprint local y compararlo con `RSA_PUBLIC_KEY_FP`.
5. **(La real en este caso) El cliente usa el `NAME` del usuario en vez de su `LOGIN_NAME`** → Snowflake exige que el parámetro `user` del conector coincida con `LOGIN_NAME`, no con `NAME`; si tu usuario se creó con un login distinto al nombre interno (típico en cuentas de prueba/trial), el JWT se construye con un usuario que Snowflake no reconoce → `JWT_TOKEN_INVALID_USER_IN_ISSUER`.

## Diagnóstico paso a paso
```bash
# 1. variables de entorno definidas (sin imprimir valores sensibles)
for v in SNOWFLAKE_ACCOUNT SNOWFLAKE_USER SNOWFLAKE_PRIVATE_KEY_PATH SNOWFLAKE_PRIVATE_KEY_PASSPHRASE DBT_PROFILES_DIR; do
  echo "$v: $([ -n "${!v}" ] && echo definida || echo FALTA)"
done

# 2. reloj sincronizado
timedatectl status

# 3. fingerprint local (sin imprimir la clave privada)
openssl rsa -in clave_privada.p8 -passin env:SNOWFLAKE_PRIVATE_KEY_PASSPHRASE -pubout -outform DER \
  | openssl dgst -sha256 -binary | openssl enc -base64
```
```sql
-- compara ese hash contra RSA_PUBLIC_KEY_FP
desc user mi_usuario;
```
```sql
-- si clave, passphrase, cuenta y reloj están bien y SIGUE fallando:
-- pregúntale a Snowflake el motivo exacto, no al cliente
use warehouse dev_wh;
use database raw;

select event_timestamp, user_name, is_success, error_code, error_message
from table(information_schema.login_history(
  time_range_start => dateadd('minutes', -5, current_timestamp())
))
order by event_timestamp desc
limit 5;
```
Un `error_code = JWT_TOKEN_INVALID_USER_IN_ISSUER` significa que el usuario del *issuer* del JWT no existe tal cual en la cuenta — compara el `user` que estás pasando contra `LOGIN_NAME` (no `NAME`) en `desc user`.

## Solución
- **Variables perdidas**: reexporta todas antes de repetir el intento; no asumas que persisten entre shells.
- **Reloj**: activa NTP (`timedatectl set-ntp true`) o espera a que sincronice.
- **Fingerprint real no coincide**: regenera el par de claves y actualiza la pública en Snowflake (`alter user ... set rsa_public_key = '...'`).
- **`NAME` vs `LOGIN_NAME`**: cambia el parámetro `user` del conector (variable de entorno o `profiles.yml`) para que use el valor de `LOGIN_NAME`, no el `NAME` interno del usuario.

## Prevención
- Al dar de alta un usuario de servicio o personal, anota explícitamente **ambos** campos (`NAME` y `LOGIN_NAME`) en el gestor de contraseñas — no asumas que son iguales, especialmente en cuentas de prueba creadas desde el signup web.
- Ante un error de auth genérico, ir primero a `LOGIN_HISTORY` por el `error_code` específico, en vez de iterar a ciegas sobre clave/passphrase/reloj.
- No reescalar directamente a "regenerar claves" como primer paso — es la hipótesis más cara y, en este caso real, no era la causa.

## Cómo contarlo
Me encontré `JWT token is invalid` al conectar dbt con mi usuario personal, con clave y passphrase que ya había verificado por fingerprint. Descarté reloj desincronizado y variables de entorno perdidas. Como el mensaje del cliente era genérico, consulté `INFORMATION_SCHEMA.LOGIN_HISTORY`, que me dio el código exacto `JWT_TOKEN_INVALID_USER_IN_ISSUER`. Comparé `NAME` contra `LOGIN_NAME` en `desc user` y vi que no coincidían — mi usuario de prueba tenía un `LOGIN_NAME` (el email) distinto del `NAME` interno. Cambié la variable de usuario del conector para usar el `LOGIN_NAME`, y `dbt debug` pasó a dar *All checks passed!*. La lección: ante un error de auth genérico, usar el log de Snowflake para obtener la causa exacta en vez de iterar sobre hipótesis caras una a una.

## Conceptos relacionados
- [[airflow-tarea-falla-por-credenciales]] (mismo síntoma client-side, pero causa distinta en ese caso)
- [[oidc-vs-claves-estaticas]]
- [[caches-de-snowflake]]
