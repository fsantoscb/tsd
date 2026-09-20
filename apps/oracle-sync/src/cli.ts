import {readFile,writeFile} from "node:fs/promises";import {parseConnectorEnv} from "./env";import {testOracleConnection} from "./oracle";import {OracleSourceReader} from "./source-reader";import {syncOnce} from "./sync";import{agentTick,heartbeatOnce}from"./agent";import{refreshDtgDailyActuals}from"./dtg-daily-actuals";
const cursorPath=new URL("../.audit-cursor",import.meta.url);
async function readAuditCursor(fallback:string){try{const value=(await readFile(cursorPath,"utf8")).trim();return /^\d+$/.test(value)?value:fallback}catch(error){if((error as NodeJS.ErrnoException).code==="ENOENT")return fallback;throw error}}
async function main(){const configured=parseConnectorEnv(process.env);const env={...configured,AUDIT_AFTER_ID:await readAuditCursor(configured.AUDIT_AFTER_ID)};const command=process.argv[2];
 if(command==="oracle:test"){await testOracleConnection(env);console.info("Oracle connectivity verified.");return}
 if(command==="oracle:inspect"){const source=new OracleSourceReader(env);try{console.info(await source.inspect())}finally{await source.close()}return}
 if(command==="sync:once"){const source=new OracleSourceReader(env);try{const result=await syncOnce(env,source);await writeFile(cursorPath,`${result.lastAuditId}\n`,"utf8");console.info(`Sync batch accepted: ${result.batchId}; audit cursor: ${result.lastAuditId}`)}finally{await source.close()}return}
 if(command==="agent:heartbeat"){const identity=await heartbeatOnce(env);console.info(`HEARTBEAT_OK project=${identity.projectRef} agent=${env.AGENT_ID}`);return}
 if(command==="agent:tick"){const outcome=await agentTick(env);if(outcome.status==="EXECUTED"){await writeFile(cursorPath,`${outcome.result.lastAuditId}\n`,"utf8");console.info(`SYNC_SUCCESS trigger=${outcome.triggerType} batch=${outcome.result.batchId} cursor=${outcome.result.lastAuditId}`)}else console.info("SYNC_IDLE");return}
 if(command==="dtg:refresh"){const from=process.argv[3],to=process.argv[4];if(!from||!to)throw new Error("Expected dtg:refresh YYYY-MM-DD YYYY-MM-DD");const source=new OracleSourceReader(env);try{const result=await refreshDtgDailyActuals(env,source,{from,to});console.info(`DTG_DAILY_REFRESH accepted=${result.accepted} from=${from} to=${to}`)}finally{await source.close()}return}
 throw new Error("Expected oracle:test, sync:once, agent:heartbeat, agent:tick or dtg:refresh");
}
main().catch(error=>{console.error(error instanceof Error?error.message:"Connector failed");process.exitCode=1});
