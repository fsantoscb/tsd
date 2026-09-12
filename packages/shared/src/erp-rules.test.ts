import{describe,expect,it}from"vitest";
import{calculateKpis}from"./kpi-engine";
import{calculatePutwallSnapshot}from"./flow-metrics";
import{segmentLabour}from"./labour-segmentation";
import{DEFAULT_SHIFT_RULES,resolveProductionShift}from"./shift-resolver";
import{recommendShiftPlan}from"./planning-capacity";

const at=(local:string)=>new Date(`${local}+10:00`);

describe("ERP shift rules",()=>{
  it("resolves weekday and Friday boundaries",()=>{
    expect(resolveProductionShift(at("2026-09-09T06:00:00"),DEFAULT_SHIFT_RULES).shift).toBe("SHIFT_1");
    expect(resolveProductionShift(at("2026-09-09T14:30:00"),DEFAULT_SHIFT_RULES).shift).toBe("SHIFT_2");
    expect(resolveProductionShift(at("2026-09-11T18:00:00"),DEFAULT_SHIFT_RULES).shift).toBe("SHIFT_3");
  });
  it("owns a cross-midnight event by the shift start date",()=>{
    expect(resolveProductionShift(at("2026-09-10T02:00:00"),DEFAULT_SHIFT_RULES)).toMatchObject({shift:"SHIFT_3",calendarDate:"2026-09-10",operationalDate:"2026-09-09"});
  });
  it("supports early tolerance and unconfirmed shift 3 overtime",()=>{
    expect(resolveProductionShift(at("2026-09-09T05:50:00"),DEFAULT_SHIFT_RULES,{applyEarlyTolerance:true,activeShiftCodes:new Set(["SHIFT_1"])})).toMatchObject({shift:"SHIFT_1",usedEarlyTolerance:true});
    expect(resolveProductionShift(at("2026-09-09T23:10:00"),DEFAULT_SHIFT_RULES,{shift3Compatibility:true,confirmedShiftCodes:new Set()})).toMatchObject({shift:"SHIFT_2",isOperationalOvertime:true});
  });
});

describe("ERP labour rules",()=>{
  const sheet=(id:string,startAt:string,endAt:string,paidHours:number)=>({id,personKey:"P1",area:"DTG_OPERATOR",startAt,endAt,paidHours,approval:"APPROVED" as const});
  it("reconciles paid, productive, regular and overtime hours",()=>{
    const rows=segmentLabour([sheet("a","2026-09-07T20:00:00Z","2026-09-08T04:30:00Z",8)]);
    const sum=(key:"paidHours"|"productiveHours"|"paidBreakHours"|"regularHours"|"overtimeHours")=>rows.reduce((n,r)=>n+r[key],0);
    expect(sum("paidHours")).toBeCloseTo(8);expect(sum("productiveHours")).toBeCloseTo(7+2/3);expect(sum("paidBreakHours")).toBeCloseTo(1/3);expect(sum("regularHours")).toBeCloseTo(8);expect(sum("overtimeHours")).toBeCloseTo(0);
  });
  it("classifies weekend work as overtime",()=>expect(segmentLabour([sheet("a","2026-09-11T20:00:00Z","2026-09-12T04:00:00Z",8)]).reduce((n,r)=>n+r.overtimeHours,0)).toBeCloseTo(8));
  it("caps weekday regular hours at 8 daily and 38 weekly",()=>{
    const rows=segmentLabour([0,1,2,3,4].map((d)=>sheet(String(d),new Date(Date.UTC(2026,8,6+d,20)).toISOString(),new Date(Date.UTC(2026,8,7+d,6)).toISOString(),10)));
    expect(rows.reduce((n,r)=>n+r.regularHours,0)).toBeCloseTo(38);expect(rows.reduce((n,r)=>n+r.overtimeHours,0)).toBeCloseTo(12);
  });
});

describe("ERP KPI maths",()=>{
  it("keeps absent sources null and applies operational rates",()=>{
    const events=[{eventId:"1",timestamp:"2026-09-08T00:00:00Z",operationalDate:"2026-09-08",shift:"SHIFT_1",metric:"DTG_PRINT",quantity:1260,quality:"COMPLETE"}];
    const labour=[{personKey:"P1",area:"DTG_OPERATOR",operationalDate:"2026-09-08",shift:"SHIFT_1",hour:6,paidHours:8,regularHours:8,overtimeHours:0,paidBreakHours:1/3,productiveHours:7+2/3,approval:"APPROVED"}];
    const row=calculateKpis(events,labour,"DAY")[0];
    expect(row.dtgTarget).toBe(1190);expect(row.dtgAchievement).toBeCloseTo(1260/1190);expect(row.screenActual).toBeNull();expect(row.screenTarget).toBeNull();
  });
  it("stores accumulation and clearance with opposite explicit signs",()=>{
    const events=[{eventId:"1",timestamp:"2026-09-08T00:00:00Z",operationalDate:"2026-09-08",shift:"SHIFT_1",metric:"DTG_PUTWALL_IN",quantity:2000,quality:"COMPLETE"},{eventId:"2",timestamp:"2026-09-08T01:00:00Z",operationalDate:"2026-09-08",shift:"SHIFT_1",metric:"DTG_PUTWALL_OUT",quantity:1500,quality:"COMPLETE"}];
    expect(calculateKpis(events,[],"DAY")[0]).toMatchObject({accumulation:500,clearance:-500});
  });
});

describe("ERP flow rules",()=>{
  it("calculates trusted physical occupancy",()=>expect(calculatePutwallSnapshot(Array.from({length:43},(_,i)=>({location:`PWL-${i}`,packId:`B-${i}`,quantity:1,timestamp:null})),96)).toMatchObject({occupiedLocations:43,freeLocations:53,occupancyPercent:43/96,boxes:43,garments:43,quality:"COMPLETE"}));
  it("keeps occupancy null when its physical source is missing",()=>expect(calculatePutwallSnapshot([],96)).toMatchObject({occupiedLocations:null,freeLocations:null,occupancyPercent:null,boxes:null,garments:null,quality:"MISSING_SOURCE"}));
});

describe("ERP planning policy",()=>{
  const base={demand:3000,morningCapacity:4000,afternoonCapacity:4000,graveyardCapacity:2000,dtgOperators:1,upResources:1,dispatchResources:1};
  it("runs Morning first and never runs Graveyard without Afternoon",()=>expect(recommendShiftPlan(base)).toMatchObject({morning:true,afternoon:false,graveyard:false,viable:true}));
  it("activates Afternoon before Graveyard",()=>expect(recommendShiftPlan({...base,demand:7000})).toMatchObject({morning:true,afternoon:true,graveyard:false}));
  it("uses Graveyard only as overflow above the configured trigger",()=>expect(recommendShiftPlan({...base,demand:12000})).toMatchObject({morning:true,afternoon:true,graveyard:true}));
  it("rejects a DTG plan without upstream and dispatch coverage",()=>expect(recommendShiftPlan({...base,upResources:0})).toMatchObject({morning:false,afternoon:false,graveyard:false,viable:false}));
});
