-- Final Power BI dashboard views.
-- These are the only views needed for the final dashboard/demo.

USE airportdw;

-- Remove older experimental views so Power BI and Workbench stay clean.
DROP VIEW IF EXISTS vw_dashboard_kpis;
DROP VIEW IF EXISTS vw_flight_performance;
DROP VIEW IF EXISTS vw_booking_revenue;
DROP VIEW IF EXISTS vw_daily_airport_traffic;
DROP VIEW IF EXISTS vw_airline_summary;
DROP VIEW IF EXISTS vw_route_summary;
DROP VIEW IF EXISTS vw_country_traffic_summary;
DROP VIEW IF EXISTS vw_airport_map_traffic;
DROP VIEW IF EXISTS vw_top_airport_map_traffic;
DROP VIEW IF EXISTS vw_top_departure_airports_map;
DROP VIEW IF EXISTS vw_top_arrival_airports_map;
DROP VIEW IF EXISTS vw_top_revenue_airports_map;
DROP VIEW IF EXISTS vw_daily_revenue_trend;
DROP VIEW IF EXISTS vw_flight_duration_distribution;

CREATE OR REPLACE VIEW vw_top20_airport_map_traffic AS
SELECT
    da.airport_label,
    da.airport_name,
    da.city,
    da.country,
    da.iata,
    da.latitude,
    da.longitude,
    SUM(fat.departure_flights) AS departure_flights,
    SUM(fat.arrival_flights) AS arrival_flights,
    SUM(fat.departure_flights + fat.arrival_flights) AS total_flights,
    SUM(fat.departure_bookings + fat.arrival_bookings) AS total_bookings,
    SUM(fat.departure_revenue + fat.arrival_revenue) AS total_revenue
FROM fact_daily_airport_traffic fat
JOIN dim_airport da ON fat.airport_key = da.airport_key
WHERE da.latitude IS NOT NULL
  AND da.longitude IS NOT NULL
GROUP BY
    da.airport_label,
    da.airport_name,
    da.city,
    da.country,
    da.iata,
    da.latitude,
    da.longitude
ORDER BY total_flights DESC
LIMIT 20;

CREATE OR REPLACE VIEW vw_top20_revenue_airports_map AS
SELECT
    da.airport_label,
    da.airport_name,
    da.city,
    da.country,
    da.iata,
    da.latitude,
    da.longitude,
    SUM(fat.departure_flights) AS departure_flights,
    SUM(fat.arrival_flights) AS arrival_flights,
    SUM(fat.departure_flights + fat.arrival_flights) AS total_flights,
    SUM(fat.departure_bookings + fat.arrival_bookings) AS total_bookings,
    SUM(fat.departure_revenue + fat.arrival_revenue) AS total_revenue
FROM fact_daily_airport_traffic fat
JOIN dim_airport da ON fat.airport_key = da.airport_key
WHERE da.latitude IS NOT NULL
  AND da.longitude IS NOT NULL
GROUP BY
    da.airport_label,
    da.airport_name,
    da.city,
    da.country,
    da.iata,
    da.latitude,
    da.longitude
HAVING total_revenue > 0
ORDER BY total_revenue DESC
LIMIT 20;

CREATE OR REPLACE VIEW vw_top_countries_by_revenue AS
SELECT
    da.country,
    CAST(SUM(fat.departure_flights) AS DOUBLE) AS departure_flights,
    CAST(SUM(fat.arrival_flights) AS DOUBLE) AS arrival_flights,
    CAST(SUM(fat.departure_flights + fat.arrival_flights) AS DOUBLE) AS total_flights,
    CAST(SUM(fat.departure_bookings + fat.arrival_bookings) AS DOUBLE) AS total_bookings,
    CAST(SUM(fat.departure_revenue + fat.arrival_revenue) AS DOUBLE) AS total_revenue
FROM fact_daily_airport_traffic fat
JOIN dim_airport da ON fat.airport_key = da.airport_key
WHERE da.country IS NOT NULL
GROUP BY da.country
ORDER BY total_revenue DESC
LIMIT 10;

CREATE OR REPLACE VIEW vw_top_airlines_by_revenue AS
SELECT
    da.airline_name,
    da.iata AS airline_iata,
    COUNT(ff.flight_id) AS flights,
    CAST(SUM(fb.booking_count) AS DOUBLE) AS bookings,
    CAST(SUM(fb.total_revenue) AS DOUBLE) AS revenue,
    CAST(ROUND(SUM(fb.total_revenue) / NULLIF(SUM(fb.booking_count), 0), 2) AS DOUBLE) AS revenue_per_booking,
    CAST(ROUND(AVG(ff.duration_minutes), 2) AS DOUBLE) AS avg_duration_minutes,
    CAST(ROUND(SUM(fb.booking_count) / NULLIF(SUM(ff.capacity), 0) * 100, 2) AS DOUBLE) AS estimated_load_factor_pct
FROM fact_flight ff
JOIN dim_airline da ON ff.airline_key = da.airline_key
JOIN fact_booking_by_flight fb ON ff.flight_id = fb.flight_id
GROUP BY da.airline_name, da.iata
HAVING revenue IS NOT NULL
ORDER BY revenue DESC
LIMIT 10;

CREATE OR REPLACE VIEW vw_monthly_revenue_trend AS
SELECT
    dd.year,
    dd.month,
    dd.month_name,
    MIN(dd.full_date) AS month_start_date,
    COUNT(ff.flight_id) AS flights,
    CAST(SUM(fb.booking_count) AS DOUBLE) AS bookings,
    CAST(SUM(fb.total_revenue) AS DOUBLE) AS revenue,
    CAST(ROUND(SUM(fb.total_revenue) / NULLIF(SUM(fb.booking_count), 0), 2) AS DOUBLE) AS revenue_per_booking,
    CAST(ROUND(AVG(ff.duration_minutes), 2) AS DOUBLE) AS avg_duration_minutes
FROM fact_flight ff
JOIN dim_date dd ON ff.departure_date_key = dd.date_key
JOIN fact_booking_by_flight fb ON ff.flight_id = fb.flight_id
GROUP BY dd.year, dd.month, dd.month_name
ORDER BY dd.year, dd.month;

CREATE OR REPLACE VIEW vw_price_range_distribution AS
SELECT
    FLOOR(average_price / 25) * 25 AS price_range_start,
    FLOOR(average_price / 25) * 25 + 24 AS price_range_end,
    CONCAT(FLOOR(average_price / 25) * 25, '-', FLOOR(average_price / 25) * 25 + 24) AS price_range_label,
    COUNT(*) AS flights,
    CAST(SUM(booking_count) AS DOUBLE) AS bookings,
    CAST(SUM(total_revenue) AS DOUBLE) AS revenue
FROM fact_booking_by_flight
GROUP BY
    FLOOR(average_price / 25) * 25,
    FLOOR(average_price / 25) * 25 + 24,
    CONCAT(FLOOR(average_price / 25) * 25, '-', FLOOR(average_price / 25) * 25 + 24);

CREATE OR REPLACE VIEW vw_etl_current_status AS
SELECT
    pipeline_name,
    simulated_now,
    closed_until_date,
    last_loaded_date,
    DATEDIFF(closed_until_date, last_loaded_date) AS closed_days_waiting,
    initial_load_months,
    batch_days,
    safety_delay_hours,
    last_status,
    last_message,
    updated_at
FROM etl_control;

CREATE OR REPLACE VIEW vw_etl_run_history AS
SELECT
    run_id,
    pipeline_name,
    started_at,
    finished_at,
    TIMESTAMPDIFF(SECOND, started_at, finished_at) AS duration_seconds,
    loaded_from_date,
    loaded_to_date,
    status,
    message,
    rows_fact_flight,
    rows_fact_booking_by_flight,
    rows_fact_daily_airport_traffic,
    rows_fact_weather
FROM etl_run_log;
