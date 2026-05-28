-- Validation queries for the closed-business-day incremental refresh.
-- Use after initialization and after every manual/scheduled refresh.

USE airportdw;

SELECT * FROM vw_etl_current_status;

SELECT
    run_id,
    status,
    loaded_from_date,
    loaded_to_date,
    rows_fact_flight,
    rows_fact_booking_by_flight,
    rows_fact_daily_airport_traffic,
    rows_fact_weather
FROM vw_etl_run_history
ORDER BY run_id;

SELECT
    COUNT(*) AS dw_flights,
    MIN(departure_datetime) AS dw_min_departure,
    MAX(departure_datetime) AS dw_max_departure
FROM fact_flight;

SELECT
    COUNT(*) AS source_flights_loaded_window
FROM airportdb.flight
WHERE DATE(departure) <= (
    SELECT last_loaded_date
    FROM etl_control
    WHERE pipeline_name = 'airportdw_closed_day_sim'
);

SELECT
    COUNT(*) AS missing_flights_in_loaded_window
FROM airportdb.flight f
LEFT JOIN fact_flight ff ON f.flight_id = ff.flight_id
WHERE DATE(f.departure) <= (
    SELECT last_loaded_date
    FROM etl_control
    WHERE pipeline_name = 'airportdw_closed_day_sim'
)
AND ff.flight_id IS NULL;

SELECT
    DATE(f.departure) AS missing_departure_date,
    COUNT(*) AS missing_flights
FROM airportdb.flight f
LEFT JOIN fact_flight ff ON f.flight_id = ff.flight_id
WHERE DATE(f.departure) <= (
    SELECT last_loaded_date
    FROM etl_control
    WHERE pipeline_name = 'airportdw_closed_day_sim'
)
AND ff.flight_id IS NULL
GROUP BY DATE(f.departure)
ORDER BY missing_departure_date;

SELECT
    COUNT(*) AS dw_booking_flight_rows,
    SUM(booking_count) AS dw_total_bookings,
    SUM(total_revenue) AS dw_total_revenue
FROM fact_booking_by_flight;

