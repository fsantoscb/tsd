import {beforeEach,describe,expect,it,vi} from "vitest";

const execute=vi.fn();
const close=vi.fn();

vi.mock("oracledb",()=>({
 default:{OUT_FORMAT_OBJECT:4002,getConnection:vi.fn(async()=>({execute,close}))},
}));

import {OracleSourceReader} from "../src/source-reader";

const env={ORACLE_CONNECT_STRING:"db",ORACLE_USER:"u",ORACLE_PASSWORD:"p",ORACLE_CREDENTIAL_TARGET:"test",INGEST_API_URL:"https://app.test/api/ingest",INGEST_SECRET:"s".repeat(32),ORGANIZATION_ID:"00000000-0000-4000-8000-000000000001",EXPECTED_SUPABASE_PROJECT_REF:"saecycamkyvzzppxudzq",AGENT_ID:"factory-1",CONNECTOR_VERSION:"0.1.0",AUDIT_AFTER_ID:"0",SYNC_INTERVAL_SECONDS:300,SYNC_TIMEZONE:"Australia/Brisbane"};

const existing={WB_ROWID:"EXISTING-1",ID:1,ONO:"130001",CUSTOMER:"C",CUSTOMER_NAME:"Customer",DTM_DUE:null,FROM_LOC:"PG11-A",FROM_ZONE:"PG11",TO_LOC:"DTGS",FROM_PACK_ID:"OLD-FROM",TO_PACK_ID:"OLD-TO",PRIORITY:1,PROD:"SKU-OLD",DESCRIPTION:"Existing product",PRODUCT_GROUP:"G",QTY:"4",WEIGHT:40,PACKDESC:"GARMENT",QUEUE:"PG11",WK_QUEUE:"PG11",ISIS_TASK:"PG11",PROD_X_5:null};
const uv=(id:string,zone:string,packdesc:string,qty:unknown,weight:unknown)=>({WB_ROWID:id,ID:2,ONO:"130002",CUSTOMER:"C",CUSTOMER_NAME:null,DTM_DUE:null,FROM_LOC:`${zone}-A`,FROM_ZONE:zone,TO_LOC:"PWL3",FROM_PACK_ID:"UV-FROM",TO_PACK_ID:"UV-TO",PRIORITY:2,PROD:"SKU-UV",DESCRIPTION:null,PRODUCT_GROUP:null,QTY:qty,WEIGHT:weight,PACKDESC:packdesc,QUEUE:"MPRD",WK_QUEUE:null,ISIS_TASK:"UV",PROD_X_5:null});

function setup(rawRows:Record<string,unknown>[]){
 execute.mockImplementation(async(sql:string)=>{
  if(sql.includes("from IS_WORKBANK_V w"))return {rows:[existing]};
  if(sql.includes("from IS_WORKBANK w"))return {rows:rawRows};
  return {rows:[]};
 });
}

describe("additive raw UV Workbank source",()=>{
 beforeEach(()=>{execute.mockReset();close.mockReset()});

 it("keeps the existing mapped row unchanged and adds PG02, PG04 and PG42 to one Workbank array",async()=>{
  setup([uv("UV-2","PG02","CARTON",1,12),uv("UV-4","PG04","GARMENT","7",70),uv("UV-42","PG42"," carton ",2,20)]);
  const reader=new OracleSourceReader(env);
  const payload=await reader.read();
  await reader.close();
  expect(payload.workbank).toHaveLength(4);
  expect(payload.workbank[0]).toEqual({sourceRowId:"EXISTING-1",orderNo:"130001",customerCode:"C",customerName:"Customer",sourceDueAt:null,fromLocation:"PG11-A",fromZone:"PG11",toLocation:"DTGS",fromPackId:"OLD-FROM",toPackId:"OLD-TO",sourcePriority:1,productCode:"SKU-OLD",productDescription:"Existing product",productGroup:"G",sourceQty:4,sourceWeight:40,productionUnits:4,printsPerGarment:null,queue:"PG11",task:"PG11"});
  expect(payload.workbank.slice(1).map(row=>[row.sourceRowId,row.fromZone,row.productionUnits])).toEqual([["UV-2","PG02",12],["UV-4","PG04",7],["UV-42","PG42",20]]);
  expect(payload.workbank[1]).toMatchObject({productCode:"SKU-UV",fromPackId:"UV-FROM",toPackId:"UV-TO",fromLocation:"PG02-A",toLocation:"PWL3",sourceQty:1,sourceWeight:12});
 });

 it("reads only incomplete raw PG02/PG04/PG42 rows without the view's queue or status-code exclusions",async()=>{
  setup([uv("UV-MPRD","PG02","GARMENT",3,30),uv("FG-NO-STATUS","PG04","GARMENT",4,40)]);
  const reader=new OracleSourceReader(env);
  const payload=await reader.read();
  await reader.close();
  const sql=execute.mock.calls.map(([value])=>String(value)).find(value=>value.includes("from IS_WORKBANK w"));
  expect(sql).toBeDefined();
  expect(sql).toContain("oh.DATE_COMPLETED is null");
  expect(sql).toContain("('PG02','PG04','PG42')");
  expect(sql).not.toContain("'PG11'");
  expect(sql).not.toContain("'DTGS'");
  expect(sql).not.toContain("'PWL1'");
  expect(sql).not.toContain("'MPRD'");
  expect(sql).not.toContain("IS_CODE_DESCRIPTION");
  expect(sql).not.toContain("days_old");
  expect(payload.workbank.slice(1).map(row=>row.sourceRowId)).toEqual(["UV-MPRD","FG-NO-STATUS"]);
 });

 it("fails loudly when raw and view rows have the same physical source ID",async()=>{
  setup([uv("EXISTING-1","PG02","CARTON",1,10)]);
  const reader=new OracleSourceReader(env);
  await expect(reader.read()).rejects.toThrow("WORKBANK_SOURCE_OVERLAP");
  await reader.close();
 });

 it("fails loudly when two raw rows have the same physical source ID",async()=>{
  setup([uv("UV-2","PG02","CARTON",1,10),uv("UV-2","PG04","GARMENT",2,20)]);
  const reader=new OracleSourceReader(env);
  await expect(reader.read()).rejects.toThrow("WORKBANK_SOURCE_OVERLAP");
  await reader.close();
 });

 it("rejects a raw row with an invalid Oracle numeric quantity",async()=>{
  setup([uv("UV-BAD","PG02","GARMENT","not-a-number",10)]);
  const reader=new OracleSourceReader(env);
  await expect(reader.read()).rejects.toThrow("UV_WORKBANK_INVALID_QUANTITY");
  await reader.close();
 });

 it("keeps nullable raw source quantities visible while producing the existing canonical zero",async()=>{
  setup([uv("UV-NULL","PG02","GARMENT",null,10)]);
  const reader=new OracleSourceReader(env);
  const payload=await reader.read();
  await reader.close();
  expect(payload.workbank[1]).toMatchObject({sourceRowId:"UV-NULL",sourceQty:null,sourceWeight:10,productionUnits:0});
 });
});
