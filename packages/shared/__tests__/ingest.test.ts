import {describe,expect,it} from "vitest";import {syncPayloadSchema} from "../src/ingest";
describe("ingest contract",()=>{it("preserves 18 digit IDs",()=>{const value=syncPayloadSchema.parse({
 organizationId:"00000000-0000-4000-8000-000000000001",agentId:"factory-1",connectorVersion:"0.1.0",orders:[],
 workbank:[],stock:[{product:"P",packId:"123456789012345678",location:"DTGS",sourceZone:null,sourceTimestamp:null,sourceQty:1,sourceWeight:2,productionUnits:2}],auditEvents:[]});
 expect(value.stock[0]?.packId).toBe("123456789012345678")})});
