export type DeputySnapshotMetadata={
  report_generated_at:string|null;
  coverage_start:string|null;
  coverage_end:string|null;
  snapshot_type:"FULL"|"PARTIAL"|null;
  certified_at:string|null;
  certified_by:string|null;
  certification_note:string|null;
};

export function parseDeputySnapshotMetadata(form:FormData,certifiedBy:string,certifiedAt:Date=new Date()):DeputySnapshotMetadata{
  const empty:DeputySnapshotMetadata={report_generated_at:null,coverage_start:null,coverage_end:null,snapshot_type:null,certified_at:null,certified_by:null,certification_note:null};
  const value=(key:string)=>String(form.get(key)??"").trim();
  const generated=value("report_generated_at"),start=value("coverage_start"),end=value("coverage_end"),type=value("snapshot_type"),note=value("certification_note");
  if(!generated&&!start&&!end&&!type&&!note)return empty;
  if(!generated||!start||!end||!type)throw new Error("Snapshot metadata fields are required together");
  if(type!=="FULL"&&type!=="PARTIAL")throw new Error("Invalid snapshot type");
  if(type==="FULL"&&!note)throw new Error("FULL snapshot requires a certification note");
  if(!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})$/i.test(generated)||Number.isNaN(Date.parse(generated)))throw new Error("Report generation timestamp requires an explicit timezone");
  const validDate=(date:string)=>/^\d{4}-\d{2}-\d{2}$/.test(date)&&!Number.isNaN(Date.parse(date))&&new Date(date).toISOString().slice(0,10)===date;
  if(!validDate(start)||!validDate(end)||start>end)throw new Error("Invalid snapshot coverage range");
  if(!certifiedBy.trim()||Number.isNaN(certifiedAt.getTime()))throw new Error("Snapshot certification identity and time are required");
  return {report_generated_at:generated,coverage_start:start,coverage_end:end,snapshot_type:type,
    certified_at:certifiedAt.toISOString(),certified_by:certifiedBy.trim(),certification_note:note||null};
}
