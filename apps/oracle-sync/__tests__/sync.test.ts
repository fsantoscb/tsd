import { describe, expect, it, vi } from "vitest";
import { syncOnce } from "../src/sync";

const env = {
  ORACLE_CONNECT_STRING: "db", ORACLE_USER: "u", ORACLE_PASSWORD: "p", ORACLE_CREDENTIAL_TARGET: "test",
  INGEST_API_URL: "https://app.test/api/ingest", INGEST_SECRET: "s".repeat(32),
  ORGANIZATION_ID: "00000000-0000-4000-8000-000000000001", EXPECTED_SUPABASE_PROJECT_REF: "eziirebccovlvhaonsgw",
  AGENT_ID: "factory-1", CONNECTOR_VERSION: "0.1.0", AUDIT_AFTER_ID: "0", SYNC_INTERVAL_SECONDS: 60,
  SYNC_TIMEZONE: "Australia/Brisbane",
};

describe("sync once", () => {
  it("posts only the current snapshot and never invokes raw Audit ingestion", async () => {
    const fetcher = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(JSON.stringify({ batchId: "batch-1" }), { status: 202 }));
    const source = { read: async () => ({ orders: [], releaseOrderLines: [], workbank: [], stock: [] }) };
    expect(await syncOnce(env, source, fetcher)).toEqual({ batchId: "batch-1", counts: { orders: 0, releaseOrderLines: 0, workbank: 0, stock: 0, audit: 0 } });
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(String(fetcher.mock.calls[0]?.[0])).toBe("https://app.test/api/ingest/sync");
    expect(String(fetcher.mock.calls[0]?.[1]?.body)).not.toContain("auditEvents");
  });

  it("does not return snapshot success when ingestion is rejected", async () => {
    const fetcher = vi.fn(async (_input: RequestInfo | URL, _init?: RequestInit) => new Response(null, { status: 413 }));
    const source = { read: async () => ({ orders: [], releaseOrderLines: [], workbank: [], stock: [] }) };
    await expect(syncOnce(env, source, fetcher)).rejects.toThrow("Ingestion failed with HTTP 413");
  });
});
