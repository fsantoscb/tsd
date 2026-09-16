export const LABOUR_SHIFTS=["SHIFT_1","SHIFT_2","SHIFT_3","OUT_OF_SHIFT"] as const;
export type LabourShift=typeof LABOUR_SHIFTS[number];
export type LabourSegment={operational_date:string;area_code:string;shift_code:string;person_key:string;paid_hours:number|string;productive_hours:number|string;regular_hours:number|string;overtime_hours:number|string;paid_break_hours:number|string;approval_status:string};
export type LabourCell={people:Set<string>;paid:number;productive:number;regular:number;overtime:number;breaks:number;provisional:boolean};
export type LabourMatrixRow={date:string;area:string;people:Set<string>;shifts:Record<LabourShift,LabourCell>;paid:number;productive:number;regular:number;overtime:number;breaks:number;provisional:boolean;reconciled:boolean};
const cell=():LabourCell=>({people:new Set(),paid:0,productive:0,regular:0,overtime:0,breaks:0,provisional:false});
const shiftOf=(value:string):LabourShift=>LABOUR_SHIFTS.includes(value as LabourShift)?value as LabourShift:"OUT_OF_SHIFT";
export function buildLabourMatrix(data:LabourSegment[]){
  const map=new Map<string,LabourMatrixRow>();
  for(const x of data){
    if(x.approval_status==="INCOMPLETE"||!x.operational_date||!x.area_code)continue;
    const key=`${x.operational_date}|${x.area_code}`,shift=shiftOf(x.shift_code);
    const r=map.get(key)??{date:x.operational_date,area:x.area_code,people:new Set<string>(),shifts:{SHIFT_1:cell(),SHIFT_2:cell(),SHIFT_3:cell(),OUT_OF_SHIFT:cell()},paid:0,productive:0,regular:0,overtime:0,breaks:0,provisional:false,reconciled:true};
    const s=r.shifts[shift],paid=Number(x.paid_hours||0),productive=Number(x.productive_hours||0),regular=Number(x.regular_hours||0),overtime=Number(x.overtime_hours||0),breaks=Number(x.paid_break_hours||0);
    r.people.add(x.person_key);s.people.add(x.person_key);s.paid+=paid;s.productive+=productive;s.regular+=regular;s.overtime+=overtime;s.breaks+=breaks;s.provisional||=x.approval_status==="PROVISIONAL";
    r.paid+=paid;r.productive+=productive;r.regular+=regular;r.overtime+=overtime;r.breaks+=breaks;r.provisional||=x.approval_status==="PROVISIONAL";map.set(key,r);
  }
  for(const r of map.values()){
    const sum=(field:"paid"|"regular"|"overtime"|"breaks")=>LABOUR_SHIFTS.reduce((a,s)=>a+r.shifts[s][field],0);
    r.reconciled=[sum("paid")-r.paid,sum("regular")-r.regular,sum("overtime")-r.overtime,sum("breaks")-r.breaks,r.regular+r.overtime-r.paid,r.paid-r.breaks-r.productive].every(x=>Math.abs(x)<.02);
  }
  return [...map.values()];
}
export const labourAreaLabel=(code:string)=>({DTG_OPERATOR:"DTG",UP_OPERATOR:"Underprint",SCREEN_PRINT_CREW:"Screen Print",SCREEN_ROOM:"Screen Room",SHARED_DISPATCH:"Dispatch",INDIRECT:"Indirect"}[code]??code.replaceAll("_"," ").replace(/\b\w/g,x=>x.toUpperCase()));
