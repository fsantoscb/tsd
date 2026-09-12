export const PRODUCTION_MIX_GROUPS = [
  "ADULT T-SHIRTS", "KIDS T-SHIRTS", "HOODIES / SWEATS", "TANKS / SINGLETS",
  "LONG-SLEEVE T-SHIRTS", "DRESSES", "TOTES", "OTHER",
] as const;

export type ProductionMixGroup = typeof PRODUCTION_MIX_GROUPS[number];
export type ProductionMixStatus = "Awaiting Picking" | "Ready to Print";

const ADULT = new Set(["MENS T", "WOMENS T"]);
const KIDS = new Set(["BOYS T", "GIRLS T"]);
const LONG_SLEEVE = new Set(["MENS L/S T", "WOMENS L/S T", "BOYS L/S T", "GIRLS L/S T"]);
const TANKS = new Set(["MENS TANK", "WOMENS TANK", "MENS SINGLET", "WOMENS SINGLET"]);
const SWEATS = new Set(["HOODY", "HOODIE", "ZIP HOODY", "ZIP THRU HOODY", "CREW", "CREW JUMPER", "RAGLAN CREW", "RAGLAN HOODY", "LIGHTWEIGHT HOODY", "1/4 ZIP", "DAYBREAKER PULLOVER"]);

export function extractProductType(description: string | null) {
  return (description ?? "").split(" - ", 1)[0].trim().toUpperCase();
}

export function classifyProductType(type: string): ProductionMixGroup {
  if (LONG_SLEEVE.has(type)) return "LONG-SLEEVE T-SHIRTS";
  if (TANKS.has(type)) return "TANKS / SINGLETS";
  if ([...SWEATS].some(value => type === value || type.endsWith(` ${value}`))) return "HOODIES / SWEATS";
  if (ADULT.has(type)) return "ADULT T-SHIRTS";
  if (KIDS.has(type)) return "KIDS T-SHIRTS";
  if (type.includes("DRESS")) return "DRESSES";
  if (type.includes("TOTE") || type.includes("BAG")) return "TOTES";
  return "OTHER";
}

export function isExplicitlyClassified(type: string) {
  return Boolean(type) && classifyProductType(type) !== "OTHER";
}
