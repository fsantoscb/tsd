# Business Rule Duplication

## Dangerous business-rule duplication

| Rule | Implementation A | Implementation B | Implementation C | Difference/risk | Canonical recommendation |
|---|---|---|---|---|---|
| Production units | `mapStock`/`mapAudit`: weight else qty | `mapWorkbank`: qty except CARTON uses weight | DECISIONS.md: weight when present else qty | Same item can carry different volume by source/stage | One versioned server policy with reconciliation tests |
| DTG PCOR selection | Workbank requires task PCOR and queue PCOR | Audit accepts queue PCOR OR task PCOR | SOURCE_MAPPING says DTG audit queue PCOR | Audit output can include unrelated task events | Exact classifier shared by extraction and KPI views |
| UP output | SOURCE_MAPPING: UNDERPRINT to any non-UNDERPRINT | Approved flow: `Name + UP` then `UPMOVE` | Audit SQL uses broad non-UNDERPRINT condition | False UP production and dispatch classification | Explicit printing and dispatch predicates |
| Freshness | Batch age fixed at five minutes | Heartbeat state stored separately | UI only displays batch freshness | Connector can be offline while snapshot looks fresh, or vice versa | Combined source-health state machine |
| Organization authorization | Optional `ADMIN_EMAIL` | Caller-supplied `organizationId` | Service-role database access | Authentication, tenancy and ingestion identity are not bound | Signed agent-to-org binding and membership RBAC |
| Audit identity | Unique source audit ID | Unique partial raw hash | Incremental cursor supplied from environment | False dedupe or repeated retrieval can occur | Database-owned watermark plus complete event identity |
| Status | Shared lower-case enum | Raw Oracle status/substatus strings | UI labels | No authoritative mapping connects them | DB mapping and generated shared enum |
| Date/time | Oracle driver date -> JS `Date` | Environment declares Brisbane | UI formatter converts to Brisbane | Environment setting is unused during parsing | Source-zone parser and UTC storage contract |

## Benign UI duplication

| Rule | Locations | Assessment |
|---|---|---|
| Timestamp formatting | Freshness badge and source-data formatter | Benign today, but central formatter would prevent display drift |
| Admin shell links | Shared AppShell | Already centralized |

## Unverifiable duplication in deployed ERP

Machine Load, DTG, UP, Flow, Performance, KPI, Planning, Capacity, Reports and Maintenance implementations are not present locally. Their formulas cannot be compared with each other or with the database. This is itself a release-governance defect: the deployed system is not reproducible from the linked repository.

