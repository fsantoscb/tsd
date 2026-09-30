import type { KpiRow } from "@tsd/shared";
import type { DtgDailyActualRow } from "./dtg-daily-actuals";
import { classifyPerformanceDay, ratio } from "./performance-rules";

type DailyRow = Partial<KpiRow> & { key: string; dtgGarments?: number | null };
export type DtgPerformanceRow = {
  operationalDate: string;
  shift: "TOTAL" | "A" | "B" | "C";
  isTotal: boolean;
  prints: number | null;
  garments: number | null;
  printsPerGarment: number | null;
  capacity: number | null;
  utilisation: number | null;
  productiveHours: number | null;
  printsPerHour: number | null;
  overtimeHours: number | null;
  notes: string;
};

export function buildDtgPerformanceRows(
  dates: string[], dailyRows: DailyRow[], shiftRows: KpiRow[],
  actuals: DtgDailyActualRow[], productionLatestDate: string | null, filter = "ALL",
): DtgPerformanceRow[] {
  const daily = new Map(dailyRows.map(row => [row.key, row]));
  const shifts = new Map(shiftRows.map(row => [row.key, row]));
  const garments = new Map<string, number>();
  for (const row of actuals) {
    if (filter !== "ALL" && row.shift_code !== filter) continue;
    const key = `${row.operational_date}|${row.shift_code}`;
    garments.set(key, (garments.get(key) ?? 0) + Number(row.garments));
  }
  const compose = (date: string, shift: DtgPerformanceRow["shift"], row: Partial<KpiRow> | undefined, garmentCount: number | null, notes = ""): DtgPerformanceRow => {
    const prints = row?.dtgActual ?? null, capacity = row?.dtgTarget ?? null, productiveHours = row?.dtgProductiveHours ?? null;
    return { operationalDate: date, shift, isTotal: shift === "TOTAL", prints, garments: garmentCount,
      printsPerGarment: ratio(prints, garmentCount), capacity, utilisation: ratio(prints, capacity),
      productiveHours, printsPerHour: ratio(prints, productiveHours), overtimeHours: row?.dtgOvertimeHours ?? null, notes };
  };
  return [...new Set(dates)].sort().reverse().flatMap(date => {
    const total = daily.get(date);
    const classification = classifyPerformanceDay({ date, actual: total?.dtgActual ?? null, capacity: total?.dtgTarget ?? null, labour: total?.dtgProductiveHours ?? null }, productionLatestDate);
    const notes = ["COMPLETE", "ZERO PRODUCTION", "NON-OPERATIONAL"].includes(classification) ? [] : [classification.replaceAll("_", " ")];
    const outside = filter === "ALL" ? shifts.get(`${date} · OUT_OF_SHIFT`) : undefined;
    if (outside && [outside.dtgActual, outside.dtgProductiveHours, outside.dtgOvertimeHours, garments.get(`${date}|OUT_OF_SHIFT`)].some(value => value != null && value !== 0)) {
      let note = `Includes OUT_OF_SHIFT: ${(outside.dtgProductiveHours ?? 0).toFixed(4)} productive h / ${(outside.dtgOvertimeHours ?? 0).toFixed(4)} OT h`;
      if (outside.dtgActual != null) note += ` / ${outside.dtgActual} prints / ${garments.get(`${date}|OUT_OF_SHIFT`) ?? "—"} garments`;
      notes.push(note);
    }
    return [compose(date, "TOTAL", total, total?.dtgGarments ?? null, notes.join(" · ")),
      ...(["A", "B", "C"] as const).map((label, index) => {
        const code = `SHIFT_${index + 1}`, selected = filter === "ALL" || filter === code;
        return compose(date, label, selected ? shifts.get(`${date} · Shift ${index + 1}`) : undefined, selected ? garments.get(`${date}|${code}`) ?? null : null);
      })];
  });
}
