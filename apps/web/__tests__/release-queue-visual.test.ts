import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

describe("release queue visual contract", () => {
  const css = readFileSync(resolve(__dirname, "../app/globals.css"), "utf8");
  const page = readFileSync(resolve(__dirname, "../app/production/release-queue/page.tsx"), "utf8");

  it("renders inside the shared production application shell", () => {
    expect(page).toContain('import{AppShell}from"@/components/app-shell"');
    expect(page).toContain('return <AppShell><section className="release-queue"');
    expect(page).toContain("</section></AppShell>");
  });

  it("uses the established Production control-room presentation", () => {
    expect(css).toContain(".release-queue{display:grid;gap:12px");
    expect(css).toContain(".release-queue .hero.compact{min-height:112px");
    expect(css).toContain(".release-table tbody tr:hover td");
    expect(css).toContain(".release-table td:nth-child(n+8)");
  });

  it("preserves dense responsive controls and horizontal table access", () => {
    expect(css).toContain(".release-filters{display:grid");
    expect(css).toContain(".release-table{max-height:calc(100vh - 350px);overflow:auto");
    expect(css).toContain("@media(max-width:650px){.release-queue{gap:9px}");
    expect(css).toContain(".release-kpis,.release-filters{grid-template-columns:1fr}");
  });
});
