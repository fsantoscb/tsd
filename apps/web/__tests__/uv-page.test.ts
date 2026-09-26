import * as React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { describe, expect, it, vi } from "vitest";
import type { UvOrder } from "../lib/uv-operational-model";
import ClearFiltersLink from "../app/production/uv/clear-filters-link";

const rows: UvOrder[] = [{
  organization_id: "org", order_no: "130137674", customer_name: "Alpha",
  source_priority: 1, date_received: "2026-09-20T00:00:00Z", date_released: null,
  date_due: "2026-09-28T00:00:00Z", uv_pick_qty: 2, uv_to_print_qty: 3,
  uv_printing_qty: 0, sticker_print_qty: 5, finished_pick_qty: 7, uv_pack_qty: 1111,
}];
vi.mock("@/lib/uv-operational", () => ({ uvOperationalOrders: async () => rows }));
vi.stubGlobal("React", React);

describe("UV V1 page", () => {
  it("shows the six cards and the canonical quantities in one row including zero", async () => {
    const { default: Page } = await import("../app/production/uv/page");
    const html = renderToStaticMarkup(await Page({ searchParams: Promise.resolve({}) }));
    expect([...html.matchAll(/<th(?:\s[^>]*)?>(.*?)<\/th>/g)].map(match => match[1])).toEqual([
      "Priority", "Order #", "Customer", "Received / Released", "Due", "UV PICK", "UV2PRINT", "UVPRNT", "STICKER PRINT", "FINISHED PICK", "UV PACK",
    ]);
    expect(html).toContain("1,111");
    expect(html).toMatch(/<td[^>]*>0<\/td>/);
    expect(html).toMatch(/<td>130137674<\/td>/);
    expect((html.match(/<tbody><tr/g) ?? []).length).toBe(1);
    expect(html).toMatch(/<a[^>]*href="\/"[^>]*>← Production Control<\/a>/);
    expect(html).not.toContain("<details");
    expect(html).not.toContain("Laser</th>");
  });
  it("filters by URL and Clear resets visible controls as well as URL", async () => {
    const { default: Page } = await import("../app/production/uv/page");
    const filtered = await Page({ searchParams: Promise.resolve({ q: "nomatch", stage: "UV PICK" }) });
    expect(renderToStaticMarkup(filtered)).toContain("No UV orders match these filters.");
    const full = await Page({ searchParams: Promise.resolve({}) });
    const filteredForm = React.Children.toArray(filtered.props.children).find(child => React.isValidElement(child) && child.type === "form");
    const fullForm = React.Children.toArray(full.props.children).find(child => React.isValidElement(child) && child.type === "form");
    expect((filteredForm as React.ReactElement).key).not.toBe((fullForm as React.ReactElement).key);
    if (!React.isValidElement<{ children: React.ReactNode }>(fullForm)) throw new Error("Filter form missing");
    const clear = React.Children.toArray(fullForm.props.children).find(child => React.isValidElement(child) && child.type === ClearFiltersLink);
    if (!React.isValidElement(clear)) throw new Error("Clear control missing");
    const rendered = (clear.type as () => React.ReactElement<{ onClick: React.MouseEventHandler<HTMLAnchorElement> }> )();
    const values = { q: { value: "edited" }, stage: { value: "UV PACK" } };
    rendered.props.onClick({ currentTarget: { closest: () => ({ elements: { namedItem: (name: "q" | "stage") => values[name] } }) } } as unknown as React.MouseEvent<HTMLAnchorElement>);
    expect(values).toEqual({ q: { value: "" }, stage: { value: "ALL" } });
    expect(rendered.props).toHaveProperty("href", "/production/uv");
  });
  it("uses one value when URL parameters are repeated", async () => {
    const { default: Page } = await import("../app/production/uv/page");
    const html = renderToStaticMarkup(await Page({ searchParams: Promise.resolve({ q: ["130137674", "ignored"], stage: ["UV PACK", "ALL"] }) }));
    expect(html).toContain("130137674");
  });
});
