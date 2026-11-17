---
tipo: concepto
herramienta: snowflake
aliases: [query profile, profile overview, percentage scanned from cache, bytes spilled, diagnóstico de queries lentas, estadísticas del query profile, remote disk io, local disk io]
tags: [guia-entrevista, snowflake]
---
# Query Profile: métricas, hipótesis y solución

> [!tip] Respuesta rápida
> El Query Profile tiene dos paneles distintos: el **árbol de operadores** (qué nodo del plan consume más % de tiempo) y el panel de **estadísticas** (poda, caché, spilling, desglose de tiempo por categoría). Cruzando ambos localizas la causa real antes de tocar nada de infraestructura — diagnosticar primero, escalar después.

## Definición

El árbol de operadores te dice **dónde** se va el tiempo (`TableScan`, `Join`, `Aggregate`...). El panel de estadísticas te dice **por qué** ese operador es costoso — son complementarios, no sustitutos. Las estadísticas más relevantes, verificadas empíricamente (no solo de memoria):

- **Particiones escaneadas vs totales**: mide la poda — cuántos [[micro-particiones-y-clustering-keys|bloques]] tuvo que leer el optimizador.
- **Bytes scanned**: volumen real leído, útil para comparar entre ejecuciones.
- **Percentage scanned from cache**: de los bytes leídos, cuántos vinieron de la caché de disco local del warehouse en vez de storage remoto. **No es lo mismo que la caché de resultados** (`bytes_scanned = 0`, D2-02) — aquí sí hay una lectura real (`bytes_scanned > 0`), solo que más rápida por venir de SSD local.
- **Desglose general de tiempo** (Processing / Local Disk I/O / Remote Disk I/O / Initialization / Synchronization / Network): a qué categoría se fue el tiempo total.
- **Bytes spilled to local/remote storage**: memoria insuficiente para un operador (join/aggregate/sort), ver [[escalar-warehouse-arriba-vs-fuera]].

## Mapa de métricas → hipótesis → solución

**1. Particiones escaneadas ≈ totales (poda nula o pobre) + Remote Disk I/O dominante en el desglose general.**
Hipótesis: filtro ausente, filtro no sargable (función/conversión de tipo envolviendo la columna), o la columna de filtro no correlaciona con el orden de inserción de los datos.
Solución: reescribir el filtro con el tipo nativo de la columna; si el patrón de filtro es estable y la tabla es grande, considerar una *clustering key*.
Verificado en vivo: `TPCH_SF10.LINEITEM` sin filtro → 116/116 particiones, 1,7GB escaneados, ~90% Remote Disk I/O. Con `WHERE l_orderkey BETWEEN...` → 1/116 partición, 2,2MB (la columna sí correlaciona con el orden de carga; `l_shipdate`, en cambio, no — visto en D2-02).

**2. `Percentage scanned from cache` bajo (cerca de 0%) incluso en ejecuciones repetidas inmediatas sobre un volumen grande.**
Hipótesis: el volumen escaneado excede la capacidad de caché local disponible para el tamaño de warehouse actual — el caché local no es "todo o nada", si el dataset no cabe, el beneficio de relecturas no se nota aunque la teoría diga que debería.
Solución: si el patrón de acceso es recurrente y crítico, un warehouse más grande (más capacidad de caché local) puede ayudar más por esta vía que por CPU bruta; o reducir el volumen por consulta (filtrar más, incremental en vez de full-scan).
Verificado en vivo: mismo query sin filtro (116 particiones, 1,7GB) relanzado inmediatamente después (sin auto-suspend de por medio) → `percentage scanned from cache` sigue bajo, sin mejora observable. La misma prueba con un volumen pequeño (1 partición, 2MB) sí mostró `100.00%` en la segunda ejecución, con el tiempo cayendo de 679ms a 164ms.

**3. Bytes spilled to local/remote storage > 0.**
Qué es: no es un problema de caché de datos de origen — es que la **RAM** necesaria para una operación en curso (buffer de `ORDER BY`, tabla hash de un `JOIN`, estado de un `GROUP BY`) no cabe, y se escribe a disco. Primero intenta disco local; si tampoco basta, va a storage remoto (mucho más lento, por red) — es el peor caso.
Hipótesis: warehouse insuficiente en memoria para el volumen intermedio de esa operación concreta.
Solución matizada por la prueba en vivo: escalar arriba **ayuda pero no garantiza eliminar** el spilling de un escalón al siguiente — mitiga el impacto en tiempo total (más nodos en paralelo), pero el volumen derramado puede apenas cambiar si la operación es grande de verdad. La solución más fiable suele ser **reducir el volumen intermedio en la query** (un `LIMIT` si solo hace falta el top-N, filtrar antes de ordenar/agrupar) en vez de asumir que un escalón de tamaño basta.
Verificado en vivo: `ORDER BY` sobre ~60M filas de `TPCH_SF10.LINEITEM` sin filtro, en `dev_wh`:
- XS: 13s totales, 558,23MB derramados a disco local.
- MEDIUM (4x créditos/hora): 4s totales (4x más rápido), pero 549,57MB derramados — **prácticamente el mismo volumen**, el escalón de tamaño no eliminó el spilling, solo aceleró el procesamiento alrededor de él.

**4. El operador `Join` produce muchas más filas que las que entran por el lado izquierdo.**
Qué es: [[fan-out-en-joins|fan-out]] — el lado derecho del join tiene varias filas por clave, y cada fila izquierda se multiplica por sus coincidencias.
Hipótesis: el join es genuinamente 1:N (como pedido→líneas) pero se esperaba 1:1, o falta una columna que acote la relación.
Solución: agregar el lado "muchos" a la granularidad deseada **antes** del join (CTE), en vez de unir en bruto y agregar después.
Verificado en vivo: `ORDERS` (15.000 filas, lado izquierdo) `JOIN` `LINEITEM` por `o_orderkey = l_orderkey` → el operador `Join` produce 60.180 filas — una media de ~4 líneas por pedido (el ratio típico de TPC-H). Agregando `LINEITEM` por `l_orderkey` en una CTE antes de unir, el join vuelve a ser 1:1 (15.000 filas de entrada, 15.000 de salida).

## Errores típicos
- Mirar solo el árbol de operadores y nunca el panel de estadísticas (o viceversa) — hace falta cruzar ambos.
- Confundir `percentage scanned from cache` (caché de disco local, ejecución real) con la caché de resultados (`bytes_scanned = 0`, ni siquiera ejecuta) — son mecanismos de caché en capas distintas.
- Asumir que relanzar la misma query siempre se beneficia de caché local sin comprobar si el volumen cabe en la capacidad de ese warehouse.
- Olvidar que un `AUTO_SUSPEND` agresivo borra la caché local entre pruebas si pasa tiempo de inactividad entre una ejecución y la siguiente — invalida cualquier comparación "antes/después" si no se controla.

## Pregunta probable
**¿Cómo distingues si una query lenta es un problema de lectura (poda/caché) o de recursos del warehouse (spilling)?** Mirando la sección de *spilling*: si hay bytes derramados a disco, es un problema de memoria/recursos (escalar arriba ayuda). Si no hay spilling pero domina el Remote Disk I/O con poda pobre, es un problema de qué/cómo se lee (más CPU no ayuda; hace falta mejor filtro o clustering).

## Aparece en
- [[snowflake-query-lenta]]
- [[escalar-warehouse-arriba-vs-fuera]]
- Relacionados: [[micro-particiones-y-clustering-keys]], [[caches-de-snowflake]], [[multi-cluster-warehouses]]
