import "server-only";

export async function applyShipTo(rows:any[],db:any){
  const orderNumbers=[...new Set(rows.map(row=>String(row.order_no??"")).filter(Boolean))];
  if(!orderNumbers.length)return rows;
  const names=new Map<string,string>();
  for(let from=0;from<orderNumbers.length;from+=200){
    const{data,error}=await db.from("v_current_orders").select("order_no,ship_to_name").in("order_no",orderNumbers.slice(from,from+200));
    if(error)throw error;
    for(const order of data??[])names.set(String(order.order_no),String(order.ship_to_name??""));
  }
  return rows.map(row=>({...row,ship_to_name:names.get(String(row.order_no))??""}));
}
