import {describe,expect,it} from "vitest";
import {parsePublicEnv} from "../lib/env";

const productionUrl="https://eziirebccovlvhaonsgw.supabase.co";
const nonProductionUrl="https://devprojectref000000.supabase.co";
const input=(vercelEnv:string,url:string)=>({
  NEXT_PUBLIC_SUPABASE_URL:url,
  NEXT_PUBLIC_SUPABASE_ANON_KEY:"anon",
  VERCEL_ENV:vercelEnv,
});

describe("public env",()=>{
  it("rejects Preview configured with the Production Supabase ref",()=>{
    expect(()=>parsePublicEnv(input("preview",productionUrl))).toThrow(/Production Supabase/);
  });

  it("rejects Development configured with the Production Supabase ref",()=>{
    expect(()=>parsePublicEnv(input("development",productionUrl))).toThrow(/Production Supabase/);
  });

  it("rejects Production configured with a non-Production Supabase ref",()=>{
    expect(()=>parsePublicEnv(input("production",nonProductionUrl))).toThrow(/Production must use/);
  });

  it("accepts Production configured with the Production Supabase ref",()=>{
    expect(parsePublicEnv(input("production",productionUrl)).NEXT_PUBLIC_SUPABASE_URL).toBe(productionUrl);
  });

  it("accepts Preview configured with a non-Production Supabase ref",()=>{
    expect(parsePublicEnv(input("preview",nonProductionUrl)).NEXT_PUBLIC_SUPABASE_URL).toBe(nonProductionUrl);
  });
});
