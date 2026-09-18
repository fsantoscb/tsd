import{describe,expect,it}from"vitest";import{canonicalMaintenanceStatus,capacityAuthority,capacityMigrationKey,maintenanceMigrationKey,migrationDisposition,observedTimer,preservesPreventiveSchedule,separateCapacityFromWorkload}from"../lib/capacity-maintenance-parity-rules";
describe("C5.6 capacity parity",()=>{
 it("treats capacity as planning configuration",()=>expect(capacityAuthority()).toBe("PLANNING_CONFIGURATION"));
 it("uses stable source identity for idempotency",()=>expect(capacityMigrationKey("ORG","DTG","PCP")).toBe("ORG:DTG:PCP"));
 it("never adds capacity to workload",()=>expect(separateCapacityFromWorkload(100,150)).toEqual({capacity:100,workload:150,loadPercent:150}));
 it("keeps zero capacity unavailable as a denominator",()=>expect(separateCapacityFromWorkload(0,20).loadPercent).toBeNull());
});
describe("C5.6 maintenance parity",()=>{
 it("maps requested work to the scheduled lifecycle",()=>expect(canonicalMaintenanceStatus("REQUESTED")).toBe("SCHEDULED"));
 it("maps waiting maintenance to open without inventing progress",()=>expect(canonicalMaintenanceStatus("WAITING_MAINTENANCE")).toBe("OPEN"));
 it("maps completed and operator states",()=>{expect(canonicalMaintenanceStatus("completed")).toBe("COMPLETED");expect(canonicalMaintenanceStatus("OPEN_OPERATOR")).toBe("OPEN")});
 it("rejects unknown statuses",()=>expect(canonicalMaintenanceStatus("mystery")).toBeNull());
 it("uses stable work-order identity and dispositions",()=>{expect(maintenanceMigrationKey("ORG","WO1")).toBe("ORG:WO1");expect(migrationDisposition("completed")).toBe("MIGRATE_HISTORY");expect(migrationDisposition("REQUESTED")).toBe("MIGRATE_ACTIVE")});
 it("does not manufacture timer precision",()=>{expect(observedTimer(null)).toBe("NOT_OBSERVED");expect(observedTimer(12)).toBe(12)});
 it("never advances a preventive schedule during migration",()=>expect(preservesPreventiveSchedule(true)).toEqual({migrateWorkOrder:true,mutatePreventivePlan:false,hasPlan:true}));
});
