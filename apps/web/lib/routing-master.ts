import { productionMaster } from "@/lib/production-master";

export async function routingMaster() {
  const context = await productionMaster();
  const organizationId = context.organizationId;
  const [routings, routingOperations] = await Promise.all([
    context.db.from("routings").select("*").eq("organization_id", organizationId).order("code").order("revision", { ascending: false }),
    context.db.from("routing_operations").select("*,operations(code,name),work_centers(code,name)").eq("organization_id", organizationId).order("sequence"),
  ]);
  if (routings.error) throw routings.error;
  if (routingOperations.error) throw routingOperations.error;
  return { ...context, routings: routings.data ?? [], routingOperations: routingOperations.data ?? [] };
}
