export type MaintenanceStatus="open"|"scheduled"|"in_progress"|"waiting_parts"|"waiting_external"|"completed"|"cancelled"|"OPEN_OPERATOR"|"WAITING_MAINTENANCE"|"REQUESTED";
const active=new Set<MaintenanceStatus>(["open","scheduled","in_progress","waiting_parts","waiting_external","OPEN_OPERATOR","WAITING_MAINTENANCE","REQUESTED"]);
export const isActiveMaintenance=(status:string)=>active.has(status as MaintenanceStatus);
export const canOperateMaintenance=(role:string)=>["maintenance","supervisor","manager","admin"].includes(role);
export const canCompleteMaintenance=(role:string,status:string)=>(canOperateMaintenance(role)||role==="operator"&&status==="OPEN_OPERATOR")&&["open","in_progress","waiting_parts","waiting_external","OPEN_OPERATOR"].includes(status);
export const canCancelMaintenance=(role:string,status:string)=>["maintenance","supervisor","manager","admin"].includes(role)&&isActiveMaintenance(status);
export const canReopenMaintenance=(role:string,status:string)=>["supervisor","manager","admin"].includes(role)&&status==="completed";
export const canDeleteMaintenance=(role:string,status:string,hasActivity:boolean,preventive:boolean)=>["manager","admin"].includes(role)&&status==="open"&&!hasActivity&&!preventive;
export const maintenancePriorityRank=(priority:string)=>({critical:0,high:1,medium:2,low:3}[priority]??4);
