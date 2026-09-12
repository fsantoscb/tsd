import "server-only";
import {createClient}from"@supabase/supabase-js";

const PAGE=1000;
type EventRow={source_record_key:string;operational_date:string;shift_code:string};
type AuditRow={source_audit_id:string|null;raw_hash:string|null;source_weight:number|null;from_pack_id:string|null;to_pack_id:string|null;order_no:string|null};
export type UpProductivityRow={date:string;stream:"A"|"B"|"C"|"OTHER";shift:string;output:number;pid:number};
function db(){const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;if(!url||!key)throw Error("Supabase server environment missing");return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}})}
// eslint-disable-next-line no-unused-vars
async function pages<T>(load:(_from:number,_to:number)=>PromiseLike<{data:T[]|null;error:any}>){const rows:T[]=[];for(let from=0;;from+=PAGE){const{data,error}=await load(from,from+PAGE-1);if(error)throw error;const batch=data??[];rows.push(...batch);if(batch.length<PAGE)break}return rows}
function dateOffset(date:string,days:number){const value=new Date(`${date}T12:00:00Z`);value.setUTCDate(value.getUTCDate()+days);return value.toISOString().slice(0,10)}
function stream(shift:string):UpProductivityRow["stream"]{const value=shift.toUpperCase();return value==="SHIFT_1"?"A":value==="SHIFT_2"?"B":value==="SHIFT_3"?"C":"OTHER"}
export async function upOperatorProductivity(from:string,to:string){const client=db(),[events,audits]=await Promise.all([
 pages<EventRow>((start,end)=>client.from("production_events").select("source_record_key,operational_date,shift_code").eq("area","UP").eq("metric","UP_OUT").gte("operational_date",from).lte("operational_date",to).range(start,end)),
 pages<AuditRow>((start,end)=>client.from("source_audit_events").select("source_audit_id,raw_hash,source_weight,from_pack_id,to_pack_id,order_no").gte("event_at",`${dateOffset(from,-1)}T00:00:00+10:00`).lte("event_at",`${dateOffset(to,1)}T23:59:59.999+10:00`).ilike("from_location","%UNDERPRINT%").range(start,end))
 ]),auditByKey=new Map(audits.map(row=>[String(row.source_audit_id??row.raw_hash??""),row])),grouped=new Map<string,{date:string;stream:UpProductivityRow["stream"];shift:string;output:number;pids:Set<string>}>();
 for(const event of events){const audit=auditByKey.get(String(event.source_record_key));if(!audit)continue;const bucket=stream(String(event.shift_code)),key=`${event.operational_date}|${bucket}`,item=grouped.get(key)??{date:String(event.operational_date),stream:bucket,shift:String(event.shift_code),output:0,pids:new Set<string>()};item.output+=Number(audit.source_weight??0);item.pids.add(String(audit.from_pack_id??audit.to_pack_id??audit.order_no??event.source_record_key));grouped.set(key,item)}
 return [...grouped.values()].map<UpProductivityRow>(item=>({date:item.date,stream:item.stream,shift:item.shift,output:item.output,pid:item.pids.size})).sort((a,b)=>a.date.localeCompare(b.date)||a.stream.localeCompare(b.stream))}