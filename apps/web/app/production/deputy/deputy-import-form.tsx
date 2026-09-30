"use client";

import {useState} from "react";
import {inspectDeputy} from "../../../lib/deputy-import";
import {brisbaneDate,snapshotFields,type SnapshotMode} from "../../../lib/deputy-import-ux";
import {uploadDeputy} from "./actions";
import styles from "./deputy.module.css";

type Inspection=ReturnType<typeof inspectDeputy>;

export function DeputyImportForm({certifiedBy}:{certifiedBy:string}){
  const [inspection,setInspection]=useState<Inspection|null>(null);
  const [error,setError]=useState("");
  const [mode,setMode]=useState<SnapshotMode>("FULL");
  const [date,setDate]=useState(()=>brisbaneDate());
  const [time,setTime]=useState("");
  const [start,setStart]=useState("");
  const [end,setEnd]=useState("");
  const [note,setNote]=useState("Standard full Deputy export");

  async function inspect(file:File|undefined){
    setInspection(null);
    setError("");
    if(!file)return;
    if(file.size>15*1024*1024){setError("File exceeds 15 MB");return;}
    try{
      const observed=inspectDeputy(await file.arrayBuffer());
      if(!observed.minDate||!observed.maxDate){setError("No valid timesheet dates were found in the file");return;}
      setInspection(observed);
      setStart(observed.minDate);
      setEnd(observed.maxDate);
    }catch(e){setError(e instanceof Error?e.message:"Could not inspect the Deputy file");}
  }

  async function submit(form:FormData){
    setError("");
    if(!inspection){setError("Choose and inspect a Deputy file first");return;}
    try{
      const fields=snapshotFields(mode,date,time,start,end,note);
      for(const [key,value] of Object.entries(fields))form.set(key,value);
      await uploadDeputy(form);
    }catch(e){setError(e instanceof Error?e.message:"Deputy import failed");}
  }

  function changeMode(value:SnapshotMode){
    setMode(value);
    if(value==="FULL"&&!note)setNote("Standard full Deputy export");
    if(value!=="FULL"&&note==="Standard full Deputy export")setNote("");
  }

  const mismatch=inspection&&(start!==inspection.minDate||end!==inspection.maxDate);

  return <form action={submit} className={`deputy-upload ${styles.upload}`}>
    <label className={styles.field}>Choose file
      <input name="file" type="file" accept=".csv,.xlsx" required onChange={event=>void inspect(event.currentTarget.files?.[0])}/>
    </label>
    <div className={styles.when}>
      <span>Report generated at</span>
      <div className={styles.dateTime}>
        <label className={styles.field}>Date <input type="date" value={date} onChange={event=>setDate(event.target.value)} required={mode!=="UNVERIFIED"}/></label>
        <label className={styles.field}>Time <input type="time" value={time} onChange={event=>setTime(event.target.value)} required={mode!=="UNVERIFIED"}/></label>
      </div>
      <small>Australia/Brisbane · Enter the time this Deputy report was generated. No time is assumed.</small>
    </div>
    <div className={styles.detected} aria-live="polite">
      <strong>Detected report coverage</strong>
      <span>{inspection?`${inspection.minDate} → ${inspection.maxDate}`:"Choose a file to detect its timesheet dates"}</span>
      {inspection&&<small>{inspection.rowCount} rows · {inspection.employeeCount} employees. These dates suggest, but do not prove, declared coverage.</small>}
    </div>
    <details className={styles.advanced}>
      <summary>Advanced snapshot settings</summary>
      <div className={styles.advancedGrid}>
        <label className={styles.field}>Snapshot type
          <select name="snapshot_type" value={mode} onChange={event=>changeMode(event.target.value as SnapshotMode)}>
            <option value="FULL">FULL — complete Deputy snapshot for declared period</option>
            <option value="PARTIAL">PARTIAL — subset export</option>
            <option value="UNVERIFIED">UNVERIFIED — legacy/manual import</option>
          </select>
        </label>
        <label className={styles.field}>Coverage start <input name="coverage_start" type="date" value={start} onChange={event=>setStart(event.target.value)} required={mode!=="UNVERIFIED"}/></label>
        <label className={styles.field}>Coverage end <input name="coverage_end" type="date" value={end} onChange={event=>setEnd(event.target.value)} required={mode!=="UNVERIFIED"}/></label>
        <label className={styles.field}>Certification note <textarea name="certification_note" rows={2} value={note} onChange={event=>setNote(event.target.value)} required={mode==="FULL"}/></label>
        <label className={styles.field}>Certified by <input value={certifiedBy} readOnly aria-label="Certified by authenticated user"/></label>
        <label className={styles.field}>Source timezone <select name="timezone" defaultValue="Australia/Brisbane"><option>Australia/Brisbane</option><option>UTC</option></select></label>
        <small className={styles.full}>Declared coverage may include dates with no timesheet rows. FULL is canonical as of its report-generation time. PARTIAL and UNVERIFIED are stored for audit but are not eligible for canonical snapshot authority.</small>
      </div>
    </details>
    {mismatch&&<p className={styles.review}>Declared coverage differs from dates observed in the file. Review the report range before import.</p>}
    {mode==="PARTIAL"&&<p className={styles.review}>PARTIAL snapshots are stored for audit but are not eligible for canonical Labour authority.</p>}
    {mode==="UNVERIFIED"&&<p className={styles.review}>UNVERIFIED imports are not eligible for snapshot authority.</p>}
    {error&&<p className={styles.error} role="alert">{error}</p>}
    <button type="submit" className="deputy-submit" disabled={!inspection}>Import Deputy</button>
    <small>CSV or XLSX, maximum 15 MB. Select UTC in Advanced only when the exported timestamps are UTC.</small>
  </form>;
}
