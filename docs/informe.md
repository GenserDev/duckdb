# Informe del laboratorio 8

Respuestas a las preguntas de cada ejercicio. Las consultas SQL están en `sql/` y sus resultados en los notebooks de `notebooks/`, así que aquí solo se citan las cifras que sostienen cada respuesta.

## Estructura del proyecto

**`data/raw/`** guarda los archivos tal como los publica la TLC, en `data/raw/<tipo>/<anio>/`, más la tabla de zonas. Nunca se modifican.

**`data/processed/`** guarda lo que se deriva de los datos crudos, como la base DuckDB materializada del Ejercicio 6.

**`notebooks/`** contiene el análisis ejecutado, con resultados e interpretación.

**`scripts/`** tiene el código reutilizable: descarga, carga de consultas, materialización y benchmark.

**`sql/`** contiene todas las consultas con nombre. Es la fuente única del SQL, los notebooks lo cargan desde ahí.

**`docs/`** guarda este informe, la evidencia del tablero y las salidas de verificación.

**`Dockerfile`, `metabase.Dockerfile` y `docker-compose.yml`** definen el ambiente de Jupyter y el de Metabase.

Las dos carpetas de datos están en `.gitignore`, así que el repositorio solo versiona código y documentación.

## Ejercicio 1. Preparación del ambiente

**1.1 a 1.3.** El repositorio base (`menene/duckdb`) se copió a este repositorio y el ambiente se levantó con `docker compose up -d --build`. Los dos servicios funcionan. JupyterLab responde con código 200 en `http://localhost:8888` y Metabase responde en `/api/health` en `http://localhost:3000`.

**1.4 Herramientas disponibles.** El contenedor `lab` trae Python 3.11.14 con DuckDB 1.5.5, JupyterLab 4.6.4, pandas 3.0.6, pyarrow 25.0.1, matplotlib 3.11.2, requests 2.34.2, nbconvert y curl. No trae la consola `duckdb`, así que DuckDB se usa desde Python. El contenedor `metabase` corre Metabase v0.63.19 con el driver de DuckDB 1.5.5.0, que coincide con la versión de Python para que ambos lean el mismo archivo `.duckdb`. Los dos contenedores montan `data/` en `/workspace/data`.

**1.5.** El procedimiento está en el README, en la sección "Cómo levantar el ambiente".

**1.6 Por qué un ambiente reproducible.** Porque los resultados dependen de las versiones. DuckDB cambia la inferencia de tipos y las funciones entre versiones, y el driver de Metabase solo abre archivos de la misma versión de DuckDB que los creó. Con Docker cualquier integrante obtiene las mismas versiones con un comando, sin depender del Python de su máquina (en este equipo la máquina local tiene Python 3.9, que no puede instalar pandas 3).

## Ejercicio 2. Sistema de descarga

**2.1 Qué había que modificar.** El script original tenía el año fijo en la constante `ANIO = 2026`, y todas las funciones (`construir_nombre`, `construir_url`, `ruta_destino` y `descargar`) la leían directamente. Ya descargaba amarillos y verdes, consultaba qué meses estaban publicados y omitía archivos existentes, pero no permitía otro año ni verificar que lo descargado estuviera completo.

**2.2 a 2.6 Cambios realizados.**

**Varios años.** `ANIO` pasó a ser la tupla `ANIOS` y el año ahora es un parámetro de cada función. Se agregó la opción `--anio`, que acepta uno o varios años.

**Verificación.** Se agregó `--verificar`, que pide al servidor el tamaño de cada archivo publicado (petición `HEAD`, sin descargar) y lo compara con el archivo local.

**Tabla de zonas.** El script también descarga `taxi_zone_lookup.csv`, que traduce `PULocationID` y `DOLocationID` a nombres de zona y distrito.

**Lo que se conservó.** La estructura `data/raw/<tipo>/<anio>/`, la consulta de meses publicados, la descarga a un archivo `.part` que solo se renombra al terminar y la omisión de archivos que ya existen.

**2.5 Ejecución.** La primera corrida descargó 16 archivos, de enero a agosto de 2026 para cada tipo, y reportó septiembre a diciembre como no publicados. La segunda corrida no descargó nada y reportó los 16 como existentes.

**2.7 Cómo se determinó que está completo.** Con tres comprobaciones. Primero, `--verificar` encontró 0 archivos con problemas, porque los 16 tienen exactamente el tamaño que reporta el servidor (salida en `docs/verificacion_2026.txt`). Segundo, el script pide al servidor los 12 meses y solo faltan los que responden que no existen. Tercero, en el Ejercicio 3 DuckDB pudo leer los metadatos de los 16 archivos y la suma de `num_rows` coincide con el `count(*)` sobre los datos, lo que descarta archivos truncados.

## Ejercicio 3. Consultas directas sobre Parquet

El detalle de cada consulta (SQL, objetivo, archivos fuente, resultado y decisión) está en `notebooks/01_exploracion.ipynb` y el SQL en `sql/01_exploracion.sql`.

**3.1 y 3.2.** Hay 16 archivos y 30,040,469 registros, 29,703,355 amarillos y 337,114 verdes.

**3.3 y 3.4.** Los amarillos tienen 21 columnas y los verdes 22. Difieren en el prefijo de las fechas (`tpep_` y `lpep_`), en `Airport_fee` (solo amarillos) y en `ehail_fee` y `trip_type` (solo verdes). La columna `request_source` aparece solo en 3 de los 8 archivos de cada tipo, por eso todas las lecturas usan `union_by_name = true`.

**3.6 Problemas de calidad.** Los más importantes son los nulos en bloque (25.98 % de los amarillos sin pasajeros, tipo de tarifa ni forma de pago), fechas de 2001 y 2008, 371,683 viajes que terminan antes de empezar, distancias de hasta 328,522 millas y 161,835 montos negativos.

**Transformación registrada.** No se modifica ningún archivo. La limpieza vive en la vista `viajes_validos` de `sql/00_vistas.sql`, que conserva los viajes con fecha dentro del mes de su archivo, duración entre 1 y 180 minutos, distancia entre 0 y 100 millas, monto total positivo y tarifa no negativa. Conserva el 94.75 % de los amarillos y el 94.63 % de los verdes.

**3.9 Consultar directamente un Parquet.** Significa que DuckDB lee el archivo en su lugar sin importarlo antes. Como Parquet es columnar y guarda estadísticas por grupo de filas, DuckDB lee solo las columnas que pide la consulta y salta los grupos que no pasan los filtros. Con mucho volumen esto evita duplicar los datos en otra base y evita un paso de carga que habría que repetir con cada archivo nuevo. El conteo de 30 millones de filas por metadatos tardó milisegundos y el `SUMMARIZE` completo de los amarillos unos 16 segundos.

## Ejercicio 4. Análisis exploratorio

Las preguntas, consultas, gráficas e interpretación están en `notebooks/02_analisis_exploratorio.ipynb`, con el SQL en `sql/02_eda.sql`. Se ejecutó sobre 2026, con los filtros de `viajes_validos`.

**4.1 Preguntas.** Cómo cambia la demanda por mes, hora y día. Cómo es un viaje típico. Dónde operan amarillos y verdes. Cómo se paga y qué compone el cobro. Cómo se distribuye el monto y cuántos atípicos hay.

**4.5 Hallazgos.**

**Los verdes dependen de pocos barrios.** El 40.27 % de sus recogidas sale de East Harlem North y South. La zona más usada por los amarillos (Upper East Side South) solo concentra el 4.44 %, y el 86.75 % de sus viajes inicia en Manhattan.

**Un cuarto de los viajes amarillos no trae datos del taxímetro.** El 25.01 % de los viajes válidos de 2026 no tiene forma de pago, pasajeros ni tipo de tarifa.

**Los dos servicios tienen ritmos distintos.** El sábado es el día más fuerte de los amarillos, que mantienen actividad hasta medianoche. Los verdes caen 32 % del jueves al domingo y casi no operan de noche.

**La demanda baja en verano.** Los amarillos pasan de 125,810 viajes por día en mayo a 101,723 en agosto.

**El rango intercuartílico sobreestima los atípicos.** Marca el 8.47 % de los amarillos, pero buena parte son viajes al aeropuerto con tarifa fija (mediana de 97.15 dólares). Los atípicos claros, como velocidades mayores a 60 mph o propinas mayores que la tarifa, suman menos del 0.2 %.

## Ejercicio 5. Incorporación de 2024

El detalle está en `notebooks/03_incorporacion_2024.ipynb` y el SQL en `sql/03_incorporacion_anios.sql`.

**5.1 a 5.4.** El único cambio al sistema fue agregar 2024 a `ANIOS` en `scripts/download_data.py`. La ejecución descargó 24 archivos y omitió los 16 de 2026 porque ya existían (`docs/descarga_2024.txt`).

**5.5.** `--verificar` reporta 0 problemas en los 40 archivos y el conteo de la vista coincide con los metadatos en los cuatro grupos de tipo y año.

**5.6.** La consulta conjunta por mes funciona sobre los dos años. Entre enero y agosto los amarillos crecieron entre 6.4 % y 22.6 % de 2024 a 2026 y los verdes cayeron entre 17.9 % y 29.2 %.

**5.7.** No hubo que modificar ninguna consulta para que corriera. El esquema es igual salvo `cbd_congestion_fee` y `request_source`, que no existen en 2024 y quedan nulas gracias a `union_by_name`. Lo que cambia es la interpretación de las consultas que no agrupan por año, porque ahora mezclan 2024 y 2026. Cuando la pregunta es por año se agrega `anio_archivo` al `GROUP BY`.

**5.8.** Las consultas de validación son `archivos_por_anio`, `conteo_metadatos_vs_datos`, `columnas_por_anio`, `tipos_por_anio`, `consulta_conjunta_por_mes` y `resumen_por_anio`.

**5.9 Por qué no hubo que cambiar el flujo.**

**Rutas con comodines.** Las vistas leen `data/raw/<tipo>/*/*.parquet`, así que una carpeta nueva entra sola.

**Año tomado del archivo.** `anio_archivo` y `mes_archivo` se extraen del nombre del archivo, no de una lista escrita en el código.

**Esquema flexible.** `union_by_name = true` tolera columnas que aparecen o desaparecen entre años.

**Una sola definición.** Las vistas y la limpieza viven en `sql/00_vistas.sql`, y todos los notebooks las cargan desde ahí.

**Descarga parametrizada e idempotente.** El año es un parámetro y lo existente se omite, así que agregar un año es cambiar una línea y volver a correr el mismo comando.
