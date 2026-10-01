import React from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { expect, it } from "vitest";
import { buildUpPerformanceRows } from "../lib/up-performance-rows";

it("renders nine accessible aligned columns with fractional garments and missing shifts",async()=>{
  const module=await import("../app/production/performance/up-daily-performance-table").catch(()=>null);
  expect(module?.UpDailyPerformanceTable,"UP table is missing").toBeTypeOf("function");
  if(!module)return;
  const html=renderToStaticMarkup(<module.UpDailyPerformanceTable rows={buildUpPerformanceRows([{operational_date:"2026-10-01",garments:747.053}],[{operational_date:"2026-10-01",shift_code:"SHIFT_1",garments:747.053,status:"CURRENT",source_snapshot_id:"s"}],[],{})}/>);
  expect([...html.matchAll(/<th[^>]*scope="col"[^>]*>(.*?)<\/th>/g)].map(x=>x[1])).toEqual(["DATE","SHIFT","GARMENTS","CAPACITY","UTILISATION","PRODUCTIVE H","GARMENTS/H","OVERTIME H","NOTES"]);
  expect(html).toContain("747.053");
  expect(html).toContain('aria-label="UP daily performance table"');
  expect(html).toContain("—");
  expect(html).not.toContain("PARTIAL");
});
