import { z } from "zod";

const id = z.string().trim().min(1);
const nullableNumber = z.number().finite().nullable();

export const sourceOrderSchema = z.object({
  orderNo:id, dateReceived:z.string().datetime().nullable(), dateDue:z.string().datetime().nullable(),
  dateReleased:z.string().datetime().nullable(), sourceStatus:z.string().nullable(), sourceSubStatus:z.string().nullable(),
  customerCode:z.string().nullable(), customerName:z.string().nullable(), shipToName:z.string().nullable(),
  customerState:z.string().nullable(), city:z.string().nullable(), deliveryDesc:z.string().nullable(),
  clientSoNumber:z.string().nullable(), sourcePriority:z.number().int().nullable(), site:z.string().nullable().optional(),
  routeId:z.string().nullable().optional(), costCentre:z.string().nullable().optional(), stopShipFlag:z.string().nullable().optional(), releaseSourceStatus:z.string().nullable().optional(), sourceUpdatedAt:z.string().datetime().nullable(),
});
export const releaseOrderLineSchema=z.object({
  orderNo:id,lineNumber:id,product:z.string().nullable(),client:z.string().nullable(),qtyLcd:z.number().finite(),origRef3:z.string().nullable(),
  released:z.string().nullable(),groupCode:z.string().nullable(),productName:z.string().nullable(),sourceUpdatedAt:z.string().datetime().nullable(),
});
export const workbankItemSchema = z.object({
  sourceRowId:id.nullable(), orderNo:id, customerCode:z.string().nullable(), customerName:z.string().nullable(),
  sourceDueAt:z.string().datetime().nullable(), fromLocation:z.string().nullable(), fromZone:z.string().nullable(),
  toLocation:z.string().nullable(), fromPackId:id.nullable(), toPackId:id.nullable(), sourcePriority:z.number().int().nullable(),
  productCode:z.string().nullable(), productDescription:z.string().nullable(), productGroup:z.string().nullable(),
  sourceQty:nullableNumber, sourceWeight:nullableNumber, productionUnits:z.number().finite(), printsPerGarment:nullableNumber, queue:z.string(), task:z.string().nullable(),
});
export const stockItemSchema = z.object({
  product:z.string(), packId:id, location:z.string(), sourceZone:z.string().nullable(), sourceTimestamp:z.string().datetime().nullable(),
  sourceQty:nullableNumber, sourceWeight:nullableNumber, productionUnits:z.number().finite(),
});
export const auditEventSchema = z.object({
  sourceAuditId:id.nullable(), orderNo:id, username:z.string().nullable(), fromZone:z.string().nullable(),
  toZone:z.string().nullable(), fromLocation:z.string().nullable(), toLocation:z.string().nullable(),
  product:z.string().nullable(), fromPackId:id.nullable(), toPackId:id.nullable(), sourceQty:nullableNumber,
  sourceWeight:nullableNumber, productionUnits:z.number().finite(), eventAt:z.string().datetime(), rawHash:id,
  queue:z.string().nullable().optional(), task:z.string().nullable().optional(),
});
export const syncPayloadSchema=z.object({
  organizationId:z.string().uuid(), agentId:id, connectorVersion:id,
  orders:z.array(sourceOrderSchema), releaseOrderLines:z.array(releaseOrderLineSchema).default([]), workbank:z.array(workbankItemSchema), stock:z.array(stockItemSchema), auditEvents:z.array(auditEventSchema),
});
export const heartbeatSchema=z.object({
  organizationId:z.string().uuid(), agentId:id, version:id, hostname:z.string().nullable(), status:z.enum(["online","degraded","offline"]), lastError:z.string().nullable(),
  lastSyncAttemptAt:z.string().datetime().nullable().optional(),lastSuccessAt:z.string().datetime().nullable().optional(),nextExpectedSyncAt:z.string().datetime().nullable().optional(),currentRunId:z.string().uuid().nullable().optional(),
});
export type SyncPayload=z.infer<typeof syncPayloadSchema>;
