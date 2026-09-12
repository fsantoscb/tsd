import {spawnSync} from "node:child_process";import {fileURLToPath} from "node:url";import type {ConnectorEnv} from "./types";
export function resolveOracleCredential(env:ConnectorEnv){
 if(env.ORACLE_USER&&env.ORACLE_PASSWORD)return {username:env.ORACLE_USER,password:env.ORACLE_PASSWORD};
 if(process.platform!=="win32")throw new Error("ORACLE_USER and ORACLE_PASSWORD are required outside Windows");
 const script=fileURLToPath(new URL("../scripts/get-windows-credential.ps1",import.meta.url));
 const result=spawnSync("powershell.exe",["-NoProfile","-NonInteractive","-File",script,env.ORACLE_CREDENTIAL_TARGET],{encoding:"utf8",windowsHide:true});
 if(result.status!==0)throw new Error("Unable to load Oracle credential from Windows Credential Manager");
 const value=JSON.parse(result.stdout.trim()) as {username:string;password:string};
 if(!value.username||!value.password)throw new Error("Windows credential is incomplete");
 return value;
}
