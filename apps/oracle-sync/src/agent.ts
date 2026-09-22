import os from "node:os";
import type { ConnectorEnv } from "./types";
import { OracleSourceReader } from "./source-reader";
import { syncOnce } from "./sync";
import { refreshDtgDailyActuals } from "./dtg-daily-actuals";
import { refreshDtgOrderHistory } from "./dtg-order-history";
import { refreshUpDailyActuals } from "./up-daily-actuals";

type Claim = { runId: string; requestId: string | null; triggerType: "AUTOMATIC" | "MANUAL"; shouldExecute: boolean };
const base = (env: ConnectorEnv) => env.INGEST_API_URL.replace(/\/$/, "");

async function request(env: ConnectorEnv, path: string, init: RequestInit) {
  const response = await fetch(base(env) + path, { ...init, headers: { authorization: `Bearer ${env.INGEST_SECRET}`, "content-type": "application/json", ...init.headers } });
  if (!response.ok) throw new Error(`Control API ${path} failed with HTTP ${response.status}: ${await response.text()}`);
  return response.json();
}

async function api(env: ConnectorEnv, path: string, body: unknown) {
  return request(env, path, { method: "POST", body: JSON.stringify(body) });
}

export async function assertExpectedTarget(env: ConnectorEnv) {
  const identity = await request(env, "/organization", { method: "GET" }) as { organizationId?: string; projectRef?: string };
  if (identity.organizationId !== env.ORGANIZATION_ID) throw new Error("SYNC_TARGET_ORGANIZATION_MISMATCH");
  if (identity.projectRef !== env.EXPECTED_SUPABASE_PROJECT_REF) throw new Error(`SYNC_TARGET_PROJECT_MISMATCH expected=${env.EXPECTED_SUPABASE_PROJECT_REF} actual=${identity.projectRef ?? "unknown"}`);
  return identity;
}

export async function heartbeat(env: ConnectorEnv, state: { status: "online" | "degraded"; lastError: string | null; lastSyncAttemptAt?: string | null; lastSuccessAt?: string | null; nextExpectedSyncAt?: string | null; currentRunId?: string | null }) {
  await api(env, "/heartbeat", { organizationId: env.ORGANIZATION_ID, agentId: env.AGENT_ID, version: env.CONNECTOR_VERSION, hostname: os.hostname(), ...state });
}

export async function heartbeatOnce(env: ConnectorEnv) {
  const identity = await assertExpectedTarget(env);
  await heartbeat(env, { status: "online", lastError: null, currentRunId: null, nextExpectedSyncAt: null });
  return identity;
}

export async function claimWork(env: ConnectorEnv) {
  return api(env, "/control", { action: "claim", organizationId: env.ORGANIZATION_ID, agentId: env.AGENT_ID, connectorVersion: env.CONNECTOR_VERSION, intervalSeconds: env.SYNC_INTERVAL_SECONDS }) as Promise<Claim | null>;
}

const wait = (milliseconds: number) => new Promise((resolve) => setTimeout(resolve, milliseconds));

export async function executeClaim(env: ConnectorEnv, claim: Claim, sleeper = wait) {
  const started = Date.now(), attemptAt = new Date().toISOString();
  await heartbeat(env, { status: "online", lastError: null, lastSyncAttemptAt: attemptAt, currentRunId: claim.runId, nextExpectedSyncAt: new Date(Date.now() + env.SYNC_INTERVAL_SECONDS * 1000).toISOString() });
  let last: unknown;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    const source = new OracleSourceReader(env);
    try {
      const result = await syncOnce(env, source);
      const dtgOrderHistory = await refreshDtgOrderHistory(env, source, await source.readActiveDtgOrderNos());
      const dtgDaily = await refreshDtgDailyActuals(env, source);
      const upDaily = await refreshUpDailyActuals(env, source);
      await api(env, "/control", { action: "finish", runId: claim.runId, status: "SUCCESS", batchId: result.batchId, durationMs: Date.now() - started, ...result.counts });
      await heartbeat(env, { status: "online", lastError: null, lastSyncAttemptAt: attemptAt, lastSuccessAt: new Date().toISOString(), currentRunId: null, nextExpectedSyncAt: new Date(Date.now() + env.SYNC_INTERVAL_SECONDS * 1000).toISOString() });
      return {...result,dtgOrderHistory:dtgOrderHistory.accepted,dtgDailyActuals:dtgDaily.accepted,upDailyActuals:upDaily.accepted};
    } catch (error) {
      last = error;
      if (attempt < 3) await sleeper(attempt * 15000);
    } finally {
      await source.close();
    }
  }
  const message = last instanceof Error ? last.message : "Unknown connector failure";
  await api(env, "/control", { action: "finish", runId: claim.runId, status: "FAILED", batchId: null, durationMs: Date.now() - started, orders: 0, workbank: 0, stock: 0, audit: 0, failureReason: message });
  await heartbeat(env, { status: "degraded", lastError: message, lastSyncAttemptAt: attemptAt, currentRunId: null, nextExpectedSyncAt: new Date(Date.now() + env.SYNC_INTERVAL_SECONDS * 1000).toISOString() });
  throw last;
}

export async function agentTick(env: ConnectorEnv) {
  await assertExpectedTarget(env);
  await heartbeat(env, { status: "online", lastError: null, currentRunId: null, nextExpectedSyncAt: new Date(Date.now() + env.SYNC_INTERVAL_SECONDS * 1000).toISOString() });
  const claim = await claimWork(env);
  if (!claim || !claim.shouldExecute) return { status: "IDLE" as const };
  return { status: "EXECUTED" as const, result: await executeClaim(env, claim), triggerType: claim.triggerType };
}
