import{describe,expect,it}from"vitest";import{resolveRelease}from"../lib/release-queue-rules";
const base={routeId:"YES",costCentre:null,stopShipFlag:"N",dueDate:"2026-09-20T00:00:00.000Z",sourceStatus:"1",customEmbQty:0,totalProcessQty:10};const today=new Date("2026-09-17T00:00:00Z");
describe("release resolver",()=>{
 it("resolves eligible and ignores priority/too-fresh concepts",()=>expect(resolveRelease(base,today).status).toBe("ELIGIBLE"));
 it("keeps every blocker under not approved precedence",()=>expect(resolveRelease({...base,costCentre:"NotAppro",routeId:"NO",stopShipFlag:"Y",customEmbQty:2},today)).toEqual({status:"NOT_APPROVED",blockers:["ROUTE_BLOCKED","STOP_SHIP","CUSTOM_EMB"],diagnostic:null}));
 it("resolves each explicit blocker",()=>{expect(resolveRelease({...base,routeId:"NO"},today).status).toBe("BLOCKED");expect(resolveRelease({...base,stopShipFlag:"Y"},today).blockers).toContain("STOP_SHIP");expect(resolveRelease({...base,customEmbQty:1},today).blockers).toContain("CUSTOM_EMB")});
 it("resolves future due",()=>expect(resolveRelease({...base,dueDate:"2026-09-25T00:00:00Z"},today).status).toBe("FUTURE_DUE"));
 it("marks missing required evidence unknown",()=>expect(resolveRelease({...base,routeId:null},today).status).toBe("UNKNOWN"));
 it("retains zero production diagnostically",()=>expect(resolveRelease({...base,totalProcessQty:0},today).diagnostic).toBe("ZERO_PRODUCTION_QTY"));
});
