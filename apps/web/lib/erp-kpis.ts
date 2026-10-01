import"server-only";
import{calculateKpis,type KpiGrain}from"@tsd/shared";
import{capacityDb}from"@/lib/capacity";
import{baseContext}from"@/lib/planning";
import{dtgGarmentsByDate,dtgPrintEvents,performanceEventsWithDailyDtg,type DtgDailyActualRow}from"@/lib/dtg-daily-actuals";

async function paged(make:any){const rows:any[]=[];for(let from=0;;from+=1000){const result=await make(from,from+999);if(result.error)throw result.error;const page=result.data??[];rows.push(...page);if(page.length<1000)break}return rows}

export async function erpKpis(grain:KpiGrain,from:string,to:string,shift="ALL"){
  const c=await baseContext(),d=capacityDb();
  const[allEvents,allLabour,rates,resources,sync,dtgResult]=await Promise.all([
    paged((start:number,end:number)=>d.from("production_events").select("event_id,event_ts_utc,operational_date,shift_code,metric,quantity,quality_status,source,source_mode,import_batch_id,created_at,calculation_version,is_partial_period").eq("organization_id",c.organizationId).gte("operational_date",from).lte("operational_date",to).order("event_ts_utc").range(start,end)),
    paged((start:number,end:number)=>d.from("v_current_labour_segments").select("person_key,area_code,operational_date,segment_end,shift_code,hour_bucket,paid_hours,regular_hours,overtime_hours,paid_break_hours,productive_hours,approval_status").eq("organization_id",c.organizationId).gte("operational_date",from).lte("operational_date",to).order("segment_start").range(start,end)),
    d.from("kpi_rate_rules").select("process,rate_per_hour,effective_from").eq("organization_id",c.organizationId).eq("active",true).lte("effective_from",to).order("effective_from",{ascending:false}),
    d.from("resource_capacity_rules").select("resource_code,shift_code,max_resources,effective_from").eq("organization_id",c.organizationId).eq("active",true).lte("effective_from",to).order("effective_from",{ascending:false}),
    d.from("v_latest_completed_batch").select("completed_at").eq("organization_id",c.organizationId).maybeSingle(),
    paged((start:number,end:number)=>d.from("production_daily_actuals").select("operational_date,machine_code,shift_code,garments,prints,source_max_event_at,refreshed_at").eq("organization_id",c.organizationId).eq("process","DTG").gte("operational_date",from).lte("operational_date",to).order("operational_date").order("id").range(start,end))
  ]);
  for(const x of[rates,resources,sync])if(x.error)throw x.error;const allDtgRows=dtgResult as DtgDailyActualRow[],dtgRows=shift==="ALL"?allDtgRows:allDtgRows.filter(x=>x.shift_code===shift),events=shift==="ALL"?allEvents:allEvents.filter((x:any)=>x.shift_code===shift),labour=shift==="ALL"?allLabour:allLabour.filter((x:any)=>x.shift_code===shift);
  const rateMap:Record<string,number>={},capMap:Record<string,number>={};
  for(const x of rates.data??[])if(rateMap[x.process]===undefined)rateMap[x.process]=Number(x.rate_per_hour);
  for(const x of resources.data??[]){const key=String(x.resource_code),shift=String(x.shift_code??"");capMap[shift?`${key}|${shift}`:key]=Number(x.max_resources)}
  const legacyEvents=events.filter((x:any)=>x.metric!=="DTG_PRINT"),productionDates=[...new Set([...legacyEvents.map((x:any)=>x.operational_date),...dtgRows.map(x=>x.operational_date)].filter(Boolean))].sort(),labourDates=[...new Set(labour.map((x:any)=>x.operational_date).filter(Boolean))].sort(),aggregateLatestAt=dtgRows.map(x=>x.source_max_event_at).filter(Boolean).sort().at(-1)??null,eventLatestAt=legacyEvents.map((x:any)=>x.event_ts_utc).filter(Boolean).sort().at(-1)??null;
  const meta={sources:[...new Set([...legacyEvents.map((x:any)=>x.source),...(dtgRows.length?["ORACLE_ISIS_AUDIT_AGGREGATE"]:[])])],sourceModes:[...new Set([...legacyEvents.map((x:any)=>x.source_mode),...(dtgRows.length?["AGGREGATED"]:[])])],calculationVersions:[...new Set([...legacyEvents.map((x:any)=>x.calculation_version),...(dtgRows.length?["DTG_PCOR_SHIFT_V2"]:[])])],importBatchIds:[...new Set(legacyEvents.map((x:any)=>x.import_batch_id).filter(Boolean))],updatedAt:[...legacyEvents.map((x:any)=>x.created_at),...dtgRows.map(x=>x.refreshed_at)].filter(Boolean).sort().at(-1)??null,productionLatestAt:[eventLatestAt,aggregateLatestAt].filter(Boolean).sort().at(-1)??null,labourLatestAt:labour.map((x:any)=>x.segment_end).filter(Boolean).sort().at(-1)??null,productionLatestDate:productionDates.at(-1)??null,labourLatestDate:labourDates.at(-1)??null,oracleLatestAt:sync.data?.completed_at??null,productionDates,labourDates,dataStatus:legacyEvents.length||labour.length||dtgRows.length?labour.some((x:any)=>x.approval_status==="PROVISIONAL")?"PROVISIONAL":"COMPLETE":"MISSING_SOURCE",isPartialPeriod:legacyEvents.some((x:any)=>x.is_partial_period)};
  const allKpiLabour=allLabour.map((x:any)=>({personKey:x.person_key,area:x.area_code,operationalDate:x.operational_date,shift:x.shift_code,hour:Number(x.hour_bucket),paidHours:Number(x.paid_hours),regularHours:Number(x.regular_hours),overtimeHours:Number(x.overtime_hours),paidBreakHours:Number(x.paid_break_hours),productiveHours:Number(x.productive_hours),approval:x.approval_status})),kpiLabour=shift==="ALL"?allKpiLabour:allKpiLabour.filter(x=>x.shift===shift),config={rates:rateMap,resourceCaps:capMap};
  const rows=calculateKpis(performanceEventsWithDailyDtg(events,dtgRows),kpiLabour,grain,config),garments=dtgGarmentsByDate(dtgRows);
  const dtgShiftRows=grain==="DAY"?calculateKpis(dtgPrintEvents(dtgRows),kpiLabour.filter(x=>x.area==="DTG_OPERATOR"),"SHIFT",config):[];
  return{context:c,meta,rows:rows.map(row=>({...row,dtgGarments:grain==="DAY"?garments.get(row.key)??null:null})),dtgShiftRows,dailyFlowInputs:{dtg:allDtgRows,labour:allLabour},upPerformanceInputs:{labour:allKpiLabour,config}}
}
