import {classifyProductType,extractProductType,PRODUCTION_MIX_GROUPS,type ProductionMixAudience,type ProductionMixGroup} from "./production-mix";

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

export type InformationalMixState="WAITING_FOR_PICKING"|"READY_TO_PRINT"|"NOT_APPROVED_INFORMATIONAL";
export type InformationalMixInput={recordKey:string;orderNo:string;productCode:string;productDescription:string;quantity:number;state:InformationalMixState;customer?:string;dueDate?:string;lineNumber?:string;process?:string;routingResolution?:string};
export type InformationalMixDetail=InformationalMixInput&{family:ProductionMixGroup;quantitySemantics:"PHYSICAL_SOURCE_QTY"|"PROCESS_QUANTITY"};
export type InformationalMixFamily={family:ProductionMixGroup;waitingForPicking:number;readyToPrint:number;activePhysicalTotal:number;notApprovedProcessQuantity:number;activeOrders:number;potentialOrders:number;details:InformationalMixDetail[]};
export type InformationalProductMix={families:InformationalMixFamily[];summary:{activePhysicalQuantity:number;notApprovedProcessQuantity:number;classifiedActiveQuantity:number;unclassifiedActiveQuantity:number;activeCoveragePercent:number;overlapExcluded:number};reconciled:boolean};

export function buildInformationalProductMix(input:InformationalMixInput[],showNotApproved:boolean):InformationalProductMix{
  const seen=new Set<string>();
  const clean=input.filter(row=>Number.isFinite(row.quantity)&&row.quantity>0&&row.recordKey&&!seen.has(row.recordKey)&&Boolean(seen.add(row.recordKey)));
  const active=clean.filter(row=>row.state!=="NOT_APPROVED_INFORMATIONAL");
  const activeOrderProducts=new Set(active.map(row=>`${row.orderNo}\u0000${row.productCode}`));
  let overlapExcluded=0;
  const visible=clean.filter(row=>{
    if(row.state!=="NOT_APPROVED_INFORMATIONAL")return true;
    if(!showNotApproved)return false;
    if(activeOrderProducts.has(`${row.orderNo}\u0000${row.productCode}`)){overlapExcluded+=1;return false;}
    return true;
  });
  const details:InformationalMixDetail[]=visible.map(row=>({...row,family:classifyProductType(extractProductType(row.productDescription)),quantitySemantics:row.state==="NOT_APPROVED_INFORMATIONAL"?"PROCESS_QUANTITY":"PHYSICAL_SOURCE_QTY"}));
  const families=PRODUCTION_MIX_GROUPS.map(family=>{
    const own=details.filter(row=>row.family===family),waitingForPicking=own.filter(row=>row.state==="WAITING_FOR_PICKING").reduce((sum,row)=>sum+row.quantity,0),readyToPrint=own.filter(row=>row.state==="READY_TO_PRINT").reduce((sum,row)=>sum+row.quantity,0),potential=own.filter(row=>row.state==="NOT_APPROVED_INFORMATIONAL");
    return{family,waitingForPicking,readyToPrint,activePhysicalTotal:waitingForPicking+readyToPrint,notApprovedProcessQuantity:potential.reduce((sum,row)=>sum+row.quantity,0),activeOrders:new Set(own.filter(row=>row.state!=="NOT_APPROVED_INFORMATIONAL").map(row=>row.orderNo)).size,potentialOrders:new Set(potential.map(row=>row.orderNo)).size,details:own};
  });
  const activePhysicalQuantity=families.reduce((sum,row)=>sum+row.activePhysicalTotal,0),unclassifiedActiveQuantity=families.find(row=>row.family==="OTHER")?.activePhysicalTotal??0,classifiedActiveQuantity=activePhysicalQuantity-unclassifiedActiveQuantity;
  return{families,summary:{activePhysicalQuantity,notApprovedProcessQuantity:families.reduce((sum,row)=>sum+row.notApprovedProcessQuantity,0),classifiedActiveQuantity,unclassifiedActiveQuantity,activeCoveragePercent:activePhysicalQuantity?classifiedActiveQuantity/activePhysicalQuantity*100:100,overlapExcluded},reconciled:Math.abs(activePhysicalQuantity-active.reduce((sum,row)=>sum+row.quantity,0))<.001};
}
