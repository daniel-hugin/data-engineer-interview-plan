---
tipo: concepto
herramienta: snowflake
aliases: [data sharing snowflake, snowflake marketplace, secure data sharing, reader account, direct share, listing, secure views compartidas]
tags: [guia-entrevista, snowflake]
---
# Data Sharing y Snowflake Marketplace

> [!tip] Respuesta rápida
> **Data Sharing**: una cuenta de Snowflake concede acceso de solo lectura a datos a otra cuenta, sin copiar nada — el consumidor lee directamente del storage del proveedor. **Marketplace**: el catálogo público de esos *shares*; en vez de construir tú el pipeline de ingesta, "obtienes" un listing y aparece como una base de datos más en tu cuenta.

## Definición

Data Sharing usa el mismo principio que el [[time-travel-fail-safe-zero-copy-cloning|zero-copy cloning]], pero cruzando la frontera de una cuenta: en vez de copiar datos, el proveedor crea un objeto `SHARE`, le concede privilegios (`usage`/`select`) sobre bases, esquemas, tablas o — más habitual — **secure views**, y añade una o más cuentas consumidoras al share. La cuenta consumidora ejecuta `CREATE DATABASE ... FROM SHARE`, y a partir de ahí ve esa base de datos como una más, de solo lectura, siempre reflejando el estado actual del proveedor (porque literalmente apunta a las mismas micro-particiones, vía la arquitectura de storage compartido de Snowflake). No hay ETL, ni API, ni fichero de por medio, ni coste de storage duplicado en el consumidor — el proveedor sigue pagando el almacenamiento, el consumidor paga el cómputo que gasta al consultarlo.

Se comparten **secure views** y no tablas en bruto casi siempre, por dos motivos: controlar exactamente qué columnas/filas ve el consumidor (ocultar PII, limitar a una región), y porque una secure view también oculta su propia definición SQL al consumidor — no puede ver cómo se construye el dato, solo el resultado. Si el consumidor no tiene cuenta propia de Snowflake, el proveedor puede crearle una **Reader Account**: una cuenta ligera, gestionada y pagada por el proveedor, que le permite consultar el share con SQL normal sin que el consumidor necesite su propia suscripción.

**Snowflake Marketplace** es la capa de descubrimiento sobre este mecanismo: los proveedores publican sus shares como **Listings** (públicos o privados), con descripción, muestra de datos y precio (gratis o de pago). Un consumidor navega el catálogo y pulsa "Get" — para un listing gratuito, Snowflake provisiona la base de datos compartida en su cuenta al instante, sin SQL manual; para uno de pago, hay un flujo de aprobación/contratación antes de que se materialice el acceso. El Marketplace incluye datasets gratuitos (indicadores económicos, clima, demografía — podría existir ya un listing que republique tipos de cambio del BCE o similares) y también **Snowflake Native Apps**: lógica de aplicación empaquetada y distribuida vía Marketplace, que se ejecuta dentro de la cuenta del consumidor sin que sus datos salgan de ella.

La diferencia de fondo frente a cualquier integración tradicional (API, fichero, réplica): no hay proceso de sincronización que pueda fallar o atrasarse — el consumidor ve el dato más reciente en el instante en que el proveedor lo confirma, sujeto a la visibilidad transaccional normal de Snowflake, porque el cómputo del consumidor lee directamente del mismo storage.

## Ejemplo mínimo
```sql
-- Lado proveedor: crear el share y conceder acceso a una secure view
create share ecb_rates_share;
grant usage on database raw to share ecb_rates_share;
grant usage on schema raw.ecb to share ecb_rates_share;
grant select on raw.ecb.exchange_rates_secure_vw to share ecb_rates_share;
alter share ecb_rates_share add accounts = ('CONSUMER_ACCOUNT_LOCATOR');

-- Lado consumidor: crear una base de datos a partir del share recibido
create database ecb_rates_shared from share PROVEEDOR_ACCOUNT.ecb_rates_share;
select * from ecb_rates_shared.ecb.exchange_rates_secure_vw;
```
Desde Marketplace, el lado consumidor se reduce a pulsar "Get" en Snowsight — Snowflake crea esa base de datos por ti, sin escribir ningún `CREATE DATABASE FROM SHARE` a mano.

## Errores típicos
- Pensar que Data Sharing copia datos al consumidor: no copia nada, lee directamente del storage del proveedor; no hay coste de storage duplicado.
- Compartir tablas en bruto en vez de secure views: expone columnas/filas de más, o revela la lógica interna de cómo se construyó el dato.
- Asumir que un listing de pago se activa igual que uno gratuito con un solo clic: los listings comerciales suelen requerir un flujo de aprobación/contratación antes de dar acceso real.
- Olvidar que un consumidor sin cuenta propia de Snowflake necesita una Reader Account creada (y pagada) por el proveedor para poder consultar el share.

## Pregunta probable
**¿Cómo cambiaría el pipeline del BCE si los tipos de cambio llegaran por Marketplace en vez de por API?** La extracción (llamada HTTP + parsing en Python) desaparecería: el "raw" del BCE ya sería una base de datos compartida dentro de la propia cuenta. La transformación podría hacerse entonces con [[streams-tasks-vs-dynamic-tables|Streams+Tasks o Dynamic Tables]] en SQL puro, sin necesitar Airflow para esa parte — solo haría falta si el resto del pipeline (orquestar `dbt build`, alertas, dependencias cruzadas) sigue necesitando una orquestación más amplia que una Task de Snowflake no cubre.

## Aparece en
- [[copy-into-vs-snowpipe-vs-snowpipe-streaming]]
- Relacionados: [[streams-tasks-vs-dynamic-tables]], [[time-travel-fail-safe-zero-copy-cloning]]
