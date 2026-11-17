---
tipo: concepto
herramienta: sql
aliases: [scd tipo 2, scd type 2, merge slowly changing dimension, valid_from valid_to, dimensión historizada]
tags: [guia-entrevista, sql]
---
# SCD tipo 2 con MERGE

> [!tip] Respuesta rápida
> Un SCD tipo 2 guarda el histórico de una dimensión con `valid_from`, `valid_to` e `is_current`. Un único `MERGE` no puede cerrar la fila vieja e insertar la nueva para la misma clave en la misma pasada: se resuelve con una tabla de cambios que duplica la clave (una fila "close", otra "open").

## Definición

Una **dimensión de cambio lento** (*slowly changing dimension*) es una tabla de dimensión cuyos atributos cambian ocasionalmente (p. ej. la comisión de un canal), y hay que decidir qué hacer con el valor anterior cuando llega uno nuevo. **Tipo 1** sobrescribe sin más (pierdes el histórico). **Tipo 2** conserva cada versión como una fila distinta, con `valid_from`/`valid_to`/`is_current` marcando qué fila estuvo vigente en cada momento — así una query histórica (`join` por fecha contra la dimensión) usa el valor que era correcto *en ese momento*, no el actual. **Tipo 3** guarda solo el valor anterior en una columna extra (un histórico muy limitado, sin usar casi nunca).

El motivo técnico de por qué un único `MERGE` no basta para tipo 2: la misma clave de negocio (`channel`) necesita dos operaciones distintas en la misma pasada — *cerrar* la fila vigente anterior (`UPDATE valid_to`/`is_current=false`) e *insertar* la fila nueva (`is_current=true`) — y un `MERGE` solo puede emparejar una fila objetivo con una fila origen por clave de join. Se resuelve generando de antemano una tabla de cambios con **dos filas por cambio** (una marcada "close" que empareja con la fila existente, otra "open" que no empareja con nada y fuerza el `INSERT`).

## Ejemplo mínimo
```sql
merge into dim_channel_commission as tgt
using changes as src           -- una fila 'close' (clave original) + una 'open' por cada cambio
on tgt.channel = src.channel and tgt.is_current
when matched and src.action = 'close' then
    update set valid_to = src.effective_date, is_current = false
when not matched then
    insert (channel, commission_pct, valid_from, valid_to, is_current)
    values (src.channel, src.commission_pct, src.effective_date, null, true)
```

## Cómo hacerlo idempotente: calcular los cambios comparando contra lo vigente

El error más fácil de cometer (y el que más tarda en notarse): construir la fuente de cambios como una lista fija de "esto es lo nuevo", en vez de **calcularla comparando contra el estado actual**. Si la fuente no comprueba qué hay ya vigente, cada ejecución repite el mismo `close`+`open` aunque no haya cambiado nada — genera historial falso, y en claves sin una fila `close` correspondiente (p. ej. una entidad que solo tiene `open`), duplica filas `is_current = true` para la misma clave en cada ejecución, rompiendo la invariante de SCD2 (como mucho una vigente por clave).

La fuente correcta separa "la nueva información que llega" de "qué cambió de verdad":
```sql
with nuevo as (
    select 'clave_x' as clave, 'valor_nuevo' as atributo
),
actual as (
    select * from dimension where is_current = true
)
-- close: solo si había una fila vigente Y es distinta de la nueva
select 'close' as accion, actual.clave, null as atributo, current_timestamp() as evento
from nuevo join actual on nuevo.clave = actual.clave
where actual.atributo != nuevo.atributo

union all

-- open: alta (no había vigente) o cambio real (vigente distinta de la nueva)
select 'open', nuevo.clave, nuevo.atributo, current_timestamp()
from nuevo left join actual on nuevo.clave = actual.clave
where actual.clave is null or actual.atributo != nuevo.atributo
```
Si lo nuevo ya coincide con lo vigente, ninguna de las dos consultas genera fila para esa clave — repetir la carga no inserta ni actualiza nada.

## Errores típicos
- Hacerlo con `UPDATE` + `INSERT` en dos pasos sin transacción: una ejecución a medias deja el histórico roto.
- **No comprobar idempotencia de verdad** (`travel-dwh-lab`, D4-04): una fuente de cambios fija (sin comparar contra lo vigente) repite el mismo `close`+`open` en cada ejecución — para una clave sin fila `close` (p. ej. una alta), esto duplica filas `is_current = true` para la misma clave en cada repetición. Se comprobó ejecutando la carga dos veces seguidas y viendo crecer la tabla; se arregló calculando los cambios por comparación (ver arriba).
- **`WITH` (CTE) delante de `MERGE`**: Snowflake no lo permite directamente (sí delante de `SELECT`). La CTE con la fuente de cambios tiene que ir como subconsulta inline dentro del `USING`, no como un `WITH` que precede al `MERGE`.
- **Desajuste de valores en la clave del `ON`** (p. ej. `'city'` en la fuente de cambios contra `'City Hotel'` guardado en la tabla): si la fila `close` no encuentra coincidencia por un desajuste de texto, cae en `NOT MATCHED` e intenta **insertarse** — y si lleva columnas a `NULL` (porque solo estaba pensada para cerrar, no para insertarse), revienta cualquier `NOT NULL` de esas columnas. Señal de alarma: un error de `NULL result in a non-nullable column` en un `MERGE` que debería estar actualizando, no insertando.
- Depender solo de `valid_to is null` sin `is_current`: funciona, pero `is_current` hace los filtros más legibles y rápidos.

## Pregunta probable
**¿En qué se diferencia de un snapshot de dbt?** El snapshot de dbt genera el mismo patrón automáticamente a partir de una tabla de origen (estrategia `timestamp` o `check`); el `MERGE` manual es el mecanismo que hay debajo, útil sin dbt o con control fino.

## Aparece en
- Relacionados: [[snapshot-timestamp-vs-check]], [[funciones-de-ventana]]
