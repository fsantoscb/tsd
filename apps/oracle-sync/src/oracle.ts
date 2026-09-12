import oracledb from "oracledb";import {resolveOracleCredential} from "./credential";import type {ConnectorEnv} from "./types";
export async function testOracleConnection(env:ConnectorEnv){
 const credential=resolveOracleCredential(env);const connection=await oracledb.getConnection({connectString:env.ORACLE_CONNECT_STRING,user:credential.username,password:credential.password});
 try{await connection.execute("select 1 as connectivity_check from dual")}finally{await connection.close()}
}
