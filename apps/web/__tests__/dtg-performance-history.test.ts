import { beforeEach, describe, expect, it, vi } from "vitest";
import { classifyPerformanceDay } from "../lib/performance-rules";

type Request = { table: string; calls: Array<[string, ...unknown[]]> };
const from = vi.fn();
const requests: Request[] = [];
const fixtures: Record<string, Array<Record<string, unknown>>> = {};

vi.mock("server-only", () => ({}));
vi.mock("@/lib/planning", () => ({ baseContext: async () => ({ organizationId: "org-1" }) }));
vi.mock("@/lib/capacity", () => ({ capacityDb: () => ({ from }) }));
vi.mock("@/lib/dtg-daily-actuals", async () => await import("../lib/dtg-daily-actuals"));

function query(table: string) {
  const request: Request = { table, calls: [] };
  requests.push(request);
  const record = (method: string, ...args: unknown[]) => {
    request.calls.push([method, ...args]);
    return builder;
  };
  const result = () => ({ data: table === "production_daily_actuals" ? (fixtures[table] ?? []).slice(0, 1000) : fixtures[table] ?? [], error: null });
  const builder = {
    select: (fields: string) => record("select", fields),
    eq: (column: string, value: unknown) => record("eq", column, value),
    gte: (column: string, value: unknown) => record("gte", column, value),
    lte: (column: string, value: unknown) => record("lte", column, value),
    order: (column: string, options?: unknown) => record("order", column, options),
    range: async (start: number, end: number) => ({ data: (fixtures[table] ?? []).slice(start, end + 1), error: null }),
    maybeSingle: async () => ({ data: (fixtures[table] ?? [])[0] ?? null, error: null }),
    then: (...callbacks: Parameters<Promise<ReturnType<typeof result>>["then"]>) =>
      Promise.resolve(result()).then(...callbacks),
  };
  return builder;
}

const event = (eventId: string, metric: string, quantity: number) => ({
  event_id: eventId,
  event_ts_utc: "2026-09-25T00:00:00Z",
  operational_date: "2026-09-25",
  shift_code: "SHIFT_1",
  metric,
  quantity,
  quality_status: "COMPLETE",
  source: "LEGACY",
  source_mode: "EVENT",
  import_batch_id: "batch-1",
  created_at: "2026-09-25T01:00:00Z",
  calculation_version: "V1",
  is_partial_period: false,
});

const daily = () => ({
  operational_date: "2026-09-25",
  machine_code: "DTG001",
  shift_code: "SHIFT_1",
  garments: 150,
  prints: 2257,
  source_max_event_at: "2026-09-25T10:00:00+10:00",
  refreshed_at: "2026-09-25T10:05:00+10:00",
});

const labour = (area = "DTG_OPERATOR", productiveHours = 71.7) => ({
  person_key: area,
  area_code: area,
  operational_date: "2026-09-25",
  segment_end: "2026-09-25T15:00:00+10:00",
  shift_code: "SHIFT_1",
  hour_bucket: 8,
  paid_hours: productiveHours,
  regular_hours: productiveHours,
  overtime_hours: 0,
  paid_break_hours: 0,
  productive_hours: productiveHours,
  approval_status: "APPROVED",
});

beforeEach(() => {
  from.mockReset();
  from.mockImplementation(query);
  requests.length = 0;
  for (const key of Object.keys(fixtures)) delete fixtures[key];
  fixtures.kpi_rate_rules = [{ process: "DTG", rate_per_hour: 1120, effective_from: "2026-09-01" }];
  fixtures.v_latest_completed_batch = [{ completed_at: "2026-09-25T10:05:00+10:00" }];
});

describe("Performance DTG historical actuals", () => {
  it("exposes every DTG daily row when the source exceeds one PostgREST page", async () => {
    fixtures.production_daily_actuals = Array.from({ length: 1001 }, (_, index) => ({ ...daily(), machine_code: `DTG${index}` }));
    const { erpKpis } = await import("../lib/erp-kpis");
    const result = await erpKpis("DAY", "2026-09-25", "2026-09-25");
    expect(result.dailyFlowInputs.dtg).toHaveLength(1001);
  });
  it("uses daily DTG prints instead of a legacy DTG_PRINT event without changing other metrics", async () => {
    fixtures.production_events = [event("old-dtg", "DTG_PRINT", 999), event("up", "UP_OUT", 300), event("putwall", "DTG_PUTWALL_IN", 50), event("screen", "SCREEN_PRINT", 90)];
    fixtures.production_daily_actuals = [daily()];
    fixtures.v_current_labour_segments = [labour(), labour("SHARED_DISPATCH", 2)];

    const { erpKpis } = await import("../lib/erp-kpis");
    const result = await erpKpis("DAY", "2026-09-25", "2026-09-25");
    const row = result.rows.find((item) => item.key === "2026-09-25");

    expect(row).toMatchObject({ dtgActual: 2257, dtgTarget: 6720, dtgProductiveHours: 71.7, upActual: 300, putwallIn: 50, screenActual: 90, dispatchProductiveHours: 2 });
    expect(row!.dtgActual! / row!.dtgTarget!).toBeCloseTo(0.336, 2);
    expect(row!.dtgActual! / row!.dtgProductiveHours!).toBeCloseTo(31.5, 1);
    expect(result.rows.find((item) => item.key === "2026-09-25")?.dtgGarments).toBe(150);
    expect(requests.find((request) => request.table === "production_daily_actuals")?.calls).toEqual(expect.arrayContaining([
      ["eq", "organization_id", "org-1"],
      ["eq", "process", "DTG"],
      ["gte", "operational_date", "2026-09-25"],
      ["lte", "operational_date", "2026-09-25"],
    ]));
    expect(requests.some((request) => request.table === "production_events")).toBe(true);
  });

  it("keeps missing DTG daily actuals null rather than falling back to legacy events or zero", async () => {
    fixtures.production_events = [event("old-dtg", "DTG_PRINT", 999)];
    fixtures.v_current_labour_segments = [labour()];

    const { erpKpis } = await import("../lib/erp-kpis");
    const result = await erpKpis("DAY", "2026-09-25", "2026-09-25");
    const row = result.rows.find((item) => item.key === "2026-09-25")!;

    expect(row.dtgActual).toBeNull();
    expect(classifyPerformanceDay({ date: row.key, actual: row.dtgActual, capacity: row.dtgTarget, labour: row.dtgProductiveHours }, result.meta.productionLatestDate)).toBe("OUTPUT MISSING");
  });

  it("keeps daily DTG prints visible when Labour is missing", async () => {
    fixtures.production_daily_actuals = [daily()];

    const { erpKpis } = await import("../lib/erp-kpis");
    const result = await erpKpis("DAY", "2026-09-25", "2026-09-25");
    const row = result.rows.find((item) => item.key === "2026-09-25")!;

    expect(row.dtgActual).toBe(2257);
    expect(row.dtgProductiveHours).toBeNull();
    expect(classifyPerformanceDay({ date: row.key, actual: row.dtgActual, capacity: row.dtgTarget, labour: row.dtgProductiveHours }, result.meta.productionLatestDate)).toBe("LABOUR MISSING");
  });
});
