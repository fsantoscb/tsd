import React from "react";
import type { buildDailyProductionFlow } from "@/lib/daily-production-flow";

type Row = ReturnType<typeof buildDailyProductionFlow>[number];
const columns: Array<[keyof Row, string]> = [
  ["date", "DATE"], ["printsDtg", "PRINTS DTG"], ["garmentsDtg", "GARMENTS DTG"],
  ["dtgOutput", "DTG OUTPUT"], ["upOutput", "UP OUTPUT"], ["totalOutput", "TOTAL OUTPUT"],
  ["dtgLabourH", "DTG LABOUR H"], ["upLabourH", "UP LABOUR H"], ["dispatchLabourH", "DISPATCH LABOUR H"],
  ["totalLabourH", "TOTAL LABOUR H"], ["overtimeH", "OVERTIME H"],
];

export function DailyProductionFlowTable({ rows }: { rows: Row[] }) {
  return <section className="performance-daily-table">
    <h3>DAILY PRODUCTION FLOW &amp; LABOUR</h3>
    <table>
      <thead><tr><th rowSpan={2}>DATE</th><th colSpan={2}>OUTPUT</th><th colSpan={3}>FLOW</th><th colSpan={5}>LABOUR</th></tr>
        <tr>{columns.slice(1).map(([, label]) => <th key={label} style={{ textAlign: "right" }}>{label}</th>)}</tr></thead>
      <tbody>{rows.map(row => <tr key={row.date}>{columns.map(([key]) => {
        const value = row[key];
        return <td key={key} style={{ textAlign: key === "date" ? "left" : "right" }}>{value === null ? "—" : typeof value === "number" ? value.toLocaleString("en-AU", { maximumFractionDigits: 2 }) : value}</td>;
      })}</tr>)}</tbody>
    </table>
  </section>;
}
