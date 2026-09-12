export type ScanKind="ORDER"|"PACK"|"AUTO";
export type ParsedScan={kind:ScanKind;value:string;canonical:string};
const prefixes:Array<[RegExp,ScanKind]>=[[ /^(?:TSD:)?ORDER:/i,"ORDER"],[/^(?:TSD:)?PACK:/i,"PACK"]];
export function parseScan(raw:string):ParsedScan|null{let value=raw.trim(),kind:ScanKind="AUTO";for(const[prefix,type]of prefixes)if(prefix.test(value)){value=value.replace(prefix,"").trim();kind=type;break}value=[...value].filter(character=>{const code=character.charCodeAt(0);return code>31&&code!==127}).join("");if(!value||value.length>128||!/^[A-Za-z0-9_-]+$/.test(value))return null;return{kind,value,canonical:`TSD:${kind}:${value}`}}
export function orderPayload(orderNo:string){const parsed=parseScan(`ORDER:${orderNo}`);if(!parsed)throw new Error("Invalid order number");return`TSD:ORDER:${parsed.value}`}
