import { describe, expect, it, vi } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import React from "react";
import { buildDailyProductionFlow, readDailyOutputSources } from "../lib/daily-production-flow";
import { DailyProductionFlowTable } from "../app/production/performance/daily-production-flow-table";

const dtg = [{ operational_date: "2026-09-24", garments: 2573, prints: 3858 }];
const labour = [
  { operational_date: "2026-09-24", area_code: "DTG_OPERATOR", productive_hours: 10, overtime_hours: 1 },
  { operational_date: "2026-09-24", area_code: "UP_OPERATOR", productive_hours: 5, overtime_hours: 0.5 },
  { operational_date: "2026-09-24", area_code: "SHARED_DISPATCH", productive_hours: 3, overtime_hours: 0.25 },
  { operational_date: "2026-09-24", area_code: "SCREEN_PRINT", productive_hours: 99, overtime_hours: 99 },
];

describe("Daily Production Flow & Labour", () => {
  it("joins persisted dates, sums DTG shifts, and scopes labour without adding overtime to productive hours", () => {
    const rows = buildDailyProductionFlow(["2026-09-24"], { dtg, labour,
      output: [{ operational_date: "2026-09-24", quantity: 3600 }, { operational_date: "2026-09-24", quantity: 1008 }],
      up: [{ operational_date: "2026-09-24", garments: 1907 }],
    });
    expect(rows[0]).toEqual({ date: "2026-09-24", printsDtg: 3858, garmentsDtg: 2573, dtgOutput: 4608,
      upOutput: 1907, totalOutput: 6515, dtgLabourH: 10, upLabourH: 5, dispatchLabourH: 3,
      totalLabourH: 18, overtimeH: 1.75 });
  });

  it("distinguishes absent sources from certified zero", () => {
    const missing = buildDailyProductionFlow(["2026-09-25"], { dtg: [], labour: [], output: [], up: [] })[0];
    expect(missing).toMatchObject({ printsDtg: null, dtgOutput: null, upOutput: null, totalOutput: null, totalLabourH: null, overtimeH: null });
    const zero = buildDailyProductionFlow(["2026-09-25"], { dtg: [], labour: [], output: [{ operational_date: "2026-09-25", quantity: 0 }], up: [{ operational_date: "2026-09-25", garments: 0 }] })[0];
    expect(zero).toMatchObject({ dtgOutput: 0, upOutput: 0, totalOutput: 0 });
  });

  it("does not certify total labour or overtime if one required area is absent", () => {
    const row = buildDailyProductionFlow(["2026-09-24"], { dtg, output: [], up: [], labour: labour.filter(x => x.area_code !== "SHARED_DISPATCH") })[0];
    expect(row).toMatchObject({ dtgLabourH: 10, upLabourH: 5, dispatchLabourH: null, totalLabourH: null, overtimeH: null });
  });

  it("renders the eleven columns with a dash for missing sources", () => {
    const html = renderToStaticMarkup(<DailyProductionFlowTable rows={buildDailyProductionFlow(["2026-09-25"], { dtg: [], labour: [], output: [], up: [] })} />);
    expect(html).toContain("DAILY PRODUCTION FLOW &amp; LABOUR");
    expect(html.match(/<th\b/g)).toHaveLength(14);
    expect(html).toContain("DTG OUTPUT");
    expect(html).toContain("OVERTIME H");
    expect(html).toContain("—");
  });

  it("reads only the two compact sources within organization and date bounds", async () => {
    const calls: Array<{ table: string; filters: string[] }> = [];
    const db = { from: vi.fn((table: string) => {
      const filters: string[] = [];
      const query = { select: () => query, eq: (key: string, value: string) => { filters.push(`${key}=${value}`); return query; },
        gte: (key: string, value: string) => { filters.push(`${key}>=${value}`); return query; },
        lte: (key: string, value: string) => { filters.push(`${key}<=${value}`); return query; },
        order: () => query, range: () => { calls.push({ table, filters }); return Promise.resolve({ data: [], error: null }); } };
      return query;
    }) } as any;
    await readDailyOutputSources(db, "org", "2026-09-23", "2026-09-28");
    expect(calls).toEqual([
      { table: "dtg_output_daily", filters: ["organization_id=org", "output_type=DTG", "operational_date>=2026-09-23", "operational_date<=2026-09-28"] },
      { table: "up_daily_actuals", filters: ["organization_id=org", "operational_date>=2026-09-23", "operational_date<=2026-09-28"] },
    ]);
  });

  it("keeps an existing longer Performance date selection usable with bounded source reads", async () => {
    const db = { from: vi.fn(() => {
      const query = { select: () => query, eq: () => query, gte: () => query, lte: () => query,
        order: () => query, range: () => Promise.resolve({ data: [], error: null }) };
      return query;
    }) } as any;
    await expect(readDailyOutputSources(db, "org", "2026-08-01", "2026-09-28")).resolves.toEqual({ output: [], up: [] });
    expect(db.from).toHaveBeenCalledTimes(2);
  });
});
