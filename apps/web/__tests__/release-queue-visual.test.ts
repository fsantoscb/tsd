import * as React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import ClearFiltersLink from "../app/production/release-queue/clear-filters-link";

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
  finished_qty: 17,
  stickers_qty: 140,
  visual_qty: 5,
  production_qty: 39,
  custom_emb_qty: 2,
  eyewear_qty: 11,
  total_process_qty: 230,
  snapshot_completed_at: "2026-09-25T00:03:44Z",
};

vi.mock("@/lib/release-queue", () => ({ releaseQueue: async () => [row] }));
vi.stubGlobal("React", React);

describe("Release Queue visual contract", () => {
  it("keeps the original 14 columns and adds every unique quantity and cost centre", async () => {
    const { default: Page } = await import("../app/production/release-queue/page");
    const html = renderToStaticMarkup(
      await Page({ searchParams: Promise.resolve({}) }),
    );

    const headers = [...html.matchAll(/<th(?:\s[^>]*)?>(.*?)<\/th>/g)].map((match) => match[1]);
    expect(headers).toEqual([
      "Priority", "Order #", "Customer", "Received", "Due", "Release status",
      "Blockers", "DTG", "Underprint", "UV", "Hats", "Custom Emb", "Route", "Stop Ship",
      "Cost centre", "Finished", "Stickers", "Visual", "Production", "Eyewear",
    ]);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>31<\/td>/);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>14<\/td>/);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>8<\/td>/);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>4<\/td>/);
    expect(html).toMatch(/<td[^>]*class="[^"]+"[^>]*>2<\/td>/);
    expect(html).toContain(">NotAppro</td>");
    for (const quantity of [17, 140, 5, 39, 11]) {
      expect(html).toMatch(new RegExp(`<td[^>]*class="[^"]+"[^>]*>${quantity}<\\/td>`));
    }
  });

  it("renders Order # as plain text without expansion or duplicate evidence", async () => {
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
    expect(html).toMatch(/<td>130137674<\/td>/);
    expect(html).not.toContain("<details");
    expect(html).not.toContain("<summary");
    expect(html).not.toContain("release-detail");
    expect(html).not.toContain("Classification evidence");
    expect((html.match(/>NotAppro<\/td>/g) ?? []).length).toBe(1);
    expect((html.match(/>YES<\/td>/g) ?? []).length).toBe(1);
    expect((html.match(/>N<\/td>/g) ?? []).length).toBe(1);
    expect((html.match(/A_LONG_BLOCKER_THAT_MUST_WRAP_WITHOUT_WIDENING_THE_PAGE/g) ?? []).length).toBe(1);
  });

  it("links back to the existing Control Tower without rendering a sidebar", async () => {
    const { default: Page } = await import("../app/production/release-queue/page");
    const html = renderToStaticMarkup(await Page({ searchParams: Promise.resolve({}) }));
    expect(html).toMatch(/<a[^>]*href="\/"[^>]*>← Production Control<\/a>/);
    expect(html).not.toContain("<aside");
  });

  it("remounts filters only when effective search parameters change", async () => {
    const { default: Page } = await import("../app/production/release-queue/page");
    async function formKey(params: Record<string, string | undefined>) {
      const section = await Page({ searchParams: Promise.resolve(params) });
      const children = React.Children.toArray(section.props.children);
      const form = children.find((child) => React.isValidElement(child) && child.type === "form");
      if (!React.isValidElement(form)) throw new Error("Release Queue filter form missing");
      return form.key;
    }
    const filtered = await formKey({ status: "BLOCKED", q: "130137674" });
    const cleared = await formKey({});
    expect(filtered).not.toBe(cleared);
    expect(cleared).toBe(await formKey({ status: "ALL", q: "" }));
  });

  it("Clear empties unapplied edits even when the URL is already unfiltered", async () => {
    const { default: Page } = await import("../app/production/release-queue/page");
    const section = await Page({ searchParams: Promise.resolve({}) });
    const form = React.Children.toArray(section.props.children).find(
      (child) => React.isValidElement(child) && child.type === "form",
    );
    if (!React.isValidElement<{ children: React.ReactNode }>(form)) throw new Error("Filter form missing");
    const clear = React.Children.toArray(form.props.children).find(
      (child) => React.isValidElement(child) && child.type === ClearFiltersLink,
    );
    if (!React.isValidElement(clear)) throw new Error("Clear control missing");

    const rendered = (clear.type as () => React.ReactElement<{ onClick: React.MouseEventHandler<HTMLAnchorElement> }>)();
    const values: Record<string, { value: string }> = Object.fromEntries(
      ["q", "status", "customer", "priority", "due", "process", "blocker"].map(
        (name) => [name, { value: name === "status" ? "BLOCKED" : "edited" }],
      ),
    );
    rendered.props.onClick({
      currentTarget: { closest: () => ({ elements: { namedItem: (name: string) => values[name] } }) },
    } as unknown as React.MouseEvent<HTMLAnchorElement>);
    expect(Object.fromEntries(Object.entries(values).map(([name, control]) => [name, control.value]))).toEqual({
      q: "", status: "ALL", customer: "", priority: "", due: "", process: "", blocker: "",
    });
  });
});
