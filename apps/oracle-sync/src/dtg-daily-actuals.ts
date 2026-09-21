import type { ConnectorEnv } from "./types";

export type DtgShiftRule = {
  weekday: number;
  shiftCode: "SHIFT_1" | "SHIFT_2" | "SHIFT_3" | "OVERTIME";
  displayName: string;
  startTime: string;
  endTime: string;
  crossMidnight: boolean;
  effectiveFrom: string;
  effectiveTo: string | null;
};

export type DtgDailyActual = {
  operationalDate: string;
  process: "DTG";
  machineCode: string;
  shiftCode: "SHIFT_1" | "SHIFT_2" | "SHIFT_3" | "OVERTIME" | "OUT_OF_SHIFT";
  garments: number;
  prints: number;
  sourceEventCount: number;
  sourceMinAuditId: string;
  sourceMaxAuditId: string;
  sourceMaxEventAt: string;
  calculationVersion: "DTG_PCOR_SHIFT_V2";
};

const numeric = (value: unknown, field: string) => {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 0) throw new Error(`INVALID_DTG_DAILY_${field}`);
  return parsed;
};
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const localTimestampPattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/;
const shiftCodes = new Set(["SHIFT_1", "SHIFT_2", "SHIFT_3", "OVERTIME", "OUT_OF_SHIFT"]);

export function isAuthoritativeDtgCompletion(row: Record<string, unknown>) {
  const value = (key: string) => String(row[key] ?? "").trim().toUpperCase();
  return value("FROM_ZONE") === "DTGS" && value("TO_ZONE") === "PWL1" && value("ISIS_TASK") === "PCOR" && value("QUEUE") === "PCOR";
}

export function mapOracleDtgDailyActual(row: Record<string, unknown>): DtgDailyActual {
  if (numeric(row.INVALID_MULTIPLIER_COUNT ?? 0, "MULTIPLIER") > 0) throw new Error("UNSUPPORTED_DTG_PRINT_MULTIPLIER");
  const operationalDate = String(row.OPERATIONAL_DATE ?? "");
  if (!datePattern.test(operationalDate)) throw new Error("INVALID_DTG_OPERATIONAL_DATE");
  const shiftCode = String(row.SHIFT_CODE ?? "OUT_OF_SHIFT").toUpperCase();
  if (!shiftCodes.has(shiftCode)) throw new Error("INVALID_DTG_SHIFT_CODE");
  const sourceLocal = String(row.SOURCE_MAX_EVENT_AT ?? "");
  if (!localTimestampPattern.test(sourceLocal)) throw new Error("INVALID_DTG_SOURCE_TIMESTAMP");
  return {
    operationalDate,
    process: "DTG",
    machineCode: String(row.MACHINE_CODE ?? "").trim().toUpperCase() || "UNATTRIBUTED",
    shiftCode: shiftCode as DtgDailyActual["shiftCode"],
    garments: numeric(row.GARMENTS, "GARMENTS"),
    prints: numeric(row.PRINTS, "PRINTS"),
    sourceEventCount: numeric(row.SOURCE_EVENT_COUNT, "SOURCE_EVENT_COUNT"),
    sourceMinAuditId: String(row.SOURCE_MIN_AUDIT_ID ?? ""),
    sourceMaxAuditId: String(row.SOURCE_MAX_AUDIT_ID ?? ""),
    sourceMaxEventAt: `${sourceLocal}+10:00`,
    calculationVersion: "DTG_PCOR_SHIFT_V2",
  };
}

const brisbaneDate = (date: Date) => new Intl.DateTimeFormat("en-CA", { timeZone: "Australia/Brisbane", year: "numeric", month: "2-digit", day: "2-digit" }).format(date);
export function dtgRefreshWindow(now = new Date()) {
  const to = brisbaneDate(now), start = new Date(`${to}T12:00:00Z`);
  start.setUTCDate(start.getUTCDate() - 6);
  return { from: start.toISOString().slice(0, 10), to };
}

export function dtgHistoricalRefreshWindows(from: string, to: string) {
  if (!datePattern.test(from) || !datePattern.test(to) || from > to) throw new Error("INVALID_DTG_REFRESH_RANGE");
  const windows: Array<{ from: string; to: string }> = [];
  let cursor = from;
  while (cursor <= to) {
    const value = new Date(`${cursor}T12:00:00Z`);
    const monthEnd = new Date(Date.UTC(value.getUTCFullYear(), value.getUTCMonth() + 1, 0, 12)).toISOString().slice(0, 10);
    const end = monthEnd < to ? monthEnd : to;
    windows.push({ from: cursor, to: end });
    const next = new Date(`${end}T12:00:00Z`); next.setUTCDate(next.getUTCDate() + 1); cursor = next.toISOString().slice(0, 10);
  }
  return windows;
}

const seconds = (value: string) => {
  const match = /^(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(value);
  if (!match) throw new Error("INVALID_DTG_SHIFT_TIME");
  return Number(match[1]) * 3600 + Number(match[2]) * 60 + Number(match[3] ?? 0);
};
const isoWeekday = (date: string) => { const day = new Date(`${date}T00:00:00Z`).getUTCDay(); return day === 0 ? 7 : day; };
const previousDate = (date: string) => { const value = new Date(`${date}T12:00:00Z`); value.setUTCDate(value.getUTCDate() - 1); return value.toISOString().slice(0, 10); };

export function assignDtgOperationalShift(sourceTimestampLocal: string, rules: DtgShiftRule[]) {
  if (!localTimestampPattern.test(sourceTimestampLocal)) throw new Error("INVALID_DTG_SOURCE_TIMESTAMP");
  const calendarDate = sourceTimestampLocal.slice(0, 10), eventSeconds = seconds(sourceTimestampLocal.slice(11));
  const ordered = [...rules].sort((a, b) => b.effectiveFrom.localeCompare(a.effectiveFrom));
  for (const rule of ordered) {
    const start = seconds(rule.startTime), end = seconds(rule.endTime);
    const operationalDate = rule.crossMidnight && eventSeconds < end ? previousDate(calendarDate) : calendarDate;
    const effective = rule.effectiveFrom <= operationalDate && (!rule.effectiveTo || rule.effectiveTo >= operationalDate);
    const timeMatches = rule.crossMidnight ? eventSeconds >= start || eventSeconds < end : eventSeconds >= start && eventSeconds < end;
    if (effective && rule.weekday === isoWeekday(operationalDate) && timeMatches) return { operationalDate, shiftCode: rule.shiftCode };
  }
  return { operationalDate: calendarDate, shiftCode: "OUT_OF_SHIFT" as const };
}

export function oracleShiftRuleCte(rules: DtgShiftRule[]) {
  if (!rules.length) throw new Error("MISSING_DTG_SHIFT_RULES");
  const binds: Record<string, string | number | null> = {};
  const sql = rules.map((rule, index) => {
    if (rule.weekday < 1 || rule.weekday > 7 || !datePattern.test(rule.effectiveFrom) || (rule.effectiveTo && !datePattern.test(rule.effectiveTo))) throw new Error("INVALID_DTG_SHIFT_RULE");
    binds[`weekday_${index}`] = rule.weekday; binds[`shift_${index}`] = rule.shiftCode; binds[`start_${index}`] = seconds(rule.startTime); binds[`end_${index}`] = seconds(rule.endTime); binds[`cross_${index}`] = rule.crossMidnight ? 1 : 0; binds[`effective_from_${index}`] = rule.effectiveFrom; binds[`effective_to_${index}`] = rule.effectiveTo;
    return `select :weekday_${index} weekday,:shift_${index} shift_code,:start_${index} start_seconds,:end_${index} end_seconds,:cross_${index} cross_midnight,to_date(:effective_from_${index},'YYYY-MM-DD') effective_from,to_date(:effective_to_${index},'YYYY-MM-DD') effective_to from dual`;
  }).join(" union all ");
  return { sql, binds };
}

type DtgAggregateReader = { readDtgDailyActuals(from: string, to: string, rules: DtgShiftRule[]): Promise<DtgDailyActual[]> };
export async function refreshDtgDailyActuals(env: ConnectorEnv, source: DtgAggregateReader, range = dtgRefreshWindow(), fetcher: typeof fetch = fetch) {
  const endpoint = `${env.INGEST_API_URL.replace(/\/$/, "")}/dtg-daily-actuals`, headers = { authorization: `Bearer ${env.INGEST_SECRET}`, "content-type": "application/json" };
  const rulesResponse = await fetcher(`${endpoint}?organizationId=${encodeURIComponent(env.ORGANIZATION_ID)}`, { method: "GET", headers });
  if (!rulesResponse.ok) throw new Error(`DTG shift rules failed with HTTP ${rulesResponse.status}: ${await rulesResponse.text()}`);
  const rulesPayload = await rulesResponse.json() as { rules?: DtgShiftRule[] };
  if (!Array.isArray(rulesPayload.rules) || !rulesPayload.rules.length) throw new Error("MISSING_DTG_SHIFT_RULES");
  const rows = await source.readDtgDailyActuals(range.from, range.to, rulesPayload.rules);
  const response = await fetcher(endpoint, { method: "POST", headers, body: JSON.stringify({ organizationId: env.ORGANIZATION_ID, from: range.from, to: range.to, rows }) });
  if (!response.ok) throw new Error(`DTG daily ingestion failed with HTTP ${response.status}: ${await response.text()}`);
  return response.json() as Promise<{ accepted: number }>;
}

export async function refreshDtgHistoricalActuals(env: ConnectorEnv, source: DtgAggregateReader, from: string, to: string, fetcher: typeof fetch = fetch) {
  const windows = dtgHistoricalRefreshWindows(from, to);
  let accepted = 0;
  for (const window of windows) {
    const result = await refreshDtgDailyActuals(env, source, window, fetcher);
    accepted += result.accepted;
  }
  return { accepted, windows: windows.length };
}
