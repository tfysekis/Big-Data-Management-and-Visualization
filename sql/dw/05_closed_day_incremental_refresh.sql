-- Production-like closed-business-day incremental refresh simulation.
-- Run after:
--   01_create_airportdw_schema.sql
--   04_create_dashboard_summary_views.sql
--
-- Idea:
--   1. airportdb is imported once and treated as the operational/source system.
--   2. airportdw is loaded first with an initial historical window.
--   3. Later runs load only newly closed business days.
--   4. Power BI reads airportdw views after the DW refresh finishes.

USE airportdw;

DROP PROCEDURE IF EXISTS rebuild_source_business_day_status;
DROP PROCEDURE IF EXISTS load_dim_date_range;
DROP PROCEDURE IF EXISTS load_reference_dimensions;
DROP PROCEDURE IF EXISTS refresh_airportdw_incremental_range;
DROP PROCEDURE IF EXISTS initialize_airportdw_closed_day_simulation;
DROP PROCEDURE IF EXISTS refresh_airportdw_next_closed_days;

DELIMITER //

CREATE PROCEDURE rebuild_source_business_day_status(IN p_simulated_now DATETIME)
BEGIN
    DECLARE closed_cutoff DATE;

    -- A day is closed only after a safety delay. This simulates late arrivals,
    -- booking corrections, and weather batches that arrive after midnight.
    SET closed_cutoff = DATE(DATE_SUB(p_simulated_now, INTERVAL 3 HOUR));

    INSERT INTO source_business_day_status (
        business_date,
        status,
        closed_at,
        source_flights,
        source_weather_rows
    )
    SELECT
        d.business_date,
        CASE WHEN d.business_date < closed_cutoff THEN 'CLOSED' ELSE 'OPEN' END AS status,
        CASE WHEN d.business_date < closed_cutoff
             THEN TIMESTAMP(DATE_ADD(d.business_date, INTERVAL 1 DAY), '03:00:00')
             ELSE NULL
        END AS closed_at,
        COALESCE(f.source_flights, 0),
        COALESCE(w.source_weather_rows, 0)
    FROM (
        SELECT DATE(departure) AS business_date FROM airportdb.flight
    ) d
    LEFT JOIN (
        SELECT DATE(departure) AS business_date, COUNT(*) AS source_flights
        FROM airportdb.flight
        GROUP BY DATE(departure)
    ) f ON d.business_date = f.business_date
    LEFT JOIN (
        SELECT log_date AS business_date, COUNT(*) AS source_weather_rows
        FROM airportdb.weatherdata
        GROUP BY log_date
    ) w ON d.business_date = w.business_date
    ON DUPLICATE KEY UPDATE
        status = VALUES(status),
        closed_at = VALUES(closed_at),
        source_flights = VALUES(source_flights),
        source_weather_rows = VALUES(source_weather_rows);
END //

CREATE PROCEDURE load_dim_date_range(IN p_from_date DATE, IN p_to_date DATE)
BEGIN
    DECLARE current_date_value DATE;

    SET current_date_value = p_from_date;

    WHILE current_date_value <= p_to_date DO
        INSERT IGNORE INTO dim_date (
            date_key,
            full_date,
            year,
            quarter,
            month,
            month_name,
            day_of_month,
            day_of_week,
            day_name,
            is_weekend
        )
        VALUES (
            CAST(DATE_FORMAT(current_date_value, '%Y%m%d') AS UNSIGNED),
            current_date_value,
            YEAR(current_date_value),
            QUARTER(current_date_value),
            MONTH(current_date_value),
            MONTHNAME(current_date_value),
            DAYOFMONTH(current_date_value),
            DAYOFWEEK(current_date_value),
            DAYNAME(current_date_value),
            DAYOFWEEK(current_date_value) IN (1, 7)
        );

        SET current_date_value = DATE_ADD(current_date_value, INTERVAL 1 DAY);
    END WHILE;
END //

CREATE PROCEDURE load_reference_dimensions(IN p_to_date DATE)
BEGIN
    INSERT INTO dim_airport (
        airport_id,
        iata,
        icao,
        airport_name,
        city,
        country,
        latitude,
        longitude,
        airport_label
    )
    SELECT
        a.airport_id,
        a.iata,
        a.icao,
        a.name,
        ag.city,
        ag.country,
        ag.latitude,
        ag.longitude,
        CONCAT(COALESCE(a.iata, a.icao), ' - ', a.name)
    FROM airportdb.airport a
    LEFT JOIN airportdb.airport_geo ag ON a.airport_id = ag.airport_id
    ON DUPLICATE KEY UPDATE
        iata = VALUES(iata),
        icao = VALUES(icao),
        airport_name = VALUES(airport_name),
        city = VALUES(city),
        country = VALUES(country),
        latitude = VALUES(latitude),
        longitude = VALUES(longitude),
        airport_label = VALUES(airport_label);

    INSERT INTO dim_airline (
        airline_id,
        iata,
        airline_name,
        base_airport_id,
        base_airport_label
    )
    SELECT
        al.airline_id,
        al.iata,
        al.airlinename,
        al.base_airport,
        da.airport_label
    FROM airportdb.airline al
    LEFT JOIN dim_airport da ON al.base_airport = da.airport_id
    ON DUPLICATE KEY UPDATE
        iata = VALUES(iata),
        airline_name = VALUES(airline_name),
        base_airport_id = VALUES(base_airport_id),
        base_airport_label = VALUES(base_airport_label);

    INSERT INTO dim_airplane (
        airplane_id,
        capacity,
        type_id,
        type_identifier,
        type_description,
        airline_id,
        airline_name
    )
    SELECT
        ap.airplane_id,
        ap.capacity,
        ap.type_id,
        apt.identifier,
        apt.description,
        ap.airline_id,
        al.airlinename
    FROM airportdb.airplane ap
    LEFT JOIN airportdb.airplane_type apt ON ap.type_id = apt.type_id
    LEFT JOIN airportdb.airline al ON ap.airline_id = al.airline_id
    ON DUPLICATE KEY UPDATE
        capacity = VALUES(capacity),
        type_id = VALUES(type_id),
        type_identifier = VALUES(type_identifier),
        type_description = VALUES(type_description),
        airline_id = VALUES(airline_id),
        airline_name = VALUES(airline_name);

    INSERT IGNORE INTO dim_route (
        from_airport_id,
        to_airport_id,
        from_airport_label,
        to_airport_label,
        from_city,
        from_country,
        to_city,
        to_country,
        route_label
    )
    SELECT
        r.from_airport_id,
        r.to_airport_id,
        origin.airport_label,
        destination.airport_label,
        origin.city,
        origin.country,
        destination.city,
        destination.country,
        CONCAT(origin.airport_label, ' -> ', destination.airport_label)
    FROM (
        SELECT DISTINCT
            f.`from` AS from_airport_id,
            f.`to` AS to_airport_id
        FROM airportdb.flight f
        WHERE DATE(f.departure) <= p_to_date
    ) r
    JOIN dim_airport origin ON r.from_airport_id = origin.airport_id
    JOIN dim_airport destination ON r.to_airport_id = destination.airport_id;
END //

CREATE PROCEDURE refresh_airportdw_incremental_range(
    IN p_from_date DATE,
    IN p_to_date DATE,
    IN p_run_id BIGINT
)
BEGIN
    DECLARE from_date_key INT;
    DECLARE to_date_key INT;
    DECLARE max_arrival_date DATE;
    DECLARE max_arrival_date_key INT;

    SET from_date_key = CAST(DATE_FORMAT(p_from_date, '%Y%m%d') AS UNSIGNED);
    SET to_date_key = CAST(DATE_FORMAT(p_to_date, '%Y%m%d') AS UNSIGNED);
    SET max_arrival_date = (
        SELECT COALESCE(MAX(DATE(arrival)), p_to_date)
        FROM airportdb.flight
        WHERE DATE(departure) BETWEEN p_from_date AND p_to_date
    );
    SET max_arrival_date_key = CAST(DATE_FORMAT(max_arrival_date, '%Y%m%d') AS UNSIGNED);

    -- Closed business day is based on departure date, but some flights arrive
    -- after midnight. Load the required arrival dates too, otherwise late
    -- flights would be skipped by the fact_flight foreign key to dim_date.
    CALL load_dim_date_range(p_from_date, max_arrival_date);
    CALL load_reference_dimensions(p_to_date);

    INSERT IGNORE INTO fact_flight (
        flight_id,
        flightno,
        departure_date_key,
        arrival_date_key,
        airline_key,
        airplane_key,
        route_key,
        departure_datetime,
        arrival_datetime,
        duration_minutes,
        capacity,
        flight_count
    )
    SELECT
        f.flight_id,
        f.flightno,
        CAST(DATE_FORMAT(DATE(f.departure), '%Y%m%d') AS UNSIGNED),
        CAST(DATE_FORMAT(DATE(f.arrival), '%Y%m%d') AS UNSIGNED),
        da.airline_key,
        dap.airplane_key,
        dr.route_key,
        f.departure,
        f.arrival,
        TIMESTAMPDIFF(MINUTE, f.departure, f.arrival),
        ap.capacity,
        1
    FROM airportdb.flight f
    JOIN dim_airline da ON f.airline_id = da.airline_id
    JOIN dim_airplane dap ON f.airplane_id = dap.airplane_id
    JOIN airportdb.airplane ap ON f.airplane_id = ap.airplane_id
    JOIN dim_route dr
        ON f.`from` = dr.from_airport_id
       AND f.`to` = dr.to_airport_id
    WHERE DATE(f.departure) BETWEEN p_from_date AND p_to_date;

    UPDATE etl_run_log
    SET rows_fact_flight = ROW_COUNT()
    WHERE run_id = p_run_id;

    INSERT INTO fact_booking_by_flight (
        flight_id,
        departure_date_key,
        airline_key,
        route_key,
        booking_count,
        booked_seat_count,
        total_revenue,
        average_price,
        min_price,
        max_price
    )
    SELECT
        b.flight_id,
        ff.departure_date_key,
        ff.airline_key,
        ff.route_key,
        COUNT(*) AS booking_count,
        COUNT(b.seat) AS booked_seat_count,
        SUM(b.price) AS total_revenue,
        ROUND(AVG(b.price), 2) AS average_price,
        MIN(b.price) AS min_price,
        MAX(b.price) AS max_price
    FROM airportdb.booking b
    JOIN fact_flight ff ON b.flight_id = ff.flight_id
    JOIN dim_date dd ON ff.departure_date_key = dd.date_key
    WHERE dd.full_date BETWEEN p_from_date AND p_to_date
    GROUP BY
        b.flight_id,
        ff.departure_date_key,
        ff.airline_key,
        ff.route_key
    ON DUPLICATE KEY UPDATE
        booking_count = VALUES(booking_count),
        booked_seat_count = VALUES(booked_seat_count),
        total_revenue = VALUES(total_revenue),
        average_price = VALUES(average_price),
        min_price = VALUES(min_price),
        max_price = VALUES(max_price);

    UPDATE etl_run_log
    SET rows_fact_booking_by_flight = ROW_COUNT()
    WHERE run_id = p_run_id;

    DELETE FROM fact_daily_airport_traffic
    WHERE date_key BETWEEN from_date_key AND max_arrival_date_key;

    INSERT INTO fact_daily_airport_traffic (
        date_key,
        airport_key,
        departure_flights,
        arrival_flights,
        departure_bookings,
        arrival_bookings,
        departure_revenue,
        arrival_revenue
    )
    SELECT
        x.date_key,
        x.airport_key,
        SUM(x.departure_flights),
        SUM(x.arrival_flights),
        SUM(x.departure_bookings),
        SUM(x.arrival_bookings),
        SUM(x.departure_revenue),
        SUM(x.arrival_revenue)
    FROM (
        SELECT
            ff.departure_date_key AS date_key,
            origin.airport_key,
            COUNT(*) AS departure_flights,
            0 AS arrival_flights,
            SUM(COALESCE(fb.booking_count, 0)) AS departure_bookings,
            0 AS arrival_bookings,
            SUM(COALESCE(fb.total_revenue, 0)) AS departure_revenue,
            0 AS arrival_revenue
        FROM fact_flight ff
        JOIN dim_route dr ON ff.route_key = dr.route_key
        JOIN dim_airport origin ON dr.from_airport_id = origin.airport_id
        LEFT JOIN fact_booking_by_flight fb ON ff.flight_id = fb.flight_id
        WHERE ff.departure_date_key BETWEEN from_date_key AND to_date_key
        GROUP BY ff.departure_date_key, origin.airport_key

        UNION ALL

        SELECT
            ff.arrival_date_key AS date_key,
            destination.airport_key,
            0 AS departure_flights,
            COUNT(*) AS arrival_flights,
            0 AS departure_bookings,
            SUM(COALESCE(fb.booking_count, 0)) AS arrival_bookings,
            0 AS departure_revenue,
            SUM(COALESCE(fb.total_revenue, 0)) AS arrival_revenue
        FROM fact_flight ff
        JOIN dim_route dr ON ff.route_key = dr.route_key
        JOIN dim_airport destination ON dr.to_airport_id = destination.airport_id
        LEFT JOIN fact_booking_by_flight fb ON ff.flight_id = fb.flight_id
        WHERE ff.arrival_date_key BETWEEN from_date_key AND max_arrival_date_key
        GROUP BY ff.arrival_date_key, destination.airport_key
    ) x
    GROUP BY x.date_key, x.airport_key;

    UPDATE etl_run_log
    SET rows_fact_daily_airport_traffic = ROW_COUNT()
    WHERE run_id = p_run_id;

    INSERT IGNORE INTO fact_weather (
        date_key,
        weather_time,
        station,
        temperature,
        humidity,
        airpressure,
        wind,
        weather,
        winddirection
    )
    SELECT
        CAST(DATE_FORMAT(w.log_date, '%Y%m%d') AS UNSIGNED),
        w.time,
        w.station,
        w.temp,
        w.humidity,
        w.airpressure,
        w.wind,
        w.weather,
        w.winddirection
    FROM airportdb.weatherdata w
    WHERE w.log_date BETWEEN p_from_date AND p_to_date;

    UPDATE etl_run_log
    SET rows_fact_weather = ROW_COUNT()
    WHERE run_id = p_run_id;
END //

CREATE PROCEDURE initialize_airportdw_closed_day_simulation(
    IN p_initial_load_months INT,
    IN p_batch_days INT,
    IN p_safety_delay_hours INT
)
BEGIN
    DECLARE initial_months_value INT;
    DECLARE source_min_date DATE;
    DECLARE initial_to_date DATE;
    DECLARE run_id_value BIGINT;

    SET initial_months_value = GREATEST(p_initial_load_months, 1);

    SET source_min_date = (
        SELECT MIN(DATE(departure)) FROM airportdb.flight
    );

    SET initial_to_date = DATE_SUB(DATE_ADD(source_min_date, INTERVAL initial_months_value MONTH), INTERVAL 1 DAY);

    SET FOREIGN_KEY_CHECKS = 0;
    TRUNCATE TABLE fact_weather;
    TRUNCATE TABLE fact_daily_airport_traffic;
    TRUNCATE TABLE fact_booking_by_flight;
    TRUNCATE TABLE fact_flight;
    TRUNCATE TABLE dim_route;
    TRUNCATE TABLE dim_airplane;
    TRUNCATE TABLE dim_airline;
    TRUNCATE TABLE dim_airport;
    TRUNCATE TABLE dim_date;
    TRUNCATE TABLE source_business_day_status;
    TRUNCATE TABLE etl_run_log;
    TRUNCATE TABLE etl_control;
    SET FOREIGN_KEY_CHECKS = 1;

    INSERT INTO etl_control (
        pipeline_name,
        simulated_now,
        closed_until_date,
        last_loaded_date,
        initial_load_months,
        rolling_window_months,
        batch_days,
        safety_delay_hours,
        last_status,
        last_message
    )
    VALUES (
        'airportdw_closed_day_sim',
        TIMESTAMP(DATE_ADD(initial_to_date, INTERVAL 1 DAY), MAKETIME(p_safety_delay_hours, 0, 0)),
        initial_to_date,
        DATE_SUB(source_min_date, INTERVAL 1 DAY),
        initial_months_value,
        initial_months_value,
        p_batch_days,
        p_safety_delay_hours,
        'INITIALIZING',
        'Initial load started'
    );

    CALL rebuild_source_business_day_status((SELECT simulated_now FROM etl_control WHERE pipeline_name = 'airportdw_closed_day_sim'));

    INSERT INTO etl_run_log (
        pipeline_name,
        started_at,
        requested_from_date,
        requested_to_date,
        loaded_from_date,
        loaded_to_date,
        status,
        message
    )
    VALUES (
        'airportdw_closed_day_sim',
        NOW(),
        source_min_date,
        initial_to_date,
        source_min_date,
        initial_to_date,
        'RUNNING',
        'Initial closed-day window load'
    );

    SET run_id_value = LAST_INSERT_ID();

    CALL refresh_airportdw_incremental_range(source_min_date, initial_to_date, run_id_value);

    UPDATE etl_run_log
    SET
        finished_at = NOW(),
        status = 'SUCCESS',
        message = 'Initial closed-day simulation load completed'
    WHERE run_id = run_id_value;

    UPDATE etl_control
    SET
        last_loaded_date = initial_to_date,
        last_status = 'SUCCESS',
        last_message = 'Initial load completed'
    WHERE pipeline_name = 'airportdw_closed_day_sim';
END //

CREATE PROCEDURE refresh_airportdw_next_closed_days()
BEGIN
    DECLARE current_simulated_now DATETIME;
    DECLARE next_simulated_now DATETIME;
    DECLARE loaded_until DATE;
    DECLARE closed_until DATE;
    DECLARE source_max_date DATE;
    DECLARE next_from DATE;
    DECLARE next_to DATE;
    DECLARE days_to_load INT;
    DECLARE batch_size INT;
    DECLARE delay_hours INT;
    DECLARE run_id_value BIGINT;

    SELECT
        simulated_now,
        last_loaded_date,
        batch_days,
        safety_delay_hours
    INTO
        current_simulated_now,
        loaded_until,
        batch_size,
        delay_hours
    FROM etl_control
    WHERE pipeline_name = 'airportdw_closed_day_sim';

    SET source_max_date = (
        SELECT MAX(DATE(departure)) FROM airportdb.flight
    );

    -- Every scheduled execution moves the simulated production clock forward.
    -- Then we close only the dates that are safely behind the new clock.
    SET next_simulated_now = DATE_ADD(current_simulated_now, INTERVAL batch_size DAY);
    SET closed_until = LEAST(
        DATE_SUB(DATE(DATE_SUB(next_simulated_now, INTERVAL delay_hours HOUR)), INTERVAL 1 DAY),
        source_max_date
    );

    SET next_from = DATE_ADD(loaded_until, INTERVAL 1 DAY);
    SET days_to_load = DATEDIFF(closed_until, loaded_until);
    SET next_to = DATE_ADD(next_from, INTERVAL LEAST(batch_size, days_to_load) - 1 DAY);

    IF days_to_load <= 0 THEN
        INSERT INTO etl_run_log (
            pipeline_name,
            started_at,
            finished_at,
            requested_from_date,
            requested_to_date,
            loaded_from_date,
            loaded_to_date,
            status,
            message
        )
        VALUES (
            'airportdw_closed_day_sim',
            NOW(),
            NOW(),
            next_from,
            closed_until,
            NULL,
            NULL,
            'SKIPPED',
            'No newly closed business days available'
        );

        UPDATE etl_control
        SET
            simulated_now = next_simulated_now,
            closed_until_date = closed_until,
            last_status = 'SKIPPED',
            last_message = 'No newly closed business days available'
        WHERE pipeline_name = 'airportdw_closed_day_sim';

        CALL rebuild_source_business_day_status(next_simulated_now);
    ELSE
        INSERT INTO etl_run_log (
            pipeline_name,
            started_at,
            requested_from_date,
            requested_to_date,
            loaded_from_date,
            loaded_to_date,
            status,
            message
        )
        VALUES (
            'airportdw_closed_day_sim',
            NOW(),
            next_from,
            closed_until,
            next_from,
            next_to,
            'RUNNING',
            'Incremental closed-day refresh'
        );

        SET run_id_value = LAST_INSERT_ID();

        CALL refresh_airportdw_incremental_range(next_from, next_to, run_id_value);

        UPDATE etl_run_log
        SET
            finished_at = NOW(),
            status = 'SUCCESS',
            message = CONCAT('Loaded closed business days through ', next_to)
        WHERE run_id = run_id_value;

        UPDATE etl_control
        SET
            last_loaded_date = next_to,
            simulated_now = next_simulated_now,
            closed_until_date = closed_until,
            last_status = 'SUCCESS',
            last_message = CONCAT('Loaded through ', next_to)
        WHERE pipeline_name = 'airportdw_closed_day_sim';

        CALL rebuild_source_business_day_status(next_simulated_now);
    END IF;
END //

DELIMITER ;

-- Demo commands:
-- Initial load with 3 months of closed source data, then load 1 new closed day per run.
-- CALL initialize_airportdw_closed_day_simulation(3, 1, 3);
-- CALL refresh_airportdw_next_closed_days();
-- CALL refresh_airportdw_next_closed_days();
--
-- Scheduler example:
-- SET GLOBAL event_scheduler = ON;
-- CREATE EVENT ev_refresh_airportdw_closed_days
-- ON SCHEDULE EVERY 1 DAY
-- DO CALL airportdw.refresh_airportdw_next_closed_days();
