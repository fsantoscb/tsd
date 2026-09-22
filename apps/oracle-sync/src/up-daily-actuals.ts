import type { ConnectorEnv } from "./types";
import { dtgHistoricalRefreshWindows, type DtgShiftRule } from "./dtg-daily-actuals";

export type UpDailyActual = { operationalDate: string; garments: number; jobs: number; sourceEventCount: number; sourceMaxEventAt: string; calculationVersion: "UP_UNDERPRINT_EXIT_DAILY_V1" };
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const timestampPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/;
const numeric = (value: unknown, field: string) => { const parsed = Number(value); if (!Number.isFinite(parsed) || parsed < 0) throw new Error(`INVALID_UP_DAILY_${field}`); return parsed };
const upper = (value: unknown) => String(value ?? "").trim().toUpperCase();

export function isAuthoritativeUpCompletion(row: Record<string, unknown>) { const from = upper(row.FROM_LOCATION), to = upper(row.TO_LOCATION); return from.includes("UNDERPRINT") && Boolean(to) && !to.includes("UNDERPRINT") }
export function upJobIdentity(row: Record<string, unknown>) { for (const key of ["FROM_PACK_ID", "TO_PACK_ID", "ONO", "AUDIT_ID"]) { const value = String(row[key] ?? "").trim(); if (value) return value } throw new Error("MISSING_UP_JOB_IDENTITY") }
export function mapOracleUpDailyActual(row: Record<string, unknown>): UpDailyActual {
  if (numeric(row.INVALID_WEIGHT_COUNT ?? 0, "INVALID_WEIGHT_COUNT") > 0) throw new Error("MISSING_UP_WEIGHT");
  const operationalDate = String(row.OPERATIONAL_DATE ?? ""), sourceTimestamp = String(row.SOURCE_MAX_EVENT_AT ?? "");
  if (!datePattern.test(operationalDate)) throw new Error("INVALID_UP_OPERATIONAL_DATE");
  if (!timestampPattern.test(sourceTimestamp)) throw new Error("INVALID_UP_SOURCE_TIMESTAMP");
  return { operationalDate, garments: numeric(row.GARMENTS, "GARMENTS"), jobs: numeric(row.JOBS, "JOBS"), sourceEventCount: numeric(row.SOURCE_EVENT_COUNT, "SOURCE_EVENT_COUNT"), sourceMaxEventAt: `${sourceTimestamp}+10:00`, calculationVersion: "UP_UNDERPRINT_EXIT_DAILY_V1" };
}
const brisbaneDate = (date: Date) => new Intl.DateTimeFormat("en-CA", { timeZone: "Australia/Brisbane", year: "numeric", month: "2-digit", day: "2-digit" }).format(date);
export function upRefreshWindow(now = new Date()) { const to = brisbaneDate(now), start = new Date(`${to}T12:00:00Z`); start.setUTCDate(start.getUTCDate() - 6); return { from: start.toISOString().slice(0, 10), to } }
type UpAggregateReader = { readUpDailyActuals(from: string, to: string, rules: DtgShiftRule[]): Promise<UpDailyActual[]> };
export async function refreshUpDailyActuals(env: ConnectorEnv, source: UpAggregateReader, range = upRefreshWindow(), fetcher: typeof fetch = fetch) {
  const endpoint = `${env.INGEST_API_URL.replace(/\/$/, "")}/up-daily-actuals`, headers = { authorization: `Bearer ${env.INGEST_SECRET}`, "content-type": "application/json" };
  const rulesResponse = await fetcher(`${endpoint}?organizationId=${encodeURIComponent(env.ORGANIZATION_ID)}`, { method: "GET", headers });
  if (!rulesResponse.ok) throw new Error(`UP shift rules failed with HTTP ${rulesResponse.status}: ${await rulesResponse.text()}`);
  const payload = await rulesResponse.json() as { rules?: DtgShiftRule[] }; if (!Array.isArray(payload.rules) || !payload.rules.length) throw new Error("MISSING_UP_SHIFT_RULES");
  const rows = await source.readUpDailyActuals(range.from, range.to, payload.rules), response = await fetcher(endpoint, { method: "POST", headers, body: JSON.stringify({ organizationId: env.ORGANIZATION_ID, from: range.from, to: range.to, rows }) });
  if (!response.ok) throw new Error(`UP daily ingestion failed with HTTP ${response.status}: ${await response.text()}`); return response.json() as Promise<{ accepted: number }>;
}
export async function refreshUpHistoricalActuals(env: ConnectorEnv, source: UpAggregateReader, from: string, to: string, fetcher: typeof fetch = fetch) { const windows = dtgHistoricalRefreshWindows(from, to); let accepted = 0; for (const window of windows) accepted += (await refreshUpDailyActuals(env, source, window, fetcher)).accepted; return { accepted, windows: windows.length } }
