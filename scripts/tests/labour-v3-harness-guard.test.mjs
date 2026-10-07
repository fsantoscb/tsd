import {test} from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
const harness=new URL('../../supabase/tests/labour_v3_read_model_concurrency.mjs',import.meta.url);
for(const [name,env]of [
  ['no approval',{}],
  ['Production',{TSD_V3_DISPOSABLE_APPROVED:'LABOUR_V3_PHASE3A_DISPOSABLE',TSD_V3_DISPOSABLE_DATABASE:'postgres',PGDATABASE:'postgres',PGHOST:'eziirebccovlvhaonsgw.supabase.co'}],
  ['Preview',{TSD_V3_DISPOSABLE_APPROVED:'LABOUR_V3_PHASE3A_DISPOSABLE',TSD_V3_DISPOSABLE_DATABASE:'tsd_v3_disposable_test',PGDATABASE:'tsd_v3_disposable_test',PGHOST:'tsd-production-control-v2-preview.vercel.app'}],
  ['missing fixture',{TSD_V3_DISPOSABLE_APPROVED:'LABOUR_V3_PHASE3A_DISPOSABLE',TSD_V3_DISPOSABLE_DATABASE:'tsd_v3_disposable_test',PGDATABASE:'tsd_v3_disposable_test',PGHOST:'127.0.0.1'}]
])test(`harness refuses ${name} before connecting`,()=>{
  const clean={PATH:process.env.PATH,SystemRoot:process.env.SystemRoot,...env};
  const r=spawnSync(process.execPath,[harness.pathname.replace(/^\/(\w:)/,'$1')],{env:clean,encoding:'utf8',windowsHide:true});
  assert.equal(r.status,2);assert.match(r.stdout,/NOT EXECUTION-CERTIFIED/);
  assert.doesNotMatch(r.stdout+r.stderr,/password|postgres:\/\//i);
});
test('all six concurrency scenarios are implemented, not merely listed',async()=>{
  const m=await import('./fixtures/labour-v3-concurrency-scenarios.mjs').catch(e=>e.code==='ERR_MODULE_NOT_FOUND'?{}:Promise.reject(e));
  for(const name of ['firstInsert','replacement','sourceLockTimeout','selectionDuringCertificate','authorityDuringCertificate','certificateAfterChange'])assert.equal(typeof m.scenarios?.[name],'function');
});
