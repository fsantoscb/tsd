export type UvOrder = {
  organization_id: string;
  order_no: string;
  customer_name: string | null;
  source_priority: number | null;
  date_received: string | null;
  date_released: string | null;
  date_due: string | null;
  uv_pick_qty: number;
  uv_to_print_qty: number;
  uv_printing_qty: number;
  sticker_print_qty: number;
  finished_pick_qty: number;
  uv_pack_qty: number;
};

export const uvStages = [
  ["UV PICK", "uv_pick_qty"],
  ["UV2PRINT", "uv_to_print_qty"],
  ["UVPRNT", "uv_printing_qty"],
  ["STICKER PRINT", "sticker_print_qty"],
  ["FINISHED PICK", "finished_pick_qty"],
  ["UV PACK", "uv_pack_qty"],
] as const;
export type UvStage = "ALL" | (typeof uvStages)[number][0];
export type UvQuantity = (typeof uvStages)[number][1];

export function parseUvStage(value: string | undefined): UvStage {
  return uvStages.some(([label]) => label === value) ? value as UvStage : "ALL";
}

export function summarizeUvOrders(rows: UvOrder[]): Record<UvQuantity, number> {
  const totals = Object.fromEntries(uvStages.map(([, field]) => [field, 0])) as Record<UvQuantity, number>;
  for (const row of rows) for (const [, field] of uvStages) totals[field] += Number(row[field]) || 0;
  return totals;
}

export function filterUvOrders(rows: UvOrder[], filters: { q: string; stage: UvStage }): UvOrder[] {
  const seen = new Set<string>();
  for (const row of rows) {
    if (seen.has(row.order_no)) throw new Error(`Duplicate UV order in canonical view: ${row.order_no}`);
    seen.add(row.order_no);
  }
  const q = filters.q.trim().toLocaleLowerCase();
  const field = uvStages.find(([label]) => label === filters.stage)?.[1];
  return rows.filter(row =>
    (!q || row.order_no.toLocaleLowerCase().includes(q) || (row.customer_name ?? "").toLocaleLowerCase().includes(q)) &&
    (!field || Number(row[field]) > 0)
  ).sort((a, b) => (a.source_priority ?? 999) - (b.source_priority ?? 999) ||
    (a.date_due ?? "9999").localeCompare(b.date_due ?? "9999") ||
    a.order_no.localeCompare(b.order_no, "en", { numeric: true }));
}
