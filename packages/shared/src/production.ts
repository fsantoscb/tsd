import { z } from "zod";
export const productionStatusSchema=z.enum(["unplanned","planned","ready","in_progress","blocked","waiting","completed","cancelled"]);
export const sourceIdentifierSchema=z.string().trim().min(1);
export const sourceQuantitySchema=z.object({sourceQty:z.number().nullable(),sourceWeight:z.number().nullable(),productionUnits:z.number()});
export type ProductionStatus=z.infer<typeof productionStatusSchema>;
