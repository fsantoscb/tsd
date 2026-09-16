import "server-only";
import {capacityDb} from "@/lib/capacity";
import {baseContext} from "@/lib/planning";
import {applyShipTo} from "@/lib/ship-to";

export async function holdOrders(){
  const context=await baseContext(),db=capacityDb(),rows:any[]=[];
  for(let from=0;;from+=1000){const{data,error}=await db.from("v_current_workbank").select("order_no,to_location,from_location,queue,production_units,source_due_at,source_priority").eq("organization_id",context.organizationId).ilike("queue","HOLD").like("order_no","130%").range(from,from+999);if(error)throw error;rows.push(...(data??[]));if((data??[]).length<1000)break}
  const enriched=await applyShipTo(rows,db),grouped=new Map<string,any>();
  for(const row of enriched){const key=String(row.order_no),item=grouped.get(key)??{order_no:key,ship_to_name:row.ship_to_name??row.customer_name??"",hold_reason:"Oracle HOLD queue",locations:new Set<string>(),remaining_units:0,due_at:row.source_due_at??null,priority:row.source_priority??null};const location=String(row.to_location??row.from_location??"").trim();if(location)item.locations.add(location);item.remaining_units+=Math.max(0,Number(row.production_units)||0);if(!item.due_at&&row.source_due_at)item.due_at=row.source_due_at;if(item.priority==null&&row.source_priority!=null)item.priority=row.source_priority;grouped.set(key,item)}
  return[...grouped.values()].map(x=>({...x,current_location:[...x.locations].sort().join(", "),age_on_hold:null})).sort((a,b)=>Number(a.priority??999)-Number(b.priority??999)||String(a.due_at??"9999").localeCompare(String(b.due_at??"9999"))||a.order_no.localeCompare(b.order_no,undefined,{numeric:true}));
}
