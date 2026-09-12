import { parseConnectorEnv } from "./env";
export const createConnectorConfiguration=(env:NodeJS.ProcessEnv=process.env)=>parseConnectorEnv(env);
