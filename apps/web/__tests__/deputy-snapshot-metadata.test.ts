import {describe,expect,it} from "vitest";
import {parseDeputySnapshotMetadata} from "../lib/deputy-snapshot-metadata";

const form=(values:Record<string,string>={})=>{const data=new FormData();for(const[key,value]of Object.entries(values))data.set(key,value);return data};
const full={report_generated_at:"2026-09-29T15:00:00+10:00",coverage_start:"2026-09-15",coverage_end:"2026-09-29",snapshot_type:"FULL"};
const certifiedAt=new Date("2026-09-30T00:00:00.000Z");

describe("Deputy snapshot metadata",()=>{
  it("keeps a legacy import unverified with nullable metadata",()=>{
    expect(parseDeputySnapshotMetadata(form(),"operator@tsd.example",certifiedAt)).toEqual({
      report_generated_at:null,coverage_start:null,coverage_end:null,snapshot_type:null,
      certified_at:null,certified_by:null,certification_note:null,
    });
  });

  it("persists an explicitly certified full report without substituting import time",()=>{
    expect(parseDeputySnapshotMetadata(form({...full,certification_note:"Deputy report verified"}),"operator@tsd.example",certifiedAt)).toEqual({
      report_generated_at:"2026-09-29T15:00:00+10:00",coverage_start:"2026-09-15",coverage_end:"2026-09-29",
      snapshot_type:"FULL",certified_at:"2026-09-30T00:00:00.000Z",certified_by:"operator@tsd.example",
      certification_note:"Deputy report verified",
    });
  });

  it("allows a partial report but does not label it full",()=>{
    expect(parseDeputySnapshotMetadata(form({...full,snapshot_type:"PARTIAL"}),"operator@tsd.example",certifiedAt).snapshot_type).toBe("PARTIAL");
  });

  it("rejects invalid or incomplete declared coverage",()=>{
    expect(()=>parseDeputySnapshotMetadata(form({...full,coverage_start:"2026-09-30"}),"operator@tsd.example",certifiedAt)).toThrow(/coverage/i);
    expect(()=>parseDeputySnapshotMetadata(form({snapshot_type:"FULL"}),"operator@tsd.example",certifiedAt)).toThrow(/required/i);
  });

  it("accepts a historical correction outside the rolling window",()=>{
    const result=parseDeputySnapshotMetadata(form({...full,coverage_start:"2026-08-01",coverage_end:"2026-08-01"}),"operator@tsd.example",certifiedAt);
    expect(result.coverage_start).toBe("2026-08-01");
    expect(result.coverage_end).toBe("2026-08-01");
  });
});
