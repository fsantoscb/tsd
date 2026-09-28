import {beforeEach,describe,expect,it,vi} from "vitest";

const state = vi.hoisted(() => ({
  getUser: vi.fn(),
  maybeSingle: vi.fn(),
  redirect: vi.fn((destination:string) => {throw new Error(`REDIRECT:${destination}`);}),
}));

vi.mock("server-only", () => ({}));
vi.mock("next/navigation", () => ({redirect:state.redirect}));
vi.mock("@/lib/permissions", async () => vi.importActual("../lib/permissions"));
vi.mock("@/lib/supabase/server", () => ({createClient:async () => ({auth:{getUser:state.getUser}})}));
vi.mock("@supabase/supabase-js", () => ({createClient:() => ({
  from:(table:string) => {
    if(table!=="maintenance_members")throw new Error(`Unexpected table: ${table}`);
    return {select:() => ({eq:() => ({eq:() => ({maybeSingle:state.maybeSingle})})})};
  },
})}));

import {requirePermission} from "../lib/authorization";

describe("existing production authorization", () => {
  beforeEach(() => {
    process.env.NEXT_PUBLIC_SUPABASE_URL="https://project.supabase.co";
    process.env.SUPABASE_SERVICE_ROLE_KEY="test-service-key";
    state.getUser.mockReset();
    state.maybeSingle.mockReset();
    state.redirect.mockClear();
  });

  it("redirects an unauthenticated production reader before accessing membership", async () => {
    state.getUser.mockResolvedValue({data:{user:null},error:null});
    await expect(requirePermission("SYSTEM_ADMIN")).rejects.toThrow("REDIRECT:/login");
    expect(state.maybeSingle).not.toHaveBeenCalled();
  });

  it("allows an authenticated admin with active membership", async () => {
    state.getUser.mockResolvedValue({data:{user:{id:"user-1"}},error:null});
    state.maybeSingle.mockResolvedValue({data:{organization_id:"org-1",role:"admin",active:true},error:null});
    const result=await requirePermission("SYSTEM_ADMIN");
    expect(result.user.id).toBe("user-1");
    expect(result.organizationId).toBe("org-1");
    expect(state.redirect).not.toHaveBeenCalled();
  });

  it("rejects an authenticated user without active membership", async () => {
    state.getUser.mockResolvedValue({data:{user:{id:"user-2"}},error:null});
    state.maybeSingle.mockResolvedValue({data:null,error:null});
    await expect(requirePermission("SYSTEM_ADMIN")).rejects.toThrow("REDIRECT:/login?error=unauthorized");
  });
});
