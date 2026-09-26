import "server-only";
import { requirePermission } from "@/lib/authorization";
import { collectPaged } from "./operational";
import type { UvOrder } from "./uv-operational-model";

const columns = "organization_id,order_no,customer_name,source_priority,date_received,date_released,date_due,uv_pick_qty,uv_to_print_qty,uv_printing_qty,sticker_print_qty,finished_pick_qty,uv_pack_qty";

export async function uvOperationalOrders(): Promise<UvOrder[]> {
  const { db, organizationId } = await requirePermission("SYSTEM_ADMIN");
  return collectPaged<UvOrder>(async (from, to) => {
    const { data, error } = await db.from("v_uv_operational_orders").select(columns).eq("organization_id", organizationId).order("order_no", { ascending: true }).range(from, to);
    if (error) throw error;
    return (data ?? []) as UvOrder[];
  }, 500);
}
