import { describe, expect, it } from "vitest";
import { dtgDailyReconciles, dtgGarmentsByDate, dtgPrintEvents } from "../lib/dtg-daily-actuals";
const rows = [{ operational_date: "2026-09-17", shift_code: "SHIFT_1", machine_code: "DTG001", garments: 700, prints: 885, source_max_event_at: "2026-09-17T04:00:00+10:00", refreshed_at: "2026-09-20T00:00:00Z" }, { operational_date: "2026-09-17", shift_code: "SHIFT_2", machine_code: "DTG004", garments: 596, prints: 826, source_max_event_at: "2026-09-17T17:00:00+10:00", refreshed_at: "2026-09-20T00:00:00Z" }];
describe("DTG shift aggregate", () => {
  it("preserves shift and machine identities", () => expect(dtgPrintEvents(rows).map(x => x.eventId)).toEqual(["DTG_DAILY:2026-09-17:SHIFT_1:DTG001", "DTG_DAILY:2026-09-17:SHIFT_2:DTG004"]));
  it("reconciles garments across shifts", () => expect(dtgGarmentsByDate(rows).get("2026-09-17")).toBe(1296));
  it("uses aggregate shift in KPI events", () => expect(dtgPrintEvents(rows).map(x => x.shift)).toEqual(["SHIFT_1", "SHIFT_2"]));
  it("validates base measures and shift codes", () => expect(dtgDailyReconciles(rows)).toBe(true));
});
