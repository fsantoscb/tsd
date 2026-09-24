import {beforeEach,describe,expect,it,vi} from "vitest";

const execute=vi.fn();
const close=vi.fn();

vi.mock("oracledb",()=>({
 default:{OUT_FORMAT_OBJECT:4002,getConnection:vi.fn(async()=>({execute,close,commit:vi.fn()}))},
}));

import {OracleSourceReader} from "../src/source-reader";

const env={ORACLE_CONNECT_STRING:"db",ORACLE_USER:"u",ORACLE_PASSWORD:"p",ORACLE_CREDENTIAL_TARGET:"test",INGEST_API_URL:"https://app.test/api/ingest",INGEST_SECRET:"s".repeat(32),ORGANIZATION_ID:"00000000-0000-4000-8000-000000000001",EXPECTED_SUPABASE_PROJECT_REF:"saecycamkyvzzppxudzq",AGENT_ID:"factory-1",CONNECTOR_VERSION:"0.1.0",AUDIT_AFTER_ID:"0",SYNC_INTERVAL_SECONDS:300,SYNC_TIMEZONE:"Australia/Brisbane"};

describe("Oracle Stock source filter",()=>{
 beforeEach(()=>{execute.mockReset();close.mockReset();execute.mockResolvedValue({rows:[]})});

 it("retains the existing scope and additively includes only the approved UV locations",async()=>{
  const reader=new OracleSourceReader(env);
  await reader.read();
  await reader.inspect();
  await reader.close();

  const stockSql=execute.mock.calls.map(([sql])=>String(sql)).filter(sql=>sql.includes("from IS_STOCK_V"));
  expect(stockSql).toHaveLength(2);
  for(const sql of stockSql){
   expect(sql).toContain("upper(CLIENT)='TSD'");
   expect(sql).toContain("PRODUCT like '#%'");
   expect(sql).toContain("LOCATION not like 'CONS%'");
   expect(sql).toContain("LOCATION not like 'DROPZONE%'");
   expect(sql).toContain("(upper(LOCATION) like '%UNDERPRINT%' or upper(ZONE)='PWL1' or upper(trim(LOCATION)) in ('UV','UVPRNT','FINISHED') or upper(LOCATION) like '%PWL3%' or upper(LOCATION) like '%STICKRDROP%')");
  }
 });
});
