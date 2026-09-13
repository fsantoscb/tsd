import { describe, expect, it } from "vitest";
import { hasUniquePositiveSequences, nextRoutingRevision, normalizeRoutingCode, orderedRoutingSteps } from "../lib/routing-rules";

describe("routing master rules", () => {
  it("normalizes stable canonical codes", () => expect(normalizeRoutingCode(" screen print standard ")).toBe("SCREEN_PRINT_STANDARD"));
  it("creates the next immutable revision", () => expect(nextRoutingRevision([{ revision: 1 }, { revision: 3 }, { revision: 2 }])).toBe(4));
  it("orders operation snapshots by sequence", () => expect(orderedRoutingSteps([{ sequence: 30 }, { sequence: 10 }, { sequence: 20 }]).map((x)=>x.sequence)).toEqual([10,20,30]));
  it("rejects duplicate or invalid sequences", () => { expect(hasUniquePositiveSequences([{sequence:10},{sequence:10}])).toBe(false); expect(hasUniquePositiveSequences([{sequence:0}])).toBe(false); });
});
