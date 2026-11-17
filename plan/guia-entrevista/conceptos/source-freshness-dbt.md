---
tipo: concepto
herramienta: dbt
aliases: [source freshness, freshness de fuentes, loaded_at_field, warn_after error_after]
tags: [guia-entrevista, dbt]
---
# Source freshness en dbt

> [!tip] Respuesta rápida
> `dbt source freshness` compara el valor más reciente de `loaded_at_field` en una fuente contra el momento actual, y lo clasifica en OK/WARN/ERROR según los umbrales `warn_after`/`error_after`. Detecta cargas que dejaron de llegar, no si los datos cargados son correctos.

## Definición

`dbt source freshness` responde a una pregunta distinta de la que responde un test: no "¿son correctos los datos?", sino "¿llegaron a tiempo?". Mecánicamente, dbt lanza una query contra la fuente que pide el valor máximo de `loaded_at_field` (un timestamp de carga, no de negocio) y lo compara contra el momento actual. Según cuánto tiempo haya pasado, clasifica el resultado en `pass` (dentro de lo esperado), `warn_after` (empieza a tardar más de lo normal) o `error_after` (claramente algo dejó de cargar).

Esto solo tiene sentido para fuentes con una cadencia esperada de llegada — una carga única o un snapshot puntual no tiene "frescura" que medir, porque no se espera que vuelva a actualizarse. Los umbrales deben reflejar el patrón real de la fuente, no un valor genérico: una fuente que no publica fines de semana necesita umbrales en días, no en horas, o cada lunes dispararía un falso `WARN`. Relacionado con [[idempotencia-y-atomicidad]]: freshness detecta que una carga *no llegó*; idempotencia/atomicidad son las propiedades que hacen segura la carga *cuando sí llega*, incluso en un reintento.

## Ejemplo mínimo
```yaml
sources:
  - name: ecb
    loaded_at_field: loaded_at
    tables:
      - name: exchange_rates
        freshness:
          warn_after: {count: 3, period: day}
          error_after: {count: 5, period: day}
```
Esto es literal del repo (`_ecb__sources.yml`): el BCE no publica fines de semana ni festivos, por eso el umbral es en días y no en horas — hay que dar margen a esos huecos normales antes de avisar.

## Errores típicos
- Poner umbrales pensados para carga horaria en una fuente que solo se actualiza entre semana (dispara falsos WARN cada lunes/festivo).
- Olvidar que freshness necesita una columna de timestamp de carga real; si no existe, hay que crearla o inferirla.
- Confundir freshness (¿llegaron datos a tiempo?) con un test de calidad (¿los datos son correctos?).

## Pregunta probable
¿Por qué el dataset de hoteles no tiene freshness configurada? Porque es una carga única (snapshot puntual), no una fuente que se actualiza periódicamente; freshness solo tiene sentido cuando hay una cadencia esperada de llegada de datos.

## Aparece en
- [[dbt-source-freshness-en-rojo]]
- [[snapshot-timestamp-vs-check]]
- Relacionados: [[model-contracts-dbt]], [[idempotencia-y-atomicidad]]
