export type CanonicalMaintenanceStatus="OPEN"|"IN_PROGRESS"|"WAITING_FOR_PARTS"|"SCHEDULED"|"COMPLETED"|"CANCELLED";

export function canonicalMaintenanceStatus(status:string):CanonicalMaintenanceStatus|null{
 const value=status.trim();
 const map:Record<string,CanonicalMaintenanceStatus>={open:"OPEN",OPEN_OPERATOR:"OPEN",WAITING_MAINTENANCE:"OPEN",in_progress:"IN_PROGRESS",waiting_parts:"WAITING_FOR_PARTS",waiting_external:"WAITING_FOR_PARTS",REQUESTED:"SCHEDULED",completed:"COMPLETED",cancelled:"CANCELLED"};
 return map[value]??null;
}

export function capacityAuthority(){return"PLANNING_CONFIGURATION" as const}
export function capacityMigrationKey(organizationId:string,areaId:string,sourceName:string){return`${organizationId}:${areaId}:${sourceName}`}
export function separateCapacityFromWorkload(capacity:number,workload:number){return{capacity,workload,loadPercent:capacity>0?workload/capacity*100:null}}
export function maintenanceMigrationKey(organizationId:string,workOrderId:string){return`${organizationId}:${workOrderId}`}
export function migrationDisposition(status:string){return canonicalMaintenanceStatus(status)==="COMPLETED"?"MIGRATE_HISTORY" as const:"MIGRATE_ACTIVE" as const}
export function observedTimer<T>(value:T|null|undefined){return value==null?"NOT_OBSERVED" as const:value}
export function preservesPreventiveSchedule(hasPlan:boolean){return{migrateWorkOrder:true,mutatePreventivePlan:false,hasPlan}}
