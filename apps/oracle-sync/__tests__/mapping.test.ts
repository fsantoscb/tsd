import {describe,expect,it} from "vitest";import {mapAudit,mapStock,mapWorkbank} from "../src/mapping";
describe("Oracle mapping",()=>{
 it("keeps IDs as strings and uses QTY for non-carton rows",()=>{const x=mapWorkbank({WB_ROWID:"AA1",ONO:"O1",FROM_ZONE:"UP",FROM_PACK_ID:"123456789012345678",PACKDESC:"GARMENT",QTY:"12",WEIGHT:15,QUEUE:"Q"});expect(x.fromPackId).toBe("123456789012345678");expect(x.sourceQty).toBe(12);expect(x.sourceWeight).toBe(15);expect(x.productionUnits).toBe(12)});
 it("uses WEIGHT for carton rows",()=>{expect(mapWorkbank({WB_ROWID:"AA5",ONO:"O5",FROM_ZONE:"PG11",PACKDESC:"CARTON",QTY:1,WEIGHT:24,QUEUE:"Q"}).productionUnits).toBe(24)});
 it("counts every DTG line as one unit and maps prints",()=>{const x=mapWorkbank({WB_ROWID:"AA2",ONO:"O2",FROM_ZONE:"dtgs",QTY:"1",WEIGHT:100,PROD_X_5:"2",QUEUE:"Q"});expect(x.sourceWeight).toBe(100);expect(x.productionUnits).toBe(1);expect(x.printsPerGarment).toBe(2)});
 it("treats the legacy 1 / 2 print value as two",()=>{expect(mapWorkbank({WB_ROWID:"AA3",ONO:"O3",FROM_ZONE:"DTGS",QTY:1,WEIGHT:1,PROD_X_5:"1 / 2",QUEUE:"Q"}).printsPerGarment).toBe(2)});
 it("does not map prints for warehouse SP11 rows",()=>{const x=mapWorkbank({WB_ROWID:"AA4",ONO:"O4",FROM_ZONE:"PG11",QUEUE:"SP11",QTY:1,WEIGHT:1,PROD_X_5:"3"});expect(x.printsPerGarment).toBeNull()});
 it("maps stock zone without renaming weight",()=>{const x=mapStock({PRODUCT:"P",PACK_ID:"9",LOCATION:"L",ZONE:"PWL1",QTY:3,WEIGHT:null});expect(x).toMatchObject({sourceZone:"PWL1",sourceQty:3,sourceWeight:null,productionUnits:3})});
 it("creates a deterministic audit hash",()=>{const row={AUDIT_ID:1,ONO:"O",TIMESTAMP:new Date("2026-01-01Z")};expect(mapAudit(row).rawHash).toBe(mapAudit(row).rawHash)});
});
