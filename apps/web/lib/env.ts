import { z } from "zod";
const productionProjectRef="eziirebccovlvhaonsgw";
const schema=z.object({
  NEXT_PUBLIC_SUPABASE_URL:z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY:z.string().min(1),
  VERCEL_ENV:z.enum(["production","preview","development"]).optional(),
});

export const parsePublicEnv=(input:Record<string,string|undefined>)=>{
  const env=schema.parse(input);
  const projectRef=new URL(env.NEXT_PUBLIC_SUPABASE_URL).hostname.split(".")[0];
  if(env.VERCEL_ENV==="production"&&projectRef!==productionProjectRef){
    throw new Error(`Production must use Supabase project ${productionProjectRef}`);
  }
  if(env.VERCEL_ENV&&env.VERCEL_ENV!=="production"&&projectRef===productionProjectRef){
    throw new Error("Production Supabase cannot be used outside the Production environment");
  }
  return env;
};

export const getPublicEnv=()=>parsePublicEnv({
  NEXT_PUBLIC_SUPABASE_URL:process.env.NEXT_PUBLIC_SUPABASE_URL,
  NEXT_PUBLIC_SUPABASE_ANON_KEY:process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  VERCEL_ENV:process.env.VERCEL_ENV,
});
