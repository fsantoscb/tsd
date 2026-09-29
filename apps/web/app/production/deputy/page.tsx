import {AppShell} from "@/components/app-shell";
import {deputyContext} from "@/lib/deputy";
import {uploadDeputy} from "./actions";
import styles from "./deputy.module.css";

export default async function Page({searchParams}:{searchParams:Promise<{result?:string}>}){
  const [p,d]=await Promise.all([searchParams,deputyContext()]);
  return <AppShell>
    <p className="eyebrow">ERP KPI · Phase B</p>
    <header><div><h2>Deputy labour<br/>imports.</h2><p>Raw, auditable timesheets. Invalid rows remain quarantined and cannot affect KPIs.</p></div></header>
    {p.result&&<p className="notice">{p.result==="duplicate"?"This exact file was already imported. No hours were duplicated.":"Deputy file imported and validated."}</p>}
    <section className="panel">
      <h3>Import Deputy export</h3>
      <form action={uploadDeputy} className={`deputy-upload ${styles.upload}`}>
        <input name="file" type="file" accept=".csv,.xlsx" required/>
        <select name="timezone" defaultValue="Australia/Brisbane"><option>Australia/Brisbane</option><option>UTC</option></select>
        <fieldset className={styles.certification}>
          <legend>Snapshot certification</legend>
          <label className={styles.field}>Snapshot type <select name="snapshot_type" defaultValue=""><option value="">Unverified — standard import</option><option value="FULL">FULL — complete report for declared period</option><option value="PARTIAL">PARTIAL — not eligible for Labour authority</option></select></label>
          <label className={styles.field}>Report generated at <input name="report_generated_at" type="text" placeholder="2026-09-30T15:00:00+10:00" autoComplete="off"/></label>
          <small className={styles.help}>Enter the actual Deputy report-generation time with an explicit timezone. Do not use the upload time or an assumed 06:10/15:00.</small>
          <label className={styles.field}>Declared coverage start <input name="coverage_start" type="date"/></label>
          <label className={styles.field}>Declared coverage end <input name="coverage_end" type="date"/></label>
          <small className={styles.help}>Declared report coverage can include dates with no rows and can be older than 14 days. It is not inferred from the observed timesheet dates.</small>
          <label className={`${styles.field} ${styles.full}`}>Certification note <textarea name="certification_note" rows={2} placeholder="Source/evidence confirming report time, coverage and completeness"/></label>
          <label className={styles.field}>Certified by <input value={d.user.email??d.user.id} readOnly aria-label="Certified by authenticated user"/></label>
          <small className={styles.help}>FULL requires report time, coverage and an evidence note. Certification identity and time are set by the server. Leave all snapshot fields blank for a standard unverified import.</small>
        </fieldset>
        <button type="submit" className="deputy-submit">Validate and import</button>
      </form>
      <small>CSV or XLSX, maximum 15 MB. Select UTC only when the exported timestamps are UTC.</small>
    </section>
    <section className="panel"><h3>Import history</h3><div className="table"><table><thead><tr><th>Imported</th><th>File</th><th>Coverage</th><th>Rows</th><th>Approved</th><th>Provisional</th><th>Quarantined</th><th>Status</th><th>Snapshot</th><th>Certified at</th><th>Certified by</th></tr></thead><tbody>{d.batches.map((b:any)=><tr key={b.id}><td>{new Date(b.imported_at).toLocaleString("en-AU",{timeZone:"Australia/Brisbane"})}</td><td>{b.filename}</td><td>{b.covered_from??"-"} → {b.covered_to??"-"}</td><td>{b.raw_rows}</td><td>{b.approved_rows}</td><td>{b.provisional_rows}</td><td>{b.quarantined_rows}</td><td>{b.status}</td><td>{b.snapshot_type??"UNVERIFIED"}</td><td>{b.certified_at?new Date(b.certified_at).toLocaleString("en-AU",{timeZone:"Australia/Brisbane"}):"—"}</td><td>{b.certified_by??"—"}</td></tr>)}</tbody></table></div></section>
    <section className="panel"><h3>Latest quarantined rows</h3><div className="table"><table><thead><tr><th>Date</th><th>Employee</th><th>Area</th><th>Reasons</th></tr></thead><tbody>{d.exceptions.map((e:any)=><tr key={e.id}><td>{e.timesheet_date??"-"}</td><td>{e.display_name??"Missing"}</td><td>{e.raw_area??"Missing"}</td><td>{e.quarantine_reasons.join(", ")}</td></tr>)}</tbody></table></div></section>
  </AppShell>;
}
