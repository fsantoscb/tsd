import { describe, expect, it } from "vitest";
import { buildLabourSelection, formatLabourHours, labourDetailHref } from "../lib/labour-operational-summary";
import type { LabourSegment } from "../lib/labour-matrix";

const segment = (values: Partial<LabourSegment> = {}): LabourSegment => ({
  operational_date: "2026-09-24", area_code: "UP_OPERATOR", shift_code: "SHIFT_1",
  person_key: "person-1", paid_hours: 8, productive_hours: 7.5, regular_hours: 8,
  overtime_hours: 0, paid_break_hours: 0.5, approval_status: "PROVISIONAL", ...values,
});
const filters = { area: "ALL", shift: "ALL", hasOvertime: false };

describe("Labour operational selection from canonical segments", () => {
  it("provides the typed operational selection boundary", () => {
    expect(buildLabourSelection).toBeTypeOf("function");
  });
  it("restricts every metric and person to the selected shift before aggregation", () => {
    const data = [segment(), segment({ shift_code: "SHIFT_2", person_key: "person-2", paid_hours: 16.5, regular_hours: 16, overtime_hours: 0.5, productive_hours: 16 })];
    const selected = buildLabourSelection(data, { ...filters, shift: "SHIFT_1" });
    expect(selected.total.paid).toBe(8);
    expect(selected.total.productive).toBe(7.5);
    expect(selected.total.people.size).toBe(1);
    expect(selected.rows[0].shifts.SHIFT_2.people.size).toBe(0);
    expect(buildLabourSelection(data, filters).total.paid).toBe(24.5);
  });
  it("Has Overtime selects date/area grains but retains all their hours and shifts", () => {
    const data = [segment(), segment({ shift_code: "SHIFT_2", overtime_hours: 1, regular_hours: 7 }), segment({ area_code: "DTG_OPERATOR" })];
    const selected = buildLabourSelection(data, { ...filters, hasOvertime: true });
    expect(selected.rows).toHaveLength(1);
    expect(selected.total).toMatchObject({ paid: 16, regular: 15, overtime: 1, productive: 15, breaks: 1 });
    expect(selected.segments).toHaveLength(2);
  });
  it("counts people distinctly across shifts, areas and the whole selected period", () => {
    const selected = buildLabourSelection([segment(), segment({ shift_code: "SHIFT_2" }), segment({ area_code: "DTG_OPERATOR" })], filters);
    expect(selected.rows.every(row => row.people.size === 1)).toBe(true);
    expect(selected.days[0].total.people.size).toBe(1);
    expect(selected.total.people.size).toBe(1);
  });
  it("retains OUT_OF_SHIFT in ALL and excludes it from named shifts without reclassification", () => {
    const data = [segment(), segment({ shift_code: "OUT_OF_SHIFT", paid_hours: 0.01, productive_hours: 0.01, regular_hours: 0.01, paid_break_hours: 0 })];
    expect(buildLabourSelection(data, filters).outPaid).toBe(0.01);
    expect(buildLabourSelection(data, { ...filters, shift: "SHIFT_1" }).outPaid).toBe(0);
    expect(formatLabourHours(0.01)).toBe("<0.1");
  });
  it("does not report arithmetic PASS for empty data or hide CHECK behind PROVISIONAL", () => {
    expect(buildLabourSelection([], filters).quality).toBe("NO DATA");
    const selected = buildLabourSelection([segment(), segment({ approval_status: "CHECK" })], filters);
    expect(selected.rows[0].quality).toBe("CHECK");
    expect(selected.quality).toBe("CHECK");
    expect(buildLabourSelection([segment()], filters).quality).toBe("PASS");
  });
  it("orders dates descending and areas by business order while excluding incomplete rows", () => {
    const selected = buildLabourSelection([segment(), segment({ area_code: "DTG_OPERATOR" }), segment({ operational_date: "2026-09-25" }), segment({ approval_status: "INCOMPLETE" })], filters);
    expect(selected.rows.map(row => `${row.date}/${row.area}`)).toEqual(["2026-09-25/UP_OPERATOR", "2026-09-24/DTG_OPERATOR", "2026-09-24/UP_OPERATOR"]);
    expect(buildLabourSelection([segment()], { ...filters, area: "DTG_OPERATOR" }).rows).toEqual([]);
  });
  it("preserves effective dates, area, shift, overtime and parent view in drill-down", () => {
    const url = new URL(labourDetailHref({ from: "2026-09-23", to: "2026-10-06", ...filters, shift: "SHIFT_1", hasOvertime: true, view: "audit" }, "UP_OPERATOR"), "https://example.test");
    expect(Object.fromEntries(url.searchParams)).toEqual({ from: "2026-09-23", to: "2026-10-06", area: "UP_OPERATOR", shift: "SHIFT_1", ot: "1", view: "audit" });
  });
});
