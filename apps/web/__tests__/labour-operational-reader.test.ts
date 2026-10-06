import { expect, it } from "vitest";
import { readLabourOperationalData } from "../lib/labour-operational-reader";

it("paginates the organization/date-bounded canonical view deterministically and adds exactly one bounded metadata read", async () => {
  const calls: unknown[][] = [];
  const db = { from(table: string) {
    calls.push(["from", table]);
    const query = Object.fromEntries(["select", "eq", "gte", "lte", "not", "order"].map(method => [method, (...args: unknown[]) => { calls.push([table, method, ...args]); return query; }])) as Record<string, any>;
    query.range = async (start: number, end: number) => { calls.push([table, "range", start, end]); return { data: start === 0 ? Array.from({ length: 1000 }, (_, id) => ({ id })) : [{ id: 1000 }], error: null }; };
    query.limit = async (limit: number) => { calls.push([table, "limit", limit]); return { data: [], error: { message: "metadata unavailable" } }; };
    return query;
  } };
  const result = await readLabourOperationalData(db as never, "org", "2026-09-23", "2026-10-06");
  expect(result.segments).toHaveLength(1001);
  expect(result.metadataComplete).toBe(false);
  expect(result.snapshots).toEqual([]);
  expect(calls.filter(call => call[0] === "from")).toEqual([["from", "v_current_labour_segments"], ["from", "deputy_import_batches"], ["from", "v_current_labour_segments"]]);
  expect(calls).toContainEqual(["v_current_labour_segments", "eq", "organization_id", "org"]);
  expect(calls).toContainEqual(["v_current_labour_segments", "gte", "operational_date", "2026-09-23"]);
  expect(calls).toContainEqual(["v_current_labour_segments", "lte", "operational_date", "2026-10-06"]);
  expect(calls).toContainEqual(["v_current_labour_segments", "order", "id", { ascending: true }]);
  expect(calls).toContainEqual(["deputy_import_batches", "limit", 100]);
});
