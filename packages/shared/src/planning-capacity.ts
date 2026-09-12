export type PlanningCapacityInput={resources:number;shiftHours:number;ratePerHour:number;efficiency:number};
export const planningCapacity=({resources,shiftHours,ratePerHour,efficiency}:PlanningCapacityInput)=>resources*shiftHours*ratePerHour*efficiency;
export const planningLoad=(demand:number,capacity:number)=>capacity>0?demand/capacity:null;
export const planningGap=(demand:number,capacity:number)=>capacity-demand;

export type ShiftPlanInput={demand:number;morningCapacity:number;afternoonCapacity:number;graveyardCapacity:number;dtgOperators:number;upResources:number;dispatchResources:number;graveyardTrigger?:number;slaDays?:number};
export type ShiftPlanRecommendation={morning:boolean;afternoon:boolean;graveyard:boolean;viable:boolean;projectedCapacity:number;projectedLeadDays:number|null;reason:string};
export function recommendShiftPlan(input:ShiftPlanInput):ShiftPlanRecommendation{
  const trigger=input.graveyardTrigger??10000,sla=input.slaDays??4,viable=input.dtgOperators>=1&&input.upResources>=1&&input.dispatchResources>=1;
  if(!viable)return{morning:false,afternoon:false,graveyard:false,viable:false,projectedCapacity:0,projectedLeadDays:null,reason:"DTG requires operator, UP feed and tunnel/dispatch coverage"};
  const morning=true,afternoon=input.demand>input.morningCapacity,base=input.morningCapacity+(afternoon?input.afternoonCapacity:0),graveyard=afternoon&&input.demand>base&&input.demand>trigger,projectedCapacity=base+(graveyard?input.graveyardCapacity:0),projectedLeadDays=projectedCapacity>0?input.demand/projectedCapacity:null;
  const reason=graveyard?"Graveyard required after Morning and Afternoon capacity":afternoon?"Morning and Afternoon absorb demand":"Morning absorbs demand";
  return{morning,afternoon,graveyard,viable,projectedCapacity,projectedLeadDays,reason:projectedLeadDays!==null&&projectedLeadDays>sla?`${reason}; SLA risk remains`:reason}
}
