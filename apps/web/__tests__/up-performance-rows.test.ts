import { describe, expect, it } from "vitest";
import type { KpiLabour } from "@tsd/shared";
import { buildUpPerformanceRows } from "../lib/up-performance-rows";

const date = "2026-09-24";
const labour = (shift: string, hours: number, ot = 0, personKey = shift): KpiLabour => ({ personKey, area: "UP_OPERATOR", operationalDate: date, shift, hour: 10, paidHours: hours, regularHours: hours - ot, overtimeHours: ot, paidBreakHours: 0, productiveHours: hours, approval: "APPROVED" });
const daily = [{ operational_date: date, garments: 1907 }];
const shifts = [
  { operational_date: date, shift_code: "SHIFT_1", garments: 489, status: "CURRENT", source_snapshot_id: "snapshot" },
  { operational_date: date, shift_code: "SHIFT_2", garments: 1418, status: "CURRENT", source_snapshot_id: "snapshot" },
];

describe("UP canonical Performance composition", () => {
  it("orders dates descending TOTAL A B C, includes Labour-only dates and excludes empty dates", () => {
    const rows = buildUpPerformanceRows([...daily, {operational_date:"2026-09-23",garments:0}], shifts, [{...labour("SHIFT_1",1), operationalDate:"2026-09-25"}], {});
    expect(rows.map(row => [row.operationalDate,row.shift])).toEqual([...["TOTAL","A","B","C"].map(label=>["2026-09-25",label]),...["TOTAL","A","B","C"].map(label=>[date,label]),...["TOTAL","A","B","C"].map(label=>["2026-09-23",label])]);
    expect(rows[0].garments).toBeNull();
    expect(rows.at(-4)?.garments).toBe(0);
    expect(buildUpPerformanceRows([],[],[],{})).toEqual([]);
  });
  it("preserves daily authority even if shift totals differ and never manufactures a missing daily", () => {
    expect(buildUpPerformanceRows([{operational_date:date,garments:2000}],shifts,[],{})[0].garments).toBe(2000);
    expect(buildUpPerformanceRows([],shifts,[labour("SHIFT_1",1)],{})[0].garments).toBeNull();
  });
  it("preserves fractional output and the persisted cross-midnight operational date", () => {
    const rows=buildUpPerformanceRows([{operational_date:"2026-09-30",garments:1442.159}], [{...shifts[0],operational_date:"2026-09-30",shift_code:"SHIFT_3",garments:16}],[],{});
    expect(rows[0].garments).toBe(1442.159);
    expect(rows[3]).toMatchObject({operationalDate:"2026-09-30",shift:"C",garments:16});
    expect(rows[1].garments).toBeNull();
  });
  it("keeps current-day rows without manufacturing later shifts or PARTIAL notes", () => {
    const rows=buildUpPerformanceRows([{operational_date:"2026-10-01",garments:747.053}],[{...shifts[0],operational_date:"2026-10-01",garments:747.053}],[],{});
    expect(rows.map(row=>row.garments)).toEqual([747.053,747.053,null,null]);
    expect(rows.every(row=>row.notes==="")).toBe(true);
  });
  it("excludes non-CURRENT shift output without converting absence to zero", () => {
    expect(buildUpPerformanceRows(daily,[{...shifts[0],status:"STALE"}],[],{})[1].garments).toBeNull();
  });
  it("preserves out-of-shift output and Labour only on ALL TOTAL, without outside capacity", () => {
    const rows=buildUpPerformanceRows([{operational_date:date,garments:1912}], [...shifts,{...shifts[0],shift_code:"OUT_OF_SHIFT",garments:5}], [labour("SHIFT_1",2),labour("SHIFT_2",4,1),labour("OUT_OF_SHIFT",0.5,0.25)],{});
    expect(rows[0]).toMatchObject({garments:1912,productiveHours:6.5,overtimeHours:1.25,capacity:1275});
    expect(rows[0].notes).toBe("Includes OUT_OF_SHIFT: 5 garments / 0.5000 productive h / 0.2500 OT h");
    expect(rows.slice(1).map(row=>row.notes)).toEqual(["","",""]);
    expect(rows).toHaveLength(4);
  });
  it.each(["SHIFT_1","SHIFT_2","SHIFT_3"])("TOTAL summarizes only %s and leaves unselected rows absent", filter=>{
    const rows=buildUpPerformanceRows(daily,shifts,[labour("SHIFT_1",2),labour("SHIFT_2",4,1),labour("OUT_OF_SHIFT",1,1)],{},filter);
    const chosen=rows[Number(filter.at(-1))];
    for(const key of ["garments","productiveHours","overtimeHours","capacity"] as const)expect(rows[0][key]).toBe(chosen[key]);
    expect(rows[0].notes).toBe("");
    rows.slice(1).forEach((row,i)=>{if(filter!==`SHIFT_${i+1}`)expect(row).toMatchObject({garments:null,productiveHours:null,overtimeHours:null,capacity:null});});
  });
  it("uses existing resource caps, scheduled Friday hours and supplied rate, not output", () => {
    const people=Array.from({length:5},(_,i)=>({...labour("SHIFT_1",1,0,String(i)), operationalDate:"2026-09-25"}));
    const [total,a]=buildUpPerformanceRows([{operational_date:"2026-09-25",garments:10}],[],people,{rates:{UP:80},resourceCaps:{"UP_OPERATOR|SHIFT_1":3}});
    expect(a.capacity).toBe(1440);
    expect(total.capacity).toBe(1440);
    expect(total.garmentsPerHour).toBe(2);
    expect(total.utilisation).toBeCloseTo(10/1440);
  });
  it("keeps zero hours and missing capacity honest and ignores non-UP/INCOMPLETE Labour", () => {
    const rows=buildUpPerformanceRows(daily,shifts,[labour("SHIFT_1",0),{...labour("SHIFT_2",99),approval:"INCOMPLETE"},{...labour("SHIFT_3",99),area:"DTG_OPERATOR"}],{});
    expect(rows[1].productiveHours).toBe(0);
    expect(rows[1].garmentsPerHour).toBeNull();
    expect(rows[2].productiveHours).toBeNull();
    expect(rows[2].capacity).toBeNull();
    expect(rows[3].productiveHours).toBeNull();
  });
  it("uses persisted daily TOTAL and independent shift authority with engine capacity", async () => {
    const module = await import("../lib/up-performance-rows").catch(() => null);
    expect(module?.buildUpPerformanceRows, "UP row composition has not been implemented").toBeTypeOf("function");
    if (!module) return;
    const [total, a, b, c] = module.buildUpPerformanceRows(daily, shifts, [labour("SHIFT_1", 2), labour("SHIFT_2", 4, 1)], {});
    expect(total).toMatchObject({ garments: 1907, productiveHours: 6, overtimeHours: 1, capacity: 1275 });
    expect(a).toMatchObject({ garments: 489, productiveHours: 2, overtimeHours: 0, capacity: 637.5 });
    expect(b).toMatchObject({ garments: 1418, productiveHours: 4, overtimeHours: 1, capacity: 637.5 });
    expect(c).toMatchObject({ garments: null, capacity: null, productiveHours: null, overtimeHours: null });
    expect(total.garmentsPerHour).toBeCloseTo(1907 / 6);
    expect(total.utilisation).toBeCloseTo(1907 / 1275);
    expect(a.garmentsPerHour).toBe(244.5);
    expect(b.garmentsPerHour).toBe(354.5);
  });
});
