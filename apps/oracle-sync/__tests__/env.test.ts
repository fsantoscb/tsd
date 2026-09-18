import { describe, expect, it } from "vitest";
import { parseConnectorEnv } from "../src/env";

describe("normalizeEndpoint", () => {
  it("validates settings", () => {
    expect(parseConnectorEnv({ORACLE_CONNECT_STRING:"db",ORACLE_USER:"u",ORACLE_PASSWORD:"p",INGEST_API_URL:"https://x.com",INGEST_SECRET:"a".repeat(32),ORGANIZATION_ID:"00000000-0000-4000-8000-000000000001",EXPECTED_SUPABASE_PROJECT_REF:"saecycamkyvzzppxudzq",AUDIT_AFTER_ID:"0"}).SYNC_INTERVAL_SECONDS).toBe(300);
  });
});
