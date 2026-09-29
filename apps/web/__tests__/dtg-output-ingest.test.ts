import { afterEach, describe, expect, it, vi } from "vitest";
import { authorizeIngest, ingestDtgOutputDaily } from "../lib/ingest";
import { POST as postDtgOutputDaily } from "../app/api/ingest/dtg-output-daily/route";

const rpc = vi.fn();
vi.mock("@supabase/supabase-js", () => ({ createClient: () => ({ rpc }) }));
afterEach(() => { vi.unstubAllEnvs(); rpc.mockReset(); });

describe("DTG Output additive ingest endpoint", () => {
  it("returns 401 for missing and invalid machine secrets before parsing a payload", async () => {
    vi.stubEnv("INGEST_SECRET", "s".repeat(32));
    for (const authorization of [undefined, "Bearer invalid"]) {
      const response = await postDtgOutputDaily(new Request("http://local/api/ingest/dtg-output-daily", {
        method: "POST", headers: authorization ? { authorization } : undefined, body: "not json",
      }));
      expect(response.status).toBe(401);
      expect(await response.json()).toEqual({ error: "Unauthorized" });
    }
    expect(rpc).not.toHaveBeenCalled();
  });
  it("keeps agent-secret authentication as the boundary", () => {
    const secret = "s".repeat(32);
    expect(authorizeIngest(null, secret)).toBe(false);
    expect(authorizeIngest("Bearer wrong", secret)).toBe(false);
    expect(authorizeIngest(`Bearer ${secret}`, secret)).toBe(true);
  });
  it("rejects malformed and reversed date ranges before any database call", async () => {
    await expect(ingestDtgOutputDaily({ organizationId: "bad", rows: [] })).rejects.toThrow("INVALID_DTG_OUTPUT_PAYLOAD");
    await expect(ingestDtgOutputDaily({ organizationId: "00000000-0000-4000-8000-000000000001", from: "2026-09-25", to: "2026-09-24", rows: [] })).rejects.toThrow("INVALID_DTG_OUTPUT_PAYLOAD");
    expect(rpc).not.toHaveBeenCalled();
  });
  it("rejects organization mismatch before the replacement RPC", async () => {
    vi.stubEnv("ORGANIZATION_ID", "00000000-0000-4000-8000-000000000001");
    await expect(ingestDtgOutputDaily({ organizationId: "00000000-0000-4000-8000-000000000002", from: "2026-09-24", to: "2026-09-24", rows: [] })).rejects.toThrow("ORGANIZATION_MISMATCH");
    expect(rpc).not.toHaveBeenCalled();
  });
  it("passes bounded compact rows unchanged to the isolated replacement RPC", async () => {
    const org = "00000000-0000-4000-8000-000000000001";
    vi.stubEnv("ORGANIZATION_ID", org);
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://example.supabase.co");
    vi.stubEnv("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
    rpc.mockResolvedValue({ data: 1, error: null });
    const rows = [{ operationalDate: "2026-09-24", shiftCode: "SHIFT_3", outputType: "DTG", quantity: 4608, sourceRowCount: 77, sourceMaxEventAt: "2026-09-25T00:31:13+10:00" }];
    await expect(ingestDtgOutputDaily({ organizationId: org, from: "2026-09-24", to: "2026-09-24", rows })).resolves.toEqual({ accepted: 1 });
    expect(rpc).toHaveBeenCalledWith("replace_dtg_output_daily", { p_organization_id: org, p_from: "2026-09-24", p_to: "2026-09-24", p_rows: rows });
  });
  it("accepts the connector contract through the authenticated route", async () => {
    const org = "00000000-0000-4000-8000-000000000001";
    const secret = "s".repeat(32);
    vi.stubEnv("ORGANIZATION_ID", org);
    vi.stubEnv("INGEST_SECRET", secret);
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://example.supabase.co");
    vi.stubEnv("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
    rpc.mockResolvedValue({ data: 0, error: null });
    const response = await postDtgOutputDaily(new Request("http://local/api/ingest/dtg-output-daily", {
      method: "POST", headers: { authorization: `Bearer ${secret}` },
      body: JSON.stringify({ organizationId: org, from: "2026-09-24", to: "2026-09-24", rows: [] }),
    }));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ accepted: 0 });
  });
});
