export type ReleaseEvidence={routeId:string|null;costCentre:string|null;stopShipFlag:string|null;dueDate:string|null;sourceStatus:string|null;customEmbQty:number;totalProcessQty:number};
export type ReleaseStatus="ELIGIBLE"|"NOT_APPROVED"|"BLOCKED"|"FUTURE_DUE"|"UNKNOWN";
export const isReleaseQueueProcessAllowed=(process:string|null|undefined)=>!["SCREEN_PRINT","PAK7"].includes(process?.trim().toUpperCase()??"");
export function resolveRelease(e:ReleaseEvidence,today=new Date()):{status:ReleaseStatus;blockers:string[];diagnostic:string|null}{
 const blockers:string[]=[];
 if(e.routeId?.trim().toUpperCase()==="NO")blockers.push("ROUTE_BLOCKED");
 if(e.stopShipFlag?.trim().toUpperCase()==="Y")blockers.push("STOP_SHIP");
 if(e.customEmbQty>0)blockers.push("CUSTOM_EMB");
 const diagnostic=e.totalProcessQty<=0?"ZERO_PRODUCTION_QTY":null;
 if(!e.routeId?.trim()||!e.stopShipFlag?.trim()||!e.dueDate||!e.sourceStatus?.trim())return{status:"UNKNOWN",blockers,diagnostic};
 if(e.costCentre?.trim().toUpperCase()==="NOTAPPRO")return{status:"NOT_APPROVED",blockers,diagnostic};
 if(blockers.length)return{status:"BLOCKED",blockers,diagnostic};
 const cutoff=new Date(today);cutoff.setHours(0,0,0,0);cutoff.setDate(cutoff.getDate()+7);
 if(new Date(e.dueDate)>cutoff)return{status:"FUTURE_DUE",blockers,diagnostic};
 return{status:"ELIGIBLE",blockers,diagnostic};
}
