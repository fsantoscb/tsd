// Disposable-only executable choreography. Importing opens no connection.
import assert from 'node:assert/strict';
const literal=x=>`'${JSON.stringify(x).replaceAll("'","''")}'::jsonb`;
const selectSql=r=>`select public.labour_v3_select_cohort_v1(${literal(r)});`;
const certSql=p=>`select public.labour_v3_certify_window_v1('${p.organizationId}'::uuid,'${p.from}'::date,'${p.to}'::date);`;
const state=x=>JSON.stringify([x.statuses,x.blocking,x.certifiedComplete,x.requiredCohorts,x.selectionVector,x.generationChecks]);
async function ok(c,sql){const r=await c.query(sql);assert.equal(r.sqlstate,'00000','Unexpected SQL failure; output withheld');return r;}
const json=r=>JSON.parse(r.text.trim().split('\n').filter(x=>x.trim().startsWith('{')).at(-1));
async function race(clients,f,initial){
  assert.equal(f.requests.length,2);
  for(const k of ['organizationId','personKey','payrollWeek','expectedGenerationId','expectedSelectionVersion'])assert.deepEqual(f.requests[0][k],f.requests[1][k]);
  if(initial){assert.equal(f.requests[0].expectedGenerationId,null);assert.equal(f.requests[0].expectedSelectionVersion,0);}
  else{assert.ok(f.requests[0].expectedGenerationId);assert.ok(f.requests[0].expectedSelectionVersion>0);}
  const responses=await Promise.all(clients.map(async(c,i)=>{
    await ok(c,'begin;');const r=await c.query(selectSql(f.requests[i]));
    await ok(c,r.sqlstate==='00000'?'commit;':'rollback;');return r;
  }));
  assert.equal(responses.filter(r=>r.sqlstate==='00000').length,1);
  assert.equal(responses.filter(r=>r.sqlstate==='P0001'&&/CAS_CONFLICT/.test(r.error)).length,1);
  assert.equal(BigInt(json(responses.find(r=>r.sqlstate==='00000')).selectionVersion),BigInt(f.requests[0].expectedSelectionVersion)+1n);
}
async function snapshot([a,b],f,mutation){
  await ok(a,'begin isolation level repeatable read read only;');
  const before=json(await ok(a,certSql(f.period)));
  await ok(b,'begin;');await ok(b,mutation?f.mutationSQL:selectSql(f.request));await ok(b,'commit;');
  const during=json(await ok(a,certSql(f.period)));assert.equal(state(during),state(before),'Certificate mixed snapshots');
  await ok(a,'commit;');await ok(a,'begin isolation level repeatable read read only;');
  const after=json(await ok(a,certSql(f.period)));await ok(a,'commit;');
  assert.notEqual(state(after),state(before),'Fresh certificate ignored committed change');
  if(mutation)assert.equal(after.certifiedComplete,false);
}
export const scenarios={
  firstInsert:(c,f)=>race(c,f,true),replacement:(c,f)=>race(c,f,false),
  async sourceLockTimeout([a,b],f){
    await ok(a,'begin;');await ok(a,'lock table public.deputy_import_batches in row exclusive mode;');
    await ok(b,'begin;');const start=performance.now();const r=await b.query(selectSql(f.request));
    assert.equal(r.sqlstate,'55P03');assert.ok(performance.now()-start>=850&&performance.now()-start<5000);
    await ok(b,'rollback;');await ok(a,'rollback;');
  },
  selectionDuringCertificate:(c,f)=>snapshot(c,f,false),authorityDuringCertificate:(c,f)=>snapshot(c,f,true),
  async certificateAfterChange([a,b],f){
    await ok(a,'begin isolation level serializable read only;');
    const before=json(await ok(a,certSql(f.period)));await ok(a,'commit;');
    await ok(b,'begin;');await ok(b,f.mutationSQL);await ok(b,'commit;');
    await ok(a,'begin isolation level serializable read only;');
    const after=json(await ok(a,certSql(f.period)));await ok(a,'commit;');
    assert.notEqual(state(after),state(before));assert.equal(after.certifiedComplete,false);
  }
};
