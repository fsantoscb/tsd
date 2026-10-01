import { calculateKpis, type KpiEngineConfig, type KpiLabour } from "@tsd/shared";
import { ratio, sumAvailable } from "./performance-rules";

export type UpDailyPerformanceSource = { operational_date: string; garments: number | string };
export type UpShiftPerformanceSource = UpDailyPerformanceSource & { shift_code: string; status: string; source_snapshot_id: string };
export type UpPerformanceRow = {
  operationalDate: string;
  shift: "TOTAL" | "A" | "B" | "C";
  isTotal: boolean;
  garments: number | null;
  capacity: number | null;
  utilisation: number | null;
  productiveHours: number | null;
  garmentsPerHour: number | null;
  overtimeHours: number | null;
  notes: string;
};

export function buildUpPerformanceRows(
  daily: UpDailyPerformanceSource[], shifts: UpShiftPerformanceSource[],
  labour: KpiLabour[], config: KpiEngineConfig, filter = "ALL",
): UpPerformanceRow[] {
  const upLabour = labour.filter(row => row.area === "UP_OPERATOR");
  const selectedLabour = upLabour.filter(row => filter === "ALL" || row.shift === filter);
  const shiftKpis = new Map(calculateKpis([], selectedLabour, "SHIFT", config).map(row => [row.key, row]));
  const dayKpis = new Map(calculateKpis([], selectedLabour, "DAY", config).map(row => [row.key, row]));
  const actuals = new Map(shifts.filter(row => row.status === "CURRENT").map(row => [`${row.operational_date}|${row.shift_code}`, Number(row.garments)]));
  const totals = new Map(daily.map(row => [row.operational_date, Number(row.garments)]));
  // Authority markers alone are deliberately not an input or an inclusion source.
  const dates = [...new Set([...daily.map(row => row.operational_date), ...upLabour.map(row => row.operationalDate)])].sort().reverse();
  const compose = (date: string, shift: UpPerformanceRow["shift"], garments: number | null, capacity: number | null, productiveHours: number | null, overtimeHours: number | null, notes = ""): UpPerformanceRow => ({
    operationalDate: date, shift, isTotal: shift === "TOTAL", garments, capacity, productiveHours, overtimeHours,
    utilisation: ratio(garments, capacity), garmentsPerHour: ratio(garments, productiveHours), notes,
  });
  return dates.flatMap(date => {
    const rows = (["A", "B", "C"] as const).map((label, index) => {
      const code = `SHIFT_${index + 1}`, selected = filter === "ALL" || filter === code;
      const kpi = selected ? shiftKpis.get(`${date} · Shift ${index + 1}`) : undefined;
      return compose(date, label, selected ? actuals.get(`${date}|${code}`) ?? null : null,
        kpi?.upTarget ?? null, kpi?.upProductiveHours ?? null, kpi?.upOvertimeHours ?? null);
    });
    const day = dayKpis.get(date), notes: string[] = [];
    if (filter === "ALL") {
      const outside = shiftKpis.get(`${date} · OUT_OF_SHIFT`), garments = actuals.get(`${date}|OUT_OF_SHIFT`);
      if (garments != null || (outside && [outside.upProductiveHours, outside.upOvertimeHours].some(value => value != null && value !== 0))) {
        const contributions: string[] = [];
        if (garments != null) contributions.push(`${garments} garments`);
        if (outside) contributions.push(`${(outside.upProductiveHours ?? 0).toFixed(4)} productive h / ${(outside.upOvertimeHours ?? 0).toFixed(4)} OT h`);
        notes.push(`Includes OUT_OF_SHIFT: ${contributions.join(" / ")}`);
      }
    }
    const garments = filter === "ALL" ? totals.get(date) ?? null : actuals.get(`${date}|${filter}`) ?? null;
    return [compose(date, "TOTAL", garments, sumAvailable(rows.map(row => row.capacity)), day?.upProductiveHours ?? null, day?.upOvertimeHours ?? null, notes.join(" · ")), ...rows];
  });
}
