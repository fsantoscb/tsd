export const ROUTING_STATUSES = ["DRAFT", "ACTIVE", "INACTIVE"] as const;

export type RoutingStep = { id: string; sequence: number; operationCode: string; required: boolean };

export function normalizeRoutingCode(value: unknown): string {
  return String(value ?? "").trim().toUpperCase().replace(/[ -]+/g, "_");
}

export function orderedRoutingSteps<T extends { sequence: number }>(steps: T[]): T[] {
  return [...steps].sort((a, b) => a.sequence - b.sequence);
}

export function nextRoutingRevision(revisions: Array<{ revision: number }>): number {
  return revisions.reduce((max, item) => Math.max(max, item.revision), 0) + 1;
}

export function hasUniquePositiveSequences(steps: Array<{ sequence: number }>): boolean {
  const sequences = steps.map((step) => step.sequence);
  return sequences.every((sequence) => Number.isInteger(sequence) && sequence > 0) && new Set(sequences).size === sequences.length;
}
