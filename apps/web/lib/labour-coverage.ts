export type LabourSnapshot = {
  snapshot_type: string; status: string; report_generated_at: string | null;
  coverage_start: string | null; coverage_end: string | null;
  certified_at: string | null; certified_by: string | null;
};
export function describeLabourCoverage(rows: LabourSnapshot[], from: string, to: string, complete: boolean) {
  const eligible = rows.filter(row => row.snapshot_type === "FULL" && row.status === "COMPLETED"
    && row.certified_at && row.certified_by && row.report_generated_at && row.coverage_start && row.coverage_end
    && row.coverage_start <= row.coverage_end);
  const empty = { sourceCovered: false, latestGenerated: null as string | null, operationalZeroCertified: false,
    message: "Labour coverage unavailable. Missing operational-date contributions are not certified zero.",
    coverageStart: null as string | null, coverageEnd: null as string | null, available: false, snapshots: 0 };
  if (!complete || !eligible.length) return empty;
  let sourceCovered = true;
  for (let date = from; date <= to; date = new Date(Date.parse(`${date}T12:00:00Z`) + 864e5).toISOString().slice(0, 10)) {
    const covering = eligible.filter(row => row.coverage_start! <= date && row.coverage_end! >= date);
    const latest = Math.max(...covering.map(row => Date.parse(row.report_generated_at!)));
    if (!covering.length || covering.filter(row => Date.parse(row.report_generated_at!) === latest).length !== 1) sourceCovered = false;
  }
  const latest = [...eligible].sort((a, b) => Date.parse(b.report_generated_at!) - Date.parse(a.report_generated_at!))[0];
  return { ...empty, available: true, sourceCovered, latestGenerated: latest.report_generated_at,
    coverageStart: eligible.map(row => row.coverage_start!).sort()[0], coverageEnd: eligible.map(row => row.coverage_end!).sort().at(-1)!, snapshots: eligible.length,
    message: sourceCovered
      ? "Coverage confirmed for selected source timesheet dates. Operational dates may include cross-midnight contributions; absence is not certified zero."
      : "Coverage status unavailable for part of the selected source period. Operational dates may include cross-midnight contributions; absence is not certified zero.",
  };
}
