import type { LabourSegment } from "./labour-matrix";
import type { LabourSnapshot } from "./labour-coverage";
import type { SupabaseClient } from "@supabase/supabase-js";
type ReadDatabase = Pick<SupabaseClient, "from">;
export async function readLabourOperationalData(db: ReadDatabase, organizationId: string, from: string, to: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to) || !Number.isFinite(Date.parse(from)) || !Number.isFinite(Date.parse(to)) || from > to) throw new Error("INVALID_LABOUR_DATE_RANGE");
  const sourceFrom = new Date(Date.parse(`${from}T12:00:00Z`) - 864e5).toISOString().slice(0, 10);
  const sourceTo = new Date(Date.parse(`${to}T12:00:00Z`) + 864e5).toISOString().slice(0, 10);
  async function canonical() {
    const rows: LabourSegment[] = [];
    for (let start = 0; ; start += 1000) {
      const result = await db.from("v_current_labour_segments")
        .select("id,operational_date,area_code,shift_code,person_key,paid_hours,productive_hours,regular_hours,overtime_hours,paid_break_hours,approval_status")
        .eq("organization_id", organizationId).gte("operational_date", from).lte("operational_date", to)
        .order("operational_date", { ascending: false }).order("id", { ascending: true }).range(start, start + 999);
      if (result.error) throw result.error;
      const page: LabourSegment[] = result.data ?? [];
      rows.push(...page);
      if (page.length < 1000) return rows;
    }
  }
  async function metadata() {
    try {
      const result = await db.from("deputy_import_batches")
        .select("snapshot_type,status,report_generated_at,coverage_start,coverage_end,certified_at,certified_by")
        .eq("organization_id", organizationId).eq("status", "COMPLETED").eq("snapshot_type", "FULL")
        .not("certified_at", "is", null).not("certified_by", "is", null).not("report_generated_at", "is", null)
        .lte("coverage_start", sourceTo).gte("coverage_end", sourceFrom)
        .order("report_generated_at", { ascending: false }).order("id", { ascending: true }).limit(100);
      if (result.error) return { snapshots: [] as LabourSnapshot[], metadataComplete: false };
      const snapshots: LabourSnapshot[] = result.data ?? [];
      return { snapshots, metadataComplete: snapshots.length < 100 };
    } catch {
      return { snapshots: [] as LabourSnapshot[], metadataComplete: false };
    }
  }
  const [segments, context] = await Promise.all([canonical(), metadata()]);
  return { segments, ...context };
}
