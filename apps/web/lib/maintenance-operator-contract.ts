export const OPERATOR_REQUEST_TYPES=["OPERATOR_FIX","CORRECTIVE_NOW","SCHEDULE_CORRECTIVE"]as const;

export type OperatorRequestType=(typeof OPERATOR_REQUEST_TYPES)[number];

export const OPERATOR_REQUEST_OPTIONS:ReadonlyArray<{type:OperatorRequestType;title:string;body:string;tone:string}>=[
 {type:"OPERATOR_FIX",title:"OPERATOR FIX",body:"Machine stopped. I will try to fix it.",tone:"operator"},
 {type:"CORRECTIVE_NOW",title:"CORRECTIVE NOW",body:"Machine stopped. Call maintenance now.",tone:"now"},
 {type:"SCHEDULE_CORRECTIVE",title:"SCHEDULE CORRECTIVE",body:"Machine still running. Schedule maintenance.",tone:"schedule"}
];

export function isOperatorRequestType(value:string):value is OperatorRequestType{return OPERATOR_REQUEST_TYPES.includes(value as OperatorRequestType)}
