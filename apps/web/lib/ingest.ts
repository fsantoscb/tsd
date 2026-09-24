import { createClient } from "@supabase/supabase-js";
import { heartbeatSchema, syncPayloadSchema } from "@tsd/shared";
import { gunzipSync } from "node:zlib";

const MAX_BYTES=200*1024*1024;
export function authorizeIngest(header:string|null,secret:string|undefined){
  return Boolean(secret&&secret.length>=32&&header===`Bearer ${secret}`);
}
export async function readJson(request:Request){
  const length=Number(request.headers.get("content-length")??0);
  if(length>MAX_BYTES) throw new Error("PAYLOAD_TOO_LARGE");
  const received=Buffer.from(await request.arrayBuffer());
  const decoded=request.headers.get("content-encoding")==="gzip"?gunzipSync(received):received;
  if(decoded.byteLength>MAX_BYTES) throw new Error("PAYLOAD_TOO_LARGE");
  const text=decoded.toString("utf8");
  return JSON.parse(text) as unknown;
}
function admin(){
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url||!key) throw new Error("Server ingestion environment is not configured");
  return createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
}
async function assertConfiguredOrganization(organizationId:string){
  const configured=process.env.ORGANIZATION_ID?.trim()||await resolveSingleOrganizationId();
  if(organizationId!==configured)throw new Error("ORGANIZATION_MISMATCH");
}
export async function ingest(value:unknown){
  const payload=syncPayloadSchema.parse(value);
  await assertConfiguredOrganization(payload.organizationId);
  const {data,error}=await admin().rpc("ingest_sync_batch",{payload});
  if(error) throw new Error(error.message); return data as string;
}
export async function ingestAuditBackfill(value:any){
  const organizationId=String(value?.organizationId??""),events=Array.isArray(value?.events)?value.events:[];
  if(!/^[0-9a-f-]{36}$/i.test(organizationId)||events.length>1000)throw new Error("INVALID_BACKFILL_PAYLOAD");
  await assertConfiguredOrganization(organizationId);
  const{data,error}=await admin().rpc("ingest_audit_backfill",{p_organization_id:organizationId,p_events:events,p_rebuild:Boolean(value?.rebuild)});
  if(error)throw new Error(error.message);
  return{accepted:events.length,rebuilt:value?.rebuild?data:null}
}
export async function ingestDtgOrderHistory(value:any){
  const organizationId=String(value?.organizationId??"");
  const orderNos=Array.isArray(value?.orderNos)?value.orderNos.map(String):[];
  const rows=Array.isArray(value?.rows)?value.rows:[];
  if(!/^[0-9a-f-]{36}$/i.test(organizationId)||orderNos.length>5000||rows.length!==orderNos.length)throw new Error("INVALID_DTG_ORDER_HISTORY_PAYLOAD");
  await assertConfiguredOrganization(organizationId);
  const allowed=new Set(orderNos);
  const records=rows.map((row:any)=>{
    const orderNo=String(row?.orderNo??"");
    if(!orderNo||!allowed.has(orderNo))throw new Error("INVALID_DTG_ORDER_HISTORY_ORDER");
    return{organization_id:organizationId,order_no:orderNo,printed_garments:Number(row.printedGarments??0),printed_prints:Number(row.printedPrints??0),first_pick:row.firstPick??null,first_print:row.firstPrint??null,last_print:row.lastPrint??null,source_max_audit_id:row.sourceMaxAuditId??null,refreshed_at:new Date().toISOString()};
  });
  if(!records.length)return{accepted:0};
  const{error}=await admin().from("dtg_order_history_summaries").upsert(records,{onConflict:"organization_id,order_no"});
  if(error)throw new Error(error.message);
  return{accepted:records.length};
}
export async function readDtgShiftRules(organizationId:string){
  if(!/^[0-9a-f-]{36}$/i.test(organizationId))throw new Error("INVALID_ORGANIZATION");
  await assertConfiguredOrganization(organizationId);
  const{data,error}=await admin().from("shift_rules")
    .select("weekday,shift_code,display_name,start_time,end_time,cross_midnight,effective_from,effective_to")
    .eq("organization_id",organizationId).eq("active",true)
    .order("effective_from",{ascending:false}).order("weekday").order("shift_code");
  if(error)throw new Error(error.message);
  return{rules:(data??[]).map(row=>({
    weekday:Number(row.weekday),shiftCode:row.shift_code,displayName:row.display_name,
    startTime:row.start_time,endTime:row.end_time,crossMidnight:Boolean(row.cross_midnight),
    effectiveFrom:row.effective_from,effectiveTo:row.effective_to,
  }))};
}
export async function ingestDtgDailyActuals(value:any){
  const organizationId=String(value?.organizationId??""),from=String(value?.from??""),to=String(value?.to??"");
  const rows=Array.isArray(value?.rows)?value.rows:[];
  if(!/^[0-9a-f-]{36}$/i.test(organizationId)||!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(from)||!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(to)||from>to||rows.length>10000)throw new Error("INVALID_DTG_DAILY_PAYLOAD");
  await assertConfiguredOrganization(organizationId);
  const{data,error}=await admin().rpc("replace_dtg_daily_actuals",{p_organization_id:organizationId,p_from:from,p_to:to,p_rows:rows});
  if(error)throw new Error(error.message);
  return{accepted:Number(data??0)};
}
export async function ingestUpDailyActuals(value:any){
  const organizationId=String(value?.organizationId??""),from=String(value?.from??""),to=String(value?.to??"");
  const rows=Array.isArray(value?.rows)?value.rows:[];
  if(!/^[0-9a-f-]{36}$/i.test(organizationId)||!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(from)||!/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/.test(to)||from>to||rows.length>1000)throw new Error("INVALID_UP_DAILY_PAYLOAD");
  await assertConfiguredOrganization(organizationId);
  const{data,error}=await admin().rpc("replace_up_daily_actuals",{p_organization_id:organizationId,p_from:from,p_to:to,p_rows:rows});
  if(error)throw new Error(error.message);
  return{accepted:Number(data??0)};
}
export async function heartbeat(value:unknown){
  const payload=heartbeatSchema.parse(value);
  await assertConfiguredOrganization(payload.organizationId);
  const {error}=await admin().from("sync_agent_heartbeat").upsert({
   organization_id:payload.organizationId,agent_id:payload.agentId,last_seen_at:new Date().toISOString(),
   version:payload.version,hostname:payload.hostname,status:payload.status,last_error:payload.lastError,
   last_sync_attempt_at:payload.lastSyncAttemptAt,last_success_at:payload.lastSuccessAt,next_expected_sync_at:payload.nextExpectedSyncAt,current_run_id:payload.currentRunId,
  }); if(error) throw new Error(error.message);
}
export async function control(value:any){const action=String(value?.action??"");if(action==="claim"){await assertConfiguredOrganization(String(value.organizationId));const{data,error}=await admin().rpc("claim_sync_work",{p_organization_id:value.organizationId,p_agent_id:String(value.agentId),p_connector_version:String(value.connectorVersion),p_interval_seconds:Number(value.intervalSeconds)});if(error)throw new Error(error.message);const x=data?.[0];return x?{runId:x.run_id,requestId:x.request_id,triggerType:x.trigger_type,shouldExecute:x.should_execute}:null}if(action==="finish"){const{error}=await admin().rpc("finish_sync_work",{p_run_id:value.runId,p_status:value.status,p_batch_id:value.batchId??null,p_duration_ms:Number(value.durationMs),p_orders:Number(value.orders),p_workbank:Number(value.workbank),p_stock:Number(value.stock),p_audit:Number(value.audit),p_failure:value.failureReason??null});if(error)throw new Error(error.message);return{ok:true}}throw new Error("INVALID_CONTROL_ACTION")}
export async function resolveSingleOrganizationId(){
  const {data,error}=await admin().from("organizations").select("id").limit(2);
  if(error) throw error;
  if(data.length!==1) throw new Error("Expected exactly one organization");
  return data[0].id as string;
}
