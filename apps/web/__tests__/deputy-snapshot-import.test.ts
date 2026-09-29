import {beforeEach,describe,expect,it,vi} from "vitest";
import * as XLSX from "xlsx";

vi.mock("server-only",()=>({}));
const inserted:{batch?:Record<string,unknown>;raw?:Record<string,unknown>[];segments?:Record<string,unknown>[]}={};
vi.mock("@/lib/capacity",()=>({capacityDb:()=>({from:(table:string)=>({
  select:()=>({eq:()=>({eq:()=>({maybeSingle:async()=>({data:null,error:null})})})}),
  insert:(value:unknown)=>{
    if(table==="deputy_import_batches"){
      inserted.batch=value as Record<string,unknown>;
      return {select:()=>({single:async()=>({data:{id:"00000000-0000-0000-0000-000000000001"},error:null})})};
    }
    if(table==="deputy_raw_timesheets")inserted.raw=value as Record<string,unknown>[];
    if(table==="labour_segments")inserted.segments=value as Record<string,unknown>[];
    return Promise.resolve({error:null});
  },
  update:()=>({eq:async()=>({error:null})}),
})})}));
vi.mock("@/lib/planning",()=>({baseContext:()=>{throw new Error("Unexpected interactive context")}}));
vi.mock("@/lib/deputy-import",async()=>await import("../lib/deputy-import"));

import {importDeputy} from "../lib/deputy";

const file=()=>{
  const book=XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book,XLSX.utils.json_to_sheet([{
    "Timesheet Date":"29/09/2026","Employee ID":"1","Display Name":"Alex",
    "Area Name":"DTG","Start":"06:00","End":"14:00","Total Hours":8,"Approved":"Yes",
  }]),"Data");
  return new File([XLSX.write(book,{type:"buffer",bookType:"xlsx"})],"timesheets.xlsx");
};
const actor={organizationId:"00000000-0000-0000-0000-000000000002",email:"operator@tsd.example"};

describe("Deputy batch insertion metadata",()=>{
  beforeEach(()=>{inserted.batch=undefined;inserted.raw=undefined;inserted.segments=undefined});

  it("stores legacy imports without authority metadata",async()=>{
    await importDeputy(file(),"Australia/Brisbane",actor);
    expect(inserted.batch).toMatchObject({snapshot_type:null,report_generated_at:null,coverage_start:null,coverage_end:null,certified_at:null});
    expect(inserted.batch).not.toHaveProperty("imported_at");
  });

  it("stores explicitly supplied full metadata in the batch, not raw rows",async()=>{
    const data=new FormData();
    data.set("snapshot_type","FULL");data.set("report_generated_at","2026-09-29T15:00:00+10:00");
    data.set("coverage_start","2026-09-15");data.set("coverage_end","2026-09-29");
    await importDeputy(file(),"Australia/Brisbane",actor,data);
    expect(inserted.batch).toMatchObject({snapshot_type:"FULL",report_generated_at:"2026-09-29T15:00:00+10:00",
      coverage_start:"2026-09-15",coverage_end:"2026-09-29",certified_by:"operator@tsd.example"});
    expect(inserted.batch).not.toHaveProperty("imported_at");
    expect(inserted.raw?.[0]).toMatchObject({timesheet_date:"2026-09-29",normalized_area:"DTG_OPERATOR"});
    expect(inserted.raw?.[0]).not.toHaveProperty("snapshot_type");
    expect(inserted.segments?.[0]).not.toHaveProperty("snapshot_type");
  });

  it("rejects a declared range that excludes an imported timesheet date",async()=>{
    const data=new FormData();
    data.set("snapshot_type","FULL");data.set("report_generated_at","2026-09-29T15:00:00+10:00");
    data.set("coverage_start","2026-09-15");data.set("coverage_end","2026-09-28");
    await expect(importDeputy(file(),"Australia/Brisbane",actor,data)).rejects.toThrow(/coverage/i);
    expect(inserted.batch).toBeUndefined();
  });
});
