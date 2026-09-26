import { describe, expect, it } from "vitest";
import { filterUvOrders, summarizeUvOrders, type UvOrder } from "../lib/uv-operational-model";

const row = (overrides: Partial<UvOrder> = {}): UvOrder => ({
  organization_id: "org", order_no: "1301", customer_name: "Alpha Garments",
  source_priority: 1, date_received: "2026-09-20", date_released: null,
  date_due: "2026-09-28", uv_pick_qty: 2, uv_to_print_qty: 3,
  uv_printing_qty: 0, sticker_print_qty: 5, finished_pick_qty: 7,
  uv_pack_qty: 11, ...overrides,
});

describe("UV operational presentation from canonical rows", () => {
  it("sums only the six canonical fields, including valid zeroes", () => {
    expect(summarizeUvOrders([row(), row({ order_no: "1302", uv_pack_qty: 4 })])).toEqual({
      uv_pick_qty: 4, uv_to_print_qty: 6, uv_printing_qty: 0,
      sticker_print_qty: 10, finished_pick_qty: 14, uv_pack_qty: 15,
    });
    expect(summarizeUvOrders([]).uv_pack_qty).toBe(0);
  });
  it("searches order and customer without changing the canonical rows", () => {
    const rows = [row(), row({ order_no: "2202", customer_name: "Beta" })];
    expect(filterUvOrders(rows, { q: "1301", stage: "ALL" }).map(r => r.order_no)).toEqual(["1301"]);
    expect(filterUvOrders(rows, { q: "beta", stage: "ALL" }).map(r => r.order_no)).toEqual(["2202"]);
    expect(rows).toHaveLength(2);
  });
  it.each([
    ["UV PICK", "uv_pick_qty"], ["UV2PRINT", "uv_to_print_qty"],
    ["UVPRNT", "uv_printing_qty"], ["STICKER PRINT", "sticker_print_qty"],
    ["FINISHED PICK", "finished_pick_qty"], ["UV PACK", "uv_pack_qty"],
  ] as const)("filters %s using only %s > 0", (stage, field) => {
    const rows = [row({ [field]: 1 }), row({ order_no: "2202", [field]: 0 })];
    expect(filterUvOrders(rows, { q: "", stage }).map(r => r.order_no)).toEqual(["1301"]);
  });
  it("keeps a multi-stage order as one row and sorts by priority, due, order", () => {
    const rows = [row({ order_no: "2", source_priority: 2 }), row({ order_no: "1", source_priority: 1 })];
    expect(filterUvOrders(rows, { q: "", stage: "UV PACK" }).map(r => r.order_no)).toEqual(["1", "2"]);
    expect(filterUvOrders([row()], { q: "", stage: "UV PICK" })[0].uv_pack_qty).toBe(11);
  });
  it("rejects duplicate order numbers rather than silently duplicating orders", () => {
    expect(() => filterUvOrders([row(), row()], { q: "", stage: "ALL" })).toThrow(/duplicate/i);
  });
});
