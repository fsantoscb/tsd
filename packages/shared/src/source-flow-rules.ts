export type SourceValue=string|null|undefined;

export const normalizeSourceValue=(value:SourceValue)=>String(value??"").trim().toUpperCase();
export const isDtgPicking=(queue:SourceValue)=>normalizeSourceValue(queue)==="SP11";
export const isDtgPrinting=(queue:SourceValue)=>normalizeSourceValue(queue)==="PCOR";
export const isDtgPutwall=(fromZone:SourceValue)=>normalizeSourceValue(fromZone)==="PWL1";
export const isDtgDispatch=(toLocation:SourceValue)=>normalizeSourceValue(toLocation)==="DTGMOVE";
export const isUpPicking=(location:SourceValue)=>normalizeSourceValue(location)==="UNDERPRINT";
export const isUpPrinting=(fromLocation:SourceValue)=>normalizeSourceValue(fromLocation).endsWith("UP");
export const isUpDispatch=(toLocation:SourceValue)=>normalizeSourceValue(toLocation)==="UPMOVE";
