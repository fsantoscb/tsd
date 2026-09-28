import {afterEach,beforeEach,describe,expect,it,vi} from "vitest";
import {NextRequest} from "next/server";

const auth = vi.hoisted(() => ({
  getUser: vi.fn(),
  createServerClient: vi.fn(),
}));

vi.mock("@supabase/ssr", () => ({
  createServerClient: auth.createServerClient,
}));

import {middleware} from "../middleware";

const request = (path: string) => new NextRequest(`https://production.example${path}`);

describe("middleware authentication boundary", () => {
  beforeEach(() => {
    process.env.NEXT_PUBLIC_SUPABASE_URL = "https://project.supabase.co";
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = "test-anon-key";
    auth.getUser.mockReset().mockResolvedValue({data:{user:{id:"user-1"}},error:null});
    auth.createServerClient.mockReset().mockImplementation(() => ({auth:{getUser:auth.getUser}}));
  });

  afterEach(() => {
    delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  });

  it.each([
    "/api/ingest/sync",
    "/api/ingest/heartbeat",
    "/sw.js",
    "/offline",
    "/login",
  ])("passes %s without interactive Supabase Auth", async path => {
    const response = await middleware(request(path));
    expect(response.status).toBe(200);
    expect(response.headers.get("x-middleware-next")).toBe("1");
    expect(auth.createServerClient).not.toHaveBeenCalled();
    expect(auth.getUser).not.toHaveBeenCalled();
  });

  it("lets an already-authenticated user visit /login without middleware redirect", async () => {
    const signedIn = request("/login");
    signedIn.cookies.set("sb-session", "existing-session");
    const response = await middleware(signedIn);
    expect(response.status).toBe(200);
    expect(response.headers.get("location")).toBeNull();
    expect(auth.getUser).not.toHaveBeenCalled();
  });

  it("keeps user authentication and cookie refresh on production pages", async () => {
    auth.createServerClient.mockImplementation((_url, _key, options) => ({auth:{getUser:async () => {
      options.cookies.setAll([{name:"sb-refreshed",value:"new-session",options:{httpOnly:true,path:"/"}}]);
      return {data:{user:{id:"user-1"}},error:null};
    }}}));
    const original = request("/production/dtg");
    const response = await middleware(original);
    expect(auth.createServerClient).toHaveBeenCalledOnce();
    expect(original.cookies.get("sb-refreshed")?.value).toBe("new-session");
    expect(response.cookies.get("sb-refreshed")?.value).toBe("new-session");
  });

  it("continues to authenticate non-ingest API routes", async () => {
    await middleware(request("/api/sync/status"));
    expect(auth.createServerClient).toHaveBeenCalledOnce();
    expect(auth.getUser).toHaveBeenCalledOnce();
  });
});
