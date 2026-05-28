# 05 - Presentation Script

This is a short script you can use with the teacher.

## 1. Introduction

```text
The project uses the MySQL airportdb sample database as a source system.
Instead of reporting directly from the raw source tables, we created a separate Data Warehouse called airportdw.
Power BI connects to airportdw views.
```

## 2. Why We Created A Data Warehouse

```text
The source database is operational and contains raw data.
For example, booking has more than 54M rows.
For reporting, we need a cleaner analytical structure.
So we created dimensions and facts inside airportdw.
```

## 3. DW Design

```text
The main dimensions are date, airport, airline, airplane, and route.
The main facts are flights, bookings by flight, daily airport traffic, and weather.
This gives us a star-schema style model where many facts connect to shared dimensions.
```

## 4. Synchronization Mechanism

```text
At first, a full rebuild would be possible, but it is not realistic.
So we implemented an incremental closed-business-day refresh.
The DW starts with one initial month.
After that, each refresh loads only the next closed business day.
```

## 5. Closed Business Day Logic

```text
A business day is not loaded immediately at midnight.
We use a 3-hour safety delay because late arrivals, booking corrections, and weather rows may arrive after midnight.
The ETL control table stores simulated_now, closed_until_date, and last_loaded_date.
The run log stores what each refresh loaded.
```

## 6. Current Evidence

```text
The current demo loaded:
Run 1: 2015-06-01 to 2015-06-30, 149254 flights.
Run 2: 2015-07-01, 4947 flights.
Run 3: 2015-07-02, 4894 flights.
Run 4: 2015-07-03, 5017 flights.
The current total is 164112 flights.
Validation shows missing flights = 0.
```

## 7. Scheduler

```text
We created a MySQL Event Scheduler event.
In a real scenario, MySQL would refresh the DW automatically, for example at 02:30.
Then Power BI Service/Gateway could refresh the report afterwards.
In the local demo, we run the procedure manually and then press Refresh in Power BI.
```

## 8. Power BI Dashboard

```text
The dashboard uses prepared views from airportdw.
It shows top airports, countries by revenue, airlines by revenue, revenue share, monthly revenue, price range bookings, and ETL refresh evidence.
The ETL visual proves that new rows are added per refresh.
```

## 9. AI Disclosure

```text
AI tools were used to help configure the Windows CLI workflow, SQL documentation, troubleshooting, and Power BI guidance.
The database, SQL scripts, and dashboard are still implemented and tested locally.
```

## 10. What Remains

```text
The backend and DW synchronization are ready.
The Power BI dashboard is working.
Next steps are to save the final PBIX, add screenshots to the report, and optionally add an AI/ML analysis if required later.
```
