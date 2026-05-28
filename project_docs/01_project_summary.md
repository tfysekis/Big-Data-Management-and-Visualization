# 01 - Project Summary

This is the short version of the whole project.

## What We Built

We built a small Data Warehouse and Power BI dashboard project using the official MySQL `airportdb` sample database.

Final architecture:

```text
airportdb -> airportdw -> Power BI
source DB    data warehouse   dashboard
```

## Why We Built It This Way

`airportdb` is the source database. It is like a production/operational system.

It has raw tables such as:

```text
flight
booking
airport
airport_geo
airline
airplane
airplane_type
weatherdata
```

We did not use `airportdb` directly in Power BI because:

```text
booking has more than 54M rows
raw tables need joins
Power BI would become harder and slower
the dashboard needs clean analytical tables/views
```

So we created a second database:

```text
airportdw
```

`airportdw` is the Data Warehouse. It has facts, dimensions, ETL control tables, and dashboard views.

## Assignment Requirements

The assignment requirements were:

```text
1. Design a Data Warehouse
2. Create a synchronization mechanism between source data and DW
3. Create a BI dashboard
4. Optional AI algorithm
```

Current coverage:

```text
1. Done: airportdw schema, dimensions, facts
2. Done: incremental closed-business-day refresh + scheduler
3. Done/in progress: Power BI dashboard views and visuals
4. Not done yet: optional, not needed for current progress presentation
```

## Final Demo State

Current local DW state:

```text
Initial load: 2015-06-01 to 2015-06-30
Run 2: 2015-07-01
Run 3: 2015-07-02
Run 4: 2015-07-03
Total fact_flight rows: 164112
Missing flights in loaded window: 0
```

This proves that the DW is not only created, but also grows incrementally.

## What To Say Simply

Use this explanation:

```text
We imported airportdb as the source database.
Then we created airportdw as a Data Warehouse.
Inside airportdw we created dimensions, facts, and dashboard views.
After that, we created an incremental refresh mechanism.
The DW starts with one month of data and then each refresh loads only the next closed business day.
Power BI reads the prepared views from airportdw and updates when we press Refresh.
```
