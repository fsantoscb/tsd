import { beforeEach, describe, expect, it, vi } from "vitest";
import * as React from "react";
import { renderToStaticMarkup } from "react-dom/server";

const erpKpis = vi.fn();
vi.mock("@/lib/erp-kpis", () => ({ erpKpis }));
vi.mock("@/lib/dtg-performance-rows", async () => await import("../lib/dtg-performance-rows"));
vi.mock("@/lib/daily-production-flow", async () => {
  const actual = await vi.importActual<typeof import("../lib/daily-production-flow")>("../lib/daily-production-flow");
  return { ...actual, readDailyOutputSources: async () => ({ output: [{ operational_date: "2026-09-24", quantity: 4608 }], up: [{ operational_date: "2026-09-24", garments: 1907 }] }) };
});
vi.mock("@/lib/capacity", () => ({ capacityDb: () => ({}) }));
vi.mock("@/lib/performance-workload", () => ({
  performanceWorkload: async () => ["DTG", "UP", "SCREEN_PRINT"].map((code) => ({
    code,
    label: code,
    unit: code === "DTG" ? "prints" : "garments",
    totalUnits: 0,
    totalOrders: 0,
    backlogUnits: 0,
    buckets: ["0", "1", "2", "3", "4", "5", "unknown"].map((key) => ({ key, label: key, units: 0, orders: 0 })),
    rows: [],
  })),
}));
vi.mock("@/lib/machine-load", () => ({
  machineLoad: async () => ({ productionMix: { model: { garmentTypes: [] } } }),
}));
vi.mock("@/lib/performance-rules", async () => await import("../lib/performance-rules"));
vi.mock("@/components/app-shell", () => ({ AppShell: ({ children }: { children: React.ReactNode }) => children }));

const meta = {
  productionLatestDate: "2026-09-28",
  labourLatestDate: "2026-09-28",
  productionLatestAt: "2026-09-28T18:00:00+10:00",
  labourLatestAt: "2026-09-28T18:00:00+10:00",
  oracleLatestAt: "2026-09-28T18:00:00+10:00",
  isPartialPeriod: false,
};

const day = (key: string, dtgActual: number, dtgGarments: number) => ({
  key,
  dtgActual,
  dtgGarments,
  dtgTarget: 6720,
  dtgProductiveHours: 100,
  dtgOvertimeHours: 0,
  upActual: null,
  screenActual: null,
});

async function dailyTable() {
  const { default: Page } = await import("../app/production/performance/page");
  const html = renderToStaticMarkup(await Page({
    searchParams: Promise.resolve({ from: "2026-09-23", to: "2026-09-28", process: "DTG" }),
  }));
  return html.match(/<section class="performance-daily-table">([\s\S]*?)<\/section>/)?.[1] ?? "";
}

beforeEach(() => {
  vi.stubGlobal("React", React);
  erpKpis.mockReset();
  erpKpis.mockResolvedValue({
    context: { organizationId: "org" },
    dtgShiftRows: [],
    dailyFlowInputs: { dtg: [{ operational_date: "2026-09-24", prints: 3858, garments: 2573 }], labour: [] },
    meta,
    rows: [day("2026-09-23", 4184, 2800), day("2026-09-24", 3858, 2573), day("2026-09-25", 1956, 1300), { ...day("2026-09-27", 0, 0), dtgActual: null, dtgGarments: null, dtgTarget: 980, dtgProductiveHours: 0.5, dtgOvertimeHours: 0.5 }, day("2026-09-28", 3498, 2427)],
  });
});

it("places Daily Production Flow & Labour directly after the unchanged DTG daily table", async () => {
  const { default: Page } = await import("../app/production/performance/page");
  const html = renderToStaticMarkup(await Page({ searchParams: Promise.resolve({ from: "2026-09-23", to: "2026-09-28", process: "DTG" }) }));
  expect(html).toMatch(/DTG — Daily performance[\s\S]*?<\/section><section class="performance-daily-table"><h3>DAILY PRODUCTION FLOW &amp; LABOUR/);
  expect(html).toMatch(/>4,608<\/td><td[^>]*>1,907<\/td><td[^>]*>6,515<\/td>/);
});

describe("Performance DTG daily garments table", () => {
  it("renders one compact DTG table with the approved shift and ratio columns", async () => {
    const table = await dailyTable();
    const head = table.match(/<thead>([\s\S]*?)<\/thead>/)?.[1] ?? "";
    const headers = [...head.matchAll(/<th\b[^>]*>(.*?)<\/th>/g)].map(match => match[1]);
    expect(headers).toEqual(["DATE", "SHIFT", "PRINTS", "GARMENTS", "P/G", "CAPACITY", "UTILISATION", "PRODUCTIVE H", "PRINTS/H", "OVERTIME H", "NOTES"]);
    expect(table).toContain("TOTAL");
  });
  it("renders persisted garments immediately after prints for the same operational date", async () => {
    const table = await dailyTable();
    expect(table).toMatch(/>PRINTS<\/th><th[^>]*>GARMENTS<\/th><th[^>]*>P\/G<\/th><th[^>]*>CAPACITY<\/th>/);
    expect(table).toMatch(/>2026-09-24<\/th><th[^>]*>TOTAL<\/th><td[^>]*>3,858<\/td><td[^>]*>2,573<\/td><td[^>]*>1.50<\/td><td[^>]*>6,720<\/td>/);
    expect(erpKpis).toHaveBeenCalledWith("DAY", "2026-09-23", "2026-09-28", "ALL");
  });

  it("keeps garments and prints missing when no daily actual exists", async () => {
    const table = await dailyTable();
    const row = table.match(/<tr[^>]*><th[^>]*>2026-09-27<\/th><th[^>]*>TOTAL<\/th>([\s\S]*?)<\/tr>/)?.[1] ?? "";
    expect([...row.matchAll(/<td[^>]*>(.*?)<\/td>/g)].map((match) => match[1])).toEqual(["—", "—", "—", "980", "—", "0.5", "—", "0.5", "OUTPUT MISSING"]);
  });
});
