import { describe, expect, it } from "vitest";
import { isCanonicalMasterCode, normalizeMasterCode, normalizeSourceOperation } from "../lib/production-master-rules";

describe("production master rules", () => {
  it("normalizes human-entered codes", () => expect(normalizeMasterCode("  screen-print_1 ")).toBe("SCREEN-PRINT_1"));
  it("rejects codes outside the canonical alphabet", () => expect(isCanonicalMasterCode("DTG 1")).toBe(false));
  it("keeps known source operations canonical", () => expect(normalizeSourceOperation(" dtg ", ["DTG", "UP"])).toBe("DTG"));
  it("keeps unknown source values visible as UNMAPPED", () => expect(normalizeSourceOperation("legacy-x", ["DTG", "UP"])).toBe("UNMAPPED"));
});
