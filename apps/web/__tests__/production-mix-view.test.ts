import * as React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it, vi } from "vitest";

const fixture = vi.hoisted(() => ({
  orders: [], dailyCapacity: 1, weeklyCapacity: 5, upDailyCapacity: 1,
  productionMix: {
    total: 300,
    model: {
      total: 300, reconciled: true,
      audiences: [
        { label: "ADULT", total: 180, toPick: 80, picked: 100, share: 60, orders: 2, types: [] },
        { label: "KIDS", total: 120, toPick: 40, picked: 80, share: 40, orders: 1, types: [] },
      ],
      garmentTypes: [
        { label: "A", total: 120, toPick: 20, picked: 100, share: 40, orders: 1 },
        { label: "B", total: 90, toPick: 30, picked: 60, share: 30, orders: 1 },
        { label: "C", total: 60, toPick: 20, picked: 40, share: 20, orders: 1 },
        { label: "D", total: 30, toPick: 10, picked: 20, share: 10, orders: 1 },
      ],
    },
    groups: [
      { group: "A", total: 200, awaiting: 50, ready: 150, percent: 66.67, orders: 2, skus: 1 },
      { group: "B", total: 100, awaiting: 25, ready: 75, percent: 33.33, orders: 1, skus: 1 },
    ],
    cards: { adult: 0, kids: 0, hoodies: 0, other: 0 },
    quality: { emptyDescription: 0, invalidQuantity: 0, unknownTypes: [] },
    options: { priorities: [], sites: [], groups: [], productTypes: [] },
  },
  reconciliation: {
    dtg: { notStarted: 0, ongoing: 0, ready: 0, outside: 0 },
    screen: { notStarted: 0, ongoing: 0, ready: 0, outside: 0 },
    outsideReasons: { dtg: "", screen: "" },
  },
  potentialNotApprovedLoad: { summary: { orders: 0, lines: 0, dtgProcessQuantity: 0, underprintProcessQuantity: 0, unresolvedProcessQuantity: 0, routingResolved: 0, routingAmbiguous: 0, routingUnresolved: 0 }, items: [] },
  informationalProductMix: { families: [], summary: { activeCoveragePercent: 100, unclassifiedActiveQuantity: 0, notApprovedProcessQuantity: 0 }, reconciled: true },
}));

vi.mock("@/lib/machine-load", () => ({ machineLoad: async () => fixture }));
vi.mock("@/components/app-shell", () => ({ AppShell: ({ children }: { children: React.ReactNode }) => React.createElement(React.Fragment, null, children) }));
vi.stubGlobal("React", React);

const render = async (mixView?: string) => {
  const { default: Page } = await import("../app/production/machine-load/page");
  return renderToStaticMarkup(await Page({ searchParams: Promise.resolve(mixView === undefined ? {} : { mixView }) }));
};
const barHeights = (html: string) => [...html.matchAll(/class="mix-bar" style="height:([\d.]+)%"/g)].map(match => Number(match[1]));

describe("Production Mix view", () => {
  it("defaults missing or invalid views to Garment Type, while honoring explicit views", async () => {
    for (const value of [undefined, "unknown"]) {
      const html = await render(value);
      expect(html).toContain('class="mix-chart mix-garment"');
      expect(html).toMatch(/class="active" href="\?mixView=garment"[^>]*>Garment type<\/a>/);
    }
    expect(await render("audience")).toContain('class="mix-chart mix-audience"');
    expect(await render("pick")).toContain('class="mix-chart mix-pick"');
  });

  it("uses one displayed-category maximum separately in each view", async () => {
    expect(barHeights(await render("garment"))).toEqual([100, 50]);
    expect(barHeights(await render("audience"))).toEqual([100, 120 / 180 * 100]);
    expect(barHeights(await render("pick"))).toEqual([100, 75, 50, 25]);
  });

  it("keeps quantities, segments and percentages while scoping layout rules to this chart", async () => {
    const html = await render("garment");
    expect(html).toContain("Awaiting Picking: 50");
    expect(html).toContain("Ready to Print: 150");
    expect(html).toContain("Production Mix: 66.67%");
    expect(html).toContain('class="ready" style="height:75%"');
    expect(html).toContain('class="awaiting" style="height:25%"');

    const css = readFileSync(resolve(__dirname, "../app/production/machine-load/machine-load.css"), "utf8");
    expect(css).toMatch(/\.machine-load-dashboard \.mix-chart\s*\{[^}]*repeat\(8,\s*minmax\(0,\s*1fr\)\)/s);
    expect(css).toMatch(/\.machine-load-dashboard \.mix-chart\.mix-audience\s*\{[^}]*repeat\(3,\s*minmax\(0,\s*1fr\)\)/s);
    expect(css).toMatch(/\.machine-load-dashboard \.mix-chart \.mix-bar\s*\{[^}]*padding:\s*0;[^}]*gap:\s*0;/s);
  });
});
