export type CapacityInput={resources:number;hours:number;rate:number;efficiency:number;workDays?:number};
export function capacity(i:CapacityInput){if([i.resources,i.hours,i.rate,i.efficiency].some(v=>!Number.isFinite(v)||v<0)||i.hours>24||i.efficiency>1)throw new Error("Invalid capacity input");return i.resources*i.hours*i.rate*i.efficiency}
export function weeklyCapacity(i:CapacityInput){const days=i.workDays??5;if(!Number.isFinite(days)||days<0||days>7)throw new Error("Invalid work days");return capacity(i)*days}
export function capacityMetrics(demand:number,daily:number){if(demand<0||daily<0)throw new Error("Invalid demand or capacity");return{loadPercent:daily===0?null:demand/daily*100,gap:daily-demand,relativeLead:daily===0?null:demand/daily}}
export function crossesMidnight(start:string,end:string){return end<=start}
export function productionDate(eventDate:string,eventTime:string,start:string,end:string){const d=new Date(`${eventDate}T00:00:00Z`);if(crossesMidnight(start,end)&&eventTime<end)d.setUTCDate(d.getUTCDate()-1);return d.toISOString().slice(0,10)}
