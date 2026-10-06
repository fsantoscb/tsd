import { buildLabourMatrix, type LabourMatrixRow, type LabourSegment } from "./labour-matrix";

export type LabourFilters = { area: string; shift: string; hasOvertime: boolean };
export type LabourQuery = LabourFilters & { from: string; to: string; view: string };
export type LabourSummaryRow = LabourMatrixRow & { quality: "APPROVED" | "PROVISIONAL" | "CHECK" };
const AREA_ORDER = ["DTG_OPERATOR", "UP_OPERATOR", "SCREEN_PRINT_CREW", "SCREEN_ROOM", "SHARED_DISPATCH", "INDIRECT"];
const areaRank = (area: string) => { const index = AREA_ORDER.indexOf(area); return index < 0 ? AREA_ORDER.length : index; };
export const compareLabourAreas = (a: string, b: string) => areaRank(a) - areaRank(b) || a.localeCompare(b);

export function totalLabourRows(rows: LabourMatrixRow[]) {
  const total = { paid: 0, productive: 0, regular: 0, overtime: 0, breaks: 0, people: new Set<string>() };
  for (const row of rows) {
    for (const field of ["paid", "productive", "regular", "overtime", "breaks"] as const) total[field] += row[field];
    row.people.forEach(person => total.people.add(person));
  }
  return total;
}

export function buildLabourSelection(data: LabourSegment[], filters: LabourFilters) {
  const filtered = data.filter(segment => segment.approval_status !== "INCOMPLETE"
    && !!segment.operational_date && !!segment.area_code
    && (filters.area === "ALL" || segment.area_code === filters.area)
    && (filters.shift === "ALL" || segment.shift_code === filters.shift));
  const checkKeys = new Set(filtered.filter(segment => segment.approval_status === "CHECK").map(segment => `${segment.operational_date}|${segment.area_code}`));
  const rows: LabourSummaryRow[] = buildLabourMatrix(filtered)
    .filter(row => !filters.hasOvertime || row.overtime > 0)
    .map(row => {
      const hasCheck = checkKeys.has(`${row.date}|${row.area}`);
      return { ...row, quality: !row.reconciled || hasCheck ? "CHECK" as const : row.provisional ? "PROVISIONAL" as const : "APPROVED" as const };
    }).sort((a, b) => b.date.localeCompare(a.date) || compareLabourAreas(a.area, b.area));
  const keys = new Set(rows.map(row => `${row.date}|${row.area}`));
  const segments = filtered.filter(segment => keys.has(`${segment.operational_date}|${segment.area_code}`));
  const days = [...new Set(rows.map(row => row.date))].map(date => {
    const dayRows = rows.filter(row => row.date === date);
    return { date, rows: dayRows, total: totalLabourRows(dayRows) };
  });
  return {
    rows, segments, days, total: totalLabourRows(rows),
    outPaid: rows.reduce((sum, row) => sum + row.shifts.OUT_OF_SHIFT.paid, 0),
    outProductive: rows.reduce((sum, row) => sum + row.shifts.OUT_OF_SHIFT.productive, 0),
    provisional: rows.filter(row => row.provisional).length,
    checks: rows.filter(row => row.quality === "CHECK").length,
    quality: !rows.length ? "NO DATA" : rows.some(row => row.quality === "CHECK") ? "CHECK" : "PASS",
  };
}

export function formatLabourHours(value: number, decimals = 1) {
  if (value !== 0 && Math.abs(value) < 0.5 * 10 ** -decimals) return value > 0 ? `<${(10 ** -decimals).toFixed(decimals)}` : `>-${(10 ** -decimals).toFixed(decimals)}`;
  return value.toLocaleString("en-AU", { minimumFractionDigits: decimals, maximumFractionDigits: decimals });
}

export function labourDetailHref(query: LabourQuery, area: string) {
  return `/production/labour/detail?${new URLSearchParams({ from: query.from, to: query.to, area, shift: query.shift, ot: query.hasOvertime ? "1" : "0", view: query.view })}`;
}
