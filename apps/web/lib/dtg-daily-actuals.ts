export type DtgDailyActualRow = {
  operational_date: string;
  machine_code: string;
  shift_code: string;
  garments: number | string;
  prints: number | string;
  source_max_event_at: string | null;
  refreshed_at: string;
};

type LegacyPerformanceEvent = {
  event_id: string;
  event_ts_utc: string;
  operational_date: string;
  shift_code: string;
  metric: string;
  quantity: number | string;
  quality_status: string;
};

export function dtgPrintEvents(rows: DtgDailyActualRow[]) {
  return rows.map((row) => ({
    eventId: `DTG_DAILY:${row.operational_date}:${row.shift_code}:${row.machine_code}`,
    timestamp: row.source_max_event_at ?? `${row.operational_date}T12:00:00+10:00`,
    operationalDate: row.operational_date,
    shift: row.shift_code,
    metric: "DTG_PRINT",
    quantity: Number(row.prints),
    quality: row.shift_code === "OUT_OF_SHIFT" ? "OUT_OF_SHIFT" : "COMPLETE",
  }));
}

export function dtgGarmentsByDate(rows: DtgDailyActualRow[]) {
  const totals = new Map<string, number>();
  for (const row of rows) {
    totals.set(row.operational_date, (totals.get(row.operational_date) ?? 0) + Number(row.garments));
  }
  return totals;
}

export function performanceEventsWithDailyDtg(
  events: LegacyPerformanceEvent[],
  dtgRows: DtgDailyActualRow[],
) {
  return [
    ...events.filter((row) => row.metric !== "DTG_PRINT").map((row) => ({
      eventId: row.event_id,
      timestamp: row.event_ts_utc,
      operationalDate: row.operational_date,
      shift: row.shift_code,
      metric: row.metric,
      quantity: Number(row.quantity),
      quality: row.quality_status,
    })),
    ...dtgPrintEvents(dtgRows),
  ];
}
