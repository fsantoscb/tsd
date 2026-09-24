import {describe,expect,it} from "vitest";
import {syncPayloadSchema} from "../src/ingest";

const organizationId="00000000-0000-4000-8000-000000000001";
const workbank={sourceRowId:"row-1",orderNo:"1301",customerCode:null,customerName:null,sourceDueAt:null,fromLocation:"A",fromZone:"PG11",toLocation:null,fromPackId:null,toPackId:null,sourcePriority:null,productCode:null,productDescription:null,productGroup:null,sourceQty:1,sourceWeight:24,productionUnits:1,printsPerGarment:null,queue:"Q",task:null};
const activePayload=(overrides:Record<string,unknown>={})=>({organizationId,agentId:"factory-1",connectorVersion:"0.2.0",orders:[],releaseOrderLines:[],workbank:[workbank],stock:[],...overrides});

describe("ingest contract",()=>{
 it("accepts the active connector payload without auditEvents and defaults it empty",()=>{const value=syncPayloadSchema.parse(activePayload());expect(value.auditEvents).toEqual([]);expect(value).toMatchObject(activePayload())});
 it("preserves supplied auditEvents",()=>{const event={sourceAuditId:"audit-1",orderNo:"1301",username:null,fromZone:null,toZone:null,fromLocation:null,toLocation:null,product:null,fromPackId:null,toPackId:null,sourceQty:null,sourceWeight:null,productionUnits:1,eventAt:"2026-09-24T00:00:00.000Z",rawHash:"hash-1"};expect(syncPayloadSchema.parse(activePayload({auditEvents:[event]})).auditEvents).toEqual([event])});
 it("keeps existing Workbank payloads backward compatible",()=>{expect(syncPayloadSchema.parse(activePayload({auditEvents:[]})).workbank[0]).toEqual(workbank)});
 it.each(["DTGS","PG1H"])("keeps %s Workbank payloads compatible",fromZone=>{const item={...workbank,fromZone};expect(syncPayloadSchema.parse(activePayload({workbank:[item]})).workbank[0]).toEqual(item)});
 it("preserves a CARTON sourcePackdesc unchanged",()=>{const item={...workbank,sourcePackdesc:"CARTON"};expect(syncPayloadSchema.parse(activePayload({workbank:[item]})).workbank[0]).toEqual(item)});
 it("allows omitted and null sourcePackdesc",()=>{expect(syncPayloadSchema.parse(activePayload()).workbank[0]).toEqual(workbank);expect(syncPayloadSchema.parse(activePayload({workbank:[{...workbank,sourcePackdesc:null}]})).workbank[0]?.sourcePackdesc).toBeNull()});
 it("preserves existing Stock payload behavior",()=>{const stock={product:"P",packId:"123456789012345678",location:"DTGS",sourceZone:null,sourceTimestamp:null,sourceQty:1,sourceWeight:2,productionUnits:2};expect(syncPayloadSchema.parse(activePayload({stock:[stock]})).stock).toEqual([stock])});
 it.each(["organizationId","agentId","connectorVersion","orders","workbank","stock"])("keeps %s required",field=>{const payload=activePayload();delete (payload as Record<string,unknown>)[field];expect(()=>syncPayloadSchema.parse(payload)).toThrow()});
});
