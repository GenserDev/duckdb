-- Ejercicio 4. Analisis exploratorio sobre las vistas de sql/00_vistas.sql.
-- Salvo que se indique, se usa viajes_validos (filtros del Ejercicio 3).

-- name: filtro_limpieza
SELECT
    tipo_taxi,
    count(*) AS registros,
    count(*) FILTER (WHERE year(inicio) = anio_archivo AND month(inicio) = mes_archivo
                       AND duracion_min BETWEEN 1 AND 180
                       AND trip_distance > 0 AND trip_distance <= 100
                       AND total_amount > 0 AND fare_amount >= 0) AS validos,
    round(100.0 * validos / registros, 2) AS pct_validos
FROM viajes
GROUP BY tipo_taxi
ORDER BY tipo_taxi;

-- name: viajes_por_mes
SELECT
    tipo_taxi,
    anio_archivo AS anio,
    mes_archivo AS mes,
    count(*) AS viajes,
    round(count(*) / any_value(day(last_day(inicio::DATE))), 0) AS viajes_por_dia
FROM viajes_validos
GROUP BY tipo_taxi, anio_archivo, mes_archivo
ORDER BY tipo_taxi, anio, mes;

-- name: viajes_por_hora_y_dia
SELECT
    tipo_taxi,
    isodow(inicio) AS dia_semana,
    hour(inicio) AS hora,
    count(*) AS viajes
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi, dia_semana, hora;

-- name: caracteristicas_viaje
SELECT
    tipo_taxi,
    round(median(trip_distance), 2) AS distancia_mediana_mi,
    round(quantile_cont(trip_distance, 0.9), 2) AS distancia_p90_mi,
    round(median(duracion_min), 1) AS duracion_mediana_min,
    round(quantile_cont(duracion_min, 0.9), 1) AS duracion_p90_min,
    round(median(trip_distance / (duracion_min / 60)), 1) AS velocidad_mediana_mph,
    round(avg(passenger_count), 2) AS pasajeros_promedio,
    round(100.0 * count(*) FILTER (WHERE passenger_count = 1) / count(passenger_count), 1) AS pct_un_pasajero
FROM viajes_validos
GROUP BY tipo_taxi
ORDER BY tipo_taxi;

-- name: zonas_de_recogida
WITH conteo AS (
    SELECT tipo_taxi, PULocationID, count(*) AS viajes
    FROM viajes_validos
    GROUP BY ALL
)
SELECT
    c.tipo_taxi,
    z.distrito,
    z.zona,
    c.viajes,
    round(100.0 * c.viajes / sum(c.viajes) OVER (PARTITION BY c.tipo_taxi), 2) AS pct
FROM conteo c
JOIN zonas z ON z.location_id = c.PULocationID
QUALIFY row_number() OVER (PARTITION BY c.tipo_taxi ORDER BY c.viajes DESC) <= 8
ORDER BY c.tipo_taxi, c.viajes DESC;

-- name: viajes_por_distrito
SELECT
    v.tipo_taxi,
    z.distrito,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY v.tipo_taxi), 2) AS pct
FROM viajes_validos v
JOIN zonas z ON z.location_id = v.PULocationID
GROUP BY v.tipo_taxi, z.distrito
ORDER BY v.tipo_taxi, viajes DESC;

-- name: tipos_de_pago
SELECT
    tipo_taxi,
    CASE coalesce(payment_type, 0)
        WHEN 0 THEN 'Flex / sin dato'
        WHEN 1 THEN 'Tarjeta'
        WHEN 2 THEN 'Efectivo'
        WHEN 3 THEN 'Sin cargo'
        WHEN 4 THEN 'Disputa'
        WHEN 5 THEN 'Desconocido'
        WHEN 6 THEN 'Viaje anulado'
    END AS tipo_pago,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS pct
FROM viajes_validos
GROUP BY tipo_taxi, payment_type
ORDER BY tipo_taxi, viajes DESC;

-- name: propinas_tarjeta
-- Las propinas en efectivo no se registran, por eso solo se usa pago con tarjeta.
SELECT
    tipo_taxi,
    count(*) AS viajes_tarjeta,
    round(avg(tip_amount), 2) AS propina_promedio,
    round(median(100 * tip_amount / fare_amount), 1) AS propina_mediana_pct,
    round(100.0 * count(*) FILTER (WHERE tip_amount = 0) / count(*), 1) AS pct_sin_propina
FROM viajes_validos
WHERE payment_type = 1 AND fare_amount > 0
GROUP BY tipo_taxi
ORDER BY tipo_taxi;

-- name: composicion_del_cobro
SELECT
    tipo_taxi,
    round(avg(total_amount), 2) AS total,
    round(avg(fare_amount), 2) AS tarifa,
    round(avg(tip_amount), 2) AS propina,
    round(avg(tolls_amount), 2) AS peajes,
    round(avg(coalesce(congestion_surcharge, 0)), 2) AS recargo_congestion,
    round(avg(coalesce(cbd_congestion_fee, 0)), 2) AS cargo_cbd,
    round(avg(coalesce(airport_fee, 0)), 2) AS cargo_aeropuerto,
    round(avg(extra + mta_tax + improvement_surcharge), 2) AS otros
FROM viajes_validos
GROUP BY tipo_taxi
ORDER BY tipo_taxi;

-- name: distribucion_total
SELECT
    tipo_taxi,
    least(floor(total_amount / 10) * 10, 150) AS rango_total_usd,
    count(*) AS viajes,
    round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY tipo_taxi), 2) AS pct
FROM viajes_validos
GROUP BY tipo_taxi, rango_total_usd
ORDER BY tipo_taxi, rango_total_usd;

-- name: tarifa_por_tipo_de_tarifa
SELECT
    tipo_taxi,
    RatecodeID,
    count(*) AS viajes,
    round(median(trip_distance), 2) AS distancia_mediana,
    round(median(total_amount), 2) AS total_mediano
FROM viajes_validos
GROUP BY ALL
ORDER BY tipo_taxi, viajes DESC;

-- name: atipicos
SELECT
    tipo_taxi,
    count(*) AS validos,
    count(*) FILTER (WHERE trip_distance / (duracion_min / 60) > 60) AS velocidad_mayor_60mph,
    count(*) FILTER (WHERE fare_amount / trip_distance > 50 AND trip_distance > 0.5) AS tarifa_por_milla_mayor_50,
    count(*) FILTER (WHERE total_amount > 300) AS total_mayor_300,
    count(*) FILTER (WHERE tip_amount > fare_amount AND fare_amount > 0) AS propina_mayor_que_tarifa,
    count(*) FILTER (WHERE passenger_count > 6) AS mas_de_6_pasajeros
FROM viajes_validos
GROUP BY tipo_taxi
ORDER BY tipo_taxi;

-- name: limites_iqr
WITH cuartiles AS (
    SELECT
        tipo_taxi,
        quantile_cont(total_amount, 0.25) AS q1,
        quantile_cont(total_amount, 0.75) AS q3
    FROM viajes_validos
    GROUP BY tipo_taxi
)
SELECT
    c.tipo_taxi,
    round(c.q1, 2) AS q1,
    round(c.q3, 2) AS q3,
    round(c.q3 + 1.5 * (c.q3 - c.q1), 2) AS limite_superior,
    count(*) FILTER (WHERE v.total_amount > c.q3 + 1.5 * (c.q3 - c.q1)) AS atipicos,
    round(100.0 * atipicos / count(*), 2) AS pct_atipicos
FROM viajes_validos v
JOIN cuartiles c USING (tipo_taxi)
GROUP BY c.tipo_taxi, c.q1, c.q3
ORDER BY c.tipo_taxi;
