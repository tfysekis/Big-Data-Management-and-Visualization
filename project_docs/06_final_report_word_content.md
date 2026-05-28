# Τελική Τεκμηρίωση Project - Airport Data Warehouse και Power BI

## Στοιχεία

Μάθημα: Big Data Management and Visualization  
Θέμα: Data Warehouse και Power BI Dashboard με χρήση της MySQL airportdb  
GitHub repository: `https://github.com/tfysekis/big-data-management`  
Power BI αρχείο: `AirportDW_Dashboard.pbix`  
PowerPoint παρουσίαση: `AirportDW_Greek_Progress_Presentation_real_final.pptx`  
Data Warehouse: `airportdw`  
Source database: `airportdb`

## 1. Σκοπός Project

Στόχος του project ήταν να δημιουργηθεί ένα ολοκληρωμένο workflow από μια επιχειρησιακή βάση δεδομένων προς ένα Data Warehouse και στη συνέχεια προς ένα Power BI dashboard.

Η τελική ροή είναι:

```text
airportdb -> airportdw -> Power BI
source DB    data warehouse   dashboard
```

Η `airportdb` χρησιμοποιείται ως source/production-like database. Η `airportdw` είναι η αναλυτική βάση δεδομένων που δημιουργήσαμε για reporting. Το Power BI συνδέεται με έτοιμα views της `airportdw`.

## 2. Γιατί Δεν Χρησιμοποιήσαμε Απευθείας Την airportdb

Η `airportdb` είναι επιχειρησιακή βάση, δηλαδή έχει raw tables που μοιάζουν περισσότερο με παραγωγικό σύστημα παρά με αναλυτικό μοντέλο.

Παραδείγματα source tables:

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

Ο βασικός λόγος που δημιουργήσαμε ξεχωριστό Data Warehouse είναι ότι το Power BI δεν πρέπει να κάνει όλα τα joins και τους υπολογισμούς πάνω στα raw tables. Ειδικά ο πίνακας `booking` έχει πάνω από 54 εκατομμύρια rows, οπότε είναι καλύτερο να δημιουργηθούν facts, dimensions και summary views στη MySQL.

## 3. Σχεδιασμός Data Warehouse

Δημιουργήσαμε τη βάση:

```text
airportdw
```

Το DW περιλαμβάνει dimensions και facts.

Dimensions:

```text
dim_date
dim_airport
dim_airline
dim_airplane
dim_route
```

Facts:

```text
fact_flight
fact_booking_by_flight
fact_daily_airport_traffic
fact_weather
```

Η λογική είναι τύπου star schema: τα facts κρατούν γεγονότα και μετρήσεις, ενώ τα dimensions δίνουν το πλαίσιο ανάλυσης, όπως ημερομηνία, αεροδρόμιο, αεροπορική και route.

### Placeholder Εικόνας

Εικόνα 1: Διάγραμμα σχέσεων του Data Warehouse.  
Τοποθέτησε εδώ screenshot από Workbench / schema relationships.

## 4. SQL Αρχεία Που Χρησιμοποιήθηκαν

Τα τελικά SQL αρχεία που χρησιμοποιούνται στο repo είναι:

```text
sql/dw/01_create_airportdw_schema.sql
sql/dw/04_create_dashboard_summary_views.sql
sql/dw/05_closed_day_incremental_refresh.sql
sql/dw/06_create_closed_day_scheduler_event.sql
sql/dw/07_validation_queries.sql
```

### 4.1 Δημιουργία Schema

Το αρχείο:

```text
sql/dw/01_create_airportdw_schema.sql
```

δημιουργεί τη δομή του Data Warehouse:

```text
dimensions
facts
foreign keys
indexes
etl_control
etl_run_log
source_business_day_status
```

### 4.2 Dashboard Views

Το αρχείο:

```text
sql/dw/04_create_dashboard_summary_views.sql
```

δημιουργεί τα τελικά views για Power BI:

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

Αυτά τα views χρησιμοποιούνται ώστε το Power BI να παίρνει ήδη καθαρά και aggregated δεδομένα.

## 5. Import Της airportdb

Η source database έγινε import με MySQL Shell:

```powershell
mysqlsh root@localhost --js -e "util.loadDump('C:/Users/thwma/Desktop/Big Data Management and Visualization/airportdb_source/airport-db', {threads: 8, deferTableIndexes: 'all', ignoreVersion: true})"
```

Κατά το import χρειάστηκε να ενεργοποιηθεί το `local_infile`, γιατί η MySQL δεν επέτρεπε αρχικά το local load.

Μετά το import, στο MySQL Workbench εμφανίστηκε η βάση `airportdb`.

## 6. Incremental Refresh Mechanism

Αρχικά θα μπορούσαμε να κάνουμε full rebuild, δηλαδή να διαγράφουμε και να ξαναφορτώνουμε όλο το Data Warehouse. Αυτό όμως δεν είναι ρεαλιστικό.

Γι' αυτό δημιουργήσαμε incremental refresh logic:

```text
αρχικό load ενός μήνα
κάθε επόμενο refresh φορτώνει μόνο την επόμενη κλειστή business day
```

Το βασικό SQL αρχείο είναι:

```text
sql/dw/05_closed_day_incremental_refresh.sql
```

Οι βασικές procedures είναι:

```text
initialize_airportdw_closed_day_simulation(1, 1, 3)
refresh_airportdw_next_closed_days()
refresh_airportdw_incremental_range(...)
```

## 7. Τι Είναι Closed Business Day

Δεν φορτώνουμε μια ημέρα ακριβώς τα μεσάνυχτα. Στο σενάριό μας μια ημέρα θεωρείται κλειστή μετά από 3 ώρες safety delay.

Αυτό γίνεται επειδή:

```text
κάποιες πτήσεις μπορεί να φτάσουν μετά τα μεσάνυχτα
μπορεί να υπάρξουν καθυστερημένες διορθώσεις κρατήσεων
τα weather rows μπορεί να φτάσουν με καθυστέρηση
```

Παράδειγμα:

```text
Η 2015-07-01 θεωρείται ασφαλής μετά το 2015-07-02 03:00.
```

Η procedure κοιτάζει την `etl_control`, βλέπει μέχρι ποια ημέρα έχει φορτωθεί το DW και μετά φορτώνει μόνο την επόμενη ημέρα που είναι πλέον closed.

## 8. Πίνακες Ελέγχου ETL

### etl_control

Ο πίνακας `etl_control` κρατά την τρέχουσα κατάσταση του pipeline:

```text
simulated_now
closed_until_date
last_loaded_date
initial_load_months
batch_days
safety_delay_hours
last_status
last_message
```

### etl_run_log

Ο πίνακας `etl_run_log` κρατά ιστορικό εκτελέσεων:

```text
run_id
loaded_from_date
loaded_to_date
status
rows_fact_flight
rows_fact_booking_by_flight
rows_fact_daily_airport_traffic
rows_fact_weather
duration_seconds
```

Αυτός ο πίνακας χρησιμοποιείται και στο Power BI για να αποδείξει ότι το Data Warehouse μεγαλώνει incremental.

## 9. Demo Commands

Αρχικοποίηση demo:

```sql
CALL airportdw.initialize_airportdw_closed_day_simulation(1, 1, 3);
```

Εκτέλεση ενός incremental refresh:

```sql
CALL airportdw.refresh_airportdw_next_closed_days();
```

Έλεγχος κατάστασης:

```sql
SELECT * FROM airportdw.vw_etl_current_status;
SELECT * FROM airportdw.vw_etl_run_history ORDER BY run_id;
SELECT COUNT(*) FROM airportdw.fact_flight;
```

Validation:

```sql
SELECT COUNT(*) AS missing_flights
FROM airportdb.flight f
LEFT JOIN airportdw.fact_flight ff ON f.flight_id = ff.flight_id
WHERE DATE(f.departure) <= (
    SELECT last_loaded_date
    FROM airportdw.etl_control
    WHERE pipeline_name = 'airportdw_closed_day_sim'
)
AND ff.flight_id IS NULL;
```

Το αναμενόμενο αποτέλεσμα είναι:

```text
missing_flights = 0
```

## 10. Τρέχον Demo State

Η τρέχουσα κατάσταση μετά τα refreshes είναι:

```text
Run 1: 2015-06-01 έως 2015-06-30 -> 149254 flights
Run 2: 2015-07-01 -> 4947 flights
Run 3: 2015-07-02 -> 4894 flights
Run 4: 2015-07-03 -> 5017 flights
Total fact_flight rows: 164112
Missing flights in loaded window: 0
```

Αυτό δείχνει ότι το Data Warehouse φορτώθηκε αρχικά με ένα μήνα και μετά αυξήθηκε με νέες ημέρες.

## 11. MySQL Event Scheduler

Για να γίνει το refresh αυτόματο, δημιουργήθηκε event στον MySQL Event Scheduler.

Αρχείο:

```text
sql/dw/06_create_closed_day_scheduler_event.sql
```

Βασική λογική:

```sql
SET GLOBAL event_scheduler = ON;

CREATE EVENT ev_refresh_airportdw_closed_days
ON SCHEDULE EVERY 1 DAY
STARTS '2026-05-25 02:30:00'
DO
    CALL airportdw.refresh_airportdw_next_closed_days();
```

Σε πραγματικό σενάριο:

```text
02:30 - MySQL refreshes airportdw
03:00 - Power BI Service/Gateway refreshes report
```

Στο local demo:

```text
τρέχουμε manual CALL στο Workbench
μετά πατάμε Power BI -> Home -> Refresh
```

## 12. Power BI Dashboard

Το Power BI συνδέεται στην `airportdw` και χρησιμοποιεί έτοιμα views.

Τελικά visuals:

```text
Top 20 Airports by Flight Activity
Top Countries by Revenue
Top Airlines by Revenue
Revenue Share by Top Airlines
Revenue by Loaded Month
Bookings Across Price Ranges
Flights Loaded per ETL Run
ETL Run History
```

### Placeholder Εικόνας

Εικόνα 2: Πρώτη έκδοση Power BI dashboard.  
Τοποθέτησε εδώ screenshot από την πρώτη έκδοση των visuals. Σε αυτό το σημείο φαίνεται ότι τα βασικά γραφήματα είχαν δημιουργηθεί, αλλά χρειαζόταν διόρθωση στα relationships/refresh ώστε τα summary views να δουλεύουν καθαρά.

### Placeholder Εικόνας

Εικόνα 3: Διορθωμένη έκδοση Power BI dashboard μετά το refresh.  
Τοποθέτησε εδώ screenshot μετά το SQL refresh και Power BI Home -> Refresh. Εδώ φαίνεται ότι τα visuals ενημερώνονται με τα νέα δεδομένα του Data Warehouse.

### Placeholder Εικόνας

Εικόνα 4: ETL evidence visual.  
Τοποθέτησε εδώ screenshot του `Flights Loaded per ETL Run` και του `ETL Run History`.

Τα screenshots αυτά δείχνουν τη λογική του τελικού demo: πρώτα δημιουργήθηκαν τα visuals, μετά διορθώθηκε το Power BI model ώστε να μην υπάρχουν λάθος auto-relationships, και τέλος έγινε refresh για να φανεί ότι οι νέες ημέρες που φορτώθηκαν στο Data Warehouse εμφανίζονται στο dashboard.

## 13. Power BI Relationships Fix

Το Power BI δημιούργησε αυτόματα λάθος relationships ανάμεσα σε summary views. Αυτό προκάλεσε error με duplicated values.

Η λύση ήταν:

```text
διαγραφή auto-created relationships
απενεργοποίηση autodetect relationships
χρήση κάθε summary view ανεξάρτητα
```

Αυτό είναι σωστό επειδή τα views είναι ήδη aggregated και δεν χρειάζονται μεταξύ τους relationships.

## 14. AI Tools Disclosure

Χρησιμοποιήθηκαν AI tools για:

```text
καθοδήγηση Windows CLI setup
οργάνωση SQL workflow
debugging Power BI connection/refresh issues
τεκμηρίωση project
δημιουργία παρουσίασης και report draft
```

Τα SQL scripts, το local MySQL setup, το Data Warehouse και το Power BI dashboard δοκιμάστηκαν τοπικά.

## 15. Συμπέρασμα

Το project ολοκληρώνει τα βασικά ζητούμενα:

```text
σχεδιασμός Data Warehouse
incremental synchronization mechanism
Power BI dashboard
validation ότι δεν χάνονται rows
τεκμηρίωση, Word report και PowerPoint παρουσίαση
```

Στο τελικό υλικό παραδίδονται το GitHub repository με τα SQL scripts και τα markdown docs, το Word report για αναλυτική τεκμηρίωση, και η PowerPoint παρουσίαση για σύντομη παρουσίαση στην τάξη. Το προαιρετικό AI/ML κομμάτι δεν έχει υλοποιηθεί ακόμα, επειδή δεν είναι απαραίτητο για αυτή τη φάση.

## 16. Τελικές Εικόνες Που Μπαίνουν Στο Report

```text
Εικόνα 1: Data Warehouse schema / relationships από MySQL Workbench
Εικόνα 2: πρώτη έκδοση Power BI dashboard
Εικόνα 3: διορθωμένη έκδοση Power BI dashboard μετά το refresh
Εικόνα 4: ETL evidence με run history και loaded rows
Εικόνα 5: τελικό overview από το PowerPoint, αν ζητηθεί από τον καθηγητή
```

Δεν χρειάζεται να προστεθούν άλλα SQL scripts για αυτά τα screenshots. Οι εικόνες μπαίνουν μόνο ως τεκμήρια του τι υλοποιήθηκε και πώς φαίνεται το αποτέλεσμα.

## 17. Επόμενα Βήματα

Το βασικό project είναι πλέον λειτουργικό. Τα επόμενα βήματα, αν ζητηθούν για την τελική παράδοση, είναι:

```text
αποθήκευση τελικού Power BI .pbix
εισαγωγή των τελικών screenshots στο Word report
εισαγωγή των ίδιων screenshots στην PowerPoint παρουσίαση
προαιρετικά: AI/ML analysis σε επόμενη φάση
```
