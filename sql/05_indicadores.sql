-- Ejercicios 7 y 8. Indicadores del tablero.
-- Usan solo viajes_validos y zonas, que existen como vistas sobre Parquet (sql/00_vistas.sql)
-- y dentro de data/processed/taxis.duckdb, asi el mismo SQL sirve en los notebooks y en Metabase.

-- name: i1_viajes_por_dia
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS mes,
    tipo_taxi,
    round(count(*) / any_value(day(last_day(inicio::DATE))), 0) AS viajes_por_dia
FROM viajes_validos
GROUP BY anio_archivo, mes_archivo, tipo_taxi
ORDER BY mes, tipo_taxi;

-- name: i2_participacion_verdes
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS mes,
    round(100.0 * count(*) FILTER (WHERE tipo_taxi = 'green') / count(*), 2) AS pct_verdes
FROM viajes_validos
GROUP BY anio_archivo, mes_archivo
ORDER BY mes;

-- name: i3_total_mediano
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS mes,
    tipo_taxi,
    round(median(total_amount), 2) AS total_mediano_usd,
    round(median(total_amount / trip_distance) FILTER (WHERE trip_distance >= 0.5), 2) AS usd_por_milla
FROM viajes_validos
GROUP BY anio_archivo, mes_archivo, tipo_taxi
ORDER BY mes, tipo_taxi;

-- name: i4_peso_de_recargos
SELECT
    anio_archivo::VARCHAR AS anio,
    tipo_taxi,
    round(100 * sum(fare_amount) / sum(total_amount), 1) AS pct_tarifa,
    round(100 * sum(tip_amount) / sum(total_amount), 1) AS pct_propina,
    round(100 * sum(tolls_amount) / sum(total_amount), 1) AS pct_peajes,
    round(100 * sum(coalesce(congestion_surcharge, 0) + coalesce(cbd_congestion_fee, 0)) / sum(total_amount), 1) AS pct_congestion,
    round(100 * sum(coalesce(airport_fee, 0) + extra + mta_tax + improvement_surcharge) / sum(total_amount), 1) AS pct_otros_recargos
FROM viajes_validos
GROUP BY anio_archivo, tipo_taxi
ORDER BY anio, tipo_taxi;

-- name: i5_propina_tarjeta
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS mes,
    tipo_taxi,
    round(median(100 * tip_amount / fare_amount), 1) AS propina_mediana_pct
FROM viajes_validos
WHERE payment_type = 1 AND fare_amount > 0
GROUP BY anio_archivo, mes_archivo, tipo_taxi
ORDER BY mes, tipo_taxi;

-- name: i6_forma_de_pago
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS mes,
    round(100.0 * count(*) FILTER (WHERE payment_type = 1) / count(*), 1) AS pct_tarjeta,
    round(100.0 * count(*) FILTER (WHERE payment_type = 2) / count(*), 1) AS pct_efectivo,
    round(100.0 * count(*) FILTER (WHERE coalesce(payment_type, 0) = 0) / count(*), 1) AS pct_sin_dato
FROM viajes_validos
WHERE tipo_taxi = 'yellow'
GROUP BY anio_archivo, mes_archivo
ORDER BY mes;

-- name: i7_velocidad_manhattan
-- Solo viajes que inician y terminan en Manhattan entre semana de 7 a 19 h, para aislar el trafico del centro
SELECT
    make_date(v.anio_archivo, v.mes_archivo, 1) AS mes,
    round(median(v.trip_distance / (v.duracion_min / 60)), 2) AS velocidad_mediana_mph
FROM viajes_validos v
JOIN zonas o ON o.location_id = v.PULocationID
JOIN zonas d ON d.location_id = v.DOLocationID
WHERE o.distrito = 'Manhattan' AND d.distrito = 'Manhattan'
  AND isodow(v.inicio) <= 5 AND hour(v.inicio) BETWEEN 7 AND 18
GROUP BY v.anio_archivo, v.mes_archivo
ORDER BY mes;

-- name: i8_viajes_aeropuerto
SELECT
    anio_archivo::VARCHAR AS anio,
    round(100.0 * count(*) FILTER (WHERE z.service_zone IN ('Airports', 'EWR')) / count(*), 2) AS pct_desde_aeropuerto,
    round(median(total_amount) FILTER (WHERE z.service_zone IN ('Airports', 'EWR')), 2) AS total_mediano_aeropuerto
FROM viajes_validos v
JOIN zonas z ON z.location_id = v.PULocationID
WHERE tipo_taxi = 'yellow'
GROUP BY anio_archivo
ORDER BY anio;

-- name: i9_viajes_por_hora
SELECT
    anio_archivo::VARCHAR AS anio,
    hour(inicio) AS hora,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY anio_archivo), 2) AS pct_viajes
FROM viajes_validos
GROUP BY anio_archivo, hora
ORDER BY anio, hora;

-- name: i10_top_zonas
SELECT
    z.zona || ' (' || z.distrito || ')' AS zona,
    count(*) FILTER (WHERE anio_archivo = (SELECT max(anio_archivo) FROM viajes_validos)) AS viajes_ultimo_anio,
    count(*) AS viajes_total
FROM viajes_validos v
JOIN zonas z ON z.location_id = v.PULocationID
GROUP BY z.zona, z.distrito
ORDER BY viajes_total DESC
LIMIT 10;

-- name: i11_registros_validos
-- Se lee de viajes (sin filtrar) porque mide justamente cuanto elimina el filtro
SELECT
    make_date(anio_archivo, mes_archivo, 1) AS mes,
    tipo_taxi,
    round(100.0 * count(*) FILTER (WHERE year(inicio) = anio_archivo AND month(inicio) = mes_archivo
                                     AND duracion_min BETWEEN 1 AND 180
                                     AND trip_distance > 0 AND trip_distance <= 100
                                     AND total_amount > 0 AND fare_amount >= 0) / count(*), 2) AS pct_validos
FROM viajes
GROUP BY anio_archivo, mes_archivo, tipo_taxi
ORDER BY mes, tipo_taxi;
