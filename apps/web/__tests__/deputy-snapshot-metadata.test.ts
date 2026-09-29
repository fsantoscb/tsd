import {describe, expect, it} from "vitest";
import {parseDeputySnapshotMetadata} from "../lib/deputy-snapshot-metadata";

const form=(fields:Record<string,string>={})=>{const data=new FormData();for(const [key,value] of Object.entries(fields))data.set(key,value);return data};
const full={snapshot_type:"FULL",report_generated_at:"2026-09-29T15:02:00+10:00",coverage_start:"2026-09-14",coverage_end:"2026-09-29",certification_note:"Full Deputy export confirmed by Operations"};
const certifiedAt=new Date("2026-09-30T00:00:00.000Z");

describe("Deputy snapshot metadata",()=>{
  it("keeps an ordinary import unverified",()=>expect(parseDeputySnapshotMetadata(form(),"operator@example.com",certifiedAt)).toEqual({report_generated_at:null,coverage_start:null,coverage_end:null,snapshot_type:null,certified_at:null,certified_by:null,certification_note:null}));
  it("preserves the actual report timestamp and derives certifier/time on the server",()=>expect(parseDeputySnapshotMetadata(form({...full,certified_by:"forged@example.com",certified_at:"2020-01-01"}),"operator@example.com",certifiedAt)).toEqual({report_generated_at:full.report_generated_at,coverage_start:full.coverage_start,coverage_end:full.coverage_end,snapshot_type:"FULL",certified_at:certifiedAt.toISOString(),certified_by:"operator@example.com",certification_note:full.certification_note}));
  it("requires evidence and all authority fields for FULL",()=>{
    for(const key of ["report_generated_at","coverage_start","coverage_end","certification_note"]){const fields={...full};delete fields[key as keyof typeof fields];expect(()=>parseDeputySnapshotMetadata(form(fields),"operator@example.com",certifiedAt)).toThrow()}
    expect(()=>parseDeputySnapshotMetadata(form({...full,report_generated_at:"2026-09-29T15:02"}),"operator@example.com",certifiedAt)).toThrow(/timezone/i);
    expect(()=>parseDeputySnapshotMetadata(form({...full,coverage_start:"2026-09-30"}),"operator@example.com",certifiedAt)).toThrow(/coverage/i);
  });
  it("allows PARTIAL but never labels it FULL",()=>expect(parseDeputySnapshotMetadata(form({...full,snapshot_type:"PARTIAL"}),"operator@example.com",certifiedAt).snapshot_type).toBe("PARTIAL"));
  it("allows historical coverage older than fourteen days",()=>expect(parseDeputySnapshotMetadata(form({...full,coverage_start:"2026-08-01",coverage_end:"2026-08-31"}),"operator@example.com",certifiedAt).coverage_start).toBe("2026-08-01"));
  it("does not treat forged identity fields as requested certification",()=>expect(parseDeputySnapshotMetadata(form({certified_by:"forged@example.com"}),"operator@example.com",certifiedAt).snapshot_type).toBeNull());
});
