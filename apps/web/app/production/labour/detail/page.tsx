import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { labourDrilldown } from "@/lib/labour-dashboard";
import { LABOUR_SHIFTS, labourAreaLabel } from "@/lib/labour-matrix";
import { formatLabourHours } from "@/lib/labour-operational-summary";
import "../labour.css";

export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const raw = await searchParams;
  const value = (name: string) => Array.isArray(raw[name]) ? raw[name][0] : raw[name];
  const from = value("from") ?? "", to = value("to") ?? "", area = (value("area") ?? "").replace(/[^A-Z_]/g, "");
  const shift = LABOUR_SHIFTS.includes(value("shift") as typeof LABOUR_SHIFTS[number]) ? value("shift")! : "ALL";
  const hasOvertime = value("ot") === "1";
  const view = ["summary", "shift", "audit"].includes(value("view") ?? "") ? value("view")! : "summary";
  const rows = from && to && area ? await labourDrilldown(from, to, area, shift, hasOvertime) : [];
  const back = `/production/labour?${new URLSearchParams({ from, to, area, shift, ot: hasOvertime ? "1" : "0", view })}`;
  return <AppShell><div className="erp-kpi labour-v2">
    <header className="labour-header"><div><p>LABOUR AUDIT</p><h2>{area ? labourAreaLabel(area) : "Area detail"}</h2><span>Production Labour detail · {from} – {to} · {shift.replaceAll("_", " ")}{hasOvertime ? " · Contributions with overtime" : ""}</span></div><Link href={back}>← Back to Labour</Link></header>
    <section className="labour-table-scroll labour-detail-table" tabIndex={0} aria-label="Labour people detail"><table><thead><tr>{["Date", "Shift", "Employee", "Paid", "Productive", "Regular", "Overtime", "Paid Breaks", "Status"].map(label => <th key={label}>{label}</th>)}</tr></thead><tbody>{rows.map((row, index) => <tr key={`${row.person}|${row.date}|${row.shift}|${index}`}><td>{row.date}</td><td>{row.shift}</td><th scope="row">{row.person}</th><td>{formatLabourHours(row.paid, 2)}</td><td>{formatLabourHours(row.productive, 2)}</td><td>{formatLabourHours(row.regular, 2)}</td><td>{formatLabourHours(row.overtime, 2)}</td><td>{formatLabourHours(row.breaks, 2)}</td><td>{row.approval}</td></tr>)}</tbody></table>{!rows.length && <p className="labour-empty">No Labour details match this selection.</p>}</section>
  </div></AppShell>;
}
