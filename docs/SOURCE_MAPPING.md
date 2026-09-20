# Production Flow Source Mapping
- DTG Picking: workbank `queue = SP11` (validated).
- DTG current queue: workbank `queue = PCOR` (validated current WIP; not output authority).
- DTG completed production: Oracle `ISIS_AUDIT`, `TASK = PCOR`, `QUEUE = PCOR`, `FROM_ZONE = DTGS`, `TO_ZONE = PWL1`; grain `AUDIT_ID`, machine `USERNAME`, timestamp `TIMESTAMP` as Brisbane local wall-clock time with no conversion, garments `COUNT(*)`, prints `SUM(QTY * PROD_X_5)` with `1 / 2 = 2`. Performance uses the effective canonical `shift_rules` to derive `shift_code` and shift-start `operational_date`.
- DTG Putwall: workbank `from_zone = PWL1` (validated).
- DTG Dispatch: audit `to_location = DTGMOVE` (requires validation).
- UP Picking: stock `location = UNDERPRINT` (validated against existing workbook logic).
- UP Printing: workbank `from_location ends_with UP` (requires validation; never uses broad contains matching).
- UP Dispatch: audit `to_location = UPMOVE` (requires validation).
- Screen Print: manual `screen_print_jobs`; no Oracle mapping is claimed.
