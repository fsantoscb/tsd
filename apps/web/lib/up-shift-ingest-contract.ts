import {z} from 'zod';

const date=z.string().regex(/^\d{4}-\d{2}-\d{2}$/).refine(v=>Number.isFinite(Date.parse(v+'T00:00:00Z'))&&new Date(v+'T00:00:00Z').toISOString().slice(0,10)===v);
const timestamp=z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+10:00$/).datetime({offset:true});
const count=z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER);
const common={operationalDate:date,garments:z.number().finite().nonnegative(),sourceEventCount:count.positive(),sourceMaxEventAt:timestamp,sourceSnapshotId:z.string().uuid()};
const shift=z.object({...common,shiftCode:z.enum(['SHIFT_1','SHIFT_2','SHIFT_3','OUT_OF_SHIFT']),calculationVersion:z.literal('UP_UNDERPRINT_EXIT_SHIFT_DAILY_V1')}).strict();
const daily=z.object({...common,jobs:count,calculationVersion:z.literal('UP_UNDERPRINT_EXIT_DAILY_V1')}).strict();
const schema=z.object({organizationId:z.string().uuid(),from:date,to:date,contractVersion:z.literal('UP_SHIFT_DAILY_V1'),sourceSnapshotId:z.string().uuid(),sourceMaxEventAt:timestamp.nullable(),rows:z.array(shift).max(124),dailySummaries:z.array(daily).max(31),coverage:z.array(z.object({operationalDate:date,complete:z.literal(true),hasActivity:z.boolean()}).strict()).min(1).max(31)}).strict();
export type UpShiftIngestPayload=z.infer<typeof schema>;

// Compare the decimal literals that PostgreSQL numeric will persist, not a binary sum.
function decimal(value:number){
 const [mantissa,exponent='0']=String(value).toLowerCase().split('e'),parts=mantissa.split('.');
 const scale=(parts[1]?.length??0)-Number(exponent);
 return {coefficient:BigInt(parts.join(''))*(scale<0?10n**BigInt(-scale):1n),scale:Math.max(0,scale)};
}
function equalSum(values:number[],expected:number){
 const all=[...values,expected].map(decimal),scale=Math.max(...all.map(v=>v.scale));
 const coefficients=all.map(v=>v.coefficient*10n**BigInt(scale-v.scale));
 return coefficients.slice(0,-1).reduce((sum,v)=>sum+v,0n)===coefficients.at(-1);
}
export function validateUpShiftPayload(value:unknown):UpShiftIngestPayload{
 const payload=schema.parse(value),days=(Date.parse(payload.to)-Date.parse(payload.from))/86400000+1;
 if(days<1||days>31)throw Error('INVALID_UP_SHIFT_RANGE');
 const dates=Array.from({length:days},(_,i)=>new Date(Date.parse(payload.from)+i*86400000).toISOString().slice(0,10));
 const coverage=new Map(payload.coverage.map(r=>[r.operationalDate,r]));
 if(coverage.size!==days||payload.coverage.length!==days||dates.some(d=>!coverage.has(d)))throw Error('INCOMPLETE_UP_SHIFT_COVERAGE');
 const unique=new Set<string>();
 for(const row of [...payload.rows,...payload.dailySummaries]){
  if(!dates.includes(row.operationalDate)||row.sourceSnapshotId!==payload.sourceSnapshotId)throw Error('INVALID_UP_SHIFT_ROW_SCOPE');
  const key=row.operationalDate+'|'+('shiftCode' in row?row.shiftCode:'DAILY');
  if(unique.has(key))throw Error('DUPLICATE_UP_SHIFT_GRAIN');unique.add(key);
 }
 for(const date of dates){
  const rows=payload.rows.filter(r=>r.operationalDate===date),summary=payload.dailySummaries.find(r=>r.operationalDate===date);
  if(!coverage.get(date)!.hasActivity){if(rows.length||summary)throw Error('UP_SHIFT_ACTIVITY_MISMATCH');continue;}
  if(!summary||!rows.length)throw Error('UP_SHIFT_ACTIVITY_MISMATCH');
  if(!equalSum(rows.map(r=>r.garments),summary.garments)||rows.reduce((n,r)=>n+r.sourceEventCount,0)!==summary.sourceEventCount)throw Error('UP_SHIFT_RECONCILIATION');
  if(Math.max(...rows.map(r=>Date.parse(r.sourceMaxEventAt)))!==Date.parse(summary.sourceMaxEventAt))throw Error('UP_SHIFT_WATERMARK');
 }
 const maximum=payload.dailySummaries.length?Math.max(...payload.dailySummaries.map(r=>Date.parse(r.sourceMaxEventAt))):null;
 if((payload.sourceMaxEventAt===null?null:Date.parse(payload.sourceMaxEventAt))!==maximum)throw Error('UP_SHIFT_GLOBAL_WATERMARK');
 return payload;
}
