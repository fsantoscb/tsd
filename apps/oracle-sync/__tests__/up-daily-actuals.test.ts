import { describe, expect, it, vi } from "vitest";
import {
  isAuthoritativeUpCompletion,
  mapOracleUpDailyActual,
  refreshUpDailyActuals,
  upJobIdentity,
  upRefreshWindow,
} from "../src/up-daily-actuals";

const env = { INGEST_API_URL: "https://app.test/api/ingest", INGEST_SECRET: "s".repeat(32), ORGANIZATION_ID: "00000000-0000-4000-8000-000000000001" } as any;
const rules = [{ weekday: 3, shiftCode: "SHIFT_3", displayName: "Shift 3", startTime: "23:00:00", endTime: "06:00:00", crossMidnight: true, effectiveFrom: "2026-01-01", effectiveTo: null }] as any;
const row = (overrides: Record<string, unknown> = {}) => ({ OPERATIONAL_DATE: "2026-09-16", GARMENTS: 2321.163, JOBS: 70, SOURCE_EVENT_COUNT: 70, SOURCE_MAX_EVENT_AT: "2026-09-17T05:56:02", INVALID_WEIGHT_COUNT: 0, ...overrides });

describe("UP daily aggregate contract", () => {
  it("includes only UNDERPRINT movements leaving UNDERPRINT", () => {
    expect(isAuthoritativeUpCompletion({ FROM_LOCATION: "UNDERPRINT", TO_LOCATION: "DESP" })).toBe(true);
    expect(isAuthoritativeUpCompletion({ FROM_LOCATION: "UNDERPRINT", TO_LOCATION: "UNDERPRINT HOLD" })).toBe(false);
    expect(isAuthoritativeUpCompletion({ FROM_LOCATION: "OTHER", TO_LOCATION: "DESP" })).toBe(false);
  });
  it("uses WEIGHT and never QTY", () => expect(mapOracleUpDailyActual(row({ GARMENTS: 12.5, QTY: 999 }))).toMatchObject({ garments: 12.5 }));
  it("rejects valid movements whose WEIGHT is missing", () => expect(() => mapOracleUpDailyActual(row({ INVALID_WEIGHT_COUNT: 1 }))).toThrow("MISSING_UP_WEIGHT"));
  it("preserves source precision and historical reconciliation", () => {
    expect(mapOracleUpDailyActual(row())).toMatchObject({ operationalDate: "2026-09-16", garments: 2321.163, jobs: 70 });
    expect(mapOracleUpDailyActual(row({ OPERATIONAL_DATE: "2026-09-09", GARMENTS: 2254.115, JOBS: 60 }))).toMatchObject({ garments: 2254.115, jobs: 60 });
    expect(mapOracleUpDailyActual(row({ OPERATIONAL_DATE: "2026-09-18", GARMENTS: 1523, JOBS: 34 }))).toMatchObject({ garments: 1523, jobs: 34 });
  });
  it("deduplicates jobs using pack, destination pack, order then audit", () => {
    expect(upJobIdentity({ FROM_PACK_ID: "P1", TO_PACK_ID: "P2", ONO: "O1", AUDIT_ID: "A1" })).toBe("P1");
    expect(upJobIdentity({ TO_PACK_ID: "P2", ONO: "O1", AUDIT_ID: "A1" })).toBe("P2");
    expect(upJobIdentity({ ONO: "O1", AUDIT_ID: "A1" })).toBe("O1");
    expect(upJobIdentity({ AUDIT_ID: "A1" })).toBe("A1");
    expect(new Set([upJobIdentity({ FROM_PACK_ID: "P1", AUDIT_ID: "A1" }), upJobIdentity({ FROM_PACK_ID: "P1", AUDIT_ID: "A2" })]).size).toBe(1);
  });
  it("uses a seven-day Brisbane reconciliation window", () => expect(upRefreshWindow(new Date("2026-09-20T02:00:00Z"))).toEqual({ from: "2026-09-14", to: "2026-09-20" }));
  it("loads canonical shifts and replaces the complete window idempotently", async () => {
    const actual = mapOracleUpDailyActual(row()), source = { readUpDailyActuals: vi.fn().mockResolvedValue([actual]) };
    const fetcher = vi.fn().mockResolvedValueOnce(new Response(JSON.stringify({ rules }), { status: 200 })).mockResolvedValueOnce(new Response(JSON.stringify({ accepted: 1 }), { status: 200 }));
    await expect(refreshUpDailyActuals(env, source, { from: "2026-09-16", to: "2026-09-16" }, fetcher as any)).resolves.toEqual({ accepted: 1 });
    expect(source.readUpDailyActuals).toHaveBeenCalledWith("2026-09-16", "2026-09-16", rules);
    expect(String(fetcher.mock.calls[1][0])).toContain("/up-daily-actuals");
    expect(JSON.parse(String(fetcher.mock.calls[1][1]?.body)).rows).toEqual([actual]);
  });
});
