export function brisbaneDate(now:Date=new Date()):string{
  const parts=new Intl.DateTimeFormat("en-AU",{timeZone:"Australia/Brisbane",year:"numeric",month:"2-digit",day:"2-digit"}).formatToParts(now);
  const value=(type:string)=>parts.find(part=>part.type===type)?.value??"";
  return `${value("year")}-${value("month")}-${value("day")}`;
}

export function reportGeneratedAt(date:string,time:string):string|null{
  if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(time))return null;
  const parsed=new Date(`${date}T00:00:00+10:00`);
  if(Number.isNaN(+parsed)||new Date(+parsed+10*60*60*1000).toISOString().slice(0,10)!==date)return null;
  return `${date}T${time}:00+10:00`;
}

export type SnapshotMode="FULL"|"PARTIAL"|"UNVERIFIED";

export function snapshotFields(mode:SnapshotMode,date:string,time:string,start:string,end:string,note:string){
  if(mode==="UNVERIFIED")return {snapshot_type:"",report_generated_at:"",coverage_start:"",coverage_end:"",certification_note:""};
  const generated=reportGeneratedAt(date,time);
  if(!generated)throw Error("Report generated at requires a valid date and time in Australia/Brisbane");
  if(!start)throw Error("Coverage start is required");
  if(!end)throw Error("Coverage end is required");
  if(!reportGeneratedAt(start,"00:00")||!reportGeneratedAt(end,"00:00")||start>end)throw Error("Coverage start/end must be valid and ordered");
  if(mode==="FULL"&&!note.trim())throw Error("Certification note is required for FULL");
  return {snapshot_type:mode,report_generated_at:generated,coverage_start:start,coverage_end:end,certification_note:note.trim()};
}
