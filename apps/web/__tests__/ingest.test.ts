import {afterEach,describe,expect,it,vi} from "vitest";
const rpc=vi.fn(async()=>({data:"batch-1",error:null}));
vi.mock("@supabase/supabase-js",()=>({createClient:()=>({rpc})}));
import {authorizeIngest,ingest,readJson} from "../lib/ingest";

describe("ingest security",()=>{const secret="s".repeat(32);
 afterEach(()=>{rpc.mockClear();delete process.env.ORGANIZATION_ID;delete process.env.NEXT_PUBLIC_SUPABASE_URL;delete process.env.SUPABASE_SERVICE_ROLE_KEY});
 it("requires exact bearer secret",()=>{expect(authorizeIngest(`Bearer ${secret}`,secret)).toBe(true);expect(authorizeIngest("Bearer bad",secret)).toBe(false)});
 it("rejects payloads larger than the 200 MB ingestion limit",async()=>{const request=new Request("http://local",{method:"POST",headers:{"content-length":String(201*1024*1024)},body:"{}"});await expect(readJson(request)).rejects.toThrow("PAYLOAD_TOO_LARGE")});
 it("passes the active connector shape to the database with default auditEvents and unchanged sourcePackdesc",async()=>{const organizationId="00000000-0000-4000-8000-000000000001";process.env.ORGANIZATION_ID=organizationId;process.env.NEXT_PUBLIC_SUPABASE_URL="https://example.supabase.co";process.env.SUPABASE_SERVICE_ROLE_KEY="test-key";const item={sourceRowId:"row-1",orderNo:"1301",customerCode:null,customerName:null,sourceDueAt:null,fromLocation:"A",fromZone:"PG02",toLocation:null,fromPackId:null,toPackId:null,sourcePriority:null,productCode:null,productDescription:null,productGroup:null,sourceQty:1,sourceWeight:24,sourcePackdesc:"CARTON",productionUnits:1,printsPerGarment:null,queue:"Q",task:null};await ingest({organizationId,agentId:"factory-1",connectorVersion:"0.2.0",orders:[],releaseOrderLines:[],workbank:[item],stock:[]});expect(rpc).toHaveBeenCalledWith("ingest_sync_batch",{payload:expect.objectContaining({auditEvents:[],workbank:[item]})})});
});
