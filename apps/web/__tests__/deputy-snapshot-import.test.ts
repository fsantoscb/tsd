import {beforeEach,describe,expect,it,vi} from "vitest";
import * as XLSX from "xlsx";

vi.mock("server-only",()=>({}));
const state:{prior:boolean;batch?:Record<string,unknown>;raw?:Record<string,unknown>[];segments?:Record<string,unknown>[];updates:number}={prior:false,updates:0};
vi.mock("@/lib/capacity",()=>({capacityDb:()=>({from:(table:string)=>({
  select:()=>({eq:()=>({eq:()=>({maybeSingle:async()=>({data:state.prior?{id:"existing"}:null,error:null})})})}),
  insert:(value:unknown)=>{
    if(table==="deputy_import_batches"){
      state.batch=value as Record<string,unknown>;
      return {select:()=>({single:async()=>({data:{id:"new"},error:null})})};
    }
    if(table==="deputy_raw_timesheets")state.raw=value as Record<string,unknown>[];
    if(table==="labour_segments")state.segments=value as Record<string,unknown>[];
    return Promise.resolve({error:null});
  },
  update:()=>{state.updates++;return {eq:async()=>({error:null})}},
})})}));
vi.mock("@/lib/planning",()=>({baseContext:()=>{throw new Error("Unexpected interactive context")}}));
vi.mock("@/lib/deputy-import",async()=>await import("../lib/deputy-import"));
import {importDeputy} from "../lib/deputy";

const actor={organizationId:"00000000-0000-0000-0000-000000000002",email:"operator@example.com"};
const file=(date="29/09/2026")=>{
  const book=XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book,XLSX.utils.json_to_sheet([{"Timesheet Date":date,"Employee ID":"1","Display Name":"Alex","Area Name":"DTG","Start":"06:00","End":"14:00","Total Hours":8,"Approved":"Yes"}]),"Data");
  return new File([XLSX.write(book,{type:"buffer",bookType:"xlsx"})],"new-report.xlsx");
};
const metadata=(overrides:Record<string,string>={})=>{
  const f=new FormData();
  for(const [k,v] of Object.entries({snapshot_type:"FULL",report_generated_at:"2026-09-29T15:02:00+10:00",coverage_start:"2026-09-15",coverage_end:"2026-09-29",certification_note:"Full export confirmed",...overrides}))f.set(k,v);
  return f;
};

describe("Deputy snapshot import",()=>{
  beforeEach(()=>{state.prior=false;state.batch=undefined;state.raw=undefined;state.segments=undefined;state.updates=0});
  it("keeps a legacy import and all seven authority fields null",async()=>{
    await importDeputy(file(),"Australia/Brisbane",actor);
    expect(state.batch).toMatchObject({snapshot_type:null,report_generated_at:null,coverage_start:null,coverage_end:null,certified_at:null,certified_by:null,certification_note:null});
    expect(state.batch).not.toHaveProperty("imported_at");
  });
  it("stores explicit FULL metadata only on the batch and uses the authenticated actor",async()=>{
    await importDeputy(file(),"Australia/Brisbane",actor,metadata({certified_by:"forged@example.com"}));
    expect(state.batch).toMatchObject({snapshot_type:"FULL",report_generated_at:"2026-09-29T15:02:00+10:00",coverage_start:"2026-09-15",coverage_end:"2026-09-29",certified_by:actor.email,certification_note:"Full export confirmed"});
    expect(state.batch).not.toHaveProperty("imported_at");
    expect(state.raw?.[0]).not.toHaveProperty("snapshot_type");
    expect(state.segments?.[0]).not.toHaveProperty("snapshot_type");
  });
  it("accepts PARTIAL without labelling it FULL",async()=>{await importDeputy(file(),"Australia/Brisbane",actor,metadata({snapshot_type:"PARTIAL"}));expect(state.batch?.snapshot_type).toBe("PARTIAL")});
  it("rejects rows outside declared coverage before any write",async()=>{
    await expect(importDeputy(file(),"Australia/Brisbane",actor,metadata({coverage_end:"2026-09-28"}))).rejects.toThrow(/coverage/i);
    expect(state.batch).toBeUndefined();expect(state.updates).toBe(0);
  });
  it("does not require a row on every date within the declared coverage",async()=>{await importDeputy(file(),"Australia/Brisbane",actor,metadata());expect(state.batch?.coverage_start).toBe("2026-09-15")});
  it("permits historical dates beyond fourteen days",async()=>{await importDeputy(file("01/08/2026"),"Australia/Brisbane",actor,metadata({coverage_start:"2026-08-01",coverage_end:"2026-08-31"}));expect(state.batch?.coverage_start).toBe("2026-08-01")});
  it("preserves hash duplicate behavior without updating the prior batch",async()=>{
    state.prior=true;
    expect(await importDeputy(file(),"Australia/Brisbane",actor,metadata())).toBe(true);
    expect(state.batch).toBeUndefined();expect(state.updates).toBe(0);
  });
});
