export type AuditFamily="DTG_PICK"|"DTG_PRINT"|"DTG_DISPATCH"|"UP_IN"|"UP_OUT"|"OTHER_ORACLE_MOVEMENT";
export type AuditRow={fromZone?:string|null;toZone?:string|null;fromLocation?:string|null;toLocation?:string|null};
const upper=(value:string|null|undefined)=>value?.trim().toUpperCase()??"";
export function classifyAuditFamily(row:AuditRow):AuditFamily{const fromZone=upper(row.fromZone),toZone=upper(row.toZone),fromLocation=upper(row.fromLocation),toLocation=upper(row.toLocation);if(fromZone==="PG11"&&toZone==="DTGS")return"DTG_PICK";if(fromZone==="DTGS"&&toZone==="PWL1")return"DTG_PRINT";if(toLocation==="DTGMOVE")return"DTG_DISPATCH";if(toLocation.includes("UNDERPRINT"))return"UP_IN";if(fromLocation.includes("UNDERPRINT")&&!toLocation.includes("UNDERPRINT"))return"UP_OUT";return"OTHER_ORACLE_MOVEMENT"}
export const auditMigrationKey=(organizationId:string,sourceAuditId:string)=>`${organizationId}:${sourceAuditId}`;
export const dtgHistoryIsDerived=()=>true;
export function separateCurrentAndHistory(currentUnits:number,historicalUnits:number){return{currentLoad:currentUnits,historicalProduction:historicalUnits}}
