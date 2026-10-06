import { Fragment } from "react";
import Link from "next/link";
import { AppShell } from "@/components/app-shell";
import { labourOperationalData } from "@/lib/labour-dashboard";
import { LABOUR_SHIFTS, labourAreaLabel } from "@/lib/labour-matrix";
import { buildLabourSelection, compareLabourAreas, formatLabourHours as hours, labourDetailHref, type LabourQuery } from "@/lib/labour-operational-summary";
import { describeLabourCoverage } from "@/lib/labour-coverage";
import "./labour.css";

const today = () => new Intl.DateTimeFormat("en-CA", { timeZone: "Australia/Brisbane", year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date());
const day = (value: string) => new Intl.DateTimeFormat("en-AU", { timeZone: "UTC", day: "2-digit", month: "short", year: "numeric" }).format(new Date(`${value}T12:00:00Z`));
const timestamp = (value: string) => new Intl.DateTimeFormat("en-AU", { timeZone: "Australia/Brisbane", day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(value));
const shiftLabel = (value: string) => ({ SHIFT_1: "A", SHIFT_2: "B", SHIFT_3: "C", OUT_OF_SHIFT: "OUT_OF_SHIFT" }[value] ?? value);
const percent = (overtime: number, paid: number) => paid > 0 ? `${hours(overtime / paid * 100)}%` : "—";
const validDate = (value: string | undefined) => !!value && /^\d{4}-\d{2}-\d{2}$/.test(value) && Number.isFinite(Date.parse(value)) && new Date(value).toISOString().slice(0, 10) === value;

export default async function Page({ searchParams }: { searchParams: Promise<Record<string, string | string[] | undefined>> }) {
  const raw = await searchParams;
  const value = (name: string) => Array.isArray(raw[name]) ? raw[name][0] : raw[name];
  const to = validDate(value("to")) ? value("to")! : today();
  const from = validDate(value("from")) ? value("from")! : new Date(Date.parse(`${to}T12:00:00Z`) - 13 * 864e5).toISOString().slice(0, 10);
  const shift = LABOUR_SHIFTS.includes(value("shift") as typeof LABOUR_SHIFTS[number]) ? value("shift")! : "ALL";
  const view = ["summary", "shift", "audit"].includes(value("view") ?? "") ? value("view")! : "summary";
  const query: LabourQuery = { from, to, area: value("area") ?? "ALL", shift, hasOvertime: value("ot") === "1", view };
  const invalidRange = from > to;
  const data = invalidRange ? { segments: [], snapshots: [], metadataComplete: false } : await labourOperationalData(from, to);
  const selection = buildLabourSelection(data.segments, query);
  const coverage = describeLabourCoverage(data.snapshots, from, to, data.metadataComplete);
  const areas = [...new Set(data.segments.filter(segment => segment.approval_status !== "INCOMPLETE").map(segment => segment.area_code))].sort(compareLabourAreas);
  const params = { from, to, area: query.area, shift, ot: query.hasOvertime ? "1" : "0", view };
  const viewHref = (nextView: string) => `/production/labour?${new URLSearchParams({ ...params, view: nextView })}`;
  const total = selection.total;

  return <AppShell><div className="erp-kpi labour-v2">
    <header className="labour-header"><div><p>LABOUR</p><h2>Historical Labour allocation &amp; utilisation</h2><span>Canonical hours and distinct people within the current selection.</span></div><Link href="/production/deputy">Deputy imports →</Link></header>
    <section className="labour-coverage" aria-label="Labour coverage">
      <strong>{coverage.available ? "Labour context: certified FULL snapshots" : "Labour coverage unavailable"}</strong>
      {coverage.latestGenerated && <span>Latest generated: {timestamp(coverage.latestGenerated)} AEST</span>}
      {coverage.coverageEnd && <span>Source timesheet coverage: {day(coverage.coverageStart!)} – {day(coverage.coverageEnd)}</span>}
      <small>{coverage.message} {coverage.snapshots > 1 && "Multiple snapshots may contribute; Deputy contains the authority details."} Oracle freshness is separate from Labour coverage.</small>
    </section>
    <form className="labour-filters" key={new URLSearchParams(params).toString()}>
      <input type="hidden" name="view" value={view}/>
      <label>From<input type="date" name="from" defaultValue={from} required/></label>
      <label>To<input type="date" name="to" defaultValue={to} required/></label>
      <label>Area<select name="area" defaultValue={query.area}><option value="ALL">All areas</option>{areas.map(area => <option key={area} value={area}>{labourAreaLabel(area)}</option>)}</select></label>
      <label>Shift<select name="shift" defaultValue={shift}><option value="ALL">All shifts</option>{LABOUR_SHIFTS.slice(0, 3).map(code => <option key={code} value={code}>Shift {shiftLabel(code)}</option>)}{shift === "OUT_OF_SHIFT" && <option value="OUT_OF_SHIFT">OUT_OF_SHIFT</option>}</select></label>
      <label className="labour-overtime-filter"><input type="checkbox" name="ot" value="1" defaultChecked={query.hasOvertime}/>Has Overtime</label>
      <button type="submit">Apply</button><Link href="/production/labour">Clear</Link>
    </form>
    {invalidRange && <p role="alert" className="labour-attention">From must be on or before To. Adjust the date filters and Apply.</p>}
    <section className="labour-cards" aria-label="Selected Labour metrics">
      <article><span>Paid H</span><strong>{hours(total.paid)}</strong></article>
      <article><span>Productive H</span><strong>{hours(total.productive)}</strong></article>
      <article><span>Overtime H</span><strong>{hours(total.overtime)}</strong><small>{percent(total.overtime, total.paid)} of Paid H</small></article>
      <article><span>People</span><strong>{total.people.size}</strong><small>Distinct in selection · not FTE</small></article>
      <article><span>OUT OF SHIFT H</span><strong>{hours(selection.outPaid)} paid h</strong><small>{hours(selection.outProductive)} productive h</small></article>
      <article><span>Quality · Hours check</span><strong>{selection.quality}</strong><small>Provisional: {selection.provisional} · Check: {selection.checks}</small></article>
    </section>
    <section className="labour-reconciliation"><b>Regular H {hours(total.regular)}</b><b>Paid Breaks H {hours(total.breaks)}</b><span>Paid = Regular + OT · Paid = Productive + Paid Breaks</span><small>Arithmetic reconciliation only — not approval or completeness certification. {selection.rows.length} selected area-days.</small></section>
    <nav className="labour-views" aria-label="Labour views">{[["summary", "Summary"], ["shift", "Shift Breakdown"], ["audit", "Audit Matrix"]].map(([key, label]) => <Link key={key} href={viewHref(key)} aria-current={view === key ? "page" : undefined}>{label}</Link>)}</nav>
    <section className={`labour-table-scroll ${view === "audit" ? "labour-audit-table" : view === "shift" ? "labour-breakdown-table" : "labour-summary-table"}`} aria-label={`${view} Labour table`} tabIndex={0}>
      {view === "summary" && <table><thead><tr>{["Date", "Area", "People", "Paid H", "Productive H", "OT H", "OT %", "OUT OF SHIFT", "Quality"].map(label => <th key={label} scope="col">{label}</th>)}</tr></thead><tbody>
        {selection.days.map(group => <Fragment key={group.date}>{group.rows.map(row => <tr key={`${row.date}|${row.area}`}><th scope="row">{day(row.date)}</th><td><Link title={row.area} href={labourDetailHref(query, row.area)}>{labourAreaLabel(row.area)}</Link></td><td>{row.people.size}</td><td>{hours(row.paid)}</td><td>{hours(row.productive)}</td><td>{hours(row.overtime)}</td><td>{percent(row.overtime, row.paid)}</td><td className={row.shifts.OUT_OF_SHIFT.people.size ? "labour-attention" : undefined}>{row.shifts.OUT_OF_SHIFT.people.size ? `${hours(row.shifts.OUT_OF_SHIFT.paid)} paid h` : "—"}</td><td><span className={`labour-quality ${row.quality.toLowerCase()}`}>{row.quality}</span></td></tr>)}
          <tr className="labour-day-total"><th scope="row">{day(group.date)}</th><td>Daily subtotal</td><td>{group.total.people.size}</td><td>{hours(group.total.paid)}</td><td>{hours(group.total.productive)}</td><td>{hours(group.total.overtime)}</td><td>{percent(group.total.overtime, group.total.paid)}</td><td>—</td><td>—</td></tr></Fragment>)}
      </tbody></table>}
      {view === "shift" && <table><thead><tr>{["Date", "Area", "Shift", "People", "Paid H", "Productive H", "OT H", "OT %"].map(label => <th key={label} scope="col">{label}</th>)}</tr></thead><tbody>
        {selection.rows.flatMap(row => LABOUR_SHIFTS.filter(code => row.shifts[code].people.size > 0).map(code => { const cell = row.shifts[code]; return <tr key={`${row.date}|${row.area}|${code}`}><th scope="row">{day(row.date)}</th><td><Link href={labourDetailHref(query, row.area)}>{labourAreaLabel(row.area)}</Link></td><td>{shiftLabel(code)}</td><td>{cell.people.size}</td><td>{hours(cell.paid)}</td><td>{hours(cell.productive)}</td><td>{hours(cell.overtime)}</td><td>{percent(cell.overtime, cell.paid)}</td></tr>; }))}
      </tbody></table>}
      {view === "audit" && <table><colgroup><col className="labour-date-col"/><col className="labour-area-col"/>{Array.from({ length: 19 }, (_, index) => <col key={index}/>)}</colgroup><thead><tr><th className="labour-date" rowSpan={2}>Date</th><th className="labour-area" rowSpan={2}>Area</th>{LABOUR_SHIFTS.map(code => <th colSpan={3} key={code}>{shiftLabel(code)}</th>)}<th colSpan={6}>Daily totals</th><th rowSpan={2}>Quality</th></tr><tr>{LABOUR_SHIFTS.flatMap(code => ["People", "Paid", "OT"].map(label => <th key={`${code}|${label}`}>{label}</th>))}{["People", "Regular", "OT", "Paid Breaks", "Productive", "Paid"].map(label => <th key={label}>{label}</th>)}</tr></thead><tbody>
        {selection.rows.map(row => <tr key={`${row.date}|${row.area}`}><th className="labour-date" scope="row">{day(row.date)}</th><th className="labour-area" scope="row"><Link title={row.area} href={labourDetailHref(query, row.area)}>{labourAreaLabel(row.area)}</Link></th>{LABOUR_SHIFTS.flatMap(code => { const cell = row.shifts[code]; return [<td key={`${code}|people`}>{cell.people.size}</td>, <td key={`${code}|paid`}>{hours(cell.paid, 2)}</td>, <td key={`${code}|ot`}>{hours(cell.overtime, 2)}</td>]; })}<td>{row.people.size}</td><td>{hours(row.regular, 2)}</td><td>{hours(row.overtime, 2)}</td><td>{hours(row.breaks, 2)}</td><td>{hours(row.productive, 2)}</td><td>{hours(row.paid, 2)}</td><td>{row.quality}</td></tr>)}
      </tbody></table>}
      {!selection.rows.length && <p className="labour-empty">No canonical Labour contributions match the selected filters. {coverage.available ? "Source-timesheet coverage does not certify zero for an operational date." : "Labour coverage is unavailable; missing contributions are not certified zero."}</p>}
    </section>
  </div></AppShell>;
}
