import {expect,it,vi} from "vitest";
import React from "react";
import {renderToStaticMarkup} from "react-dom/server";

vi.mock("@/components/app-shell",()=>({AppShell:({children}:{children:React.ReactNode})=>children}));
vi.mock("@/lib/deputy",()=>({deputyContext:async()=>({user:{email:"operator@example.com"},batches:[{id:"old",imported_at:"2026-09-28T00:00:00Z",filename:"old.xlsx",covered_from:"2026-09-14",covered_to:"2026-09-28",raw_rows:1,approved_rows:1,provisional_rows:0,quarantined_rows:0,status:"COMPLETED",snapshot_type:null,certified_at:null,certified_by:null}],exceptions:[]})}));
vi.mock("../app/production/deputy/actions",()=>({uploadDeputy:vi.fn()}));

it("shows optional snapshot fields, server-derived identity and an old unverified batch",async()=>{
  vi.stubGlobal("React",React);
  const {default:Page}=await import("../app/production/deputy/page");
  const html=renderToStaticMarkup(await Page({searchParams:Promise.resolve({})}));
  for(const name of ["snapshot_type","report_generated_at","coverage_start","coverage_end","certification_note"])
    expect(html).toContain(`name="${name}"`);
  expect(html).toContain("FULL — complete report");
  expect(html).toContain("PARTIAL — not eligible");
  expect(html).toMatch(/<input readOnly=""[^>]*value="operator@example.com"/);
  expect(html).not.toContain('name="certified_by"');
  expect(html).toContain("UNVERIFIED");
});
