import {afterEach,describe,expect,it,vi} from "vitest";
const state=vi.hoisted(()=>({
 rpc:vi.fn(async()=>({data:"batch-1",error:null})),
 history:new Map<string,Record<string,unknown>>(),
}));
vi.mock("@supabase/supabase-js",()=>({createClient:()=>({
 rpc:state.rpc,
 from:(table:string)=>({
  upsert:async(records:Record<string,unknown>[],options:{onConflict:string})=>{
   if(table!=="dtg_order_history_summaries"||options.onConflict!=="organization_id,order_no")return{error:new Error("Unexpected upsert")};
   for(const record of records)state.history.set(`${record.organization_id}:${record.order_no}`,record);
   return{error:null};
  },
 }),
})}));
import {authorizeIngest,ingest,ingestDtgOrderHistory,readJson} from "../lib/ingest";
import {POST as postDtgOrderHistory} from "../app/api/ingest/dtg-order-history/route";

const organizationId="00000000-0000-4000-8000-000000000001";
const secret="s".repeat(32);
const historyPayload=(printedGarments=4)=>({organizationId,orderNos:["1301"],rows:[{orderNo:"1301",printedGarments,printedPrints:8,firstPick:"2026-09-24T00:00:00.000Z",firstPrint:"2026-09-24T01:00:00.000Z",lastPrint:"2026-09-24T02:00:00.000Z",sourceMaxAuditId:"12832931"}]});

describe("ingest security",()=>{
 afterEach(()=>{state.rpc.mockClear();state.history.clear();delete process.env.ORGANIZATION_ID;delete process.env.NEXT_PUBLIC_SUPABASE_URL;delete process.env.SUPABASE_SERVICE_ROLE_KEY;delete process.env.INGEST_SECRET});
 it("requires exact bearer secret",()=>{expect(authorizeIngest(`Bearer ${secret}`,secret)).toBe(true);expect(authorizeIngest("Bearer bad",secret)).toBe(false)});
 it("rejects payloads larger than the 200 MB ingestion limit",async()=>{const request=new Request("http://local",{method:"POST",headers:{"content-length":String(201*1024*1024)},body:"{}"});await expect(readJson(request)).rejects.toThrow("PAYLOAD_TOO_LARGE")});
 it("passes the active connector shape to the database with default auditEvents and unchanged sourcePackdesc",async()=>{process.env.ORGANIZATION_ID=organizationId;process.env.NEXT_PUBLIC_SUPABASE_URL="https://example.supabase.co";process.env.SUPABASE_SERVICE_ROLE_KEY="test-key";const item={sourceRowId:"row-1",orderNo:"1301",customerCode:null,customerName:null,sourceDueAt:null,fromLocation:"A",fromZone:"PG02",toLocation:null,fromPackId:null,toPackId:null,sourcePriority:null,productCode:null,productDescription:null,productGroup:null,sourceQty:1,sourceWeight:24,sourcePackdesc:"CARTON",productionUnits:1,printsPerGarment:null,queue:"Q",task:null};await ingest({organizationId,agentId:"factory-1",connectorVersion:"0.2.0",orders:[],releaseOrderLines:[],workbank:[item],stock:[]});expect(state.rpc).toHaveBeenCalledWith("ingest_sync_batch",{payload:expect.objectContaining({auditEvents:[],workbank:[item]})})});
});

describe("DTG order history ingestion",()=>{
 afterEach(()=>{state.history.clear();delete process.env.ORGANIZATION_ID;delete process.env.NEXT_PUBLIC_SUPABASE_URL;delete process.env.SUPABASE_SERVICE_ROLE_KEY;delete process.env.INGEST_SECRET});
 function configure(){process.env.ORGANIZATION_ID=organizationId;process.env.NEXT_PUBLIC_SUPABASE_URL="https://example.supabase.co";process.env.SUPABASE_SERVICE_ROLE_KEY="test-key";process.env.INGEST_SECRET=secret}
 it("rejects missing and invalid endpoint authentication",async()=>{configure();for(const authorization of [undefined,"Bearer invalid"]){const headers=authorization?{authorization}:undefined;const response=await postDtgOrderHistory(new Request("http://local/api/ingest/dtg-order-history",{method:"POST",headers,body:JSON.stringify(historyPayload())}));expect(response.status).toBe(401);expect(await response.json()).toEqual({error:"Unauthorized"})}});
 it("rejects an organization mismatch",async()=>{configure();const payload={...historyPayload(),organizationId:"00000000-0000-4000-8000-000000000002"};const response=await postDtgOrderHistory(new Request("http://local/api/ingest/dtg-order-history",{method:"POST",headers:{authorization:`Bearer ${secret}`},body:JSON.stringify(payload)}));expect(response.status).toBe(400);expect(await response.json()).toEqual({error:"ORGANIZATION_MISMATCH"})});
 it("rejects rows outside the declared order set",async()=>{configure();const payload={...historyPayload(),rows:[{...historyPayload().rows[0],orderNo:"9999"}]};await expect(ingestDtgOrderHistory(payload)).rejects.toThrow("INVALID_DTG_ORDER_HISTORY_ORDER")});
 it("accepts the proven payload and returns the accepted count",async()=>{configure();const response=await postDtgOrderHistory(new Request("http://local/api/ingest/dtg-order-history",{method:"POST",headers:{authorization:`Bearer ${secret}`},body:JSON.stringify(historyPayload())}));expect(response.status).toBe(200);expect(await response.json()).toEqual({accepted:1});expect(state.history.size).toBe(1)});
 it("upserts repeated payloads by organization and order without duplicates",async()=>{configure();expect(await ingestDtgOrderHistory(historyPayload(4))).toEqual({accepted:1});expect(await ingestDtgOrderHistory(historyPayload(7))).toEqual({accepted:1});expect(state.history.size).toBe(1);expect(state.history.get(`${organizationId}:1301`)).toMatchObject({organization_id:organizationId,order_no:"1301",printed_garments:7,printed_prints:8,source_max_audit_id:"12832931"})});
});
