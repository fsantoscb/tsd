import { describe, expect, it } from "vitest";
import { calculateKpis, type KpiLabour } from "@tsd/shared";
import { dtgPrintEvents, type DtgDailyActualRow } from "../lib/dtg-daily-actuals";
import { buildDtgPerformanceRows } from "../lib/dtg-performance-rows";

const date = "2026-09-24";
const actual = (shift: string, prints: number, garments: number): DtgDailyActualRow => ({ operational_date: date, shift_code: shift, machine_code: "DTG1", prints, garments, source_max_event_at: `${date}T12:00:00+10:00`, refreshed_at: `${date}T13:00:00+10:00` });
const labour = (shift: string, hours: number, ot = 0): KpiLabour => ({ personKey: shift, area: "DTG_OPERATOR", operationalDate: date, shift, hour: 10, paidHours: hours, regularHours: hours - ot, overtimeHours: ot, paidBreakHours: 0, productiveHours: hours, approval: "PROVISIONAL" });
const production = [actual("SHIFT_1", 100, 200), actual("SHIFT_2", 300, 100)];
const segments = [labour("SHIFT_1", 2), labour("SHIFT_2", 4, 1)];
function compose(filter = "ALL", input = segments, output = production, dates = [date]) {
  const selected = input.filter(row => filter === "ALL" || row.shift === filter);
  const selectedOutput = output.filter(row => filter === "ALL" || row.shift_code === filter);
  const events = dtgPrintEvents(selectedOutput);
  return buildDtgPerformanceRows(dates, calculateKpis(events, selected, "DAY").map(row => ({ ...row, dtgGarments: selectedOutput.length ? selectedOutput.reduce((total, item) => total + Number(item.garments), 0) : null })), calculateKpis(events, selected, "SHIFT"), selectedOutput, date, filter);
}

describe("DTG day and shift composition", () => {
  it("orders dates newest first and always emits TOTAL A B C", () => {
    expect(compose("ALL", segments, production, ["2026-09-23", date]).map(row => [row.operationalDate, row.shift])).toEqual([[date,"TOTAL"],[date,"A"],[date,"B"],[date,"C"],["2026-09-23","TOTAL"],["2026-09-23","A"],["2026-09-23","B"],["2026-09-23","C"]]);
  });
  it("exposes persisted shift prints and garments and engine Labour, overtime and capacity", () => {
    const [total, a, b, c] = compose();
    expect(a).toMatchObject({ prints: 100, garments: 200, productiveHours: 2, overtimeHours: 0, capacity: 1190, printsPerGarment: 0.5, printsPerHour: 50 });
    expect(b).toMatchObject({ prints: 300, garments: 100, productiveHours: 4, overtimeHours: 1, capacity: 1190, printsPerGarment: 3, printsPerHour: 75 });
    expect(a.utilisation).toBeCloseTo(100 / 1190);
    expect(b.utilisation).toBeCloseTo(300 / 1190);
    expect(total).toMatchObject({ prints: 400, garments: 300, productiveHours: 6, overtimeHours: 1, capacity: 2380 });
    expect(c).toMatchObject({ prints: null, garments: null, productiveHours: null, overtimeHours: null, capacity: null, utilisation: null, printsPerHour: null, printsPerGarment: null });
  });
  it("calculates TOTAL ratios from totals rather than averaging shift ratios", () => {
    const [total] = compose();
    expect(total.printsPerGarment).toBeCloseTo(4 / 3);
    expect(total.printsPerHour).toBeCloseTo(400 / 6);
    expect(total.utilisation).toBeCloseTo(400 / 2380);
  });
  it("reconciles additive totals without OUT_OF_SHIFT", () => {
    const [total, ...shifts] = compose();
    for (const metric of ["prints", "garments", "productiveHours", "overtimeHours", "capacity"] as const) expect(total[metric]).toBeCloseTo(shifts.reduce((sum, row) => sum + (row[metric] ?? 0), 0));
  });
  it("preserves OUT_OF_SHIFT in TOTAL only, with precise Notes and no fifth row", () => {
    const [total, ...shifts] = compose("ALL", [...segments, labour("OUT_OF_SHIFT", 0.5, 0.25)]);
    expect(total.productiveHours).toBe(6.5);
    expect(total.overtimeHours).toBe(1.25);
    expect(total.notes).toContain("Includes OUT_OF_SHIFT: 0.5000 productive h / 0.2500 OT h");
    expect(shifts.reduce((sum, row) => sum + (row.productiveHours ?? 0), 0) + 0.5).toBe(total.productiveHours);
    expect(shifts.reduce((sum, row) => sum + (row.overtimeHours ?? 0), 0) + 0.25).toBe(total.overtimeHours);
    expect(shifts.map(row => row.notes)).toEqual(["", "", ""]);
    expect(shifts).toHaveLength(3);
  });
  it.each(["SHIFT_1", "SHIFT_2", "SHIFT_3"])("keeps all rows but excludes other shifts and OUT_OF_SHIFT from %s", filter => {
    const [total, ...shifts] = compose(filter, [...segments, labour("OUT_OF_SHIFT", 0.5, 0.25)]);
    expect(total.notes).not.toContain("OUT_OF_SHIFT");
    for (const [index, row] of shifts.entries()) if (`SHIFT_${index + 1}` !== filter) expect(row).toMatchObject({ prints: null, garments: null, productiveHours: null, overtimeHours: null, capacity: null });
    const selected = shifts[Number(filter.at(-1)) - 1];
    expect(total.prints).toBe(selected.prints);
    expect(total.productiveHours).toBe(selected.productiveHours);
  });
  it("preserves missing metrics, zero garments and zero productive hours without invalid ratios", () => {
    const rows = compose("ALL", [labour("SHIFT_1", 0)], [actual("SHIFT_1", 10, 0)]);
    expect(rows[0].printsPerGarment).toBeNull();
    expect(rows[0].printsPerHour).toBeNull();
    expect(rows[1].printsPerGarment).toBeNull();
    expect(rows[1].printsPerHour).toBeNull();
    expect(compose("ALL", [], [actual("SHIFT_1", 10, 2)])[0].capacity).toBeNull();
  });
  it("keeps existing daily classification on TOTAL only", () => {
    const [total, ...shifts] = compose("ALL", segments, []);
    expect(total.notes).toBe("OUTPUT MISSING");
    expect(shifts.every(row => row.notes === "")).toBe(true);
  });
  it("does not redistribute unknown production shifts into A B C", () => {
    const [total, ...shifts] = compose("ALL", segments, [...production, actual("OUT_OF_SHIFT", 5, 2)]);
    expect(total.prints).toBe(405);
    expect(total.garments).toBe(302);
    expect(shifts.reduce((sum, row) => sum + (row.prints ?? 0), 0)).toBe(400);
    expect(total.notes).toContain("5 prints / 2 garments");
  });
});
