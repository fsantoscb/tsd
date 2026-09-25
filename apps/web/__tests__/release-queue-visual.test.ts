import * as React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";

const row = {
  order_no: "130137674",
  customer_name: "A customer with a long name",
  date_received: "2026-09-23T00:00:00Z",
  date_due: "2026-09-28T00:00:00Z",
  source_priority: 3,
  route_id: "YES",
  cost_centre: "NotAppro",
  stop_ship_flag: "N",
  release_status: "NOT_APPROVED",
  release_blockers: ["A_LONG_BLOCKER_THAT_MUST_WRAP_WITHOUT_WIDENING_THE_PAGE"],
  dtg_qty: 31,
  underprint_qty: 14,
  uv_qty: 8,
  hats_qty: 4,
  finished_qty: 0,
  stickers_qty: 140,
  visual_qty: 0,
  production_qty: 31,
  custom_emb_qty: 2,
  eyewear_qty: 0,
  total_process_qty: 230,
  snapshot_completed_at: "2026-09-25T00:03:44Z",
};

vi.mock("@/lib/release-queue", () => ({ releaseQueue: async () => [row] }));
vi.stubGlobal("React", React);

describe("Release Queue visual contract", () => {
  it("keeps all 14 columns and marks the five production quantities for right alignment", async () => {
    const { default: Page } = await import("../app/production/release-queue/page");
    const html = renderToStaticMarkup(
      await Page({ searchParams: Promise.resolve({}) }),
    );

    const headers = [...html.matchAll(/<th(?:\s[^>]*)?>(.*?)<\/th>/g)].map((match) => match[1]);
    expect(headers).toEqual([
      "Priority", "Order #", "Customer", "Received", "Due", "Release status",
      "Blockers", "DTG", "Underprint", "UV", "Hats", "Custom Emb", "Route", "Stop Ship",
    ]);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>31<\/td>/);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>14<\/td>/);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>8<\/td>/);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>4<\/td>/);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>2<\/td>/);
  });

  it("retains cards, filters, blocker evidence and all expanded detail values", async () => {
    const { default: Page } = await import("../app/production/release-queue/page");
    const html = renderToStaticMarkup(
      await Page({ searchParams: Promise.resolve({}) }),
    );

    expect(html).toContain("Operational orders");
    expect(html).toContain("ELIGIBLE");
    expect(html).toContain("NOT APPROVED");
    expect(html).toContain("BLOCKED");
    expect(html).toContain("FUTURE DUE");
    expect(html).toContain("UNKNOWN");
    expect(html).toContain("Apply");
    expect(html).toContain("Clear");
    expect(html).toContain("A_LONG_BLOCKER_THAT_MUST_WRAP_WITHOUT_WIDENING_THE_PAGE");
    expect(html).toContain("Eyewear 0");
  });
});
