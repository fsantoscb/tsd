"use client";

export function PrintReportButton() {
  return (
    <button className="print-report-button" type="button" onClick={() => window.print()}>
      <svg aria-hidden="true" viewBox="0 0 24 24" width="16" height="16">
        <path d="M6 9V3h12v6M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2M6 14h12v7H6z" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      Print report
    </button>
  );
}
