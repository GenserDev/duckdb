-- Ejercicio 3. Exploracion inicial directa sobre los archivos Parquet.
-- Ninguna consulta importa datos a una tabla, todas leen data/raw.

-- name: archivos_disponibles
SELECT
    split_part(file_name, '/', 3) AS tipo_taxi,
    split_part(file_name, '/', 4) AS anio,
    count(*) AS archivos,
    sum(num_rows) AS registros,
    round(sum(file_size_bytes) / 1024 / 1024, 1) AS tamanio_mib
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY tipo_taxi, anio;

-- name: registros_por_archivo
SELECT
    split_part(file_name, '/', 5) AS archivo,
    num_rows AS registros,
    num_row_groups AS grupos_de_filas
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
ORDER BY archivo;

-- name: registros_totales
SELECT 'yellow' AS tipo_taxi, count(*) AS registros
FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true)
UNION ALL
SELECT 'green', count(*)
FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true);

-- name: columnas_yellow
DESCRIBE SELECT * FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true);

-- name: columnas_green
DESCRIBE SELECT * FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true);

-- name: columnas_por_archivo
SELECT
    split_part(file_name, '/', 3) AS tipo_taxi,
    name AS columna,
    string_agg(DISTINCT coalesce(logical_type::VARCHAR, type), ', ') AS tipos_fisicos,
    count(DISTINCT file_name) AS archivos_con_columna
FROM parquet_schema('data/raw/*/*/*.parquet')
WHERE name NOT IN ('schema', 'duckdb_schema')
GROUP BY ALL
ORDER BY tipo_taxi, columna;

-- name: muestra_yellow
SELECT *
FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true)
USING SAMPLE reservoir(5 ROWS) REPEATABLE (42);

-- name: muestra_green
SELECT *
FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true)
USING SAMPLE reservoir(5 ROWS) REPEATABLE (42);

-- name: resumen_yellow
SUMMARIZE SELECT * FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true);

-- name: resumen_green
SUMMARIZE SELECT * FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true);

-- name: problemas_calidad
WITH base AS (
    SELECT 'yellow' AS tipo_taxi, tpep_pickup_datetime AS inicio, tpep_dropoff_datetime AS fin,
           passenger_count, trip_distance, fare_amount, total_amount, RatecodeID, payment_type,
           filename
    FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true, filename = true)
    UNION ALL
    SELECT 'green', lpep_pickup_datetime, lpep_dropoff_datetime,
           passenger_count, trip_distance, fare_amount, total_amount, RatecodeID, payment_type,
           filename
    FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true, filename = true)
)
SELECT
    tipo_taxi,
    count(*) AS registros,
    count(*) FILTER (WHERE passenger_count IS NULL) AS pasajeros_nulos,
    count(*) FILTER (WHERE passenger_count = 0) AS pasajeros_cero,
    count(*) FILTER (WHERE trip_distance = 0) AS distancia_cero,
    count(*) FILTER (WHERE trip_distance > 100) AS distancia_mayor_100mi,
    count(*) FILTER (WHERE fare_amount < 0) AS tarifa_negativa,
    count(*) FILTER (WHERE total_amount < 0) AS total_negativo,
    count(*) FILTER (WHERE fin <= inicio) AS fin_antes_de_inicio,
    count(*) FILTER (WHERE date_diff('hour', inicio, fin) > 24) AS duracion_mayor_24h,
    count(*) FILTER (WHERE strftime(inicio, '%Y-%m') <> regexp_extract(filename, '(\d{4}-\d{2})\.parquet$', 1))
        AS fecha_fuera_del_mes_del_archivo,
    count(*) FILTER (WHERE RatecodeID = 99 OR RatecodeID IS NULL) AS ratecode_desconocido,
    count(*) FILTER (WHERE payment_type = 0) AS pago_tipo_cero
FROM base
GROUP BY tipo_taxi
ORDER BY tipo_taxi;

-- name: fechas_fuera_de_rango
SELECT
    'yellow' AS tipo_taxi,
    min(tpep_pickup_datetime) AS inicio_minimo,
    max(tpep_pickup_datetime) AS inicio_maximo
FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true)
UNION ALL
SELECT 'green', min(lpep_pickup_datetime), max(lpep_pickup_datetime)
FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true);

-- name: nulos_por_archivo
SELECT
    regexp_extract(filename, '([a-z]+_tripdata_\d{4}-\d{2})', 1) AS archivo,
    count(*) AS registros,
    round(100.0 * count(*) FILTER (WHERE passenger_count IS NULL) / count(*), 2) AS pct_pasajeros_nulos
FROM read_parquet('data/raw/*/*/*.parquet', union_by_name = true, filename = true)
GROUP BY archivo
ORDER BY archivo;
