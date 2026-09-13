'use server';
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { routingMaster } from "@/lib/routing-master";
import { normalizeRoutingCode, ROUTING_STATUSES } from "@/lib/routing-rules";

const uuid = z.string().uuid();
const numberOrNull = (value: FormDataEntryValue | null) => value === null || String(value).trim() === "" ? null : z.coerce.number().nonnegative().parse(value);
async function managed() { const context = await routingMaster(); if (!context.canManage) throw Error("Routing permission denied"); return context; }
export async function createRouting(form: FormData) {
  const context = await managed();
  const payload = { organization_id: context.organizationId, code: z.string().regex(/^[A-Z0-9_]+$/).max(60).parse(normalizeRoutingCode(form.get("code"))), name: z.string().trim().min(2).max(160).parse(form.get("name")), revision: z.coerce.number().int().positive().parse(form.get("revision")), status: z.enum(ROUTING_STATUSES).parse(form.get("status")), effective_from: String(form.get("effective_from") || "") || null };
  const { error } = await context.db.from("routings").insert(payload); if (error) throw error; revalidatePath("/admin/routings");
}
export async function addRoutingOperation(form: FormData) {
  const context = await managed();
  const payload = { organization_id: context.organizationId, routing_id: uuid.parse(form.get("routing_id")), sequence: z.coerce.number().int().positive().parse(form.get("sequence")), operation_id: uuid.parse(form.get("operation_id")), work_center_id: String(form.get("work_center_id") || "") || null, required: form.get("required") === "on", setup_minutes: numberOrNull(form.get("setup_minutes")), run_rate: numberOrNull(form.get("run_rate")), queue_minutes: numberOrNull(form.get("queue_minutes")), instructions: String(form.get("instructions") || "") || null };
  const { error } = await context.db.from("routing_operations").insert(payload); if (error) throw error; revalidatePath("/admin/routings");
}
export async function removeRoutingOperation(form: FormData) { const context = await managed(); const { error } = await context.db.from("routing_operations").delete().eq("organization_id", context.organizationId).eq("id", uuid.parse(form.get("id"))); if (error) throw error; revalidatePath("/admin/routings"); }
export async function assignProductRouting(form: FormData) { const context = await managed(); const { error } = await context.db.from("products").update({ default_routing_id: uuid.parse(form.get("routing_id")) }).eq("organization_id", context.organizationId).eq("id", uuid.parse(form.get("product_id"))); if (error) throw error; revalidatePath("/admin/routings"); }
export async function cloneRoutingRevision(form: FormData) { const context=await managed();const result=await context.db.rpc("clone_routing_revision",{p_routing_id:uuid.parse(form.get("routing_id"))});if(result.error)throw result.error;revalidatePath("/admin/routings");}
export async function moveRoutingOperation(form:FormData){const context=await managed();const result=await context.db.rpc("move_routing_operation",{p_operation_id:uuid.parse(form.get("id")),p_direction:z.enum(["up","down"]).parse(form.get("direction"))});if(result.error)throw result.error;revalidatePath("/admin/routings");}
export async function setRoutingStatus(form:FormData){const context=await managed();const status=z.enum(ROUTING_STATUSES).parse(form.get("status"));const result=await context.db.from("routings").update({status,active:status!=="INACTIVE",effective_to:status==="INACTIVE"?new Date().toISOString().slice(0,10):null}).eq("organization_id",context.organizationId).eq("id",uuid.parse(form.get("routing_id")));if(result.error)throw result.error;revalidatePath("/admin/routings");}
