import"server-only";
import{calculateKpis,type KpiGrain}from"@tsd/shared";
import{capacityDb}from"@/lib/capacity";
import{baseContext}from"@/lib/planning";

async function paged(make:any){const rows:any[]=[];for(let from=0;;from+=1000){const result=await make(from,from+999);if(result.error)throw result.error;const page=result.data??[];rows.push(...page);if(page.length<1000)break}return rows}

export async function erpKpis(grain:KpiGrain,from:string,to:string,shift="ALL"){
  const c=await baseContext(),d=capacityDb();
  const[allEvents,allLabour,rates,resources,sync]=await Promise.all([
    paged((start:number,end:number)=>d.from("production_events").select("event_id,event_ts_utc,operational_date,shift_code,metric,quantity,quality_status,source,source_mode,import_batch_id,created_at,calculation_version,is_partial_period").eq("organization_id",c.organizationId).gte("operational_date",from).lte("operational_date",to).order("event_ts_utc").range(start,end)),
    paged((start:number,end:number)=>d.from("v_current_labour_segments").select("person_key,area_code,operational_date,segment_end,shift_code,hour_bucket,paid_hours,regular_hours,overtime_hours,paid_break_hours,productive_hours,approval_status").eq("organization_id",c.organizationId).gte("operational_date",from).lte("operational_date",to).order("segment_start").range(start,end)),
    d.from("kpi_rate_rules").select("process,rate_per_hour,effective_from").eq("organization_id",c.organizationId).eq("active",true).lte("effective_from",to).order("effective_from",{ascending:false}),
    d.from("resource_capacity_rules").select("resource_code,shift_code,max_resources,effective_from").eq("organization_id",c.organizationId).eq("active",true).lte("effective_from",to).order("effective_from",{ascending:false}),
    d.from("v_latest_completed_batch").select("completed_at").eq("organization_id",c.organizationId).maybeSingle()
  ]);
  for(const x of[rates,resources,sync])if(x.error)throw x.error;const events=shift==="ALL"?allEvents:allEvents.filter((x:any)=>x.shift_code===shift),labour=shift==="ALL"?allLabour:allLabour.filter((x:any)=>x.shift_code===shift);
  const rateMap:Record<string,number>={},capMap:Record<string,number>={};
  for(const x of rates.data??[])if(rateMap[x.process]===undefined)rateMap[x.process]=Number(x.rate_per_hour);
  for(const x of resources.data??[]){const key=String(x.resource_code),shift=String(x.shift_code??"");capMap[shift?`${key}|${shift}`:key]=Number(x.max_resources)}
  const productionDates=[...new Set(events.map((x:any)=>x.operational_date).filter(Boolean))].sort(),labourDates=[...new Set(labour.map((x:any)=>x.operational_date).filter(Boolean))].sort();
  const meta={sources:[...new Set(events.map((x:any)=>x.source))],sourceModes:[...new Set(events.map((x:any)=>x.source_mode))],calculationVersions:[...new Set(events.map((x:any)=>x.calculation_version))],importBatchIds:[...new Set(events.map((x:any)=>x.import_batch_id).filter(Boolean))],updatedAt:events.map((x:any)=>x.created_at).filter(Boolean).sort().at(-1)??null,productionLatestAt:events.map((x:any)=>x.event_ts_utc).filter(Boolean).sort().at(-1)??null,labourLatestAt:labour.map((x:any)=>x.segment_end).filter(Boolean).sort().at(-1)??null,productionLatestDate:productionDates.at(-1)??null,labourLatestDate:labourDates.at(-1)??null,oracleLatestAt:sync.data?.completed_at??null,productionDates,labourDates,dataStatus:events.length||labour.length?labour.some((x:any)=>x.approval_status==="PROVISIONAL")?"PROVISIONAL":"COMPLETE":"MISSING_SOURCE",isPartialPeriod:events.some((x:any)=>x.is_partial_period)};
  return{context:c,meta,rows:calculateKpis(events.map((x:any)=>({eventId:x.event_id,timestamp:x.event_ts_utc,operationalDate:x.operational_date,shift:x.shift_code,metric:x.metric,quantity:Number(x.quantity),quality:x.quality_status})),labour.map((x:any)=>({personKey:x.person_key,area:x.area_code,operationalDate:x.operational_date,shift:x.shift_code,hour:Number(x.hour_bucket),paidHours:Number(x.paid_hours),regularHours:Number(x.regular_hours),overtimeHours:Number(x.overtime_hours),paidBreakHours:Number(x.paid_break_hours),productiveHours:Number(x.productive_hours),approval:x.approval_status})),grain,{rates:rateMap,resourceCaps:capMap})}
}
