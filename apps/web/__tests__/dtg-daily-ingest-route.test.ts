import { afterEach, describe, expect, it, vi } from "vitest";

const state = vi.hoisted(() => ({
  rpc: vi.fn(async () => ({ data: 1, error: null })),
  query: [] as Array<[string, unknown]>,
}));

vi.mock("@supabase/supabase-js", () => ({
  createClient: () => ({
    rpc: state.rpc,
    from: (table: string) => ({
      select: (columns: string) => {
        state.query.push(["table", table], ["select", columns]);
        const chain = {
          eq: (column: string, value: unknown) => { state.query.push([column, value]); return chain; },
          order: (column: string) => {
            state.query.push(["order", column]);
            return Object.assign(chain, {
              then: (resolve: typeof Promise.resolve) => resolve({
                data: [{ weekday: 1, shift_code: "SHIFT_1", display_name: "Morning", start_time: "06:00:00", end_time: "14:00:00", cross_midnight: false, effective_from: "2026-01-01", effective_to: null }],
                error: null,
              }),
            });
          },
        };
        return chain;
      },
    }),
  }),
}));

import { GET, POST } from "../app/api/ingest/dtg-daily-actuals/route";

const organizationId = "00000000-0000-4000-8000-000000000001";
const secret = "s".repeat(32);
function configure() {
  process.env.ORGANIZATION_ID = organizationId;
  process.env.NEXT_PUBLIC_SUPABASE_URL = "https://example.supabase.co";
  process.env.SUPABASE_SERVICE_ROLE_KEY = "test-key";
  process.env.INGEST_SECRET = secret;
}

describe("DTG daily actuals ingestion route", () => {
  afterEach(() => {
    state.rpc.mockClear(); state.query.length = 0;
    delete process.env.ORGANIZATION_ID; delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    delete process.env.SUPABASE_SERVICE_ROLE_KEY; delete process.env.INGEST_SECRET;
  });

  it("returns active shift rules in the connector's exact response shape", async () => {
    configure();
    const response = await GET(new Request(`http://local/api/ingest/dtg-daily-actuals?organizationId=${organizationId}`, { headers: { authorization: `Bearer ${secret}` } }));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ rules: [{ weekday: 1, shiftCode: "SHIFT_1", displayName: "Morning", startTime: "06:00:00", endTime: "14:00:00", crossMidnight: false, effectiveFrom: "2026-01-01", effectiveTo: null }] });
    expect(state.query).toContainEqual(["table", "shift_rules"]);
    expect(state.query).toContainEqual(["active", true]);
  });

  it("rejects unauthenticated and mismatched-organization rule requests", async () => {
    configure();
    const url = `http://local/api/ingest/dtg-daily-actuals?organizationId=${organizationId}`;
    expect((await GET(new Request(url))).status).toBe(401);
    const mismatch = await GET(new Request(url.replace(organizationId, "00000000-0000-4000-8000-000000000002"), { headers: { authorization: `Bearer ${secret}` } }));
    expect(mismatch.status).toBe(400);
    expect(await mismatch.json()).toEqual({ error: "ORGANIZATION_MISMATCH" });
  });

  it("passes the connector's DTG daily rows to the existing replacement RPC", async () => {
    configure();
    const rows = [{ operationalDate: "2026-09-24", process: "DTG", machineCode: "DTG1", shiftCode: "SHIFT_1", garments: 5, prints: 9, sourceEventCount: 1, sourceMinAuditId: "10", sourceMaxAuditId: "10", sourceMaxEventAt: "2026-09-24T01:00:00+10:00", calculationVersion: "DTG_PCOR_SHIFT_V2" }];
    const response = await POST(new Request("http://local/api/ingest/dtg-daily-actuals", { method: "POST", headers: { authorization: `Bearer ${secret}` }, body: JSON.stringify({ organizationId, from: "2026-09-24", to: "2026-09-24", rows }) }));
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ accepted: 1 });
    expect(state.rpc).toHaveBeenCalledWith("replace_dtg_daily_actuals", { p_organization_id: organizationId, p_from: "2026-09-24", p_to: "2026-09-24", p_rows: rows });
  });
});
