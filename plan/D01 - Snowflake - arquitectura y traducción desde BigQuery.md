---
tipo: epica
dia: 1
estado: confirmado
tags: [plan-10-dias, snowflake, bigquery]
aliases: [D1, Día 1]
---

# ÉPICA D1 — Snowflake: arquitectura y traducción desde BigQuery

← [[00 - Plan 10 días (índice)|Índice]] · Siguiente: [[D02 - Snowflake - operación, monitorización y decisiones|Día 2]] →

**Objetivo del día:** tener la cuenta de Snowflake configurada como en producción (roles, warehouses, usuarios de servicio) y poder explicar en qué se diferencia de BigQuery.

**DoD de la épica:** todos los tickets en *Done*.

---

## D1-01 · Cuenta de Snowflake operativa
**Tipo:** Tarea

**Definition of Done**
- [ ] Cuenta de prueba creada en una región europea, por ejemplo AWS `eu-central-1` (Frankfurt).
- [ ] Entras en Snowsight y ves los créditos de prueba disponibles.
- [ ] Identificador de cuenta (`<org>-<cuenta>`) anotado en el gestor de contraseñas.

## D1-02 · Claves de los usuarios de servicio
**Tipo:** Tarea

**Definition of Done**
- [ ] Pares de claves generados para `svc_airflow`, `svc_ci` y el usuario personal.
- [ ] Ningún `.p8` aparece en `git status`.
- [ ] Claves privadas guardadas también en el gestor de contraseñas: sin ellas se pierde el acceso de los usuarios de servicio.

## D1-03 · RBAC, warehouses y bases de datos (`setup.sql`)
**Tipo:** Tarea

**Definition of Done**
- [ ] `setup.sql` ejecutado sin errores.
- [ ] Existen los roles `loader`, `transformer` y `developer`.
- [ ] Existen tres warehouses XS con `auto_suspend = 60`, asignados al *resource monitor* `lab_monthly_monitor`.
- [ ] Existen las bases `raw`, `analytics` y `analytics_dev`, y los esquemas `raw.hotel_bookings` y `raw.ecb`.
- [ ] `desc user` muestra `RSA_PUBLIC_KEY_FP` con valor en los dos usuarios de servicio.
- [ ] El usuario personal tiene el rol `developer` y su clave pública asociada.

Consultas de comprobación:

```sql
show roles like '%er';
show warehouses;
show resource monitors;
show schemas in database raw;
desc user svc_airflow;
desc user svc_ci;
show grants to user svc_airflow;
show grants to user svc_ci;
```

## D1-04 · Conexión desde dbt con clave
**Tipo:** Tarea

**Definition of Done**
- [ ] `dbt debug` desde el portátil termina con *All checks passed!*, con el usuario personal y el target `dev`.
- [ ] Sabes explicar por qué el perfil fija el rol por target en lugar de leerlo de una variable de entorno.

## D1-05 · Arquitectura de tres capas
**Tipo:** Estudio

**DoD:** respondes en voz alta, sin mirar notas:

  1. ¿Cuáles son las tres capas de Snowflake y qué hace cada una en un
  SELECT?

  2. ¿Cómo consultan dos equipos la misma tabla sin competir por recursos?

  3. ¿Qué son las micro-particiones y en qué se diferencian del
  particionado de BigQuery?

  4. (Bonus) Dos equipos hacen UPDATE a la vez sobre la misma tabla: ¿qué
  pasa?

## D1-06 · Modelo de coste
**Tipo:** Estudio

**DoD:** respondes en voz alta, sin mirar notas:
1. «Vienes de BigQuery: ¿qué es lo primero que cambiarías en tu forma de
  pensar los costes?»

2. Una query tarda 30s en un warehouse XS. ¿Y si en un M tarda 8s? ¿Cuál
  es más barato?

3. Si un warehouse se queda encendido sin consultas, ¿pagas? ¿Qué lo
  evita?

## D1-07 · Tabla de equivalencias BigQuery → Snowflake
**Tipo:** Estudio

**Definition of Done**
- [ ] Reproduces de memoria las siete filas de la tabla.
- [ ] Explicas un matiz en al menos tres filas (por ejemplo: qué añade Fail-safe sobre Time Travel, o en qué se diferencia el clonado *zero-copy* de un snapshot de BigQuery).

Tabla de referencia (para repasar, no para mirar durante la evaluación):

| BigQuery | Snowflake |
|---|---|
| Project / Dataset | Database / Schema |
| Slots / on-demand | Virtual warehouses (XS–6XL, multi-cluster) |
| Partitioning + clustering | Micro-partitions automáticas + clustering keys |
| Time travel (7 días) | Time Travel (configurable) + Fail-safe |
| Table snapshots / clones | Zero-copy cloning |
| `INFORMATION_SCHEMA.JOBS` | `ACCOUNT_USAGE.QUERY_HISTORY` |
| IAM | RBAC con roles jerárquicos |
---
