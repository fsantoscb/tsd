# Production Flow Source Mapping
- DTG Picking: workbank `queue = SP11` (validated).
- DTG Printing: workbank `queue = PCOR` (validated).
- DTG Putwall: workbank `from_zone = PWL1` (validated).
- DTG Dispatch: audit `to_location = DTGMOVE` (requires validation).
- UP Picking: stock `location = UNDERPRINT` (validated against existing workbook logic).
- UP Printing: workbank `from_location ends_with UP` (requires validation; never uses broad contains matching).
- UP Dispatch: audit `to_location = UPMOVE` (requires validation).
- Screen Print: manual `screen_print_jobs`; no Oracle mapping is claimed.
