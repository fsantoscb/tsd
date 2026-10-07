// Actual SQL execution requires independently verified localhost disposable DB.
import {readFileSync} from 'node:fs';
import {spawn} from 'node:child_process';
import {randomBytes} from 'node:crypto';
import {scenarios} from '../../scripts/tests/fixtures/labour-v3-concurrency-scenarios.mjs';
const database=process.env.TSD_V3_DISPOSABLE_DATABASE,host=process.env.PGHOST;
if(process.env.TSD_V3_DISPOSABLE_APPROVED!=='LABOUR_V3_PHASE3A_DISPOSABLE'
  ||!/^tsd_v3_disposable_[a-z0-9_]+$/.test(database??'')||!['127.0.0.1','::1'].includes(host)){
  console.log('NOT EXECUTION-CERTIFIED: explicitly approved localhost disposable database absent.');process.exit(2);
}
if(process.env.PGDATABASE!==database||!process.env.TSD_V3_CAS_FIXTURE){
  console.log('NOT EXECUTION-CERTIFIED: exact disposable database and synthetic fixture required.');process.exit(2);
}
const fixtures=JSON.parse(readFileSync(process.env.TSD_V3_CAS_FIXTURE,'utf8'));
for(const name of Object.keys(scenarios)){
  const f=fixtures[name];if(!f)throw Error('COMPLETE_SIX_SCENARIO_FIXTURE_REQUIRED');
  for(const r of f.requests??(f.request?[f.request]:[]))if(!/^TEST-/.test(r.personKey)||!/^[a-f0-9-]{36}$/i.test(r.organizationId))throw Error('SYNTHETIC_FIXTURE_REQUIRED');
  if(f.period&&!(/^[a-f0-9-]{36}$/i.test(f.period.organizationId)&&/^\d{4}-\d{2}-\d{2}$/.test(f.period.from)&&/^\d{4}-\d{2}-\d{2}$/.test(f.period.to)))throw Error('INVALID_CERTIFICATE_FIXTURE');
  if(f.mutationSQL&&(!/^update public\.(deputy_import_batches|deputy_raw_timesheets|shift_rules)\s+set\s+/i.test(f.mutationSQL)
    ||/;|--|\/\*/.test(f.mutationSQL)||!f.mutationSQL.includes(`organization_id='${f.period.organizationId}'`)))throw Error('SCOPED_DISPOSABLE_UPDATE_REQUIRED');
}
function connect(){
  const child=spawn('psql',['-X','-q','-A','-t','-v','ON_ERROR_STOP=0'],{env:process.env,stdio:['pipe','pipe','pipe'],windowsHide:true});
  let stdout='',stderr='',pending;
  const fail=()=>pending?.reject(Error('PSQL_UNAVAILABLE_OR_DISCONNECTED'));
  child.on('error',fail);child.on('exit',fail);child.stdout.on('data',d=>{stdout+=d;finish();});child.stderr.on('data',d=>stderr+=d);
  function finish(){
    if(!pending||!stdout.includes(pending.marker))return;
    const out=stdout.slice(pending.start,stdout.indexOf(pending.marker));
    const result={text:out.replace(/__SQLSTATE__[^\n]*\n?/g,''),sqlstate:out.match(/__SQLSTATE__\s+(\w{5})/)?.[1],error:stderr.slice(pending.errorStart)};
    clearTimeout(pending.timer);const done=pending.resolve;pending=undefined;done(result);
  }
  return {query(sql){
    if(pending)throw Error('OVERLAPPING_CLIENT_COMMAND');
    return new Promise((resolve,reject)=>{
      const marker='__DONE_'+randomBytes(12).toString('hex');
      pending={resolve,reject,marker,start:stdout.length,errorStart:stderr.length,timer:setTimeout(()=>reject(Error('DISPOSABLE_SQL_TIMEOUT')),30000)};
      child.stdin.write(sql+'\n\\echo __SQLSTATE__ :SQLSTATE\n\\echo '+marker+'\n');
    });
  },close(){child.stdin.end();child.kill();}};
}
const clients=[connect(),connect()];
try{
  // Actual server identity, before any mutation. Env assertions alone are insufficient.
  for(const c of clients){
    const r=await c.query("select jsonb_build_object('database',current_database(),'host',coalesce(inet_server_addr()::text,'127.0.0.1'));");
    if(r.sqlstate!=='00000')throw Error('DISPOSABLE_IDENTITY_NOT_PROVEN');
    const identity=JSON.parse(r.text.trim());
    if(identity.database!==database||!['127.0.0.1','::1'].includes(identity.host))throw Error('DISPOSABLE_IDENTITY_MISMATCH');
  }
  for(const [name,run]of Object.entries(scenarios)){await run(clients,fixtures[name]);console.log(`${name}: PostgreSQL execution PASS`);}
}finally{for(const c of clients)c.close();}
// No retry/provisioning/cleanup DML; disposable evidence remains for inspection.
