import type { SupabaseClient } from "@supabase/supabase-js";
import type { UpShiftPerformanceSource } from "./up-performance-rows";

export async function readUpPerformanceShifts(db: Pick<SupabaseClient, "from">, organizationId: string, from: string, to: string): Promise<UpShiftPerformanceSource[]> {
  const validDate = (date: string) => /^\d{4}-\d{2}-\d{2}$/.test(date) && Number.isFinite(Date.parse(`${date}T00:00:00Z`)) && new Date(`${date}T00:00:00Z`).toISOString().slice(0, 10) === date;
  if (!validDate(from) || !validDate(to) || from > to) throw new Error("INVALID_UP_PERFORMANCE_RANGE");
  const rows: UpShiftPerformanceSource[] = [];
  for (let start = 0; start < 10000; start += 1000) {
    const result = await db.from("up_shift_daily_actuals")
      .select("operational_date,shift_code,garments,status,source_snapshot_id")
      .eq("organization_id", organizationId).eq("status", "CURRENT")
      .gte("operational_date", from).lte("operational_date", to)
      .order("operational_date").order("shift_code").range(start, start + 999);
    if (result.error) throw result.error;
    const page = (result.data ?? []) as UpShiftPerformanceSource[];
    rows.push(...page);
    if (page.length < 1000) return rows;
  }
  throw new Error("UP_PERFORMANCE_ROW_LIMIT_REACHED");
}
