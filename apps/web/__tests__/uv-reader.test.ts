import { describe, expect, it, vi } from "vitest";

const from = vi.fn();
const requirePermission = vi.fn(async () => ({ db: { from }, organizationId: "org-1" }));
vi.mock("server-only", () => ({}));
vi.mock("@/lib/authorization", () => ({ requirePermission }));

describe("UV canonical reader", () => {
  it("uses SYSTEM_ADMIN and only the organization-scoped canonical view", async () => {
    const range = vi.fn(async () => ({ data: [{ order_no: "1301" }], error: null }));
    const order = vi.fn(() => ({ range }));
    const eq = vi.fn(() => ({ order }));
    const select = vi.fn(() => ({ eq }));
    from.mockReturnValue({ select });
    const { uvOperationalOrders } = await import("../lib/uv-operational");
    expect((await uvOperationalOrders()).map(row => row.order_no)).toEqual(["1301"]);
    expect(requirePermission).toHaveBeenCalledWith("SYSTEM_ADMIN");
    expect(from).toHaveBeenCalledWith("v_uv_operational_orders");
    expect(eq).toHaveBeenCalledWith("organization_id", "org-1");
    expect(order).toHaveBeenCalledWith("order_no", { ascending: true });
    expect(range).toHaveBeenCalledWith(0, 499);
  });
  it("propagates query errors instead of presenting an empty workload", async () => {
    from.mockReturnValue({ select: () => ({ eq: () => ({ order: () => ({ range: async () => ({ data: null, error: new Error("UV source unavailable") }) }) }) }) });
    const { uvOperationalOrders } = await import("../lib/uv-operational");
    await expect(uvOperationalOrders()).rejects.toThrow("UV source unavailable");
  });
  it("reads successive ordered pages without losing a row after 500", async () => {
    const source = Array.from({ length: 501 }, (_, index) => ({ order_no: String(index).padStart(4, "0") }));
    const range = vi.fn(async (start: number, end: number) => ({ data: source.slice(start, end + 1), error: null }));
    const order = vi.fn(() => ({ range }));
    from.mockReturnValue({ select: () => ({ eq: () => ({ order }) }) });
    const { uvOperationalOrders } = await import("../lib/uv-operational");
    const result = await uvOperationalOrders();
    expect(result).toHaveLength(501);
    expect(result[500].order_no).toBe("0500");
    expect(order).toHaveBeenCalledWith("order_no", { ascending: true });
    expect(range.mock.calls).toEqual([[0, 499], [500, 999]]);
  });
});
