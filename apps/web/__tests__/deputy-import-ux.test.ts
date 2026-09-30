import {describe,expect,it} from "vitest";
import * as XLSX from "xlsx";
import {inspectDeputy} from "../lib/deputy-import";
import {brisbaneDate,reportGeneratedAt,snapshotFields} from "../lib/deputy-import-ux";

const workbook=(rows:Record<string,unknown>[])=>{
  const book=XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book,XLSX.utils.json_to_sheet(rows),"Data");
  return XLSX.write(book,{type:"array",bookType:"xlsx"}) as ArrayBuffer;
};

describe("Deputy file-first import",()=>{
  it("suggests observed coverage and counts distinct employees without claiming declared coverage",()=>{
    const file=workbook([
      {"Timesheet Date":"15/09/2026","Employee ID":"1","Display Name":"Alex"},
      {"Timesheet Date":"30/09/2026","Employee ID":"1","Display Name":"Alex"},
      {"Timesheet Date":"29/09/2026","Employee ID":"2","Display Name":"Sam"},
    ]);
    expect(inspectDeputy(file)).toEqual({rowCount:3,employeeCount:2,minDate:"2026-09-15",maxDate:"2026-09-30"});
  });

  it("does not invent coverage for a report without usable timesheet dates",()=>{
    expect(inspectDeputy(workbook([{"Timesheet Date":"invalid","Employee ID":"1"}]))).toEqual({rowCount:1,employeeCount:1,minDate:null,maxDate:null});
  });

  it("defaults only the Brisbane date and never invents a generation time",()=>{
    expect(brisbaneDate(new Date("2026-09-29T15:45:00.000Z"))).toBe("2026-09-30");
    expect(reportGeneratedAt("2026-09-30","")).toBeNull();
  });

  it("submits an explicitly confirmed Brisbane report time",()=>{
    expect(reportGeneratedAt("2026-09-30","14:10")).toBe("2026-09-30T14:10:00+10:00");
    expect(reportGeneratedAt("2026-09-31","14:10")).toBeNull();
  });

  it("creates FULL metadata with the standard note and no client certification identity",()=>{
    expect(snapshotFields("FULL","2026-09-30","14:10","2026-09-15","2026-09-30","Standard full Deputy export")).toEqual({
      snapshot_type:"FULL",report_generated_at:"2026-09-30T14:10:00+10:00",coverage_start:"2026-09-15",coverage_end:"2026-09-30",certification_note:"Standard full Deputy export",
    });
  });

  it("requires the confirmed time and coverage before FULL submission",()=>{
    expect(()=>snapshotFields("FULL","2026-09-30","","2026-09-15","2026-09-30","Standard full Deputy export")).toThrow(/Report generated at/);
    expect(()=>snapshotFields("FULL","2026-09-30","14:10","","2026-09-30","Standard full Deputy export")).toThrow(/Coverage start/);
  });

  it("keeps PARTIAL non-FULL and UNVERIFIED without authority metadata",()=>{
    expect(snapshotFields("PARTIAL","2026-09-30","14:10","2026-09-15","2026-09-30","").snapshot_type).toBe("PARTIAL");
    expect(snapshotFields("UNVERIFIED","","","","","")).toEqual({snapshot_type:"",report_generated_at:"",coverage_start:"",coverage_end:"",certification_note:""});
  });
});
