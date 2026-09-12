import { describe, expect, it } from "vitest";
import { DEFAULT_SHIFT_RULES, resolveProductionShift } from "../src/shift-resolver";

const utc = (value: string) => new Date(`${value}+10:00`);
describe("operational ShiftResolver", () => {
  it("S1 resolves a normal Shift 1", () => expect(resolveProductionShift(utc("2026-09-09T08:00:00"), DEFAULT_SHIFT_RULES).shift).toBe("SHIFT_1"));
  it("S2 resolves a normal Shift 2", () => expect(resolveProductionShift(utc("2026-09-09T16:00:00"), DEFAULT_SHIFT_RULES).shift).toBe("SHIFT_2"));
  it("S3 owns cross-midnight production by the start date", () => expect(resolveProductionShift(utc("2026-09-10T02:00:00"), DEFAULT_SHIFT_RULES)).toMatchObject({ shift: "SHIFT_3", calendarDate: "2026-09-10", operationalDate: "2026-09-09" }));
  it("S4 applies Friday's shorter boundaries", () => {
    expect(resolveProductionShift(utc("2026-09-11T11:59:00"), DEFAULT_SHIFT_RULES).shift).toBe("SHIFT_1");
    expect(resolveProductionShift(utc("2026-09-11T12:00:00"), DEFAULT_SHIFT_RULES).shift).toBe("SHIFT_2");
    expect(resolveProductionShift(utc("2026-09-11T18:00:00"), DEFAULT_SHIFT_RULES).shift).toBe("SHIFT_3");
    expect(resolveProductionShift(utc("2026-09-11T23:00:00"), DEFAULT_SHIFT_RULES).shift).toBe("OUT_OF_SHIFT");
  });
  it("S5 assigns an early event only when that area confirms the shift active", () => expect(resolveProductionShift(utc("2026-09-09T14:20:00"), DEFAULT_SHIFT_RULES, { applyEarlyTolerance: true, activeShiftCodes: new Set(["SHIFT_2"]) })).toMatchObject({ shift: "SHIFT_2", usedEarlyTolerance: true }));
  it("S6 keeps unconfirmed Shift 3 activity as Shift 2 operational overtime", () => expect(resolveProductionShift(utc("2026-09-09T23:10:00"), DEFAULT_SHIFT_RULES, { shift3Compatibility: true, confirmedShiftCodes: new Set() })).toMatchObject({ shift: "SHIFT_2", isOperationalOvertime: true }));
  it("S7 assigns the official boundary after Shift 3 is confirmed", () => expect(resolveProductionShift(utc("2026-09-09T23:10:00"), DEFAULT_SHIFT_RULES, { shift3Compatibility: true, confirmedShiftCodes: new Set(["SHIFT_3"]) })).toMatchObject({ shift: "SHIFT_3", operationalDate: "2026-09-09" }));
});
