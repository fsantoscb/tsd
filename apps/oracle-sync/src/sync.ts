import {gzipSync} from "node:zlib";import {syncPayloadSchema,type SyncPayload} from "@tsd/shared";import type {ConnectorEnv} from "./types";
export interface SourceReader{read():Promise<Pick<SyncPayload,"orders"|"releaseOrderLines"|"workbank"|"stock">>}
export async function syncOnce(env:ConnectorEnv,source:SourceReader,fetcher:typeof fetch=fetch){
 const payload=syncPayloadSchema.parse({organizationId:env.ORGANIZATION_ID,agentId:env.AGENT_ID,connectorVersion:env.CONNECTOR_VERSION,...await source.read()});
 const snapshot={organizationId:payload.organizationId,agentId:payload.agentId,connectorVersion:payload.connectorVersion,orders:payload.orders,releaseOrderLines:payload.releaseOrderLines,workbank:payload.workbank,stock:payload.stock};
 const body=gzipSync(JSON.stringify(snapshot));
 const response=await fetcher(env.INGEST_API_URL.replace(/\/$/,"")+"/sync",{method:"POST",headers:{"authorization":`Bearer ${env.INGEST_SECRET}`,"content-type":"application/json","content-encoding":"gzip"},body});
 if(!response.ok) throw new Error(`Ingestion failed with HTTP ${response.status}: ${await response.text()}`);
 const result=await response.json() as {batchId:string};
 return {...result,counts:{orders:payload.orders.length,releaseOrderLines:payload.releaseOrderLines.length,workbank:payload.workbank.length,stock:payload.stock.length,audit:0}};
}
