import{describe,expect,it}from"vitest";import{isScreenPrintWorkbank,screenPrintCurrentLoad}from"../lib/screen-print-rules";
describe("Screen Print Workbank authority",()=>{
 it("recognizes PAK7 from queue or task",()=>{expect(isScreenPrintWorkbank({queue:"PAK7",task:null})).toBe(true);expect(isScreenPrintWorkbank({queue:null,task:"pak7"})).toBe(true)});
 it("does not infer Screen Print from release or unrelated rows",()=>expect(isScreenPrintWorkbank({queue:"SP11",task:"PCOR"})).toBe(false));
 it("counts current Workbank once",()=>expect(screenPrintCurrentLoad([{source_row_id:"A",queue:"PAK7",task:null,production_units:40},{source_row_id:"B",queue:null,task:"PAK7",production_units:10},{source_row_id:"C",queue:"SP11",task:null,production_units:999}])).toMatchObject({jobs:2,quantity:50}));
});
