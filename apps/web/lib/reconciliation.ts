export function normalizePage(value:string|undefined){const n=Number(value);return Number.isInteger(n)&&n>0?n:1}
export function freshness(value:string|null,now=Date.now()){if(!value)return {level:"stale",label:"No completed sync"} as const;return now-new Date(value).getTime()>300000?{level:"stale",label:"Data stale"} as const:{level:"fresh",label:"Source current"} as const}
