import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

describe("performance production event query", () => {
  it("uses the indexed stable operational ordering", () => {
    const source = readFileSync(new URL("../lib/erp-kpis.ts", import.meta.url), "utf8");

    expect(source).toContain('.order("operational_date").order("event_id")');
    expect(source).not.toContain('.order("event_ts_utc").range(start,end)');
  });
});
