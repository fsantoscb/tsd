import { expect, it, vi } from "vitest";

it("reads only CURRENT organization/date-bounded persisted shifts and propagates errors", async()=>{
  const module=await import("../lib/up-performance-reader").catch(()=>null);
  expect(module?.readUpPerformanceShifts,"bounded UP reader is missing").toBeTypeOf("function");
  if(!module)return;
  const calls: unknown[][]=[];
  const query={select:(...args:unknown[])=>{calls.push(["select",...args]);return query;},eq:(...args:unknown[])=>{calls.push(["eq",...args]);return query;},gte:(...args:unknown[])=>{calls.push(["gte",...args]);return query;},lte:(...args:unknown[])=>{calls.push(["lte",...args]);return query;},order:(...args:unknown[])=>{calls.push(["order",...args]);return query;},range:vi.fn(async()=>({data:[{operational_date:"2026-09-24",shift_code:"SHIFT_1",garments:489,status:"CURRENT",source_snapshot_id:"snapshot"}],error:null}))};
  const db={from:(name:string)=>{calls.push(["from",name]);return query;}};
  const rows=await module.readUpPerformanceShifts(db as never,"org","2026-09-23","2026-10-01");
  expect(rows[0].garments).toBe(489);
  expect(calls).toEqual([["from","up_shift_daily_actuals"],["select","operational_date,shift_code,garments,status,source_snapshot_id"],["eq","organization_id","org"],["eq","status","CURRENT"],["gte","operational_date","2026-09-23"],["lte","operational_date","2026-10-01"],["order","operational_date"],["order","shift_code"]]);
  expect(query.range).toHaveBeenCalledTimes(1);
  query.range.mockResolvedValueOnce({data:[],error:{message:"database unavailable"}} as never);
  await expect(module.readUpPerformanceShifts(db as never,"org","2026-09-23","2026-10-01")).rejects.toEqual({message:"database unavailable"});
  await expect(module.readUpPerformanceShifts(db as never,"org","2026-10-01","2026-09-23")).rejects.toThrow("INVALID_UP_PERFORMANCE_RANGE");
});
