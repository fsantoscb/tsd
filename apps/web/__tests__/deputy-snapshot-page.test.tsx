import {expect,it,vi} from "vitest";
import React from "react";
import {renderToStaticMarkup} from "react-dom/server";
import {readFileSync} from "node:fs";

vi.mock("@/components/app-shell",()=>({AppShell:({children}:{children:React.ReactNode})=>children}));
vi.mock("@/lib/deputy",()=>({deputyContext:async()=>({user:{email:"operator@example.com"},batches:[{id:"old",imported_at:"2026-09-28T00:00:00Z",filename:"old.xlsx",covered_from:"2026-09-14",covered_to:"2026-09-28",raw_rows:1,approved_rows:1,provisional_rows:0,quarantined_rows:0,status:"COMPLETED",snapshot_type:null,certified_at:null,certified_by:null}],exceptions:[]})}));
vi.mock("../app/production/deputy/actions",()=>({uploadDeputy:vi.fn()}));

it("starts with a file-first FULL import, date-only default, blank required time and collapsed Advanced",async()=>{
  vi.stubGlobal("React",React);
  const {default:Page}=await import("../app/production/deputy/page");
  const html=renderToStaticMarkup(await Page({searchParams:Promise.resolve({})}));
  expect(html).toContain('type="file"');
  expect(html).toContain('type="date"');
  expect(html).toMatch(/type="time"[^>]*required=""/);
  expect(html).toContain('value="FULL" selected=""');
  expect(html).toContain("Advanced snapshot settings");
  expect(html).toMatch(/<details[^>]*>/);
  expect(html).not.toMatch(/<details[^>]*open/);
  expect(html).toContain("Australia/Brisbane");
  expect(html).toContain("Detected report coverage");
  expect(html).toMatch(/<input readOnly=""[^>]*value="operator@example.com"/);
  expect(html).not.toContain('name="certified_by"');
  expect(html).toContain("UNVERIFIED");
});

it("keeps the form responsive without wide metadata columns",()=>{
  const css=readFileSync(new URL("../app/production/deputy/deputy.module.css",import.meta.url),"utf8");
  expect(css).toMatch(/minmax\(0,\s*1fr\)/);
  expect(css).toMatch(/@media\s*\(max-width:\s*700px\)/);
});
