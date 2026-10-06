import * as React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import { buildLabourMatrix, type LabourSegment } from "../lib/labour-matrix";

const segments: LabourSegment[] = [{ operational_date: "2026-09-24", area_code: "UP_OPERATOR", shift_code: "SHIFT_1", person_key: "one", paid_hours: 8, productive_hours: 7.5, regular_hours: 8, overtime_hours: 0, paid_break_hours: 0.5, approval_status: "PROVISIONAL" }];
vi.mock("@/lib/labour-dashboard", () => ({ labourDailyMatrix: async () => buildLabourMatrix(segments), labourOperationalData: async () => ({ segments, snapshots: [], metadataComplete: false }) }));
vi.mock("@/components/app-shell", () => ({ AppShell: ({ children }: { children: React.ReactNode }) => children }));
vi.mock("@/lib/labour-matrix", async () => await import("../lib/labour-matrix"));
vi.mock("@/lib/labour-operational-summary", async () => await import("../lib/labour-operational-summary"));
vi.mock("@/lib/labour-coverage", async () => await import("../lib/labour-coverage"));
vi.stubGlobal("React", React);
async function html(view?: string) {
  const { default: Page } = await import("../app/production/labour/page");
  return renderToStaticMarkup(await Page({ searchParams: Promise.resolve({ from: "2026-09-24", to: "2026-09-24", shift: "SHIFT_1", view }) }));
}
describe("Labour operational server page", () => {
  it("reports reversed date filters without an application error", async () => {
    const { default: Page } = await import("../app/production/labour/page");
    const markup = renderToStaticMarkup(await Page({ searchParams: Promise.resolve({ from: "2026-10-06", to: "2026-09-23" }) }));
    expect(markup).toContain("From must be on or before To");
    expect(markup).toContain("NO DATA");
  });
  it("defaults to the nine-column summary and distinguishes arithmetic from certification", async () => {
    const markup = await html();
    const headers = [...markup.matchAll(/<th(?:\s[^>]*)?>([^<]*)<\/th>/g)].map(match => match[1]);
    expect(headers.slice(0, 9)).toEqual(["Date", "Area", "People", "Paid H", "Productive H", "OT H", "OT %", "OUT OF SHIFT", "Quality"]);
    expect(markup).toContain("Arithmetic reconciliation only");
    expect(markup).toContain("Labour coverage unavailable");
    expect(markup).toMatch(/href="\/production\/labour"[^>]*>Clear/);
    expect(markup).toContain("Has Overtime");
    expect(markup).toContain("shift=SHIFT_1");
  });
  it("keeps the complete 21-column audit available behind the local view control", async () => {
    const markup = await html("audit");
    expect(markup).toContain("labour-audit-table");
    expect(markup).toContain("OUT_OF_SHIFT");
    expect(markup).toContain("Paid Breaks");
    expect(markup).toContain("Regular");
    expect(markup).toContain("Productive");
    expect(markup).toMatch(/colspan="6"/i);
  });
  it("renders only contributing shifts in the eight-column breakdown", async () => {
    const markup = await html("shift");
    expect(markup).toContain("labour-breakdown-table");
    expect(markup).toMatch(/<td>A<\/td>/);
    expect(markup).not.toMatch(/<td>B<\/td>/);
    expect(markup).not.toMatch(/<td>C<\/td>/);
  });
});
