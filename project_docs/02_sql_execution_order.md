# 02 - SQL Execution Order

This file explains the commands and SQL files in the order we used them.

## Step 1 - Import The Source Database

We imported the official MySQL `airportdb` sample dump.

Command used in PowerShell:

```powershell
mysqlsh root@localhost --js -e "util.loadDump('C:/Users/thwma/Desktop/Big Data Management and Visualization/airportdb_source/airport-db', {threads: 8, deferTableIndexes: 'all', ignoreVersion: true})"
```

Problem we fixed:

```text
local_infile was disabled
```

After enabling it, the import worked and `airportdb` appeared in MySQL Workbench.

## Step 2 - Create The Data Warehouse Schema

SQL file:

```text
sql/dw/01_create_airportdw_schema.sql
```

What it creates:

```text
airportdw database
dim_date
dim_airport
dim_airline
dim_airplane
dim_route
fact_flight
fact_booking_by_flight
fact_daily_airport_traffic
fact_weather
etl_control
etl_run_log
source_business_day_status
```

Why:

```text
The source database is raw.
The Data Warehouse needs dimensions and facts for analysis.
```

## Step 3 - Create Dashboard Summary Views

SQL file:

```text
sql/dw/04_create_dashboard_summary_views.sql
```

Important final views:

```text
vw_top20_airport_map_traffic
vw_top20_revenue_airports_map
vw_top_countries_by_revenue
vw_top_airlines_by_revenue
vw_monthly_revenue_trend
vw_price_range_distribution
vw_etl_current_status
vw_etl_run_history
```

Why:

```text
Power BI should not do all calculations from raw tables.
These views already answer the dashboard questions.
```

## Step 4 - Create Incremental Refresh Procedures

SQL file:

```text
sql/dw/05_closed_day_incremental_refresh.sql
```

Important procedures:

```text
initialize_airportdw_closed_day_simulation(...)
refresh_airportdw_next_closed_days()
refresh_airportdw_incremental_range(...)
```

Why:

```text
A real DW should not reload everything every time.
It should add only the next stable/closed source day.
```

## Step 5 - Initialize The Demo

Command:

```sql
CALL airportdw.initialize_airportdw_closed_day_simulation(1, 1, 3);
```

Meaning:

```text
1 = initial load is 1 month
1 = each refresh loads 1 new closed day
3 = safety delay is 3 hours
```

Initial result:

```text
2015-06-01 to 2015-06-30
149254 flights
```

## Step 6 - Run Incremental Refresh

Command:

```sql
CALL airportdw.refresh_airportdw_next_closed_days();
```

Each call loads the next closed business day.

Current observed runs:

```text
Run 1: 2015-06-01 to 2015-06-30 -> 149254 flights
Run 2: 2015-07-01 -> 4947 flights
Run 3: 2015-07-02 -> 4894 flights
Run 4: 2015-07-03 -> 5017 flights
Total: 164112 flights
```

## Step 7 - Validate

Useful validation queries:

```sql
SELECT * FROM airportdw.vw_etl_current_status;
SELECT * FROM airportdw.vw_etl_run_history ORDER BY run_id;
SELECT COUNT(*) FROM airportdw.fact_flight;
```

Full validation file:

```text
sql/dw/07_validation_queries.sql
```

Current validation:

```text
missing flights in loaded window = 0
```
