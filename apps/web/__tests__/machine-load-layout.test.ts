import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const page = readFileSync(resolve(__dirname, "../app/production/machine-load/page.tsx"), "utf8");
const cssPath = resolve(__dirname, "../app/production/machine-load/machine-load.css");

describe("Machine Load presentation contract", () => {
  it("keeps the hero actions in Show Not Approved, DTG, UP order", () => {
    const hero = page.slice(page.indexOf('className="machine-hero-actions"'), page.indexOf("</section>", page.indexOf('className="machine-hero-actions"')));
    expect(hero.indexOf("Show Not Approved")).toBeLessThan(hero.indexOf("DTG RELATIVE LEAD TIME"));
    expect(hero.indexOf("DTG RELATIVE LEAD TIME")).toBeLessThan(hero.indexOf("UP RELATIVE LEAD TIME"));
  });

  it("uses local layout rules for the three hero cards and 3/3/2/4 metric grids", () => {
    const css = readFileSync(cssPath, "utf8");
    expect(css).toMatch(/\.machine-hero-actions\s*\{[^}]*grid-template-columns:\s*repeat\(3,\s*minmax\(0,\s*1fr\)\)/s);
    expect(css).toMatch(/\.ongoing\s+\.matrix-cells\s*\{[^}]*grid-template-columns:\s*repeat\(2,\s*minmax\(0,\s*1fr\)\)/s);
    expect(css).toMatch(/\.dispatch\s+\.matrix-cells\s*\{[^}]*grid-template-columns:\s*repeat\(4,\s*minmax\(0,\s*1fr\)\)/s);
    expect(css).not.toMatch(/overflow:\s*visible/);
  });
});
