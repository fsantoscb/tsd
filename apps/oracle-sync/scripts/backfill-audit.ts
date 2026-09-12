import { OracleSourceReader } from "../src/source-reader";
import { parseConnectorEnv } from "../src/env";

const [from,to]=process.argv.slice(2).filter(value=>/^\d{4}-\d{2}-\d{2}$/.test(value));
if(!/^\d{4}-\d{2}-\d{2}$/.test(from??"")||!/^\d{4}-\d{2}-\d{2}$/.test(to??""))throw new Error("Usage: backfill-audit.ts YYYY-MM-DD YYYY-MM-DD");
const env=parseConnectorEnv(process.env);
const source=new OracleSourceReader(env);
try{
  const rows=await source.readAuditBetween(from,to),headers={Authorization:`Bearer ${env.INGEST_SECRET}`,"Content-Type":"application/json"};let rebuilt:null|number=null;
  for(let i=0;i<rows.length||i===0;i+=500){const events=rows.slice(i,i+500),rebuild=i+500>=rows.length,response=await fetch(`${env.INGEST_API_URL}/audit-backfill`,{method:"POST",headers,body:JSON.stringify({organizationId:env.ORGANIZATION_ID,events,rebuild})});if(!response.ok)throw new Error(`Backfill ingest failed: ${response.status} ${await response.text()}`);const result=await response.json()as{rebuilt:number|null};if(result.rebuilt!==null)rebuilt=result.rebuilt;if(rebuild)break}
  console.info(`Backfilled ${rows.length} Oracle audit events; rebuilt ${rebuilt??0} canonical events.`);
}finally{await source.close()}
