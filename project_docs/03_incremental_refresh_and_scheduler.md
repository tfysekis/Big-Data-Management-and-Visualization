# 03 - Incremental Refresh And Scheduler

This file explains the hardest part: how the DW synchronization works.

## The Problem

At first, the simple idea was:

```text
delete the DW
reload everything from airportdb
```

That works technically, but it is not realistic.

In a real project, we should not reload everything every day. We should load only new stable data.

## Our Scenario

We simulate a production system:

```text
airportdb = source/production database
airportdw = reporting Data Warehouse
```

The source data is historical, so we simulate time.

The DW starts with one month:

```text
2015-06-01 to 2015-06-30
```

Then each refresh adds one new closed business day:

```text
2015-07-01
2015-07-02
2015-07-03
...
```

## What Is A Closed Business Day?

A day is not loaded immediately at midnight.

Reason:

```text
some flights arrive after midnight
booking corrections can arrive late
weather rows can arrive late
```

So we use a safety delay:

```text
3 hours
```

Example:

```text
2015-07-01 becomes safe after 2015-07-02 03:00
```

Then the DW can load it.

## Tables That Control The Refresh

### `etl_control`

Stores the current state:

```text
pipeline_name
simulated_now
closed_until_date
last_loaded_date
initial_load_months
batch_days
safety_delay_hours
last_status
last_message
```

This tells the procedure:

```text
where the simulated clock is
which source day is closed
which source day was already loaded
```

### `etl_run_log`

Stores every refresh run:

```text
run_id
started_at
finished_at
loaded_from_date
loaded_to_date
status
rows_fact_flight
rows_fact_booking_by_flight
rows_fact_daily_airport_traffic
rows_fact_weather
```

This is what we show in Power BI as evidence.

## Main Procedure

Command:

```sql
CALL airportdw.refresh_airportdw_next_closed_days();
```

What it does:

```text
1. Reads etl_control
2. Moves simulated_now forward
3. Finds the next closed business day
4. Loads only that day into the DW facts
5. Writes a row into etl_run_log
6. Updates last_loaded_date
```

## Why We Fixed Overnight Arrivals

Some flights depart before midnight and arrive after midnight.

Example:

```text
departure date = 2015-07-01
arrival date = 2015-07-02
```

If `dim_date` did not contain the arrival date, those flights could be skipped.

We fixed the refresh procedure so it loads required arrival dates too.

Validation after the fix:

```text
missing flights in loaded window = 0
```

## Scheduler

SQL file:

```text
sql/dw/06_create_closed_day_scheduler_event.sql
```

Purpose:

```text
MySQL can run the refresh automatically every day.
```

The event calls:

```sql
CALL airportdw.refresh_airportdw_next_closed_days();
```

In a real deployment:

```text
02:30 MySQL scheduler refreshes airportdw
03:00 Power BI Service/Gateway refreshes dashboard
```

In our local demo:

```text
Run the SQL procedure manually
Then press Power BI Home -> Refresh
```

Important:

```text
Power BI Desktop does not update automatically when MySQL changes.
You must press Refresh.
```
