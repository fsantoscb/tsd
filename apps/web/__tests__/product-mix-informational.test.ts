import {describe,expect,it} from "vitest";
import {buildInformationalProductMix,type InformationalMixInput} from "../lib/product-mix-rules";

const row=(overrides:Partial<InformationalMixInput>={}):InformationalMixInput=>({recordKey:"a",orderNo:"SO1",productCode:"SKU1",productDescription:"MENS T - BLACK",quantity:10,state:"WAITING_FOR_PICKING",...overrides});

describe("machine load informational product mix",()=>{
  it("keeps physical waiting and ready quantities additive",()=>{const model=buildInformationalProductMix([row(),row({recordKey:"b",state:"READY_TO_PRINT",quantity:5})],false);expect(model.summary.activePhysicalQuantity).toBe(15);expect(model.reconciled).toBe(true)});
  it("hides Not Approved when toggle is off",()=>expect(buildInformationalProductMix([row({state:"NOT_APPROVED_INFORMATIONAL"})],false).summary.notApprovedProcessQuantity).toBe(0));
  it("shows Not Approved as separate process quantity",()=>{const model=buildInformationalProductMix([row(),row({recordKey:"p",orderNo:"SO2",state:"NOT_APPROVED_INFORMATIONAL",quantity:30})],true);expect(model.summary.activePhysicalQuantity).toBe(10);expect(model.summary.notApprovedProcessQuantity).toBe(30)});
  it("never adds potential process quantity to active physical quantity",()=>expect(buildInformationalProductMix([row(),row({recordKey:"p",orderNo:"SO2",state:"NOT_APPROVED_INFORMATIONAL",quantity:999})],true).summary.activePhysicalQuantity).toBe(10));
  it("excludes an active SO and SKU overlap from potential",()=>{const model=buildInformationalProductMix([row(),row({recordKey:"p",state:"NOT_APPROVED_INFORMATIONAL",quantity:20})],true);expect(model.summary.overlapExcluded).toBe(1);expect(model.summary.notApprovedProcessQuantity).toBe(0)});
  it("does not exclude a different Sales Order",()=>expect(buildInformationalProductMix([row(),row({recordKey:"p",orderNo:"SO2",state:"NOT_APPROVED_INFORMATIONAL"})],true).summary.notApprovedProcessQuantity).toBe(10));
  it("does not exclude a different SKU",()=>expect(buildInformationalProductMix([row(),row({recordKey:"p",productCode:"SKU2",state:"NOT_APPROVED_INFORMATIONAL"})],true).summary.notApprovedProcessQuantity).toBe(10));
  it("deduplicates identical source records",()=>expect(buildInformationalProductMix([row(),row()],false).summary.activePhysicalQuantity).toBe(10));
  it("ignores zero quantity",()=>expect(buildInformationalProductMix([row({quantity:0})],false).summary.activePhysicalQuantity).toBe(0));
  it("ignores negative quantity",()=>expect(buildInformationalProductMix([row({quantity:-1})],false).summary.activePhysicalQuantity).toBe(0));
  it("ignores non-finite quantity",()=>expect(buildInformationalProductMix([row({quantity:Number.NaN})],false).summary.activePhysicalQuantity).toBe(0));
  it("classifies adult T-shirts with the existing resolver",()=>expect(buildInformationalProductMix([row()],false).families.find(x=>x.family==="ADULT T-SHIRTS")?.activePhysicalTotal).toBe(10));
  it("classifies kids T-shirts",()=>expect(buildInformationalProductMix([row({productDescription:"BOYS T - BLUE"})],false).families.find(x=>x.family==="KIDS T-SHIRTS")?.activePhysicalTotal).toBe(10));
  it("classifies hoodies and sweats",()=>expect(buildInformationalProductMix([row({productDescription:"HOODIE - NAVY"})],false).families.find(x=>x.family==="HOODIES / SWEATS")?.activePhysicalTotal).toBe(10));
  it("surfaces unknown descriptions as unclassified Other",()=>{const model=buildInformationalProductMix([row({productDescription:"MYSTERY PRODUCT"})],false);expect(model.summary.unclassifiedActiveQuantity).toBe(10);expect(model.summary.activeCoveragePercent).toBe(0)});
  it("reports full coverage when all active records classify",()=>expect(buildInformationalProductMix([row()],false).summary.activeCoveragePercent).toBe(100));
  it("keeps detail quantity semantics physical for active",()=>expect(buildInformationalProductMix([row()],false).families.flatMap(x=>x.details)[0].quantitySemantics).toBe("PHYSICAL_SOURCE_QTY"));
  it("keeps detail quantity semantics process for potential",()=>expect(buildInformationalProductMix([row({state:"NOT_APPROVED_INFORMATIONAL",orderNo:"SO2"})],true).families.flatMap(x=>x.details)[0].quantitySemantics).toBe("PROCESS_QUANTITY"));
  it("preserves Sales Order identity in drilldown",()=>expect(buildInformationalProductMix([row({orderNo:"SO99"})],false).families.flatMap(x=>x.details)[0].orderNo).toBe("SO99"));
  it("counts active and potential orders independently",()=>{const family=buildInformationalProductMix([row(),row({recordKey:"p",orderNo:"SO2",state:"NOT_APPROVED_INFORMATIONAL"})],true).families.find(x=>x.family==="ADULT T-SHIRTS");expect(family?.activeOrders).toBe(1);expect(family?.potentialOrders).toBe(1)});
  it("does not mutate source input or operational values",()=>{const input=[row()],before=structuredClone(input);buildInformationalProductMix(input,true);expect(input).toEqual(before)});
});
