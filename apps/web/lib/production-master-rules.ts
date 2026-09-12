export const MASTER_CODE_PATTERN = /^[A-Z0-9_-]+$/;

export function normalizeMasterCode(value: unknown): string {
  return String(value ?? "").trim().toUpperCase();
}

export function isCanonicalMasterCode(value: unknown): boolean {
  const normalized = normalizeMasterCode(value);
  return normalized.length > 0 && normalized.length <= 60 && MASTER_CODE_PATTERN.test(normalized);
}

export function normalizeSourceOperation(value: unknown, canonicalCodes: Iterable<string>): string {
  const normalized = normalizeMasterCode(value);
  const known = new Set(Array.from(canonicalCodes, normalizeMasterCode));
  return known.has(normalized) ? normalized : "UNMAPPED";
}
