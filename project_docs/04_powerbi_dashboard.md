# 04 - Power BI Dashboard

This file explains the final Power BI dashboard.

## Main Idea

Power BI connects to `airportdw`, not directly to raw `airportdb`.

We use prepared MySQL views so Power BI does not need complicated relationships.

Important:

```text
Delete auto-created relationships between summary views.
Disable auto-detect relationships.
Each view is already aggregated and can work alone.
```

## Final Visuals

### 1. Top Airports by Flight Activity

View:

```text
vw_top20_airport_map_traffic
```

Visual:

```text
Map
```

Fields:

```text
Latitude: latitude
Longitude: longitude
Size: total_flights
Tooltips: airport_label, city, country, total_flights
```

Question answered:

```text
Where is airport activity concentrated?
```

### 2. Top Countries by Revenue

View:

```text
vw_top_countries_by_revenue
```

Visual:

```text
Clustered bar chart
```

Fields:

```text
Y-axis: country
X-axis: total_revenue
```

Question answered:

```text
Which countries generate the most revenue?
```

### 3. Top Airlines by Revenue

View:

```text
vw_top_airlines_by_revenue
```

Visual:

```text
Clustered bar chart
```

Fields:

```text
Y-axis: airline_name
X-axis: revenue
```

Question answered:

```text
Which airlines generate the most revenue?
```

### 4. Revenue Share by Top Airlines

View:

```text
vw_top_airlines_by_revenue
```

Visual:

```text
Donut chart
```

Fields:

```text
Legend: airline_name
Values: revenue
```

Question answered:

```text
How is revenue distributed between the top airlines?
```

### 5. Revenue by Loaded Month

View:

```text
vw_monthly_revenue_trend
```

Visual:

```text
Clustered column chart
```

Fields:

```text
X-axis: month_name
Y-axis: revenue
```

Question answered:

```text
How does revenue look across the loaded period?
```

### 6. Bookings Across Price Ranges

View:

```text
vw_price_range_distribution
```

Visual:

```text
Clustered column chart
```

Fields:

```text
X-axis: price_range_start
Y-axis: bookings
```

Question answered:

```text
Which ticket price ranges have the most bookings?
```

### 7. Flights Loaded per ETL Run

View:

```text
vw_etl_run_history
```

Visual:

```text
Clustered column chart
```

Fields:

```text
X-axis: run_id
Y-axis: rows_fact_flight
```

Question answered:

```text
Does the DW load data incrementally?
```

## What Happens After A Refresh

Run in MySQL:

```sql
CALL airportdw.refresh_airportdw_next_closed_days();
```

Then in Power BI:

```text
Home -> Refresh
```

Expected:

```text
ETL run history gets a new row
Flights Loaded per ETL Run gets a new bar
dashboard values update
```
