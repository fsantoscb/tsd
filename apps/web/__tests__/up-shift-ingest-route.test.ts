import {afterEach,describe,expect,it,vi} from 'vitest';
import {upShiftFixture} from './fixtures/up-shift-stage-b';
const state=vi.hoisted(()=>({rpc:vi.fn(async()=>({data:{accepted:1,acceptedShifts:3,acceptedCoverage:2},error:null as null|{message:string}}))}));
vi.mock('@supabase/supabase-js',()=>({createClient:()=>({rpc:state.rpc})}));
import {POST} from '../app/api/ingest/up-daily-actuals/route';
const secret='s'.repeat(32);
async function post(payload:unknown,auth=true){
 process.env.ORGANIZATION_ID=upShiftFixture().organizationId;process.env.NEXT_PUBLIC_SUPABASE_URL='https://example.supabase.co';process.env.SUPABASE_SERVICE_ROLE_KEY='test-key';process.env.INGEST_SECRET=secret;
 return POST(new Request('http://local/api/ingest/up-daily-actuals',{method:'POST',headers:auth?{authorization:`Bearer ${secret}`}:{},body:JSON.stringify(payload)}));
}
afterEach(()=>{state.rpc.mockClear();for(const key of ['ORGANIZATION_ID','NEXT_PUBLIC_SUPABASE_URL','SUPABASE_SERVICE_ROLE_KEY','INGEST_SECRET'])delete process.env[key];});
describe('versioned UP atomic endpoint',()=>{
 it('accepts fully covered no-activity dates without manufacturing daily or shift rows',async()=>{
  const payload=upShiftFixture();payload.rows=[];payload.dailySummaries=[];payload.sourceMaxEventAt=null;
  payload.coverage.forEach(day=>{day.hasActivity=false;});
  expect((await post(payload)).status).toBe(200);
  expect(state.rpc).toHaveBeenCalledWith('replace_up_shift_daily_actuals_v1',{p_payload:payload});
 });
 it('preserves 1122.053 without rounding on a one-shift snapshot',async()=>{
  const payload=upShiftFixture();payload.rows=[{...payload.rows[0],garments:1122.053}];
  payload.dailySummaries=[{...payload.dailySummaries[0],garments:1122.053,sourceEventCount:20,sourceMaxEventAt:payload.rows[0].sourceMaxEventAt}];
  payload.sourceMaxEventAt=payload.rows[0].sourceMaxEventAt;
  expect((await post(payload)).status).toBe(200);
  expect(state.rpc).toHaveBeenCalledWith('replace_up_shift_daily_actuals_v1',{p_payload:payload});
 });
 it('passes exact Stage B payload to the new RPC, retaining cross-midnight operational date and fractional data',async()=>{
  const payload=upShiftFixture(),response=await post(payload);
  expect(response.status).toBe(200);expect(await response.json()).toEqual({accepted:1,acceptedShifts:3,acceptedCoverage:2});
  expect(state.rpc).toHaveBeenCalledWith('replace_up_shift_daily_actuals_v1',{p_payload:payload});
 });
 it('retains the ingest secret boundary',async()=>{expect((await post(upShiftFixture(),false)).status).toBe(401);expect(state.rpc).not.toHaveBeenCalled();});
 it.each([
  ['unknown version',(p:any)=>{p.contractVersion='UNKNOWN';}],
  ['null version',(p:any)=>{p.contractVersion=null;}],
  ['invalid UUID',(p:any)=>{p.sourceSnapshotId='invalid';}],
  ['invalid organization',(p:any)=>{p.organizationId='invalid';}],
  ['organization mismatch',(p:any)=>{p.organizationId='00000000-0000-4000-8000-000000000003';}],
  ['invalid date',(p:any)=>{p.from='2026-02-30';}],
  ['reversed dates',(p:any)=>{p.from='2026-10-02';}],
  ['invalid shift',(p:any)=>{p.rows[0].shiftCode='OVERTIME';}],
  ['duplicate shift',(p:any)=>{p.rows.push(p.rows[0]);}],
  ['duplicate daily',(p:any)=>{p.dailySummaries.push(p.dailySummaries[0]);}],
  ['outside range',(p:any)=>{p.rows[0].operationalDate='2026-09-29';}],
  ['negative garments',(p:any)=>{p.rows[0].garments=-1;}],
  ['garments mismatch',(p:any)=>{p.dailySummaries[0].garments=1442;}],
  ['count mismatch',(p:any)=>{p.dailySummaries[0].sourceEventCount=37;}],
  ['watermark mismatch',(p:any)=>{p.dailySummaries[0].sourceMaxEventAt='2026-09-30T19:50:03+10:00';}],
  ['row snapshot mismatch',(p:any)=>{p.rows[0].sourceSnapshotId='00000000-0000-4000-8000-000000000003';}],
  ['missing coverage',(p:any)=>{delete p.coverage;}],
  ['incomplete coverage',(p:any)=>{p.coverage.pop();}],
  ['false activity declaration',(p:any)=>{p.coverage[0].hasActivity=false;}],
  ['incomplete extraction',(p:any)=>{p.coverage[0].complete=false;}],
  ['wrong calculation version',(p:any)=>{p.rows[0].calculationVersion='UP_UNDERPRINT_EXIT_DAILY_V1';}],
  ['fractional event count',(p:any)=>{p.rows[0].sourceEventCount=1.5;}],
  ['missing rows',(p:any)=>{delete p.rows;}],
 ] as const)('rejects %s before RPC',async(_label,mutate)=>{
  const payload=upShiftFixture();mutate(payload);expect((await post(payload)).status).toBe(400);expect(state.rpc).not.toHaveBeenCalled();
 });
 it('accepts OUT_OF_SHIFT as-is without adding artificial missing shifts',async()=>{
  const payload=upShiftFixture();payload.rows[2].shiftCode='OUT_OF_SHIFT';
  expect((await post(payload)).status).toBe(200);expect(state.rpc.mock.calls[0]).toEqual(['replace_up_shift_daily_actuals_v1',{p_payload:payload}]);
 });
});
