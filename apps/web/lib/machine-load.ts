import "server-only";
import { createClient } from "@supabase/supabase-js";
import { redirect } from "next/navigation";
import { createClient as sessionClient } from "@/lib/supabase/server";
import { isAuthorizedAdminEmail } from "@/lib/auth";
import { classifyProductType, extractProductType, isExplicitlyClassified, PRODUCTION_MIX_GROUPS, type ProductionMixGroup } from "@/lib/production-mix";

type LoadRow = {
  from_zone: string | null;
  product_code: string | null;
  product_group: string | null;
  production_units: number | string | null;
  prints_per_garment: number | string | null;
  order_no: string;
  customer_name: string | null;
  source_due_at: string | null;
  source_priority: number | string | null;
  product_description: string | null;
  source_qty: number | string | null;
  queue: string | null;
  to_location: string | null;
  from_pack_id: string | null;
};

type OrderRow = { order_no: string; site: string | null; ship_to_name: string | null };
export type MachineLoadFilters = { dueFrom?: string; dueTo?: string; customer?: string; order?: string; priority?: string; site?: string; mixGroup?: string; productType?: string };

type StockRow = { product: string; location: string; source_zone: string | null; production_units: number | string | null };

function admin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("Supabase server environment missing");
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

async function readWorkbank(db: ReturnType<typeof admin>) {
  const rows: LoadRow[] = [];
  const pageSize = 1000;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await db
      .from("v_current_workbank")
      .select("from_zone,to_location,from_pack_id,product_code,product_group,production_units,prints_per_garment,order_no,customer_name,source_due_at,source_priority,product_description,source_qty,queue")
      .range(from, from + pageSize - 1);
    if (error) throw error;
    rows.push(...((data ?? []) as LoadRow[]));
    if (!data || data.length < pageSize) break;
  }
  return rows;
}

async function readOrders(db: ReturnType<typeof admin>) {
  const rows: OrderRow[] = [];
  const pageSize = 1000;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await db.from("v_current_orders").select("order_no,site,ship_to_name").range(from, from + pageSize - 1);
    if (error) throw error;
    rows.push(...((data ?? []) as OrderRow[]));
    if (!data || data.length < pageSize) break;
  }
  return rows;
}

async function readStock(db: ReturnType<typeof admin>) {
  const rows: StockRow[] = [];
  const pageSize = 1000;
  for (let from = 0; ; from += pageSize) {
    const { data, error } = await db.from("v_current_stock").select("product,location,source_zone,production_units").range(from, from + pageSize - 1);
    if (error) throw error;
    rows.push(...((data ?? []) as StockRow[]));
    if (!data || data.length < pageSize) break;
  }
  return rows;
}

export async function machineLoad(filters: MachineLoadFilters = {}) {
  const session = await sessionClient();
  const { data: user } = await session.auth.getUser();
  if (!user.user) redirect("/login");
  if (!isAuthorizedAdminEmail(user.user.email)) redirect("/login?error=unauthorized");

  const db = admin();
  const [workbank, stock, orders, capacity] = await Promise.all([
    readWorkbank(db),
    readStock(db),
    readOrders(db),
    db.from("v_capacity_load").select("daily_capacity,weekly_capacity").eq("area_code", "DTG").limit(1).maybeSingle(),
  ]);
  if (capacity.error) throw capacity.error;

  const siteByOrder = new Map(orders.map(row => [row.order_no, row.site?.trim() ?? ""]));
  const mixSource = workbank.filter(row => ["SP11", "PCOR"].includes(row.queue?.trim().toUpperCase() ?? ""));
  const optionValues = (values: Array<string | null | undefined>) => [...new Set(values.map(value => value?.trim()).filter((value): value is string => Boolean(value)))].sort();
  const enriched = mixSource.map(row => ({ ...row, productType: extractProductType(row.product_description), mixGroup: classifyProductType(extractProductType(row.product_description)), site: siteByOrder.get(row.order_no) ?? "", customer_name: orders.find(order => order.order_no === row.order_no)?.ship_to_name ?? "" }));
  const selected = enriched.filter(row => {
    const due = row.source_due_at?.slice(0, 10) ?? "";
    return (!filters.dueFrom || due >= filters.dueFrom) && (!filters.dueTo || due <= filters.dueTo)
      && (!filters.customer || row.customer_name?.toUpperCase().includes(filters.customer.toUpperCase()))
      && (!filters.order || row.order_no.includes(filters.order))
      && (!filters.priority || String(row.source_priority ?? "") === filters.priority)
      && (!filters.site || row.site === filters.site)
      && (!filters.mixGroup || row.mixGroup === filters.mixGroup)
      && (!filters.productType || row.productType === filters.productType);
  });
  const buckets = new Map<ProductionMixGroup, { awaiting: number; ready: number; orders: Set<string>; skus: Set<string> }>();
  for (const group of PRODUCTION_MIX_GROUPS) buckets.set(group, { awaiting: 0, ready: 0, orders: new Set(), skus: new Set() });
  for (const row of selected) {
    const bucket = buckets.get(row.mixGroup)!;
    const quantity = Number(row.source_qty);
    if (Number.isFinite(quantity) && quantity > 0) {
      if (row.queue?.trim().toUpperCase() === "SP11") bucket.awaiting += quantity;
      else bucket.ready += quantity;
    }
    bucket.orders.add(row.order_no);
    if (row.product_code) bucket.skus.add(row.product_code);
  }
  const mixTotal = [...buckets.values()].reduce((sum, bucket) => sum + bucket.awaiting + bucket.ready, 0);
  const mixGroups = [...buckets.entries()].map(([group, bucket]) => ({ group, awaiting: bucket.awaiting, ready: bucket.ready, total: bucket.awaiting + bucket.ready, percent: mixTotal ? (bucket.awaiting + bucket.ready) / mixTotal * 100 : 0, orders: bucket.orders.size, skus: bucket.skus.size })).filter(group => group.total > 0).sort((a, b) => b.total - a.total);
  const percentage = (group: ProductionMixGroup) => mixGroups.find(item => item.group === group)?.percent ?? 0;
  const unknownTypes = optionValues(selected.filter(row => row.productType && !isExplicitlyClassified(row.productType)).map(row => row.productType));

  const zones = (values: string[]) => workbank.filter(row => values.includes(row.from_zone?.trim().toUpperCase() ?? ""));
  const sumUnits = (rows: Array<{ production_units: number | string | null }>) => rows.reduce((total, row) => total + Number(row.production_units ?? 0), 0);
  const dtgPick = zones(["PG11"]);
  const dtgPrint = zones(["DTGS"]);
  type Stat = { units: number; prints: number };
  const productStats = new Map<string, Stat>();
  const groupStats = new Map<string, Stat>();
  const addStat = (map: Map<string, Stat>, key: string, units: number, prints: number) => {
    if (!key) return;
    const stat = map.get(key) ?? { units: 0, prints: 0 };
    stat.units += units;
    stat.prints += prints;
    map.set(key, stat);
  };
  let observedUnits = 0;
  let observedPrints = 0;
  for (const row of dtgPrint) {
    const units = Number(row.production_units ?? 0);
    const printsPerGarment = Number(row.prints_per_garment ?? 0);
    if (units <= 0 || printsPerGarment <= 0) continue;
    const prints = units * printsPerGarment;
    observedUnits += units;
    observedPrints += prints;
    addStat(productStats, row.product_code?.trim().toUpperCase() ?? "", units, prints);
    addStat(groupStats, row.product_group?.trim().toUpperCase() ?? "", units, prints);
  }
  const globalRatio = observedUnits ? observedPrints / observedUnits : 1;
  let productCoveredUnits = 0;
  const forecastPickPrints = dtgPick.reduce((total, row) => {
    const units = Number(row.production_units ?? 0);
    const product = productStats.get(row.product_code?.trim().toUpperCase() ?? "");
    const group = groupStats.get(row.product_group?.trim().toUpperCase() ?? "");
    if (product && product.units >= 5) productCoveredUnits += units;
    const ratio = product && product.units >= 5 ? product.prints / product.units : group && group.units >= 20 ? group.prints / group.units : globalRatio;
    return total + units * ratio;
  }, 0);
  const underprint = zones(["PG01", "PG1H", "PG1A", "PG1D"]);
  const underprintStock = stock.filter(row => row.location.trim().toUpperCase().includes("UNDERPRINT"));
  const readyToLift = zones(["PWL1"]);
  const readyOrders = new Set(readyToLift.map(row => row.order_no));
  const readyLocations = new Set(readyToLift.map(row => row.to_location?.trim()).filter((value):value is string=>Boolean(value)));
  const readyBoxes = new Set(readyToLift.map(row => row.from_pack_id?.trim()).filter((value):value is string=>Boolean(value)));
  const pendingForReadyOrders = dtgPrint.filter(row => readyOrders.has(row.order_no));

  return {
    orders: [{
      warehouse_garments: sumUnits(dtgPick),
      warehouse_prints: 0,
      print_garments: sumUnits(dtgPrint),
      print_prints: dtgPrint.reduce((total, row) => total + Number(row.production_units ?? 0) * Number(row.prints_per_garment ?? 0), 0),
      forecast_pick_prints: forecastPickPrints,
      forecast_ratio: globalRatio,
      forecast_product_coverage: sumUnits(dtgPick) ? productCoveredUnits / sumUnits(dtgPick) : 0,
      underprint_pick: sumUnits(underprint),
      underprint_active: sumUnits(underprintStock),
      ready_orders: readyOrders.size,
      ready_locations: readyLocations.size,
      ready_boxes: readyBoxes.size,
      ready_garments: sumUnits(readyToLift) + sumUnits(pendingForReadyOrders),
    }],
    dailyCapacity: Number(capacity.data?.daily_capacity ?? 0),
    weeklyCapacity: Number(capacity.data?.weekly_capacity ?? 0),
    productionMix: {
      total: mixTotal,
      groups: mixGroups,
      cards: { adult: percentage("ADULT T-SHIRTS"), kids: percentage("KIDS T-SHIRTS"), hoodies: percentage("HOODIES / SWEATS"), other: percentage("OTHER") },
      quality: { emptyDescription: selected.filter(row => !row.product_description?.trim()).length, invalidQuantity: selected.filter(row => !Number.isFinite(Number(row.source_qty)) || Number(row.source_qty) <= 0).length, unknownTypes },
      options: { customers: optionValues(enriched.map(row => row.customer_name)), sites: optionValues(enriched.map(row => row.site)), priorities: optionValues(enriched.map(row => String(row.source_priority ?? "") || null)), groups: [...PRODUCTION_MIX_GROUPS], productTypes: optionValues(enriched.map(row => row.productType)) },
    },
  };
}
