-- Vistas sobre los archivos Parquet. No copian datos, solo guardan la consulta.
-- El patron */*.parquet toma cualquier anio presente en data/raw, por eso
-- agregar un anio nuevo no requiere cambiar ninguna consulta.

-- name: vista_yellow
CREATE OR REPLACE VIEW yellow AS
SELECT *
FROM read_parquet('data/raw/yellow/*/*.parquet', union_by_name = true, filename = true);

-- name: vista_green
CREATE OR REPLACE VIEW green AS
SELECT *
FROM read_parquet('data/raw/green/*/*.parquet', union_by_name = true, filename = true);

-- name: vista_viajes
CREATE OR REPLACE VIEW viajes AS
WITH unidos AS (
    SELECT
        'yellow' AS tipo_taxi,
        tpep_pickup_datetime AS inicio,
        tpep_dropoff_datetime AS fin,
        VendorID, passenger_count, trip_distance, RatecodeID,
        PULocationID, DOLocationID, payment_type,
        fare_amount, extra, mta_tax, tip_amount, tolls_amount,
        improvement_surcharge, congestion_surcharge, cbd_congestion_fee,
        Airport_fee AS airport_fee,
        NULL::BIGINT AS trip_type,
        total_amount, filename
    FROM yellow
    UNION ALL
    SELECT
        'green',
        lpep_pickup_datetime,
        lpep_dropoff_datetime,
        VendorID, passenger_count, trip_distance, RatecodeID,
        PULocationID, DOLocationID, payment_type,
        fare_amount, extra, mta_tax, tip_amount, tolls_amount,
        improvement_surcharge, congestion_surcharge, cbd_congestion_fee,
        NULL::DOUBLE,
        trip_type,
        total_amount, filename
    FROM green
)
SELECT
    *,
    CAST(regexp_extract(filename, '(\d{4})-\d{2}\.parquet$', 1) AS INTEGER) AS anio_archivo,
    CAST(regexp_extract(filename, '\d{4}-(\d{2})\.parquet$', 1) AS INTEGER) AS mes_archivo,
    date_diff('second', inicio, fin) / 60.0 AS duracion_min
FROM unidos;

-- name: vista_zonas
CREATE OR REPLACE VIEW zonas AS
SELECT LocationID AS location_id, Borough AS distrito, Zone AS zona, service_zone
FROM read_csv('data/raw/taxi_zone_lookup.csv');

-- name: vista_viajes_validos
-- Filtros de limpieza definidos en el Ejercicio 3. Los archivos originales no se modifican.
CREATE OR REPLACE VIEW viajes_validos AS
SELECT *
FROM viajes
WHERE year(inicio) = anio_archivo
  AND month(inicio) = mes_archivo
  AND duracion_min BETWEEN 1 AND 180
  AND trip_distance > 0 AND trip_distance <= 100
  AND total_amount > 0
  AND fare_amount >= 0;
