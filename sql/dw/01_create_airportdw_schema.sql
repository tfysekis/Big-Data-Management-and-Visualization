-- Create the airport Data Warehouse schema.
-- Source schema: airportdb
-- DW schema: airportdw

DROP DATABASE IF EXISTS airportdw;
CREATE DATABASE airportdw CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE airportdw;

CREATE TABLE dim_date (
    date_key INT NOT NULL PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year SMALLINT NOT NULL,
    quarter TINYINT NOT NULL,
    month TINYINT NOT NULL,
    month_name VARCHAR(12) NOT NULL,
    day_of_month TINYINT NOT NULL,
    day_of_week TINYINT NOT NULL,
    day_name VARCHAR(12) NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

CREATE TABLE dim_airport (
    airport_key INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    airport_id SMALLINT NOT NULL UNIQUE,
    iata CHAR(3),
    icao CHAR(4) NOT NULL,
    airport_name VARCHAR(50) NOT NULL,
    city VARCHAR(50),
    country VARCHAR(50),
    latitude DECIMAL(11,8),
    longitude DECIMAL(11,8),
    airport_label VARCHAR(120) NOT NULL
);

CREATE TABLE dim_airline (
    airline_key INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    airline_id SMALLINT NOT NULL UNIQUE,
    iata CHAR(2) NOT NULL,
    airline_name VARCHAR(30),
    base_airport_id SMALLINT NOT NULL,
    base_airport_label VARCHAR(120)
);

CREATE TABLE dim_airplane (
    airplane_key INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    airplane_id INT NOT NULL UNIQUE,
    capacity MEDIUMINT UNSIGNED NOT NULL,
    type_id INT NOT NULL,
    type_identifier VARCHAR(50),
    type_description TEXT,
    airline_id INT NOT NULL,
    airline_name VARCHAR(30)
);

CREATE TABLE dim_route (
    route_key INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    from_airport_id SMALLINT NOT NULL,
    to_airport_id SMALLINT NOT NULL,
    from_airport_label VARCHAR(120) NOT NULL,
    to_airport_label VARCHAR(120) NOT NULL,
    from_city VARCHAR(50),
    from_country VARCHAR(50),
    to_city VARCHAR(50),
    to_country VARCHAR(50),
    route_label VARCHAR(255) NOT NULL,
    UNIQUE KEY uq_dim_route_source (from_airport_id, to_airport_id)
);

CREATE TABLE fact_flight (
    flight_key BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    flight_id INT NOT NULL UNIQUE,
    flightno CHAR(8) NOT NULL,
    departure_date_key INT NOT NULL,
    arrival_date_key INT NOT NULL,
    airline_key INT NOT NULL,
    airplane_key INT NOT NULL,
    route_key INT NOT NULL,
    departure_datetime DATETIME NOT NULL,
    arrival_datetime DATETIME NOT NULL,
    duration_minutes INT NOT NULL,
    capacity MEDIUMINT UNSIGNED NOT NULL,
    flight_count INT NOT NULL DEFAULT 1,
    FOREIGN KEY (departure_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (arrival_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (airline_key) REFERENCES dim_airline(airline_key),
    FOREIGN KEY (airplane_key) REFERENCES dim_airplane(airplane_key),
    FOREIGN KEY (route_key) REFERENCES dim_route(route_key)
);

CREATE TABLE fact_booking_by_flight (
    booking_flight_key BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    flight_id INT NOT NULL UNIQUE,
    departure_date_key INT NOT NULL,
    airline_key INT NOT NULL,
    route_key INT NOT NULL,
    booking_count INT NOT NULL,
    booked_seat_count INT NOT NULL,
    total_revenue DECIMAL(18,2) NOT NULL,
    average_price DECIMAL(10,2) NOT NULL,
    min_price DECIMAL(10,2) NOT NULL,
    max_price DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (flight_id) REFERENCES fact_flight(flight_id),
    FOREIGN KEY (departure_date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (airline_key) REFERENCES dim_airline(airline_key),
    FOREIGN KEY (route_key) REFERENCES dim_route(route_key)
);

CREATE TABLE fact_daily_airport_traffic (
    daily_airport_traffic_key BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    date_key INT NOT NULL,
    airport_key INT NOT NULL,
    departure_flights INT NOT NULL,
    arrival_flights INT NOT NULL,
    departure_bookings INT NOT NULL,
    arrival_bookings INT NOT NULL,
    departure_revenue DECIMAL(18,2) NOT NULL,
    arrival_revenue DECIMAL(18,2) NOT NULL,
    UNIQUE KEY uq_fact_daily_airport_traffic (date_key, airport_key),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (airport_key) REFERENCES dim_airport(airport_key)
);

CREATE TABLE fact_weather (
    weather_key BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    date_key INT NOT NULL,
    weather_time TIME NOT NULL,
    station INT NOT NULL,
    temperature DECIMAL(3,1) NOT NULL,
    humidity DECIMAL(4,1) NOT NULL,
    airpressure DECIMAL(10,2) NOT NULL,
    wind DECIMAL(5,2) NOT NULL,
    weather VARCHAR(40),
    winddirection SMALLINT NOT NULL,
    UNIQUE KEY uq_fact_weather_source (date_key, weather_time, station),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key)
);

CREATE TABLE etl_control (
    pipeline_name VARCHAR(80) NOT NULL PRIMARY KEY,
    simulated_now DATETIME,
    closed_until_date DATE,
    last_loaded_date DATE,
    initial_load_months INT NOT NULL DEFAULT 3,
    rolling_window_months INT NOT NULL DEFAULT 3,
    batch_days INT NOT NULL DEFAULT 1,
    safety_delay_hours INT NOT NULL DEFAULT 3,
    last_status VARCHAR(20),
    last_message VARCHAR(255),
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE source_business_day_status (
    business_date DATE NOT NULL PRIMARY KEY,
    status ENUM('OPEN', 'CLOSED') NOT NULL DEFAULT 'OPEN',
    closed_at DATETIME,
    source_flights INT NOT NULL DEFAULT 0,
    source_weather_rows INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE etl_run_log (
    run_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    pipeline_name VARCHAR(80) NOT NULL,
    started_at DATETIME NOT NULL,
    finished_at DATETIME,
    requested_from_date DATE,
    requested_to_date DATE,
    loaded_from_date DATE,
    loaded_to_date DATE,
    status VARCHAR(20) NOT NULL,
    message VARCHAR(255),
    rows_fact_flight BIGINT DEFAULT 0,
    rows_fact_booking_by_flight BIGINT DEFAULT 0,
    rows_fact_daily_airport_traffic BIGINT DEFAULT 0,
    rows_fact_weather BIGINT DEFAULT 0
);
