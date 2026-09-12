import { describe, expect, it } from "vitest";
import { assertExternalId, isNonEmptyString, parsePositiveInt } from "../src/validation";

describe("validation helpers", () => {
  it("detects non-empty string", () => {
    expect(isNonEmptyString("ok")).toBe(true);
    expect(isNonEmptyString("   ")).toBe(false);
  });

  it("parses positive integers", () => {
    expect(parsePositiveInt("12")).toBe(12);
    expect(() => parsePositiveInt(0)).toThrow("Expected positive integer");
  });
  it("preserves large IDs", () => expect(assertExternalId("123456789012345678")).toBe("123456789012345678"));
});
