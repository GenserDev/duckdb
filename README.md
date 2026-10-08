# Lab 8 - DuckDB

CC3084 Data Science, Universidad del Valle de Guatemala, ciclo 2 de 2026.

Flujo reproducible para analizar los viajes de taxis amarillos y verdes de Nueva York de 2024, 2025 y 2026 (NYC TLC Trip Record Data, 121 millones de registros) con DuckDB. Un script descarga los Parquet mensuales desde la fuente, DuckDB los consulta sin importarlos, se compara contra una tabla materializada y los indicadores se publican en un tablero de Metabase. Las respuestas de cada ejercicio están en [docs/informe.md](docs/informe.md).

## Cómo levantar el ambiente

**1. Clonar el repositorio y entrar a la carpeta**

```bash
git clone https://github.com/GenserDev/duckdb.git && cd duckdb
```

**2. Construir y levantar los contenedores**

```bash
docker compose up -d --build
```

JupyterLab queda en http://localhost:8888 (sin contraseña) y Metabase en http://localhost:3000.

## Cómo descargar los datos

**3. Descargar y verificar los archivos de la TLC**

```bash
docker compose exec lab python scripts/download_data.py
```

```bash
docker compose exec lab python scripts/download_data.py --verificar
```

Los años salen de `ANIOS` en `scripts/download_data.py` (o de `--anio`). Lo que ya existe no se vuelve a descargar.

## Cómo ejecutar el análisis

**4. Abrir los notebooks en JupyterLab y ejecutarlos en orden**

| Notebook | Ejercicio |
|---|---|
| `notebooks/01_exploracion.ipynb` | 3, consultas directas sobre Parquet |
| `notebooks/02_analisis_exploratorio.ipynb` | 4, análisis exploratorio |
| `notebooks/03_incorporacion_2024.ipynb` | 5, incorporación de 2024 |
| `notebooks/04_benchmark.ipynb` | 6, Parquet contra tabla DuckDB |
| `notebooks/05_indicadores_y_evolucion.ipynb` | 7 y 8, indicadores y análisis 2024 a 2026 |

Todo el SQL vive en `sql/` con un nombre por consulta, y los notebooks lo cargan con `scripts/consultas.py`. Las vistas y la limpieza están en `sql/00_vistas.sql`.

## Cómo reproducir los benchmarks

**5. Crear la tabla materializada y correr el benchmark**

```bash
docker compose exec lab python scripts/materializar.py
```

```bash
docker compose exec lab python scripts/benchmark.py
```

El primero crea `data/processed/taxis.duckdb` y el segundo escribe los tiempos en `docs/benchmark_resultados.csv`, que lee el notebook 04.

## Cómo generar los resultados principales

**6. Crear el tablero de Metabase**

```bash
MB_EMAIL=correo@ejemplo.com MB_PASSWORD=una-clave-segura1 docker compose exec -e MB_EMAIL -e MB_PASSWORD lab python scripts/tablero_metabase.py
```

Si Metabase es nuevo, el script crea la cuenta de administrador con ese correo y clave. Luego conecta `taxis.duckdb` en solo lectura, crea una pregunta SQL por indicador y el tablero, e imprime el enlace. La captura del tablero está en `docs/tablero/tablero_metabase.png`.

**Notas.** Los datos de los tres años ocupan 2 GB, `taxis.duckdb` 4 GB y `benchmark.duckdb` unos 3.5 GB, así que conviene tener 15 GB libres además de los 3 GB de imágenes. Hay que correr `materializar.py` antes del tablero y volver a correrlo cada vez que se descarguen datos nuevos. Los notebooks 01 y 02 se ejecutaron solo con 2026 y el 03 con 2024 y 2026, así que sus cifras cambian si se ejecutan con los tres años.
