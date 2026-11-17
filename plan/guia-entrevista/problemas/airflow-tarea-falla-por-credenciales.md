---
tipo: problema
herramienta: airflow
prioridad: alta
aliases: [tarea falla al conectar con Snowflake, JWT token is invalid, error de credenciales airflow, snowflake_conn_id error, fallo autenticación key pair]
tags: [guia-entrevista, airflow]
---
# La tarea falla al conectar con Snowflake

> [!tip] Respuesta rápida
> Tres sospechosos en orden de probabilidad: `snowflake_conn_id` mal nombrado, permisos del fichero `.p8`, o fingerprint público/privado que no coincide (el clásico `JWT token is invalid`).

## Hipótesis (de más barata a más cara de comprobar)
1. **`snowflake_conn_id` mal nombrado o inexistente** → la conexión no existe en Airflow con ese nombre exacto.
2. **Permisos de la clave privada** → el usuario 50000 del contenedor no puede leer el `.p8` si está en modo 600 y pertenece a root.
3. **Fingerprint público/privado no coincide** → la clave privada usada no es la pareja de la pública registrada en el usuario de Snowflake.
4. **`user` del conector usa el `NAME` en vez del `LOGIN_NAME`** → caso real documentado en D1 (conectando dbt, no Airflow): `error_code = JWT_TOKEN_INVALID_USER_IN_ISSUER` en `LOGIN_HISTORY`, con clave y fingerprint ya verificados como correctos. Ver [[snowflake-jwt-token-invalid]] para el caso completo.

## Diagnóstico paso a paso
```bash
# 1. revisa el log de la tarea: suele decir exactamente qué falla
# (conn_id no encontrado / permission denied / JWT token is invalid)

# 2. reproduce la tarea de forma aislada
airflow tasks test <dag_id> <task_id> <fecha>

# 3. permisos del fichero de clave (sin imprimir su contenido)
ls -l /ruta/a/la/clave.p8

# 4. compara fingerprints SIN imprimir la clave privada
openssl rsa -pubout -in clave_privada.p8 | openssl sha256
# compara ese hash contra RSA_PUBLIC_KEY_FP:
```
```sql
desc user mi_usuario;
```
Si los dos fingerprints no coinciden, la clave pública registrada en Snowflake no corresponde a la privada que usa dbt/Airflow.

## Solución
- **`conn_id`**: corrige el nombre en el DAG o crea la conexión que falta en Airflow.
- **Permisos**: ajusta propietario/modo del fichero para que el usuario 50000 pueda leerlo (ej. `chown` al usuario del contenedor, o modo que permita lectura sin exponerlo de más).
- **Fingerprint distinto**: regenera el par de claves y actualiza la pública en Snowflake con `alter user ... set rsa_public_key = '...'`, o usa la clave correcta si simplemente se usó la antigua.

## Prevención
- Comprobar las conexiones en un entorno de staging antes de desplegar.
- Documentar el proceso de rotación de claves (cuál es la activa, cuándo caduca).
- Nunca imprimir ni la clave privada ni su contenido en logs; comparar solo fingerprints.

## Cómo contarlo
Si la tarea de Airflow falla al conectar con Snowflake, empiezo por el log de la tarea (casi siempre dice si es `conn_id` no encontrado, permisos del fichero, o un error de Snowflake). Si es de auth con clave, comparo primero `conn_id` y permisos del `.p8` (barato), y solo si sigue fallando paso a comparar fingerprints con `openssl`, sin imprimir la clave privada en ningún momento. Si el fingerprint coincide y aun así falla, no asumo que es la clave — reviso `LOGIN_HISTORY` por el `error_code` exacto, como me pasó en D1 con dbt (ver [[snowflake-jwt-token-invalid]]): ahí la clave era correcta y el problema era que el `user` configurado no coincidía con el `LOGIN_NAME` real. Lo prevengo documentando qué conexión/credencial usa cada proceso y verificando `NAME` vs `LOGIN_NAME` al dar de alta un usuario.

## Conceptos relacionados
- [[oidc-vs-claves-estaticas]]
- [[airflow-dag-no-aparece]]
- [[idempotencia-y-atomicidad]]
