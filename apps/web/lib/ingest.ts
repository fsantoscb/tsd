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
  if(error) throw new Error(error.message);
  const staged=await admin().rpc("stage_workbank_demand_lines",{p_organization_id:payload.organizationId});
  if(staged.error)throw new Error(staged.error.message);
  return data as string;
}
export async function ingestAuditBackfill(value:any){
  const organizationId=String(value?.organizationId??""),events=Array.isArray(value?.events)?value.events:[];
  if(!/^[0-9a-f-]{36}$/i.test(organizationId)||events.length>1000)throw new Error("INVALID_BACKFILL_PAYLOAD");
  await assertConfiguredOrganization(organizationId);
  const{data,error}=await admin().rpc("ingest_audit_backfill",{p_organization_id:organizationId,p_events:events,p_rebuild:Boolean(value?.rebuild)});
  if(error)throw new Error(error.message);
  return{accepted:events.length,rebuilt:value?.rebuild?data:null}
}
export async function heartbeat(value:unknown){
  const payload=heartbeatSchema.parse(value);
  await assertConfiguredOrganization(payload.organizationId);
  const {error}=await admin().from("sync_agent_heartbeat").upsert({
   organization_id:payload.organizationId,agent_id:payload.agentId,last_seen_at:new Date().toISOString(),
   version:payload.version,hostname:payload.hostname,status:payload.status,last_error:payload.lastError,
  }); if(error) throw error;
}
export async function resolveSingleOrganizationId(){
  const {data,error}=await admin().from("organizations").select("id").limit(2);
  if(error) throw error;
  if(data.length!==1) throw new Error("Expected exactly one organization");
  return data[0].id as string;
}
