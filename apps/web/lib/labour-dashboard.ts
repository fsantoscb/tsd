import "server-only";
import { capacityDb } from "@/lib/capacity";
import { baseContext } from "@/lib/planning";

async function paged(make: any) {
  const rows: any[] = [];
  for (let from = 0; ; from += 1000) {
    const result = await make(from, from + 999);
    if (result.error) throw result.error;
    const page = result.data ?? [];
    rows.push(...page);
    if (page.length < 1000) break;
  }
  return rows;
}

const outputMetric: Record<string, string> = {
  DTG_OPERATOR: "DTG_PRINT",
  UP_OPERATOR: "UP_OUT",
  SCREEN_PRINT_CREW: "SCREEN_PRINT",
  SHARED_DISPATCH: "DTG_PUTWALL_OUT",
};

export async function labourBreakdown(from: string, to: string) {
  const c = await baseContext();
  const d = capacityDb();
  const [data, events] = await Promise.all([
    paged((start: number, end: number) => d.from("v_current_labour_segments")
      .select("area_code,shift_code,person_key,paid_hours,productive_hours,regular_hours,overtime_hours,paid_break_hours,approval_status")
      .eq("organization_id", c.organizationId).gte("operational_date", from).lte("operational_date", to).order("segment_start").range(start, end)),
    paged((start: number, end: number) => d.from("production_events")
      .select("metric,quantity").eq("organization_id", c.organizationId).gte("operational_date", from).lte("operational_date", to)
      .in("metric", Object.values(outputMetric)).range(start, end)),
  ]);
  const output = new Map<string, number>();
  for (const event of events) output.set(event.metric, (output.get(event.metric) ?? 0) + Number(event.quantity));
  const map = new Map<string, { area: string; shift: string; people: Set<string>; paid: number; productive: number; regular: number; overtime: number; breaks: number; provisional: boolean }>();
  for (const x of data) {
    if (x.approval_status === "INCOMPLETE") continue;
    const key = `${x.area_code}|${x.shift_code}`;
    const r = map.get(key) ?? { area: x.area_code, shift: x.shift_code, people: new Set<string>(), paid: 0, productive: 0, regular: 0, overtime: 0, breaks: 0, provisional: false };
    r.people.add(x.person_key); r.paid += Number(x.paid_hours); r.productive += Number(x.productive_hours); r.regular += Number(x.regular_hours); r.overtime += Number(x.overtime_hours); r.breaks += Number(x.paid_break_hours); r.provisional ||= x.approval_status === "PROVISIONAL"; map.set(key, r);
  }
  const areaProductive = new Map<string, number>();
  for (const r of map.values()) areaProductive.set(r.area, (areaProductive.get(r.area) ?? 0) + r.productive);
  return [...map.values()].map(x => {
    const metric = outputMetric[x.area];
    const areaOutput = metric ? output.get(metric) ?? null : null;
    const productive = areaProductive.get(x.area) ?? 0;
    return { ...x, headcount: x.people.size, people: undefined, output: areaOutput, productivity: areaOutput !== null && productive > 0 ? areaOutput / productive : null };
  }).sort((a, b) => a.area.localeCompare(b.area) || a.shift.localeCompare(b.shift));
}

export async function labourDrilldown(from:string,to:string,area:string){
  const c=await baseContext(),d=capacityDb();
  const segments=await paged((start:number,end:number)=>d.from("v_current_labour_segments").select("source_timesheet_row_id,person_key,area_code,operational_date,shift_code,paid_hours,productive_hours,regular_hours,overtime_hours,approval_status").eq("organization_id",c.organizationId).eq("area_code",area).gte("operational_date",from).lte("operational_date",to).order("operational_date").range(start,end));
  const ids=[...new Set(segments.map(x=>x.source_timesheet_row_id))],names=new Map<string,string>();
  for(let i=0;i<ids.length;i+=500){const result=await d.from("deputy_raw_timesheets").select("id,display_name").in("id",ids.slice(i,i+500));if(result.error)throw result.error;for(const row of result.data??[])names.set(row.id,row.display_name??"Unknown")}
  const grouped=new Map<string,{date:string;shift:string;person:string;paid:number;productive:number;regular:number;overtime:number;approval:string}>();
  for(const x of segments){const key=`${x.source_timesheet_row_id}|${x.operational_date}|${x.shift_code}`,r=grouped.get(key)??{date:x.operational_date,shift:x.shift_code,person:names.get(x.source_timesheet_row_id)??x.person_key,paid:0,productive:0,regular:0,overtime:0,approval:x.approval_status};r.paid+=Number(x.paid_hours);r.productive+=Number(x.productive_hours);r.regular+=Number(x.regular_hours);r.overtime+=Number(x.overtime_hours);grouped.set(key,r)}
  return[...grouped.values()];
}
