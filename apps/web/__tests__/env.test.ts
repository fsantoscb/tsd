import {describe,expect,it} from "vitest";import {parsePublicEnv} from "../lib/env";
describe("public env",()=>{it("validates Supabase",()=>expect(parsePublicEnv({NEXT_PUBLIC_SUPABASE_URL:"https://x.supabase.co",NEXT_PUBLIC_SUPABASE_ANON_KEY:"anon"}).NEXT_PUBLIC_SUPABASE_ANON_KEY).toBe("anon"))});
