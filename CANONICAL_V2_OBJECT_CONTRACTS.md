# Canonical V2 Exact Object Contracts

TOTAL APPLICATION DB DEPENDENCIES = 86

- Runtime required: 86
- Exact contracts complete: 86
- Unresolved: 0
- Current 001 coverage: 5 / 86

## C1.3 divergence resolutions

| # | Object | Type | Domain | Decision | Difference resolved |
|---:|---|---|---|---|---|
| 1 | `public.v_release_queue` | VIEW | A. RELEASE_QUEUE | NEW_CLEAN_CANONICAL | DEV exposes MO/routing coverage but does not match the published result shape. PROD exposes the published shape but is backed by legacy storage. V2 preserves the exact published output and precedence while deriving it from canonical source and E5/E6 structures. |
| 2 | `public.kpi_results` | TABLE_OR_VIEW | H. PRODUCTION / PERFORMANCE | NEW_CLEAN_CANONICAL | Neither legacy copy has unique authority; the clean contract removes snapshot ordering noise while retaining the identical columns, keys, constraints and RLS state. |
| 3 | `public.maintenance_post_inventory` | FUNCTION_RPC | G. MAINTENANCE | NEW_CLEAN_CANONICAL | DEV and PROD differ only in internal PL/pgSQL identifiers/formatting. V2 keeps one clean function with the existing signature and validated stock checks. |
| 4 | `public.maintenance_members` | TABLE_OR_VIEW | I. AUTH / RLS / CONFIG | DEV_CANONICAL | DEV contains the required authenticated self-read RLS policy; PROD has RLS enabled without that policy. DEV is the secure functional contract. |
| 5 | `public.ingest_sync_batch` | FUNCTION_RPC | B. ORACLE_SYNC / INGESTION | MERGED_CANONICAL | DEV has safer organization-scoped serialization and transaction behavior; PROD includes current release-line/source fields. V2 needs both approved behaviors, not either legacy body verbatim. |
| 6 | `public.v_current_orders` | VIEW | B. ORACLE_SYNC / INGESTION | MERGED_CANONICAL | DEV uses canonical source_route_id naming; PROD adds release_source_status. V2 exposes both required semantics with one canonical source_route_id, retaining release_source_status and avoiding duplicate route concepts. |
| 7 | `public.production_events` | TABLE_OR_VIEW | H. PRODUCTION / PERFORMANCE | NEW_CLEAN_CANONICAL | The schemas are semantically identical; V2 freezes the shared exact contract without preserving catalog ordering artifacts. |
| 8 | `public.maintenance_create_component` | FUNCTION_RPC | G. MAINTENANCE | NEW_CLEAN_CANONICAL | DEV and PROD signatures and behavior agree; only implementation formatting differs. |
| 9 | `public.v_production_planning` | VIEW | E. ROUTING / PLANNING | DEV_CANONICAL | DEV retains source-routing context in the planning association; PROD uses the older order-only shortcut. The DEV contract better preserves one Sales Order plus Routing boundaries. |
| 10 | `public.sync_agent_heartbeat` | TABLE_OR_VIEW | B. ORACLE_SYNC / INGESTION | PROD_CANONICAL | Current code writes last_sync_attempt_at, last_success_at, next_expected_sync_at and current_run_id, which only PROD provides. |
| 11 | `public.ingest_audit_backfill` | FUNCTION_RPC | B. ORACLE_SYNC / INGESTION | PROD_CANONICAL | PROD includes the current validated source_audit_events ingestion plus production_events rebuild required by performance. DEV lacks the complete published behavior. |
| 12 | `public.maintenance_create_asset` | FUNCTION_RPC | G. MAINTENANCE | NEW_CLEAN_CANONICAL | DEV and PROD signatures and behavior agree; internal variable names/formatting are not business differences. |
| 13 | `public.resource_capacity_rules` | TABLE_OR_VIEW | H. PRODUCTION / PERFORMANCE | NEW_CLEAN_CANONICAL | Only index definition/order differs. V2 keeps one query-aligned partial lookup index and the identical table contract. |
| 14 | `public.sync_batches` | TABLE_OR_VIEW | B. ORACLE_SYNC / INGESTION | PROD_CANONICAL | PROD adds release_line_count required to audit the authoritative line-level release snapshot; DEV lacks it. |
| 15 | `public.apply_production_planning` | FUNCTION_RPC | E. ROUTING / PLANNING | NEW_CLEAN_CANONICAL | Bodies differ mainly by formatting. V2 freezes one readable implementation with existing signature, transition checks and history. |
| 16 | `public.maintenance_work_orders` | TABLE_OR_VIEW | G. MAINTENANCE | NEW_CLEAN_CANONICAL | The only table difference is physical column order. V2 uses one clean logical order without changing any column contract. |
| 17 | `public.source_workbank_items` | TABLE_OR_VIEW | B. ORACLE_SYNC / INGESTION | MERGED_CANONICAL | Rows are equivalent; DEV adds E6 resolution indexes while PROD has current operational indexes. V2 keeps the shared table and the minimal union of query-required indexes. |

## public.maintenance_part_stock_levels

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT p.organization_id,\n    p.id AS part_id,\n    p.part_number,\n    p.description,\n    p.manufacturer,\n    p.unit_cost,\n    p.reorder_point,\n    l.id AS location_id,\n    l.name AS location,\n    (COALESCE(sum(t.quantity), (0)::numeric))::numeric(14,2) AS stock_on_hand\n   FROM ((maintenance_parts p\n     CROSS JOIN maintenance_inventory_locations l)\n     LEFT JOIN maintenance_inventory_transactions t ON (((t.part_id = p.id) AND (t.location_id = l.id))))\n  WHERE (p.active AND l.active AND (p.organization_id = l.organization_id))\n  GROUP BY p.organization_id, p.id, l.id;",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "part_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "part_number",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "manufacturer",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "unit_cost",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "reorder_point",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "location_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "stock_on_hand",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.staffing_layouts

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/capacity.ts, web/app/production/capacity/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "effective_from",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": "CURRENT_DATE",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "effective_to",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "source",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'USER'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "staffing_layouts_check",
      "constraint_type": "c",
      "definition": "CHECK (effective_to IS NULL OR effective_to >= effective_from)"
    },
    {
      "constraint_name": "staffing_layouts_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "staffing_layouts_organization_id_name_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, name)"
    },
    {
      "constraint_name": "staffing_layouts_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    }
  ],
  "indexes": [
    {
      "index_name": "staffing_layouts_organization_id_name_key",
      "definition": "CREATE UNIQUE INDEX staffing_layouts_organization_id_name_key ON public.staffing_layouts USING btree (organization_id, name)"
    },
    {
      "index_name": "staffing_layouts_pkey",
      "definition": "CREATE UNIQUE INDEX staffing_layouts_pkey ON public.staffing_layouts USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_current_labour_segments

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/labour-dashboard.ts, web/lib/erp-kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " WITH ranked AS (\n         SELECT r_1.id,\n            row_number() OVER (PARTITION BY r_1.organization_id, COALESCE(NULLIF(r_1.source_timesheet_id, ''::text), r_1.source_row_key) ORDER BY b.imported_at DESC, r_1.created_at DESC) AS rn\n           FROM (deputy_raw_timesheets r_1\n             JOIN deputy_import_batches b ON ((b.id = r_1.import_batch_id)))\n          WHERE ((b.status = 'COMPLETED'::text) AND (r_1.row_status = 'ACCEPTED'::text))\n        )\n SELECT s.id,\n    s.organization_id,\n    s.import_batch_id,\n    s.source_timesheet_row_id,\n    s.person_key,\n    s.area_code,\n    s.segment_start,\n    s.segment_end,\n    s.calendar_date,\n    s.operational_date,\n    s.hour_bucket,\n    s.shift_code,\n    s.paid_hours,\n    s.regular_hours,\n    s.overtime_hours,\n    s.paid_break_hours,\n    s.productive_hours,\n    s.approval_status,\n    s.allocation_method,\n    s.week_start,\n    s.calculation_version,\n    s.created_at\n   FROM (labour_segments s\n     JOIN ranked r ON (((r.id = s.source_timesheet_row_id) AND (r.rn = 1))));",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "import_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "source_timesheet_row_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "person_key",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "area_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "segment_start",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "segment_end",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "calendar_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "operational_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "hour_bucket",
      "data_type": "smallint",
      "udt_schema": "pg_catalog",
      "udt_name": "int2",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "shift_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "paid_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "regular_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "overtime_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "paid_break_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "productive_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 18,
      "column_name": "approval_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 19,
      "column_name": "allocation_method",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 20,
      "column_name": "week_start",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 21,
      "column_name": "calculation_version",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 22,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.maintenance_asset_prefixes

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "category_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "prefix",
      "data_type": "character varying",
      "udt_schema": "pg_catalog",
      "udt_name": "varchar",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_asset_prefixes_category_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (category_id) REFERENCES maintenance_asset_categories(id)"
    },
    {
      "constraint_name": "maintenance_asset_prefixes_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_asset_prefixes_organization_id_prefix_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, prefix)"
    },
    {
      "constraint_name": "maintenance_asset_prefixes_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_asset_prefixes_prefix_check",
      "constraint_type": "c",
      "definition": "CHECK (prefix::text ~ '^[A-Z]{2,5}$'::text)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_asset_prefixes_organization_id_prefix_key",
      "definition": "CREATE UNIQUE INDEX maintenance_asset_prefixes_organization_id_prefix_key ON public.maintenance_asset_prefixes USING btree (organization_id, prefix)"
    },
    {
      "index_name": "maintenance_asset_prefixes_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_asset_prefixes_pkey ON public.maintenance_asset_prefixes USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_transition_work_order

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text",
      "result": "void",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_transition_work_order(p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare old text;a uuid;begin select status,asset_id into old,a from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;if p_status='completed'and nullif(trim(p_resolution),'')is null then raise exception'Resolution required';end if;update maintenance_work_orders set status=p_status,root_cause=coalesce(nullif(trim(p_root_cause),''),root_cause),resolution=coalesce(nullif(trim(p_resolution),''),resolution),started_at=case when p_status='in_progress'then coalesce(started_at,now())else started_at end,completed_at=case when p_status='completed'then now()else completed_at end,updated_at=now()where id=p_work_order_id;insert into maintenance_work_order_history values(gen_random_uuid(),p_organization_id,p_work_order_id,old,p_status,p_actor_id,p_actor_email,now());if p_status='completed'then update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=p_work_order_id and ended_at is null;update maintenance_assets set status='operational',updated_at=now()where id=a and not exists(select 1 from maintenance_downtime_events where asset_id=a and ended_at is null);elsif p_status='in_progress'then update maintenance_assets set status='maintenance',updated_at=now()where id=a and status<>'down';end if;end$function$\n"
    },
    {
      "arguments": "p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text, p_cancel_reason text",
      "result": "void",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_transition_work_order(p_organization_id uuid, p_work_order_id uuid, p_status text, p_root_cause text, p_resolution text, p_actor_id uuid, p_actor_email text, p_cancel_reason text DEFAULT NULL::text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare old text;a uuid;allowed boolean:=false;begin select status,asset_id into old,a from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;allowed:=case old when'open'then p_status in('open','in_progress','cancelled')when'in_progress'then p_status in('in_progress','waiting_parts','waiting_external','completed')when'waiting_parts'then p_status in('waiting_parts','in_progress','cancelled')when'waiting_external'then p_status in('waiting_external','in_progress','cancelled')else p_status=old end;if not allowed then raise exception'Invalid work order transition';end if;if p_status='completed'and nullif(trim(p_resolution),'')is null then raise exception'Resolution required';end if;if p_status='cancelled'and nullif(trim(p_cancel_reason),'')is null then raise exception'Cancellation reason required';end if;update maintenance_work_orders set status=p_status,root_cause=coalesce(nullif(trim(p_root_cause),''),root_cause),resolution=coalesce(nullif(trim(p_resolution),''),resolution),cancel_reason=coalesce(nullif(trim(p_cancel_reason),''),cancel_reason),started_at=case when p_status='in_progress'then coalesce(started_at,now())else started_at end,completed_at=case when p_status='completed'then now()else completed_at end,updated_at=now()where id=p_work_order_id;if old<>p_status then insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,p_work_order_id,old,p_status,p_actor_id,p_actor_email);end if;if p_status='completed'then update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=p_work_order_id and ended_at is null;update maintenance_assets set status='operational',updated_at=now()where id=a and not exists(select 1 from maintenance_downtime_events where asset_id=a and ended_at is null);elsif p_status='in_progress'then update maintenance_assets set status='maintenance',updated_at=now()where id=a and status<>'down';end if;end$function$\n"
    }
  ]
}
```

## public.maintenance_parts

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/app/maintenance/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "part_number",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "manufacturer",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "unit_cost",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "reorder_point",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_parts_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_parts_organization_id_part_number_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, part_number)"
    },
    {
      "constraint_name": "maintenance_parts_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_parts_organization_id_part_number_key",
      "definition": "CREATE UNIQUE INDEX maintenance_parts_organization_id_part_number_key ON public.maintenance_parts USING btree (organization_id, part_number)"
    },
    {
      "index_name": "maintenance_parts_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_parts_pkey ON public.maintenance_parts USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_generate_due_pm

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_actor_id uuid, p_actor_email text",
      "result": "integer",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_generate_due_pm(p_organization_id uuid, p_actor_id uuid, p_actor_email text)\n RETURNS integer\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare p record;w uuid;n text;made integer:=0;begin for p in select*from maintenance_preventive_plans where organization_id=p_organization_id and active and trigger_type='calendar'and next_due_at<=now()+(lead_time_days||' days')::interval and not exists(select 1 from maintenance_work_orders where preventive_plan_id=maintenance_preventive_plans.id and status not in('completed','cancelled'))for update skip locked loop n='WO-'||extract(year from now()at time zone'Australia/Brisbane')::int||'-'||lpad(nextval('maintenance_work_order_seq')::text,6,'0');insert into maintenance_work_orders(organization_id,work_order_number,asset_id,work_order_type,preventive_plan_id,status,priority,title,problem_description,requested_by,requested_by_email,due_at)values(p_organization_id,n,p.asset_id,'preventive',p.id,'open',p.priority,p.name,p.description,p_actor_id,p_actor_email,p.next_due_at)returning id into w;insert into maintenance_work_order_checklist(organization_id,work_order_id,sequence,task,instructions,required)select p_organization_id,w,sequence,task,instructions,required from maintenance_preventive_plan_tasks where preventive_plan_id=p.id;insert into maintenance_work_order_history(organization_id,work_order_id,to_status,changed_by,changed_by_email)values(p_organization_id,w,'open',p_actor_id,p_actor_email);made:=made+1;end loop;return made;end$function$\n"
    }
  ]
}
```

## public.transition_daily_plan

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/production/plans/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_plan_id uuid, p_action text, p_actor_id uuid, p_actor_email text",
      "result": "void",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.transition_daily_plan(p_plan_id uuid, p_action text, p_actor_id uuid, p_actor_email text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare stat text;items integer;begin select status into stat from production_plans where id=p_plan_id for update;select count(*)into items from production_plan_items where production_plan_id=p_plan_id;if p_action='publish'then if stat<>'draft'or items=0 then raise exception 'Only non-empty drafts can be published';end if;update production_plans set status='published',published_by=p_actor_id,published_at=now(),updated_at=now()where id=p_plan_id;elsif p_action='close'then if stat<>'published'then raise exception 'Only published plans can be closed';end if;update production_plans set status='closed',closed_by=p_actor_id,closed_at=now(),updated_at=now()where id=p_plan_id;else raise exception 'Invalid action';end if;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select p_plan_id,p_action,p_actor_id,p_actor_email,to_jsonb(p)from production_plans p where id=p_plan_id;end$function$\n"
    }
  ]
}
```

## public.sync_runs

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** PRODUCTION

**USED BY:** web/lib/sync-health.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "refresh_request_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "trigger_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "requested_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "started_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "completed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "duration_ms",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "agent_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "connector_version",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "orders_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "workbank_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "stock_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "audit_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "failure_reason",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "sync_runs_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "sync_runs_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "sync_runs_refresh_request_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (refresh_request_id) REFERENCES sync_refresh_requests(id)"
    },
    {
      "constraint_name": "sync_runs_status_check",
      "constraint_type": "c",
      "definition": "CHECK (status = ANY (ARRAY['QUEUED'::text, 'RUNNING'::text, 'SUCCESS'::text, 'FAILED'::text, 'SKIPPED_ALREADY_RUNNING'::text]))"
    },
    {
      "constraint_name": "sync_runs_trigger_type_check",
      "constraint_type": "c",
      "definition": "CHECK (trigger_type = ANY (ARRAY['AUTOMATIC'::text, 'MANUAL'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "sync_runs_pkey",
      "definition": "CREATE UNIQUE INDEX sync_runs_pkey ON public.sync_runs USING btree (id)"
    },
    {
      "index_name": "sync_runs_recent_idx",
      "definition": "CREATE INDEX sync_runs_recent_idx ON public.sync_runs USING btree (organization_id, requested_at DESC)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_asset_current_installations

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/reliability-dashboard.ts, web/lib/operator-maintenance.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT i.id,\n    i.organization_id,\n    i.movement_id,\n    i.movable_asset_id,\n    i.host_asset_id,\n    i.host_system_asset_id,\n    i.\"position\",\n    i.channel,\n    i.installed_at,\n    i.removed_at,\n    i.movement_reason,\n    i.installed_by,\n    i.notes,\n    i.created_at,\n    i.updated_at,\n    m.asset_code AS movable_asset_code,\n    h.asset_code AS host_asset_code,\n    s.asset_code AS host_system_asset_code\n   FROM (((maintenance_asset_installations i\n     JOIN maintenance_assets m ON ((m.id = i.movable_asset_id)))\n     JOIN maintenance_assets h ON ((h.id = i.host_asset_id)))\n     LEFT JOIN maintenance_assets s ON ((s.id = i.host_system_asset_id)))\n  WHERE (i.removed_at IS NULL);",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "movement_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "movable_asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "host_asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "host_system_asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "position",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "channel",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "installed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "removed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "movement_reason",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "installed_by",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "notes",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "movable_asset_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "host_asset_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 18,
      "column_name": "host_system_asset_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.kpi_targets

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/kpis.ts, web/app/kpis/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "kpi_definition_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "shift_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "effective_from",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "effective_to",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "target_value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "warning_value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "critical_value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "created_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "kpi_targets_check",
      "constraint_type": "c",
      "definition": "CHECK (effective_to IS NULL OR effective_to >= effective_from)"
    },
    {
      "constraint_name": "kpi_targets_kpi_definition_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (kpi_definition_id) REFERENCES kpi_definitions(id)"
    },
    {
      "constraint_name": "kpi_targets_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "kpi_targets_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "kpi_targets_production_area_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_area_id) REFERENCES production_areas(id)"
    },
    {
      "constraint_name": "kpi_targets_shift_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (shift_id) REFERENCES shift_templates(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "kpi_targets_effective_idx",
      "definition": "CREATE INDEX kpi_targets_effective_idx ON public.kpi_targets USING btree (organization_id, kpi_definition_id, effective_from DESC)"
    },
    {
      "index_name": "kpi_targets_pkey",
      "definition": "CREATE UNIQUE INDEX kpi_targets_pkey ON public.kpi_targets USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_work_order_labor

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/lib/reliability-dashboard.ts, web/app/maintenance/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "work_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "user_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "technician_email",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "minutes",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "hourly_rate_snapshot",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_work_order_labor_minutes_check",
      "constraint_type": "c",
      "definition": "CHECK (minutes > 0)"
    },
    {
      "constraint_name": "maintenance_work_order_labor_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_work_order_labor_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_work_order_labor_work_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_labor_wo_idx",
      "definition": "CREATE INDEX maintenance_labor_wo_idx ON public.maintenance_work_order_labor USING btree (work_order_id, created_at)"
    },
    {
      "index_name": "maintenance_work_order_labor_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_work_order_labor_pkey ON public.maintenance_work_order_labor USING btree (id)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "audit_change",
      "definition": "CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_work_order_labor FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_kpi_trends

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " WITH daily_base AS (\n         SELECT DISTINCT ON (r.kpi_definition_id, r.production_date, COALESCE(r.production_area_id, '00000000-0000-0000-0000-000000000000'::uuid)) r.organization_id,\n            r.kpi_definition_id,\n            r.production_area_id,\n            r.production_date,\n            r.value\n           FROM kpi_results r\n          WHERE (r.value IS NOT NULL)\n          ORDER BY r.kpi_definition_id, r.production_date, COALESCE(r.production_area_id, '00000000-0000-0000-0000-000000000000'::uuid), r.calculated_at DESC\n        ), periods AS (\n         SELECT daily_base.organization_id,\n            daily_base.kpi_definition_id,\n            daily_base.production_area_id,\n            'DAILY'::text AS period_type,\n            daily_base.production_date AS period_start,\n            daily_base.production_date AS period_end,\n            (1)::bigint AS points,\n            daily_base.value AS latest_value,\n            daily_base.value AS average_value,\n            daily_base.value AS minimum_value,\n            daily_base.value AS maximum_value\n           FROM daily_base\n        UNION ALL\n         SELECT daily_base.organization_id,\n            daily_base.kpi_definition_id,\n            daily_base.production_area_id,\n            'WEEKLY'::text,\n            (date_trunc('week'::text, (daily_base.production_date)::timestamp with time zone))::date AS date_trunc,\n            ((date_trunc('week'::text, (daily_base.production_date)::timestamp with time zone) + '6 days'::interval))::date AS date,\n            count(*) AS count,\n            (array_agg(daily_base.value ORDER BY daily_base.production_date DESC))[1] AS array_agg,\n            avg(daily_base.value) AS avg,\n            min(daily_base.value) AS min,\n            max(daily_base.value) AS max\n           FROM daily_base\n          GROUP BY daily_base.organization_id, daily_base.kpi_definition_id, daily_base.production_area_id, (date_trunc('week'::text, (daily_base.production_date)::timestamp with time zone))\n        UNION ALL\n         SELECT daily_base.organization_id,\n            daily_base.kpi_definition_id,\n            daily_base.production_area_id,\n            'MONTHLY'::text,\n            (date_trunc('month'::text, (daily_base.production_date)::timestamp with time zone))::date AS date_trunc,\n            ((date_trunc('month'::text, (daily_base.production_date)::timestamp with time zone) + '1 mon -1 days'::interval))::date AS date,\n            count(*) AS count,\n            (array_agg(daily_base.value ORDER BY daily_base.production_date DESC))[1] AS array_agg,\n            avg(daily_base.value) AS avg,\n            min(daily_base.value) AS min,\n            max(daily_base.value) AS max\n           FROM daily_base\n          GROUP BY daily_base.organization_id, daily_base.kpi_definition_id, daily_base.production_area_id, (date_trunc('month'::text, (daily_base.production_date)::timestamp with time zone))\n        ), compared AS (\n         SELECT p.organization_id,\n            p.kpi_definition_id,\n            p.production_area_id,\n            p.period_type,\n            p.period_start,\n            p.period_end,\n            p.points,\n            p.latest_value,\n            p.average_value,\n            p.minimum_value,\n            p.maximum_value,\n            lag(p.latest_value) OVER (PARTITION BY p.organization_id, p.kpi_definition_id, p.production_area_id, p.period_type ORDER BY p.period_start) AS previous_value\n           FROM periods p\n        )\n SELECT organization_id,\n    kpi_definition_id,\n    production_area_id,\n    period_type,\n    period_start,\n    period_end,\n    points,\n    latest_value,\n    average_value,\n    minimum_value,\n    maximum_value,\n    previous_value,\n    (latest_value - previous_value) AS absolute_change,\n        CASE\n            WHEN (previous_value = (0)::numeric) THEN NULL::numeric\n            ELSE round((((latest_value - previous_value) / abs(previous_value)) * (100)::numeric), 2)\n        END AS percentage_change\n   FROM compared c;",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "kpi_definition_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "period_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "period_start",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "period_end",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "points",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "latest_value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "average_value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "minimum_value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "maximum_value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "previous_value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "absolute_change",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "percentage_change",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.production_plan_history

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/daily-plans.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "production_plan_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "action",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "changed_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "changed_by_email",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "changed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "snapshot",
      "data_type": "jsonb",
      "udt_schema": "pg_catalog",
      "udt_name": "jsonb",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "production_plan_history_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "production_plan_history_production_plan_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_plan_id) REFERENCES production_plans(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "production_plan_history_pkey",
      "definition": "CREATE UNIQUE INDEX production_plan_history_pkey ON public.production_plan_history USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.create_daily_plan

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/production/plans/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_production_date date, p_shift_id uuid, p_area_id uuid, p_actor_id uuid, p_actor_email text",
      "result": "uuid",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.create_daily_plan(p_organization_id uuid, p_production_date date, p_shift_id uuid, p_area_id uuid, p_actor_id uuid, p_actor_email text)\n RETURNS uuid\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare result uuid;begin if not exists(select 1 from shift_templates where id=p_shift_id and organization_id=p_organization_id and active)then raise exception 'Invalid shift';end if;if not exists(select 1 from production_areas where id=p_area_id and organization_id=p_organization_id and active and code<>'UNMAPPED')then raise exception 'Invalid area';end if;insert into production_plans(organization_id,production_date,shift_template_id,production_area_id,created_by)values(p_organization_id,p_production_date,p_shift_id,p_area_id,p_actor_id)returning id into result;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select result,'created',p_actor_id,p_actor_email,to_jsonb(p)from production_plans p where id=result;return result;end$function$\n"
    }
  ]
}
```

## public.v_latest_completed_batch

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/erp-kpis.ts, web/lib/source-data.ts, web/lib/production-flow-kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT DISTINCT ON (organization_id) id,\n    organization_id,\n    started_at,\n    completed_at,\n    status,\n    orders_count,\n    workbank_count,\n    stock_count,\n    audit_new_count,\n    error_message,\n    connector_version,\n    created_at\n   FROM sync_batches\n  WHERE (status = 'completed'::text)\n  ORDER BY organization_id, completed_at DESC;",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "started_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "completed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "orders_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "workbank_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "stock_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "audit_new_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "error_message",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "connector_version",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.organizations

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/ingest.ts, web/lib/planning.ts, web/app/api/sync/refresh/route.ts, web/app/api/ingest/deputy/route.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** PRESENT - validate/replace against this contract

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "timezone",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'Australia/Brisbane'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "organizations_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    }
  ],
  "indexes": [
    {
      "index_name": "organizations_pkey",
      "definition": "CREATE UNIQUE INDEX organizations_pkey ON public.organizations USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_release_queue

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** NEW_CLEAN_CANONICAL

**DOMAIN:** A. RELEASE_QUEUE

**USED BY:** web/lib/release-queue.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** DEV exposes MO/routing coverage but does not match the published result shape. PROD exposes the published shape but is backed by legacy storage. V2 preserves the exact published output and precedence while deriving it from canonical source and E5/E6 structures.

**DECISION EVIDENCE:** Published Release Queue result contract plus validated E5/E6 release authority

**SOURCE OF TRUTH:** Canonical source-order evidence and canonical release/demand resolution

**READ CONTRACT:** One row per Sales Order with current source identity, process quantities, all blockers, diagnostic state, release state and snapshot timestamp. Output columns follow the current application ReleaseQueueRow contract.

**WRITE CONTRACT:** Read-only view; no direct writes.

**LIFECYCLE:** Recomputed from current authoritative snapshot and canonical release state.

**IDEMPOTENCY:** Same source snapshot and canonical mappings return the same row and blocker set.

**BUSINESS INVARIANTS:**
- Statuses are ELIGIBLE, NOT_APPROVED, BLOCKED, FUTURE_DUE or UNKNOWN
- NOT_APPROVED precedence is preserved while every blocker remains visible
- ROUTE_BLOCKED, STOP_SHIP and CUSTOM_EMB may coexist
- zero production is diagnostic and does not silently disappear
- Oracle remains read-only

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT id,\n    organization_id,\n    sync_batch_id,\n    order_no,\n    date_received,\n    date_due,\n    date_released,\n    source_status,\n    source_sub_status,\n    customer_code,\n    customer_name,\n    ship_to_name,\n    customer_state,\n    city,\n    delivery_desc,\n    client_so_number,\n    source_priority,\n    source_updated_at,\n    created_at,\n    site,\n    route_id,\n    cost_centre,\n    stop_ship_flag,\n    release_source_status,\n    snapshot_completed_at,\n    dtg_qty,\n    underprint_qty,\n    uv_qty,\n    hats_qty,\n    finished_qty,\n    stickers_qty,\n    visual_qty,\n    production_qty,\n    custom_emb_qty,\n    eyewear_qty,\n    total_process_qty,\n    release_blockers,\n    diagnostic_status,\n    release_status\n   FROM v_release_queue_all\n  WHERE (total_process_qty > (0)::numeric);",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "sync_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "date_received",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "date_due",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "date_released",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "source_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "source_sub_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "customer_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "ship_to_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "customer_state",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "city",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "delivery_desc",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "client_so_number",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "source_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 18,
      "column_name": "source_updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 19,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 20,
      "column_name": "site",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 21,
      "column_name": "route_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 22,
      "column_name": "cost_centre",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 23,
      "column_name": "stop_ship_flag",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 24,
      "column_name": "release_source_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 25,
      "column_name": "snapshot_completed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 26,
      "column_name": "dtg_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 27,
      "column_name": "underprint_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 28,
      "column_name": "uv_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 29,
      "column_name": "hats_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 30,
      "column_name": "finished_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 31,
      "column_name": "stickers_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 32,
      "column_name": "visual_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 33,
      "column_name": "production_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 34,
      "column_name": "custom_emb_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 35,
      "column_name": "eyewear_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 36,
      "column_name": "total_process_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 37,
      "column_name": "release_blockers",
      "data_type": "ARRAY",
      "udt_schema": "pg_catalog",
      "udt_name": "_text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 38,
      "column_name": "diagnostic_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 39,
      "column_name": "release_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.kpi_results

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** NEW_CLEAN_CANONICAL

**DOMAIN:** H. PRODUCTION / PERFORMANCE

**USED BY:** web/lib/kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** Neither legacy copy has unique authority; the clean contract removes snapshot ordering noise while retaining the identical columns, keys, constraints and RLS state.

**DECISION EVIDENCE:** DEV and PROD are structurally and semantically equivalent

**SOURCE OF TRUTH:** Calculated KPI engine results

**READ CONTRACT:** KPI detail reads result rows by kpi_definition_id ordered by calculated_at.

**WRITE CONTRACT:** KPI calculation/upsert path only.

**LIFECYCLE:** Append or replace by calculation period according to KPI engine.

**IDEMPOTENCY:** Natural KPI grain prevents duplicate results for one calculation context.

**BUSINESS INVARIANTS:**
- numerator, denominator, value and target remain auditable
- organization and KPI definition are mandatory

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "kpi_definition_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "period_start",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "period_end",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "production_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "shift_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "machine_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "operator_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "product_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "numerator",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "denominator",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "target_value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "data_quality_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "source_refresh_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 20,
      "column_name": "calculated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "kpi_results_data_quality_status_check",
      "constraint_type": "c",
      "definition": "CHECK (data_quality_status = ANY (ARRAY['NO_DATA'::text, 'PARTIAL_DATA'::text, 'STALE_DATA'::text, 'VALID'::text]))"
    },
    {
      "constraint_name": "kpi_results_kpi_definition_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (kpi_definition_id) REFERENCES kpi_definitions(id)"
    },
    {
      "constraint_name": "kpi_results_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "kpi_results_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "kpi_results_production_area_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_area_id) REFERENCES production_areas(id)"
    },
    {
      "constraint_name": "kpi_results_shift_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (shift_id) REFERENCES shift_templates(id)"
    },
    {
      "constraint_name": "kpi_results_status_check",
      "constraint_type": "c",
      "definition": "CHECK (status = ANY (ARRAY['GOOD'::text, 'WARNING'::text, 'CRITICAL'::text, 'NO_TARGET'::text, 'NO_DATA'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "kpi_results_latest_idx",
      "definition": "CREATE INDEX kpi_results_latest_idx ON public.kpi_results USING btree (organization_id, kpi_definition_id, calculated_at DESC)"
    },
    {
      "index_name": "kpi_results_pkey",
      "definition": "CREATE UNIQUE INDEX kpi_results_pkey ON public.kpi_results USING btree (id)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "kpi_result_target_status",
      "definition": "CREATE TRIGGER kpi_result_target_status BEFORE INSERT ON kpi_results FOR EACH ROW EXECUTE FUNCTION apply_kpi_target_status()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_dtg_order_history

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/source-data.ts, web/lib/performance-workload.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT order_no,\n    count(*) FILTER (WHERE ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text))) AS printed,\n    min(event_at) FILTER (WHERE ((upper(from_zone) = 'PG11'::text) AND (upper(to_zone) = 'DTGS'::text))) AS first_pick,\n    min(event_at) FILTER (WHERE ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text))) AS first_print,\n    max(event_at) FILTER (WHERE ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text))) AS last_print\n   FROM source_audit_events\n  WHERE (((upper(from_zone) = 'PG11'::text) AND (upper(to_zone) = 'DTGS'::text)) OR ((upper(from_zone) = 'DTGS'::text) AND (upper(to_zone) = 'PWL1'::text)))\n  GROUP BY order_no;",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "printed",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "first_pick",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "first_print",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "last_print",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.v_up_operational_orders

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/performance-workload.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " WITH stock AS (\n         SELECT s_1.organization_id,\n            regexp_replace(s_1.product, '^#'::text, ''::text) AS order_no,\n            count(*) AS box_count,\n            sum(s_1.production_units) AS remaining_units,\n            min(s_1.source_timestamp) AS last_movement\n           FROM v_current_stock s_1\n          WHERE (upper(COALESCE(s_1.location, ''::text)) = 'UNDERPRINT'::text)\n          GROUP BY s_1.organization_id, (regexp_replace(s_1.product, '^#'::text, ''::text))\n        ), putwall AS (\n         SELECT v_current_workbank.organization_id,\n            v_current_workbank.order_no,\n            string_agg(DISTINCT COALESCE(NULLIF(v_current_workbank.to_location, ''::text), v_current_workbank.from_location), ', '::text ORDER BY COALESCE(NULLIF(v_current_workbank.to_location, ''::text), v_current_workbank.from_location)) AS putwall_locations\n           FROM v_current_workbank\n          WHERE (upper(COALESCE(v_current_workbank.from_zone, ''::text)) = 'PWL1'::text)\n          GROUP BY v_current_workbank.organization_id, v_current_workbank.order_no\n        )\n SELECT s.organization_id,\n    s.order_no,\n    o.customer_name,\n    o.delivery_desc AS screen,\n    o.source_status AS status,\n    o.source_priority AS priority,\n    o.date_due,\n    GREATEST(0, (((now() AT TIME ZONE 'Australia/Brisbane'::text))::date - ((o.date_released AT TIME ZONE 'Australia/Brisbane'::text))::date)) AS age_days,\n    s.box_count AS item_count,\n    s.remaining_units,\n    s.last_movement,\n    p.putwall_locations,\n    'At UP'::text AS progress_label,\n    NULL::numeric AS total_prints,\n    NULL::numeric AS adult_prints,\n    NULL::numeric AS kids_prints,\n    NULL::numeric AS unclassified_prints\n   FROM ((stock s\n     LEFT JOIN v_current_orders o ON (((o.organization_id = s.organization_id) AND (o.order_no = s.order_no))))\n     LEFT JOIN putwall p ON (((p.organization_id = s.organization_id) AND (p.order_no = s.order_no))));",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "screen",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "date_due",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "age_days",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "item_count",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "remaining_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "last_movement",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "putwall_locations",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "progress_label",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "total_prints",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "adult_prints",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "kids_prints",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "unclassified_prints",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.add_daily_plan_items

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/production/plans/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_plan_id uuid, p_order_nos text[], p_actor_id uuid, p_actor_email text",
      "result": "integer",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.add_daily_plan_items(p_plan_id uuid, p_order_nos text[], p_actor_id uuid, p_actor_email text)\n RETURNS integer\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare p production_plans%rowtype;n text;po production_orders%rowtype;units numeric;seq integer;added integer:=0;begin select*into p from production_plans where id=p_plan_id for update;if p.id is null then raise exception 'Plan not found';end if;if p.status<>'draft'then raise exception 'Only drafts can be edited';end if;select coalesce(max(sequence),0)into seq from production_plan_items where production_plan_id=p_plan_id;foreach n in array p_order_nos loop select*into po from production_orders where organization_id=p.organization_id and order_no=n and planning_status in('planned','ready','in_progress');if po.id is null then raise exception 'Order % is not planned',n;end if;select remaining_units into units from v_production_planning where organization_id=p.organization_id and order_no=n and line=(select code from production_areas where id=p.production_area_id)limit 1;if units is null or units<=0 then raise exception 'Order unavailable in area';end if;seq=seq+1;insert into production_plan_items(production_plan_id,production_order_id,order_no,sequence,planned_units,special_instruction)values(p_plan_id,po.id,n,seq,units,po.special_instruction)on conflict(production_plan_id,production_order_id)do nothing;if found then added=added+1;end if;end loop;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)values(p_plan_id,'items_added',p_actor_id,p_actor_email,jsonb_build_object('orders',p_order_nos,'added',added));return added;end$function$\n"
    }
  ]
}
```

## public.staffing_layout_lines

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/capacity.ts, web/app/production/capacity/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "staffing_layout_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "shift_template_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "day_of_week",
      "data_type": "smallint",
      "udt_schema": "pg_catalog",
      "udt_name": "int2",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "operator_count",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "machine_count",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "scheduled_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "hourly_rate",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "efficiency",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "staffing_layout_lines_day_of_week_check",
      "constraint_type": "c",
      "definition": "CHECK (day_of_week >= 1 AND day_of_week <= 7)"
    },
    {
      "constraint_name": "staffing_layout_lines_efficiency_check",
      "constraint_type": "c",
      "definition": "CHECK (efficiency >= 0::numeric AND efficiency <= 1::numeric)"
    },
    {
      "constraint_name": "staffing_layout_lines_hourly_rate_check",
      "constraint_type": "c",
      "definition": "CHECK (hourly_rate >= 0::numeric)"
    },
    {
      "constraint_name": "staffing_layout_lines_machine_count_check",
      "constraint_type": "c",
      "definition": "CHECK (machine_count >= 0::numeric)"
    },
    {
      "constraint_name": "staffing_layout_lines_operator_count_check",
      "constraint_type": "c",
      "definition": "CHECK (operator_count >= 0::numeric)"
    },
    {
      "constraint_name": "staffing_layout_lines_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "staffing_layout_lines_production_area_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_area_id) REFERENCES production_areas(id)"
    },
    {
      "constraint_name": "staffing_layout_lines_scheduled_hours_check",
      "constraint_type": "c",
      "definition": "CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric)"
    },
    {
      "constraint_name": "staffing_layout_lines_shift_template_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id)"
    },
    {
      "constraint_name": "staffing_layout_lines_staffing_layout_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (staffing_layout_id) REFERENCES staffing_layouts(id) ON DELETE CASCADE"
    }
  ],
  "indexes": [
    {
      "index_name": "staffing_layout_line_context",
      "definition": "CREATE UNIQUE INDEX staffing_layout_line_context ON public.staffing_layout_lines USING btree (staffing_layout_id, production_area_id, shift_template_id, COALESCE((day_of_week)::integer, 0))"
    },
    {
      "index_name": "staffing_layout_lines_pkey",
      "definition": "CREATE UNIQUE INDEX staffing_layout_lines_pkey ON public.staffing_layout_lines USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.source_stock_items

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/source-data.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** PRESENT - validate/replace against this contract

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "sync_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "product",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "pack_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "source_timestamp",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "source_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "source_weight",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "production_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "source_zone",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "source_stock_items_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "source_stock_items_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "source_stock_items_sync_batch_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "source_stock_batch_location_idx",
      "definition": "CREATE INDEX source_stock_batch_location_idx ON public.source_stock_items USING btree (sync_batch_id, location)"
    },
    {
      "index_name": "source_stock_items_pkey",
      "definition": "CREATE UNIQUE INDEX source_stock_items_pkey ON public.source_stock_items USING btree (id)"
    },
    {
      "index_name": "source_stock_location_idx",
      "definition": "CREATE INDEX source_stock_location_idx ON public.source_stock_items USING btree (location)"
    },
    {
      "index_name": "source_stock_pack_idx",
      "definition": "CREATE INDEX source_stock_pack_idx ON public.source_stock_items USING btree (pack_id)"
    },
    {
      "index_name": "source_stock_product_idx",
      "definition": "CREATE INDEX source_stock_product_idx ON public.source_stock_items USING btree (product)"
    },
    {
      "index_name": "source_stock_zone_idx",
      "definition": "CREATE INDEX source_stock_zone_idx ON public.source_stock_items USING btree (source_zone)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "source_stock_batch_organization",
      "definition": "CREATE TRIGGER source_stock_batch_organization BEFORE INSERT OR UPDATE OF organization_id, sync_batch_id ON source_stock_items FOR EACH ROW EXECUTE FUNCTION enforce_sync_batch_organization()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.production_plans

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/plan-actual.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "production_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "shift_template_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'draft'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "version",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "1",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "created_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "published_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "published_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "closed_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "closed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "production_plans_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "production_plans_organization_id_production_date_shift_temp_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, production_date, shift_template_id, production_area_id)"
    },
    {
      "constraint_name": "production_plans_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "production_plans_production_area_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_area_id) REFERENCES production_areas(id)"
    },
    {
      "constraint_name": "production_plans_shift_template_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id)"
    },
    {
      "constraint_name": "production_plans_status_check",
      "constraint_type": "c",
      "definition": "CHECK (status = ANY (ARRAY['draft'::text, 'published'::text, 'closed'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "production_plans_organization_id_production_date_shift_temp_key",
      "definition": "CREATE UNIQUE INDEX production_plans_organization_id_production_date_shift_temp_key ON public.production_plans USING btree (organization_id, production_date, shift_template_id, production_area_id)"
    },
    {
      "index_name": "production_plans_pkey",
      "definition": "CREATE UNIQUE INDEX production_plans_pkey ON public.production_plans USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_import_history

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/api/maintenance/import-history/route.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_file_name text, p_file_hash text, p_assets jsonb, p_events jsonb, p_report jsonb",
      "result": "jsonb",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_import_history(p_organization_id uuid, p_file_name text, p_file_hash text, p_assets jsonb, p_events jsonb, p_report jsonb)\n RETURNS jsonb\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare b uuid;r jsonb;a uuid;h uuid;s uuid;ph uuid;ins integer:=0;upd integer:=0;begin\r\n insert into maintenance_import_batches(organization_id,file_name,file_hash,source_system,status,total_rows,valid_rows,warning_rows,error_rows,import_report)\r\n values(p_organization_id,p_file_name,p_file_hash,'ERP_MAINTENANCE_HISTORY','IMPORTING',jsonb_array_length(p_events),(p_report->>'valid_rows')::int,(p_report->>'warning_rows')::int,(p_report->>'error_rows')::int,p_report)\r\n on conflict(organization_id,file_hash)do update set import_report=excluded.import_report returning id into b;\r\n if exists(select 1 from maintenance_import_batches where id=b and status='COMPLETED')then return jsonb_build_object('batch_id',b,'status','duplicate');end if;\r\n if coalesce((p_report->>'error_rows')::int,0)>0 then raise exception 'Blocking dry-run errors remain';end if;\r\n for r in select * from jsonb_array_elements(p_assets)loop\r\n  insert into maintenance_assets(organization_id,asset_code,name,asset_name,parent_asset_id,asset_kind,asset_type,asset_category,status,active,notes)\r\n  values(p_organization_id,r->>'asset_code',r->>'asset_name',r->>'asset_name',\r\n   (select id from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'parent_asset_code','')),\r\n   coalesce(r->>'asset_kind','FIXED'),r->>'asset_type',r->>'category',\r\n   case upper(coalesce(r->>'status','ACTIVE'))when 'ACTIVE'then'operational'when'STORED'then'standby'when'UNDER_MAINTENANCE'then'maintenance'when'SCRAPPED'then'scrapped'else'retired'end,\r\n   upper(coalesce(r->>'status','ACTIVE'))not in('RETIRED','SCRAPPED'),r->>'notes')\r\n  on conflict(organization_id,asset_code)do update set name=excluded.name,asset_name=excluded.asset_name,\r\n   asset_kind=excluded.asset_kind,asset_type=coalesce(excluded.asset_type,maintenance_assets.asset_type),\r\n   asset_category=coalesce(excluded.asset_category,maintenance_assets.asset_category),\r\n   notes=coalesce(excluded.notes,maintenance_assets.notes),updated_at=now();\r\n end loop;\r\n for r in select * from jsonb_array_elements(p_events)loop\r\n  select id into h from maintenance_assets where organization_id=p_organization_id and asset_code=r->>'parent_asset_code';\r\n  select id into a from maintenance_assets where organization_id=p_organization_id and asset_code=r->>'asset_code';\r\n  select id into s from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'host_print_system_code','');\r\n  select id into ph from maintenance_assets where organization_id=p_organization_id and asset_code=nullif(r->>'ph_asset_code','') and asset_kind='MOVABLE';\r\n  if h is null or a is null then raise exception 'Unresolved required asset at source row %',r->>'source_row';end if;\r\n  insert into maintenance_import_staging(batch_id,organization_id,source_row,row_status,source_key,host_asset_code,affected_asset_code,historical_asset_reference,payload)\r\n  values(b,p_organization_id,(r->>'source_row')::int,case when ph is null and nullif(r->>'ph_reference','')is not null then'UNRESOLVED_PH'else'VALID'end,\r\n   r->>'source_key',r->>'parent_asset_code',r->>'ph_asset_code',r->>'ph_reference',r);\r\n  if exists(select 1 from maintenance_downtime_events where organization_id=p_organization_id and source_system=r->>'source_system' and source_key=r->>'source_key')then upd:=upd+1;else ins:=ins+1;end if;\r\n  insert into maintenance_downtime_events(organization_id,asset_id,event_code,event_date,host_asset_id,host_system_asset_id,affected_asset_id,\r\n   started_at,ended_at,downtime_minutes,event_type,maintenance_class,failure_category,failure_mode,root_cause,action_taken,spare_parts_text,\r\n   description,counts_as_failure,counts_as_downtime,event_status,source_system,source_key,source_row,original_duration_minutes,\r\n   clock_duration_minutes,correction_factor,data_quality_status,correction_confidence,correction_method,correction_note,raw_reason,historical_asset_reference,reason)\r\n  values(p_organization_id,a,r->>'event_id',(r->>'event_date')::date,h,s,ph,(r->>'started_at')::timestamptz,(r->>'ended_at')::timestamptz,\r\n   (r->>'downtime_minutes')::numeric,r->>'event_type',r->>'maintenance_class',r->>'failure_category',r->>'failure_mode',\r\n   r->>'root_cause_inferred',r->>'action_inferred',r->>'spare_parts_text',r->>'description',(r->>'counts_as_failure')='YES',\r\n   (r->>'counts_as_downtime')='YES',r->>'status',r->>'source_system',r->>'source_key',(r->>'source_row')::int,\r\n   nullif(r->>'original_duration_minutes','')::numeric,nullif(r->>'clock_duration_minutes','')::numeric,nullif(r->>'correction_factor','')::numeric,\r\n   r->>'data_quality_status',r->>'correction_confidence',r->>'correction_method',r->>'correction_note',r->>'raw_reason',r->>'ph_reference',r->>'raw_reason')\r\n  on conflict(organization_id,source_system,source_key)where source_system is not null and source_key is not null do update set\r\n   host_asset_id=excluded.host_asset_id,host_system_asset_id=excluded.host_system_asset_id,affected_asset_id=excluded.affected_asset_id,\r\n   downtime_minutes=excluded.downtime_minutes,event_type=excluded.event_type,maintenance_class=excluded.maintenance_class,\r\n   failure_category=excluded.failure_category,failure_mode=excluded.failure_mode,counts_as_failure=excluded.counts_as_failure,\r\n   counts_as_downtime=excluded.counts_as_downtime,original_duration_minutes=excluded.original_duration_minutes,\r\n   clock_duration_minutes=excluded.clock_duration_minutes,correction_factor=excluded.correction_factor,data_quality_status=excluded.data_quality_status,\r\n   correction_confidence=excluded.correction_confidence,correction_method=excluded.correction_method,correction_note=excluded.correction_note,\r\n   historical_asset_reference=excluded.historical_asset_reference,updated_at=now();\r\n end loop;\r\n update maintenance_import_batches set status='COMPLETED',inserted_rows=ins,updated_rows=upd,completed_at=now() where id=b;\r\n return jsonb_build_object('batch_id',b,'status','COMPLETED','inserted_rows',ins,'updated_rows',upd);\r\nend$function$\n"
    }
  ]
}
```

## public.maintenance_post_inventory

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** NEW_CLEAN_CANONICAL

**DOMAIN:** G. MAINTENANCE

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** DEV and PROD differ only in internal PL/pgSQL identifiers/formatting. V2 keeps one clean function with the existing signature and validated stock checks.

**DECISION EVIDENCE:** Current maintenance runtime and equivalent DEV/PROD behavior

**SOURCE OF TRUTH:** Maintenance inventory transaction ledger

**READ CONTRACT:** Returns created transaction UUID.

**WRITE CONTRACT:** Validates positive quantity, stock availability for issues, writes immutable transaction and updates derived stock.

**LIFECYCLE:** Receipt/return increase stock; issue decreases stock; adjustment follows explicit transaction semantics.

**IDEMPOTENCY:** Each user submission creates one auditable transaction; retries require caller-level request control.

**BUSINESS INVARIANTS:**
- issue cannot make available stock negative
- actor and work-order provenance retained
- organization scope enforced

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_part_id uuid, p_location_id uuid, p_work_order_id uuid, p_type text, p_quantity numeric, p_unit_cost numeric, p_notes text, p_actor_id uuid, p_actor_email text",
      "result": "uuid",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_post_inventory(p_organization_id uuid, p_part_id uuid, p_location_id uuid, p_work_order_id uuid, p_type text, p_quantity numeric, p_unit_cost numeric, p_notes text, p_actor_id uuid, p_actor_email text)\n RETURNS uuid\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare id uuid;q numeric;available numeric;begin if p_quantity<=0 then raise exception'Quantity must be positive';end if;if not exists(select 1 from maintenance_parts where id=p_part_id and organization_id=p_organization_id and active)or not exists(select 1 from maintenance_inventory_locations where id=p_location_id and organization_id=p_organization_id and active)then raise exception'Invalid inventory reference';end if;q:=case when p_type='issue'then-p_quantity else p_quantity end;if p_type='issue'then select coalesce(sum(quantity),0)into available from maintenance_inventory_transactions where part_id=p_part_id and location_id=p_location_id;if available<p_quantity then raise exception'Insufficient stock';end if;end if;insert into maintenance_inventory_transactions(organization_id,part_id,location_id,work_order_id,transaction_type,quantity,unit_cost_snapshot,notes,created_by,created_by_email)values(p_organization_id,p_part_id,p_location_id,p_work_order_id,p_type,q,p_unit_cost,p_notes,p_actor_id,p_actor_email)returning maintenance_inventory_transactions.id into id;return id;end$function$\n"
    }
  ]
}
```

## public.maintenance_operator_classify

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_work_order_id uuid, p_problem_area text, p_symptom text, p_comment text, p_actor_id uuid, p_actor_email text",
      "result": "void",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_operator_classify(p_organization_id uuid, p_work_order_id uuid, p_problem_area text, p_symptom text, p_comment text, p_actor_id uuid, p_actor_email text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$begin update maintenance_work_orders set problem_description=concat_ws(' · ',nullif(trim(p_problem_area),''),nullif(trim(p_symptom),''),nullif(trim(p_comment),'')),updated_at=now()where id=p_work_order_id and organization_id=p_organization_id;if not found then raise exception'Work order not found';end if;insert into maintenance_work_order_comments(organization_id,work_order_id,user_id,author_email,comment)select p_organization_id,p_work_order_id,p_actor_id,p_actor_email,concat('Operator classification: ',concat_ws(' · ',nullif(trim(p_problem_area),''),nullif(trim(p_symptom),''),nullif(trim(p_comment),'')))where coalesce(trim(p_problem_area),'')<>''or coalesce(trim(p_symptom),'')<>''or coalesce(trim(p_comment),'')<>'';end$function$\n"
    }
  ]
}
```

## public.v_daily_plans

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/daily-plans.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT p.id,\n    p.organization_id,\n    p.production_date,\n    p.shift_template_id,\n    p.production_area_id,\n    p.status,\n    p.version,\n    p.created_by,\n    p.published_by,\n    p.published_at,\n    p.closed_by,\n    p.closed_at,\n    p.created_at,\n    p.updated_at,\n    s.name AS shift_name,\n    a.code AS area_code,\n    a.name AS area_name,\n    count(i.id) AS item_count,\n    COALESCE(sum(i.planned_units), (0)::numeric) AS planned_units\n   FROM (((production_plans p\n     JOIN shift_templates s ON ((s.id = p.shift_template_id)))\n     JOIN production_areas a ON ((a.id = p.production_area_id)))\n     LEFT JOIN production_plan_items i ON ((i.production_plan_id = p.id)))\n  GROUP BY p.id, s.name, a.code, a.name;",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "production_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "shift_template_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "version",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "created_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "published_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "published_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "closed_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "closed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "shift_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "area_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "area_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 18,
      "column_name": "item_count",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 19,
      "column_name": "planned_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.maintenance_members

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_CANONICAL

**DOMAIN:** I. AUTH / RLS / CONFIG

**USED BY:** web/lib/maintenance.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** DEV contains the required authenticated self-read RLS policy; PROD has RLS enabled without that policy. DEV is the secure functional contract.

**DECISION EVIDENCE:** DEV security policy plus current maintenance membership lookup

**SOURCE OF TRUTH:** Organization maintenance membership

**READ CONTRACT:** Authenticated user may read only their own membership; service role retains administrative access.

**WRITE CONTRACT:** Administrative/service-role membership management only.

**LIFECYCLE:** active controls maintenance access; role controls action authorization.

**IDEMPOTENCY:** Unique membership key prevents duplicate user/organization membership.

**BUSINESS INVARIANTS:**
- authenticated users cannot enumerate other members
- inactive membership denies access

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "user_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "role",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_members_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_members_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (user_id, organization_id)"
    },
    {
      "constraint_name": "maintenance_members_role_check",
      "constraint_type": "c",
      "definition": "CHECK (role = ANY (ARRAY['admin'::text, 'maintenance'::text, 'supervisor'::text, 'operator'::text, 'viewer'::text]))"
    },
    {
      "constraint_name": "maintenance_members_user_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_members_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_members_pkey ON public.maintenance_members USING btree (user_id, organization_id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": [
    {
      "policy_name": "maintenance_members_self_read",
      "permissive": "PERMISSIVE",
      "roles": "{authenticated}",
      "cmd": "SELECT",
      "qual": "(user_id = auth.uid())",
      "with_check": null
    }
  ]
}
```

## public.ingest_sync_batch

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** MERGED_CANONICAL

**DOMAIN:** B. ORACLE_SYNC / INGESTION

**USED BY:** web/lib/ingest.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** DEV has safer organization-scoped serialization and transaction behavior; PROD includes current release-line/source fields. V2 needs both approved behaviors, not either legacy body verbatim.

**DECISION EVIDENCE:** Production source payload coverage merged with validated transactional/idempotent ingestion

**SOURCE OF TRUTH:** Complete Oracle read-only snapshot payload

**READ CONTRACT:** Accepts one validated JSON payload and returns the created sync batch UUID.

**WRITE CONTRACT:** Advisory-lock one organization, create running batch, replace snapshot tables including release lines, append deduplicated audit, finalize counts/status atomically; on failure mark/raise without partial authoritative snapshot.

**LIFECYCLE:** Only completed batches become current source evidence.

**IDEMPOTENCY:** Single organization lock, source natural keys and audit conflict handling prevent duplicate authoritative rows.

**BUSINESS INVARIANTS:**
- Oracle is never written
- release lines are line-grain
- incomplete batch is never current
- all snapshot rows share the returned sync_batch_id

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "signature": "payload jsonb",
  "result": "uuid",
  "body_contract": "Advisory-lock one organization, create running batch, replace snapshot tables including release lines, append deduplicated audit, finalize counts/status atomically; on failure mark/raise without partial authoritative snapshot.",
  "security_definer": true,
  "search_path": "public"
}
```

## public.maintenance_report_problem

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_asset_id uuid, p_title text, p_description text, p_priority text, p_machine_stopped boolean, p_actor_id uuid, p_actor_email text",
      "result": "uuid",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_report_problem(p_organization_id uuid, p_asset_id uuid, p_title text, p_description text, p_priority text, p_machine_stopped boolean, p_actor_id uuid, p_actor_email text)\n RETURNS uuid\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare w uuid;n text;begin if not exists(select 1 from maintenance_assets where id=p_asset_id and organization_id=p_organization_id and active)then raise exception'Invalid asset';end if;n='WO-'||extract(year from now()at time zone'Australia/Brisbane')::int||'-'||lpad(nextval('maintenance_work_order_seq')::text,6,'0');insert into maintenance_work_orders(organization_id,work_order_number,asset_id,priority,title,problem_description,requested_by,requested_by_email)values(p_organization_id,n,p_asset_id,p_priority,p_title,p_description,p_actor_id,p_actor_email)returning id into w;insert into maintenance_work_order_history values(gen_random_uuid(),p_organization_id,w,null,'open',p_actor_id,p_actor_email,now());if p_machine_stopped then insert into maintenance_downtime_events(organization_id,asset_id,work_order_id,reason,started_by)values(p_organization_id,p_asset_id,w,p_title,p_actor_id);update maintenance_assets set status='down',updated_at=now()where id=p_asset_id;end if;return w;end$function$\n"
    }
  ]
}
```

## public.labour_segments

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/deputy.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "import_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "source_timesheet_row_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "person_key",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "area_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "segment_start",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "segment_end",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "calendar_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "operational_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "hour_bucket",
      "data_type": "smallint",
      "udt_schema": "pg_catalog",
      "udt_name": "int2",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "shift_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "paid_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "regular_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "overtime_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "paid_break_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "productive_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "approval_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "allocation_method",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'PRO_RATA_ELAPSED'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 20,
      "column_name": "week_start",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 21,
      "column_name": "calculation_version",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'V29_DAILY8_WEEKLY38_WEEKEND_OT_PAID_BREAK20'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 22,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "labour_segments_hour_bucket_check",
      "constraint_type": "c",
      "definition": "CHECK (hour_bucket >= 0 AND hour_bucket <= 23)"
    },
    {
      "constraint_name": "labour_segments_import_batch_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (import_batch_id) REFERENCES deputy_import_batches(id)"
    },
    {
      "constraint_name": "labour_segments_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "labour_segments_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "labour_segments_source_timesheet_row_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (source_timesheet_row_id) REFERENCES deputy_raw_timesheets(id)"
    },
    {
      "constraint_name": "labour_segments_source_timesheet_row_id_segment_start_key",
      "constraint_type": "u",
      "definition": "UNIQUE (source_timesheet_row_id, segment_start)"
    }
  ],
  "indexes": [
    {
      "index_name": "labour_segments_period_idx",
      "definition": "CREATE INDEX labour_segments_period_idx ON public.labour_segments USING btree (organization_id, operational_date, shift_code, area_code)"
    },
    {
      "index_name": "labour_segments_person_week_idx",
      "definition": "CREATE INDEX labour_segments_person_week_idx ON public.labour_segments USING btree (organization_id, person_key, week_start)"
    },
    {
      "index_name": "labour_segments_pkey",
      "definition": "CREATE UNIQUE INDEX labour_segments_pkey ON public.labour_segments USING btree (id)"
    },
    {
      "index_name": "labour_segments_source_timesheet_row_id_segment_start_key",
      "definition": "CREATE UNIQUE INDEX labour_segments_source_timesheet_row_id_segment_start_key ON public.labour_segments USING btree (source_timesheet_row_id, segment_start)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_capacity_load

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/capacity.ts, web/lib/machine-load.ts, web/lib/production-flow-kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " WITH demand AS (\n         SELECT v_production_planning.organization_id,\n            v_production_planning.line AS area_code,\n            sum(v_production_planning.remaining_units) AS demand_units\n           FROM v_production_planning\n          WHERE (COALESCE(v_production_planning.planning_status, 'unplanned'::text) <> ALL (ARRAY['completed'::text, 'cancelled'::text]))\n          GROUP BY v_production_planning.organization_id, v_production_planning.line\n        ), profile_capacity AS (\n         SELECT p.organization_id,\n            a.code AS area_code,\n            sum((((p.resource_count * p.scheduled_hours) * p.hourly_rate) * p.efficiency)) AS daily_capacity,\n            sum(((((p.resource_count * p.scheduled_hours) * p.hourly_rate) * p.efficiency) * p.work_days)) AS weekly_capacity\n           FROM (capacity_profiles p\n             JOIN production_areas a ON ((a.id = p.production_area_id)))\n          WHERE p.active\n          GROUP BY p.organization_id, a.code\n        ), legacy_capacity AS (\n         SELECT o.organization_id,\n            a.code AS area_code,\n            sum(o.daily_capacity) AS daily_capacity,\n            sum((o.daily_capacity * o.work_days)) AS weekly_capacity\n           FROM (capacity_legacy_overrides o\n             JOIN production_areas a ON ((a.id = o.production_area_id)))\n          WHERE o.active\n          GROUP BY o.organization_id, a.code\n        ), capacity AS (\n         SELECT profile_capacity.organization_id,\n            profile_capacity.area_code,\n            profile_capacity.daily_capacity,\n            profile_capacity.weekly_capacity\n           FROM profile_capacity\n        UNION ALL\n         SELECT l.organization_id,\n            l.area_code,\n            l.daily_capacity,\n            l.weekly_capacity\n           FROM legacy_capacity l\n          WHERE (NOT (EXISTS ( SELECT 1\n                   FROM profile_capacity p\n                  WHERE ((p.organization_id = l.organization_id) AND (p.area_code = l.area_code)))))\n        )\n SELECT c.organization_id,\n    c.area_code,\n    COALESCE(d.demand_units, (0)::numeric) AS demand_units,\n    c.daily_capacity,\n    c.weekly_capacity,\n        CASE\n            WHEN (c.daily_capacity = (0)::numeric) THEN NULL::numeric\n            ELSE round(((COALESCE(d.demand_units, (0)::numeric) / c.daily_capacity) * (100)::numeric), 2)\n        END AS load_percent,\n    (c.daily_capacity - COALESCE(d.demand_units, (0)::numeric)) AS capacity_gap,\n        CASE\n            WHEN (c.daily_capacity = (0)::numeric) THEN NULL::numeric\n            ELSE round((COALESCE(d.demand_units, (0)::numeric) / c.daily_capacity), 2)\n        END AS relative_lead_days\n   FROM (capacity c\n     LEFT JOIN demand d USING (organization_id, area_code));",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "area_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "demand_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "daily_capacity",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "weekly_capacity",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "load_percent",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "capacity_gap",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "relative_lead_days",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.v_source_reconciliation

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/source-data.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT organization_id,\n    id AS sync_batch_id,\n    completed_at,\n    orders_count AS batch_orders,\n    ( SELECT count(*) AS count\n           FROM source_orders o\n          WHERE (o.sync_batch_id = b.id)) AS current_orders,\n    workbank_count AS batch_workbank,\n    ( SELECT count(*) AS count\n           FROM source_workbank_items w\n          WHERE (w.sync_batch_id = b.id)) AS current_workbank,\n    stock_count AS batch_stock,\n    ( SELECT count(*) AS count\n           FROM source_stock_items s\n          WHERE (s.sync_batch_id = b.id)) AS current_stock,\n    audit_new_count\n   FROM v_latest_completed_batch b;",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "sync_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "completed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "batch_orders",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "current_orders",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "batch_workbank",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "current_workbank",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "batch_stock",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "current_stock",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "audit_new_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.kpi_rate_rules

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/erp-kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "process",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "rate_per_hour",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "unit",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "capacity_mode",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "calculation_version",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "effective_from",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "effective_to",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "kpi_rate_rules_check",
      "constraint_type": "c",
      "definition": "CHECK (effective_to IS NULL OR effective_to >= effective_from)"
    },
    {
      "constraint_name": "kpi_rate_rules_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "kpi_rate_rules_organization_id_process_effective_from_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, process, effective_from)"
    },
    {
      "constraint_name": "kpi_rate_rules_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "kpi_rate_rules_process_check",
      "constraint_type": "c",
      "definition": "CHECK (process = ANY (ARRAY['DTG'::text, 'UP'::text, 'SCREEN_PRINT'::text]))"
    },
    {
      "constraint_name": "kpi_rate_rules_rate_per_hour_check",
      "constraint_type": "c",
      "definition": "CHECK (rate_per_hour > 0::numeric)"
    }
  ],
  "indexes": [
    {
      "index_name": "kpi_rate_rules_organization_id_process_effective_from_key",
      "definition": "CREATE UNIQUE INDEX kpi_rate_rules_organization_id_process_effective_from_key ON public.kpi_rate_rules USING btree (organization_id, process, effective_from)"
    },
    {
      "index_name": "kpi_rate_rules_pkey",
      "definition": "CREATE UNIQUE INDEX kpi_rate_rules_pkey ON public.kpi_rate_rules USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_current_stock

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/operational-scan.ts, web/lib/machine-load.ts, web/lib/source-data.ts, web/lib/production-flow-kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT s.id,\n    s.organization_id,\n    s.sync_batch_id,\n    s.product,\n    s.pack_id,\n    s.location,\n    s.source_timestamp,\n    s.source_qty,\n    s.source_weight,\n    s.production_units,\n    s.created_at,\n    s.source_zone\n   FROM (source_stock_items s\n     JOIN v_latest_completed_batch b ON ((b.id = s.sync_batch_id)));",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "sync_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "product",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "pack_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "source_timestamp",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "source_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "source_weight",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "production_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "source_zone",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.maintenance-private

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** APPLICATION_USAGE

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** QUERY, STORAGE

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "STORAGE_BUCKET",
  "bucket_name": "maintenance-private",
  "source": "APPLICATION_USAGE",
  "note": "Bucket row/configuration is data and was intentionally excluded from schema-only snapshots."
}
```

## public.finish_sync_work

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** PRODUCTION

**USED BY:** web/lib/ingest.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_run_id uuid, p_status text, p_batch_id uuid, p_duration_ms bigint, p_orders integer, p_workbank integer, p_stock integer, p_audit integer, p_failure text",
      "result": "void",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.finish_sync_work(p_run_id uuid, p_status text, p_batch_id uuid, p_duration_ms bigint, p_orders integer, p_workbank integer, p_stock integer, p_audit integer, p_failure text DEFAULT NULL::text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare v_request uuid;begin if p_status not in('SUCCESS','FAILED')then raise exception'INVALID_SYNC_STATUS';end if;update sync_runs set status=p_status,completed_at=now(),duration_ms=p_duration_ms,batch_id=p_batch_id,orders_count=coalesce(p_orders,0),workbank_count=coalesce(p_workbank,0),stock_count=coalesce(p_stock,0),audit_count=coalesce(p_audit,0),failure_reason=left(p_failure,1000)where id=p_run_id and status='RUNNING'returning refresh_request_id into v_request;if v_request is not null then update sync_refresh_requests set status=p_status,completed_at=now(),failure_reason=left(p_failure,1000)where id=v_request;end if;end$function$\n"
    }
  ]
}
```

## public.production_areas

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/daily-plans.ts, web/lib/capacity.ts, web/lib/kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "sequence",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "production_areas_organization_id_code_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, code)"
    },
    {
      "constraint_name": "production_areas_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "production_areas_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    }
  ],
  "indexes": [
    {
      "index_name": "production_areas_organization_id_code_key",
      "definition": "CREATE UNIQUE INDEX production_areas_organization_id_code_key ON public.production_areas USING btree (organization_id, code)"
    },
    {
      "index_name": "production_areas_pkey",
      "definition": "CREATE UNIQUE INDEX production_areas_pkey ON public.production_areas USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.source_audit_events

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/up-productivity.ts, web/lib/flow-dashboard.ts, web/lib/source-data.ts, web/lib/production-flow-kpis.ts, web/lib/performance-workload.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** PRESENT - validate/replace against this contract

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "source_audit_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "username",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "from_zone",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "to_zone",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "from_location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "to_location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "product",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "from_pack_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "to_pack_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "source_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "source_weight",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "production_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "event_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "raw_hash",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "imported_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "queue",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 20,
      "column_name": "task",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "source_audit_events_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "source_audit_events_organization_id_raw_hash_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, raw_hash)"
    },
    {
      "constraint_name": "source_audit_events_organization_id_source_audit_id_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, source_audit_id)"
    },
    {
      "constraint_name": "source_audit_events_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    }
  ],
  "indexes": [
    {
      "index_name": "source_audit_event_idx",
      "definition": "CREATE INDEX source_audit_event_idx ON public.source_audit_events USING btree (event_at)"
    },
    {
      "index_name": "source_audit_events_dtg_history_idx",
      "definition": "CREATE INDEX source_audit_events_dtg_history_idx ON public.source_audit_events USING btree (order_no, from_zone, to_zone, event_at)"
    },
    {
      "index_name": "source_audit_events_organization_id_raw_hash_key",
      "definition": "CREATE UNIQUE INDEX source_audit_events_organization_id_raw_hash_key ON public.source_audit_events USING btree (organization_id, raw_hash)"
    },
    {
      "index_name": "source_audit_events_organization_id_source_audit_id_key",
      "definition": "CREATE UNIQUE INDEX source_audit_events_organization_id_source_audit_id_key ON public.source_audit_events USING btree (organization_id, source_audit_id)"
    },
    {
      "index_name": "source_audit_events_pkey",
      "definition": "CREATE UNIQUE INDEX source_audit_events_pkey ON public.source_audit_events USING btree (id)"
    },
    {
      "index_name": "source_audit_from_location_idx",
      "definition": "CREATE INDEX source_audit_from_location_idx ON public.source_audit_events USING btree (from_location)"
    },
    {
      "index_name": "source_audit_order_idx",
      "definition": "CREATE INDEX source_audit_order_idx ON public.source_audit_events USING btree (order_no)"
    },
    {
      "index_name": "source_audit_to_location_idx",
      "definition": "CREATE INDEX source_audit_to_location_idx ON public.source_audit_events USING btree (to_location)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_current_orders

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** MERGED_CANONICAL

**DOMAIN:** B. ORACLE_SYNC / INGESTION

**USED BY:** web/lib/operational-scan.ts, web/lib/machine-load.ts, web/lib/source-data.ts, web/lib/ship-to.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** DEV uses canonical source_route_id naming; PROD adds release_source_status. V2 exposes both required semantics with one canonical source_route_id, retaining release_source_status and avoiding duplicate route concepts.

**DECISION EVIDENCE:** Current application reads plus release-source evidence and canonical naming

**SOURCE OF TRUTH:** Latest completed source_orders snapshot

**READ CONTRACT:** Current order identity/customer/dates/status/priority/site/source_route_id/cost centre/stop-ship/release-source status from the latest completed batch.

**WRITE CONTRACT:** Read-only view.

**LIFECYCLE:** Changes only when a completed sync batch becomes current.

**IDEMPOTENCY:** One current row per organization and order in the selected snapshot.

**BUSINESS INVARIANTS:**
- never reads an incomplete batch
- source_route_id is source evidence, not canonical routing
- release_source_status does not itself rewrite an MO routing

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "sync_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "date_received",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "date_due",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "date_released",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "source_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "source_sub_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "customer_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "ship_to_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "customer_state",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "city",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "delivery_desc",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "client_so_number",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "source_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 18,
      "column_name": "source_updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 19,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 20,
      "column_name": "site",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 21,
      "column_name": "source_route_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 22,
      "column_name": "cost_centre",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 23,
      "column_name": "stop_ship_flag",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 24,
      "column_name": "release_source_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    }
  ],
  "definition_contract": "Latest completed source_orders snapshot. Expose DEV columns using source_route_id plus release_source_status. No route_id alias."
}
```

## public.capacity_scenarios

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/capacity.ts, web/app/production/capacity/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "notes",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "created_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "created_by_email",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "capacity_scenarios_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "capacity_scenarios_organization_id_name_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, name)"
    },
    {
      "constraint_name": "capacity_scenarios_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    }
  ],
  "indexes": [
    {
      "index_name": "capacity_scenarios_organization_id_name_key",
      "definition": "CREATE UNIQUE INDEX capacity_scenarios_organization_id_name_key ON public.capacity_scenarios USING btree (organization_id, name)"
    },
    {
      "index_name": "capacity_scenarios_pkey",
      "definition": "CREATE UNIQUE INDEX capacity_scenarios_pkey ON public.capacity_scenarios USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.production_events

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** NEW_CLEAN_CANONICAL

**DOMAIN:** H. PRODUCTION / PERFORMANCE

**USED BY:** web/lib/labour-dashboard.ts, web/lib/up-productivity.ts, web/lib/erp-kpis.ts, web/app/production/screen-events/page.tsx, web/app/production/screen-events/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** The schemas are semantically identical; V2 freezes the shared exact contract without preserving catalog ordering artifacts.

**DECISION EVIDENCE:** Equivalent DEV/PROD table and current event writers/readers

**SOURCE OF TRUTH:** Accepted immutable production event ledger

**READ CONTRACT:** Performance and labour consumers filter organization, date, area, metric and quality.

**WRITE CONTRACT:** Validated Oracle-audit derivation and manual Screen Print event insertion.

**LIFECYCLE:** Events are append-only; quality and provenance remain attached.

**IDEMPOTENCY:** event_id and source_record_key prevent duplicate source events.

**BUSINESS INVARIANTS:**
- manual and Oracle-derived events remain distinguishable
- operational date and shift are stored at ingestion
- quantity is non-negative according to event metric

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "event_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "event_ts_utc",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "event_ts_local",
      "data_type": "timestamp without time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamp",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "calendar_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "operational_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "hour_bucket",
      "data_type": "smallint",
      "udt_schema": "pg_catalog",
      "udt_name": "int2",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "shift_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "area",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "metric",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "quantity",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "unit",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "source",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "source_mode",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "source_record_key",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "quality_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "import_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "calculation_version",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 20,
      "column_name": "is_partial_period",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 21,
      "column_name": "operational_shift_overtime",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 22,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "production_events_hour_bucket_check",
      "constraint_type": "c",
      "definition": "CHECK (hour_bucket >= 0 AND hour_bucket <= 23)"
    },
    {
      "constraint_name": "production_events_metric_check",
      "constraint_type": "c",
      "definition": "CHECK (metric = ANY (ARRAY['DTG_PRINT'::text, 'DTG_PUTWALL_IN'::text, 'DTG_PUTWALL_OUT'::text, 'UP_IN'::text, 'UP_OUT'::text, 'SCREEN_PRINT'::text, 'SCREEN_MACHINE_HOURS'::text]))"
    },
    {
      "constraint_name": "production_events_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "production_events_organization_id_source_source_record_key__key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, source, source_record_key, metric)"
    },
    {
      "constraint_name": "production_events_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "production_events_quality_status_check",
      "constraint_type": "c",
      "definition": "CHECK (quality_status = ANY (ARRAY['COMPLETE'::text, 'PARTIAL'::text, 'PROVISIONAL'::text, 'MISSING_SOURCE'::text, 'NO_TARGET_HOURS'::text, 'OUT_OF_SHIFT'::text, 'REJECTED'::text]))"
    },
    {
      "constraint_name": "production_events_shift_code_check",
      "constraint_type": "c",
      "definition": "CHECK (shift_code = ANY (ARRAY['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text, 'OUT_OF_SHIFT'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "production_events_organization_id_source_source_record_key__key",
      "definition": "CREATE UNIQUE INDEX production_events_organization_id_source_source_record_key__key ON public.production_events USING btree (organization_id, source, source_record_key, metric)"
    },
    {
      "index_name": "production_events_period_idx",
      "definition": "CREATE INDEX production_events_period_idx ON public.production_events USING btree (organization_id, operational_date, shift_code, metric)"
    },
    {
      "index_name": "production_events_pkey",
      "definition": "CREATE UNIQUE INDEX production_events_pkey ON public.production_events USING btree (id)"
    },
    {
      "index_name": "production_events_timestamp_idx",
      "definition": "CREATE INDEX production_events_timestamp_idx ON public.production_events USING btree (organization_id, event_ts_utc)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "production_event_units_trigger",
      "definition": "CREATE TRIGGER production_event_units_trigger BEFORE INSERT OR UPDATE OF quantity, metric ON production_events FOR EACH ROW EXECUTE FUNCTION normalize_production_event_units()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.screen_print_jobs

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/machine-load.ts, web/lib/production-flow-kpis.ts, web/lib/performance-workload.ts, web/app/production/flow/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "job_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "planned_quantity",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "completed_quantity",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'todo'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "planned_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "shift_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "line_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "started_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "completed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "notes",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "created_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "updated_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "screen_print_jobs_check",
      "constraint_type": "c",
      "definition": "CHECK (completed_quantity <= planned_quantity)"
    },
    {
      "constraint_name": "screen_print_jobs_completed_quantity_check",
      "constraint_type": "c",
      "definition": "CHECK (completed_quantity >= 0::numeric)"
    },
    {
      "constraint_name": "screen_print_jobs_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "screen_print_jobs_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "screen_print_jobs_planned_quantity_check",
      "constraint_type": "c",
      "definition": "CHECK (planned_quantity >= 0::numeric)"
    },
    {
      "constraint_name": "screen_print_jobs_status_check",
      "constraint_type": "c",
      "definition": "CHECK (status = ANY (ARRAY['todo'::text, 'in_production'::text, 'completed'::text, 'cancelled'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "screen_print_jobs_org_status_idx",
      "definition": "CREATE INDEX screen_print_jobs_org_status_idx ON public.screen_print_jobs USING btree (organization_id, status, planned_date)"
    },
    {
      "index_name": "screen_print_jobs_pkey",
      "definition": "CREATE UNIQUE INDEX screen_print_jobs_pkey ON public.screen_print_jobs USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_operator_start_request

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_asset_id uuid, p_request_type text, p_request_key text, p_actor_id uuid, p_actor_email text",
      "result": "uuid",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_operator_start_request(p_organization_id uuid, p_asset_id uuid, p_request_type text, p_request_key text, p_actor_id uuid, p_actor_email text)\n RETURNS uuid\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare w uuid;n text;s text;stopped boolean;event_start timestamptz;begin if p_request_type not in('OPERATOR_FIX','CORRECTIVE_NOW','SCHEDULE_CORRECTIVE')then raise exception'Invalid request type';end if;perform pg_advisory_xact_lock(hashtext(p_asset_id::text));select id into w from maintenance_work_orders where organization_id=p_organization_id and operator_request_key=p_request_key limit 1;if w is not null then return w;end if;stopped:=p_request_type in('OPERATOR_FIX','CORRECTIVE_NOW');if stopped then select work_order_id into w from maintenance_downtime_events where organization_id=p_organization_id and asset_id=p_asset_id and ended_at is null order by started_at limit 1;if w is not null then return w;end if;end if;if not exists(select 1 from maintenance_assets where id=p_asset_id and organization_id=p_organization_id and active)then raise exception'Invalid asset';end if;s:=case p_request_type when'OPERATOR_FIX'then'OPEN_OPERATOR'when'CORRECTIVE_NOW'then'WAITING_MAINTENANCE'else'REQUESTED'end;event_start:=case when stopped then clock_timestamp() else null end;n:='WO-'||extract(year from now()at time zone'Australia/Brisbane')::int||'-'||lpad(nextval('maintenance_work_order_seq')::text,6,'0');insert into maintenance_work_orders(organization_id,work_order_number,asset_id,status,priority,title,requested_by,requested_by_email,request_type,maintenance_requested_at,counts_as_downtime,operator_request_key,downtime_started_at)values(p_organization_id,n,p_asset_id,s,case when p_request_type='CORRECTIVE_NOW'then'critical'when p_request_type='OPERATOR_FIX'then'high'else'medium'end,replace(p_request_type,'_',' '),p_actor_id,p_actor_email,p_request_type,case when p_request_type='CORRECTIVE_NOW'then event_start end,stopped,p_request_key,event_start)returning id into w;insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,w,null,s,p_actor_id,p_actor_email);if stopped then insert into maintenance_downtime_events(organization_id,asset_id,host_asset_id,work_order_id,reason,started_at,started_by,maintenance_class,counts_as_failure,counts_as_downtime)values(p_organization_id,p_asset_id,p_asset_id,w,replace(p_request_type,'_',' '),event_start,p_actor_id,'CORRECTIVE',true,true);update maintenance_assets set status='down',updated_at=now()where id=p_asset_id;end if;return w;end$function$\n"
    }
  ]
}
```

## public.maintenance_inventory_transactions

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/lib/reliability-dashboard.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "part_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "location_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "work_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "transaction_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "quantity",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "unit_cost_snapshot",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "notes",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "created_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "created_by_email",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_inventory_transactions_check",
      "constraint_type": "c",
      "definition": "CHECK ((transaction_type = ANY (ARRAY['receipt'::text, 'return'::text])) AND quantity > 0::numeric OR transaction_type = 'issue'::text AND quantity < 0::numeric OR transaction_type = 'adjustment'::text)"
    },
    {
      "constraint_name": "maintenance_inventory_transactions_location_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (location_id) REFERENCES maintenance_inventory_locations(id)"
    },
    {
      "constraint_name": "maintenance_inventory_transactions_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_inventory_transactions_part_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (part_id) REFERENCES maintenance_parts(id)"
    },
    {
      "constraint_name": "maintenance_inventory_transactions_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_inventory_transactions_quantity_check",
      "constraint_type": "c",
      "definition": "CHECK (quantity <> 0::numeric)"
    },
    {
      "constraint_name": "maintenance_inventory_transactions_transaction_type_check",
      "constraint_type": "c",
      "definition": "CHECK (transaction_type = ANY (ARRAY['receipt'::text, 'issue'::text, 'return'::text, 'adjustment'::text]))"
    },
    {
      "constraint_name": "maintenance_inventory_transactions_work_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_inventory_part_location_idx",
      "definition": "CREATE INDEX maintenance_inventory_part_location_idx ON public.maintenance_inventory_transactions USING btree (part_id, location_id, created_at)"
    },
    {
      "index_name": "maintenance_inventory_transactions_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_inventory_transactions_pkey ON public.maintenance_inventory_transactions USING btree (id)"
    },
    {
      "index_name": "maintenance_inventory_wo_idx",
      "definition": "CREATE INDEX maintenance_inventory_wo_idx ON public.maintenance_inventory_transactions USING btree (work_order_id) WHERE (work_order_id IS NOT NULL)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "audit_change",
      "definition": "CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_inventory_transactions FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_work_order_history

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "work_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "from_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "to_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "changed_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "changed_by_email",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "changed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_work_order_history_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_work_order_history_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_work_order_history_work_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_work_order_history_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_work_order_history_pkey ON public.maintenance_work_order_history USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_create_component

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** NEW_CLEAN_CANONICAL

**DOMAIN:** G. MAINTENANCE

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** DEV and PROD signatures and behavior agree; only implementation formatting differs.

**DECISION EVIDENCE:** Equivalent runtime behavior and current component action

**SOURCE OF TRUTH:** Maintenance asset/component registry

**READ CONTRACT:** Returns the created component asset UUID.

**WRITE CONTRACT:** Checks maintenance membership, allocates component code, creates child asset and installation provenance.

**LIFECYCLE:** Component starts with requested status and remains linked to its parent.

**IDEMPOTENCY:** Generated organization-scoped asset code uniqueness prevents duplicate identity.

**BUSINESS INVARIANTS:**
- parent and prefix belong to organization
- component identity remains distinct from parent

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_parent_asset_id uuid, p_component_prefix_id uuid, p_name text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_actor_id uuid",
      "result": "uuid",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_create_component(p_organization_id uuid, p_parent_asset_id uuid, p_component_prefix_id uuid, p_name text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_actor_id uuid)\n RETURNS uuid\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare pc text;p text;n integer;code text;a uuid;begin if not exists(select 1 from maintenance_members where organization_id=p_organization_id and user_id=p_actor_id and active and role in('admin','maintenance'))then raise exception'Maintenance permission denied';end if;select asset_code into pc from maintenance_assets where id=p_parent_asset_id and organization_id=p_organization_id and active for share;select prefix into p from maintenance_component_prefixes where id=p_component_prefix_id and organization_id=p_organization_id and active for share;if pc is null or p is null then raise exception'Invalid parent or component prefix';end if;insert into maintenance_component_code_sequences values(p_organization_id,p_parent_asset_id,p,0,now())on conflict do nothing;update maintenance_component_code_sequences set last_number=last_number+1,updated_at=now()where organization_id=p_organization_id and parent_asset_id=p_parent_asset_id and component_prefix=p returning last_number into n;if n>99 then raise exception'Component sequence exhausted';end if;code:=pc||'-'||p||'-'||lpad(n::text,2,'0');insert into maintenance_assets(organization_id,asset_code,name,asset_name,parent_asset_id,manufacturer,model,serial_number,description,criticality,status,installation_date,installed_at,created_by)values(p_organization_id,code,p_name,p_name,p_parent_asset_id,nullif(trim(p_manufacturer),''),nullif(trim(p_model),''),nullif(trim(p_serial_number),''),nullif(trim(p_description),''),p_criticality,p_status,p_installation_date,case when p_installation_date is not null then p_installation_date::timestamptz end,p_actor_id)returning id into a;return a;end$function$\n"
    }
  ]
}
```

## public.v_production_planning

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_CANONICAL

**DOMAIN:** E. ROUTING / PLANNING

**USED BY:** web/lib/planning.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** DEV retains source-routing context in the planning association; PROD uses the older order-only shortcut. The DEV contract better preserves one Sales Order plus Routing boundaries.

**DECISION EVIDENCE:** Canonical routing separation and newer DEV routing-aware planning join

**SOURCE OF TRUTH:** Current source demand enriched by canonical planning state

**READ CONTRACT:** Returns the established planning columns ordered by effective priority and age.

**WRITE CONTRACT:** Read-only view; changes go through apply_production_planning.

**LIFECYCLE:** Source demand remains separate from mutable planner attributes.

**IDEMPOTENCY:** One planning row per canonical order/routing planning grain.

**BUSINESS INVARIANTS:**
- blank SKU never determines routing
- unresolved routing remains unresolved
- planning does not mutate source evidence

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " WITH queues AS (\n         SELECT v_up_operational_orders.organization_id,\n            v_up_operational_orders.order_no,\n            'UP'::text AS line,\n            v_up_operational_orders.customer_name,\n            v_up_operational_orders.screen,\n            v_up_operational_orders.status AS source_status,\n            v_up_operational_orders.priority AS source_priority,\n            v_up_operational_orders.age_days,\n            v_up_operational_orders.remaining_units,\n            v_up_operational_orders.total_prints\n           FROM v_up_operational_orders\n        UNION ALL\n         SELECT v_dtg_operational_orders.organization_id,\n            v_dtg_operational_orders.order_no,\n            'DTG'::text,\n            v_dtg_operational_orders.customer_name,\n            v_dtg_operational_orders.screen,\n            v_dtg_operational_orders.status,\n            v_dtg_operational_orders.priority,\n            v_dtg_operational_orders.age_days,\n            v_dtg_operational_orders.remaining_units,\n            v_dtg_operational_orders.total_prints\n           FROM v_dtg_operational_orders\n        )\n SELECT q.organization_id,\n    q.order_no,\n    q.line,\n    q.customer_name,\n    q.screen,\n    q.source_status,\n    q.source_priority,\n    q.age_days,\n    q.remaining_units,\n    q.total_prints,\n    p.id AS production_order_id,\n    p.planner_priority,\n    COALESCE(p.planner_priority, q.source_priority) AS effective_priority,\n    p.planned_date,\n    p.planned_shift_id,\n    s.name AS planned_shift,\n    p.planning_status,\n    p.special_instruction,\n    p.planner_note,\n    p.blocked_reason,\n    p.updated_at\n   FROM ((queues q\n     LEFT JOIN production_orders p ON (((p.organization_id = q.organization_id) AND (p.order_no = q.order_no) AND (p.source_routing_id IS NULL))))\n     LEFT JOIN shift_templates s ON ((s.id = p.planned_shift_id)));",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "line",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "screen",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "source_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "source_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "age_days",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "remaining_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "total_prints",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "production_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "planner_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "effective_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "planned_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "planned_shift_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "planned_shift",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "planning_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 18,
      "column_name": "special_instruction",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 19,
      "column_name": "planner_note",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 20,
      "column_name": "blocked_reason",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 21,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.maintenance_preventive_plans

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/lib/reliability-dashboard.ts, web/lib/operator-maintenance.ts, web/app/maintenance/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "priority",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'medium'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "trigger_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'calendar'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "frequency_value",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "frequency_unit",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "next_due_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "lead_time_days",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "estimated_minutes",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "requires_downtime",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_preventive_plans_asset_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id)"
    },
    {
      "constraint_name": "maintenance_preventive_plans_frequency_unit_check",
      "constraint_type": "c",
      "definition": "CHECK (frequency_unit = ANY (ARRAY['day'::text, 'week'::text, 'month'::text, 'year'::text]))"
    },
    {
      "constraint_name": "maintenance_preventive_plans_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_preventive_plans_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_preventive_plans_priority_check",
      "constraint_type": "c",
      "definition": "CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]))"
    },
    {
      "constraint_name": "maintenance_preventive_plans_trigger_type_check",
      "constraint_type": "c",
      "definition": "CHECK (trigger_type = ANY (ARRAY['calendar'::text, 'meter'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_pm_due_idx",
      "definition": "CREATE INDEX maintenance_pm_due_idx ON public.maintenance_preventive_plans USING btree (organization_id, next_due_at) WHERE active"
    },
    {
      "index_name": "maintenance_preventive_plans_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_preventive_plans_pkey ON public.maintenance_preventive_plans USING btree (id)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "audit_change",
      "definition": "CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_preventive_plans FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.kpi_definitions

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "category",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'OPERATIONS'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "unit",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'UNITS'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "direction",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'LOWER_IS_BETTER'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "frequency",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'REALTIME'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "data_source",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "data_readiness_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "is_active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "dashboard_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "owner_role",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'manager'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "supports_area_dimension",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "kpi_definitions_data_readiness_status_check",
      "constraint_type": "c",
      "definition": "CHECK (data_readiness_status = ANY (ARRAY['ACTIVE'::text, 'WAITING_FOR_DATA'::text, 'DISABLED'::text]))"
    },
    {
      "constraint_name": "kpi_definitions_direction_check",
      "constraint_type": "c",
      "definition": "CHECK (direction = ANY (ARRAY['HIGHER_IS_BETTER'::text, 'LOWER_IS_BETTER'::text, 'TARGET_RANGE'::text]))"
    },
    {
      "constraint_name": "kpi_definitions_organization_id_code_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, code)"
    },
    {
      "constraint_name": "kpi_definitions_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "kpi_definitions_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    }
  ],
  "indexes": [
    {
      "index_name": "kpi_definitions_organization_id_code_key",
      "definition": "CREATE UNIQUE INDEX kpi_definitions_organization_id_code_key ON public.kpi_definitions USING btree (organization_id, code)"
    },
    {
      "index_name": "kpi_definitions_pkey",
      "definition": "CREATE UNIQUE INDEX kpi_definitions_pkey ON public.kpi_definitions USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.production_plan_items

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/daily-plans.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "production_plan_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "production_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "sequence",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "planned_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "responsible",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "special_instruction",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "production_plan_items_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "production_plan_items_planned_units_check",
      "constraint_type": "c",
      "definition": "CHECK (planned_units > 0::numeric)"
    },
    {
      "constraint_name": "production_plan_items_production_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_order_id) REFERENCES production_orders(id)"
    },
    {
      "constraint_name": "production_plan_items_production_plan_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_plan_id) REFERENCES production_plans(id) ON DELETE CASCADE"
    },
    {
      "constraint_name": "production_plan_items_production_plan_id_production_order_i_key",
      "constraint_type": "u",
      "definition": "UNIQUE (production_plan_id, production_order_id)"
    },
    {
      "constraint_name": "production_plan_items_production_plan_id_sequence_key",
      "constraint_type": "u",
      "definition": "UNIQUE (production_plan_id, sequence)"
    }
  ],
  "indexes": [
    {
      "index_name": "production_plan_items_pkey",
      "definition": "CREATE UNIQUE INDEX production_plan_items_pkey ON public.production_plan_items USING btree (id)"
    },
    {
      "index_name": "production_plan_items_production_plan_id_production_order_i_key",
      "definition": "CREATE UNIQUE INDEX production_plan_items_production_plan_id_production_order_i_key ON public.production_plan_items USING btree (production_plan_id, production_order_id)"
    },
    {
      "index_name": "production_plan_items_production_plan_id_sequence_key",
      "definition": "CREATE UNIQUE INDEX production_plan_items_production_plan_id_sequence_key ON public.production_plan_items USING btree (production_plan_id, sequence)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_work_order_comments

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/app/maintenance/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "work_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "user_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "author_email",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "comment",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_work_order_comments_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_work_order_comments_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_work_order_comments_work_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_comments_wo_idx",
      "definition": "CREATE INDEX maintenance_comments_wo_idx ON public.maintenance_work_order_comments USING btree (work_order_id, created_at)"
    },
    {
      "index_name": "maintenance_work_order_comments_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_work_order_comments_pkey ON public.maintenance_work_order_comments USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_current_workbank

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/operational-scan.ts, web/lib/machine-load.ts, web/lib/hold-orders.ts, web/lib/flow-dashboard.ts, web/lib/source-data.ts, web/lib/production-flow-kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT w.id,\n    w.organization_id,\n    w.sync_batch_id,\n    w.source_row_id,\n    w.order_no,\n    w.customer_code,\n    w.customer_name,\n    w.source_due_at,\n    w.from_location,\n    w.from_zone,\n    w.to_location,\n    w.from_pack_id,\n    w.to_pack_id,\n    w.source_priority,\n    w.product_code,\n    w.product_description,\n    w.product_group,\n    w.source_qty,\n    w.source_weight,\n    w.production_units,\n    w.queue,\n    w.task,\n    w.created_at,\n    w.prints_per_garment\n   FROM (source_workbank_items w\n     JOIN v_latest_completed_batch b ON ((b.id = w.sync_batch_id)));",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "sync_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "source_row_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "customer_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "source_due_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "from_location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "from_zone",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "to_location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "from_pack_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "to_pack_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "source_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "product_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "product_description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "product_group",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 18,
      "column_name": "source_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 19,
      "column_name": "source_weight",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 20,
      "column_name": "production_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 21,
      "column_name": "queue",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 22,
      "column_name": "task",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 23,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 24,
      "column_name": "prints_per_garment",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.maintenance_attachments

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/app/maintenance/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "work_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "file_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "storage_path",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "mime_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "file_size",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "uploaded_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "uploaded_by_email",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_attachments_file_size_check",
      "constraint_type": "c",
      "definition": "CHECK (file_size >= 0)"
    },
    {
      "constraint_name": "maintenance_attachments_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_attachments_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_attachments_work_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_attachments_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_attachments_pkey ON public.maintenance_attachments USING btree (id)"
    },
    {
      "index_name": "maintenance_attachments_wo_idx",
      "definition": "CREATE INDEX maintenance_attachments_wo_idx ON public.maintenance_attachments USING btree (work_order_id, created_at)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_operator_resolve

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text",
      "result": "void",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_operator_resolve(p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare old text;a uuid;begin select status,asset_id into old,a from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;if old='OPEN_OPERATOR'then update maintenance_work_orders set status='completed',resolution='Resolved by operator',completed_at=now(),updated_at=now()where id=p_work_order_id;update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=p_work_order_id and ended_at is null;update maintenance_assets set status='operational',updated_at=now()where id=a and not exists(select 1 from maintenance_downtime_events where asset_id=a and ended_at is null);insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,p_work_order_id,old,'completed',p_actor_id,p_actor_email);end if;end$function$\n"
    }
  ]
}
```

## public.maintenance_inventory_locations

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/app/maintenance/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_inventory_locations_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_inventory_locations_organization_id_name_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, name)"
    },
    {
      "constraint_name": "maintenance_inventory_locations_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_inventory_locations_organization_id_name_key",
      "definition": "CREATE UNIQUE INDEX maintenance_inventory_locations_organization_id_name_key ON public.maintenance_inventory_locations USING btree (organization_id, name)"
    },
    {
      "index_name": "maintenance_inventory_locations_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_inventory_locations_pkey ON public.maintenance_inventory_locations USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.capacity_scenario_lines

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/production/capacity/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "capacity_scenario_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "shift_template_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "resource_count",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "machine_count",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "scheduled_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "hourly_rate",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "efficiency",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "work_days",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": "5",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "calculated_capacity",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "ALWAYS",
      "generation_expression": "(((resource_count * scheduled_hours) * hourly_rate) * efficiency)"
    }
  ],
  "constraints": [
    {
      "constraint_name": "capacity_scenario_lines_capacity_scenario_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (capacity_scenario_id) REFERENCES capacity_scenarios(id) ON DELETE CASCADE"
    },
    {
      "constraint_name": "capacity_scenario_lines_efficiency_check",
      "constraint_type": "c",
      "definition": "CHECK (efficiency >= 0::numeric AND efficiency <= 1::numeric)"
    },
    {
      "constraint_name": "capacity_scenario_lines_hourly_rate_check",
      "constraint_type": "c",
      "definition": "CHECK (hourly_rate >= 0::numeric)"
    },
    {
      "constraint_name": "capacity_scenario_lines_machine_count_check",
      "constraint_type": "c",
      "definition": "CHECK (machine_count >= 0::numeric)"
    },
    {
      "constraint_name": "capacity_scenario_lines_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "capacity_scenario_lines_production_area_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_area_id) REFERENCES production_areas(id)"
    },
    {
      "constraint_name": "capacity_scenario_lines_resource_count_check",
      "constraint_type": "c",
      "definition": "CHECK (resource_count >= 0::numeric)"
    },
    {
      "constraint_name": "capacity_scenario_lines_scheduled_hours_check",
      "constraint_type": "c",
      "definition": "CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric)"
    },
    {
      "constraint_name": "capacity_scenario_lines_shift_template_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id)"
    },
    {
      "constraint_name": "capacity_scenario_lines_work_days_check",
      "constraint_type": "c",
      "definition": "CHECK (work_days >= 0::numeric AND work_days <= 7::numeric)"
    }
  ],
  "indexes": [
    {
      "index_name": "capacity_scenario_lines_pkey",
      "definition": "CREATE UNIQUE INDEX capacity_scenario_lines_pkey ON public.capacity_scenario_lines USING btree (id)"
    },
    {
      "index_name": "capacity_scenario_lines_scenario_idx",
      "definition": "CREATE INDEX capacity_scenario_lines_scenario_idx ON public.capacity_scenario_lines USING btree (capacity_scenario_id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_preventive_plan_tasks

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "preventive_plan_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "sequence",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "task",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "instructions",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "required",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_preventive_plan_tasks_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_preventive_plan_tasks_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_preventive_plan_tasks_preventive_plan_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (preventive_plan_id) REFERENCES maintenance_preventive_plans(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_preventive_plan_tasks_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_preventive_plan_tasks_pkey ON public.maintenance_preventive_plan_tasks USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_kpi_dashboard

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT d.id AS definition_id,\n    d.organization_id,\n    d.code,\n    d.name,\n    d.category,\n    d.unit,\n    d.data_readiness_status,\n    d.dashboard_priority,\n    r.value,\n    r.numerator,\n    r.denominator,\n    r.status,\n    r.data_quality_status,\n    r.production_area_id,\n    a.code AS area_code,\n    r.source_refresh_at,\n    r.calculated_at\n   FROM ((kpi_definitions d\n     LEFT JOIN LATERAL ( SELECT x.id,\n            x.organization_id,\n            x.kpi_definition_id,\n            x.period_start,\n            x.period_end,\n            x.production_date,\n            x.production_area_id,\n            x.shift_id,\n            x.machine_id,\n            x.operator_id,\n            x.order_no,\n            x.product_code,\n            x.numerator,\n            x.denominator,\n            x.value,\n            x.target_value,\n            x.status,\n            x.data_quality_status,\n            x.source_refresh_at,\n            x.calculated_at\n           FROM kpi_results x\n          WHERE (x.kpi_definition_id = d.id)\n          ORDER BY x.calculated_at DESC\n         LIMIT 1) r ON (true))\n     LEFT JOIN production_areas a ON ((a.id = r.production_area_id)));",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "definition_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "category",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "unit",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "data_readiness_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "dashboard_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "value",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "numerator",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "denominator",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "data_quality_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "area_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "source_refresh_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "calculated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.sync_agent_heartbeat

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** PROD_CANONICAL

**DOMAIN:** B. ORACLE_SYNC / INGESTION

**USED BY:** web/lib/sync-health.ts, web/lib/ingest.ts, web/lib/source-data.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** Current code writes last_sync_attempt_at, last_success_at, next_expected_sync_at and current_run_id, which only PROD provides.

**DECISION EVIDENCE:** Current application heartbeat writer and freshness reader

**SOURCE OF TRUTH:** Latest agent execution heartbeat

**READ CONTRACT:** Sync health reads latest heartbeat and falls back to last_success_at.

**WRITE CONTRACT:** Agent upserts one row by organization and agent.

**LIFECYCLE:** Updated every heartbeat; run linkage follows current_run_id.

**IDEMPOTENCY:** Upsert key prevents duplicate agent heartbeat rows.

**BUSINESS INVARIANTS:**
- freshness timestamps are nullable but preserved
- heartbeat status never replaces completed batch authority

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "agent_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "last_seen_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "version",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "hostname",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "last_error",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "last_sync_attempt_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "last_success_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "next_expected_sync_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "current_run_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "sync_agent_heartbeat_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "sync_agent_heartbeat_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (organization_id, agent_id)"
    }
  ],
  "indexes": [
    {
      "index_name": "sync_agent_heartbeat_pkey",
      "definition": "CREATE UNIQUE INDEX sync_agent_heartbeat_pkey ON public.sync_agent_heartbeat USING btree (organization_id, agent_id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_downtime_events

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/lib/reliability-dashboard.ts, web/lib/operator-maintenance.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "work_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "started_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "ended_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "reason",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "started_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "ended_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "event_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "event_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "host_asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "host_system_asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "affected_asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "downtime_minutes",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "event_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "maintenance_class",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "failure_category",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "failure_mode",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 20,
      "column_name": "root_cause",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 21,
      "column_name": "action_taken",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 22,
      "column_name": "spare_parts_text",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 23,
      "column_name": "description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 24,
      "column_name": "counts_as_failure",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 25,
      "column_name": "counts_as_downtime",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 26,
      "column_name": "event_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 27,
      "column_name": "source_system",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 28,
      "column_name": "source_key",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 29,
      "column_name": "source_row",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 30,
      "column_name": "original_duration_minutes",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 31,
      "column_name": "clock_duration_minutes",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 32,
      "column_name": "correction_factor",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 33,
      "column_name": "data_quality_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 34,
      "column_name": "correction_confidence",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 35,
      "column_name": "correction_method",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 36,
      "column_name": "correction_note",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 37,
      "column_name": "raw_reason",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 38,
      "column_name": "historical_asset_reference",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 39,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 40,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_downtime_events_affected_asset_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (affected_asset_id) REFERENCES maintenance_assets(id)"
    },
    {
      "constraint_name": "maintenance_downtime_events_asset_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id)"
    },
    {
      "constraint_name": "maintenance_downtime_events_host_asset_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (host_asset_id) REFERENCES maintenance_assets(id)"
    },
    {
      "constraint_name": "maintenance_downtime_events_host_system_asset_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (host_system_asset_id) REFERENCES maintenance_assets(id)"
    },
    {
      "constraint_name": "maintenance_downtime_events_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_downtime_events_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_downtime_events_work_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (work_order_id) REFERENCES maintenance_work_orders(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_downtime_events_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_downtime_events_pkey ON public.maintenance_downtime_events USING btree (id)"
    },
    {
      "index_name": "maintenance_downtime_org_started_idx",
      "definition": "CREATE INDEX maintenance_downtime_org_started_idx ON public.maintenance_downtime_events USING btree (organization_id, started_at DESC)"
    },
    {
      "index_name": "maintenance_event_affected_idx",
      "definition": "CREATE INDEX maintenance_event_affected_idx ON public.maintenance_downtime_events USING btree (organization_id, affected_asset_id, event_date)"
    },
    {
      "index_name": "maintenance_event_date_idx",
      "definition": "CREATE INDEX maintenance_event_date_idx ON public.maintenance_downtime_events USING btree (organization_id, event_date)"
    },
    {
      "index_name": "maintenance_event_host_idx",
      "definition": "CREATE INDEX maintenance_event_host_idx ON public.maintenance_downtime_events USING btree (organization_id, host_asset_id, event_date)"
    },
    {
      "index_name": "maintenance_event_source_unique",
      "definition": "CREATE UNIQUE INDEX maintenance_event_source_unique ON public.maintenance_downtime_events USING btree (organization_id, source_system, source_key) WHERE ((source_system IS NOT NULL) AND (source_key IS NOT NULL))"
    },
    {
      "index_name": "maintenance_one_active_down",
      "definition": "CREATE UNIQUE INDEX maintenance_one_active_down ON public.maintenance_downtime_events USING btree (asset_id) WHERE (ended_at IS NULL)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "audit_change",
      "definition": "CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_downtime_events FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.ingest_audit_backfill

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** PROD_CANONICAL

**DOMAIN:** B. ORACLE_SYNC / INGESTION

**USED BY:** web/lib/ingest.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** PROD includes the current validated source_audit_events ingestion plus production_events rebuild required by performance. DEV lacks the complete published behavior.

**DECISION EVIDENCE:** Current published audit backfill and production event rebuild behavior

**SOURCE OF TRUTH:** Oracle audit events ingested read-only

**READ CONTRACT:** Returns rebuilt/accepted event count.

**WRITE CONTRACT:** Upserts audit evidence by source identity and rebuilds deterministic production events only when requested.

**LIFECYCLE:** Audit evidence is append/deduplicate; derived events can be deterministically rebuilt.

**IDEMPOTENCY:** Source audit identity and production event identity make reruns duplicate-free.

**BUSINESS INVARIANTS:**
- payload must be an array of at most 1000
- Oracle remains read-only
- rebuild cannot duplicate production events

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_events jsonb, p_rebuild boolean",
      "result": "bigint",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.ingest_audit_backfill(p_organization_id uuid, p_events jsonb, p_rebuild boolean DEFAULT false)\n RETURNS bigint\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare v_inserted bigint:=0;begin\n if jsonb_typeof(p_events)<>'array'or jsonb_array_length(p_events)>1000 then raise exception'INVALID_BACKFILL_PAYLOAD';end if;\n insert into public.source_audit_events(organization_id,source_audit_id,order_no,username,from_zone,to_zone,from_location,to_location,product,from_pack_id,to_pack_id,source_qty,source_weight,production_units,event_at,raw_hash,queue,task)\n select p_organization_id,event->>'sourceAuditId',coalesce(event->>'orderNo',''),event->>'username',event->>'fromZone',event->>'toZone',event->>'fromLocation',event->>'toLocation',event->>'product',event->>'fromPackId',event->>'toPackId',nullif(event->>'sourceQty','')::numeric,nullif(event->>'sourceWeight','')::numeric,coalesce(nullif(event->>'productionUnits','')::numeric,0),(event->>'eventAt')::timestamptz,event->>'rawHash',event->>'queue',event->>'task'from jsonb_array_elements(p_events)event on conflict do nothing;\n insert into production_events(organization_id,event_id,event_ts_utc,event_ts_local,calendar_date,operational_date,hour_bucket,shift_code,area,metric,quantity,unit,source,source_mode,source_record_key,quality_status,calculation_version)\n select a.organization_id,coalesce(a.source_audit_id,a.raw_hash)||':'||m.metric,a.event_at,a.event_at at time zone'Australia/Brisbane',(a.event_at at time zone'Australia/Brisbane')::date,case when r.cross_midnight and(a.event_at at time zone'Australia/Brisbane')::time<r.end_time then(a.event_at at time zone'Australia/Brisbane')::date-1 else(a.event_at at time zone'Australia/Brisbane')::date end,extract(hour from a.event_at at time zone'Australia/Brisbane')::smallint,coalesce(r.shift_code,'OUT_OF_SHIFT'),m.area,m.metric,a.production_units,m.unit,'ORACLE_AUDIT','SQL',coalesce(a.source_audit_id,a.raw_hash),case when r.shift_code is null then'OUT_OF_SHIFT'else'COMPLETE'end,'ERP_KPI_V1'\n from source_audit_events a cross join lateral(select*from(values('DTG'::text,'DTG_PRINT'::text,'prints'::text,upper(coalesce(a.queue,''))='PCOR'or upper(coalesce(a.task,''))='PCOR'),('DTG','DTG_PUTWALL_IN','garments',upper(coalesce(a.to_zone,''))='PWL1'),('DTG','DTG_PUTWALL_OUT','garments',upper(coalesce(a.from_zone,''))='PWL1'),('UP','UP_IN','garments',upper(coalesce(a.to_location,''))like'%UNDERPRINT%'),('UP','UP_OUT','garments',upper(coalesce(a.from_location,''))like'%UNDERPRINT%'and upper(coalesce(a.to_location,''))not like'%UNDERPRINT%'))v(area,metric,unit,accepted)where accepted)m\n left join lateral(select s.*from shift_rules s where s.organization_id=a.organization_id and s.active and s.effective_from<=(a.event_at at time zone'Australia/Brisbane')::date and(s.effective_to is null or s.effective_to>=(a.event_at at time zone'Australia/Brisbane')::date)and s.weekday=extract(isodow from case when s.cross_midnight and(a.event_at at time zone'Australia/Brisbane')::time<s.end_time then(a.event_at at time zone'Australia/Brisbane')::date-1 else(a.event_at at time zone'Australia/Brisbane')::date end)and(case when s.cross_midnight then(a.event_at at time zone'Australia/Brisbane')::time>=s.start_time or(a.event_at at time zone'Australia/Brisbane')::time<s.end_time else(a.event_at at time zone'Australia/Brisbane')::time>=s.start_time and(a.event_at at time zone'Australia/Brisbane')::time<s.end_time end)order by s.effective_from desc limit 1)r on true\n where a.organization_id=p_organization_id and a.production_units>0 and a.raw_hash in(select event->>'rawHash'from jsonb_array_elements(p_events)event)on conflict do nothing;get diagnostics v_inserted=row_count;return v_inserted;end$function$\n"
    }
  ]
}
```

## public.update_daily_plan_item

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/production/plans/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_item_id uuid, p_sequence integer, p_responsible text, p_units numeric, p_actor_id uuid, p_actor_email text",
      "result": "void",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.update_daily_plan_item(p_item_id uuid, p_sequence integer, p_responsible text, p_units numeric, p_actor_id uuid, p_actor_email text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare pid uuid;stat text;begin select i.production_plan_id,p.status into pid,stat from production_plan_items i join production_plans p on p.id=i.production_plan_id where i.id=p_item_id for update;if stat<>'draft'then raise exception 'Only drafts can be edited';end if;update production_plan_items set sequence=p_sequence,responsible=nullif(trim(p_responsible),''),planned_units=p_units,updated_at=now()where id=p_item_id;insert into production_plan_history(production_plan_id,action,changed_by,changed_by_email,snapshot)select pid,'item_updated',p_actor_id,p_actor_email,to_jsonb(i)from production_plan_items i where id=p_item_id;end$function$\n"
    }
  ]
}
```

## public.deputy_import_batches

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/deputy.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "filename",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "source_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "source_timezone",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "target_timezone",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'Australia/Brisbane'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "content_hash",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "imported_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "covered_from",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "covered_to",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "raw_rows",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "approved_rows",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "provisional_rows",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "quarantined_rows",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "imported_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "imported_by_email",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "error_message",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "segmented_rows",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "deputy_import_batches_organization_id_content_hash_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, content_hash)"
    },
    {
      "constraint_name": "deputy_import_batches_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "deputy_import_batches_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "deputy_import_batches_source_type_check",
      "constraint_type": "c",
      "definition": "CHECK (source_type = ANY (ARRAY['CSV'::text, 'XLSX'::text]))"
    },
    {
      "constraint_name": "deputy_import_batches_status_check",
      "constraint_type": "c",
      "definition": "CHECK (status = ANY (ARRAY['PROCESSING'::text, 'COMPLETED'::text, 'FAILED'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "deputy_batch_date_idx",
      "definition": "CREATE INDEX deputy_batch_date_idx ON public.deputy_import_batches USING btree (organization_id, imported_at DESC)"
    },
    {
      "index_name": "deputy_import_batches_organization_id_content_hash_key",
      "definition": "CREATE UNIQUE INDEX deputy_import_batches_organization_id_content_hash_key ON public.deputy_import_batches USING btree (organization_id, content_hash)"
    },
    {
      "index_name": "deputy_import_batches_pkey",
      "definition": "CREATE UNIQUE INDEX deputy_import_batches_pkey ON public.deputy_import_batches USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.sync_refresh_requests

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** PRODUCTION

**USED BY:** web/lib/sync-health.ts, web/app/api/sync/refresh/route.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "requested_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'QUEUED'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "requested_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "started_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "completed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "sync_run_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "failure_reason",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "sync_refresh_requests_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "sync_refresh_requests_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "sync_refresh_requests_status_check",
      "constraint_type": "c",
      "definition": "CHECK (status = ANY (ARRAY['QUEUED'::text, 'RUNNING'::text, 'SUCCESS'::text, 'FAILED'::text, 'SKIPPED_ALREADY_RUNNING'::text]))"
    },
    {
      "constraint_name": "sync_refresh_requests_sync_run_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (sync_run_id) REFERENCES sync_runs(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "sync_refresh_one_active_idx",
      "definition": "CREATE UNIQUE INDEX sync_refresh_one_active_idx ON public.sync_refresh_requests USING btree (organization_id) WHERE (status = ANY (ARRAY['QUEUED'::text, 'RUNNING'::text]))"
    },
    {
      "index_name": "sync_refresh_requests_pkey",
      "definition": "CREATE UNIQUE INDEX sync_refresh_requests_pkey ON public.sync_refresh_requests USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.claim_sync_work

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** PRODUCTION

**USED BY:** web/lib/ingest.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_agent_id text, p_connector_version text, p_interval_seconds integer",
      "result": "TABLE(run_id uuid, request_id uuid, trigger_type text, should_execute boolean)",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.claim_sync_work(p_organization_id uuid, p_agent_id text, p_connector_version text, p_interval_seconds integer DEFAULT 300)\n RETURNS TABLE(run_id uuid, request_id uuid, trigger_type text, should_execute boolean)\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare v_run uuid;v_request uuid;v_trigger text;v_last_auto timestamptz;begin perform pg_advisory_xact_lock(hashtextextended('sync-control:'||p_organization_id::text,0));update sync_runs set status='FAILED',completed_at=now(),duration_ms=extract(epoch from(now()-started_at))*1000,failure_reason='STALE_RUN_LEASE_EXPIRED'where organization_id=p_organization_id and status='RUNNING'and started_at<now()-interval'20 minutes';update sync_refresh_requests r set status='FAILED',completed_at=now(),failure_reason='STALE_RUN_LEASE_EXPIRED'where r.organization_id=p_organization_id and r.status='RUNNING'and not exists(select 1 from sync_runs s where s.id=r.sync_run_id and s.status='RUNNING');if exists(select 1 from sync_runs s where s.organization_id=p_organization_id and s.status='RUNNING')then insert into sync_runs(organization_id,trigger_type,status,requested_at,completed_at,agent_id,connector_version,failure_reason)values(p_organization_id,'AUTOMATIC','SKIPPED_ALREADY_RUNNING',now(),now(),p_agent_id,p_connector_version,'ACTIVE_RUN_EXISTS')returning id into v_run;return query select v_run,null::uuid,'AUTOMATIC'::text,false;return;end if;select r.id into v_request from sync_refresh_requests r where r.organization_id=p_organization_id and r.status='QUEUED'order by r.requested_at limit 1 for update skip locked;if v_request is not null then v_trigger:='MANUAL';else select max(s.requested_at)into v_last_auto from sync_runs s where s.organization_id=p_organization_id and s.trigger_type='AUTOMATIC'and s.status in('RUNNING','SUCCESS','FAILED');if v_last_auto is not null and v_last_auto>now()-make_interval(secs=>greatest(60,p_interval_seconds))then return;end if;v_trigger:='AUTOMATIC';end if;insert into sync_runs(organization_id,refresh_request_id,trigger_type,status,requested_at,started_at,agent_id,connector_version)values(p_organization_id,v_request,v_trigger,'RUNNING',now(),now(),p_agent_id,p_connector_version)returning id into v_run;if v_request is not null then update sync_refresh_requests set status='RUNNING',started_at=now(),sync_run_id=v_run where id=v_request;end if;return query select v_run,v_request,v_trigger,true;end$function$\n"
    }
  ]
}
```

## public.maintenance_create_asset

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** NEW_CLEAN_CANONICAL

**DOMAIN:** G. MAINTENANCE

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** DEV and PROD signatures and behavior agree; internal variable names/formatting are not business differences.

**DECISION EVIDENCE:** Equivalent runtime behavior and current asset action

**SOURCE OF TRUTH:** Maintenance asset registry

**READ CONTRACT:** Returns created asset UUID.

**WRITE CONTRACT:** Checks membership, allocates organization prefix sequence and inserts the asset with supplied lifecycle fields.

**LIFECYCLE:** Asset begins in requested operational status and can later be classified/retired.

**IDEMPOTENCY:** Organization-scoped asset_code uniqueness prevents duplicate generated identity.

**BUSINESS INVARIANTS:**
- prefix and organization must match
- purchase and warranty metadata remain optional

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_prefix_id uuid, p_name text, p_location text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_purchase_date date, p_purchase_cost numeric, p_warranty_expiry date, p_actor_id uuid",
      "result": "uuid",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_create_asset(p_organization_id uuid, p_prefix_id uuid, p_name text, p_location text, p_manufacturer text, p_model text, p_serial_number text, p_description text, p_criticality text, p_status text, p_installation_date date, p_purchase_date date, p_purchase_cost numeric, p_warranty_expiry date, p_actor_id uuid)\n RETURNS uuid\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare p text;c uuid;n integer;code text;a uuid;begin if not exists(select 1 from maintenance_members where organization_id=p_organization_id and user_id=p_actor_id and active and role in('admin','maintenance'))then raise exception'Maintenance permission denied';end if;select prefix,category_id into p,c from maintenance_asset_prefixes where id=p_prefix_id and organization_id=p_organization_id and active for share;if p is null then raise exception'Invalid or inactive asset prefix';end if;insert into maintenance_asset_code_sequences values(p_organization_id,p,0,now())on conflict do nothing;update maintenance_asset_code_sequences set last_number=last_number+1,updated_at=now()where organization_id=p_organization_id and prefix=p returning last_number into n;if n>999 then raise exception'Asset sequence exhausted';end if;code:=p||'-'||lpad(n::text,3,'0');insert into maintenance_assets(organization_id,asset_code,name,asset_name,category_id,prefix_id,location,manufacturer,model,serial_number,description,criticality,status,installation_date,purchase_date,purchase_cost,warranty_expiry,installed_at,created_by)values(p_organization_id,code,p_name,p_name,c,p_prefix_id,nullif(trim(p_location),''),nullif(trim(p_manufacturer),''),nullif(trim(p_model),''),nullif(trim(p_serial_number),''),nullif(trim(p_description),''),p_criticality,p_status,p_installation_date,p_purchase_date,p_purchase_cost,p_warranty_expiry,case when p_installation_date is not null then p_installation_date::timestamptz end,p_actor_id)returning id into a;return a;end$function$\n"
    }
  ]
}
```

## public.resource_capacity_rules

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** NEW_CLEAN_CANONICAL

**DOMAIN:** H. PRODUCTION / PERFORMANCE

**USED BY:** web/lib/erp-kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** Only index definition/order differs. V2 keeps one query-aligned partial lookup index and the identical table contract.

**DECISION EVIDENCE:** Equivalent data contract plus current capacity lookup

**SOURCE OF TRUTH:** Effective-dated resource capacity configuration

**READ CONTRACT:** Active rules filtered by organization/process/date and ordered by effective_from.

**WRITE CONTRACT:** Authorized configuration management only.

**LIFECYCLE:** Effective date interval selects applicable rule; inactive rules do not contribute.

**IDEMPOTENCY:** Canonical uniqueness prevents overlapping duplicate identity at the configured grain.

**BUSINESS INVARIANTS:**
- max_resources is non-negative
- effective_to cannot precede effective_from

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "process",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "resource_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "shift_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "max_resources",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "condition_context",
      "data_type": "jsonb",
      "udt_schema": "pg_catalog",
      "udt_name": "jsonb",
      "is_nullable": "NO",
      "column_default": "'{}'::jsonb",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "effective_from",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "effective_to",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "calculation_version",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'ERP_KPI_V1'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "resource_capacity_rules_check",
      "constraint_type": "c",
      "definition": "CHECK (effective_to IS NULL OR effective_to >= effective_from)"
    },
    {
      "constraint_name": "resource_capacity_rules_max_resources_check",
      "constraint_type": "c",
      "definition": "CHECK (max_resources >= 0::numeric)"
    },
    {
      "constraint_name": "resource_capacity_rules_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "resource_capacity_rules_organization_id_resource_code_shift_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, resource_code, shift_code, effective_from)"
    },
    {
      "constraint_name": "resource_capacity_rules_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "resource_capacity_rules_process_check",
      "constraint_type": "c",
      "definition": "CHECK (process = ANY (ARRAY['DTG'::text, 'UP'::text, 'SCREEN_PRINT'::text]))"
    },
    {
      "constraint_name": "resource_capacity_rules_shift_code_check",
      "constraint_type": "c",
      "definition": "CHECK (shift_code = ANY (ARRAY['SHIFT_1'::text, 'SHIFT_2'::text, 'SHIFT_3'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "resource_capacity_rules_lookup_idx",
      "definition": "CREATE INDEX resource_capacity_rules_lookup_idx ON public.resource_capacity_rules USING btree (organization_id, process, effective_from, effective_to) WHERE active"
    },
    {
      "index_name": "resource_capacity_rules_organization_id_resource_code_shift_key",
      "definition": "CREATE UNIQUE INDEX resource_capacity_rules_organization_id_resource_code_shift_key ON public.resource_capacity_rules USING btree (organization_id, resource_code, shift_code, effective_from)"
    },
    {
      "index_name": "resource_capacity_rules_pkey",
      "definition": "CREATE UNIQUE INDEX resource_capacity_rules_pkey ON public.resource_capacity_rules USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.capacity_legacy_overrides

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/capacity.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "source_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "daily_capacity",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "work_days",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": "5",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "temporary",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "capacity_legacy_overrides_daily_capacity_check",
      "constraint_type": "c",
      "definition": "CHECK (daily_capacity >= 0::numeric)"
    },
    {
      "constraint_name": "capacity_legacy_overrides_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "capacity_legacy_overrides_organization_id_production_area_i_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, production_area_id, source_name)"
    },
    {
      "constraint_name": "capacity_legacy_overrides_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "capacity_legacy_overrides_production_area_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_area_id) REFERENCES production_areas(id)"
    },
    {
      "constraint_name": "capacity_legacy_overrides_work_days_check",
      "constraint_type": "c",
      "definition": "CHECK (work_days >= 0::numeric AND work_days <= 7::numeric)"
    }
  ],
  "indexes": [
    {
      "index_name": "capacity_legacy_overrides_organization_id_production_area_i_key",
      "definition": "CREATE UNIQUE INDEX capacity_legacy_overrides_organization_id_production_area_i_key ON public.capacity_legacy_overrides USING btree (organization_id, production_area_id, source_name)"
    },
    {
      "index_name": "capacity_legacy_overrides_pkey",
      "definition": "CREATE UNIQUE INDEX capacity_legacy_overrides_pkey ON public.capacity_legacy_overrides USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_dtg_operational_orders

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/performance-workload.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " SELECT w.organization_id,\n    w.order_no,\n    max(COALESCE(w.customer_name, o.customer_name)) AS customer_name,\n    max(o.delivery_desc) AS screen,\n    max(o.source_status) AS status,\n    max(COALESCE(w.source_priority, o.source_priority)) AS priority,\n    min(COALESCE(w.source_due_at, o.date_due)) AS date_due,\n    GREATEST(0, (((now() AT TIME ZONE 'Australia/Brisbane'::text))::date - ((max(o.date_released) AT TIME ZONE 'Australia/Brisbane'::text))::date)) AS age_days,\n    count(*) AS item_count,\n    (count(*))::numeric AS remaining_units,\n    NULL::timestamp with time zone AS last_movement,\n    string_agg(DISTINCT COALESCE(NULLIF(w.to_location, ''::text), w.from_location), ', '::text ORDER BY COALESCE(NULLIF(w.to_location, ''::text), w.from_location)) AS putwall_locations,\n    'At DTG'::text AS progress_label,\n    sum(w.prints_per_garment) AS total_prints,\n    sum(\n        CASE\n            WHEN ((upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'MENS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'WOMENS%'::text)) THEN w.prints_per_garment\n            ELSE (0)::numeric\n        END) AS adult_prints,\n    sum(\n        CASE\n            WHEN ((upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'BOYS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'GIRLS%'::text)) THEN w.prints_per_garment\n            ELSE (0)::numeric\n        END) AS kids_prints,\n    sum(\n        CASE\n            WHEN (NOT ((upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'MENS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'WOMENS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'BOYS%'::text) OR (upper(TRIM(BOTH FROM COALESCE(w.product_description, ''::text))) ~~ 'GIRLS%'::text))) THEN w.prints_per_garment\n            ELSE (0)::numeric\n        END) AS unclassified_prints\n   FROM (v_current_workbank w\n     LEFT JOIN v_current_orders o ON (((o.organization_id = w.organization_id) AND (o.order_no = w.order_no))))\n  WHERE (upper(COALESCE(w.from_zone, ''::text)) = 'DTGS'::text)\n  GROUP BY w.organization_id, w.order_no;",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "screen",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "date_due",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "age_days",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "item_count",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "remaining_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "last_movement",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "putwall_locations",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "progress_label",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "total_prints",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "adult_prints",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "kids_prints",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "unclassified_prints",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.maintenance_operator_escalate

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text",
      "result": "void",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_operator_escalate(p_organization_id uuid, p_work_order_id uuid, p_actor_id uuid, p_actor_email text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$declare old text;begin select status into old from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id for update;if old is null then raise exception'Work order not found';end if;if old='OPEN_OPERATOR'then update maintenance_work_orders set status='WAITING_MAINTENANCE',request_type='CORRECTIVE_NOW',maintenance_requested_at=coalesce(maintenance_requested_at,now()),updated_at=now()where id=p_work_order_id;insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,p_work_order_id,old,'WAITING_MAINTENANCE',p_actor_id,p_actor_email);end if;end$function$\n"
    }
  ]
}
```

## public.sync_batches

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** PROD_CANONICAL

**DOMAIN:** B. ORACLE_SYNC / INGESTION

**USED BY:** web/lib/sync-health.ts, web/lib/source-data.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** PRESENT - validate/replace against this contract

**DECISION:** PROD adds release_line_count required to audit the authoritative line-level release snapshot; DEV lacks it.

**DECISION EVIDENCE:** Current production ingestion including release-line provenance

**SOURCE OF TRUTH:** Sync batch execution ledger

**READ CONTRACT:** Freshness and source readers select completed batches and their counts.

**WRITE CONTRACT:** Ingestion creates running batch and finalizes status/counts/error.

**LIFECYCLE:** running to completed/failed; only completed is current.

**IDEMPOTENCY:** Each run has one UUID; current selection is deterministic by completion.

**BUSINESS INVARIANTS:**
- release_line_count defaults to zero
- failed batches never become current

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "started_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "completed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "orders_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "workbank_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "stock_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "audit_new_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "error_message",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "connector_version",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "release_line_count",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "0",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "sync_batches_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "sync_batches_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "sync_batches_status_check",
      "constraint_type": "c",
      "definition": "CHECK (status = ANY (ARRAY['running'::text, 'completed'::text, 'failed'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "sync_batches_pkey",
      "definition": "CREATE UNIQUE INDEX sync_batches_pkey ON public.sync_batches USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.production_stage_source_rules

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/production-flow-kpis.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "production_stage_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "source_dataset",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "source_field",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "match_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "match_value",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "NO",
      "column_default": "100",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "validation_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'VALIDATED'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "production_stage_source_rules_match_type_check",
      "constraint_type": "c",
      "definition": "CHECK (match_type = ANY (ARRAY['exact'::text, 'contains'::text, 'starts_with'::text, 'ends_with'::text, 'regex'::text]))"
    },
    {
      "constraint_name": "production_stage_source_rules_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "production_stage_source_rules_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "production_stage_source_rules_production_stage_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_stage_id) REFERENCES production_process_stages(id)"
    },
    {
      "constraint_name": "production_stage_source_rules_validation_status_check",
      "constraint_type": "c",
      "definition": "CHECK (validation_status = ANY (ARRAY['VALIDATED'::text, 'REQUIRES_VALIDATION'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "production_stage_source_rules_pkey",
      "definition": "CREATE UNIQUE INDEX production_stage_source_rules_pkey ON public.production_stage_source_rules USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_assets

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/lib/reliability-dashboard.ts, web/lib/operator-maintenance.ts, web/app/maintenance/actions.ts, web/app/maintenance/assets/[id]/page.tsx, web/app/maintenance/scan/[token]/page.tsx

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "asset_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "criticality",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'medium'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'operational'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "created_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "public_qr_token",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "asset_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "category_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "prefix_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "parent_asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "manufacturer",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "model",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "serial_number",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 20,
      "column_name": "description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 21,
      "column_name": "installation_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 22,
      "column_name": "purchase_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 23,
      "column_name": "purchase_cost",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 24,
      "column_name": "warranty_expiry",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 25,
      "column_name": "installed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 26,
      "column_name": "removed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 27,
      "column_name": "installed_work_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 28,
      "column_name": "removed_work_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 29,
      "column_name": "asset_kind",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'FIXED'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 30,
      "column_name": "asset_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 31,
      "column_name": "asset_category",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 32,
      "column_name": "commission_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 33,
      "column_name": "retire_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 34,
      "column_name": "notes",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 35,
      "column_name": "asset_level",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'EQUIPMENT'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 36,
      "column_name": "operational_role",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'SUPPORT'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 37,
      "column_name": "counts_in_availability",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 38,
      "column_name": "capacity_resource",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_assets_asset_kind_check",
      "constraint_type": "c",
      "definition": "CHECK (asset_kind = ANY (ARRAY['FIXED'::text, 'MOVABLE'::text]))"
    },
    {
      "constraint_name": "maintenance_assets_asset_level_check",
      "constraint_type": "c",
      "definition": "CHECK (asset_level = ANY (ARRAY['SYSTEM'::text, 'EQUIPMENT'::text, 'SUBSYSTEM'::text, 'COMPONENT'::text]))"
    },
    {
      "constraint_name": "maintenance_assets_category_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (category_id) REFERENCES maintenance_asset_categories(id)"
    },
    {
      "constraint_name": "maintenance_assets_criticality_check",
      "constraint_type": "c",
      "definition": "CHECK (criticality = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]))"
    },
    {
      "constraint_name": "maintenance_assets_installed_work_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (installed_work_order_id) REFERENCES maintenance_work_orders(id)"
    },
    {
      "constraint_name": "maintenance_assets_operational_role_check",
      "constraint_type": "c",
      "definition": "CHECK (operational_role = ANY (ARRAY['PRODUCTION'::text, 'UTILITY'::text, 'SUPPORT'::text, 'MOVABLE'::text]))"
    },
    {
      "constraint_name": "maintenance_assets_organization_id_asset_code_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, asset_code)"
    },
    {
      "constraint_name": "maintenance_assets_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_assets_parent_asset_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (parent_asset_id) REFERENCES maintenance_assets(id)"
    },
    {
      "constraint_name": "maintenance_assets_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_assets_prefix_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (prefix_id) REFERENCES maintenance_asset_prefixes(id)"
    },
    {
      "constraint_name": "maintenance_assets_removed_work_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (removed_work_order_id) REFERENCES maintenance_work_orders(id)"
    },
    {
      "constraint_name": "maintenance_assets_status_check",
      "constraint_type": "c",
      "definition": "CHECK (status = ANY (ARRAY['operational'::text, 'down'::text, 'maintenance'::text, 'standby'::text, 'retired'::text, 'scrapped'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_asset_org_status_idx",
      "definition": "CREATE INDEX maintenance_asset_org_status_idx ON public.maintenance_assets USING btree (organization_id, status) WHERE active"
    },
    {
      "index_name": "maintenance_asset_parent_idx",
      "definition": "CREATE INDEX maintenance_asset_parent_idx ON public.maintenance_assets USING btree (organization_id, parent_asset_id)"
    },
    {
      "index_name": "maintenance_asset_qr_token_idx",
      "definition": "CREATE UNIQUE INDEX maintenance_asset_qr_token_idx ON public.maintenance_assets USING btree (public_qr_token)"
    },
    {
      "index_name": "maintenance_asset_search_idx",
      "definition": "CREATE INDEX maintenance_asset_search_idx ON public.maintenance_assets USING btree (organization_id, asset_code, name, serial_number)"
    },
    {
      "index_name": "maintenance_assets_availability_idx",
      "definition": "CREATE INDEX maintenance_assets_availability_idx ON public.maintenance_assets USING btree (organization_id, counts_in_availability) WHERE (active AND counts_in_availability)"
    },
    {
      "index_name": "maintenance_assets_organization_id_asset_code_key",
      "definition": "CREATE UNIQUE INDEX maintenance_assets_organization_id_asset_code_key ON public.maintenance_assets USING btree (organization_id, asset_code)"
    },
    {
      "index_name": "maintenance_assets_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_assets_pkey ON public.maintenance_assets USING btree (id)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "audit_change",
      "definition": "CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_assets FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_machine_load_not_approved

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** PRODUCTION

**USED BY:** web/lib/machine-load.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " WITH order_process AS (\n         SELECT l_1.organization_id,\n            l_1.sync_batch_id,\n            l_1.order_no,\n            bool_or((upper(TRIM(BOTH FROM l_1.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text]))) AS has_dtg,\n            bool_or((upper(TRIM(BOTH FROM l_1.group_code)) = 'UNDERPRINT'::text)) AS has_underprint,\n            bool_or((upper(TRIM(BOTH FROM l_1.group_code)) <> ALL (ARRAY['DTG_1'::text, 'DTG_2'::text, 'UNDERPRINT'::text]))) AS has_other\n           FROM (v_current_release_order_lines l_1\n             JOIN v_release_queue q_1 ON (((q_1.organization_id = l_1.organization_id) AND (q_1.sync_batch_id = l_1.sync_batch_id) AND (q_1.order_no = l_1.order_no) AND (q_1.release_status = 'NOT_APPROVED'::text))))\n          WHERE (l_1.qty_lcd > (0)::numeric)\n          GROUP BY l_1.organization_id, l_1.sync_batch_id, l_1.order_no\n        )\n SELECT l.organization_id,\n    l.sync_batch_id,\n    l.order_no,\n    l.line_number,\n    l.product,\n    l.client,\n    l.product_name,\n    l.group_code AS source_process_code,\n    l.qty_lcd AS process_quantity,\n    'PROCESS_QUANTITY'::text AS quantity_semantics,\n    q.customer_name,\n    q.date_due,\n    q.source_priority,\n    q.site,\n    q.route_id AS release_route_evidence,\n    NULL::uuid AS routing_id,\n    NULL::text AS routing_code,\n    NULL::integer AS routing_revision,\n    NULL::text AS machine_group,\n        CASE\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text])) THEN 'DTG'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'UNDERPRINT'::text) THEN 'UNDERPRINT'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'UV PRINT'::text) THEN 'UV'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'HATS'::text) THEN 'HATS'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'FINISHED'::text) THEN 'FINISHED'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'STICKERS'::text) THEN 'STICKERS'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'VISUAL'::text) THEN 'VISUAL'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'PROD'::text) THEN 'PRODUCTION'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'CUSTOM EMB'::text) THEN 'CUSTOM EMB'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'EYEWEAR'::text) THEN 'EYEWEAR'::text\n            ELSE 'UNRESOLVED'::text\n        END AS process,\n        CASE\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = ANY (ARRAY['DTG_1'::text, 'DTG_2'::text])) THEN 'DTG'::text\n            WHEN (upper(TRIM(BOTH FROM l.group_code)) = 'UNDERPRINT'::text) THEN 'UNDERPRINT'::text\n            ELSE NULL::text\n        END AS machine_load_bucket,\n        CASE\n            WHEN ((((op.has_dtg)::integer + (op.has_underprint)::integer) = 1) AND (NOT op.has_other)) THEN 'RESOLVED'::text\n            WHEN ((op.has_dtg OR op.has_underprint) AND (op.has_other OR (op.has_dtg AND op.has_underprint))) THEN 'AMBIGUOUS'::text\n            ELSE 'UNRESOLVED'::text\n        END AS routing_resolution,\n    'NOT_APPROVED'::text AS release_status,\n    q.release_blockers,\n    q.snapshot_completed_at\n   FROM ((v_current_release_order_lines l\n     JOIN v_release_queue q ON (((q.organization_id = l.organization_id) AND (q.sync_batch_id = l.sync_batch_id) AND (q.order_no = l.order_no) AND (q.release_status = 'NOT_APPROVED'::text))))\n     JOIN order_process op ON (((op.organization_id = l.organization_id) AND (op.sync_batch_id = l.sync_batch_id) AND (op.order_no = l.order_no))))\n  WHERE (l.qty_lcd > (0)::numeric);",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "sync_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "line_number",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "product",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "client",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "product_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "source_process_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "process_quantity",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 10,
      "column_name": "quantity_semantics",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 11,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 12,
      "column_name": "date_due",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 13,
      "column_name": "source_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 14,
      "column_name": "site",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 15,
      "column_name": "release_route_evidence",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 16,
      "column_name": "routing_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 17,
      "column_name": "routing_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 18,
      "column_name": "routing_revision",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 19,
      "column_name": "machine_group",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 20,
      "column_name": "process",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 21,
      "column_name": "machine_load_bucket",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 22,
      "column_name": "routing_resolution",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 23,
      "column_name": "release_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 24,
      "column_name": "release_blockers",
      "data_type": "ARRAY",
      "udt_schema": "pg_catalog",
      "udt_name": "_text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 25,
      "column_name": "snapshot_completed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.maintenance_component_prefixes

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/maintenance.ts, web/app/maintenance/assets/[id]/page.tsx

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "prefix",
      "data_type": "character varying",
      "udt_schema": "pg_catalog",
      "udt_name": "varchar",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_component_prefixes_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_component_prefixes_organization_id_prefix_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, prefix)"
    },
    {
      "constraint_name": "maintenance_component_prefixes_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_component_prefixes_prefix_check",
      "constraint_type": "c",
      "definition": "CHECK (prefix::text ~ '^[A-Z]{2,4}$'::text)"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_component_prefixes_organization_id_prefix_key",
      "definition": "CREATE UNIQUE INDEX maintenance_component_prefixes_organization_id_prefix_key ON public.maintenance_component_prefixes USING btree (organization_id, prefix)"
    },
    {
      "index_name": "maintenance_component_prefixes_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_component_prefixes_pkey ON public.maintenance_component_prefixes USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.v_order_stage_summary

**TYPE:** VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/source-data.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "VIEW",
  "definition": " WITH classified AS (\n         SELECT w.id,\n            w.organization_id,\n            w.sync_batch_id,\n            w.source_row_id,\n            w.order_no,\n            w.customer_code,\n            w.customer_name,\n            w.source_due_at,\n            w.from_location,\n            w.from_zone,\n            w.to_location,\n            w.from_pack_id,\n            w.to_pack_id,\n            w.source_priority,\n            w.product_code,\n            w.product_description,\n            w.product_group,\n            w.source_qty,\n            w.source_weight,\n            w.production_units,\n            w.queue,\n            w.task,\n            w.created_at,\n            COALESCE(mapped.code, 'UNMAPPED'::text) AS stage_code,\n            COALESCE(mapped.name, 'Unmapped'::text) AS stage_name,\n            (w.production_units * COALESCE(rule.multiplier, (1)::numeric)) AS converted_units\n           FROM ((v_current_workbank w\n             LEFT JOIN LATERAL ( SELECT a.code,\n                    a.name\n                   FROM (production_stage_mappings m\n                     JOIN production_areas a ON ((a.id = m.production_area_id)))\n                  WHERE ((m.organization_id = w.organization_id) AND m.active AND a.active AND\n                        CASE m.source_field\n                            WHEN 'from_zone'::text THEN (COALESCE(w.from_zone, ''::text) ~~* m.match_pattern)\n                            WHEN 'from_location'::text THEN (COALESCE(w.from_location, ''::text) ~~* m.match_pattern)\n                            ELSE NULL::boolean\n                        END)\n                  ORDER BY m.priority\n                 LIMIT 1) mapped ON (true))\n             LEFT JOIN LATERAL ( SELECT r.multiplier\n                   FROM quantity_conversion_rules r\n                  WHERE ((r.organization_id = w.organization_id) AND r.active AND (COALESCE(w.product_group, ''::text) ~~* r.product_group_pattern))\n                  ORDER BY r.priority\n                 LIMIT 1) rule ON (true))\n        )\n SELECT organization_id,\n    order_no,\n    max(customer_name) AS customer_name,\n    min(source_due_at) AS due_at,\n    stage_code,\n    max(stage_name) AS stage_name,\n    count(*) AS item_count,\n    sum(converted_units) AS production_units,\n    GREATEST(0, (CURRENT_DATE - COALESCE((min(source_due_at))::date, CURRENT_DATE))) AS age_days\n   FROM classified\n  GROUP BY organization_id, order_no, stage_code;",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 2,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 3,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 4,
      "column_name": "due_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 5,
      "column_name": "stage_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 6,
      "column_name": "stage_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 7,
      "column_name": "item_count",
      "data_type": "bigint",
      "udt_schema": "pg_catalog",
      "udt_name": "int8",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 8,
      "column_name": "production_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null
    },
    {
      "ordinal_position": 9,
      "column_name": "age_days",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null
    }
  ]
}
```

## public.apply_production_planning

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** NEW_CLEAN_CANONICAL

**DOMAIN:** E. ROUTING / PLANNING

**USED BY:** web/lib/planning.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** Bodies differ mainly by formatting. V2 freezes one readable implementation with existing signature, transition checks and history.

**DECISION EVIDENCE:** Equivalent DEV/PROD behavior, current action validation and audit requirement

**SOURCE OF TRUTH:** Planner-controlled production order attributes

**READ CONTRACT:** Returns number of changed orders.

**WRITE CONTRACT:** Validates orders/shift/status transition, updates approved planner fields and inserts before/after history per order.

**LIFECYCLE:** unplanned/planned/blocked/completed/cancelled transitions follow approved transition matrix.

**IDEMPOTENCY:** Reapplying identical changes leaves values stable; history is emitted only for an applied update according to the frozen body.

**BUSINESS INVARIANTS:**
- source fields are never rewritten
- blocked requires a reason
- routing identity is preserved

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_order_nos text[], p_changes jsonb, p_actor_id uuid, p_actor_email text",
      "result": "integer",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.apply_production_planning(p_organization_id uuid, p_order_nos text[], p_changes jsonb, p_actor_id uuid, p_actor_email text)\n RETURNS integer\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$\r\ndeclare n text; row_id uuid; old_row jsonb; new_row jsonb; old_status text; new_status text; changed integer:=0;\r\nbegin\r\n  if coalesce(array_length(p_order_nos,1),0)=0 then raise exception 'At least one order is required'; end if;\r\n  if p_changes ? 'planned_shift_id' and nullif(p_changes->>'planned_shift_id','') is not null and not exists(select 1 from shift_templates where id=(p_changes->>'planned_shift_id')::uuid and organization_id=p_organization_id and active) then raise exception 'Invalid shift'; end if;\r\n  foreach n in array p_order_nos loop\r\n    if not exists(select 1 from v_current_orders where organization_id=p_organization_id and order_no=n) then raise exception 'Unknown source order %',n; end if;\r\n    insert into production_orders(organization_id,order_no,updated_by) values(p_organization_id,n,p_actor_id) on conflict do nothing;\r\n    select id,to_jsonb(po),planning_status into row_id,old_row,old_status from production_orders po where organization_id=p_organization_id and order_no=n for update;\r\n    new_status=coalesce(nullif(p_changes->>'planning_status',''),old_status);\r\n    if new_status<>old_status and not ((old_status='unplanned' and new_status in ('planned','cancelled')) or (old_status='planned' and new_status in ('unplanned','ready','blocked','waiting','cancelled')) or (old_status='ready' and new_status in ('planned','in_progress','blocked','waiting','cancelled')) or (old_status='in_progress' and new_status in ('blocked','waiting','completed','cancelled')) or (old_status in ('blocked','waiting') and new_status in ('planned','ready','in_progress','cancelled')) or (old_status in ('completed','cancelled') and new_status='unplanned')) then raise exception 'Invalid status transition: % to %',old_status,new_status; end if;\r\n    update production_orders set\r\n      planner_priority=case when p_changes?'planner_priority' then nullif(p_changes->>'planner_priority','')::integer else planner_priority end,\r\n      planned_date=case when p_changes?'planned_date' then nullif(p_changes->>'planned_date','')::date else planned_date end,\r\n      planned_shift_id=case when p_changes?'planned_shift_id' then nullif(p_changes->>'planned_shift_id','')::uuid else planned_shift_id end,\r\n      planning_status=new_status,\r\n      special_instruction=case when p_changes?'special_instruction' then nullif(trim(p_changes->>'special_instruction'),'') else special_instruction end,\r\n      planner_note=case when p_changes?'planner_note' then nullif(trim(p_changes->>'planner_note'),'') else planner_note end,\r\n      blocked_reason=case when new_status='blocked' then nullif(trim(p_changes->>'blocked_reason'),'') else null end,\r\n      updated_at=now(),updated_by=p_actor_id where id=row_id returning to_jsonb(production_orders.*) into new_row;\r\n    insert into production_order_history(production_order_id,organization_id,order_no,changed_by,changed_by_email,before_state,after_state) values(row_id,p_organization_id,n,p_actor_id,p_actor_email,old_row,new_row);\r\n    changed=changed+1;\r\n  end loop;\r\n  return changed;\r\nend $function$\n"
    }
  ]
}
```

## public.deputy_raw_timesheets

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/labour-dashboard.ts, web/lib/deputy.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "import_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "source_row_key",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "source_timesheet_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "employee_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "person_key",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "display_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "timesheet_date",
      "data_type": "date",
      "udt_schema": "pg_catalog",
      "udt_name": "date",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "raw_area",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "normalized_area",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "start_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "end_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "total_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "meal_break_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "approval_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "row_status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "quarantine_reasons",
      "data_type": "ARRAY",
      "udt_schema": "pg_catalog",
      "udt_name": "_text",
      "is_nullable": "NO",
      "column_default": "'{}'::text[]",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "raw_data",
      "data_type": "jsonb",
      "udt_schema": "pg_catalog",
      "udt_name": "jsonb",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 20,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "deputy_raw_timesheets_approval_status_check",
      "constraint_type": "c",
      "definition": "CHECK (approval_status = ANY (ARRAY['APPROVED'::text, 'PROVISIONAL'::text, 'INCOMPLETE'::text]))"
    },
    {
      "constraint_name": "deputy_raw_timesheets_import_batch_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (import_batch_id) REFERENCES deputy_import_batches(id)"
    },
    {
      "constraint_name": "deputy_raw_timesheets_import_batch_id_source_row_key_key",
      "constraint_type": "u",
      "definition": "UNIQUE (import_batch_id, source_row_key)"
    },
    {
      "constraint_name": "deputy_raw_timesheets_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "deputy_raw_timesheets_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "deputy_raw_timesheets_row_status_check",
      "constraint_type": "c",
      "definition": "CHECK (row_status = ANY (ARRAY['ACCEPTED'::text, 'QUARANTINED'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "deputy_period_idx",
      "definition": "CREATE INDEX deputy_period_idx ON public.deputy_raw_timesheets USING btree (organization_id, timesheet_date, normalized_area)"
    },
    {
      "index_name": "deputy_quarantine_idx",
      "definition": "CREATE INDEX deputy_quarantine_idx ON public.deputy_raw_timesheets USING btree (organization_id, row_status) WHERE (row_status = 'QUARANTINED'::text)"
    },
    {
      "index_name": "deputy_raw_timesheets_import_batch_id_source_row_key_key",
      "definition": "CREATE UNIQUE INDEX deputy_raw_timesheets_import_batch_id_source_row_key_key ON public.deputy_raw_timesheets USING btree (import_batch_id, source_row_key)"
    },
    {
      "index_name": "deputy_raw_timesheets_pkey",
      "definition": "CREATE UNIQUE INDEX deputy_raw_timesheets_pkey ON public.deputy_raw_timesheets USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_work_orders

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** NEW_CLEAN_CANONICAL

**DOMAIN:** G. MAINTENANCE

**USED BY:** web/lib/maintenance.ts, web/lib/reliability-dashboard.ts, web/app/maintenance/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

**DECISION:** The only table difference is physical column order. V2 uses one clean logical order without changing any column contract.

**DECISION EVIDENCE:** Same DEV/PROD logical schema and current maintenance runtime

**SOURCE OF TRUTH:** Corrective/preventive/operator maintenance work order

**READ CONTRACT:** Maintenance pages read work order, asset, status, priority, type, lifecycle timestamps and operator workflow fields.

**WRITE CONTRACT:** Maintenance RPCs and authorized actions create/transition/update work orders.

**LIFECYCLE:** open/in_progress/waiting/completed/cancelled with protected history and operator/preventive subflows.

**IDEMPOTENCY:** operator_request_key and source PM linkage prevent duplicate workflow creation where applicable.

**BUSINESS INVARIANTS:**
- completion/cancellation is audited
- preventive and corrective semantics remain explicit
- organization and asset scope enforced

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "work_order_number",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "status",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'open'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "priority",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'medium'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "title",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "problem_description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "root_cause",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "resolution",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "requested_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "requested_by_email",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "requested_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "started_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "completed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "cancel_reason",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "due_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "work_order_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'corrective'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 20,
      "column_name": "preventive_plan_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 21,
      "column_name": "component_asset_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 22,
      "column_name": "no_parts_used_confirmed",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 23,
      "column_name": "no_parts_used_confirmed_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 24,
      "column_name": "no_parts_used_confirmed_by",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 25,
      "column_name": "source_pm_work_order_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 26,
      "column_name": "request_flow",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 27,
      "column_name": "request_type",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 28,
      "column_name": "maintenance_requested_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 29,
      "column_name": "counts_as_downtime",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 30,
      "column_name": "operator_request_key",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 31,
      "column_name": "downtime_started_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "maintenance_wo_pm_fk",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (preventive_plan_id) REFERENCES maintenance_preventive_plans(id)"
    },
    {
      "constraint_name": "maintenance_work_orders_asset_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (asset_id) REFERENCES maintenance_assets(id)"
    },
    {
      "constraint_name": "maintenance_work_orders_component_asset_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (component_asset_id) REFERENCES maintenance_assets(id)"
    },
    {
      "constraint_name": "maintenance_work_orders_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "maintenance_work_orders_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "maintenance_work_orders_priority_check",
      "constraint_type": "c",
      "definition": "CHECK (priority = ANY (ARRAY['low'::text, 'medium'::text, 'high'::text, 'critical'::text]))"
    },
    {
      "constraint_name": "maintenance_work_orders_request_flow_check",
      "constraint_type": "c",
      "definition": "CHECK (request_flow = ANY (ARRAY['operator_fix'::text, 'maintenance_required'::text, 'maintenance_request'::text]))"
    },
    {
      "constraint_name": "maintenance_work_orders_source_pm_work_order_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (source_pm_work_order_id) REFERENCES maintenance_work_orders(id)"
    },
    {
      "constraint_name": "maintenance_work_orders_status_check",
      "constraint_type": "c",
      "definition": "CHECK (status = ANY (ARRAY['open'::text, 'in_progress'::text, 'waiting_parts'::text, 'waiting_external'::text, 'completed'::text, 'cancelled'::text, 'OPEN_OPERATOR'::text, 'WAITING_MAINTENANCE'::text, 'REQUESTED'::text]))"
    },
    {
      "constraint_name": "maintenance_work_orders_work_order_number_key",
      "constraint_type": "u",
      "definition": "UNIQUE (work_order_number)"
    },
    {
      "constraint_name": "maintenance_work_orders_work_order_type_check",
      "constraint_type": "c",
      "definition": "CHECK (work_order_type = ANY (ARRAY['corrective'::text, 'preventive'::text, 'inspection'::text]))"
    }
  ],
  "indexes": [
    {
      "index_name": "maintenance_one_open_pm",
      "definition": "CREATE UNIQUE INDEX maintenance_one_open_pm ON public.maintenance_work_orders USING btree (preventive_plan_id) WHERE ((preventive_plan_id IS NOT NULL) AND (status <> ALL (ARRAY['completed'::text, 'cancelled'::text])))"
    },
    {
      "index_name": "maintenance_operator_request_key_uq",
      "definition": "CREATE UNIQUE INDEX maintenance_operator_request_key_uq ON public.maintenance_work_orders USING btree (organization_id, operator_request_key) WHERE (operator_request_key IS NOT NULL)"
    },
    {
      "index_name": "maintenance_wo_org_status_due_idx",
      "definition": "CREATE INDEX maintenance_wo_org_status_due_idx ON public.maintenance_work_orders USING btree (organization_id, status, due_at)"
    },
    {
      "index_name": "maintenance_wo_source_pm_idx",
      "definition": "CREATE INDEX maintenance_wo_source_pm_idx ON public.maintenance_work_orders USING btree (source_pm_work_order_id) WHERE (source_pm_work_order_id IS NOT NULL)"
    },
    {
      "index_name": "maintenance_work_orders_pkey",
      "definition": "CREATE UNIQUE INDEX maintenance_work_orders_pkey ON public.maintenance_work_orders USING btree (id)"
    },
    {
      "index_name": "maintenance_work_orders_work_order_number_key",
      "definition": "CREATE UNIQUE INDEX maintenance_work_orders_work_order_number_key ON public.maintenance_work_orders USING btree (work_order_number)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "audit_change",
      "definition": "CREATE TRIGGER audit_change AFTER INSERT OR DELETE OR UPDATE ON maintenance_work_orders FOR EACH ROW EXECUTE FUNCTION maintenance_audit_change()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.source_workbank_items

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** MERGED_CANONICAL

**DOMAIN:** B. ORACLE_SYNC / INGESTION

**USED BY:** web/lib/source-data.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** PRESENT - validate/replace against this contract

**DECISION:** Rows are equivalent; DEV adds E6 resolution indexes while PROD has current operational indexes. V2 keeps the shared table and the minimal union of query-required indexes.

**DECISION EVIDENCE:** Shared source row contract plus current operational queries and E6 resolution lookups

**SOURCE OF TRUTH:** Current completed Oracle/WMS workbank snapshot

**READ CONTRACT:** Operational pages read by sync_batch, organization, order, zone/location, task and product.

**WRITE CONTRACT:** Only complete snapshot ingestion replaces rows.

**LIFECYCLE:** Replaceable snapshot; historical authority belongs to batches/audit, not stale workbank rows.

**IDEMPOTENCY:** source_row_id within batch and snapshot replacement prevent duplicate current rows.

**BUSINESS INVARIANTS:**
- physical units and prints_per_garment remain separate
- task is source evidence, not an automatic routing override
- only completed batch is exposed as current

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "sync_batch_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "source_row_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "order_no",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "customer_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "customer_name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "source_due_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "from_location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "from_zone",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "to_location",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "from_pack_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "to_pack_id",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "source_priority",
      "data_type": "integer",
      "udt_schema": "pg_catalog",
      "udt_name": "int4",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 15,
      "column_name": "product_code",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 16,
      "column_name": "product_description",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 17,
      "column_name": "product_group",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 18,
      "column_name": "source_qty",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 19,
      "column_name": "source_weight",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 20,
      "column_name": "production_units",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 21,
      "column_name": "queue",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 22,
      "column_name": "task",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 23,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 24,
      "column_name": "prints_per_garment",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "source_workbank_items_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "source_workbank_items_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "source_workbank_items_sync_batch_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (sync_batch_id) REFERENCES sync_batches(id)"
    }
  ],
  "indexes": [
    {
      "index_name": "source_workbank_batch_zone_idx",
      "definition": "CREATE INDEX source_workbank_batch_zone_idx ON public.source_workbank_items USING btree (sync_batch_id, from_zone)"
    },
    {
      "index_name": "source_workbank_items_e61_lookup_idx",
      "definition": "CREATE INDEX source_workbank_items_e61_lookup_idx ON public.source_workbank_items USING btree (organization_id, order_no, upper(TRIM(BOTH FROM product_code)))"
    },
    {
      "index_name": "source_workbank_items_e61_snapshot_lookup",
      "definition": "CREATE INDEX source_workbank_items_e61_snapshot_lookup ON public.source_workbank_items USING btree (sync_batch_id, organization_id, order_no, upper(TRIM(BOTH FROM product_code)))"
    },
    {
      "index_name": "source_workbank_location_idx",
      "definition": "CREATE INDEX source_workbank_location_idx ON public.source_workbank_items USING btree (from_location)"
    },
    {
      "index_name": "source_workbank_order_no_idx",
      "definition": "CREATE INDEX source_workbank_order_no_idx ON public.source_workbank_items USING btree (order_no)"
    },
    {
      "index_name": "source_workbank_zone_idx",
      "definition": "CREATE INDEX source_workbank_zone_idx ON public.source_workbank_items USING btree (from_zone)"
    },
    {
      "index_name": "source_workbank_items_pkey",
      "definition": "CREATE UNIQUE INDEX source_workbank_items_pkey ON public.source_workbank_items USING btree (id)"
    }
  ],
  "triggers": [
    {
      "trigger_name": "source_workbank_batch_organization",
      "definition": "CREATE TRIGGER source_workbank_batch_organization BEFORE INSERT OR UPDATE OF organization_id, sync_batch_id ON source_workbank_items FOR EACH ROW EXECUTE FUNCTION enforce_sync_batch_organization()"
    }
  ],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.shift_templates

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/planning.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "starts_at",
      "data_type": "time without time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "time",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "ends_at",
      "data_type": "time without time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "time",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "day_group",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": "'all_days'::text",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "crosses_midnight",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "false",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "scheduled_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "shift_scheduled_hours_positive",
      "constraint_type": "c",
      "definition": "CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric)"
    },
    {
      "constraint_name": "shift_templates_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "shift_templates_organization_id_name_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, name)"
    },
    {
      "constraint_name": "shift_templates_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    }
  ],
  "indexes": [
    {
      "index_name": "shift_templates_organization_id_name_key",
      "definition": "CREATE UNIQUE INDEX shift_templates_organization_id_name_key ON public.shift_templates USING btree (organization_id, name)"
    },
    {
      "index_name": "shift_templates_pkey",
      "definition": "CREATE UNIQUE INDEX shift_templates_pkey ON public.shift_templates USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.capacity_profiles

**TYPE:** TABLE_OR_VIEW

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/lib/capacity.ts, web/app/production/capacity/actions.ts

**ACCESS:** QUERY

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "BASE TABLE",
  "columns": [
    {
      "ordinal_position": 1,
      "column_name": "id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": "gen_random_uuid()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 2,
      "column_name": "organization_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 3,
      "column_name": "name",
      "data_type": "text",
      "udt_schema": "pg_catalog",
      "udt_name": "text",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 4,
      "column_name": "production_area_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 5,
      "column_name": "shift_template_id",
      "data_type": "uuid",
      "udt_schema": "pg_catalog",
      "udt_name": "uuid",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 6,
      "column_name": "resource_count",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 7,
      "column_name": "machine_count",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "YES",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 8,
      "column_name": "scheduled_hours",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 9,
      "column_name": "hourly_rate",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 10,
      "column_name": "efficiency",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": null,
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 11,
      "column_name": "work_days",
      "data_type": "numeric",
      "udt_schema": "pg_catalog",
      "udt_name": "numeric",
      "is_nullable": "NO",
      "column_default": "5",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 12,
      "column_name": "active",
      "data_type": "boolean",
      "udt_schema": "pg_catalog",
      "udt_name": "bool",
      "is_nullable": "NO",
      "column_default": "true",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 13,
      "column_name": "created_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    },
    {
      "ordinal_position": 14,
      "column_name": "updated_at",
      "data_type": "timestamp with time zone",
      "udt_schema": "pg_catalog",
      "udt_name": "timestamptz",
      "is_nullable": "NO",
      "column_default": "now()",
      "is_identity": "NO",
      "identity_generation": null,
      "is_generated": "NEVER",
      "generation_expression": null
    }
  ],
  "constraints": [
    {
      "constraint_name": "capacity_profiles_efficiency_check",
      "constraint_type": "c",
      "definition": "CHECK (efficiency >= 0::numeric AND efficiency <= 1::numeric)"
    },
    {
      "constraint_name": "capacity_profiles_hourly_rate_check",
      "constraint_type": "c",
      "definition": "CHECK (hourly_rate >= 0::numeric)"
    },
    {
      "constraint_name": "capacity_profiles_machine_count_check",
      "constraint_type": "c",
      "definition": "CHECK (machine_count >= 0::numeric)"
    },
    {
      "constraint_name": "capacity_profiles_organization_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (organization_id) REFERENCES organizations(id)"
    },
    {
      "constraint_name": "capacity_profiles_organization_id_name_key",
      "constraint_type": "u",
      "definition": "UNIQUE (organization_id, name)"
    },
    {
      "constraint_name": "capacity_profiles_pkey",
      "constraint_type": "p",
      "definition": "PRIMARY KEY (id)"
    },
    {
      "constraint_name": "capacity_profiles_production_area_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (production_area_id) REFERENCES production_areas(id)"
    },
    {
      "constraint_name": "capacity_profiles_resource_count_check",
      "constraint_type": "c",
      "definition": "CHECK (resource_count >= 0::numeric)"
    },
    {
      "constraint_name": "capacity_profiles_scheduled_hours_check",
      "constraint_type": "c",
      "definition": "CHECK (scheduled_hours > 0::numeric AND scheduled_hours <= 24::numeric)"
    },
    {
      "constraint_name": "capacity_profiles_shift_template_id_fkey",
      "constraint_type": "f",
      "definition": "FOREIGN KEY (shift_template_id) REFERENCES shift_templates(id)"
    },
    {
      "constraint_name": "capacity_profiles_work_days_check",
      "constraint_type": "c",
      "definition": "CHECK (work_days >= 0::numeric AND work_days <= 7::numeric)"
    }
  ],
  "indexes": [
    {
      "index_name": "capacity_profiles_context_idx",
      "definition": "CREATE INDEX capacity_profiles_context_idx ON public.capacity_profiles USING btree (organization_id, production_area_id, shift_template_id) WHERE active"
    },
    {
      "index_name": "capacity_profiles_organization_id_name_key",
      "definition": "CREATE UNIQUE INDEX capacity_profiles_organization_id_name_key ON public.capacity_profiles USING btree (organization_id, name)"
    },
    {
      "index_name": "capacity_profiles_pkey",
      "definition": "CREATE UNIQUE INDEX capacity_profiles_pkey ON public.capacity_profiles USING btree (id)"
    }
  ],
  "triggers": [],
  "rls": [
    {
      "rls_enabled": true,
      "rls_forced": false
    }
  ],
  "policies": []
}
```

## public.maintenance_operator_pm_action

**TYPE:** FUNCTION_RPC

**CLASSIFICATION:** RUNTIME_REQUIRED

**CANONICAL SOURCE:** DEV_PROD_MATCH

**USED BY:** web/app/maintenance/actions.ts

**ACCESS:** RPC

**V2 ACTION:** CREATE / REPLACE FROM CANONICAL CONTRACT

**BASELINE 001:** MISSING

### Exact canonical V2 contract

```json
{
  "kind": "FUNCTION",
  "overloads": [
    {
      "arguments": "p_organization_id uuid, p_work_order_id uuid, p_action text, p_checklist_id uuid, p_completed boolean, p_no_parts_used boolean, p_resolution text, p_actor_id uuid, p_actor_email text",
      "result": "void",
      "security_definer": true,
      "volatility": "v",
      "definition": "CREATE OR REPLACE FUNCTION public.maintenance_operator_pm_action(p_organization_id uuid, p_work_order_id uuid, p_action text, p_checklist_id uuid, p_completed boolean, p_no_parts_used boolean, p_resolution text, p_actor_id uuid, p_actor_email text)\n RETURNS void\n LANGUAGE plpgsql\n SECURITY DEFINER\n SET search_path TO 'public'\nAS $function$\r\ndeclare w maintenance_work_orders%rowtype;p maintenance_preventive_plans%rowtype;old_status text;missing_tasks integer;has_parts boolean;\r\nbegin\r\n select * into w from maintenance_work_orders where id=p_work_order_id and organization_id=p_organization_id and work_order_type='preventive' for update;\r\n if w.id is null then raise exception'Preventive work order not found';end if;\r\n select * into p from maintenance_preventive_plans where id=w.preventive_plan_id and organization_id=p_organization_id;old_status:=w.status;\r\n if p_action='start' then\r\n  if w.status not in('open','in_progress')then raise exception'Preventive work cannot be started from this status';end if;\r\n  update maintenance_work_orders set status='in_progress',started_at=coalesce(started_at,now()),updated_at=now()where id=w.id;\r\n  if old_status<>'in_progress'then insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,w.id,old_status,'in_progress',p_actor_id,p_actor_email);end if;\r\n  if p.requires_downtime and not exists(select 1 from maintenance_downtime_events where work_order_id=w.id and ended_at is null)then\r\n   insert into maintenance_downtime_events(organization_id,asset_id,host_asset_id,work_order_id,reason,started_by,maintenance_class,counts_as_failure,counts_as_downtime)values(p_organization_id,w.asset_id,w.asset_id,w.id,w.title,p_actor_id,'PLANNED',false,true);\r\n   update maintenance_assets set status='maintenance',updated_at=now()where id=w.asset_id and status<>'down';\r\n  end if;\r\n elsif p_action='check'then\r\n  if w.status<>'in_progress'then raise exception'Start preventive work first';end if;\r\n  update maintenance_work_order_checklist set completed=p_completed,completed_at=case when p_completed then now()else null end,completed_by=case when p_completed then p_actor_id else null end where id=p_checklist_id and work_order_id=w.id and organization_id=p_organization_id;\r\n  if not found then raise exception'Checklist item not found';end if;\r\n elsif p_action='parts_confirm'then\r\n  update maintenance_work_orders set no_parts_used_confirmed=p_no_parts_used,no_parts_used_confirmed_at=case when p_no_parts_used then now()else null end,no_parts_used_confirmed_by=case when p_no_parts_used then p_actor_id else null end,updated_at=now()where id=w.id;\r\n elsif p_action='complete'then\r\n  if w.status<>'in_progress'then raise exception'Preventive work must be in progress';end if;\r\n  select count(*)into missing_tasks from maintenance_work_order_checklist where work_order_id=w.id and required and not completed;\r\n  if missing_tasks>0 then raise exception'Complete all required checklist items';end if;\r\n  select exists(select 1 from maintenance_inventory_transactions where work_order_id=w.id and transaction_type='issue')into has_parts;\r\n  if not(w.no_parts_used_confirmed or has_parts)then raise exception'Record parts used or confirm No Parts Used';end if;\r\n  update maintenance_work_orders set status='completed',resolution=coalesce(nullif(trim(p_resolution),''),'Preventive maintenance completed'),completed_at=now(),updated_at=now()where id=w.id;\r\n  insert into maintenance_work_order_history(organization_id,work_order_id,from_status,to_status,changed_by,changed_by_email)values(p_organization_id,w.id,old_status,'completed',p_actor_id,p_actor_email);\r\n  update maintenance_downtime_events set ended_at=now(),ended_by=p_actor_id where work_order_id=w.id and ended_at is null;\r\n  update maintenance_assets set status='operational',updated_at=now()where id=w.asset_id and not exists(select 1 from maintenance_downtime_events where asset_id=w.asset_id and ended_at is null);\r\n  update maintenance_preventive_plans set next_due_at=case frequency_unit when'day'then greatest(next_due_at,now())+make_interval(days=>frequency_value)when'week'then greatest(next_due_at,now())+make_interval(days=>frequency_value*7)when'month'then greatest(next_due_at,now())+make_interval(months=>frequency_value)when'year'then greatest(next_due_at,now())+make_interval(years=>frequency_value)else next_due_at end,updated_at=now()where id=w.preventive_plan_id;\r\n else raise exception'Unsupported PM action';end if;\r\nend$function$\n"
    }
  ]
}
```


## C2.1A executable closure

- `public.ingest_sync_batch`: executable merged SQL at `canonical-sql/ingest_sync_batch.sql`.
- `public.v_current_orders`: executable merged SQL at `canonical-sql/v_current_orders.sql`.
- E5/E6 transitive support graph: `canonical-v2-support-objects.json` and `CANONICAL_V2_SUPPORT_OBJECTS.md`.
- Canonical support required: 87 objects.
- Platform objects: 5.
- Legacy unused: 29.
- Unresolved SQL references: 0.
- Semantically relevant typmod/collation/grant blockers: 0.

No database operation was performed and `001_canonical_baseline.sql` was not modified.
