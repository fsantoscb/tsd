import { describe, expect, it, vi } from "vitest";
import { agentTick, heartbeatOnce } from "../src/agent";

const env = { ORACLE_CONNECT_STRING: "db", ORACLE_USER: "u", ORACLE_PASSWORD: "p", ORACLE_CREDENTIAL_TARGET: "test", INGEST_API_URL: "https://app.test/api/ingest", INGEST_SECRET: "s".repeat(32), ORGANIZATION_ID: "00000000-0000-4000-8000-000000000001", EXPECTED_SUPABASE_PROJECT_REF: "saecycamkyvzzppxudzq", AGENT_ID: "factory-1", CONNECTOR_VERSION: "0.2.0", AUDIT_AFTER_ID: "0", SYNC_INTERVAL_SECONDS: 300, SYNC_TIMEZONE: "Australia/Brisbane" };

describe("agent scheduler", () => {
  it("proves the target before heartbeat and remains idle when no work is due", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
      const url = String(input);
      if (url.endsWith("/organization")) return new Response(JSON.stringify({ organizationId: env.ORGANIZATION_ID, projectRef: env.EXPECTED_SUPABASE_PROJECT_REF }), { status: 200 });
      return new Response(JSON.stringify(url.endsWith("/control") ? null : { ok: true }), { status: 200 });
    });
    await expect(agentTick(env)).resolves.toEqual({ status: "IDLE" });
    expect(fetchMock).toHaveBeenCalledTimes(3);
    fetchMock.mockRestore();
  });

  it("refuses a mismatched Supabase target before heartbeat or claim", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(JSON.stringify({ organizationId: env.ORGANIZATION_ID, projectRef: "gdajktoqmajipivpdude" }), { status: 200 }));
    await expect(agentTick(env)).rejects.toThrow("SYNC_TARGET_PROJECT_MISMATCH");
    expect(fetchMock).toHaveBeenCalledTimes(1);
    fetchMock.mockRestore();
  });

  it("emits one guarded heartbeat without claiming sync work", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockImplementation(async (input) => {
      const url = String(input);
      if (url.endsWith("/organization")) return new Response(JSON.stringify({ organizationId: env.ORGANIZATION_ID, projectRef: env.EXPECTED_SUPABASE_PROJECT_REF }), { status: 200 });
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    });
    await expect(heartbeatOnce(env)).resolves.toEqual({ organizationId: env.ORGANIZATION_ID, projectRef: env.EXPECTED_SUPABASE_PROJECT_REF });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(String(fetchMock.mock.calls[1]?.[0])).toBe("https://app.test/api/ingest/heartbeat");
    fetchMock.mockRestore();
  });

  it("does not emit heartbeat when the heartbeat-only target guard fails", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(new Response(JSON.stringify({ organizationId: env.ORGANIZATION_ID, projectRef: "wrongprojectrefxxxxx" }), { status: 200 }));
    await expect(heartbeatOnce(env)).rejects.toThrow("SYNC_TARGET_PROJECT_MISMATCH");
    expect(fetchMock).toHaveBeenCalledTimes(1);
    fetchMock.mockRestore();
  });
});
