---
tipo: concepto
herramienta: sql
aliases: [sesionizacion, session id sql, retencion por cohortes, cohort retention, cohort analysis]
tags: [guia-entrevista, sql]
---
# Sesionización y retención por cohortes

> [!tip] Respuesta rápida
> **Sesionización**: agrupar eventos de un usuario en "sesiones" separadas por un hueco de inactividad (p. ej. 30 min) — mismo patrón que [[gaps-and-islands]] (`LAG` + bandera + suma acumulada), con el hueco medido en minutos en vez de días. **Retención por cohortes**: para cada cohorte (usuarios agrupados por su primera actividad), qué porcentaje sigue activo N periodos después — un *self-join* entre "primera actividad" y "actividad por periodo", normalizado por el tamaño de la cohorte.

## Definición

**Sesionización** resuelve la pregunta "¿qué eventos de un usuario pertenecen a la misma visita/sesión?". La regla de negocio típica es un umbral de inactividad: si pasan más de N minutos sin eventos, la sesión termina y el siguiente evento abre una nueva. Es exactamente el problema de *gaps & islands* aplicado a tiempo en vez de fechas de calendario — por eso se resuelve igual: una bandera de "aquí empieza algo nuevo" (hueco > N minutos desde el evento anterior, por `LAG`) y una suma acumulada de esa bandera como identificador de sesión.

**Retención por cohortes** resuelve una pregunta distinta: "de los usuarios que empezaron en el mes X (su cohorte), ¿qué porcentaje seguía activo 1, 2, 3... meses después?". No es un problema de islas — es comparar la fecha de **primera actividad** de cada usuario (que define su cohorte) contra su actividad en cada periodo posterior, y agregar por cohorte y por "periodo desde el inicio" (no por fecha de calendario absoluta, para poder comparar cohortes de distintos meses en igualdad de condiciones).

## Ejemplo mínimo — sesionización

```sql
with eventos as (
    select * from values
        ('u1', '2026-01-01 10:00'::timestamp),
        ('u1', '2026-01-01 10:20'::timestamp),
        ('u1', '2026-01-01 11:05'::timestamp),  -- > 30 min desde la anterior: sesión nueva
        ('u2', '2026-01-01 09:00'::timestamp)
    as t(user_id, event_ts)
),
flagged as (
    select
        user_id, event_ts,
        iff(
            lag(event_ts) over (partition by user_id order by event_ts) is null
            or datediff('minute', lag(event_ts) over (partition by user_id order by event_ts), event_ts) > 30,
            1, 0
        ) as starts_new_session
    from eventos
),
sessions as (
    select
        user_id, event_ts,
        sum(starts_new_session) over (partition by user_id order by event_ts) as session_id
    from flagged
)
select user_id, session_id, min(event_ts) as session_start, max(event_ts) as session_end, count(*) as n_events
from sessions
group by user_id, session_id
```

## Ejemplo mínimo — retención por cohortes

```sql
with primera_actividad as (
    select user_id, date_trunc('month', min(event_date)) as cohort_month
    from eventos
    group by user_id
),
actividad_mensual as (
    select distinct user_id, date_trunc('month', event_date) as activity_month
    from eventos
),
retencion as (
    select
        p.cohort_month,
        datediff('month', p.cohort_month, a.activity_month) as periodo,
        count(distinct a.user_id) as usuarios_activos
    from primera_actividad p
    join actividad_mensual a on p.user_id = a.user_id
    group by p.cohort_month, periodo
),
tamano_cohorte as (
    select cohort_month, count(*) as usuarios_cohorte
    from primera_actividad
    group by cohort_month
)
select
    r.cohort_month, r.periodo, r.usuarios_activos, t.usuarios_cohorte,
    round(r.usuarios_activos * 100.0 / t.usuarios_cohorte, 1) as pct_retencion
from retencion r
join tamano_cohorte t on r.cohort_month = t.cohort_month
order by r.cohort_month, r.periodo
```

## Errores típicos
- **Sesionización:** olvidar que la primera fila de cada usuario necesita la bandera en 1 explícitamente — `LAG` devuelve `NULL` y hay que tratarlo como "empieza sesión", no dejar que la condición se evalúe a `NULL`/falso.
- **Sesionización:** no particionar el `LAG`/la suma acumulada por `user_id` — sin eso, las sesiones de usuarios distintos se mezclan en una sola secuencia.
- **Retención:** medir actividad "acumulada" en vez de actividad distinta por periodo (contar un usuario como activo en el periodo 3 solo porque lo fue en el periodo 1, sin actividad real en el 3).
- **Retención:** dividir por los usuarios activos del periodo actual en vez de por el tamaño original de la cohorte (periodo 0) — infla la retención artificialmente.

## Pregunta probable
**¿Qué tienen en común sesionización y gaps & islands?** La misma estructura (`LAG` + bandera de cambio + suma acumulada); la única diferencia es qué define el "hueco" — días de calendario en gaps & islands, minutos de inactividad en sesionización.
**¿Y retención por cohortes, también es el mismo patrón?** No — ahí no hay huecos que detectar entre eventos consecutivos, es un *self-join* entre la primera actividad de cada usuario y su actividad en cada periodo posterior, con el periodo expresado como "meses desde el inicio" para poder comparar cohortes distintas.

## Aparece en
- Relacionados: [[gaps-and-islands]], [[funciones-de-ventana]]
