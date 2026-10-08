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
