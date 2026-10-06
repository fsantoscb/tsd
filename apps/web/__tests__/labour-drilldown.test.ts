import { expect, it, vi } from "vitest";
const state = vi.hoisted(() => ({ calls: [] as unknown[][] }));
vi.mock("server-only", () => ({}));
vi.mock("@/lib/planning", () => ({ baseContext: async () => ({ organizationId: "org" }) }));
vi.mock("@/lib/labour-matrix", async () => await import("../lib/labour-matrix"));
vi.mock("@/lib/labour-operational-reader", async () => await import("../lib/labour-operational-reader"));
vi.mock("@/lib/capacity", () => ({ capacityDb: () => ({ from(table: string) {
  const rows = [
    { source_timesheet_row_id: "one", person_key: "p1", operational_date: "2026-09-24", shift_code: "SHIFT_1", paid_hours: 8, productive_hours: 7.5, regular_hours: 7, overtime_hours: 1, paid_break_hours: 0.5, approval_status: "PROVISIONAL" },
    { source_timesheet_row_id: "two", person_key: "p2", operational_date: "2026-09-24", shift_code: "SHIFT_2", paid_hours: 9, productive_hours: 8.5, regular_hours: 8, overtime_hours: 1, paid_break_hours: 0.5, approval_status: "PROVISIONAL" },
  ];
  const query = Object.fromEntries(["select", "eq", "gte", "lte", "order"].map(method => [method, (...args: unknown[]) => { state.calls.push([table, method, ...args]); return query; }])) as Record<string, any>;
  query.range = async () => ({ data: rows, error: null });
  query.in = async () => ({ data: [{ id: "one", display_name: "Person one" }, { id: "two", display_name: "Person two" }], error: null });
  return query;
} }) }));
it("drill-down excludes other shifts, preserves full contribution hours and exposes persisted paid breaks", async () => {
  const { labourDrilldown } = await import("../lib/labour-dashboard");
  const rows = await labourDrilldown("2026-09-24", "2026-09-24", "UP_OPERATOR", "SHIFT_1", true);
  expect(rows).toHaveLength(1);
  expect(rows[0]).toMatchObject({ shift: "SHIFT_1", paid: 8, productive: 7.5, regular: 7, overtime: 1, breaks: 0.5 });
  expect(state.calls).toContainEqual(["v_current_labour_segments", "order", "id"]);
});
