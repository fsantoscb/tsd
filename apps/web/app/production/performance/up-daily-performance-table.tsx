import React from "react";
import type { UpPerformanceRow } from "@/lib/up-performance-rows";
import styles from "./up-daily-performance.module.css";

const numeric = (value: number | null, decimals = 1) => value === null ? "—" : value.toLocaleString("en-AU", { maximumFractionDigits: decimals });
const percentage = (value: number | null) => value === null ? "—" : `${(value * 100).toFixed(1)}%`;
const headers = ["DATE", "SHIFT", "GARMENTS", "CAPACITY", "UTILISATION", "PRODUCTIVE H", "GARMENTS/H", "OVERTIME H", "NOTES"];

export function UpDailyPerformanceTable({ rows }: { rows: UpPerformanceRow[] }) {
  return <section className="performance-daily-table">
    <h3>UP — Daily performance</h3>
    <div className={styles.scroll} role="region" aria-label="UP daily performance table" tabIndex={0}>
      <table className={styles.table}>
        <thead><tr>{headers.map((header, index) => <th key={header} scope="col" className={index > 1 && index < 8 ? styles.numeric : undefined}>{header}</th>)}</tr></thead>
        <tbody>{rows.map(row => <tr key={`${row.operationalDate}|${row.shift}`} className={row.isTotal ? styles.total : undefined}>
          <th scope="row">{row.isTotal ? row.operationalDate : <span className={styles.srOnly}>{row.operationalDate}</span>}</th>
          <th scope="row" className={styles.shiftLabel}>{row.shift}</th>
          <td className={styles.numeric}>{numeric(row.garments, 3)}</td>
          <td className={styles.numeric}>{numeric(row.capacity)}</td>
          <td className={styles.numeric}>{percentage(row.utilisation)}</td>
          <td className={styles.numeric}>{numeric(row.productiveHours)}</td>
          <td className={styles.numeric}>{numeric(row.garmentsPerHour)}</td>
          <td className={styles.numeric}>{numeric(row.overtimeHours)}</td>
          <td className={styles.notes}>{row.notes}</td>
        </tr>)}</tbody>
      </table>
    </div>
  </section>;
}
