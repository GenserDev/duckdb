-- Ejercicio 5 y 8. Validacion de los anios incorporados.
-- Ninguna consulta menciona un anio concreto, todas descubren los anios desde los archivos.

-- name: archivos_por_anio
SELECT
    split_part(file_name, '/', 3) AS tipo_taxi,
    split_part(file_name, '/', 4) AS anio,
    count(*) AS archivos,
    min(regexp_extract(file_name, '(\d{4}-\d{2})\.parquet$', 1)) AS primer_mes,
    max(regexp_extract(file_name, '(\d{4}-\d{2})\.parquet$', 1)) AS ultimo_mes,
    sum(num_rows) AS registros
FROM parquet_file_metadata('data/raw/*/*/*.parquet')
GROUP BY ALL
ORDER BY tipo_taxi, anio;

-- name: conteo_metadatos_vs_datos
WITH metadatos AS (
    SELECT
        split_part(file_name, '/', 3) AS tipo_taxi,
        split_part(file_name, '/', 4)::INTEGER AS anio,
        sum(num_rows) AS registros_metadatos
    FROM parquet_file_metadata('data/raw/*/*/*.parquet')
    GROUP BY ALL
),
datos AS (
    SELECT tipo_taxi, anio_archivo AS anio, count(*) AS registros_vista
    FROM viajes
    GROUP BY ALL
)
SELECT m.*, d.registros_vista, m.registros_metadatos = d.registros_vista AS coincide
FROM metadatos m
JOIN datos d USING (tipo_taxi, anio)
ORDER BY tipo_taxi, anio;

-- name: columnas_por_anio
-- Solo muestra las columnas que no estan en todos los archivos de su tipo de taxi
WITH esquema AS (
    SELECT
        split_part(file_name, '/', 3) AS tipo_taxi,
        split_part(file_name, '/', 4) AS anio,
        file_name,
        name AS columna
    FROM parquet_schema('data/raw/*/*/*.parquet')
    WHERE name NOT IN ('schema', 'duckdb_schema')
),
total AS (
    SELECT tipo_taxi, count(DISTINCT file_name) AS archivos FROM esquema GROUP BY tipo_taxi
)
SELECT
    e.tipo_taxi,
    e.columna,
    count(DISTINCT e.file_name) AS archivos_con_columna,
    any_value(t.archivos) AS archivos_del_tipo,
    string_agg(DISTINCT e.anio, ', ' ORDER BY e.anio) AS anios_con_columna
FROM esquema e
JOIN total t USING (tipo_taxi)
GROUP BY e.tipo_taxi, e.columna
HAVING count(DISTINCT e.file_name) < any_value(t.archivos)
ORDER BY e.tipo_taxi, e.columna;

-- name: tipos_por_anio
SELECT
    split_part(file_name, '/', 4) AS anio,
    name AS columna,
    string_agg(DISTINCT type, ', ') AS tipo_fisico
FROM parquet_schema('data/raw/yellow/*/*.parquet')
WHERE name IN ('passenger_count', 'RatecodeID', 'payment_type', 'VendorID', 'PULocationID')
GROUP BY ALL
ORDER BY columna, anio;

-- name: consulta_conjunta_por_mes
-- PIVOT crea una columna por cada anio que exista, sin escribirlos en la consulta
PIVOT (
    SELECT tipo_taxi, mes_archivo AS mes, anio_archivo::VARCHAR AS anio
    FROM viajes_validos
)
ON anio
USING count(*)
GROUP BY tipo_taxi, mes
ORDER BY tipo_taxi, mes;

-- name: resumen_por_anio
SELECT
    tipo_taxi,
    anio_archivo AS anio,
    count(*) AS viajes_validos,
    round(median(trip_distance), 2) AS distancia_mediana,
    round(median(total_amount), 2) AS total_mediano,
    round(avg(coalesce(cbd_congestion_fee, 0)), 2) AS cargo_cbd_promedio
FROM viajes_validos
GROUP BY tipo_taxi, anio_archivo
ORDER BY tipo_taxi, anio;
