import{describe,expect,it}from"vitest";import{auditMigrationKey,classifyAuditFamily,dtgHistoryIsDerived,separateCurrentAndHistory}from"../lib/history-authority-rules";
describe("audit and DTG history authority",()=>{
 it("classifies every movement into an explicit family",()=>{expect(classifyAuditFamily({fromZone:"PG11",toZone:"DTGS"})).toBe("DTG_PICK");expect(classifyAuditFamily({fromZone:"DTGS",toZone:"PWL1"})).toBe("DTG_PRINT");expect(classifyAuditFamily({toLocation:"DTGMOVE"})).toBe("DTG_DISPATCH");expect(classifyAuditFamily({toLocation:"UNDERPRINT"})).toBe("UP_IN");expect(classifyAuditFamily({fromLocation:"Underprint",toLocation:"DESP"})).toBe("UP_OUT");expect(classifyAuditFamily({fromZone:"DESP",toZone:"DESP"})).toBe("OTHER_ORACLE_MOVEMENT")});
 it("uses stable source identity for idempotent migration",()=>expect(auditMigrationKey("ORG","12705793")).toBe("ORG:12705793"));
 it("defines DTG history as derived from immutable audit events",()=>expect(dtgHistoryIsDerived()).toBe(true));
 it("never adds historical production to current Workbank load",()=>expect(separateCurrentAndHistory(100,900)).toEqual({currentLoad:100,historicalProduction:900}));
});
