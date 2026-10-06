import { describe, expect, it } from "vitest";
import { describeLabourCoverage, type LabourSnapshot } from "../lib/labour-coverage";
const snapshot = (overrides: Partial<LabourSnapshot> = {}): LabourSnapshot => ({
  snapshot_type: "FULL", status: "COMPLETED", report_generated_at: "2026-10-05T12:59:00+10:00",
  coverage_start: "2026-09-18", coverage_end: "2026-10-02", certified_at: "2026-10-05T19:07:07+10:00", certified_by: "server-identity", ...overrides,
});
describe("conservative source-timesheet coverage context", () => {
  it("reports coverage for source dates without certifying operational zero or cross-midnight boundaries", () => {
    const context = describeLabourCoverage([snapshot()], "2026-09-23", "2026-09-30", true);
    expect(context.sourceCovered).toBe(true);
    expect(context.latestGenerated).toBe("2026-10-05T12:59:00+10:00");
    expect(context.operationalZeroCertified).toBe(false);
    expect(context.message).toContain("cross-midnight");
  });
  it("warns for a partially uncovered selected source period", () => {
    const context = describeLabourCoverage([snapshot()], "2026-09-23", "2026-10-06", true);
    expect(context.sourceCovered).toBe(false);
    expect(context.coverageEnd).toBe("2026-10-02");
  });
  it("does not claim coverage from partial, unverified or uncertified imports", () => {
    expect(describeLabourCoverage([snapshot({ snapshot_type: "PARTIAL" }), snapshot({ certified_at: null })], "2026-09-23", "2026-09-24", true).available).toBe(false);
  });
  it("fails closed on tied latest timestamps and bounded metadata truncation", () => {
    expect(describeLabourCoverage([snapshot(), snapshot()], "2026-09-23", "2026-09-24", true).sourceCovered).toBe(false);
    expect(describeLabourCoverage([snapshot()], "2026-09-23", "2026-09-24", false).available).toBe(false);
  });
  it("combines coverage conservatively without claiming one snapshot owns a hybrid period", () => {
    const context = describeLabourCoverage([snapshot({ coverage_start: "2026-09-25" }), snapshot({ coverage_end: "2026-09-24", report_generated_at: "2026-10-01T07:00:00+10:00" })], "2026-09-23", "2026-09-28", true);
    expect(context.sourceCovered).toBe(true);
    expect(context.snapshots).toBe(2);
    expect(context.operationalZeroCertified).toBe(false);
  });
});
