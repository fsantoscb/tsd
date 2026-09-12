# Deputy SharePoint automation

## Objective

Import the refreshed `timesheets.xlsx` into the ERP automatically after the existing 06:00 Australia/Brisbane SharePoint update.

## Recommended Power Automate steps

Add these actions after the step that updates the workbook:

1. `Delay`: 2 minutes, so SharePoint finishes committing the workbook.
2. `Get file content using path` (OneDrive for Business): select `timesheets.xlsx`.
3. `HTTP`: `POST https://tsd-production-control.vercel.app/api/ingest/deputy`.
4. Header `Authorization`: `Bearer <INGEST_SECRET>`.
5. Body type: `multipart/form-data`.
6. File field name: `file`; filename: `timesheets.xlsx`; content: output of `Get file content using path`.
7. Text field `timezone`: `Australia/Brisbane`.
8. Configure retry policy to exponential, 3 retries, and notify only if the final request fails.

## Expected responses

- `201 imported`: a new workbook version was imported and segmented.
- `200 duplicate`: that exact workbook was already imported; no labour hours were duplicated.
- `400`: invalid file, format, timezone, or workbook data.
- `401`: missing or incorrect ingestion secret.
- `413`: file exceeds 15 MB.

The import appears in ERP `Production > Deputy` with actor `sharepoint-automation@system`. Invalid rows remain quarantined and do not affect production KPIs.
