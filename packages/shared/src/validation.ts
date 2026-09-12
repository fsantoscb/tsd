export function isNonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}
export function assertExternalId(value: unknown): string {
  if (typeof value !== "string" || !value.trim()) throw new Error("External source identifiers must be non-empty strings");
  return value;
}

export function parsePositiveInt(value: unknown): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0 || !Number.isInteger(parsed)) {
    throw new Error("Expected positive integer");
  }
  return parsed;
}
