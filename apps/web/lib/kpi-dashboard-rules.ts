export type NullableNumber=number|null;
export const safeDivide=(a:NullableNumber,b:NullableNumber)=>a===null||b===null||b<=0?null:a/b;
export const variance=(actual:NullableNumber,target:NullableNumber)=>actual===null||target===null?null:actual-target;
export const planAttainment=(actual:NullableNumber,target:NullableNumber)=>safeDivide(actual,target);
export const capacityLoad=(demand:NullableNumber,capacity:NullableNumber)=>safeDivide(demand,capacity);
export const capacityGap=(demand:NullableNumber,capacity:NullableNumber)=>demand===null||capacity===null?null:capacity-demand;
export const backlogClearance=(backlog:NullableNumber,capacity:NullableNumber)=>safeDivide(backlog,capacity);
export const labourProductivity=(actual:NullableNumber,hours:NullableNumber)=>safeDivide(actual,hours);
export const slaBucket=(days:number)=>days<=1?"0-1":days<=2?"1-2":days<=3?"2-3":days<=4?"3-4":">4";
export function riskLevel(age:number,due:string|null,priority:number|null,now=new Date()){const overdue=due?new Date(`${due.slice(0,10)}T23:59:59+10:00`).getTime()<now.getTime():false;if(age>6||overdue&&age>4||priority===1)return"CRITICAL";if(age>4||overdue)return"HIGH";if(age>2||priority===2)return"MEDIUM";return"LOW"}
export function brisbaneDate(date=new Date()){return new Intl.DateTimeFormat("en-CA",{timeZone:"Australia/Brisbane",year:"numeric",month:"2-digit",day:"2-digit"}).format(date)}
export function defaultRange(days=13){const to=brisbaneDate(),d=new Date(`${to}T12:00:00Z`);d.setUTCDate(d.getUTCDate()-days);return{from:d.toISOString().slice(0,10),to}}
