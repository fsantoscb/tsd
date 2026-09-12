import {gzipSync} from "node:zlib";import {syncPayloadSchema,type SyncPayload} from "@tsd/shared";import type {ConnectorEnv} from "./types";
export interface SourceReader{read():Promise<Pick<SyncPayload,"orders"|"workbank"|"stock"|"auditEvents">>}
export async function syncOnce(env:ConnectorEnv,source:SourceReader,fetcher:typeof fetch=fetch){
 const payload=syncPayloadSchema.parse({organizationId:env.ORGANIZATION_ID,agentId:env.AGENT_ID,connectorVersion:env.CONNECTOR_VERSION,...await source.read()});
 const body=gzipSync(JSON.stringify({...payload,auditEvents:[]}));
 const response=await fetcher(env.INGEST_API_URL.replace(/\/$/,"")+"/sync",{method:"POST",headers:{"authorization":`Bearer ${env.INGEST_SECRET}`,"content-type":"application/json","content-encoding":"gzip"},body});
 if(!response.ok) throw new Error(`Ingestion failed with HTTP ${response.status}: ${await response.text()}`);
 const result=await response.json() as {batchId:string};
 for(let index=0;index<payload.auditEvents.length;index+=500){
  const events=payload.auditEvents.slice(index,index+500);
  const auditBody=gzipSync(JSON.stringify({organizationId:env.ORGANIZATION_ID,events,rebuild:false}));
  const auditResponse=await fetcher(env.INGEST_API_URL.replace(/\/$/,"")+"/audit-backfill",{method:"POST",headers:{"authorization":`Bearer ${env.INGEST_SECRET}`,"content-type":"application/json","content-encoding":"gzip"},body:auditBody});
  if(!auditResponse.ok) throw new Error(`Audit ingestion failed with HTTP ${auditResponse.status}: ${await auditResponse.text()}`);
 }
 const lastAuditId=payload.auditEvents.reduce((latest,event)=>{
  const candidate=event.sourceAuditId;
  return candidate!==null&&BigInt(candidate)>BigInt(latest)?candidate:latest;
 },env.AUDIT_AFTER_ID);
 return {...result,lastAuditId};
}
