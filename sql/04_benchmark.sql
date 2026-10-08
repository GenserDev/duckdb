-- Ejercicio 6. Consultas del benchmark.
-- {fuente} se reemplaza por la vista sobre Parquet o por la tabla materializada,
-- asi ambas estrategias ejecutan exactamente el mismo SQL.

-- name: conteo_total
SELECT count(*) AS viajes FROM {fuente};

-- name: viajes_por_mes
SELECT tipo_taxi, anio_archivo, mes_archivo, count(*) AS viajes
FROM {fuente}
GROUP BY ALL
ORDER BY ALL;

-- name: viajes_por_hora_y_dia
SELECT tipo_taxi, isodow(inicio) AS dia_semana, hour(inicio) AS hora, count(*) AS viajes
FROM {fuente}
WHERE duracion_min BETWEEN 1 AND 180
GROUP BY ALL
ORDER BY ALL;

-- name: medianas_por_tipo
SELECT
    tipo_taxi,
    median(trip_distance) AS distancia_mediana,
    median(duracion_min) AS duracion_mediana,
    quantile_cont(total_amount, 0.9) AS total_p90
FROM {fuente}
WHERE trip_distance BETWEEN 0 AND 100 AND total_amount > 0
GROUP BY tipo_taxi;

-- name: top_zonas_con_join
SELECT z.zona, count(*) AS viajes, avg(v.total_amount) AS total_promedio
FROM {fuente} v
JOIN zonas z ON z.location_id = v.PULocationID
GROUP BY z.zona
ORDER BY viajes DESC
LIMIT 10;

-- name: filtro_selectivo
SELECT count(*) AS viajes, avg(total_amount) AS total_promedio, avg(tip_amount) AS propina_promedio
FROM {fuente}
WHERE PULocationID = 132 AND total_amount > 100 AND payment_type = 1;
