import { describe, expect, it } from "vitest";
import { upDailyRows } from "../lib/up-daily-actuals";

describe("UP daily performance presentation", () => {
  it("preserves precision in data while exposing populated dates", () => expect(upDailyRows(["2026-09-09"], [{ operational_date: "2026-09-09", garments: 2254.115, jobs: 60, status: "CURRENT" }])).toEqual([{ date: "2026-09-09", garments: 2254.115, jobs: 60, status: "CURRENT" }]));
  it("shows an unavailable day as missing rather than verified zero", () => expect(upDailyRows(["2026-09-13"], [])).toEqual([{ date: "2026-09-13", garments: null, jobs: null, status: "MISSING" }]));
});
