import type { SupabaseClient } from "@supabase/supabase-js";

type NumberValue = number | string;
type DtgRow = { operational_date: string; garments: NumberValue; prints: NumberValue };
type LabourRow = { operational_date: string; area_code: string; productive_hours: NumberValue; overtime_hours: NumberValue };
type OutputRow = { operational_date: string; quantity: NumberValue };
type UpRow = { operational_date: string; garments: NumberValue };

export type DailyFlowSources = { dtg: DtgRow[]; labour: LabourRow[]; output: OutputRow[]; up: UpRow[] };

const sumPresent = (values: NumberValue[]) => values.length ? values.reduce<number>((sum, value) => sum + Number(value), 0) : null;

export function buildDailyProductionFlow(dates: string[], sources: DailyFlowSources) {
  return dates.map(date => {
    const dtg = sources.dtg.filter(row => row.operational_date === date);
    const output = sources.output.filter(row => row.operational_date === date);
    const up = sources.up.filter(row => row.operational_date === date);
    const labour = sources.labour.filter(row => row.operational_date === date);
    const forArea = (area: string) => labour.filter(row => row.area_code === area);
    const dtgLabourH = sumPresent(forArea("DTG_OPERATOR").map(row => row.productive_hours));
    const upLabourH = sumPresent(forArea("UP_OPERATOR").map(row => row.productive_hours));
    const dispatchLabourH = sumPresent(forArea("SHARED_DISPATCH").map(row => row.productive_hours));
    const dtgOutput = sumPresent(output.map(row => row.quantity));
    const upOutput = sumPresent(up.map(row => row.garments));
    const scopedLabour = labour.filter(row => ["DTG_OPERATOR", "UP_OPERATOR", "SHARED_DISPATCH"].includes(row.area_code));
    return {
      date,
      printsDtg: sumPresent(dtg.map(row => row.prints)),
      garmentsDtg: sumPresent(dtg.map(row => row.garments)),
      dtgOutput,
      upOutput,
      totalOutput: dtgOutput === null || upOutput === null ? null : dtgOutput + upOutput,
      dtgLabourH,
      upLabourH,
      dispatchLabourH,
      totalLabourH: dtgLabourH === null || upLabourH === null || dispatchLabourH === null ? null : dtgLabourH + upLabourH + dispatchLabourH,
      overtimeH: dtgLabourH === null || upLabourH === null || dispatchLabourH === null ? null : sumPresent(scopedLabour.map(row => row.overtime_hours)),
    };
  });
}

export async function readDailyOutputSources(db: Pick<SupabaseClient, "from">, organizationId: string, from: string, to: string): Promise<Pick<DailyFlowSources, "output" | "up">> {
  const days = (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(from) || !/^\d{4}-\d{2}-\d{2}$/.test(to) || from > to || !Number.isFinite(days)) {
    throw new Error("INVALID_DAILY_FLOW_RANGE");
  }
  async function read<T>(table: string, columns: string): Promise<T[]> {
    const rows: T[] = [];
    for (let start = 0; start < 10000; start += 1000) {
      let query = db.from(table).select(columns).eq("organization_id", organizationId);
      if (table === "dtg_output_daily") query = query.eq("output_type", "DTG");
      const result = await query.gte("operational_date", from).lte("operational_date", to).order("operational_date").order("id").range(start, start + 999);
      if (result.error) throw result.error;
      const page = (result.data ?? []) as unknown as T[];
      rows.push(...page);
      if (page.length < 1000) return rows;
    }
    throw new Error("DAILY_FLOW_ROW_LIMIT_REACHED");
  }
  const [output, up] = await Promise.all([
    read<OutputRow>("dtg_output_daily", "operational_date,quantity"),
    read<UpRow>("up_daily_actuals", "operational_date,garments"),
  ]);
  return { output, up };
}
