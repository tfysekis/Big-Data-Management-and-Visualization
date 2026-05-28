# Big Data Management and Visualization

Clean project repository for the Airport Data Warehouse and Power BI assignment.

## Project Flow

```text
airportdb -> airportdw -> Power BI
source DB    data warehouse   dashboard
```

The project uses the MySQL `airportdb` as the source system, creates the analytical `airportdw` Data Warehouse, implements an incremental ETL refresh mechanism, and connects Power BI to prepared summary views.

## What To Read First

1. `project_docs/01_project_summary.md`
2. `project_docs/02_sql_execution_order.md`
3. `project_docs/03_incremental_refresh_and_scheduler.md`
4. `project_docs/04_powerbi_dashboard.md`
5. `project_docs/05_presentation_script.md`
6. `project_docs/06_final_report_word_content.md`

## Main SQL Files

```text
sql/dw/01_create_airportdw_schema.sql
sql/dw/04_create_dashboard_summary_views.sql
sql/dw/05_closed_day_incremental_refresh.sql
sql/dw/06_create_closed_day_scheduler_event.sql
sql/dw/07_validation_queries.sql
```

## Final Deliverables

```text
deliverables/AirportDW_Final_Report_GR.docx
deliverables/AirportDW_Greek_Progress_Presentation_GR.pptx
deliverables/AirportDW_Dashboard.pbix
deliverables/airportdw_schema.png
```

## Not Included

The raw `airportdb` dump, teacher slides, generated exports, and local terminal logs are intentionally excluded from this clean repository.

## Demo Refresh Command

```sql
CALL airportdw.refresh_airportdw_next_closed_days();
```

Then refresh Power BI:

```text
Power BI Desktop -> Home -> Refresh
```
