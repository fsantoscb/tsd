import React from "react";
import type { DtgPerformanceRow } from "@/lib/dtg-performance-rows";
import styles from "./dtg-daily-performance.module.css";

const numeric = (value: number | null, decimals = 1) => value === null ? "—" : value.toLocaleString("en-AU", { maximumFractionDigits: decimals });
const ratio = (value: number | null) => value === null ? "—" : value.toFixed(2);
const percentage = (value: number | null) => value === null ? "—" : `${(value * 100).toFixed(1)}%`;
const headers = ["DATE", "SHIFT", "PRINTS", "GARMENTS", "P/G", "CAPACITY", "UTILISATION", "PRODUCTIVE H", "PRINTS/H", "OVERTIME H", "NOTES"];

export function DtgDailyPerformanceTable({ rows }: { rows: DtgPerformanceRow[] }) {
  return <section className="performance-daily-table">
    <h3>DTG — Daily performance</h3>
    <div className={styles.scroll} role="region" aria-label="DTG daily performance table" tabIndex={0}>
      <table className={styles.table}>
        <thead><tr>{headers.map((header, index) => <th key={header} scope="col" className={index > 1 && index < 10 ? styles.numeric : undefined}>{header}</th>)}</tr></thead>
        <tbody>{rows.map(row => <tr key={`${row.operationalDate}|${row.shift}`} className={row.isTotal ? styles.total : undefined}>
          <th scope="row">{row.isTotal ? row.operationalDate : <span className={styles.srOnly}>{row.operationalDate}</span>}</th>
          <th scope="row" className={styles.shiftLabel}>{row.shift}</th>
          <td className={styles.numeric}>{numeric(row.prints, 0)}</td>
          <td className={styles.numeric}>{numeric(row.garments, 0)}</td>
          <td className={styles.numeric}>{ratio(row.printsPerGarment)}</td>
          <td className={styles.numeric}>{numeric(row.capacity, 0)}</td>
          <td className={styles.numeric}>{percentage(row.utilisation)}</td>
          <td className={styles.numeric}>{numeric(row.productiveHours)}</td>
          <td className={styles.numeric}>{numeric(row.printsPerHour)}</td>
          <td className={styles.numeric}>{numeric(row.overtimeHours)}</td>
          <td className={styles.notes}>{row.notes}</td>
        </tr>)}</tbody>
      </table>
    </div>
  </section>;
}
