-- Optional MySQL Event Scheduler setup for the closed-business-day DW refresh.
-- Run this only after 05_closed_day_incremental_refresh.sql and initialization.
--
-- Important:
--   This schedules the MySQL/Data Warehouse refresh only.
--   Power BI refresh must be scheduled separately in Power BI Service
--   or refreshed manually in Power BI Desktop.

USE airportdw;

SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS ev_refresh_airportdw_closed_days;

DELIMITER //

CREATE EVENT ev_refresh_airportdw_closed_days
ON SCHEDULE EVERY 1 DAY
STARTS TIMESTAMP(CURRENT_DATE + INTERVAL 1 DAY, '02:30:00')
DO
BEGIN
    CALL airportdw.refresh_airportdw_next_closed_days();
END //

DELIMITER ;

SHOW EVENTS FROM airportdw LIKE 'ev_refresh_airportdw_closed_days';

