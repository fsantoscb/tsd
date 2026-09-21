import {describe,expect,it,vi} from "vitest";
import {NextRequest} from "next/server";
import {readFileSync} from "node:fs";
import {resolve} from "node:path";

const getUser=vi.fn(()=>new Promise(()=>{}));

vi.mock("@supabase/ssr",()=>({
  createServerClient:vi.fn(()=>({auth:{getUser}})),
}));

import {middleware} from "../middleware";

describe("routing middleware",()=>{
  it("does not wait for a hanging Supabase Auth request",async()=>{
    process.env.NEXT_PUBLIC_SUPABASE_URL="https://example.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY="test-anon-key";

    const outcome=await Promise.race([
      Promise.resolve(middleware(new NextRequest("https://erp.example/production/performance"))).then(()=>"resolved"),
      new Promise<string>(resolve=>setTimeout(()=>resolve("timed-out"),50)),
    ]);

    expect(outcome).toBe("resolved");
    expect(getUser).not.toHaveBeenCalled();
  });

  it("leaves Production authorization at the server-side permission boundary",()=>{
    const authorization=readFileSync(resolve(__dirname,"../lib/authorization.ts"),"utf8");
    const planning=readFileSync(resolve(__dirname,"../lib/planning.ts"),"utf8");

    expect(authorization).toContain("session.auth.getUser()");
    expect(authorization).toContain('from("maintenance_members")');
    expect(planning).toContain('requirePermission("PRODUCTION_READ")');
  });
});
