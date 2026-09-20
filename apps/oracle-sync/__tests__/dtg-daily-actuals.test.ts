import { describe, expect, it, vi } from "vitest";
import { assignDtgOperationalShift, dtgRefreshWindow, isAuthoritativeDtgCompletion, mapOracleDtgDailyActual, oracleShiftRuleCte, refreshDtgDailyActuals, type DtgShiftRule } from "../src/dtg-daily-actuals";

const row = (overrides: Record<string, unknown> = {}) => ({ OPERATIONAL_DATE: "2026-09-17", SHIFT_CODE: "SHIFT_1", MACHINE_CODE: "DTG001", GARMENTS: 1, PRINTS: 1, SOURCE_EVENT_COUNT: 1, SOURCE_MIN_AUDIT_ID: "12780698", SOURCE_MAX_AUDIT_ID: "12780698", SOURCE_MAX_EVENT_AT: "2026-09-17T08:32:55", INVALID_MULTIPLIER_COUNT: 0, ...overrides });
const env = { INGEST_API_URL: "https://app.test/api/ingest", INGEST_SECRET: "s".repeat(32), ORGANIZATION_ID: "00000000-0000-4000-8000-000000000001" } as any;
const rule = (weekday: number, shiftCode: DtgShiftRule["shiftCode"], startTime: string, endTime: string, crossMidnight = false): DtgShiftRule => ({ weekday, shiftCode, displayName: shiftCode, startTime, endTime, crossMidnight, effectiveFrom: "2026-01-01", effectiveTo: null });
const rules: DtgShiftRule[] = [
  ...[1, 2, 3, 4].flatMap(day => [rule(day, "SHIFT_1", "06:00:00", "14:30:00"), rule(day, "SHIFT_2", "14:30:00", "23:00:00"), rule(day, "SHIFT_3", "23:00:00", "06:00:00", true)]),
  rule(5, "SHIFT_1", "06:00:00", "12:00:00"), rule(5, "SHIFT_2", "12:00:00", "18:00:00"), rule(5, "SHIFT_3", "18:00:00", "23:00:00"),
];

describe("DTG PCOR shift aggregate contract", () => {
  it("preserves source local wall-clock time without UTC conversion", () => expect(mapOracleDtgDailyActual(row()).sourceMaxEventAt).toBe("2026-09-17T08:32:55+10:00"));
  it("maps garments, prints, shift and historical machine identity", () => expect(mapOracleDtgDailyActual(row({ MACHINE_CODE: "DTG004", PRINTS: 2 }))).toMatchObject({ garments: 1, prints: 2, shiftCode: "SHIFT_1", machineCode: "DTG004" }));
  it("uses UNATTRIBUTED rather than inventing a machine", () => expect(mapOracleDtgDailyActual(row({ MACHINE_CODE: "" })).machineCode).toBe("UNATTRIBUTED"));
  it("rejects unsupported print multiplicity", () => expect(() => mapOracleDtgDailyActual(row({ INVALID_MULTIPLIER_COUNT: 1 }))).toThrow("UNSUPPORTED_DTG_PRINT_MULTIPLIER"));
  it("accepts an explicit overtime aggregate", () => expect(mapOracleDtgDailyActual(row({ SHIFT_CODE: "OVERTIME" }))).toMatchObject({ shiftCode: "OVERTIME" }));
  it("classifies Friday overtime and its Saturday continuation on the Friday operational date", () => {
    const overtime = [rule(5, "OVERTIME" as DtgShiftRule["shiftCode"], "23:00:00", "06:00:00", true)];
    expect(assignDtgOperationalShift("2026-09-18T23:30:00", overtime)).toEqual({ shiftCode: "OVERTIME", operationalDate: "2026-09-18" });
    expect(assignDtgOperationalShift("2026-09-19T05:30:00", overtime)).toEqual({ shiftCode: "OVERTIME", operationalDate: "2026-09-18" });
  });
  it("classifies legitimate Saturday production from an explicit Saturday rule", () => {
    const saturday = [rule(6, "SHIFT_1", "06:00:00", "14:30:00")];
    expect(assignDtgOperationalShift("2026-09-19T09:15:00", saturday)).toEqual({ shiftCode: "SHIFT_1", operationalDate: "2026-09-19" });
  });
  it("does not fabricate a shift before any rule is effective", () => expect(assignDtgOperationalShift("2025-02-19T11:41:07", rules)).toEqual({ shiftCode: "OUT_OF_SHIFT", operationalDate: "2025-02-19" }));
  it.each([
    { AUDIT_ID: 8218837, FROM_ZONE: "DTGS", TO_ZONE: "PWL1", TO_LOCATION: "PWL1FULL", ISIS_TASK: "SA", QUEUE: null },
    { AUDIT_ID: 8218838, FROM_ZONE: "DTGS", TO_ZONE: "PWL1", TO_LOCATION: "PWL1FULL", ISIS_TASK: "SA", QUEUE: null },
  ])("keeps excluded stock-assignment event $AUDIT_ID outside authoritative DTG output", event => expect(isAuthoritativeDtgCompletion(event)).toBe(false));
  it("accepts only the canonical PCOR DTGS to PWL1 completion evidence", () => expect(isAuthoritativeDtgCompletion({ FROM_ZONE: "DTGS", TO_ZONE: "PWL1", ISIS_TASK: "PCOR", QUEUE: "PCOR" })).toBe(true));
  it.each([
    ["2026-09-16T08:00:00", "SHIFT_1", "2026-09-16"], ["2026-09-16T16:00:00", "SHIFT_2", "2026-09-16"], ["2026-09-16T23:30:00", "SHIFT_3", "2026-09-16"], ["2026-09-17T02:30:00", "SHIFT_3", "2026-09-16"], ["2026-09-17T07:00:00", "SHIFT_1", "2026-09-17"], ["2026-09-18T11:00:00", "SHIFT_1", "2026-09-18"], ["2026-09-18T13:00:00", "SHIFT_2", "2026-09-18"], ["2026-09-18T19:00:00", "SHIFT_3", "2026-09-18"],
  ])("assigns %s to %s on operational date %s", (timestamp, shiftCode, operationalDate) => expect(assignDtgOperationalShift(timestamp, rules)).toEqual({ shiftCode, operationalDate }));
  it("keeps unmatched events visible", () => expect(assignDtgOperationalShift("2026-09-18T23:30:00", rules)).toEqual({ shiftCode: "OUT_OF_SHIFT", operationalDate: "2026-09-18" }));
  it("builds Oracle rules from canonical configuration", () => expect(oracleShiftRuleCte(rules)).toMatchObject({ binds: expect.objectContaining({ shift_0: "SHIFT_1", start_0: 21600 }) }));
  it("uses a seven-day Brisbane refresh window", () => expect(dtgRefreshWindow(new Date("2026-09-20T02:00:00Z"))).toEqual({ from: "2026-09-14", to: "2026-09-20" }));
  it("loads shift rules then sends grouped facts through the factory bridge", async () => {
    const actual = mapOracleDtgDailyActual(row()), source = { readDtgDailyActuals: vi.fn().mockResolvedValue([actual]) };
    const fetcher = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ rules }), { status: 200 })).mockResolvedValueOnce(new Response(JSON.stringify({ accepted: 1 }), { status: 200 }));
    await expect(refreshDtgDailyActuals(env, source, { from: "2026-09-17", to: "2026-09-17" }, fetcher as any)).resolves.toEqual({ accepted: 1 });
    expect(source.readDtgDailyActuals).toHaveBeenCalledWith("2026-09-17", "2026-09-17", rules);
    expect(String(fetcher.mock.calls[0][0])).toContain("/dtg-daily-actuals?organizationId=");
    expect(JSON.parse(String(fetcher.mock.calls[1][1]?.body)).rows).toEqual([actual]);
  });
});
