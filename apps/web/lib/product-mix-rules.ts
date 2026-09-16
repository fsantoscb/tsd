import type {ProductionMixAudience,ProductionMixGroup} from "@/lib/production-mix";

export type ProductMixInput={orderNo:string;quantity:number;audience:ProductionMixAudience;garmentType:ProductionMixGroup;status:"TO_PICK"|"PICKED"};
export type ProductMixSlice={label:string;total:number;share:number;orders:number;toPick:number;picked:number};
export type ProductMixAudienceSlice=ProductMixSlice&{types:ProductMixSlice[]};
export type ProductMixResult={total:number;audiences:ProductMixAudienceSlice[];garmentTypes:ProductMixSlice[];reconciled:boolean};

const slice=(label:string,rows:ProductMixInput[],grand:number):ProductMixSlice=>{const total=rows.reduce((n,x)=>n+x.quantity,0);return{label,total,share:grand?total/grand*100:0,orders:new Set(rows.map(x=>x.orderNo)).size,toPick:rows.filter(x=>x.status==="TO_PICK").reduce((n,x)=>n+x.quantity,0),picked:rows.filter(x=>x.status==="PICKED").reduce((n,x)=>n+x.quantity,0)}};

export function buildProductMix(input:ProductMixInput[]):ProductMixResult{
  const rows=input.filter(x=>Number.isFinite(x.quantity)&&x.quantity>0),total=rows.reduce((n,x)=>n+x.quantity,0),audienceNames:ProductionMixAudience[]=["ADULT","KIDS","UNCLASSIFIED"],garmentNames=[...new Set(rows.map(x=>x.garmentType))];
  const audiences=audienceNames.map(label=>{const own=rows.filter(x=>x.audience===label),base=slice(label,own,total);return{...base,types:garmentNames.map(type=>slice(type,own.filter(x=>x.garmentType===type),base.total)).filter(x=>x.total>0).sort((a,b)=>b.total-a.total)}});
  const garmentTypes=garmentNames.map(label=>slice(label,rows.filter(x=>x.garmentType===label),total)).filter(x=>x.total>0).sort((a,b)=>b.total-a.total);
  const close=(a:number,b:number)=>Math.abs(a-b)<.001;
  return{total,audiences,garmentTypes,reconciled:close(audiences.reduce((n,x)=>n+x.total,0),total)&&close(garmentTypes.reduce((n,x)=>n+x.total,0),total)&&close(garmentTypes.reduce((n,x)=>n+x.toPick+x.picked,0),total)};
}
