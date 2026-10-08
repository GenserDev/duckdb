# Lab 8 - DuckDB

CC3084 Data Science, Universidad del Valle de Guatemala, ciclo 2 de 2026.

Flujo reproducible para analizar los viajes de taxis amarillos y verdes de Nueva York (NYC TLC Trip Record Data) con DuckDB. Un script descarga los archivos Parquet mensuales directo de la fuente, DuckDB los consulta sin importarlos y el análisis se documenta en notebooks y en `docs/informe.md`. El repositorio parte de la base del docente (`menene/duckdb`).

## Cómo levantar el ambiente

**1. Clonar el repositorio y entrar a la carpeta**

```bash
git clone https://github.com/GenserDev/Lab8-DS.git && cd Lab8-DS
```

**2. Construir y levantar los contenedores**

```bash
docker compose up -d --build
```

**3. Verificar que los servicios respondan**

```bash
docker compose ps
```

JupyterLab queda en http://localhost:8888 (sin contraseña) y Metabase en http://localhost:3000.

## Cómo descargar los datos

**4. Descargar los archivos de la TLC**

```bash
docker compose exec lab python scripts/download_data.py
```

**5. Verificar que la descarga esté completa**

```bash
docker compose exec lab python scripts/download_data.py --verificar
```

Los archivos quedan en `data/raw/<tipo>/<anio>/`. Si se corre de nuevo, solo descarga los meses que falten o que la TLC haya publicado después.

La primera construcción descarga cerca de 3 GB de imágenes. Los datos de 2026 ocupan unos 500 MB.

## Cómo reproducir los benchmarks

**6. Crear la tabla materializada y correr el benchmark**

```bash
docker compose exec lab python scripts/materializar.py
docker compose exec lab python scripts/benchmark.py
```

El primero crea `data/processed/taxis.duckdb` y el segundo `data/processed/benchmark.duckdb` y escribe los tiempos en `docs/benchmark_resultados.csv`. Con los tres años tardan unos minutos y ocupan cerca de 8 GB en disco.
