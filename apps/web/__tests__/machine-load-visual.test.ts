import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const page = readFileSync(resolve(__dirname, "../app/production/machine-load/page.tsx"), "utf8");
const css = readFileSync(resolve(__dirname, "../app/globals.css"), "utf8");

describe("machine load targeted visual contract", () => {
  it("uses garments as the primary DTG values and prints as secondary values", () => {
    expect(page).toContain("<b>{num(total.wg)}</b><small>garments · ≈ {num(forecastDemand)} forecast prints</small>");
    expect(page).toContain("<b>{num(total.pg)}</b><small>garments · {num(confirmedDemand)} confirmed prints</small>");
    expect(page).toContain("<b>{num(total.wg+total.pg)}</b><small>garments · {num(demand)} prints</small>");
  });

  it("keeps the hero cards in a bounded responsive grid", () => {
    expect(css).toContain(".machine-hero-actions{display:grid;grid-template-columns:minmax(150px,180px) minmax(0,1fr)");
    expect(css).toContain(".capacity-lead-pair{display:grid;grid-template-columns:repeat(2,minmax(0,1fr))");
    expect(css).toContain(".capacity-lead-pair .capacity-lead{min-width:0");
  });

  it("preserves Underprint and On Going Orders markup", () => {
    expect(page).toContain("<span>UP to pick</span><b>{num(total.up)}</b><small>garments</small>");
    expect(page).toContain("<span>DTG</span><b>{num(total.odo)}</b><small>{num(total.odg)} garments remaining</small>");
  });
});
