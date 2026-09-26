import Link from "next/link";
import { uvOperationalOrders } from "@/lib/uv-operational";
import { filterUvOrders, parseUvStage, summarizeUvOrders, uvStages } from "../../../lib/uv-operational-model";
import ClearFiltersLink from "./clear-filters-link";
import styles from "./uv.module.css";

const number = (value: number) => new Intl.NumberFormat("en-AU").format(Number(value) || 0);
const date = (value: string | null) => value ? new Intl.DateTimeFormat("en-AU", { day: "2-digit", month: "short", year: "numeric" }).format(new Date(value)) : "—";

const single = (value: string | string[] | undefined) => Array.isArray(value) ? value[0] ?? "" : value ?? "";

export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const params = await searchParams;
  const all = await uvOperationalOrders();
  const q = single(params.q).trim().slice(0, 80);
  const stage = parseUvStage(single(params.stage));
  const rows = filterUvOrders(all, { q, stage });
  const totals = summarizeUvOrders(all);
  const filterKey = JSON.stringify([q, stage]);

  return <section className={styles.root}>
    <header className={`hero compact ${styles.header}`}>
      <div><p className="eyebrow">ORACLE · UV ROOM</p><h2>UV Production</h2><p>Current UV, Laser, Sticker and Finished Goods workload.</p></div>
      <div className={styles.headerRight}><Link className={styles.homeLink} href="/">← Production Control</Link><div className="hero-stat"><b>{number(all.length)}</b><span>Operational orders</span></div></div>
    </header>

    <div className={styles.cards}>{uvStages.map(([label, field]) => <div className={styles.card} key={label}><span>{label}</span><strong>{number(totals[field])}</strong><small>current units</small></div>)}</div>

    <form className={styles.filters} method="get" key={filterKey}>
      <input aria-label="Search order or customer" name="q" defaultValue={q} placeholder="Order number or customer" />
      <select aria-label="Stage" name="stage" defaultValue={stage}><option value="ALL">All stages</option>{uvStages.map(([label]) => <option key={label} value={label}>{label}</option>)}</select>
      <button type="submit">Apply</button><ClearFiltersLink />
    </form>

    <p className={styles.result}>Showing <b>{number(rows.length)}</b> of {number(all.length)} operational orders.</p>
    <div className={styles.tableScroll}><table><thead><tr><th>Priority</th><th>Order #</th><th>Customer</th><th>Received / Released</th><th>Due</th>{uvStages.map(([label]) => <th className={styles.numeric} key={label}>{label}</th>)}</tr></thead>
      <tbody>{rows.map(row => <tr key={row.order_no}><td>{row.source_priority ?? "—"}</td><td>{row.order_no}</td><td className={styles.customer}>{row.customer_name ?? "—"}</td><td>{date(row.date_received ?? row.date_released)}</td><td>{date(row.date_due)}</td>{uvStages.map(([, field]) => <td className={styles.numeric} key={field}>{number(row[field])}</td>)}</tr>)}</tbody></table>
    </div>
    {rows.length === 0 && <p className={styles.empty}>{all.length === 0 ? "No current UV orders." : "No UV orders match these filters."}</p>}
  </section>;
}
