import {createBrowserClient} from "@supabase/ssr";import {getPublicEnv} from "../env";
export function createClient(){const e=getPublicEnv();return createBrowserClient(e.NEXT_PUBLIC_SUPABASE_URL,e.NEXT_PUBLIC_SUPABASE_ANON_KEY)}
